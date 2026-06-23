%% Fig_SDI.m
% Reproduces the skill-diversity-index (SDI) figures of the paper:
%   SDIdiff        : Delta-SDI and Delta-Performance heatmaps (mixed minus
%                    non-mixed) at matched IFD/DFD, in an open & costly
%                    communication regime (tau = 90%, kappa = 50, scheme 2).
%   SDI_scatter    : Delta-Performance vs Delta-SDI with least-squares fit.
%   SDI_robustness : R^2 of (Delta-Perf ~ Delta-SDI) and the partial SDI
%                    coefficient on performance (controlling for IFD, DFD),
%                    as a function of tau, for several communication costs kappa.
%
% Method 3 agents; mixed (good coverage) and non-mixed (missing expertise) teams
% have identical IFD and DFD by construction, so SDI varies independently of them.
%
% Run:  >> Fig_SDI                 (paper settings; SLOW -- tens of minutes)
%       >> QUICK = true; Fig_SDI   (fast smoke test: coarse grid, fewer repeats)

thisdir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisdir, '..', 'Functions'));
figdir = fullfile(thisdir, '..', 'figures');
if ~exist(figdir, 'dir'); mkdir(figdir); end
set(0, 'DefaultFigureVisible', 'off');
if ~exist('QUICK', 'var'); QUICK = false; end

DENSE_DFD = [0 0.2025 0.36 0.3825 0.4725 0.5175 0.54 0.5625 0.6075 0.63 0.6525 0.675 0.6975 0.72 ...
             0.7425 0.765 0.7875 0.81 0.8325 0.855 0.8775 0.90 0.9225 0.945 0.9675 0.989];
MT_DFD = [0 0.20 0.36 0.47 0.54 0.61 0.65 0.70 0.74 0.79 0.83 0.86 0.88 0.90 0.92 0.95 0.97 0.99];
base = struct('numfuncs', 9, 'numagents', 10, 'numtasks', 7, 'anorm', 10, 'tnorm', 10, ...
    'TaskType', 1, 'AgentGenMethod', 3, 'OldDFDGen', true, 'maxPass', Inf, 'NoPassInRef', true, ...
    'PCDistDep', false, 'RestrictedFunctions', Inf, 'IFDSLevel', 5, 'IFDSFitRange', [0 0.99], ...
    'SigEstMeth', 2, 'EmergencyStop', 250, 'gamma', 1, 'passVersion', 1, ...
    'IFDs', 0:0.05:1, 'numrepeats', 10, 'DFDmeasd', [0.27 0.92], 'IFDmeasd', [0.12 0.51]);
if QUICK; base.IFDs = 0:0.1:1; base.numrepeats = 3; end
pn = base.numtasks * base.tnorm;

%% (1) SDI-difference maps + scatter  (open & costly regime: tau = 90%, kappa = 50, scheme 2)
fprintf('\n===== SDI difference + scatter (tau=90%%, kappa=50, scheme 2) =====\n');
par = base; par.DFDvec = DENSE_DFD; par.similThresh = 90; par.passCost = 50;
par.MixSkillStrengths = true;  rM = runSweep(par);
par.MixSkillStrengths = false; rN = runSweep(par);
dS = rM.SDI - rN.SDI;
dP = (rM.meanstn - rN.meanstn) / pn;
ok = ~isnan(dS) & ~isnan(dP);
md = fitlm(dS(ok), dP(ok));
fprintf('dPerf ~ dSDI : R^2 = %.2f, slope = %.2f, n = %d\n', ...
    md.Rsquared.Ordinary, md.Coefficients.Estimate(2), sum(ok(:)));

