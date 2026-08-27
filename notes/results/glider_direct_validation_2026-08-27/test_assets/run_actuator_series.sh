#!/usr/bin/env bash
set -u

OUT=$1
mkdir -p "$OUT/ros_logs"
export ROS_LOG_DIR="$OUT/ros_logs"
TO=$(command -v gtimeout || command -v timeout)

ros2 launch dave_demos dave_robot.launch.py \
  namespace:=glider_slocum world_name:=dave_ocean_waves paused:=false \
  x:=4 z:=-1.5 > "$OUT/launch.log" 2>&1 &
LAUNCH_PID=$!
echo "$LAUNCH_PID" > "$OUT/launch.pid"

cleanup() {
  kill -INT "$LAUNCH_PID" 2>/dev/null || true
  sleep 4
  kill -TERM "$LAUNCH_PID" 2>/dev/null || true
  pkill -TERM -f 'gz-sim-main.*dave_ocean_waves.world' 2>/dev/null || true
  pkill -TERM -f 'parameter_bridge.*model/glider_slocum' 2>/dev/null || true
  sleep 2
  kill -KILL "$LAUNCH_PID" 2>/dev/null || true
  pkill -KILL -f 'gz-sim-main.*dave_ocean_waves.world' 2>/dev/null || true
  pkill -KILL -f 'parameter_bridge.*model/glider_slocum' 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 120); do
  if "$TO" -k 2 8 ros2 topic list --no-daemon --spin-time 3 2>/dev/null | \
     grep -Fxq '/model/glider_slocum/imu'; then
    echo 'ready=yes' > "$OUT/readiness.txt"
    break
  fi
  sleep 1
done
if [ ! -f "$OUT/readiness.txt" ]; then
  echo 'ready=no' > "$OUT/readiness.txt"
  exit 5
fi

BASE=/model/glider_slocum
"$TO" -k 2 15 gz topic -e -t "$BASE/odometry" -n 1 > "$OUT/gz_odometry_before.txt" 2>&1 || true
"$TO" -k 2 15 gz topic -e -t "$BASE/battery/battery/state" -n 1 > "$OUT/gz_battery_before.txt" 2>&1 || true

"$TO" -k 2 18 gz topic -e -t "$BASE/joint/propeller_joint/ang_vel" \
  > "$OUT/gz_ang_vel_series.txt" 2>&1 &
ANG_PID=$!
"$TO" -k 2 18 gz topic -e -t "$BASE/joint/propeller_joint/cmd_thrust" \
  > "$OUT/gz_cmd_thrust_series.txt" 2>&1 &
CMD_ECHO_PID=$!
"$TO" -k 2 15 gz topic -e -t "$BASE/joint/propeller_joint/enable_deadband" -n 1 \
  > "$OUT/gz_enable_deadband_received.txt" 2>&1 &
DEADBAND_ECHO_PID=$!
sleep 2

"$TO" -k 2 5 ros2 topic pub -r 5 \
  "$BASE/joint/propeller_joint/enable_deadband" std_msgs/msg/Bool '{data: false}' \
  > "$OUT/enable_deadband_command.txt" 2>&1 || true
"$TO" -k 2 10 ros2 topic pub -r 5 \
  "$BASE/joint/propeller_joint/cmd_thrust" std_msgs/msg/Float64 '{data: 25.0}' \
  > "$OUT/cmd_thrust_command.txt" 2>&1 || true

wait "$ANG_PID" 2>/dev/null || true
wait "$CMD_ECHO_PID" 2>/dev/null || true
wait "$DEADBAND_ECHO_PID" 2>/dev/null || true
"$TO" -k 2 15 gz topic -e -t "$BASE/odometry" -n 1 > "$OUT/gz_odometry_after.txt" 2>&1 || true
"$TO" -k 2 15 gz topic -e -t "$BASE/battery/battery/state" -n 1 > "$OUT/gz_battery_after.txt" 2>&1 || true

cleanup
trap - EXIT
