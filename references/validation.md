# Numerical Validation and Postprocessing

## Acceptance hierarchy

Check in this order:

1. **Execution:** compilation succeeds; batch log has no fatal exception; completion marker exists.
2. **Artifacts:** MPH, raw tables, fields, summary, and required metadata exist and are nonempty.
3. **Geometry:** selected entity dimensions, counts, volumes, areas, and locations match the model contract.
4. **Bounds:** temperature and phase fraction are finite and physically bounded within documented numerical tolerance.
5. **Direction and symmetry:** profiles follow the expected heating/melting direction and geometric symmetries.
6. **Conservation:** energy, mass, or flux balances close within the target tolerance.
7. **Convergence:** reported observables are stable under mesh/time-step/tolerance refinement.
8. **Visual QA:** plots use correct domains, coordinates, units, color limits, labels, and time/progress annotations.

Do not lower a tolerance until the discrepancy has been diagnosed.

## Minimum raw outputs

Export enough data to validate without reopening the GUI:

- study times and solver settings;
- spatial coordinates and fields at selected states;
- domain averages/integrals;
- boundary fluxes and extrema;
- geometry measures;
- event or crossing times such as `t10`, `t50`, and `t90`;
- an explicit parameter/summary table;
- a completion marker created last.

Use CSV headers with variable names and units. Keep plotting scripts deterministic and separate from the solver source.

## Validator design

Write a project-specific validator that exits nonzero on failure and writes a text report. Print metrics before pass/fail labels so tolerances can be audited. Include checks for missing or stale snapshots.

For a uniformly heated spherical PCM capsule, typical initial checks are:

```text
outer surface temperature spread      <= mesh-scaled tolerance
axis/equator temperature difference   <= mesh-scaled tolerance
north/south temperature difference    <= mesh-scaled tolerance
axis/equator liquid-fraction difference <= phase-scaled tolerance
minimum outward temperature step      >= small negative tolerance
minimum outward liquid-fraction step  >= small negative tolerance
minimum time liquid-fraction step     >= small negative tolerance
energy balance error                  <= 0.05 initially
volume and area relative errors       <= geometry tolerance
```

Treat these as starting points, not universal constants.

## Convergence table

Run at least baseline and refined cases. Record:

```text
case, elements, max_dt, rtol, t10, t50, t90, center_T_final,
liquid_fraction_final, energy_error, runtime
```

Accept a result only when the observables relevant to the user's claim change less than the declared convergence threshold.

## Plotting rules

- Reconstruct a full cross-section from axisymmetric half-plane data only by a documented mirror operation.
- Use one shared color range when comparing time snapshots.
- Mask fields outside their physical domain.
- Show actual time and, for phase change, average liquid-fraction progress.
- Check that the plotted melt direction agrees with radial profile data.
- Export vector PDF/SVG where possible and a high-resolution raster preview.

Inspect representative images after generation. A numerically valid CSV can still be plotted with swapped axes, stale files, wrong domains, or misleading independent color scales.
