# Windows CAD → COMSOL: tested rules

Verified 2026-10-06: COMSOL 6.3.0.290, cadgen 0.7.15, managed Python 3.13, uv 0.12.23. These are this machine's tested versions, not universal latest versions.

For general CAD/physics projects, first read [the text-to-cad handoff workflow](text-to-cad-integration.md).

## Cheap entry point

For acoustic CAD tasks run `scripts/test_cad_comsol_acoustics.ps1 -ProjectRoot <absolute writable project> -ComsolBin <actual installation bin\win64>`. Omitting `-ComsolBin` uses the shared resolver instead of a fixed COMSOL63 path; use `-Force` for a fresh release check. It generates a small straight air duct, imports its STEP, solves 200 Hz, exports and checks the data. Logs remain in the project. An unchanged environment reuses a checked pass for up to 24 hours; `-Force` reruns it. A cached pass is not a promise that a license remains available. Use ordinary execution first; if the native importer cannot read an existing absolute STEP path, use the host's approval mechanism for that exact preflight. Supply `-ExecutionContextTag native-approved` only when actually executing under that approval; standard and approved runs have separate cache keys. This does not authorize unrelated escalation or security changes.

## Known local environment

- COMSOL bin: `<COMSOL_BIN>` — the `Multiphysics\bin\win64` directory of your install selected with `scripts/resolve_comsol.ps1`, `-ComsolBin`, or `COMSOL_BIN`. Do not assume a particular drive or release exists. Acoustics and CAD Import were available on the reference machine, but verify rather than assume future license availability.
- uvx: `%USERPROFILE%\.local\bin\uvx.exe`.
- `UV_PYTHON_INSTALL_DIR=%USERPROFILE%\.local\share\uv\python` avoids the observed agent-sandbox Windows app-redirection problem. Use a process-local value in runners; don't rewrite user environment during every task.

## Proven fixes

| Symptom | First check / fix |
| --- | --- |
| uv missing expected Python directory | Check the managed Python installation folder and version link; use the tested nonredirected folder. |
| Native STEP import says file not found | Verify an absolute file path in the actual execution context. An absolute-path rewrite alone did not resolve this host's sandbox restriction; an approved native run did. |
| Successful solve but empty CSV | After solving explicitly set the result node's `data` to the actual solution dataset tag, such as `dset1`; assert row count and finite values before writing completion. Do not assume every model uses dset1. |
| `results/results/...` | Loading an MPH changes modelPath; use an injected absolute root for every import/save/export. |
| Plot length wrong by 1000× | Read CSV units for coordinates and expressions separately; do not convert mm as if it were m. |

## Reuse and cost controls

If you already have one working acoustic project, keep it as the reference. For side-branch acoustics reuse its port API, dataset handling, exports and validator; parameterize new geometry and rebuild selections. Do not copy its geometry dimensions or ideal-loss assumptions into a different task without checking intent.

Start with one frequency and a nonempty export, then coarse sweep, local fine sweep, and refinement. This catches export issues before the expensive scan. The previous solve took 471 s for three scans; reading or solving its 218 MB MPH is unnecessary for a routine environment check. Keep logs on disk and print a short status/error tail instead of streaming thousands of progress lines. Reuse numerical results only when geometry, physics, mesh, study and runtime provenance match; an old marker alone is insufficient.

The small acoustic preflight uses an explicit FreeTet mesh. Creating a physics-controlled acoustic mesh before its frequency study is configured produced "Cannot determine maximum element size; mesh is not used in any study" on this version.

For narrow resonances, separate frequency sampling from mesh convergence. For lossless equal-area ports verify R+T≈1; a reflection peak is not absorption or real product performance.
