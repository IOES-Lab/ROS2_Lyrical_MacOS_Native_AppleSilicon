#!/usr/bin/env zsh
set -o pipefail

source /Users/gwon-yeseol/ros2_lyrical/.venv/bin/activate
source /Users/gwon-yeseol/ros2_lyrical/install/setup.zsh
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.zsh
source /Users/gwon-yeseol/dave_ws_lyrical/install/local_setup.zsh
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

OUT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/rov_direct_validation_2026-08-27/06_rexrov_ocean_mac
mkdir -p "$OUT/ros_logs"
export ROS_LOG_DIR="$OUT/ros_logs"

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1 || true
pgrep -x gz-sim-main 2>/dev/null | sort -n >"$OUT/gz_pids_before.txt" || true

ros2 launch dave_demos dave_robot.launch.py \
  z:=-5 namespace:=rexrov world_name:=dave_ocean_waves paused:=false \
  >"$OUT/launch.log" 2>&1 &
LAUNCH_PID=$!
echo "$LAUNCH_PID" >"$OUT/launch.pid"

cleanup() {
  kill -INT "$LAUNCH_PID" 2>/dev/null || true
  sleep 4
  kill -TERM "$LAUNCH_PID" 2>/dev/null || true
  wait "$LAUNCH_PID" 2>/dev/null || true
  pgrep -x gz-sim-main 2>/dev/null | sort -n >"$OUT/gz_pids_after.txt" || true
  comm -13 "$OUT/gz_pids_before.txt" "$OUT/gz_pids_after.txt" | while read -r pid; do
    test -n "$pid" && kill -TERM "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

for _ in $(seq 1 120); do
  grep -q 'Creating GZ->ROS Bridge.*camera/camera_info' "$OUT/launch.log" && break
  kill -0 "$LAUNCH_PID" 2>/dev/null || break
  sleep 1
done

python3 /Users/gwon-yeseol/Documents/Codex/2026-07-15/dave-ros-2-lyrical-validation/work/capture_rexrov.py \
  "$OUT/topic_samples.json" 90 >"$OUT/capture.log" 2>&1
grep -E \
  'Entity creation successful|Creating GZ->ROS Bridge|process has died|ERROR|Failed' \
  "$OUT/launch.log" >"$OUT/key_evidence.txt" || true
cat "$OUT/topic_samples.json"
