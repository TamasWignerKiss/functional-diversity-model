function res = runSweep(par)
%RUNSWEEP Run an IFD x DFD sweep and return diversity-vs-outcome regression coefficients.
%
% This is the reusable measurement core extracted from PaperFigureScripts/MixedTeam.m
% and SDIExample.m. It runs the agent/task simulation over a grid of desired IFD and
% DFD values, then fits:
%       Comm ~ 1 + IFD + DFD
%       Perf ~ 1 + IFD + DFD
% and returns the IFD and DFD slope coefficients (the quantities whose SIGNS encode
% the Bunderson&Sutcliffe (negative DFD) vs Zhou (positive DFD) behaviours).
%
% No plotting, no diary. Designed to be called many times by a driver script.
%
% Input: par struct with fields (defaults applied if missing):
%   numfuncs(9) numagents(10) numtasks(7) anorm(10) tnorm(10)
%   TaskType(1) AgentGenMethod(4) maxPass(Inf) similThresh(90) passCost(50)
%   NoPassInRef(true) PCDistDep(false) passVersion(1)
%   RestrictedFunctions(Inf) MixSkillStrengths(true) OldDFDGen(false)
%   IFDSLevel(5) IFDSFitRange([0 0.99]) SigEstMeth(2)
%   numrepeats(10) EmergencyStop(250)
%   IFDs (vector of desired IFD)        default 0:0.1:1
%   nDFD (number of desired DFD steps)  default 13
%   DFDmeasd([0.27 0.92]) IFDmeasd([0.12 0.51])  (B&S measured region)
%
% Output: res struct with grids (IFD,DFD,meanstn,meanca,meansno,simAgs) and
%   res.full  = coefficients over the whole feasible grid
%   res.bs    = coefficients over the B&S measured region only
%   each with fields: bIFD_Comm bDFD_Comm pIFD_Comm pDFD_Comm
%                     bIFD_Perf bDFD_Perf pIFD_Perf pDFD_Perf  n
%
% Author: (anonymized for double-anonymous peer review)

%% Defaults
def = struct('numfuncs',9,'numagents',10,'numtasks',7,'anorm',10,'tnorm',10, ...
    'TaskType',1,'AgentGenMethod',4,'maxPass',Inf,'similThresh',90,'passCost',50, ...
    'NoPassInRef',true,'PCDistDep',false,'passVersion',1,'RestrictedFunctions',Inf, ...
    'MixSkillStrengths',true,'OldDFDGen',false,'IFDSLevel',5,'IFDSFitRange',[0 0.99], ...
    'SigEstMeth',2,'numrepeats',10,'EmergencyStop',250,'nDFD',13,'DFDmeasd',[0.27 0.92], ...
    'IFDmeasd',[0.12 0.51],'gamma',1);
fn = fieldnames(def);
for k = 1:numel(fn)
    if ~isfield(par, fn{k}) || isempty(par.(fn{k}))
        par.(fn{k}) = def.(fn{k});
    end
end
if ~isfield(par,'IFDs') || isempty(par.IFDs), par.IFDs = 0:0.1:1; end

%% Build a feasible desired-DFD grid given the function restriction
nfEff   = min(par.RestrictedFunctions, par.numfuncs);
maxDFDf = 1 - 1/nfEff;                       % largest DFD attainable
if isfield(par,'DFDvec') && ~isempty(par.DFDvec)
    DFDdes = par.DFDvec;                      % explicit desired-DFD list (match paper grid)
else
    DFDdes = linspace(0, 0.98*maxDFDf, par.nDFD);
end
IFDdes  = par.IFDs;

%% Containers
nI = numel(IFDdes); nG = numel(DFDdes);
DFD = NaN(nI,nG); IFD = NaN(nI,nG); SDI = NaN(nI,nG);
meanstn = NaN(nI,nG); meanca = NaN(nI,nG); meansno = NaN(nI,nG); simAgs = NaN(nI,nG);

etc.maxPass = par.maxPass; etc.emStop = par.EmergencyStop; etc.passCost = par.passCost;
etc.passVersion = par.passVersion; etc.NoPassInRef = par.NoPassInRef; etc.PCDistDep = par.PCDistDep;
maxDist = sqrt(2*par.anorm^2);
simTh = maxDist*par.similThresh/100;

rng('default')   % reproducible, matches the paper scripts

