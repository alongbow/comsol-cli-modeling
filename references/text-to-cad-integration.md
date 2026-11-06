# text-to-cad → COMSOL geometry handoff

## Choose the geometry route

| Situation | Route |
| --- | --- |
| Simple primitives, 2D, or axisymmetric physics | Build geometry directly with the installed COMSOL Java API. |
| Complex 3D parts, assemblies, or geometric variants | Use the available text-to-cad CAD skill, export STEP, then import in COMSOL. |
| Existing STEP from another CAD tool | Inspect the saved geometry, then start at COMSOL import. |

Use the installed `text-to-cad:cad` skill's current interface when available. Its source is [earthtojake/text-to-cad](https://github.com/earthtojake/text-to-cad). Do not silently install a plugin or switch the user's geometry route. Without that skill, use an existing STEP file or COMSOL-native geometry as appropriate.

## Reproducible handoff

1. **Define geometry and physics together.** Record dimensions, units, axes, origin, participating solids, material domains, and the intended inlet/outlet/heated/contact surfaces. Distinguish the manufactured part from the simulation domain: fluid passages need fluid volumes, external flow needs a surrounding domain, and thermal or acoustic coupling may require both solids and fluids.
2. **Generate and verify CAD.** Keep editable parametric Python source with STEP output. Use the CAD skill's pinned runtime and source-generation contract. Validate the saved STEP's closed solids, dimensions, volume and bounding box, then render and inspect it under that skill's review rules. Use STEP as the solid-geometry handoff; mesh-only exports need a separately justified import route.
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
