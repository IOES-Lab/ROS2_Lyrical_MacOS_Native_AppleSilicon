# Direct ROV model validation — 2026-08-27

This evidence set re-runs the **Dave ROV Models** Wiki examples and isolates
the vehicle and input paths that the earlier matrix did not directly cover.
It uses DAVE revision `6aef91c` in a non-pristine Lyrical/Jetty migration
checkout. The Mac workspace contains the local IMU-topic patch for the four
previously tested vehicles; the Docker `lyrical-theme-test` install does not.
The two environments therefore show patch-state as well as platform differences.

## Current verdicts

| Path | Direct result | Verdict |
|---|---|---|
| REXROV + `dave_ocean_waves`, Mac patched workspace | 7/7 message contents: odometry, odometry-with-covariance, pose, IMU, magnetometer, camera info, camera image | **FUNCTIONAL PASS** within this bridge scope |
| REXROV + stock `empty.sdf`, exact Mac Wiki command | entity and bridge startup; retained ROS content discovery was inconclusive | **SMOKE PASS only** |
| REXROV + stock `empty.sdf`, exact Docker Wiki command | 4/7: odometry, covariance odometry, pose, magnetometer; camera and IMU silent | **PARTIAL** |
| BlueROV2 / Heavy, Mac patched recheck | odometry + IMU; no magnetometer in the tracked three-sensor set | **PARTIAL**; consistent with the earlier 4/5 matrix |
| BlueROV2 / Heavy, Docker as-shipped isolated | odometry only; IMU and magnetometer silent | **PARTIAL**; image lacks the local IMU patch |
| `bluerov2_heavy_multibeam_sonar`, Mac and Docker | odometry only; IMU, magnetometer, and sonar PointCloud2 silent in 120 s | **PARTIAL** on both platforms |
| WebSocket virtual joystick, Docker standalone | injected browser-gamepad JSON reproduced on `/joy` with matching axes/buttons | **FUNCTIONAL PASS** |
| keyboard publisher, Docker TTY | pressing `w` produced non-neutral `/keyboard/joy`; `q` exited | **FUNCTIONAL PASS** |
| exact integrated BlueROV2 Docker launch | entity, WebSocket, Firefox, QGC, and ArduSub startup observed; launch then tears down | **PARTIAL / incomplete integration** |

## Important scope corrections

The fifth `bluerov2_heavy_multibeam_sonar` variant is **no longer
source-only**. It was launched in isolated controls on both Mac and Docker.
The vehicle spawned and odometry published, but IMU, magnetometer, and the
bridged sonar PointCloud2 remained silent for 120 seconds. Source inspection
explains the IMU omission and the bridge-without-sensor magnetometer path; it
does **not** establish why the declared sonar stayed silent.

The REXROV `empty.sdf` command is a valid spawn example, not a complete sensor
example. In Docker it returned four of the seven configured topics. The stock
empty world has no Sensors system, so camera output is not expected there;
the Docker install also lacks the local IMU-topic patch. The exact installed
world excerpt is retained in
[`empty_world_systems.txt`](05_docker/rexrov_empty_exact/empty_world_systems.txt).

The exact integrated Docker BlueROV2 command does not complete in the current
image. `mavros_msgs` is absent, the `mavros` package is absent, the keyboard
non-TTY failure path calls the removed logger method `.warn()`, and
`libArduPilotPlugin.so` is missing. QGroundControl and Firefox process startup
is not evidence of a vehicle connection or control loop. The input backends
were therefore validated separately, where both produced discriminating Joy
messages. The traceback at the end of the WebSocket server log occurred during
the deliberate test shutdown, after the matching Joy message had been saved;
it is not treated as evidence of steady-state success or failure.

## Evidence map

- [`00_environment/`](00_environment/) — Mac and Docker package/environment inventory
- [`01_rexrov_empty_mac/`](01_rexrov_empty_mac/) — exact Mac empty-world spawn/bridge run
- [`02_bluerov2_exact_mac/`](02_bluerov2_exact_mac/) — exact Mac BlueROV2 run
- [`03_vehicle_matrix_mac/`](03_vehicle_matrix_mac/) — isolated Mac Heavy recheck
- [`04_multibeam_variant_mac/`](04_multibeam_variant_mac/) — first Mac runtime of the fifth variant
- [`05_docker/`](05_docker/) — exact/isolated Docker vehicle and input runs
- [`06_rexrov_ocean_mac/`](06_rexrov_ocean_mac/) — 7/7 REXROV message contents
- [`source_audit.md`](source_audit.md) — fifth-variant SDF/bridge scope
- [`scripts/`](scripts/) — retained capture and launch helpers
- [`summary.json`](summary.json) — machine-readable verdicts

## Limits

- The 2026-08-27 BlueROV2 and Heavy reruns tracked three sensor/vehicle topics;
  they do not replace the earlier broader 4/5 matrix.
- No successful MAVROS/QGroundControl vehicle-control loop was established.
- No commanded-thrust dynamics, quantitative maneuver response, or multi-run
  stability matrix was measured.
- The fifth variant's sonar failure is observed but not root-caused.
