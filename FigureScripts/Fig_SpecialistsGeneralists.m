%% Fig_SpecialistsGeneralists.m
% Reproduces the specialist/generalist results of the paper
% (section "Pure specialists and absolute generalists"; figures specgen / comsg2).
%
% Teams are mixtures of pure specialists (IFDS = 0) and absolute generalists
% (IFDS = 1); agents are built with GenAgent Method 2. Each condition produces a
% 2x2 surface over the IFD-DFD plane:
%   (a) performance  = fraction of total task workload solved (0-1)
%   (b) communication density = task passes per simulation step
%   (c) steps to completion (log scale, capped at EmergencyStop)
%   (d) fraction of agent pairs able to collaborate
%
% Conditions produced (similarity threshold tau; communication scheme):
%   specgen_B : tau =  80%, scheme 1 (pass when stuck)        -> paper Fig. specgen, panel B
%   specgen_C : tau = 100%, scheme 1 (all pairs communicate)  -> paper Fig. specgen, panel C
%   comsg2    : tau =  80%, scheme 2 (repeatedly seek best)   -> paper Fig. comsg2
% Panel A of Fig. specgen ("communication too restricted for specialist-generalist
% collaboration") is the same sweep at a lower tau; add a row to `conds` to explore it.
%
% Run:  >> Fig_SpecialistsGeneralists           (paper settings)
%       >> QUICK = true; Fig_SpecialistsGeneralists   (fast smoke test)

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, '..', 'Functions'));
figdir = fullfile(thisdir, '..', 'figures');
if ~exist(figdir, 'dir'); mkdir(figdir); end
set(0, 'DefaultFigureVisible', 'off');
if ~exist('QUICK', 'var'); QUICK = false; end

%% Parameters
P.numfuncs = 9; P.numagents = 10; P.numtasks = 7;
P.anorm = 10; P.tnorm = 10; P.TaskType = 1;
P.AgentGenMethod = 2;                 % mixture of specialists and generalists
P.maxPass = Inf; P.passCost = 5; P.PCDistDep = false; P.NoPassInRef = true;
P.EmergencyStop = 250;
P.MixingRatios = 0:1/P.numagents:1;   % ratio of generalists to specialists
P.DFDs = [0 0.20 0.36 0.47 0.54 0.61 0.65 0.70 0.74 0.79 0.83 0.86 0.88 0.90 0.92 0.95 0.97 0.99];
P.numrepeats = 10;
if QUICK; P.numrepeats = 3; end

% {label, similThresh (%), passVersion}  (passVersion 2 = scheme 1, 1 = scheme 2)
conds = { 'specgen_B', 80,  2; ...
          'specgen_C', 100, 2; ...
          'comsg2',    80,  1 };

rng('default')
for c = 1:size(conds, 1)
    label = conds{c, 1}; P.similThresh = conds{c, 2}; P.passVersion = conds{c, 3};
    fprintf('\n=== %s: tau=%d%%, scheme %d ===\n', label, P.similThresh, 3 - P.passVersion);
    [DFD, IFD, perf, comm, steps, collab] = sgSweep(P);
    f = plotSurf(DFD, IFD, perf, comm, steps, collab, P, label);
    exportgraphics(f, fullfile(figdir, ['SpecGen_' label '.png']), 'Resolution', 150);
    exportgraphics(f, fullfile(figdir, ['SpecGen_' label '.pdf']));
    close(f)
    fprintf('saved SpecGen_%s.png / .pdf\n', label);
end
fprintf('\nDONE Fig_SpecialistsGeneralists\n');

%% ---------- local functions ----------
function [DFD, IFD, perf, comm, steps, collab] = sgSweep(P)
    nI = numel(P.MixingRatios); nG = numel(P.DFDs);
    DFD = NaN(nI, nG); IFD = NaN(nI, nG); meanstn = NaN(nI, nG);
    meanca = NaN(nI, nG); meansno = NaN(nI, nG); simAgs = NaN(nI, nG);
    etc.maxPass = P.maxPass; etc.emStop = P.EmergencyStop; etc.passCost = P.passCost;
    etc.passVersion = P.passVersion; etc.PCDistDep = P.PCDistDep; etc.NoPassInRef = P.NoPassInRef;
    maxDist = sqrt(2 * P.anorm^2); simTh = maxDist * P.similThresh / 100;
    for ai = 1:nI
        parfor gi = 1:nG
            agents = GenAgent(P.numfuncs, P.numagents, [], [], P.anorm, 'Method', P.AgentGenMethod, ...
                'DesiredDFD', P.DFDs(gi), 'MixingRatio', P.MixingRatios(ai)); %#ok<PFBNS>
            agdistmat = squareform(pdist(agents));
            simAgs(ai, gi) = sum(agdistmat <= simTh, 'all') - P.numagents;
            [DFD(ai, gi), IFD(ai, gi)] = CalcFD(agents);
            stn = zeros(P.numrepeats, 1); ca = NaN(P.numrepeats, 1); sno = NaN(P.numrepeats, 1);
            for r = 1:P.numrepeats
                tasks = GenTask(P.numfuncs, P.numtasks, P.tnorm, P.EmergencyStop, P.TaskType, agents);
                [t2a, th, sno(r)] = PassingSolveTasks(agents, tasks, etc, agdistmat, simTh);
                a = th(:, :, 1); b = th(:, :, end); a(isnan(a)) = 0; b(isnan(b)) = 0;
                stn(r) = sum(sum(a - b));
                d = diff(t2a); ca(r) = sum(sum(d ~= 0 & ~isnan(d))) / sno(r);
            end
            meanstn(ai, gi) = mean(stn); meanca(ai, gi) = mean(ca); meansno(ai, gi) = mean(sno);
        end
        fprintf('.');
    end
    fprintf('\n');
    perf = meanstn / (P.numtasks * P.tnorm); comm = meanca; steps = meansno;
    collab = simAgs / ((P.numagents - 1) * P.numagents);
end

function f = plotSurf(DFD, IFD, perf, comm, steps, collab, P, label)
    f = figure('Position', [60 60 900 720]);
    t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, sprintf('Specialists & generalists  |  %s  |  \\tau = %d%%  |  scheme %d', ...
        strrep(label, '_', '\_'), P.similThresh, 3 - P.passVersion), 'Interpreter', 'tex');
    nexttile; surf(DFD, IFD, perf);   zlim([0 1]); clim([0 1]); zlabel('Performance (fraction solved)'); decorateAxis
    nexttile; surf(DFD, IFD, comm);   zlabel('Communication density'); decorateAxis
    nexttile; surf(DFD, IFD, steps);  set(gca, 'ZScale', 'log'); zlabel('Steps to completion'); decorateAxis
    nexttile; surf(DFD, IFD, collab); zlim([0 1]); zlabel('Fraction collaborating pairs'); decorateAxis
end

function decorateAxis
    grid on; xlim([0 1]); ylim([0 1]); view(45, 30);
    xlabel('Dominant Function Diversity'); ylabel('Individual Functional Diversity');
end
