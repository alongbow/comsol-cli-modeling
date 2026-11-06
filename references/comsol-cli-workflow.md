# COMSOL Java and CLI Workflow

## Project contract

Use this layout unless the existing repository already has a coherent convention:

```text
project/
  ModelName.java
  run_comsol.ps1
  .comsol-cli-prefs/comsol.prefs
  results/                 raw COMSOL outputs, MPH, CSV, log, marker
  figures/                 publication or report figures
  validate_results.py      project-specific numerical acceptance tests
```

Keep a single authoritative run entry point. Derive PowerShell paths from the runner location and inject that absolute root into the Java source. Avoid Java calls that require blocked system-property permissions. Use absolute paths for geometry imports, model saves and result exports: loading or saving an MPH can change modelPath, making relative result paths duplicate directory segments. For Windows STEP integration, use references/cad-comsol-windows.md.

## Discover the installation

Dot-source `scripts/resolve_comsol.ps1` and call `Resolve-ComsolBin`. Both executables must come from one `bin\win64` directory. Selection order: runner `-ComsolBin` → `COMSOL_BIN` → scaffold-saved path → discovery through PATH, Windows registry `COMSOLROOT`, and common installation directories. Invalid explicit paths fail visibly. Multiple discovered installations require an explicit choice.

## Version compatibility and 6.4 reports

COMSOL 6.4 documents `comsolcompile`, `comsolbatch -inputfile <class>`, `-prefsdir`, and `-version`. Compiling Java model source is distinct from packaging standalone applications with COMSOL Compiler. Physics/CAD licenses must still match the model.

Official references: [6.4 Windows commands](https://doc.comsol.com/6.4/doc/com.comsol.help.comsol/comsol_ref_running.38.31.html), [compiled Java batch models](https://doc.comsol.com/6.4/doc/com.comsol.help.comsol/comsol_api_intro.46.11.html), [programming reference and registry lookup](https://doc.comsol.com/6.4/doc/com.comsol.help.comsol/COMSOL_ProgrammingReferenceManual.pdf).

The previous CAD preflight defaulted to COMSOL63. This was a portability defect; it does not establish the cause of a report without logs.

1. Generate a fresh geometry-only scaffold. Run `run_comsol.ps1 -ComsolBin '<actual 6.4 bin\win64>' -Diagnose` and inspect `results/comsol_environment.json` and `comsol_version.log`.
2. Run the unmodified scaffold with the same installation. On failure, inspect `compile.log`, `comsol_stdout.log` and `comsol_batch.log`. The runner uses project-local startup/configuration directories.
3. For CAD/acoustics, run the preflight with the same `-ComsolBin` and `-Force`. Diagnose missing licenses, import failures and physics/API errors separately.
4. Recompile source with the selected release, check that release's exported Java/examples, and validate the target physics with a short solve.

Verification on 2026-11-07: local COMSOL 6.3.0.290 passed geometry-only compile/batch/MPH checks and resolver selection/error checks. 6.4 CLI syntax was checked against official documentation; no 6.4 runtime or release-specific physics/CAD validation was available. Existing generated runners must be regenerated or updated to receive these changes.

## Java model structure

Use small methods in this order:

```text
defineParameters
createGeometry
resolveAndAssertSelections
createMaterials
createPhysics
createOperators
createMesh
createStudyAndSolver
runStudy
exportRawData
exportSummary
exportImages
saveModel
writeCompletionMarker
```

Create all parameters with units and descriptions. Build the finalized geometry before asking for entity IDs. Prefer named selections produced by geometry features; otherwise detect entities using bounding boxes, coordinates, measures, adjacency, or material topology and assert the result.

Print a compact pre-solve audit containing domain IDs, boundary IDs, dimensions, measures, material assignments, study time range, mesh settings, and solver tolerances.

## API discovery order

1. Read the current project's working Java source.
2. Inspect Java exported from an MPH model created in the same COMSOL version.
3. Search the local COMSOL documentation and examples.
4. Compile a minimal change and use the exact compiler or batch error.
5. Change one API assumption at a time.

Do not invent feature types or property names from memory when compilation can verify them.

## Compile and batch gates

Run from the project root:

```powershell
& "$ComsolBin\comsolcompile.exe" ModelName.java
& "$ComsolBin\comsolbatch.exe" `
  -prefsdir .\.comsol-cli-prefs `
  -inputfile ModelName.class `
  -nosave -batchlogout `
  -batchlog .\results\comsol_batch.log
```

Do not infer completion only from the process exit code. Require a marker written by Java after the solve, required exports, and MPH save. On failure, retain the complete log and report its last useful exception chain.

`comsolcompile` is not exempt from that rule. Measured on COMSOL 6.3.0.290 / Windows: a source file with a syntax error printed `ERROR: Compilation failed` and still left `$LASTEXITCODE` at 0. Gate on the artifact, not the exit code — delete `ModelName.class` before compiling, capture the compile output to `results/compile.log`, and treat a missing class file afterwards as a failed compile. Otherwise a class file from an earlier good build is solved silently and the run reports success for source that no longer compiles.

Use a minimal preferences directory that grants only required file access. Keep network, external process, reflection, property, runtime, and socket permissions disabled unless the model demonstrably needs one and the user approves it.

## Iteration strategy

- First compile a geometry-only model and save an MPH smoke test.
- Add selections and print/assert their topology.
- Add materials and physics without solving.
- Solve a short or coarse study.
- Add full study settings and raw exports.
- Add project-specific validation.
- Perform mesh, time-step, and tolerance refinement.

When a long solve fails, reproduce the issue with the smallest geometry, shortest time range, or coarsest mesh that still fails. Preserve the production configuration separately.

## Output hygiene

Write only under a verified project result directory. Remove only known generated names before a rerun; stale progress snapshots can otherwise enter plots. Never remove user-authored data, arbitrary wildcard matches outside the result directory, or an entire computed directory without checking its resolved absolute path.
