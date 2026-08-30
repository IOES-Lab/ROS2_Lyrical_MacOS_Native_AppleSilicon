#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-lyrical-sim:jetty-rdp-no-cache-20260830}"
OUT="${2:-.}"
mkdir -p "$OUT"

docker image inspect "$IMAGE" --format \
  'ID={{.Id}} Created={{.Created}} SizeBytes={{.Size}} Architecture={{.Architecture}} OS={{.Os}} User={{.Config.User}}' \
  | tee "$OUT/image_metadata.txt"

docker run --rm --entrypoint bash "$IMAGE" -lc '
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
source /home/docker/mavros_ws/install/setup.bash
set -u

echo "== PLATFORM =="
uname -m
. /etc/os-release
echo "$PRETTY_NAME"

echo "== ROS / GAZEBO =="
echo "ROS_DISTRO=$ROS_DISTRO"
command -v ros2
command -v gz
gz sim --versions

echo "== PACKAGE PREFIXES =="
ros2 pkg prefix dave_demos
ros2 pkg prefix multibeam_sonar
ros2 pkg prefix mavros
ros2 pkg prefix mavros_msgs

echo "== PINNED SOURCES =="
printf "DAVE_COMMIT="
git -C /home/docker/dave_ws/src/dave rev-parse HEAD
printf "GEOGRAPHIC_INFO_COMMIT="
git -C /home/docker/mavros_ws/src/geographic_info rev-parse HEAD
printf "ARDUPILOT_COMMIT="
git -c safe.directory=/home/docker/ardupilot \
  -C /home/docker/ardupilot rev-parse HEAD
printf "ARDUPILOT_GAZEBO_COMMIT="
git -c safe.directory=/home/docker/ardupilot_gazebo \
  -C /home/docker/ardupilot_gazebo rev-parse HEAD

echo "== REQUIRED ARTIFACTS =="
test -x /usr/local/bin/ardusub
test -f /home/docker/ardupilot_gazebo/build/libArduPilotPlugin.so
test -x /home/docker/QGC/AppRun
test "${QGC_NO_SYSTEM_GLIB:-}" = "1"
test -L /home/docker/.local/bin/qgroundcontrol
for vehicle in bluerov2 bluerov2_heavy bluerov2_heavy_multibeam_sonar; do
  cfg="/home/docker/dave_ws/install/share/dave_robot_models/config/$vehicle/robot_config.py"
  test -f "$cfg"
  grep -q -- '"--speedup"' "$cfg"
done

echo "IMAGE_VERIFICATION=PASS"
' | tee "$OUT/image_verification.txt"
