# ROS 2 Lyrical / Gazebo Jetty — DAVE Migration Verification

```text
Status: Experimental / validation environment
Validated: Build, headless launch, XFCE/xrdp login, representative smoke tests
Not yet validated: all 18 worlds, quantitative performance
Known limitation: Ubuntu 26.04 GNOME 50 no longer provides an X11 session for xorgxrdp; XFCE is used
```

## Purpose

This repository documents verifying whether [DAVE](https://github.com/IOES-Lab/dave) (underwater robotics simulation library, currently documented for ROS 2 Jazzy + Gazebo Harmonic) and its multibeam sonar plugin ([PR #44](https://github.com/naitikpahwa18/dave/tree/wgpu_integration), CUDA-free WGPU backend) can be updated and run on the next-generation **ROS 2 Lyrical + Gazebo Jetty** combination.

Verified on both macOS (Apple Silicon, native) and Docker (Ubuntu 26.04). This is an **integration smoke test**, not exhaustive validation: DAVE's core packages and a representative set of vehicle, sensor, and multibeam-sonar paths were confirmed working end to end. Full coverage of every world/vehicle/sensor/launch combination is planned for August (see [Next steps](#next-steps)).

**Pinned commits** (so results here are reproducible against the exact code tested):

| Repo | Branch | Commit |
|---|---|---|
| `naitikpahwa18/dave` | `wgpu_integration` | `6aef91c823af5da073329b84ba617b572965e79e` |
| `IOES-Lab/dave` | `sonar-demo` (untested paths only) | `8f6314f1133e19613f4d145b179f61d3b3daa741` |
| `ArduPilot/ardupilot` | `ArduSub-stable` | `30257f01185471ab4c1ac544e47d1b4437e44c98` |

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
| 2026-07-15 | Root-caused Docker RDP desktop crash | Done | XFCE + xrdp works; GNOME 50 is Wayland-only on Ubuntu 26.04 and has no X11 session for xorgxrdp — not a bug, an OS/RDP-stack incompatibility. `docker/` Dockerfile updated to install XFCE explicitly and use a custom `startwm.sh`; not yet re-verified with a clean (`--no-cache`) build |

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

| Demo | Result | Evidence |
|---|---|---|
| Multibeam sonar (PR #44, WGPU) | PASS | Real `PointCloud2`, 513 beams × 301 rays |
| REXROV vehicle | PASS | odometry/imu/camera bridged via `ros_gz`, real topic data |
| BlueROV2 + ArduSub SITL | PASS | full launch, keyboard teleop node also confirmed |
| DVL, underwater camera, ocean current, sea pressure | PASS (4/4) | all launch and publish real topics |
| USBL | PARTIAL | server-side plugin/SDF loads and publishes correctly; GUI client crashes (world-only test, no vehicle spawn, so limited practical impact) |
| Docker RDP desktop (XFCE) | PASS (live container) / NOT RE-VERIFIED (clean image) | works on the manually-patched container; `docker/` Dockerfile now bakes this in but hasn't been re-tested from a clean build yet |
| `dave_ocean_waves_sonar`, `dave_ocean_waves_sonar_integrated` (sonar-demo branch) | NOT TESTED | needs `IOES-Lab/dave` `sonar-demo` branch, not on `naitikpahwa18/dave` |
| `dave_bimanual_example`, `dave_electrical_mating`, `dave_plug_and_socket` (manipulation) | NOT TESTED | out of scope this round |

18 world files exist under `models/dave_worlds/worlds/`; 6 of them smoke-tested above (see rows above for the remaining 12).

## Known issues

- **`gui`/`headless` launch argument interaction** — `dave_sensor.launch.py` / `dave_robot.launch.py` gate the entire Gazebo process on `gui` (`condition=IfCondition(gui)`); `gui:=false` disables Gazebo entirely, not just the window. Pass both `gui:=true headless:=true` for real headless mode.
- **OGRE2 unavailable on Ubuntu 26.04 aarch64** — confirmed on both source-built and apt-vendored Gazebo Jetty; GUI launches fail (`Failed to load plugin [ogre2]`) unless world files are patched `ogre2` → `ogre`. The resulting OGRE1 fallback renders visibly worse than the Jazzy+Harmonic baseline (OGRE2) — this is a reasonable inference from a qualitative comparison, not a rigorous frame-time benchmark.
- **`multibeam_sonar_system` missing `package.xml` dependencies** — `CMakeLists.txt` pulls in a neighboring package via `add_subdirectory` without declaring it, causing a parallel-build race condition. Fixed with 7 added `<depend>` tags — see the patch. Worth an upstream PR regardless of ROS distro.
- **ArduSub SITL build vs. Python 3.14** — `waf` and its `clang_compilation_database` extra import Python stdlib modules removed in modern Python: `imp` (removed 3.12) and `pipes` (removed 3.13). See [`notes/ardusub-sitl-setup.md`](notes/ardusub-sitl-setup.md) for the full fix (shims + non-root user + `PIP_BREAK_SYSTEM_PACKAGES=1`).
- **`xrdp` group permission (RDP screen setup)** — the `xrdp` daemon can't reach session sockets owned `<user>:root`; fix with `usermod -aG root xrdp` + full service restart.
- **GNOME is not usable as the RDP desktop on this OS** — Ubuntu 26.04 ships GNOME 50, which is Wayland-only (no GNOME X11 session). `xorgxrdp` is X11-only, so it cannot start a GNOME session here. This is an OS/RDP-stack incompatibility, not a container misconfiguration. XFCE still ships a full X11 session and works correctly with `xorgxrdp` — see [`docker/`](docker/).
- **Docker image password** — the `docker` user ships with password `docker` (see `docker/lyrical.arm64v8.dockerfile`) for local validation convenience only; change it before exposing the container beyond localhost.
- **`--privileged` on `docker run`** — currently used for simplicity; the minimal capability set xrdp/Xorg actually need has not been determined yet (follow-up item).
- **DAVE Wiki inaccuracies found while cross-checking** — see [`notes/dave-wiki-inaccuracies.md`](notes/dave-wiki-inaccuracies.md) (raw findings) and [`notes/wiki-error-reports.md`](notes/wiki-error-reports.md) (structured report draft). No page anywhere in the Wiki mentions Lyrical or Jetty, including pages edited as recently as this week. A possible duplicate Wiki database (two separate URLs, same page titles, dated 2026-06-26 and 2026-07-13) was flagged by an independent review — **not yet confirmed by us**; verify both URLs actually differ before reporting this to maintainers.

## Patch

[`patches/dave_lyrical_jetty_migration_mac.diff`](patches/dave_lyrical_jetty_migration_mac.diff) — base commit `6aef91c` on `naitikpahwa18/dave` (`wgpu_integration`), 8 files changed, +172/−147. Verified to apply identically and produce identical `git diff --stat` output on both macOS and Docker/Ubuntu 26.04. Full pattern breakdown in [`notes/cmake-migration-patterns.md`](notes/cmake-migration-patterns.md).

## Docker image

A reproducible Docker image (build instructions, verification commands, RDP desktop) lives in [`docker/`](docker/) — see [`docker/README.md`](docker/README.md) for the full build/run/verify walkthrough.

## Next steps

- [ ] Re-verify `docker/lyrical.arm64v8.dockerfile` from a clean (`--no-cache`) build — confirm RDP login reaches a usable XFCE desktop, not just the manually-patched container it was derived from
- [ ] Record image build time, image size, and minimum RAM for the Docker image
- [ ] Narrow `--privileged` on `docker run` to the minimal capabilities xrdp/Xorg need
- [ ] Report the DAVE Wiki inaccuracies to the Wiki maintainers (draft ready, see [`notes/wiki-error-reports.md`](notes/wiki-error-reports.md))
- [ ] Consider upstreaming the `package.xml` fix and reporting the OGRE2 gap
- [ ] Verify Ocean Current service names against the running container (`ros2 service list | grep current`) — the Wiki, our own notes, and a third-party review of the Wiki each name these services differently; none should be trusted without a live check

### August

- [ ] Define a shared `PASS` / `PARTIAL` / `NOT TESTED` matrix (`validation_matrix.csv`) and a repeatable test script (`test_worlds.sh`) before running the full sweep, so results are comparable run to run
- [ ] Exhaustive validation of all 18 worlds and documented vehicles/sensors (REXROV, BlueROV2, BlueROV2 Heavy, Slocum Glider), recording spawn success / crash / timeout per world
- [ ] Test the two `sonar-demo`-branch-only demos
- [ ] Re-attempt USBL and root-cause the GUI client crash (server/plugin path already confirmed working)
- [ ] Quantitative performance/accuracy benchmarking — Real Time Factor, CPU/memory, sonar frame time; report Mac (Metal) and Docker (llvmpipe) as separate environments rather than a single "N× faster" comparison, since OS, native-vs-container, and GPU-vs-CPU-renderer all vary at once between them
- [ ] Long-running stability test
- [ ] Decide sonar extension priority: Profiling vs. Mechanical Scanning vs. Side-scan

## References

- [DAVE (IOES-Lab fork)](https://github.com/IOES-Lab/dave)
- [PR #44 branch (naitikpahwa18/dave, wgpu_integration)](https://github.com/naitikpahwa18/dave/tree/wgpu_integration)
- [DAVE ROS2 Wiki](http://dave-ros2.notion.site)
- [ROS 2 Lyrical Luth — official docs](https://docs.ros.org)
- Choi, W. et al., "Physics-based modelling and simulation of Multibeam Echosounder perception for Autonomous Underwater Manipulation," *Frontiers in Robotics and AI*, 2021. [10.3389/frobt.2021.706646](https://doi.org/10.3389/frobt.2021.706646)
