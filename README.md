# COMSOL CLI Modeling

An **agent skill** that makes COMSOL Multiphysics work reproducible from the command line: build the model with the Java API, compile it, run it under `comsolbatch`, export machine-readable data, and pass validation gates — without opening the COMSOL GUI.

Point an agent at this folder and it stops guessing Java API property names, stops trusting hard-coded boundary IDs, and stops declaring a solve "successful" because a contour plot looked nice.

Works with any agent that reads `SKILL.md` — Codex CLI, Claude Code, or a harness that injects skill folders.

## Install

```bash
# Codex CLI
git clone https://github.com/alongbow/comsol-cli-modeling ~/.codex/skills/comsol-cli-modeling

# Claude Code
git clone https://github.com/alongbow/comsol-cli-modeling ~/.claude/skills/comsol-cli-modeling
```

Then ask your agent to build a COMSOL model, or reference the skill explicitly.

## What is in here

| Path | What it is |
| --- | --- |
| `SKILL.md` | The workflow: model contract → implement → compile gate → batch run → validate → deliver. Loaded by the agent. |
| `references/comsol-cli-workflow.md` | Locating the COMSOL install, project layout, Java API patterns, compile debugging, security prefs, reading batch completion. |
| `references/cad-comsol-windows.md` | Tested CAD → STEP → COMSOL import rules on Windows, plus a symptom → first-fix table for the failures that cost the most time. |
| `references/phase-change-axisymmetric.md` | PCM / shell-core / 2D axisymmetry checks: liquid-fraction direction, symmetry, monotonicity, energy balance. |
| `references/validation.md` | Gate order, tolerance selection, figure QA, what counts as convergence evidence. |
| `scripts/new_comsol_cli_project.ps1` | Scaffolds a runnable project: Java source, runner, prefs dir, `results/`, `figures/`. |
| `scripts/test_cad_comsol_acoustics.ps1` | Environment preflight: generates a small duct, imports its STEP, solves 200 Hz, exports CSV, asserts nonempty data. Caches a pass for 24 h keyed on a fingerprint of the environment. |
| `assets/*.template` | Templates the scaffold expands: model class, runner, prefs, acoustic preflight. |
| `agents/openai.yaml` | Display metadata for agents that surface skills in a menu. |

## Quick start

```powershell
# 1. Scaffold a project
powershell -ExecutionPolicy Bypass -File scripts/new_comsol_cli_project.ps1 `
  -ClassName CapsuleModel `
  -Destination C:\work\capsule-model `
  -ComsolBin "C:\Program Files\COMSOL\COMSOL63\Multiphysics\bin\win64"

# 2. Replace buildModel() in the generated Java — the template is a plumbing
#    smoke test, not a finished physical model.

# 3. Run it
cd C:\work\capsule-model && .\run_comsol.ps1
```

For CAD-driven work, preflight the environment before any long study:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test_cad_comsol_acoustics.ps1 `
  -ProjectRoot C:\work\acoustics-preflight
```

`-ComsolBin` defaults to the standard install root; point it at your own `Multiphysics\bin\win64` if COMSOL lives elsewhere.

## The rules that matter

The skill is opinionated because these are the failures that silently produce wrong results:

- **Compile before solving.** `comsolcompile` is the API-compatibility gate for the installed COMSOL version.
- **Geometry first, then selections — and assert them.** Boundary and domain IDs move when geometry changes. Name selections; assert counts, dimensions, measures, locations.
- **A completion marker is written only after every required export and the MPH save succeed.** Otherwise a partial run looks like a finished one.
- **Loading an MPH changes `modelPath`.** Use an injected absolute root for every import, save and export, or you get `results/results/...`.
- **Export CSV, not just pictures.** Images are never evidence; a solve with an empty CSV is a failed solve.
- **Check invariants before contour plots:** computed volume/area vs. analytic, axisymmetric weighting on, energy balance, monotonic liquid fraction, mesh/time-step sensitivity.
- **Keep failed logs.** Do not mix stale outputs into a new run.
- **Never launch the GUI** unless the user asks for it.

## Requirements

- COMSOL Multiphysics 6.x with `comsolcompile` and `comsolbatch` reachable (on `PATH` or via `-ComsolBin`). Physics coverage depends on your license — verify per machine rather than assuming a module is present.
- The bundled scripts are PowerShell and were developed on Windows. On Linux/macOS the workflow is identical; adapt the runner template's paths.
- Verified against COMSOL 6.3.0.290 on Windows. Versions named in the references are the ones that were actually tested, not the current latest.

## Provenance

Distilled from real engineering runs — 2D axisymmetric transient heat transfer with phase change, and CAD-to-STEP-to-COMSOL acoustic and conjugate-heat models — where each rule in the references came from a failure that had to be diagnosed once so it would not be repeated. Machine-specific paths and private project references have been replaced with placeholders.

## License

MIT
