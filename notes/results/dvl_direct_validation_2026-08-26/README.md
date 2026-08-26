# DVL direct validation — 2026-08-26

## Verdict

**PARTIAL.** The DAVE DVL publishes structurally valid bottom-track data in
Docker, and controlled flat-plane and moving-platform tests agree with the
configured geometry and velocity transform. The same DVL rendering-sensor
path crashes Gazebo Jetty on this Mac, the DAVE custom bridge drops
`frame_id`, and the shipped water-mass configuration does not become active
without environmental data.

The runs used the existing Lyrical/Jetty migration workspaces: DAVE was based
on `6aef91c` and `ros_gz` on `0ea9efc`. Both checkouts were non-pristine, with
migration changes present. The DVL launch/model/bridge source quoted in
[`source_audit.txt`](source_audit.txt) was not itself listed as modified;
`ros_gz`'s DVL conversion source was also unmodified, while its CMake files
carried migration changes. These are validation results for that workspace,
not for pristine upstream checkouts.

## What was run

| Test | Result | Direct observation |
|---|---|---|
| DAVE Wiki Quickstart on Mac | FAIL | Gazebo SIGSEGV in `SensorsPrivate::RenderThread()` |
| DAVE headless launch on Mac | FAIL | same server-side SIGSEGV |
| official `ros_gz_sim_demos` DVL on Mac | FAIL | same SIGSEGV, so not DAVE-world-specific |
| official stock DVL forced to `ogre` on Mac | FAIL | same SIGSEGV, so not `ogre2`-only |
| exact DAVE Wiki Quickstart in Docker | PASS | bottom target, four beams, 8 Hz in simulation time |
| 20 m flat-plane control in Docker | PASS | 20/20 samples at 21.8671856 m, all beams locked |
| 1 m/s moving-platform control in Docker | PASS | mean speed 1.0004053 m/s over 20 samples |
| official `ros_gz_bridge` DVL conversion in Docker | PASS | C++ subscriber received frame, velocity, altitude and four valid beams |
| shipped DAVE water-mass configuration without bottom | FAIL | 20/20 `DVL_TARGET_UNSPECIFIED`, no locked beams |
| corrected environmental-data water-mass control | PASS | 20/20 water-mass target, four locked beams, expected transformed speed |

## Mac failure scope

The four Mac runs all terminate in the Gazebo Sensors render thread at
`gz::sim::v10::systems::SensorsPrivate::RenderThread()` / `WaitForInit()`.
The controls rule out a DAVE-only world defect, a GUI-client-only defect and
an `ogre2`-only defect. They do **not** establish the exact lower-level macOS
root cause.

Evidence: [`01_wiki_quickstart_mac/`](01_wiki_quickstart_mac/),
[`02_headless_mac/`](02_headless_mac/),
[`03_stock_ros_gz_demo_mac/`](03_stock_ros_gz_demo_mac/), and
[`04_stock_dvl_ogre_mac/`](04_stock_dvl_ogre_mac/).

## Docker bottom-track controls

The exact DAVE Quickstart publishes `/dvl/velocity` as
`dave_interfaces/msg/DVL`, with a phased-array bottom target and four beams.
Consecutive message stamps are 0.125 s apart, matching the model's 8 Hz
update rate. A slower wall-clock `ros2 topic hz` value in this container is a
simulation-RTF effect, not an 8 Hz configuration failure.

The flat-plane control places the DVL 20 m above a planar target. For a 25°
beam tilt, the center-ray distance is 22.067566 m. The 3° aperture spans an
analytic range envelope of approximately 21.80882–22.34801 m; all 20 samples
are 21.8671856 m and all four beams are locked. This validates one controlled
geometry, not general acoustic accuracy.

The moving-platform control commands +1 m/s in world X. The configured
ENU-to-FSD transform maps that approximately to negative DVL Y. Across 20
samples, the mean DVL vector is `(0.000998, -1.000355, -0.001053)` m/s and
the mean speed is 1.000405 m/s.

Evidence: [`05_docker_dave_quickstart/`](05_docker_dave_quickstart/),
[`06_flat_plane_docker/`](06_flat_plane_docker/), and
[`07_moving_platform_docker/`](07_moving_platform_docker/).

## Bridge findings

The DAVE `DVLBridge` copies the Gazebo timestamp but never copies the Gazebo
header's `frame_id`. Every directly sampled DAVE ROS message therefore has an
empty frame, while the corresponding Gazebo message contains
`nortek_dvl500_300::dvl500_base_link::nortek_dvl500_300`.

The current Lyrical `ros_gz_bridge` **does** support DVL conversion. A C++
subscriber received `marine_acoustic_msgs/msg/Dvl` with frame
`tethys/base_link/teledyne_pathfinder_dvl`, bottom mode, altitude and four
valid beam ranges and velocities. This directly contradicts the old Wiki
claim that no DVL bridge exists.

Evidence: [`08_stock_ros_gz_docker/`](08_stock_ros_gz_docker/) and
[`source_audit.txt`](source_audit.txt).

## Water-mass finding

Gazebo defines `<water_velocity><x|y|z>` as **names of variables in world
environmental data**, not numeric vector components. All eight standalone
DAVE DVL models and the REXROV-integrated DVL use `0.` in those elements, and
the DAVE source contains no environmental-data preload for these worlds.

With the shipped configuration and no bottom return, 20/20 messages remain
`DVL_TARGET_UNSPECIFIED`, with zero range and no locked beams. A corrected
control supplies time-varying environmental data named `water_vx`,
`water_vy`, and `water_vz`. For a world velocity `(1.0, 0.5, 0.0)` m/s, all
20 messages switch to `DVL_TARGET_WATER_MASS`, all four beams lock, and the
reported transformed mean is `(0.499204, 1.000397, 0.001593)` m/s with speed
1.118034 m/s. The target range 60.685786 m equals the mean 55 m layer depth
projected along the 25° beam.

Evidence: [`09_water_mass_docker/`](09_water_mass_docker/),
[`10_water_mass_corrected_control/`](10_water_mass_corrected_control/), and
the installed primary API excerpt in [`source_audit.txt`](source_audit.txt).

## Limits

- The bottom-range and velocity controls each use one synthetic geometry.
- The Docker samples establish functional behavior, not general DVL or
  underwater-acoustics accuracy.
- The corrected water field is uniform and synthetic, not a real ocean
  profile.
- The exact macOS rendering failure remains below the isolated scope.

Machine-readable verdict: [`summary.json`](summary.json).
