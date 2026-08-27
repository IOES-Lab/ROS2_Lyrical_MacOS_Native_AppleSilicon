#!/usr/bin/env bash
set -o pipefail

source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DISPLAY=:10
export XAUTHORITY=/home/docker/.Xauthority

OUT=/home/docker/rov_validation/rexrov_empty_exact
mkdir -p "$OUT/ros_logs"
export ROS_LOG_DIR="$OUT/ros_logs"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
ps -C gz-sim-main -o pid= 2>/dev/null | tr -d ' ' | sort -n >"$OUT/gz_pids_before.txt" || true

ros2 launch dave_demos dave_robot.launch.py \
  z:=2.0 namespace:=rexrov world_name:=empty.sdf paused:=false \
  use_teleop:=false use_web_joystick:=false \
  open_qgc:=false open_virtual_joystick:=false \
  >"$OUT/launch.log" 2>&1 &
LAUNCH_PID=$!
echo "$LAUNCH_PID" >"$OUT/launch.pid"

cleanup() {
  kill -INT "$LAUNCH_PID" 2>/dev/null || true
  sleep 4
  kill -TERM "$LAUNCH_PID" 2>/dev/null || true
  wait "$LAUNCH_PID" 2>/dev/null || true
  ps -C gz-sim-main -o pid= 2>/dev/null | tr -d ' ' | sort -n >"$OUT/gz_pids_after.txt" || true
  comm -13 "$OUT/gz_pids_before.txt" "$OUT/gz_pids_after.txt" | while read -r pid; do
    test -n "$pid" && kill -TERM "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

for _ in $(seq 1 90); do
  grep -q 'Creating GZ->ROS Bridge.*camera/camera_info' "$OUT/launch.log" && break
  kill -0 "$LAUNCH_PID" 2>/dev/null || break
  sleep 1
done

python3 /home/docker/rov_validation/capture_rexrov.py \
  "$OUT/topic_samples.json" >"$OUT/capture.log" 2>&1

grep -E \
  'Entity creation successful|Creating GZ->ROS Bridge|process has died|ERROR|Failed' \
  "$OUT/launch.log" >"$OUT/key_evidence.txt" || true
cat "$OUT/topic_samples.json"
