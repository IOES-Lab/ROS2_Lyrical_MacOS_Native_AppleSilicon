#!/usr/bin/env bash
set +u
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
source /home/docker/glider_validation/overlay_ws/install/local_setup.bash
set -u
export ROS_DOMAIN_ID=87
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DISPLAY=:10
export XAUTHORITY=/home/docker/.Xauthority
OUT=/home/docker/glider_validation/results/08_docker_deadband_bidirectional
mkdir -p "$OUT"
rm -f "$OUT"/*.txt "$OUT"/*.log "$OUT"/*.status 2>/dev/null || true

ros2 launch dave_demos dave_robot.launch.py \
  namespace:=glider_slocum world_name:=dave_ocean_waves paused:=false \
  x:=4 z:=-1.5 gui:=true headless:=true >"$OUT/launch.log" 2>&1 &
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

TOPIC=/model/glider_slocum/joint/propeller_joint/enable_deadband
for _ in $(seq 1 120); do
  if timeout -k 2 8 ros2 topic list --no-daemon --spin-time 3 2>/dev/null | grep -Fxq "$TOPIC"; then
    echo ready=yes > "$OUT/readiness.txt"
    break
  fi
  sleep 1
done
test -f "$OUT/readiness.txt" || { echo ready=no > "$OUT/readiness.txt"; exit 5; }

gz topic -i -t "$TOPIC" > "$OUT/gz_topic_info.txt" 2>&1 || true
timeout -k 2 10 ros2 topic info -v "$TOPIC" > "$OUT/ros_topic_info.txt" 2>&1 || true

timeout -k 2 15 ros2 topic echo "$TOPIC" --once --timeout 12 > "$OUT/ros_from_gz_true.txt" 2>&1 &
ROS_ECHO_PID=$!
sleep 2
gz topic -t "$TOPIC" -m gz.msgs.Boolean -p 'data: true' > "$OUT/gz_true_publish.txt" 2>&1
GZ_PUB_RC=$?
wait "$ROS_ECHO_PID"; ROS_ECHO_RC=$?
printf 'gz_publish_rc=%s\nros_echo_rc=%s\n' "$GZ_PUB_RC" "$ROS_ECHO_RC" > "$OUT/gz_to_ros.status"

timeout -k 2 15 gz topic -e -t "$TOPIC" -n 1 > "$OUT/gz_from_ros_true.txt" 2>&1 &
GZ_ECHO_PID=$!
sleep 2
timeout -k 2 8 ros2 topic pub --once "$TOPIC" std_msgs/msg/Bool '{data: true}' > "$OUT/ros_true_publish.txt" 2>&1
ROS_PUB_RC=$?
wait "$GZ_ECHO_PID"; GZ_ECHO_RC=$?
printf 'ros_publish_rc=%s\ngz_echo_rc=%s\n' "$ROS_PUB_RC" "$GZ_ECHO_RC" > "$OUT/ros_to_gz.status"

printf '\n== GZ TO ROS ==\n'
cat "$OUT/gz_to_ros.status" "$OUT/ros_from_gz_true.txt"
printf '\n== ROS TO GZ ==\n'
cat "$OUT/ros_to_gz.status" "$OUT/gz_from_ros_true.txt"
cleanup
trap - EXIT
