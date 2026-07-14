# ROS 2 Lyrical / Gazebo Jetty — DAVE Migration Verification

## Purpose

This repository documents verifying whether [DAVE](https://github.com/IOES-Lab/dave) (underwater robotics simulation library, currently documented for ROS 2 Jazzy + Gazebo Harmonic) and its multibeam sonar plugin ([PR #44](https://github.com/naitikpahwa18/dave/tree/wgpu_integration), CUDA-free WGPU backend) can be updated and run on the next-generation **ROS 2 Lyrical + Gazebo Jetty** combination.

Verified on both macOS (Apple Silicon, native) and Docker (Ubuntu 26.04). This is smoke-test level verification — core packages, demos, and sensors run correctly — not an exhaustive validation of every DAVE feature. Exhaustive verification is planned for August.

## Environment

| | macOS (native) | Docker |
|---|---|---|
| OS | macOS 15.7.3, Apple Silicon (M2) | Ubuntu 26.04 Resolute (arm64) |
| ROS 2 | Lyrical (source build) | Lyrical (apt, `ros-lyrical-desktop`) |
| Gazebo | Jetty (Homebrew) | Jetty 10.4.0 (apt vendor build via `ros-lyrical-ros-gz`) |
| Python | 3.14 | 3.14 |
| GPU | Metal (real hardware) | Vulkan `llvmpipe` (CPU software renderer) |

## Progress Log

| Date | Task | Result | Notes |
|---|---|---|---|
| 2026-07-06 | ROS 2 Lyrical native source build (Mac) | Done | GUI-related packages excluded; core succeeded |
| 2026-07-06 | Gazebo Jetty apt availability check (Docker) | Failed | Not in OSRF apt at the time; source build attempted, OOM |
| 2026-07-07 | PR #44 multibeam sonar without Nvidia (Jazzy+Harmonic, Mac Metal) | Done | Confirmed WGPU backend works without CUDA |
| 2026-07-07 | `ros_gz` bridge build for Lyrical+Jetty (Mac) | Done | 35 packages |
| 2026-07-08 | DAVE core packages ported to Lyrical+Jetty (Mac) | Done | 10 packages; CMake + `SphericalCoords.cc` changes only |
| 2026-07-08 | Gazebo Jetty source build retry (Docker) | Done | OOM root-caused to colcon+make parallelism multiplying |
| 2026-07-11 | DAVE + PR #44 sonar demo actually run in Docker | Done | Discovered apt already vendors Gazebo Jetty — source build unnecessary |
| 2026-07-13 | Mac vs Docker frame timing measured | Done | ~86–96 ms (Mac, Metal) vs ~273–438 ms (Docker, llvmpipe) |
| 2026-07-13 | Confirmed Ubuntu 26.04 is the official target OS for ROS 2 Lyrical | Done | docs.ros.org: "Deb packages ... available for Ubuntu Resolute (26.04)"; 24.04 has zero `ros-lyrical-*` packages |
| 2026-07-13 | REXROV vehicle launch verified | Done | Real odometry/imu/magnetometer/camera data via `ros_gz` bridge |
| 2026-07-13 | Real GUI confirmed visually via RDP (Docker) | Done | See [Known Issues](#known-issues) for the OGRE2 caveat and the xrdp setup gotcha |
| 2026-07-14 | Full world list catalogued (18 worlds) | Done | Only 6 previously known; 3 are manipulation scenarios, 2 require a separate `sonar-demo` branch |
| 2026-07-14 | DVL / underwater camera / USBL / ocean current / sea pressure sensors verified | Done | All 5 launch and publish correctly |
| 2026-07-14 | BlueROV2 + ArduSub SITL built and launched | Done | Required fixing 5 chained Python 3.14 incompatibilities in `waf` — see [Known Issues](#known-issues) |
| 2026-07-14 | `git diff --stat` compared Mac vs Docker | Done | Identical: 8 files, +172/−147 |

## Reproduction

### macOS (Apple Silicon, native)

```bash
git clone https://github.com/naitikpahwa18/dave.git
cd dave
git checkout wgpu_integration
git apply patches/dave_lyrical_jetty_migration_mac.diff

colcon build --symlink-install --packages-select \
  dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
  dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
  dave_ros_gz_plugins dave_demos \
  --cmake-args -DBUILD_TESTING=OFF -Wno-dev

source install/setup.zsh   # zsh — sourcing .bash under zsh breaks COLCON_CURRENT_PREFIX

ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
  x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

### Docker (Ubuntu 26.04)

```bash
apt install -y ros-lyrical-desktop ros-lyrical-ros-gz

git clone https://github.com/naitikpahwa18/dave.git
cd dave
git checkout wgpu_integration
git apply patches/dave_lyrical_jetty_migration_mac.diff   # identical diff applies cleanly on Linux too

colcon build --merge-install --executor sequential --packages-select \
  dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
  dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
  dave_ros_gz_plugins dave_demos
colcon build --merge-install --executor sequential --packages-select wgpu_vendor
colcon build --merge-install --executor sequential --packages-select multibeam_sonar multibeam_sonar_system

source install/setup.bash

# gui:=true headless:=true together == real headless mode (see Known Issues)
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
  x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

## Verified demos

| Demo | Status |
|---|---|
| Multibeam sonar (PR #44, WGPU) | Real `PointCloud2` data, 513 beams × 301 rays |
| REXROV vehicle | odometry/imu/camera bridged correctly |
| BlueROV2 + ArduSub SITL | full launch, keyboard teleop node also confirmed |
| DVL, underwater camera, USBL, ocean current, sea pressure | all launch and publish |

18 world files exist under `models/dave_worlds/worlds/`; 6 of them smoke-tested above. 3 are manipulation scenarios (`dave_bimanual_example`, `dave_electrical_mating`, `dave_plug_and_socket`, out of scope this round) and 2 (`dave_ocean_waves_sonar`, `dave_ocean_waves_sonar_integrated`) require a `sonar-demo` branch that exists on `IOES-Lab/dave` but not on `naitikpahwa18/dave` — untested.

## Known issues

- **`gui`/`headless` launch argument interaction** — `dave_sensor.launch.py` / `dave_robot.launch.py` gate the entire Gazebo process on `gui` (`condition=IfCondition(gui)`); `gui:=false` disables Gazebo entirely, not just the window. Pass both `gui:=true headless:=true` for real headless mode.
- **OGRE2 unavailable on Ubuntu 26.04 aarch64** — confirmed on both source-built and apt-vendored Gazebo Jetty; GUI launches fail (`Failed to load plugin [ogre2]`) unless world files are patched `ogre2` → `ogre`. The resulting OGRE1 fallback renders visibly worse than the Jazzy+Harmonic baseline (OGRE2) — this is a reasonable inference from a qualitative comparison, not a rigorous frame-time benchmark.
- **`multibeam_sonar_system` missing `package.xml` dependencies** — `CMakeLists.txt` pulls in a neighboring package via `add_subdirectory` without declaring it, causing a parallel-build race condition. Fixed with 7 added `<depend>` tags — see the patch. Worth an upstream PR regardless of ROS distro.
- **ArduSub SITL build vs. Python 3.14** — `waf` and its `clang_compilation_database` extra import Python stdlib modules removed in modern Python: `imp` (removed 3.12) and `pipes` (removed 3.13). See [`notes/ardusub-sitl-setup.md`](notes/ardusub-sitl-setup.md) for the full fix (shims + non-root user + `PIP_BREAK_SYSTEM_PACKAGES=1`).
- **`xrdp` group permission (RDP screen setup)** — the `xrdp` daemon can't reach session sockets owned `<user>:root`; fix with `usermod -aG root xrdp` + full service restart.
- **DAVE Wiki inaccuracies found while cross-checking** — see [`notes/dave-wiki-inaccuracies.md`](notes/dave-wiki-inaccuracies.md). No page anywhere in the Wiki mentions Lyrical or Jetty, including pages edited as recently as this week.

## Patch

[`patches/dave_lyrical_jetty_migration_mac.diff`](patches/dave_lyrical_jetty_migration_mac.diff) — base commit `6aef91c` on `naitikpahwa18/dave` (`wgpu_integration`), 8 files changed, +172/−147. Verified to apply identically and produce identical `git diff --stat` output on both macOS and Docker/Ubuntu 26.04. Full pattern breakdown in [`notes/cmake-migration-patterns.md`](notes/cmake-migration-patterns.md).

## Next steps (August)

- [ ] Exhaustive validation of all 18 worlds and documented vehicles/sensors
- [ ] Test the two `sonar-demo`-branch-only demos
- [ ] Quantitative performance/accuracy benchmarking
- [ ] Decide sonar extension priority: Profiling vs. Mechanical Scanning vs. Side-scan
- [ ] Consider upstreaming the `package.xml` fix and reporting the OGRE2 gap
- [ ] Report the DAVE Wiki inaccuracies to the Wiki maintainers

## References

- [DAVE (IOES-Lab fork)](https://github.com/IOES-Lab/dave)
- [PR #44 branch (naitikpahwa18/dave, wgpu_integration)](https://github.com/naitikpahwa18/dave/tree/wgpu_integration)
- [DAVE ROS2 Wiki](http://dave-ros2.notion.site)
- [ROS 2 Lyrical Luth — official docs](https://docs.ros.org)
- Choi, W. et al., "Physics-based modelling and simulation of Multibeam Echosounder perception for Autonomous Underwater Manipulation," *Frontiers in Robotics and AI*, 2021. [10.3389/frobt.2021.706646](https://doi.org/10.3389/frobt.2021.706646)
