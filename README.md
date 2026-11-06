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
| `references/text-to-cad-integration.md` | Geometry routing, shared parameters, STEP handoff, simulation domains and semantic selections. |
| `scripts/resolve_comsol.ps1` | Shared Windows installation discovery and explicit version selection. |
| `references/cad-comsol-windows.md` | Tested CAD → STEP → COMSOL import rules on Windows, plus a symptom → first-fix table for the failures that cost the most time. |
| `references/phase-change-axisymmetric.md` | PCM / shell-core / 2D axisymmetry checks: liquid-fraction direction, symmetry, monotonicity, energy balance. |
| `references/validation.md` | Gate order, tolerance selection, figure QA, what counts as convergence evidence. |
| `scripts/new_comsol_cli_project.ps1` | Scaffolds a runnable project: Java source, runner, prefs dir, `.gitignore`, `results/`, `figures/`. |
| `scripts/test_cad_comsol_acoustics.ps1` | Environment preflight: generates a small duct, imports its STEP, solves 200 Hz, exports CSV, asserts nonempty data. Caches a pass for 24 h keyed on a fingerprint of the environment. |
| `assets/*.template` | Templates the scaffold expands: model class, runner, prefs, acoustic preflight. |
| `agents/openai.yaml` | Display metadata for agents that surface skills in a menu. |

## text-to-cad integration

Use text-to-cad for complex 3D geometry and COMSOL for the simulation:

**Natural-language dimensions → parametric CAD → verified STEP → COMSOL import → named selections → physics/mesh/study → validated data.**

Simple 2D, axisymmetric and primitive geometry can stay inside COMSOL. CAD and COMSOL share a geometry contract for parameters, units, coordinate axes and domain roles. Rebuild and verify selections after every geometry change; CAD face IDs are not COMSOL boundary IDs. A fluid simulation also needs the fluid volume, not only the manufactured solid.

Read [the integration workflow](references/text-to-cad-integration.md). The existing acoustic preflight already exercises the CAD-to-STEP-to-COMSOL path for a small duct; it is an environment probe, not an automatic converter for arbitrary physics. The general handoff workflow is new guidance; no generic CAD/physics converter is added.

## Quick start

```powershell
# 1. Set COMSOL_BIN to the actual installation's Multiphysics\bin\win64.
#    Alternatively, omit -ComsolBin for automatic discovery.
#    Scaffold a project
powershell -ExecutionPolicy Bypass -File scripts/new_comsol_cli_project.ps1 `
  -ClassName CapsuleModel `
  -Destination C:\work\capsule-model `
  -ComsolBin $env:COMSOL_BIN

# 2. Replace buildModel() in the generated Java — the template is a plumbing
#    smoke test, not a finished physical model.

# 3. Run it
Set-Location C:\work\capsule-model
.\run_comsol.ps1 -Diagnose
.\run_comsol.ps1
```

For CAD-driven work, preflight the environment before any long study:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test_cad_comsol_acoustics.ps1 `
  -ProjectRoot C:\work\capsule-model `
  -ComsolBin $env:COMSOL_BIN -Force
```

Both the generated runner and CAD preflight use a shared resolver. Selection order: runner `-ComsolBin` → `COMSOL_BIN` → scaffold-saved path → PATH, registry and common directories. Multiple installations require an explicit choice. Invalid explicit paths fail rather than silently switching releases.

For a 6.4 report, run `run_comsol.ps1 -ComsolBin '<actual 6.4 bin\win64>' -Diagnose` first. Send `results/comsol_environment.json` and the first failing compile/batch log. COMSOL 6.4 command syntax was checked against its official documentation; **6.4 has not been runtime-tested here**. Existing generated projects need their runners regenerated or updated.

The scaffold also writes a `.gitignore` covering `*.class`, `*.mph`, `*.log` and `results/` — a solved MPH runs to hundreds of MB, and a stray class file is a correctness hazard, not just noise.

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

## Verified behaviour

Measured on a real COMSOL 6.3.0.290 install (Windows, PowerShell 5.1), not asserted:

- The generated project's Java passes `comsolcompile` unchanged, and `run_comsol.ps1` drives the whole loop: compile → `comsolbatch` → MPH save → completion marker → results listing.
- A source file that fails to compile stops the run **even when a stale class file is planted in the project directory**. `comsolcompile` returns exit code 0 after printing `ERROR: Compilation failed`, so the gate is the class file the compiler produced, and `results/compile.log` keeps the compiler output. In that state the batch step never starts.
- A failed run leaves no completion marker and no MPH; the runner exits non-zero instead of reporting success.
- A stale marker is deleted before each run, so a previous success cannot be reused as this run's evidence.
- The scaffold refuses a non-empty destination directory and a class name that is not a valid Java identifier.

The 2026-11-07 update additionally checks installation selection, version diagnostics and project-local startup paths on COMSOL 6.3.0.290. No new 6.4 runtime or general CAD-to-physics validation is claimed.

That second bullet is the reason this skill exists in scripted form: the exit code lied, and the only honest signal was the artifact.

## Requirements

- COMSOL Multiphysics 6.x with `comsolcompile` and `comsolbatch` reachable (on `PATH` or via `-ComsolBin`). Physics coverage depends on your license — verify per machine rather than assuming a module is present.
- The bundled scripts are PowerShell and were developed on Windows. On Linux/macOS the workflow is identical; adapt the runner template's paths.
- Verified against COMSOL 6.3.0.290 on Windows. Versions named in the references are the ones that were actually tested, not the current latest.

## Provenance

Distilled from real engineering runs — 2D axisymmetric transient heat transfer with phase change, and CAD-to-STEP-to-COMSOL acoustic and conjugate-heat models — where each rule in the references came from a failure that had to be diagnosed once so it would not be repeated. Machine-specific paths and private project references have been replaced with placeholders.

## License

MIT