for ai = 1:nI
    parfor gi = 1:nG
        agents = GenAgent(par.numfuncs, par.numagents, [], [], par.anorm, ...
            'Method', par.AgentGenMethod, 'IFDSLevel', par.IFDSLevel, ...
            'IFDSFitRange', par.IFDSFitRange, 'DesiredIFD', IFDdes(ai), ...
            'DesiredDFD', DFDdes(gi), 'SigEstMeth', par.SigEstMeth, ...
            'MixSkillStrengths', par.MixSkillStrengths, ...
            'RestrictedFunctions', par.RestrictedFunctions, ...
            'OldDFDGen', par.OldDFDGen, 'BlockParallelWarning', true); %#ok<PFBNS>

        if any(isnan(agents(:)))
            continue   % infeasible IFD/DFD combination -> leave NaN
        end

        % Diversity labels and similarity geometry come from the NOMINAL agents,
        % so IFD/DFD and who-talks-to-whom are held fixed as gamma varies.
        agdistmat = squareform(pdist(agents));
        simAgs(ai,gi) = sum(agdistmat <= simTh, 'all') - par.numagents;
        [DFD(ai,gi), IFD(ai,gi), ~, SDI(ai,gi)] = CalcFD(agents);

        % Effective (acting) skills: contrast-sharpened so underrepresented
        % skills contribute even less to actual work. gamma==1 -> baseline.
        agents_eff = agents;
        if par.gamma ~= 1
            agents_eff = agents.^par.gamma;
            agents_eff = agents_eff ./ sum(agents_eff,2) * par.anorm;
        end

        stn = zeros(par.numrepeats,1);
        ca  = NaN(par.numrepeats,1);
        sno = NaN(par.numrepeats,1);
        for ridx = 1:par.numrepeats
            tasks = GenTask(par.numfuncs, par.numtasks, par.tnorm, par.EmergencyStop, par.TaskType, agents);
            [t2a, taskhist, sno(ridx)] = PassingSolveTasks(agents_eff, tasks, etc, agdistmat, simTh);

            tmp1 = taskhist(:,:,1);   tmp1(isnan(tmp1)) = 0;
            tmp2 = taskhist(:,:,end); tmp2(isnan(tmp2)) = 0;
            stn(ridx) = sum(sum(tmp1 - tmp2));

            tmp = diff(t2a);
            ca(ridx) = sum(sum(tmp ~= 0 & not(isnan(tmp)))) ./ sno(ridx);
        end
        meanstn(ai,gi) = mean(stn);
        meanca(ai,gi)  = mean(ca);
        meansno(ai,gi) = mean(sno);
    end
end

%% Pack grids
res.par = par;
res.IFD = IFD; res.DFD = DFD; res.SDI = SDI;
res.meanstn = meanstn; res.meanca = meanca; res.meansno = meansno; res.simAgs = simAgs;

%% Regressions
res.full = fitBlock(IFD(:), DFD(:), meanca(:), meanstn(:), true(numel(IFD),1));
bsMask = IFD(:) > par.IFDmeasd(1) & IFD(:) < par.IFDmeasd(2) & ...
         DFD(:) > par.DFDmeasd(1) & DFD(:) < par.DFDmeasd(2);
res.bs = fitBlock(IFD(:), DFD(:), meanca(:), meanstn(:), bsMask);

end

%% ---- local: fit the two regressions on a masked set of grid points ----
function b = fitBlock(IFD, DFD, Comm, Perf, mask)
good = mask & ~isnan(IFD) & ~isnan(DFD) & ~isnan(Comm) & ~isnan(Perf);
b.n = sum(good);
[b.bIFD_Comm,b.bDFD_Comm,b.pIFD_Comm,b.pDFD_Comm] = deal(NaN);
[b.bIFD_Perf,b.bDFD_Perf,b.pIFD_Perf,b.pDFD_Perf] = deal(NaN);
if b.n < 6 || numel(unique(DFD(good))) < 2 || numel(unique(IFD(good))) < 2
    return
end
tbl = table(IFD(good), DFD(good), Comm(good), Perf(good), ...
    'VariableNames', {'IFD','DFD','Comm','Perf'});
mC = fitlm(tbl, 'Comm ~ IFD + DFD');
mP = fitlm(tbl, 'Perf ~ IFD + DFD');
b.bIFD_Comm = mC.Coefficients.Estimate(strcmp(mC.CoefficientNames,'IFD'));
b.bDFD_Comm = mC.Coefficients.Estimate(strcmp(mC.CoefficientNames,'DFD'));
b.pIFD_Comm = mC.Coefficients.pValue(strcmp(mC.CoefficientNames,'IFD'));
b.pDFD_Comm = mC.Coefficients.pValue(strcmp(mC.CoefficientNames,'DFD'));
b.bIFD_Perf = mP.Coefficients.Estimate(strcmp(mP.CoefficientNames,'IFD'));
b.bDFD_Perf = mP.Coefficients.Estimate(strcmp(mP.CoefficientNames,'DFD'));
b.pIFD_Perf = mP.Coefficients.pValue(strcmp(mP.CoefficientNames,'IFD'));
b.pDFD_Perf = mP.Coefficients.pValue(strcmp(mP.CoefficientNames,'DFD'));
end
