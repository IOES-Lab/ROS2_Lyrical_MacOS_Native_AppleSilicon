#!/usr/bin/env bash
set -eo pipefail

OUT=/evidence/runtime
mkdir -p "$OUT"
source /opt/ros/jazzy/setup.bash
source /ws/install/local_setup.bash
export ROS_DOMAIN_ID=187
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
BIN=/ws/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
test -x "$BIN"

stop_pid() {
  local pid="$1" label="$2" rc
  if kill -0 "$pid" 2>/dev/null; then kill -INT "$pid" 2>/dev/null || true; fi
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then
    echo TERM > "$OUT/${label}_escalation.txt"
    kill -TERM "$pid" 2>/dev/null || true
  else
    echo NONE > "$OUT/${label}_escalation.txt"
  fi
  set +e; wait "$pid"; rc=$?; set -e
  echo "$rc" > "$OUT/${label}_rc.txt"
  test "$rc" -eq 0
}

capture_g2r() {
  local topic="$1" gz_type="$2" payload="$3" file="$4"
  : > "$file"
  ros2 topic echo "$topic" --once --timeout 90 > "$file" 2> "${file%.txt}.stderr" &
  local echo_pid=$!
  for _ in $(seq 1 20); do
    sleep 1
    gz topic -t "$topic" -m "$gz_type" -p "$payload" || true
    test -s "$file" && break
    kill -0 "$echo_pid" 2>/dev/null || break
  done
  wait "$echo_pid"
  test -s "$file"
}

capture_r2g() {
  local topic="$1" ros_type="$2" payload="$3" file="$4"
  : > "$file"
  gz topic -e -t "$topic" -n 1 > "$file" 2> "${file%.txt}.stderr" &
  local echo_pid=$!
  for _ in $(seq 1 20); do
    sleep 1
    ros2 topic pub "$topic" "$ros_type" "$payload" --once >/dev/null || true
    test -s "$file" && break
    kill -0 "$echo_pid" 2>/dev/null || break
  done
  wait "$echo_pid"
  test -s "$file"
}

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1
"$BIN" \
  '/cross_g2r_string@std_msgs/msg/String[gz.msgs.StringMsg' \
  '/cross_g2r_double@std_msgs/msg/Float64[gz.msgs.Double' \
  '/cross_g2r_vector@geometry_msgs/msg/Vector3[gz.msgs.Vector3d' \
  '/cross_g2r_pose@geometry_msgs/msg/Pose[gz.msgs.Pose' \
  '/cross_r2g_string@std_msgs/msg/String]gz.msgs.StringMsg' \
  '/cross_r2g_double@std_msgs/msg/Float64]gz.msgs.Double' \
  '/cross_r2g_vector@geometry_msgs/msg/Vector3]gz.msgs.Vector3d' \
  '/cross_r2g_twist@geometry_msgs/msg/Twist]gz.msgs.Twist' \
  > "$OUT/topic_bridge.log" 2>&1 &
topic_pid=$!
sleep 5

capture_g2r /cross_g2r_string gz.msgs.StringMsg 'data:"jazzy-amd64-g2r"' "$OUT/g2r_string.txt"
capture_g2r /cross_g2r_double gz.msgs.Double 'data:42.25' "$OUT/g2r_double.txt"
capture_g2r /cross_g2r_vector gz.msgs.Vector3d 'x:1.5 y:2.5 z:3.5' "$OUT/g2r_vector.txt"
capture_g2r /cross_g2r_pose gz.msgs.Pose 'position:{x:4.0 y:5.0 z:6.0} orientation:{w:1.0}' "$OUT/g2r_pose.txt"
capture_r2g /cross_r2g_string std_msgs/msg/String '{data: jazzy-amd64-r2g}' "$OUT/r2g_string.txt"
capture_r2g /cross_r2g_double std_msgs/msg/Float64 '{data: 84.5}' "$OUT/r2g_double.txt"
capture_r2g /cross_r2g_vector geometry_msgs/msg/Vector3 '{x: -1.25, y: 4.5, z: 8.75}' "$OUT/r2g_vector.txt"
capture_r2g /cross_r2g_twist geometry_msgs/msg/Twist \
  '{linear: {x: 1.0, y: 2.0, z: 3.0}, angular: {x: 0.1, y: 0.2, z: 0.3}}' \
  "$OUT/r2g_twist.txt"

grep -q 'jazzy-amd64-g2r' "$OUT/g2r_string.txt"
grep -q '42.25' "$OUT/g2r_double.txt"
grep -q '1.5' "$OUT/g2r_vector.txt"
grep -q 'x: 4.0' "$OUT/g2r_pose.txt"
grep -q 'jazzy-amd64-r2g' "$OUT/r2g_string.txt"
grep -q '84.5' "$OUT/r2g_double.txt"
grep -q -- '-1.25' "$OUT/r2g_vector.txt"
grep -q 'linear' "$OUT/r2g_twist.txt"
stop_pid "$topic_pid" topic_bridge

cat > "$OUT/service_world.sdf" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.10"><world name="bridge_matrix">
<plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
<plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
<plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
</world></sdf>
SDF
gz sim -s -r "$OUT/service_world.sdf" > "$OUT/gz_server.log" 2>&1 &
sim_pid=$!
found=0
for _ in $(seq 1 240); do
  if timeout 5 gz service -l 2>/dev/null | grep -q '^/world/bridge_matrix/control$'; then found=1; break; fi
  sleep 0.25
done
test "$found" -eq 1
timeout 10 gz service -l | grep '^/world/bridge_matrix/control$' > "$OUT/gz_control_service.txt"
"$BIN" '/world/bridge_matrix/control@ros_gz_interfaces/srv/ControlWorld' \
  > "$OUT/service_bridge.log" 2>&1 &
service_pid=$!
found=0
for _ in $(seq 1 240); do
  if ros2 service list 2>/dev/null | grep -q '^/world/bridge_matrix/control$'; then found=1; break; fi
  sleep 0.25
done
test "$found" -eq 1
ros2 service type /world/bridge_matrix/control > "$OUT/ros_service_type.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld \
  '{world_control: {pause: true}}' > "$OUT/pause_response.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld \
  '{world_control: {pause: false}}' > "$OUT/unpause_response.txt"
grep -q 'success=True' "$OUT/pause_response.txt"
grep -q 'success=True' "$OUT/unpause_response.txt"
stop_pid "$service_pid" service_bridge
stop_pid "$sim_pid" gz_server

printf 'runtime=PASS\ntopic_matrix=8/8\nservice_matrix=1/1\ntopic_exit=0\nservice_exit=0\n' \
  > "$OUT/summary.txt"
