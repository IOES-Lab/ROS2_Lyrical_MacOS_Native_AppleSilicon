#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
source /home/docker/glider_validation/overlay_ws/install/local_setup.bash
set -u

export ROS_DOMAIN_ID=187
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DISPLAY=:10
export XAUTHORITY=/home/docker/.Xauthority

ROOT=/home/docker/full_gap_validation_2026-08-27/06_glider_deadband_integrated
OUT="$ROOT/run"
TOPIC=/model/glider_slocum/joint/propeller_joint/enable_deadband

test ! -e "$OUT"
mkdir -p "$OUT"

setsid ros2 launch dave_demos dave_robot.launch.py \
  namespace:=glider_slocum world_name:=dave_ocean_waves paused:=false \
  x:=4 z:=-1.5 gui:=true headless:=true \
  >"$OUT/launch.log" 2>&1 &
LAUNCH_PID=$!
PGID=$(ps -o pgid= -p "$LAUNCH_PID" | tr -d ' ')
printf 'launch_pid=%s\npgid=%s\n' "$LAUNCH_PID" "$PGID" >"$OUT/process_ids.txt"

cleanup() {
  kill -INT -- "-$PGID" 2>/dev/null || true
  sleep 5
  kill -TERM -- "-$PGID" 2>/dev/null || true
  sleep 2
  kill -KILL -- "-$PGID" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 150); do
  if timeout -k 2 8 ros2 topic list --no-daemon --spin-time 3 2>/dev/null \
      | grep -Fxq "$TOPIC"; then
    ready=1
    break
  fi
  sleep 1
done
printf 'ready=%s\n' "$ready" >"$OUT/readiness.txt"
test "$ready" -eq 1

gz topic -i -t "$TOPIC" >"$OUT/gz_topic_info_before.txt" 2>&1 || true
timeout -k 2 20 gz topic -e -t "$TOPIC" >"$OUT/gz_capture_during_ros_publish.txt" 2>&1 &
CAPTURE_PID=$!
sleep 2
timeout -k 2 15 ros2 topic pub -r 10 --times 50 \
  "$TOPIC" std_msgs/msg/Bool '{data: true}' \
  >"$OUT/ros_publish_true_50.txt" 2>&1
PUBLISH_RC=$?
wait "$CAPTURE_PID" || CAPTURE_RC=$?
CAPTURE_RC=${CAPTURE_RC:-0}

grep -E 'Passing message from ROS std_msgs/msg/Bool to Gazebo gz.msgs.Boolean' \
  "$OUT/launch.log" >"$OUT/bridge_ros_to_gz_log.txt" || true
TRUE_COUNT=$(grep -c 'data: true' "$OUT/gz_capture_during_ros_publish.txt" || true)
FALSE_COUNT=$(grep -c 'data: false' "$OUT/gz_capture_during_ros_publish.txt" || true)
printf 'ros_publish_rc=%s\ngz_capture_rc=%s\ntrue_count=%s\nfalse_count=%s\n' \
  "$PUBLISH_RC" "$CAPTURE_RC" "$TRUE_COUNT" "$FALSE_COUNT" \
  >"$OUT/verdict.txt"

cleanup
trap - EXIT

ps -eo pid,ppid,pgid,comm,args \
  | grep -E '[g]z-sim-main|[r]os2 launch|[p]arameter_bridge' \
  >"$OUT/processes_after_cleanup.txt" || true

cat "$OUT/verdict.txt"
