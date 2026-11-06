# text-to-cad → COMSOL geometry handoff

## Choose the geometry route

| Situation | Route |
| --- | --- |
| Simple primitives, 2D, or axisymmetric physics | Build geometry directly with the installed COMSOL Java API. |
| Complex 3D parts, assemblies, or geometric variants | Generate parametric CAD with the installed CAD skill or the standalone runtime below, export STEP, then import in COMSOL. |
| Existing STEP from another CAD tool | Inspect the saved geometry, then start at COMSOL import. |

Use the installed `text-to-cad:cad` skill's current interface when available. Its source is [earthtojake/text-to-cad](https://github.com/earthtojake/text-to-cad). The plugin is optional: this skill can generate CAD with the standalone runtime below. Honor the user's selected geometry route.

## Standalone CAD runtime (agent-operated)

Resolve an available `uvx` and run commands from the project root. Keep caches and generated artifacts in the host-approved project/cache locations. These are commands for the agent to execute, not instructions to hand back to the user.

```powershell
uvx --no-config --managed-python --python 3.13 --from cadgen==0.7.15 python src/part.py
```

A minimal `src/part.py`:

```python
from cadgen import build123d as bd, step

WIDTH_MM = 40.0

@step(out="../STEP/part.step")
def part():
    body = bd.Box(WIDTH_MM, 20.0, 6.0)
    body.label = "solid"
    return body

if __name__ == "__main__":
    part()
```

Use millimeters and XY/+Z unless the project specifies another convention. Decorator output paths are relative to the source script. Keep dimensions in ordinary Python parameters/factory functions; preserve separate solid and fluid domains where needed. Read existing CAD with `cadgen.read_step` rather than reading a model's own generated output back into that model.

If `uvx` is absent, resolve an existing suitable Python/uv installation or prepare a project-local environment containing `cadgen==0.7.15` for Python 3.13. Use the existing package manager and host permissions; do not replace global Python or COMSOL. Stop at a concrete dependency/permission blocker if no permitted setup is available.

Before importing, inspect the saved STEP with `cadgen.read_step` or `cadgen.read_scene`, check dimensions/volume, and render a review image:

```powershell
uvx --no-config --managed-python --python 3.13 --from cadgen==0.7.15 cadgen step snapshot STEP/part.step tmp/part-review.png
```

Read that image yourself and correct geometry errors before COMSOL import. If snapshot rendering is unavailable, state that visual review was not completed and retain numerical geometry checks. First use may fetch the managed runtime and rendering dependencies; later runs reuse them.

## Reproducible handoff

1. **Define geometry and physics together.** Record dimensions, units, axes, origin, participating solids, material domains, and the intended inlet/outlet/heated/contact surfaces. Distinguish the manufactured part from the simulation domain: fluid passages need fluid volumes, external flow needs a surrounding domain, and thermal or acoustic coupling may require both solids and fluids.
2. **Generate and verify CAD.** Keep editable parametric Python source with STEP output. Use the installed CAD skill's contract or the standalone runtime above. Validate the saved STEP's closed solids, dimensions, volume and bounding box, then render and inspect it under that skill's review rules. Use STEP as the solid-geometry handoff; mesh-only exports need a separately justified import route.
3. **Import into the selected COMSOL release.** Check the required CAD import and physics licenses. Import using an absolute STEP path, explicitly set/check geometry units, and choose union versus assembly according to the physics. Preserve material interfaces or configure pairs where the model needs them. Compare imported dimensions, volumes and domain counts against the CAD contract before meshing.
4. **Rebuild semantic selections and physics.** Define named selections such as `fluid`, `shell`, `inlet`, `outlet` and `heated_outer` with geometric rules, adjacency or supported import-generated selections. Assert dimensions, counts, areas/volumes and locations. CAD viewer face references, labels and numeric IDs are not COMSOL entity IDs and are not assumed to survive regeneration. Assign materials and boundary conditions only after these checks.
5. **Run a small solve before scaling up.** Compile with the selected release, require a newly generated class file, solve one frequency or a short time interval, export nonempty numerical data, and check a physical invariant. Then run the requested study and convergence checks. Rebuild geometry, selections and mesh after a parameter change; do not reuse results from a previous geometry.

## Shared parameters and provenance

Keep one authoritative parameter source in the project. A small JSON file is suitable when both Python CAD and Java COMSOL need the same dimensions; each implementation must explicitly read or derive values from it. The existing scaffold does not automatically synchronize CAD and COMSOL parameters.

A compact handoff record should contain the STEP path and SHA-256, CAD source and parameter hashes, length unit, coordinate convention, expected solids/domains, bounding box and volumes, semantic selection rules, and the selected COMSOL version. STEP alone does not define materials, governing equations, boundary conditions or numerical acceptance criteria.

For example, a multi-part cooler handoff describes the copper solid and the extracted coolant volume separately; an `inlet` rule identifies the coolant face at a specified coordinate and verifies its area. A change to the channel width regenerates the STEP, rechecks the fluid volume, rebuilds inlet/outlet selections and remeshes before solving.

## Existing executable check

On Windows, `scripts/test_cad_comsol_acoustics.ps1` already exercises cadgen → STEP → COMSOL import → a 200 Hz acoustic solve → CSV/physical checks. Use the same environment checks from [the Windows CAD reference](cad-comsol-windows.md).

This probe is a straight-duct environment test, not a general CAD-to-physics converter and not evidence that a new physics setup is correct. It requires its configured acoustic/CAD-import modules. Heat transfer, structural mechanics and other models need their own minimal physics/export check.

The CAD workflow may use the CAD viewer for inspection; this does not require launching the COMSOL GUI.
