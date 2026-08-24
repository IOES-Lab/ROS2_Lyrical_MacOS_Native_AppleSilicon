# What was changed

Six patches. Together they are everything that had to be modified to get DAVE and its WGPU
multibeam sonar building and running on ROS 2 Lyrical + Gazebo Jetty.

All apply against `naitikpahwa18/dave` at `6aef91c` (branch `wgpu_integration`, part of
[PR #44](https://github.com/IOES-Lab/dave/pull/44)), except `ros_gz_lyrical_jetty_mac.diff`,
which applies to the `ros_gz` source workspace.

| Patch | Changes | Size | Why | Status |
|---|---|---|---|---|
| [`dave_lyrical_jetty_migration_mac.diff`](dave_lyrical_jetty_migration_mac.diff) | 8 files: 6 `CMakeLists.txt`, 1 `package.xml`, `SphericalCoords.cc` | +177 −152 | Without it DAVE does not build on Jetty at all | Required. One part proposed upstream, not yet filed |
| [`ros_gz_lyrical_jetty_mac.diff`](ros_gz_lyrical_jetty_mac.diff) | `ros_gz_bridge` and `ros_gz_sim` `CMakeLists.txt` | +6 | `ros_gz` has no macOS binary for Lyrical, and the source build fails without these | Required on macOS |
| [`dave_world_launch_headless_fix.diff`](dave_world_launch_headless_fix.diff) | `dave_world.launch.py` | +21 | The launch file had no headless mode, so 3 manipulation worlds could not be tested at all | Fixed and confirmed on all 3 worlds |
| [`vehicle_imu_topic_fix.diff`](vehicle_imu_topic_fix.diff) | 4 vehicle `model.sdf` | +19 | No vehicle's IMU data reached ROS | Fixed, measured before and after. Issue report ready |
| [`usbl_sigma_fix.diff`](usbl_sigma_fix.diff) | `usbl_tutorial.world` | +7 −2 | `<sigma>0.0</sigma>` aborts the Gazebo **server** | **Workaround only.** The plugin still lacks validation |
| [`new_dvl_uri_fix.diff`](new_dvl_uri_fix.diff) | `new_dvl.world` | +1 −1 | A malformed Fuel model URI stopped the world loading | Fixed and confirmed live |

## Which of these are real fixes

Three are complete: the headless launch mode, the vehicle IMU topics, and the DVL URI. Each was
applied, run, and confirmed to change the observed behaviour.

Two are ports rather than fixes — the migration patch and the `ros_gz` patch exist because Jetty
renamed things and macOS builds differently. They are not defects in DAVE.

One is a workaround. `usbl_sigma_fix.diff` edits the world file so the demo stops crashing, but
`UsblTransponder.cc` still builds a `std::normal_distribution` straight from `<sigma>` with no
validation, so any other world setting `sigma=0` still aborts the server. The plugin-level fix is
written up but not filed.

## What the migration patch actually contains

Eight patterns, recurring across the six `CMakeLists.txt`:

- Gazebo version suffixes dropped — `gz-sim8` → `gz-sim`, and the same for the other components
- `ament_target_dependencies` removed in favour of `target_link_libraries`
- Boost component handling
- `SphericalCoords.cc` — `gz-math9` made the conversion API return an optional
- `package.xml` — 7 missing `<depend>` entries that caused a parallel-build race
- Build-log text still saying "Compiling against Gazebo Harmonic" on a Jetty build

Full breakdown with code:
[`../notes/cmake-migration-patterns.md`](../notes/cmake-migration-patterns.md).

## One caveat on the migration patch

The original +172/−147 version was verified to apply identically and rebuild successfully on both
macOS and Docker (2026-07-14). The current +177/−152 adds five string- and comment-only edits.
Each was confirmed against the real checkout, but the full rebuild-and-compare was not re-run
against this version. They change no logic.

## Not in this folder

Two experiment switches were added to `MultibeamSonarSensor.cc` (`DAVE_CV_THREADS`,
`DAVE_SONAR_IMAGE`) while investigating sonar cost. They exist to make measurements possible, both
default to existing behaviour, and they are **not proposed upstream** — so they are not kept here
as a patch.

The eight issue reports prepared for `IOES-Lab/dave` are in
[`../notes/upstream/submit/`](../notes/upstream/submit/). Two of them correspond to patches here
(`vehicle_imu_topic_fix`, `usbl_sigma_fix`); the rest report findings that need no patch from us.
