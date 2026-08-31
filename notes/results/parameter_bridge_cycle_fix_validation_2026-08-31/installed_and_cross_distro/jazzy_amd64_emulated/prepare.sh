#!/usr/bin/env bash
set -eo pipefail

OUT=/evidence/prepare
mkdir -p "$OUT"
printf 'ROS_DISTRO=jazzy\nARCH=%s\nSOURCE_COMMIT=%s\nEMULATION=linux/amd64_on_Apple_Silicon\n' \
  "$(dpkg --print-architecture)" "$(cat /source_commit.txt)" > "$OUT/environment.txt"
uname -a >> "$OUT/environment.txt"

apt-get -o Acquire::Retries=10 -o Acquire::http::Timeout=60 update \
  > "$OUT/apt_update.log" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get \
  -o Acquire::Retries=10 -o Acquire::http::Timeout=60 install -y \
  ros-jazzy-ros-gz-bridge ros-jazzy-ros-gz-sim \
  python3-colcon-common-extensions > "$OUT/apt_install.log" 2>&1

source /opt/ros/jazzy/setup.bash
mkdir -p /ws/src/ros_gz
cp -a /source/ros_gz_interfaces /source/ros_gz_bridge /ws/src/ros_gz/
cd /ws
export MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2
set +e
colcon build --executor sequential \
  --packages-select ros_gz_interfaces ros_gz_bridge \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
  > "$OUT/build.log" 2>&1
build_rc=$?
set -e
echo "$build_rc" > "$OUT/build_rc.txt"
test "$build_rc" -eq 0

source /ws/install/local_setup.bash
PREFIX="$(ros2 pkg prefix ros_gz_bridge)"
printf 'PREFIX=%s\n' "$PREFIX" | tee "$OUT/install_prefix.txt"
test "$PREFIX" = /ws/install/ros_gz_bridge
test -x /ws/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
printf 'prepare=PASS\nbuild=PASS\n' > "$OUT/summary.txt"
