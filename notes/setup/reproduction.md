<!-- 이 문서는 README.md 에서 분리한 것이다. 2026-08-19 재편 전에는 README 안에 있었고,
     README 가 186 KB 로 불어나 읽기 어려워져 옮겼다. 내용은 그대로다. -->

# 재현 절차 — 주석 포함 전문

명령마다 왜 그 인자가 필요한지, 언제 무엇이 확인됐는지가 주석으로 붙어 있다.
짧은 판은 [`../../README.md`](../../README.md) 의 Reproduction 절에 있다.

## Reproduction

Run all commands below from the **repository root** (the parent directory of `dave/`, `patches/`, and `docker/`) — this is what makes the `../patches/...` relative path in the steps below resolve correctly.

### macOS (Apple Silicon, native)

**Note (added 2026-07-23):** the one-shot snippet below was flagged in a documentation audit as
incomplete — it's abbreviated from the actual sequence of steps recorded in the Progress Log
(2026-07-06 through 2026-07-08) and omits three real prerequisites confirmed against this
session's own shell history: a Python venv, a separately-built `ros_gz` underlay, and a macOS SDK
CMake flag. Corrected below.

**Prerequisite 1 — Python venv.** A venv (this session used `~/ros2_lyrical/.venv`) is activated
before every build/run command, ahead of anything else:

```bash
source ~/ros2_lyrical/.venv/bin/activate   # adjust path to wherever your venv lives
```

**Prerequisite 2 — `ros_gz` built from source, in its own workspace.** ROS 2 Lyrical + Gazebo
Jetty's `ros_gz` bridge is not available prebuilt for macOS, so it's built from source once into a
separate workspace (this session used `~/ros_gz_ws_lyrical`). Its exact 24 source repositories
(containing multiple ROS packages each — 47 `package.xml` files / ~35 ROS packages actually built
from them), the source repo URLs, and the precise commit each was built at are captured in
[`notes/ros_gz_ws_lyrical.repos`](ros_gz_ws_lyrical.repos) (added 2026-07-23, read directly
off the built workspace via `git remote get-url origin` + `git rev-parse HEAD` per package, not
reconstructed from memory) — a corrected list versus an earlier draft of this section, which
misread a terminal paste and included a nonexistent `gz_ogre_next_vendor` package. Building this
workspace needs the real Xcode SDK path, not just the Command Line Tools' —
`-DCMAKE_OSX_SYSROOT` pointing at the installed Xcode's `MacOSX.sdk` was required for at least the
`gz-sim`/`ros_gz_sim` build step to succeed:

```bash
# Confirmed 2026-07-23 via this session's actual .zsh_history (not guessed): building ros_gz
# from source needs ROS 2 Lyrical's OWN underlay sourced first (rclcpp/ament_cmake etc. come
# from there), not just the venv. This session's workspace was ~/ros2_lyrical:
source ~/ros2_lyrical/install/setup.zsh   # adjust path if your ROS 2 Lyrical workspace differs

# Confirmed 2026-07-23 via .zsh_history (previously flagged as unverified, now confirmed real):
# CMake needs Homebrew's prefix on CMAKE_PREFIX_PATH to find brew-installed deps (e.g. tinyxml2,
# CLI11) during the ros_gz build. psutil was also confirmed present in the same history near these
# commands -- its exact consumer wasn't independently re-traced (not used by the shell scripts in
# notes/, which use plain `ps`), but it's included here since the history confirms it was actually
# installed as part of this workflow:
export CMAKE_PREFIX_PATH="/opt/homebrew:$CMAKE_PREFIX_PATH"
pip install psutil vcstool

# built at ~/ros_gz_ws_lyrical specifically -- DAVE's own environment chains to source
# this exact absolute path later, so keep it here rather than an arbitrary location
mkdir -p ~/ros_gz_ws_lyrical/src && cd ~/ros_gz_ws_lyrical
vcs import src < ~/ROS2_Lyrical_review_fixes/notes/ros_gz_ws_lyrical.repos

# Local, uncommitted CMakeLists.txt changes this session actually built against (confirmed
# 2026-07-23 via `git diff` on the real workspace) -- not present in the pinned commits
# themselves, so apply on top of the fresh checkout:
git apply --directory=src/ros_gz ~/ROS2_Lyrical_review_fixes/patches/ros_gz_lyrical_jetty_mac.diff

# --package-skip flags added 2026-07-23: this session's actual shell history (per the
# vision_msgs_rviz_plugins local_setup.zsh warning documented below) shows these two
# were excluded from the build, but the colcon command previously documented here omitted
# the flags that do that -- added for consistency with the rest of this section.
colcon build --symlink-install \
  --packages-skip vision_msgs_rviz_plugins \
  --packages-skip-by-dep python_qt_binding \
  --cmake-args -DBUILD_TESTING=OFF -Wno-dev \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

# -DCMAKE_BUILD_TYPE=Release added 2026-08-05 -- colcon otherwise leaves the build
# type empty and nothing here gets an -O flag. The gz_*_vendor packages compile
# nothing (they wrap the Homebrew Gazebo), so this only affects ros_gz's own
# packages, but there is no reason to build those unoptimised either.
# See notes/results/release_rebuild_2026-08-05/.

source ~/ros_gz_ws_lyrical/install/setup.zsh

# Return to the repository root before continuing -- the DAVE clone/build steps below assume
# they're run from here (that's what makes their `../patches/...` relative path resolve).
cd ~/ROS2_Lyrical_review_fixes   # adjust to wherever this repo is actually cloned
```

