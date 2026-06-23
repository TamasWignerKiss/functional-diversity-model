%% Fig_MixedTeam.m
% Reproduces the diverse-team results (paper Fig. lackcomm) and the IFD/DFD
% regression of Table tab:fit. Agents have a distribution of individual breadth
% (GenAgent Method 3); skills are well covered (mixed, mu = True), tau = 60%,
% kappa = 5.
%
% For each communication scheme it produces a 2x2 pcolor over the IFD-DFD plane
% (performance, communication density, steps, fraction of collaborating pairs;
% red lines mark the Bunderson & Sutcliffe empirical window) and prints the
% multivariate regressions Comm ~ IFD + DFD and Perf ~ IFD + DFD (Table tab:fit).
%
% Run:  >> Fig_MixedTeam              (paper settings)
%       >> QUICK = true; Fig_MixedTeam     (fast smoke test)

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, '..', 'Functions'));
figdir = fullfile(thisdir, '..', 'figures');
if ~exist(figdir, 'dir'); mkdir(figdir); end
set(0, 'DefaultFigureVisible', 'off');
if ~exist('QUICK', 'var'); QUICK = false; end

MT_DFD = [0 0.20 0.36 0.47 0.54 0.61 0.65 0.70 0.74 0.79 0.83 0.86 0.88 0.90 0.92 0.95 0.97 0.99];
base = struct('numfuncs', 9, 'numagents', 10, 'numtasks', 7, 'anorm', 10, 'tnorm', 10, ...
    'TaskType', 1, 'AgentGenMethod', 3, 'OldDFDGen', true, 'maxPass', Inf, 'NoPassInRef', true, ...
    'PCDistDep', false, 'RestrictedFunctions', Inf, 'IFDSLevel', 5, 'IFDSFitRange', [0 0.99], ...
    'SigEstMeth', 2, 'EmergencyStop', 250, 'similThresh', 60, 'passCost', 5, 'gamma', 1, ...
    'MixSkillStrengths', true, 'DFDvec', MT_DFD, 'IFDs', 0:0.05:1, 'numrepeats', 10, ...
    'DFDmeasd', [0.27 0.92], 'IFDmeasd', [0.12 0.51]);
if QUICK; base.IFDs = 0:0.1:1; base.numrepeats = 3; end
pn = base.numtasks * base.tnorm;

schemes = {'A_scheme1', 2; 'B_scheme2', 1};   % passVersion 2 = scheme 1, 1 = scheme 2
for s = 1:size(schemes, 1)
    label = schemes{s, 1}; par = base; par.passVersion = schemes{s, 2};
    fprintf('\n===== Mixed team, %s (scheme %d), tau=%d%%, kappa=%d =====\n', ...
        label, 3 - par.passVersion, par.similThresh, par.passCost);
    res = runSweep(par);
    collab = res.simAgs / ((par.numagents - 1) * par.numagents);
    f = plot4(res.DFD, res.IFD, res.meanstn / pn, res.meanca, res.meansno, collab, label, par);
    exportgraphics(f, fullfile(figdir, ['MixedTeam_' label '.png']), 'Resolution', 150);
    exportgraphics(f, fullfile(figdir, ['MixedTeam_' label '.pdf'])); close(f)
    fprintf('saved MixedTeam_%s.png / .pdf\n', label);
    printReg(res, pn, sprintf('Mixed team, scheme %d  (cf. Table tab:fit)', 3 - par.passVersion));
end
fprintf('\nDONE Fig_MixedTeam\n');

%% ---------- local functions ----------
function f = plot4(DFD, IFD, perf, comm, steps, collab, label, par)
    f = figure('Position', [60 60 950 760]);
    t = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, sprintf('Diverse team (Method 3, mixed)  |  %s  |  \\tau = %d%%  |  \\kappa = %d', ...
        strrep(label, '_', '\_'), par.similThresh, par.passCost), 'Interpreter', 'tex');
    panelP(DFD, IFD, perf,   'Performance (fraction solved)', [0 1]);
    panelP(DFD, IFD, comm,   'Communication density', []);
    panelP(DFD, IFD, steps,  'Steps to completion', [0 par.EmergencyStop]);
    panelP(DFD, IFD, collab, 'Fraction collaborating pairs', [0 1]);
end

function panelP(DFD, IFD, Z, ttl, cl)
    nexttile; pcolor(DFD, IFD, Z); shading flat; hold on
    line([0.27 0.27], [0 1], 'Color', 'r', 'LineWidth', 1.5);
    line([0.92 0.92], [0 1], 'Color', 'r', 'LineWidth', 1.5);
    line([0 1], [0.12 0.12], 'Color', 'r', 'LineWidth', 1.5);
    line([0 1], [0.51 0.51], 'Color', 'r', 'LineWidth', 1.5);
    xlabel('Dominant Function Diversity'); ylabel('Individual Functional Diversity');
    cb = colorbar; ylabel(cb, ttl); if ~isempty(cl); clim(cl); end
end

function printReg(res, pn, ttl)
    ok = ~isnan(res.IFD(:)) & ~isnan(res.DFD(:)) & ~isnan(res.meanca(:)) & ~isnan(res.meanstn(:));
    T = table(res.IFD(ok), res.DFD(ok), res.meanca(ok), res.meanstn(ok) / pn, ...
        'VariableNames', {'IFD', 'DFD', 'Comm', 'Perf'});
    fprintf('\n----- %s -----\n', ttl);
    fprintf('Communication density ~ IFD + DFD:\n'); disp(fitlm(T, 'Comm ~ IFD + DFD'));
    fprintf('Performance ~ IFD + DFD:\n');           disp(fitlm(T, 'Perf ~ IFD + DFD'));
end
