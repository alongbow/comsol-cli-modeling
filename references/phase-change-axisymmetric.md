# Phase Change in 2D Axisymmetry

## Modeling decision

State which level is being modeled:

- **Conduction plus latent heat:** solve heat transfer with an apparent heat-capacity or enthalpy formulation and set fluid velocity to zero. This is the preferred first model for a micrometer capsule when buoyancy is negligible.
- **Melting with liquid convection:** couple nonisothermal flow, momentum damping in the mushy zone, gravity, and appropriate fluid properties. This is a different model and needs stronger convergence testing.

Do not describe a conduction-only model as CFD with natural convection.

## Shell-core sphere

Represent a full sphere in the meridional `r-z` half-plane with `r >= 0`; enable axisymmetry on the geometry and relevant integration/average operators. Keep separate named selections for:

- PCM core domains;
- shell domains;
- complete outer spherical boundary;
- optional core-shell interface and symmetry axis.

After the geometry finalization, assert the expected topology. A split outer curve may contain multiple boundary entities; select all of them. Applying temperature to one arc creates one-sided heating and an unphysical directional melt front.

For core radius `Rc` and outer radius `Ro`, compare numerical measures with:

```text
Vcore  = 4*pi*Rc^3/3
Vshell = 4*pi*(Ro^3-Rc^3)/3
Aouter = 4*pi*Ro^2
```

Use axisymmetric integration instead of manually multiplying by `2*pi*r` twice.

## Phase-change material

Define at least density, solid/liquid conductivity, solid/liquid heat capacity, latent heat, solidus/liquidus or transition center/width, and initial temperature. Document data sources and uncertainty.

Use COMSOL's Phase Change Material feature when it is stable for the selected heat-transfer node. If a feature is attached to a fluid node for numerical reasons while velocity is zero, state this explicitly and confirm that only the core inherits the phase-change attribute.

Treat liquid fraction as a PCM-domain variable. During export, set values outside the core to NaN or mask them in postprocessing so the shell is never plotted as liquid PCM.

## Boundary and initial conditions

For uniform environmental heating, choose one physical boundary model and document it:

- prescribed outer-surface temperature ramp;
- convection to an ambient temperature with heat-transfer coefficient;
- conjugate heat transfer through an explicitly modeled surrounding fluid.

Do not replace a full-surface boundary with a point or single-edge source. Smooth abrupt ramps when needed for solver stability, but record the ramp duration.

## Expected invariants during uniform heating

For a homogeneous spherical capsule with no gravity-driven flow:

- outer-surface temperature spread should be near numerical zero for prescribed uniform temperature;
- north and south profiles should agree;
- axis and equator radial profiles should agree within discretization error;
- temperature should generally increase toward the outer radius during heating;
- liquid fraction should generally increase toward the outer radius;
- average liquid fraction should not decrease under monotonic heating;
- the melt front should move from the shell-core interface toward the center.

Use tolerances scaled to the imposed temperature span, phase interval, mesh, and output interpolation. Diagnose selection errors before loosening symmetry tolerances.

## Energy balance

Compute cumulative boundary heat input and stored energy independently:

```text
Ein(t) = integral_0^t integral_outer(-n dot q) dA dt
Estored(t) = sensible_core + latent_core + sensible_shell
relative_error = abs(Ein-Estored) / max(abs(Ein), abs(Estored), small_value)
```

Use the same temperature-dependent properties and phase-fraction convention as the model. Integrate boundary power over time with sufficiently fine output. A final error below 5% is a useful initial target, but also examine the error history and refinement trend.

## Resolution and convergence

Resolve the shell thickness and moving phase front with multiple elements. Limit the maximum time step so the transition interval is not crossed in one or two steps. Repeat with refined mesh and time step; compare `t10`, `t50`, `t90`, center temperature, final liquid fraction, and energy error.

Select field snapshots by liquid-fraction progress, for example 0, 0.05, 0.2, 0.4, 0.6, 0.8, 0.95, and approximately 1.0, rather than only by uniform time.
