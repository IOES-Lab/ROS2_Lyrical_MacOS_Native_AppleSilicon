#!/usr/bin/env bash
#
# Build DAVE and the PR #44 WGPU multibeam sonar on ROS 2 Lyrical + Gazebo Jetty (macOS,
# Apple Silicon, native).
#
# This covers two of the three stages: the ros_gz underlay, and DAVE itself. The first
# stage -- building ROS 2 Lyrical from source -- is NOT covered, because the commands used
# on 2026-07-06 were not recorded. The script checks for its output and stops with an
# explanation rather than failing halfway through something else.
#
# Usage:
#   ROS2_LYRICAL_WS=~/ros2_lyrical extras/build-dave-lyrical-macos.sh [workspace-dir]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${1:-$(dirname "$REPO_ROOT")/dave_ws}"
ROS2_WS="${ROS2_LYRICAL_WS:-$HOME/ros2_lyrical}"
ROS_GZ_WS="${ROS_GZ_WS:-$HOME/ros_gz_ws_lyrical}"
DAVE_COMMIT="6aef91c823af5da073329b84ba617b572965e79e"
SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

say () { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die () { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preconditions

say "Checking preconditions"

[ "$(uname -s)" = "Darwin" ] || die "This script is for macOS. On Linux use build-dave-lyrical-linux.sh."
[ "$(uname -m)" = "arm64" ]  || echo "   warning: verified only on Apple Silicon; you are on $(uname -m)"

command -v brew >/dev/null || die "Homebrew not found. Gazebo Jetty is installed through it."

# The real Xcode SDK, not the Command Line Tools one. Building gz-sim / ros_gz_sim failed
# without -DCMAKE_OSX_SYSROOT pointing here.
[ -d "$SDK" ] || die "Xcode SDK not found at:
    $SDK
  The Command Line Tools SDK is not enough -- the ros_gz build needs the full Xcode SDK.
  Install Xcode, then run: sudo xcode-select -s /Applications/Xcode.app"

# ---- the stage this script cannot do for you -------------------------------------------

if [ ! -f "$ROS2_WS/install/setup.zsh" ]; then
  die "ROS 2 Lyrical was not found at:
    $ROS2_WS

  This script does not build it, and that is a real gap rather than an oversight.

  ROS 2 Lyrical has no macOS binary release, so it was built from source on 2026-07-06
  with GUI-related packages excluded. The exact commands were never written down -- the
  progress log records the outcome, not the invocation. Reconstructing them from memory
  would put commands in this repository that nobody has run, which is worse than a gap
  that says so.

  Two ways forward:
    1. Follow the official macOS source-build instructions at
       https://docs.ros.org/en/lyrical/Installation/Alternatives/macOS-Development-Setup.html
       then re-run this script with ROS2_LYRICAL_WS pointing at the result.
    2. Use Docker instead -- that path is complete and verified end to end:
       docker/README.md, or extras/build-dave-lyrical-linux.sh inside the container.

  If you already have it somewhere else:
    ROS2_LYRICAL_WS=/path/to/ws $0"
fi

# shellcheck disable=SC1091
source "$ROS2_WS/install/setup.zsh"

# ---------------------------------------------------------------- ros_gz underlay

if [ ! -f "$ROS_GZ_WS/install/setup.zsh" ]; then
  say "Building the ros_gz underlay at $ROS_GZ_WS"

  # ros_gz has no macOS binary for Lyrical, so it is built once into its own workspace.
  # Keep it at this path: DAVE's environment chains to this absolute location later.
  export CMAKE_PREFIX_PATH="/opt/homebrew:${CMAKE_PREFIX_PATH:-}"
  pip install psutil vcstool

  mkdir -p "$ROS_GZ_WS/src"
  cd "$ROS_GZ_WS"

  # 24 source repositories, each pinned to the commit it was actually built at. The list
  # was read off the built workspace with git remote/rev-parse, not reconstructed.
  vcs import src < "$REPO_ROOT/notes/setup/ros_gz_ws_lyrical.repos"

  git apply --directory=src/ros_gz "$REPO_ROOT/patches/ros_gz_lyrical_jetty_mac.diff"

  # vision_msgs_rviz_plugins and anything needing python_qt_binding are skipped: they are
  # GUI packages that do not build here and nothing in this validation uses them.
  colcon build --symlink-install \
    --packages-skip vision_msgs_rviz_plugins \
    --packages-skip-by-dep python_qt_binding \
    --cmake-args -DBUILD_TESTING=OFF -Wno-dev \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_SYSROOT="$SDK"
else
  say "ros_gz underlay already built at $ROS_GZ_WS -- skipping"
fi

# shellcheck disable=SC1091
source "$ROS_GZ_WS/install/setup.zsh"

# ---------------------------------------------------------------- DAVE

say "Cloning DAVE at the pinned commit"

mkdir -p "$WS"
cd "$WS"
[ -d dave ] || git clone https://github.com/naitikpahwa18/dave.git
cd dave
git fetch --all --quiet
git checkout --quiet "$DAVE_COMMIT"

say "Applying the Lyrical/Jetty migration patch"
if git apply --check "$REPO_ROOT/patches/dave_lyrical_jetty_migration_mac.diff" 2>/dev/null; then
  git apply "$REPO_ROOT/patches/dave_lyrical_jetty_migration_mac.diff"
else
  echo "   patch does not apply cleanly -- assuming it is already applied, continuing"
fi

say "Building DAVE and the sonar"

# CMAKE_BUILD_TYPE=Release is not optional. Without it colcon leaves the build type empty,
# nothing gets an -O flag, and the sonar world runs at RTF 0.2180 instead of 0.4380.
colcon build --symlink-install --packages-select \
  dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
  dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
  dave_ros_gz_plugins dave_demos \
  wgpu_vendor multibeam_sonar multibeam_sonar_system \
  --cmake-args -DBUILD_TESTING=OFF -Wno-dev \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_OSX_SYSROOT="$SDK"

# ---------------------------------------------------------------- verify

say "Verifying the build actually got optimised"

CC="$WS/dave/build/multibeam_sonar/compile_commands.json"
if [ -f "$CC" ] && grep -qo '\-O[123s]' "$CC"; then
  echo "   ok: $(grep -o '\-O[0-3s]*' "$CC" | sort | uniq -c | tr -s ' ' | paste -sd' ' -)"
else
  die "No -O flag in the sonar's compile commands. CMAKE_BUILD_TYPE did not take effect.
  Every performance figure taken from this build would be wrong. Do not proceed."
fi

cat <<EOF

$(say "Done")
Source the workspace and launch -- note .zsh, not .bash. Sourcing the bash script under
zsh breaks COLCON_CURRENT_PREFIX:

  source $WS/dave/install/setup.zsh
  ros2 launch dave_demos dave_sensor.launch.py \\
    namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \\
    x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true

  export FASTDDS_BUILTIN_TRANSPORTS=UDPv4    # if model spawning hangs

The sonar is not live until roughly 145-175 s after launch. See notes/known-issues.md.
EOF