f1 = figure('Position', [60 60 1000 400]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; pcolor(rM.DFD, rM.IFD, dS); shading flat; drawBS; cb = colorbar; ylabel(cb, '\Delta SDI');         title('A  Skill-coverage difference'); axlab
nexttile; pcolor(rM.DFD, rM.IFD, dP); shading flat; drawBS; cb = colorbar; ylabel(cb, '\Delta Performance'); title('B  Performance difference');     axlab
exportgraphics(f1, fullfile(figdir, 'SDIdiff.png'), 'Resolution', 150); exportgraphics(f1, fullfile(figdir, 'SDIdiff.pdf')); close(f1)

f2 = figure('Position', [60 60 560 470]);
x = dS(ok); y = dP(ok); plot(x, y, '.', 'MarkerSize', 10); hold on
xx = linspace(min(x), max(x), 100)'; plot(xx, predict(md, xx), 'r-', 'LineWidth', 2); grid on
xlabel('\Delta SDI  (coverage difference, mixed - non-mixed)'); ylabel('\Delta Performance');
title(sprintf('\\tau = 90%%, scheme 2:   R^2 = %.2f', md.Rsquared.Ordinary));
exportgraphics(f2, fullfile(figdir, 'SDI_scatter.png'), 'Resolution', 150); exportgraphics(f2, fullfile(figdir, 'SDI_scatter.pdf')); close(f2)
fprintf('saved SDIdiff and SDI_scatter\n');

%% (2) Robustness across communication threshold tau and cost kappa  (scheme 2)
TAUS = 50:10:100; KAPPAS = [5 25 50];
if QUICK; TAUS = [50 75 100]; KAPPAS = [5 50]; end
R2 = NaN(numel(TAUS), numel(KAPPAS)); SDIcoef = R2; SDIp = R2;
fprintf('\n===== Robustness sweep (tau x kappa, scheme 2) =====\n');
for jk = 1:numel(KAPPAS)
    for it = 1:numel(TAUS)
        par = base; par.DFDvec = MT_DFD; par.similThresh = TAUS(it); par.passCost = KAPPAS(jk);
        par.MixSkillStrengths = true;  a = runSweep(par);
        par.MixSkillStrengths = false; b = runSweep(par);
        ds = a.SDI - b.SDI; dp = (a.meanstn - b.meanstn) / pn;
        ok2 = ~isnan(ds) & ~isnan(dp); m = fitlm(ds(ok2), dp(ok2)); R2(it, jk) = m.Rsquared.Ordinary;
        IFD = [a.IFD(:); b.IFD(:)]; DFD = [a.DFD(:); b.DFD(:)];
        SDI = [a.SDI(:); b.SDI(:)]; Pf = [a.meanstn(:); b.meanstn(:)] / pn;
        okp = ~isnan(IFD) & ~isnan(DFD) & ~isnan(SDI) & ~isnan(Pf);
        T = table(IFD(okp), DFD(okp), SDI(okp), Pf(okp), 'VariableNames', {'IFD', 'DFD', 'SDI', 'Perf'});
        mm = fitlm(T, 'Perf ~ IFD + DFD + SDI'); iS = strcmp(mm.CoefficientNames, 'SDI');
        SDIcoef(it, jk) = mm.Coefficients.Estimate(iS); SDIp(it, jk) = mm.Coefficients.pValue(iS);
        fprintf('tau=%3d  kappa=%2d : R2(dPerf~dSDI)=%.2f   partial SDI coef=%+.2f (p=%.0e)\n', ...
            TAUS(it), KAPPAS(jk), R2(it, jk), SDIcoef(it, jk), SDIp(it, jk));
    end
end

mk = {'o-', 's-', '^-'};
f3 = figure('Position', [60 60 1000 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; hold on
for jk = 1:numel(KAPPAS)
    plot(TAUS, R2(:, jk), mk{min(jk, 3)}, 'LineWidth', 1.6, 'DisplayName', sprintf('\\kappa = %d', KAPPAS(jk)));
end
grid on; ylim([0 1]); xlabel('Communication threshold \tau (%)'); ylabel('R^2 of  \DeltaPerformance \sim \DeltaSDI');
title('A  Coverage explains the performance gap'); legend('Location', 'northwest')
nexttile; hold on
for jk = 1:numel(KAPPAS)
    plot(TAUS, SDIcoef(:, jk), mk{min(jk, 3)}, 'LineWidth', 1.6, 'DisplayName', sprintf('\\kappa = %d', KAPPAS(jk)));
    ns = SDIp(:, jk) >= 0.05; if any(ns); plot(TAUS(ns), SDIcoef(ns, jk), 'kx', 'MarkerSize', 10, 'HandleVisibility', 'off'); end
end
yline(0, 'k--', 'HandleVisibility', 'off'); grid on
xlabel('Communication threshold \tau (%)'); ylabel('partial SDI coefficient on performance');
title('B  SDI contribution beyond IFD, DFD  (\times = n.s.)'); legend('Location', 'northwest')
exportgraphics(f3, fullfile(figdir, 'SDI_robustness.png'), 'Resolution', 150); exportgraphics(f3, fullfile(figdir, 'SDI_robustness.pdf')); close(f3)
fprintf('saved SDI_robustness\nDONE Fig_SDI\n');

%% ---------- local functions ----------
function drawBS
    hold on
    line([0.27 0.27], [0 1], 'Color', 'r', 'LineWidth', 1.2); line([0.92 0.92], [0 1], 'Color', 'r', 'LineWidth', 1.2);
    line([0 1], [0.12 0.12], 'Color', 'r', 'LineWidth', 1.2); line([0 1], [0.51 0.51], 'Color', 'r', 'LineWidth', 1.2);
end
function axlab
    xlabel('Dominant Function Diversity'); ylabel('Individual Functional Diversity');
end
