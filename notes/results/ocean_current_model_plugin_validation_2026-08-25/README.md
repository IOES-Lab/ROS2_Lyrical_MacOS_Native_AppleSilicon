# OceanCurrentModelPlugin direct validation — 2026-08-25

> **Current update — 2026-08-31.** The final limit below is the scope of this 2026-08-25 run. Later synthetic controls directly exercised 400-sample Gauss–Markov variation and the documented per-model tidal path (200 no-tide plus 200 tide-enabled messages). Those later controls supersede only the old tide/non-zero-noise gap; mission endurance and real-ocean accuracy remain open. See [`../ocean_current_tidal_noise_validation_2026-08-31/`](../ocean_current_tidal_noise_validation_2026-08-31/).

## Verdict

**FUNCTIONAL PASS**, within the recorded scope.

The stock REXROV model comments out its Hydrodynamics namespace and
`OceanCurrentModelPlugin`. This experiment enabled both only in copied test assets.
The DAVE source checkout was not modified.

## Fixed-depth interpolation

Two static probe models isolated interpolation from vehicle motion.

| Depth | Expected `(north, east, down)` m/s | Measured m/s |
|---:|---:|---:|
| 5 m | `(0.005, 0.040, 0.0)` | `(0.005, 0.040, 0.0)` |
| 15 m | `(0.010, 0.025, 0.0)` | `(0.010, 0.025, 0.0)` |

Both ROS and Gazebo vehicle-specific topics were present.

**What makes this discriminating, and where it is not.** Both probe depths sit at layer
*midpoints* — 5 m between the 0 m and 10 m layers, 15 m between 10 m and 20 m — so the expected
values are interpolated quantities rather than stored ones. `0.005`, `0.040` and `0.025` appear
nowhere in the stratified database, so a nearest-layer lookup, a clamp, or an off-by-one layer
index could not produce them. **The exception is the 15 m north component:** both bounding layers
carry `0.010`, so that one number is consistent with interpolation and with plain lookup alike,
and proves nothing on its own. The 15 m row rests on its east component, `0.025`.

Database used: [`01_depth_interpolation/stratified_database.txt`](01_depth_interpolation/stratified_database.txt).

Machine-readable result:
[`01_depth_interpolation/interpolation_check.json`](01_depth_interpolation/interpolation_check.json).

## REXROV physical response

All 12 stratified layers were set to the same value before each vehicle spawn.

| Measurement | Zero current | `+1.5 m/s` X current |
|---|---:|---:|
| Simulation interval | 8.98 s | 8.99 s |
| X displacement | -0.014398 m | +11.549603 m |
| Average X velocity | -0.001603 m/s | +1.284717 m/s |
| End X velocity | -0.003196 m/s | +1.381538 m/s |

Paired differences:

- X displacement: **+11.564001 m**
- average X velocity: **+1.286320 m/s**
- end X velocity: **+1.384734 m/s**

The directly recorded ModelPlugin output was `(1.5, 0.0, 0.0)` m/s.

Machine-readable result:
[`02_physical_response/comparison.json`](02_physical_response/comparison.json).

## Validated path

```text
OceanCurrentWorldPlugin / ROS wrapper
  -> stratified database
  -> OceanCurrentModelPlugin
  -> /model/rexrov/ocean_current
  -> Gazebo Hydrodynamics
  -> REXROV motion
```

## Limits

- One independent physical run was recorded per condition.
- Vehicle states at the start of the recorded windows were not identical.
- **The two windows are not the same length** — 8.98 s against 8.99 s, as the table above shows.
  At the measured average velocity the extra hundredth of a second accounts for about 0.013 m of
  the 11.564 m difference, so it does not carry the result, but the paired difference is a
  comparison across slightly unequal intervals rather than a matched one.
- **This run is not comparable with the global-current run of the same date.** That experiment
  ([`../ocean_current_direct_validation_2026-08-25/`](../ocean_current_direct_validation_2026-08-25/))
  measured +9.034 m for a nominally identical `+1.5 m/s` X current. The conditions differ: it
  began at `t = 0.01 s` with the vehicle ascending about 4.37 m during the window and the
  Hydrodynamics namespace commented out, while this run starts from a settled state near
  `t = 69 s` with vertical displacement under 0.26 m. The two numbers describe different setups
  and neither supersedes the other.
- This establishes functional application, not coefficient accuracy.
- It does not establish real-ocean or general physical accuracy.
- Tidal evolution, non-zero noise, multi-vehicle isolation and long stability remain untested.

## Evidence

- [`test_assets/`](test_assets/)
- [`01_depth_interpolation/`](01_depth_interpolation/)
- [`02_physical_response/baseline_zero_current/`](02_physical_response/baseline_zero_current/)
- [`02_physical_response/current_1p5x/`](02_physical_response/current_1p5x/)
- [`summary.json`](summary.json)
