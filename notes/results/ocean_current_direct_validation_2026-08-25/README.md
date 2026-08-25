# Ocean Current direct validation — 2026-08-25

This directory records direct Mac ROS 2 Lyrical + Gazebo Jetty validation of
the DAVE Ocean Current plugins.

## Verdict

- All **12 custom `/hydrodynamics/` services** were discovered with their
  exact types and called directly.
- Constant-current velocity and direction changes appeared on both the ROS
  and Gazebo current outputs.
- Stratified velocity, horizontal direction and vertical direction updates
  changed only the selected layer.
- Invalid layer `65535` and an invalid Gauss-Markov constraint returned
  `success: false`.
- All six Gauss-Markov get/set model paths were exercised and the original
  values were restored.
- A controlled paired REXROV trial directly confirmed that the current reaches
  the hydrodynamics path and changes vehicle motion.

## Controlled vehicle comparison

Both worlds used the same REXROV spawn and **8.98 s** simulation interval.
The committed world assets differ only in the world name and constant-current
mean (`0` versus `1.5 m/s`). The zero-current ROS wrapper topic capture did not
succeed, so the control condition is established by the committed world
configuration rather than by a second runtime current-topic sample.

| Condition | X displacement |
|---|---:|
| Zero current | -0.016826641 m |
| +1.5 m/s current in X | 9.034046258 m |
| Paired difference | +9.050872899 m |

The end X-velocity difference was
`+1.296746855 m/s`.

Both trials rose approximately 4.37 m because the vehicle was buoyant and no
controller held depth. Their Z displacement differed by only
`+0.004652765 m`; the principal controlled difference was horizontal.

## Mac plugin-path finding

The first launch failed to load `OceanCurrentWorldPlugin` and
`OceanCurrentPlugin`. In this isolated-install workspace, the relevant dylibs
were installed directly under each package's `lib/`, while the generated
Gazebo plugin-path hooks referenced `lib/<package>/`.

Adding the two real `lib/` directories to `GZ_SIM_SYSTEM_PLUGIN_PATH` allowed
the plugins to load. This is an observed workspace packaging/path mismatch,
not yet an upstream fix.

## Evidence layout

- `01_runtime_inventory/` — initial load failure
- `02_plugin_path_override/` — actual dylib locations and successful override
- `03_constant_current_services/` — service inventory and constant velocity
- `04_stratified_current_services/` — layer velocity/direction and invalid layer
- `05_global_direction_services/` — global horizontal/vertical direction
- `06_gauss_markov_models/` — all six get/set model paths
- `07_vehicle_force_response/` — paired zero-current and +1.5 m/s trials
- `summary.json` — machine-readable summary

The `invalid_*` and `incomplete_*` directories preserve failed methodologies:
a world reset invalidated the paired comparison, a service call while paused
timed out, and one CLI capture missed its start sample. None is used as final
vehicle-response evidence.

## Reproduction assets

`07_vehicle_force_response/test_assets/` contains the two custom world files.
The temporary overlay's generated `build/`, `install/`, `log/` and copied DAVE
assets are intentionally not committed.

## Scope limit

This confirms the World Plugin / ROS wrapper service behavior, topic changes,
and one controlled vehicle-motion effect through the global `/ocean_current`
Hydrodynamics path. In the tested REXROV model, the Hydrodynamics `<namespace>`
line and the complete `OceanCurrentModelPlugin` block are commented out, so
the per-vehicle model-plugin path and depth-based stratified-force interpolation
were **not** tested. It also does **not** establish hydrodynamic coefficient
accuracy, real-ocean agreement, tidal evolution, multi-vehicle isolation, or
long-duration stability.
