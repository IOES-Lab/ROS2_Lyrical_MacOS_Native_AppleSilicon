#!/usr/bin/env bash
set +u
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
set -u
export ROS_DOMAIN_ID=88
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
OUT=/home/docker/glider_validation/results/09_docker_bool_bridge_isolation
mkdir -p "$OUT"
TOPIC=/codex_bool_test
ros2 run ros_gz_bridge parameter_bridge "$TOPIC@std_msgs/msg/Bool@gz.msgs.Boolean" > "$OUT/bridge.log" 2>&1 &
BRIDGE_PID=$!
cleanup() {
  kill -INT "$BRIDGE_PID" 2>/dev/null || true
  sleep 2
  kill -TERM "$BRIDGE_PID" 2>/dev/null || true
  kill -KILL "$BRIDGE_PID" 2>/dev/null || true
}
trap cleanup EXIT
sleep 4
timeout -k 2 10 ros2 topic info -v "$TOPIC" > "$OUT/ros_topic_info.txt" 2>&1 || true

timeout -k 2 15 gz topic -e -t "$TOPIC" -n 1 > "$OUT/gz_from_ros_true.txt" 2>&1 &
GZ_ECHO_PID=$!
sleep 2
timeout -k 2 8 ros2 topic pub --once "$TOPIC" std_msgs/msg/Bool '{data: true}' > "$OUT/ros_true_publish.txt" 2>&1
ROS_PUB_RC=$?
wait "$GZ_ECHO_PID"; GZ_ECHO_RC=$?
printf 'ros_publish_rc=%s\ngz_echo_rc=%s\n' "$ROS_PUB_RC" "$GZ_ECHO_RC" > "$OUT/ros_to_gz.status"

timeout -k 2 15 ros2 topic echo "$TOPIC" --once --timeout 12 > "$OUT/ros_from_gz_true.txt" 2>&1 &
ROS_ECHO_PID=$!
sleep 2
gz topic -t "$TOPIC" -m gz.msgs.Boolean -p 'data: true' > "$OUT/gz_true_publish.txt" 2>&1
GZ_PUB_RC=$?
wait "$ROS_ECHO_PID"; ROS_ECHO_RC=$?
printf 'gz_publish_rc=%s\nros_echo_rc=%s\n' "$GZ_PUB_RC" "$ROS_ECHO_RC" > "$OUT/gz_to_ros.status"

printf '\n== ISOLATED ROS TO GZ ==\n'
cat "$OUT/ros_to_gz.status" "$OUT/gz_from_ros_true.txt"
printf '\n== ISOLATED GZ TO ROS ==\n'
cat "$OUT/gz_to_ros.status" "$OUT/ros_from_gz_true.txt"
cleanup
trap - EXIT
