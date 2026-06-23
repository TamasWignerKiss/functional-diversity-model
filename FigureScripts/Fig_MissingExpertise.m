%% Fig_MissingExpertise.m
% Reproduces (a) the missing-expertise illustration (paper Fig. missskill) and
% (b) the IFD/DFD regression for poor-coverage teams (Table tab:fitnonmix).
%
% Method 3 agents. "Mixed" (mu = True) spreads each agent's remaining skill
% strengths across functions at random  -> good coverage. "Non-mixed" (mu = False)
% assigns them in strictly decreasing order of skill index -> functions high in
% the index are barely covered (missing expertise). The two methods produce teams
% with IDENTICAL IFD and DFD but different skill coverage (SDI).
%
% Run:  >> Fig_MissingExpertise              (paper settings)
%       >> QUICK = true; Fig_MissingExpertise     (fast smoke test)

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, '..', 'Functions'));
figdir = fullfile(thisdir, '..', 'figures');
if ~exist(figdir, 'dir'); mkdir(figdir); end
set(0, 'DefaultFigureVisible', 'off');
if ~exist('QUICK', 'var'); QUICK = false; end

%% (a) Two example teams with identical IFD, DFD but different coverage -- Fig. missskill
nf = 9; na = 10; anorm = 10; exIFD = 0.65; exDFD = 0.79;
genArgs = {'Method', 3, 'IFDSLevel', 5, 'IFDSFitRange', [0 0.99], ...
    'DesiredIFD', exIFD, 'DesiredDFD', exDFD, 'SigEstMeth', 2, 'OldDFDGen', true};
rng('default'); agMix    = GenAgent(nf, na, [], [], anorm, genArgs{:}, 'MixSkillStrengths', true);
rng('default'); agNonmix = GenAgent(nf, na, [], [], anorm, genArgs{:}, 'MixSkillStrengths', false);

if any(isnan(agMix(:))) || any(isnan(agNonmix(:)))
    error('GenAgent returned NaN for IFD=%.2f, DFD=%.2f (infeasible request).', exIFD, exDFD);
end
[dfdM, ifdM, ~, sdiM] = CalcFD(agMix);
[dfdN, ifdN, ~, sdiN] = CalcFD(agNonmix);
fprintf('Mixed     team: IFD=%.2f  DFD=%.2f  SDI=%.2f\n', ifdM, dfdM, sdiM);
fprintf('Non-mixed team: IFD=%.2f  DFD=%.2f  SDI=%.2f\n', ifdN, dfdN, sdiN);

f = figure('Position', [60 60 950 760]);
t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, sprintf('Missing expertise: two teams, IFD = %.2f, DFD = %.2f', ifdM, dfdM));
nexttile; imagesc(agMix);    axis image; colorbar; clim([0 anorm]); title(sprintf('A  Skill strengths, mixed (SDI = %.2f)', sdiM));    xlabel('Function'); ylabel('Agent');
nexttile; imagesc(agNonmix); axis image; colorbar; clim([0 anorm]); title(sprintf('B  Skill strengths, non-mixed (SDI = %.2f)', sdiN)); xlabel('Function'); ylabel('Agent');
nexttile; imagesc(squareform(pdist(agMix)));    axis image; colorbar; title('C  Agent-agent distance, mixed');     xlabel('Agent'); ylabel('Agent');
nexttile; imagesc(squareform(pdist(agNonmix))); axis image; colorbar; title('D  Agent-agent distance, non-mixed'); xlabel('Agent'); ylabel('Agent');
exportgraphics(f, fullfile(figdir, 'MissingExpertise_teams.png'), 'Resolution', 150);
exportgraphics(f, fullfile(figdir, 'MissingExpertise_teams.pdf')); close(f)
fprintf('saved MissingExpertise_teams.png / .pdf\n');

%% (b) Regression for poor-coverage (non-mixed) teams -- Table tab:fitnonmix
MT_DFD = [0 0.20 0.36 0.47 0.54 0.61 0.65 0.70 0.74 0.79 0.83 0.86 0.88 0.90 0.92 0.95 0.97 0.99];
base = struct('numfuncs', 9, 'numagents', 10, 'numtasks', 7, 'anorm', 10, 'tnorm', 10, ...
    'TaskType', 1, 'AgentGenMethod', 3, 'OldDFDGen', true, 'maxPass', Inf, 'NoPassInRef', true, ...
    'PCDistDep', false, 'RestrictedFunctions', Inf, 'IFDSLevel', 5, 'IFDSFitRange', [0 0.99], ...
    'SigEstMeth', 2, 'EmergencyStop', 250, 'similThresh', 60, 'passCost', 5, 'gamma', 1, ...
    'MixSkillStrengths', false, 'DFDvec', MT_DFD, 'IFDs', 0:0.05:1, 'numrepeats', 10);
if QUICK; base.IFDs = 0:0.1:1; base.numrepeats = 3; end
pn = base.numtasks * base.tnorm;

for pv = [2 1]
    par = base; par.passVersion = pv;
    fprintf('\n===== Non-mixed (missing expertise), scheme %d  (cf. Table tab:fitnonmix) =====\n', 3 - pv);
    res = runSweep(par);
    ok = ~isnan(res.IFD(:)) & ~isnan(res.DFD(:)) & ~isnan(res.meanca(:)) & ~isnan(res.meanstn(:));
    T = table(res.IFD(ok), res.DFD(ok), res.meanca(ok), res.meanstn(ok) / pn, ...
        'VariableNames', {'IFD', 'DFD', 'Comm', 'Perf'});
    fprintf('Communication density ~ IFD + DFD:\n'); disp(fitlm(T, 'Comm ~ IFD + DFD'));
    fprintf('Performance ~ IFD + DFD:\n');           disp(fitlm(T, 'Perf ~ IFD + DFD'));
end
fprintf('\nDONE Fig_MissingExpertise\n');
