# Agent-based model of functional diversity in management teams

MATLAB code accompanying *"Modeling the Effect of Functional Diversity in Management
Teams: An Agent-Based Approach."* The model represents managers as normalized skill
vectors and tasks as bundles of functional requirements, and studies how intrapersonal
functional diversity (IFD), dominant-function diversity (DFD), skill coverage (the Skill
Diversity Index, SDI), and the communication regime shape team communication and performance.

## Requirements
- MATLAB (developed and tested on R2022b).
- Statistics and Machine Learning Toolbox (for `fitlm`).
- Parallel Computing Toolbox (optional; scripts use `parfor` — they still run without it,
  just serially).

## Layout
```
Functions/        backend (model + analysis); added to the path by each script
FigureScripts/    one script per paper figure group; run these
figures/          output (created on first run)
```

## How to run
Each figure script is self-contained: it adds `Functions/` to the path and writes PNG and
PDF output into `figures/`. From the `FigureScripts/` folder (or with it on the path):

```matlab
Fig_SpecialistsGeneralists      % specialists/generalists surfaces
Fig_MixedTeam                   % diverse-team surfaces + Table tab:fit regressions
Fig_MissingExpertise            % missing-expertise illustration + Table tab:fitnonmix
Fig_SDI                         % SDI difference maps, scatter, and robustness
```

For a fast smoke test (coarser IFD grid, fewer repeats), set `QUICK` first in the same session:

```matlab
QUICK = true; Fig_MixedTeam
```

Paper-quality output uses the default settings (`QUICK = false`). `Fig_SDI` with paper
settings runs a full tau x kappa sweep and can take tens of minutes; the others run in
about a minute each.

## Figure / table → script map
| Paper item | Script | Notes |
|---|---|---|
| Fig. *specgen*, Fig. *comsg2* | `Fig_SpecialistsGeneralists.m` | GenAgent Method 2; conditions `specgen_B` (tau 80%, scheme 1), `specgen_C` (tau 100%), `comsg2` (tau 80%, scheme 2) |
| Fig. *lackcomm*, Table *tab:fit* | `Fig_MixedTeam.m` | GenAgent Method 3, mixed skills, tau 60%, kappa 5; both communication schemes |
| Fig. *missskill*, Table *tab:fitnonmix* | `Fig_MissingExpertise.m` | two example teams (IFD 0.65, DFD 0.79) + non-mixed regression |
| Fig. *sdidiff*, Fig. *sdiscatter*, Fig. *sdirobust* | `Fig_SDI.m` | mixed vs non-mixed at matched IFD/DFD; difference maps, scatter, tau×kappa robustness |

The schematic figures (`TaskAgTeam`, `ModelDynamics`, `CommSchemes`) are conceptual diagrams
drawn by hand and are **not** produced by code.

## Key parameters (defaults match the paper, Table tab:params)
`numfuncs` = 9, `numagents` = 10, `numtasks` = 7, `anorm` (ω) = 10, `tnorm` (Θ) = 10,
similarity threshold `tau` = 60%, communication cost `kappa` = 5, agent-generation method
`nu` = "IFDS distribution" (Method 3), IFDS spread `delta` = 5, passing scheme `pi` = pass-if-stuck,
instances per point `l` = 10, max steps `M` = 250. `passVersion` 2 = scheme 1 (pass when stuck),
`passVersion` 1 = scheme 2 (repeatedly seek the best collaborator). `MixSkillStrengths`
(`mu`) True = good coverage, False = missing expertise.

## Backend entry points
- `GenAgent.m` — build the agent skill matrix (Methods 2 and 3 used here).
- `GenTask.m` — generate task requirement vectors.
- `PassingSolveTasks.m` — the stepping loop; dispatches to `passTasks_v2` / `passTasks_v4`.
- `CalcFD.m` — compute DFD, IFD, IFDS, and SDI from an agent matrix.
- `runSweep.m` — sweep the IFD-DFD plane and return the diversity/outcome grids used by the figure scripts.

Results are reproducible: each sweep calls `rng('default')` before generating agents/tasks.