**Local ros_gz patch (found 2026-07-23, now resolved):** `ros_gz_ws_lyrical.repos` pins the exact
commit of each of the 24 repositories, but did **not** capture two local, uncommitted
modifications this session actually built against — confirmed via `git diff` against the real
workspace and now captured as
[`patches/ros_gz_lyrical_jetty_mac.diff`](../../patches/ros_gz_lyrical_jetty_mac.diff) (applied above,
after `vcs import`, before `colcon build`): `ros_gz_bridge/CMakeLists.txt` adds
`find_package(tinyxml2 REQUIRED)`; `ros_gz_sim/CMakeLists.txt` adds both a `CLI11::CLI11`
include-dir shim (`if(TARGET CLI11::CLI11 AND NOT DEFINED CLI11_INCLUDE_DIRS) ... endif()`) and
`find_package(tinyxml2 REQUIRED)` — the real workspace has this `tinyxml2` line duplicated twice
in a row in `ros_gz_sim/CMakeLists.txt` (harmless, evidently an accidental leftover from iterative
debugging), preserved as-is in the patch for exact reproducibility of what was actually built and
tested, rather than silently "cleaning it up" into a state that was never verified.

**Not yet done:** this exact `vcs import` + patch + clean-build sequence hasn't been independently
re-verified end to end from a fresh checkout — the `.repos` file and the patch above were both
captured from an already-built workspace, so treat this as the best available record of what was
actually used, not yet a proven-reproducible recipe run from zero. **Resolved 2026-07-23:** the
`CMAKE_PREFIX_PATH`/`psutil` gap flagged in an earlier review pass was checked against this
session's real `.zsh_history` and confirmed — both are now included as real commands above,
not a guess.

**Then the DAVE build itself** — note the package list below was also corrected: the original
snippet only built DAVE's core 10 packages and skipped the WGPU sonar packages entirely, so a
fresh checkout following just the old snippet could not actually run the multibeam-sonar demo the
next command launches:

```bash
git clone https://github.com/naitikpahwa18/dave.git
cd dave
git checkout 6aef91c823af5da073329b84ba617b572965e79e   # pinned commit, not the branch tip — see Pinned commits above
git apply ../patches/dave_lyrical_jetty_migration_mac.diff

colcon build --symlink-install --packages-select \
  dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
  dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
  dave_ros_gz_plugins dave_demos \
  wgpu_vendor multibeam_sonar multibeam_sonar_system \
  --cmake-args -DBUILD_TESTING=OFF -Wno-dev \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

# -DCMAKE_BUILD_TYPE=Release added 2026-08-05. THIS ONE MATTERS.
# Without it colcon leaves CMAKE_BUILD_TYPE empty, so no DAVE package gets an -O
# flag and the whole workspace builds unoptimised. Measured on the sonar world at
# default settings: RTF 0.2180 -> 0.4380, a 2.01x speed-up with no code change.
# Every performance figure in this README dated before 2026-08-05 was taken
# without it.
# Verify -- expect -O3, not an empty result:
#   grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
# See notes/results/release_rebuild_2026-08-05/.

source install/setup.zsh   # zsh — sourcing .bash under zsh breaks COLCON_CURRENT_PREFIX
# dave_ws's own setup.zsh chains to source the ros_gz_ws_lyrical underlay automatically;
# expect one specific warning here: "not found: .../ros_gz_ws_lyrical/install/
# vision_msgs_rviz_plugins/share/vision_msgs_rviz_plugins/local_setup.zsh" -- confirmed
# seen repeatedly this session with no other effect on the launch. **Narrowed 2026-07-23
# (caught in review):** this was previously described as an expected/normal consequence of
# excluding vision_msgs_rviz_plugins from the build -- that's too broad a claim. The real
# workspace shows `install/vision_msgs_rviz_plugins/` partially present (a `package.dsv`
# exists, but no `local_setup.zsh`), which points to a leftover from an earlier partial/
# failed install in this session's *reused* workspace, not something guaranteed to
# reproduce if the package is cleanly skipped from a genuinely fresh workspace. Treat this
# specific warning as benign *for this session's workspace*, not as a documented, guaranteed
# behavior of the build. Other missing-local_setup warnings for different packages have NOT
# been characterized and should not be assumed equally benign without checking.

ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
  x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

**Update (2026-07-23):** the exact `ros_gz_ws_lyrical/src` package versions/tags are now captured
in [`notes/ros_gz_ws_lyrical.repos`](ros_gz_ws_lyrical.repos), read directly off the built
workspace. Still open: that manifest was captured from an already-built workspace, not proven by
importing it fresh into an empty directory and rebuilding from zero — treat it as the best
available record of what was actually used, not yet a fully verified one-command rebuild.

### Docker (Ubuntu 26.04)

This manual sequence assumes the ROS 2 apt repository (signing key + `sources.list.d` entry) is
already configured in the container/host — that setup step is omitted below since it's
environment-specific and not part of what this repo verifies. It is **not** a complete,
copy-pasteable procedure on a bare Ubuntu 26.04 image. The recommended, fully self-contained way
to reproduce the Docker environment is the Dockerfile in [`docker/`](../../docker/) — see
[`docker/README.md`](../../docker/README.md), which builds from a bare base image (including the
CA-certificate bootstrap and ROS apt source setup) end to end.

```bash
apt update
apt install -y ros-lyrical-desktop ros-lyrical-ros-gz
source /opt/ros/lyrical/setup.bash   # fixed 2026-07-23: this step was missing -- the DAVE colcon
                                      # build below needs ROS 2 Lyrical's own underlay sourced first

git clone https://github.com/naitikpahwa18/dave.git
cd dave
git checkout 6aef91c823af5da073329b84ba617b572965e79e   # pinned commit, not the branch tip — see Pinned commits above
git apply ../patches/dave_lyrical_jetty_migration_mac.diff   # identical diff applies cleanly on Linux too

# IMPORTANT (added 2026-08-05): -DCMAKE_BUILD_TYPE=Release.
# Without it colcon leaves CMAKE_BUILD_TYPE empty, so nothing is compiled with -O
# and every DAVE package builds unoptimised. Measured effect on the sonar world:
# RTF 0.2180 -> 0.4380 at the default sensor configuration, a 2.01x speed-up, with
# no code change. All performance figures in this README that predate 2026-08-05
# were taken without it. See notes/results/release_rebuild_2026-08-05/.
colcon build --merge-install --executor sequential \
  --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select \
  dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
  dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
  dave_ros_gz_plugins dave_demos
colcon build --merge-install --executor sequential \
  --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select wgpu_vendor
colcon build --merge-install --executor sequential \
  --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select multibeam_sonar multibeam_sonar_system

# Verify it took effect -- expect -O3, not an empty result:
#   grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
# (add -DCMAKE_EXPORT_COMPILE_COMMANDS=ON above if compile_commands.json is absent)

source install/setup.bash

# Pre-candidate installed workspace: gui:=true headless:=true is the verified headless form.
# The 2026-08-29 candidate also supports gui:=false or headless:=true independently.
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
  x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

### Validation matrix format

[`notes/validation_matrix.csv`](../validation_matrix.csv) uses a fixed vocabulary so the file can be counted
programmatically without string-matching on free text:

| column | values |
|---|---|
| `status` | exactly one of `SMOKE PASS`, `FUNCTIONAL PASS`, `FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS`, `PARTIAL`, `NOT AUTOMATED` — no dates |
| `workaround` | `TRUE` if the pass depends on a patch or launch-arg workaround rather than stock behaviour, else `FALSE` |
| `evidence_date` | date of the evidence the current `status` rests on, not the date the row was first written |
| `notes` | full prose history, including superseded findings and what is inferred vs. directly confirmed |

`SMOKE PASS` means the process stayed alive without crashing; it does **not** imply the world's functionality was
checked. `FUNCTIONAL PASS` requires real topic/service data on record. `FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS`
adds that the functional path still depends on documented non-stock or launch constraints. Two rows currently carry
`workaround = TRUE`: `new_dvl` (Fuel URI patch) and `usbl_tutorial` (positive-sigma world patch, world-only launcher,
and an unpaused simulation so the plugin can pump ROS callbacks).
