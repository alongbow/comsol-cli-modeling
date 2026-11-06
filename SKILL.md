---
name: comsol-cli-modeling
description: Build, repair, run, and validate COMSOL models with the Java API and CLI, including text-to-cad/STEP geometry handoff, acoustics, heat transfer and phase change. Use for COMSOL建模、CAD导入COMSOL、批处理求解、MPH创建、仿真验证 and solver or export debugging.
---

# COMSOL CLI Modeling

Build a reproducible CLI project that creates the model, solves it, exports raw data, validates physics, and records completion without relying on the COMSOL GUI.

## Start from the user's modeling request

This is a Git-installable, self-contained agent skill. The user installs the repository into their agent's skill directory and describes a modeling task; carry out the setup and modeling work yourself.

- Find COMSOL and its version, check the task's modules, create the project, and run the relevant short checks with tools. Do not turn these agent tasks into a setup checklist for the user.
- Resolve paths automatically first. If several releases are installed, honor the requested version or existing working project configuration; ask one short version question only when the choice remains ambiguous. Do not require the user to set `COMSOL_BIN` as routine onboarding.
- For CAD generation, use the installed text-to-cad skill when available, or the bundled standalone cadgen instructions in [the CAD reference](references/text-to-cad-integration.md). A separate plugin installation is not required.
- Reuse available dependencies. Prepare missing task-specific open-source CAD dependencies in a project-local environment or managed tool cache, respecting host permissions and storage rules; keep COMSOL and existing global software installations unchanged.
- Ask only for scientific inputs that materially change the model or for a blocker you cannot resolve, such as missing COMSOL/modules or a host approval. Otherwise continue through modeling, export and validation.

## Core workflow

1. Inspect the workspace, COMSOL installation, version, licensed modules, existing Java source, scripts, logs, and user changes. Resolve the installed release with `scripts/resolve_comsol.ps1`; use an explicit installation when multiple versions exist.
2. Write a model contract before coding: geometry, dimensions, materials, governing physics, assumptions, initial and boundary conditions, study type, outputs, and numerical acceptance criteria.
3. For a new project, run `scripts/new_comsol_cli_project.ps1`. Keep source, raw results, figures, logs, and validation reports in separate paths.
4. Implement the Java model in small methods: parameters, geometry, selections, materials, physics, operators, mesh, study, exports, and summary.
5. Compile with `comsolcompile` before starting a solve. Treat compilation as the API compatibility gate for the installed COMSOL version — but gate on the produced class file, not the exit code: `comsolcompile` was measured printing `ERROR: Compilation failed` while still returning 0, which leaves a stale class file to be solved and reported as success.
6. Run with `comsolbatch`, a dedicated preferences directory, a batch log, and a completion marker written only after all required exports and the MPH save succeed.
7. Validate geometry selections and numerical invariants before judging contour plots. Never declare success from images alone.
8. Refine mesh, time step, and solver tolerance when validation or convergence checks fail. Preserve failed logs and do not mix stale outputs into a new run.
9. Deliver the exact run command, output locations, assumptions, validation status, and any checks that were not run.

## Geometry route and text-to-cad integration

Use COMSOL-native geometry for simple primitives, 2D and axisymmetric models. For complex 3D parts, assemblies, or repeated geometric variants, create and inspect parametric solids using the available `text-to-cad:cad` skill or the bundled standalone CAD route, then import STEP through the COMSOL Java API. Existing STEP files can enter at the import stage. Read [the geometry handoff workflow](references/text-to-cad-integration.md) for parameter ownership, units, simulation domains, selection rebuilding and acceptance checks. CAD supplies geometry; materials, physics, boundary conditions, mesh and studies are configured in COMSOL.

## CAD import and repeat runs

For text-to-cad/STEP to COMSOL on Windows, read [tested integration rules](references/cad-comsol-windows.md) before coding. Reuse the installed-version examples and environment checks there instead of rediscovering known errors. The acoustic preflight script tests the CAD runtime, native STEP importer, ports, a one-frequency solve and nonempty data export; it caches a pass only for an unchanged environment. A new physics configuration still needs its own one-frequency/short-time export check before a long study.

## Non-negotiable rules

- Prefer the installed version's existing project code, locally generated Java, local documentation, examples, and compiler feedback over guessed Java API properties.
- Parameterize physical values with COMSOL units. Do not bury dimensional constants in expressions.
- Build geometry before resolving entity selections. Name selections and assert their dimensions, counts, measures, and locations.
- Do not trust hard-coded boundary or domain IDs after geometry changes. Detect entities from geometry or create stable named selections from geometry features.
- Apply a full-surface heating condition to every entity of that surface. A single arc or point source is not equivalent.
- In 2D axisymmetry, enable axisymmetric weighting for averages and integrals and compare computed volumes and surface areas with analytic values.
- Scope phase fraction and latent heat to the PCM domain. Mask undefined phase variables outside that domain in exports.
- Distinguish conduction-only melting from melting with liquid convection. Do not silently claim convection when velocity is fixed to zero.
- Export machine-readable CSV data and a compact summary in addition to an MPH file and images.
- Use progress-based snapshots for phase change when uniform-time snapshots hide the melt front.
- Clean only known generated files under the verified project result directory. Never recursively clean a computed or unverified path.
- Do not launch the GUI unless the user explicitly asks for it.

## Phase-change and axisymmetric tasks

Read `references/phase-change-axisymmetric.md` before implementing or reviewing a PCM capsule, spherical particle, shell-core geometry, liquid-fraction field, or outside-in melting claim.

Require at minimum:

- complete outer boundary selection;
- PCM and shell domain separation;
- radial temperature and liquid-fraction direction checks;
- north-south and axis-equator symmetry checks when spherical symmetry is expected;
- monotonic average liquid fraction during continuous heating;
- core volume, shell volume, outer area, and energy-balance checks;
- mesh/time-step sensitivity near the phase-change interval.

## CLI implementation details

Read `references/comsol-cli-workflow.md` when locating COMSOL, scaffolding a project, selecting a Java API pattern, debugging compilation, setting security preferences, or interpreting batch completion.

Agent implementation example (run this yourself after resolving the project location):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_comsol_cli_project.ps1 `
  -ClassName CapsuleModel `
  -Destination C:\work\capsule-model
```

Omitting `-ComsolBin` uses automatic discovery. When an explicit installation is needed, pass its actual `Multiphysics\bin\win64` directory yourself; `COMSOL_BIN` is an optional override. The generated runner accepts `-ComsolBin` to override a saved path and `-Diagnose` to record version/path information without compiling or solving. See the version compatibility section in `references/comsol-cli-workflow.md` for 6.4 reports.

The generated Java file is a plumbing smoke test, not a finished physical model. Replace `buildModel` while preserving output and completion behavior.

## Validation and delivery

Read `references/validation.md` before accepting results, writing a validator, selecting tolerances, producing figures, or reporting convergence.

Use independent gates:

1. source and script syntax;
2. Java compilation;
3. batch completion marker and required files;
4. geometry/selection checks;
5. physical invariants and conservation;
6. mesh/time-step convergence;
7. visual QA of fields and plots.

If any required gate is not run, state that explicitly. Keep the final response short and link directly to the runnable source, runner, validation report, and main outputs.
