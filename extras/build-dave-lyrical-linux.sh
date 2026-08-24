#!/usr/bin/env bash
#
# Build DAVE and the PR #44 WGPU multibeam sonar on ROS 2 Lyrical + Gazebo Jetty (Ubuntu 26.04).
#
# This is the procedure from notes/setup/reproduction.md, made executable. Running it beats
# following prose: prose lets you skip a step and find out twenty minutes later.
#
# It is deliberately not clever. Every command is the one that was actually run, in order.
#
# Usage:
#   extras/build-dave-lyrical-linux.sh [workspace-dir]
#
# Default workspace is ./dave_ws next to this repository.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="${1:-$(dirname "$REPO_ROOT")/dave_ws}"
DAVE_COMMIT="6aef91c823af5da073329b84ba617b572965e79e"

say () { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die () { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preconditions

say "Checking preconditions"

[ -r /etc/os-release ] || die "Cannot read /etc/os-release. This script targets Ubuntu 26.04."
. /etc/os-release
[ "${VERSION_ID:-}" = "26.04" ] || cat >&2 <<EOF
!! This was verified on Ubuntu 26.04 (Resolute), the official target for ROS 2 Lyrical.
   You are on ${PRETTY_NAME:-unknown}. On 24.04, 'apt-cache search ros-lyrical' returns
   nothing at all -- this was tested. Continuing anyway; expect the apt step to fail.
EOF

command -v git >/dev/null     || die "git not found."
command -v colcon >/dev/null  || die "colcon not found. Install python3-colcon-common-extensions."

for p in "$REPO_ROOT/patches/dave_lyrical_jetty_migration_mac.diff"; do
  [ -f "$p" ] || die "Missing patch: $p"
done

# ---------------------------------------------------------------- ROS 2 + Gazebo

say "Installing ROS 2 Lyrical and ros_gz"

# ros-lyrical-ros-gz vendors Gazebo Jetty itself (gz_*_vendor). Building Gazebo from source
# first, as we did on 2026-07-06, turned out to be unnecessary -- see notes/progress-log.md.
sudo apt-get update
sudo apt-get install -y ros-lyrical-desktop ros-lyrical-ros-gz

# shellcheck disable=SC1091
source /opt/ros/lyrical/setup.bash

# ---------------------------------------------------------------- DAVE

say "Cloning DAVE at the pinned commit"

mkdir -p "$WS"
cd "$WS"

if [ ! -d dave ]; then
  git clone https://github.com/naitikpahwa18/dave.git
fi
cd dave

# The pinned commit, not the branch tip. The branch moves; the measurements in this
# repository were taken against this exact tree.
git fetch --all --quiet
git checkout --quiet "$DAVE_COMMIT"

say "Applying the Lyrical/Jetty migration patch"

# Applies cleanly on Linux despite the filename saying mac -- confirmed 2026-07-14 by
# producing an identical git diff --stat on both platforms.
if git apply --check "$REPO_ROOT/patches/dave_lyrical_jetty_migration_mac.diff" 2>/dev/null; then
  git apply "$REPO_ROOT/patches/dave_lyrical_jetty_migration_mac.diff"
else
  echo "   patch does not apply cleanly -- assuming it is already applied, continuing"
fi

# ---------------------------------------------------------------- build

# Three separate colcon invocations, sequential. This is not stylistic: building everything
# at once ran the machine out of memory on 2026-07-06, because colcon's parallelism and
# make's multiply. Sequential is slower and finishes.
#
# CMAKE_BUILD_TYPE=Release matters more than it looks. Without it colcon leaves the build
# type empty and nothing gets an -O flag -- RTF 0.2180 against 0.4380 on the sonar world,
# a 2.01x difference with no code change. See notes/sonar-performance.md.

CMAKE_ARGS=(--cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_TESTING=OFF -Wno-dev)

say "Building DAVE core packages"
colcon build --merge-install --executor sequential "${CMAKE_ARGS[@]}" --packages-select \
  dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
  dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
  dave_ros_gz_plugins dave_demos

say "Building the WGPU vendor package"
colcon build --merge-install --executor sequential "${CMAKE_ARGS[@]}" --packages-select wgpu_vendor

say "Building the multibeam sonar"
colcon build --merge-install --executor sequential "${CMAKE_ARGS[@]}" --packages-select \
  multibeam_sonar multibeam_sonar_system

# ---------------------------------------------------------------- verify

say "Verifying the build actually got optimised"

CC="$WS/dave/build/multibeam_sonar/compile_commands.json"
if [ -f "$CC" ]; then
  if grep -qo '\-O[123s]' "$CC"; then
    echo "   ok: $(grep -o '\-O[0-3s]*' "$CC" | sort | uniq -c | tr -s ' ' | paste -sd' ' -)"
  else
    die "No -O flag in the sonar's compile commands. CMAKE_BUILD_TYPE did not take effect.
    Every performance figure taken from this build would be wrong. Do not proceed."
  fi
else
  die "compile_commands.json not found; optimisation could not be verified.
  Do not proceed with performance measurements."
fi

cat <<EOF

$(say "Done")
Source the workspace and launch:

  source $WS/dave/install/setup.bash
  ros2 launch dave_demos dave_sensor.launch.py \\
    namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \\
    x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true

Notes worth knowing before you interpret anything you see:

  - gui:=true headless:=true together is the real headless mode. Not a typo.
  - The sonar sensor is not live until roughly 145-175 s after launch. Measuring before
    that describes a sonar-free world. See notes/known-issues.md.
  - If model spawning hangs, export FASTDDS_BUILTIN_TRANSPORTS=UDPv4 and retry. Fast DDS
    shared memory hangs ros_gz_sim create; with it on, spawning succeeded 1 time in 9.
EOF
