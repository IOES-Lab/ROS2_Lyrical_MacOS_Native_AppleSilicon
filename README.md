# ROS 2 Lyrical / Gazebo Jetty — DAVE Migration Verification

```text
Status: Experimental / validation environment
Validated: Build, headless launch, XFCE/xrdp login, representative smoke tests
Not yet validated: all 18 worlds, quantitative performance
Known limitation: in the tested Ubuntu 26.04 image, the installed GNOME 50 session requires Wayland while xorgxrdp produces an X11 session; XFCE is used as the validated RDP desktop
```

## Purpose

This repository documents verifying whether [DAVE](https://github.com/IOES-Lab/dave) (underwater robotics simulation library, currently documented for ROS 2 Jazzy + Gazebo Harmonic) and its multibeam sonar plugin ([PR #44](https://github.com/IOES-Lab/dave/pull/44), CUDA-free WGPU backend) can be updated and run on the next-generation **ROS 2 Lyrical + Gazebo Jetty** combination.

Verified on both macOS (Apple Silicon, native) and Docker (Ubuntu 26.04). This is an **integration smoke test**, not exhaustive validation: DAVE's core packages and a representative set of vehicle, sensor, and multibeam-sonar paths were confirmed working end to end. Full coverage of every world/vehicle/sensor/launch combination is planned for August (see [Next steps](#next-steps)).

**Pinned commits** (so results here are reproducible against the exact code tested):

| Repo | Branch | Commit |
|---|---|---|
| `naitikpahwa18/dave` | `wgpu_integration` | [`6aef91c823af5da073329b84ba617b572965e79e`](https://github.com/IOES-Lab/dave/pull/44/commits/6aef91c823af5da073329b84ba617b572965e79e) (part of [PR #44](https://github.com/IOES-Lab/dave/pull/44)) |
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
| 2026-07-14 | DVL / underwater camera / ocean current / sea pressure sensors verified; USBL attempted | PASS 4 / PARTIAL 1 | DVL/camera/current/pressure launch and publish correctly; USBL server/plugin publishes but GUI client crashes — see [Verified demos](#verified-demos) |
| 2026-07-14 | BlueROV2 + ArduSub SITL built and launched | Done | Required fixing 5 chained Python 3.14 incompatibilities in `waf` — see [Known Issues](#known-issues) |
| 2026-07-14 | `git diff --stat` compared Mac vs Docker | Done | Identical: 8 files, +172/−147 |
| 2026-07-15 | Root-caused Docker RDP desktop crash | Done | XFCE + xrdp works; in the tested Ubuntu 26.04 image, the installed GNOME 50 session requires Wayland while xorgxrdp produces an X11 session, so GNOME could not be used as the RDP desktop here. `docker/` Dockerfile updated to install XFCE explicitly |
| 2026-07-15 | Clean (`--no-cache`) Docker build + RDP re-verified | Done | `lyrical-sim:jetty-rdp` built clean, RDP login reached a usable XFCE desktop, prompt `docker@lyrical_docker:~$` confirmed |
| 2026-07-17 | Docker CA-certificate bootstrap fix + clean (`--no-cache`) rebuild (Docker) | Done | `arm64v8/ubuntu:26.04` ships without `ca-certificates`, breaking HTTPS apt; fixed via digest-pinned `curlimages/curl` CA bundle copy plus `Acquire::https::CaInfo` on both `apt-get update` and `apt-get install`. Clean build succeeded end-to-end (image `lyrical-sim:jetty-rdp-pr1-ca-fix`), RDP login reached XFCE, `ROS_DISTRO=lyrical` and `dave_demos`/`multibeam_sonar_system` package presence confirmed — scoped to build + login + package-presence only, not a re-run of world/vehicle/performance rows; see `docker/README.md` Known limitations |
| 2026-07-18 | Ocean Current service names verified against a running container (Docker) | Done | Launched `dave_robot.launch.py world_name:=ocean_current_plugin` on `lyrical-sim:jetty-rdp-pr1-ca-fix` and ran `ros2 service list \| grep -i current`; real services are all under `/hydrodynamics/` (`set_current_velocity`, `set_current_horz_angle`, `set_current_vert_angle`, `set_stratified_current_*`, matching `get_*`/`*_model` variants, plus standard `underwater_current_ros_plugin` parameter services) — see Next steps for the full confirmed list |
| 2026-07-18 | Tested narrowing `--privileged` on `docker run` (Docker) | Done | Ran `lyrical-sim:jetty-rdp-pr1-ca-fix` with no `--privileged` and no extra `--cap-add`; RDP login still reached a working XFCE desktop (screenshot confirmed). `xorgxrdp` needs no host GPU device access in this image (`llvmpipe` software rendering). Documented `docker run` example updated to drop `--privileged` |
| 2026-07-18 | `rosdep \|\| true` masking check + mavros source-build + clean rebuild (Docker) | Done | Removing `\|\| true` surfaced a real failure: `ros-lyrical-mavros` not on apt for `lyrical` yet. Built mavros from source instead (official ros2-branch procedure); hit and fixed two real build bugs along the way — an `rm -rf /var/lib/apt/lists/*` wiping the apt index before rosdep needed it (self-inflicted, `libasio-dev` was never actually missing), and an OOM kill of `cc1plus` from unconstrained `make -j$(nproc)` on mavros's plugins (fixed by scoping `MAKEFLAGS=-j1` to that one colcon build). Clean `--no-cache` rebuild completed end-to-end: 51m 22s, 21.9GB image, 62.66MiB idle container RAM; `mavros`/`mavros_extras`/`mavros_msgs`/`mavros_examples` confirmed via `ros2 pkg list`. Also recovered a critical host-disk-full (133Mi free) + hung Docker Desktop daemon along the way — resolved by force-killing Docker, deleting and letting it recreate `Docker.raw`, and raising the Docker Desktop memory limit to 12GB |

## Reproduction

Run all commands below from the **repository root** (the parent directory of `dave/`, `patches/`, and `docker/`) — this is what makes the `../patches/...` relative path in the steps below resolve correctly.

### macOS (Apple Silicon, native)

```bash
git clone https://github.com/naitikpahwa18/dave.git
cd dave
git checkout 6aef91c823af5da073329b84ba617b572965e79e   # pinned commit, not the branch tip — see Pinned commits above
git apply ../patches/dave_lyrical_jetty_migration_mac.diff

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

This manual sequence assumes the ROS 2 apt repository (signing key + `sources.list.d` entry) is
already configured in the container/host — that setup step is omitted below since it's
environment-specific and not part of what this repo verifies. It is **not** a complete,
copy-pasteable procedure on a bare Ubuntu 26.04 image. The recommended, fully self-contained way
to reproduce the Docker environment is the Dockerfile in [`docker/`](docker/) — see
[`docker/README.md`](docker/README.md), which builds from a bare base image (including the
CA-certificate bootstrap and ROS apt source setup) end to end.

```bash
apt install -y ros-lyrical-desktop ros-lyrical-ros-gz

git clone https://github.com/naitikpahwa18/dave.git
cd dave
git checkout 6aef91c823af5da073329b84ba617b572965e79e   # pinned commit, not the branch tip — see Pinned commits above
git apply ../patches/dave_lyrical_jetty_migration_mac.diff   # identical diff applies cleanly on Linux too

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
| Docker RDP desktop (XFCE) | PASS | clean (`--no-cache`) build, RDP login reached a usable XFCE desktop, prompt `docker@lyrical_docker:~$` confirmed |
| `dave_ocean_waves_sonar`, `dave_ocean_waves_sonar_integrated` (sonar-demo branch) | NOT TESTED | needs `IOES-Lab/dave` `sonar-demo` branch, not on `naitikpahwa18/dave` |
| `dave_bimanual_example`, `dave_electrical_mating`, `dave_plug_and_socket` (manipulation) | NOT TESTED | out of scope this round |

18 world files exist under `models/dave_worlds/worlds/`; the rows in the table above show exactly which demos were run — per-world file names for full 18-world coverage have not been enumerated yet (tracked in [Next steps](#next-steps)).

## Known issues

- **`gui`/`headless` launch argument interaction** — `dave_sensor.launch.py` / `dave_robot.launch.py` gate the entire Gazebo process on `gui` (`condition=IfCondition(gui)`); `gui:=false` disables Gazebo entirely, not just the window. Pass both `gui:=true headless:=true` for real headless mode.
- **OGRE2 unavailable on Ubuntu 26.04 aarch64** — confirmed on both source-built and apt-vendored Gazebo Jetty; GUI launches fail (`Failed to load plugin [ogre2]`) unless world files are patched `ogre2` → `ogre`. The resulting OGRE1 fallback renders visibly worse than the Jazzy+Harmonic baseline (OGRE2) — this is a reasonable inference from a qualitative comparison, not a rigorous frame-time benchmark.
- **`multibeam_sonar_system` missing `package.xml` dependencies** — `CMakeLists.txt` pulls in a neighboring package via `add_subdirectory` without declaring it, causing a parallel-build race condition. Fixed with 7 added `<depend>` tags — see the patch. Worth an upstream PR regardless of ROS distro.
- **ArduSub SITL build vs. Python 3.14** — `waf` and its `clang_compilation_database` extra import Python stdlib modules removed in modern Python: `imp` (removed 3.12) and `pipes` (removed 3.13). See [`notes/ardusub-sitl-setup.md`](notes/ardusub-sitl-setup.md) for the full fix (shims + non-root user + `PIP_BREAK_SYSTEM_PACKAGES=1`).
- **`xrdp` group permission (RDP screen setup)** — the `xrdp` daemon can't reach session sockets owned `<user>:root`; fix with `usermod -aG root xrdp` + full service restart.
- **GNOME was not usable as the RDP desktop in the tested image** — the installed Ubuntu 26.04 GNOME 50 session required Wayland, while `xorgxrdp` produces an X11 session. XFCE still ships a full X11 session and worked correctly with `xorgxrdp` — see [`docker/`](docker/). This describes the tested image only, not every possible Ubuntu 26.04 GNOME/RDP configuration.
- **Docker image password** — the `docker` user ships with password `docker` (see `docker/lyrical.arm64v8.dockerfile`) for local validation convenience only; change it before exposing the container beyond localhost.
- **`--privileged` on `docker run` was tested and found unnecessary** (2026-07-18) — running the image with no `--privileged` flag and no extra `--cap-add` still reached a working RDP/XFCE login; `xorgxrdp` doesn't need host GPU device access in this image (`llvmpipe` software rendering, no `/dev/dri` passthrough). Dropped from the documented `docker run` example — see [`docker/README.md`](docker/README.md).
- **DAVE Wiki inaccuracies found while cross-checking** — see [`notes/dave-wiki-inaccuracies.md`](notes/dave-wiki-inaccuracies.md) (raw findings) and [`notes/wiki-error-reports.md`](notes/wiki-error-reports.md) (structured report draft). No page anywhere in the Wiki mentions Lyrical or Jetty, including pages edited as recently as this week.
- **`rosdep install ... || true` was masking a real failure** (confirmed 2026-07-18) — a clean rebuild with `|| true` removed from the install step failed with `E: Unable to locate package ros-lyrical-mavros`: this package is not yet published via apt for the `lyrical` distro. `|| true` is kept on that one line (the DAVE workspace's own rosdep pass) so the build doesn't hard-fail, but **mavros is now built from source separately** — see the next bullet — so this gap is resolved, not just tolerated.
- **mavros built from source and validated** (2026-07-18) — since `ros-lyrical-mavros` isn't available via apt yet (previous bullet), added a source-build stage to [`docker/lyrical.arm64v8.dockerfile`](docker/lyrical.arm64v8.dockerfile) following [mavros's official ros2-branch source-install procedure](https://github.com/mavlink/mavros/blob/ros2/mavros/README.md#source-installation). Two real build issues found and fixed along the way, both documented inline in the Dockerfile: (1) an `rm -rf /var/lib/apt/lists/*` earlier in the same block was wiping the apt index before rosdep's own `apt-get install` call could use it (self-inflicted, not an archive gap — `libasio-dev` was actually present the whole time); (2) mavros's plugin compilation OOM-killed `cc1plus` under the default parallel `make -j$(nproc)`, fixed by scoping `MAKEFLAGS=-j1` to just that one colcon build. Confirmed working: `ros2 pkg list` inside a running container lists `mavros`, `mavros_extras`, `mavros_msgs`, `mavros_examples`.

## Patch

[`patches/dave_lyrical_jetty_migration_mac.diff`](patches/dave_lyrical_jetty_migration_mac.diff) — base commit [`6aef91c`](https://github.com/IOES-Lab/dave/pull/44/commits/6aef91c823af5da073329b84ba617b572965e79e) on `naitikpahwa18/dave` (`wgpu_integration`, part of [PR #44](https://github.com/IOES-Lab/dave/pull/44)), 8 files changed, +172/−147. Verified to apply identically and produce identical `git diff --stat` output on both macOS and Docker/Ubuntu 26.04. Full pattern breakdown in [`notes/cmake-migration-patterns.md`](notes/cmake-migration-patterns.md).

## Docker image

A reproducible Docker image (build instructions, verification commands, RDP desktop) lives in [`docker/`](docker/) — see [`docker/README.md`](docker/README.md) for the full build/run/verify walkthrough.

## Next steps

- [ ] Record image build time, image size, and minimum RAM for the Docker image
- [x] Tested narrowing `--privileged` on `docker run` (2026-07-18) — found it's not needed at all; RDP/XFCE login worked with no `--privileged` and no extra `--cap-add`. Documented example updated.
- [ ] Report the DAVE Wiki inaccuracies to the Wiki maintainers (draft ready, see [`notes/wiki-error-reports.md`](notes/wiki-error-reports.md))
- [ ] Consider upstreaming the `package.xml` fix and reporting the OGRE2 gap
- [x] Verified Ocean Current service names against the running container (2026-07-18, `ros2 service list | grep -i current` on `lyrical-sim:jetty-rdp-pr1-ca-fix` after launching `dave_robot.launch.py world_name:=ocean_current_plugin`) — real names are all under the `/hydrodynamics/` namespace: `set_current_velocity`, `set_current_horz_angle`, `set_current_vert_angle`, `set_stratified_current_velocity`, `set_stratified_current_horz_angle`, `set_stratified_current_vert_angle`, matching `get_*`/`*_model` variants, plus the standard `underwater_current_ros_plugin` parameter services (`get_parameters`, `set_parameters`, etc.). This supersedes the Wiki/notes/third-party-review names, none of which matched.
- [x] Verified whether `rosdep install ... || true` in `docker/lyrical.arm64v8.dockerfile` is masking any real dependency-resolution failure (2026-07-18) — yes: `ros-lyrical-mavros` is not available via apt for `lyrical` yet. See [Known issues](#known-issues).
- [x] Resolved the `ros-lyrical-mavros` apt gap by building mavros from source (2026-07-18) — clean `--no-cache` rebuild completed successfully end to end; `mavros`/`mavros_extras`/`mavros_msgs`/`mavros_examples` all confirmed present via `ros2 pkg list` in a running container. See [Known issues](#known-issues).
- [x] Recorded Docker image build time, image size, and idle-container RAM (2026-07-18, clean `--no-cache` build including the mavros source-build stage): build time **51m 22s**, image size **21.9GB**, idle container memory **62.66MiB** (`docker stats`, container up with no active RDP session or Gazebo demo running — this is an idle floor, not a running-simulation figure; not yet measured under an active demo load)

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
- [PR #44 (IOES-Lab/dave)](https://github.com/IOES-Lab/dave/pull/44) — vendor-agnostic WGPU sonar backend
- [Pinned commit `6aef91c` (naitikpahwa18/dave, wgpu_integration)](https://github.com/naitikpahwa18/dave/commit/6aef91c823af5da073329b84ba617b572965e79e)
- [DAVE ROS2 Wiki](http://dave-ros2.notion.site)
- [ROS 2 Lyrical Luth — official docs](https://docs.ros.org)
- Choi, W. et al., "Physics-based modelling and simulation of Multibeam Echosounder perception for Autonomous Underwater Manipulation," *Frontiers in Robotics and AI*, 2021. [10.3389/frobt.2021.706646](https://doi.org/10.3389/frobt.2021.706646)
