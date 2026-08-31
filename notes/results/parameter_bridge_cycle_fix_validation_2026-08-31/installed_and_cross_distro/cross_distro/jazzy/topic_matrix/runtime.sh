#!/usr/bin/env bash
set -eo pipefail
OUT=/evidence/direct_runtime
mkdir -p "$OUT"
source /opt/ros/jazzy/setup.bash
source /ws2/install/local_setup.bash
export ROS_DOMAIN_ID=182
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
BIN=/ws2/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
test -x "$BIN"
printf 'ROS_DISTRO=jazzy\nARCH=%s\nBIN=%s\nPREFIX=%s\n'   "$(dpkg --print-architecture)" "$BIN" "$(ros2 pkg prefix ros_gz_bridge)" > "$OUT/environment.txt"

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

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1
"$BIN"   '/cross_g2r_string@std_msgs/msg/String[gz.msgs.StringMsg'   '/cross_g2r_double@std_msgs/msg/Float64[gz.msgs.Double'   '/cross_g2r_vector@geometry_msgs/msg/Vector3[gz.msgs.Vector3d'   '/cross_g2r_pose@geometry_msgs/msg/Pose[gz.msgs.Pose'   '/cross_r2g_string@std_msgs/msg/String]gz.msgs.StringMsg'   '/cross_r2g_double@std_msgs/msg/Float64]gz.msgs.Double'   '/cross_r2g_vector@geometry_msgs/msg/Vector3]gz.msgs.Vector3d'   '/cross_r2g_twist@geometry_msgs/msg/Twist]gz.msgs.Twist'   > "$OUT/topic_bridge.log" 2>&1 &
pid=$!
sleep 3

ros2 topic echo /cross_g2r_string --once --timeout 30 > "$OUT/g2r_string.txt" & e=$!; sleep 1
gz topic -t /cross_g2r_string -m gz.msgs.StringMsg -p 'data:"jazzy-g2r"'; wait "$e"
ros2 topic echo /cross_g2r_double --once --timeout 30 > "$OUT/g2r_double.txt" & e=$!; sleep 1
gz topic -t /cross_g2r_double -m gz.msgs.Double -p 'data:42.25'; wait "$e"
ros2 topic echo /cross_g2r_vector --once --timeout 30 > "$OUT/g2r_vector.txt" & e=$!; sleep 1
gz topic -t /cross_g2r_vector -m gz.msgs.Vector3d -p 'x:1.5 y:2.5 z:3.5'; wait "$e"
ros2 topic echo /cross_g2r_pose --once --timeout 30 > "$OUT/g2r_pose.txt" & e=$!; sleep 1
gz topic -t /cross_g2r_pose -m gz.msgs.Pose -p 'position:{x:4.0 y:5.0 z:6.0} orientation:{w:1.0}'; wait "$e"

gz topic -e -t /cross_r2g_string -n 1 > "$OUT/r2g_string.txt" & g=$!; sleep 1
ros2 topic pub /cross_r2g_string std_msgs/msg/String '{data: jazzy-r2g}' --once >/dev/null; wait "$g"
gz topic -e -t /cross_r2g_double -n 1 > "$OUT/r2g_double.txt" & g=$!; sleep 1
ros2 topic pub /cross_r2g_double std_msgs/msg/Float64 '{data: 84.5}' --once >/dev/null; wait "$g"
gz topic -e -t /cross_r2g_vector -n 1 > "$OUT/r2g_vector.txt" & g=$!; sleep 1
ros2 topic pub /cross_r2g_vector geometry_msgs/msg/Vector3 '{x: -1.25, y: 4.5, z: 8.75}' --once >/dev/null; wait "$g"
gz topic -e -t /cross_r2g_twist -n 1 > "$OUT/r2g_twist.txt" & g=$!; sleep 1
ros2 topic pub /cross_r2g_twist geometry_msgs/msg/Twist '{linear: {x: 1.0, y: 2.0, z: 3.0}, angular: {x: 0.1, y: 0.2, z: 0.3}}' --once >/dev/null; wait "$g"

grep -q 'jazzy-g2r' "$OUT/g2r_string.txt"
grep -q '42.25' "$OUT/g2r_double.txt"
grep -q '1.5' "$OUT/g2r_vector.txt"
grep -q 'x: 4.0' "$OUT/g2r_pose.txt"
grep -q 'jazzy-r2g' "$OUT/r2g_string.txt"
grep -q '84.5' "$OUT/r2g_double.txt"
grep -q -- '-1.25' "$OUT/r2g_vector.txt"
grep -q 'linear' "$OUT/r2g_twist.txt"
stop_pid "$pid" topic_bridge

cat > "$OUT/service_world.sdf" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.10"><world name="bridge_matrix">
<plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
<plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
<plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
</world></sdf>
SDF
gz sim -s -r "$OUT/service_world.sdf" > "$OUT/gz_server.log" 2>&1 &
gpid=$!
for _ in $(seq 1 80); do gz service -l 2>/dev/null | grep -q '^/world/bridge_matrix/control$' && break; sleep 0.25; done
gz service -l | grep '^/world/bridge_matrix/control$' > "$OUT/gz_control_service.txt"
"$BIN" '/world/bridge_matrix/control@ros_gz_interfaces/srv/ControlWorld' > "$OUT/service_bridge.log" 2>&1 &
spid=$!
for _ in $(seq 1 80); do ros2 service list 2>/dev/null | grep -q '^/world/bridge_matrix/control$' && break; sleep 0.25; done
ros2 service type /world/bridge_matrix/control > "$OUT/ros_service_type.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld '{world_control: {pause: true}}' > "$OUT/pause_response.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld '{world_control: {pause: false}}' > "$OUT/unpause_response.txt"
grep -q 'success=True' "$OUT/pause_response.txt"
grep -q 'success=True' "$OUT/unpause_response.txt"
stop_pid "$spid" service_bridge
stop_pid "$gpid" gz_server
printf 'build=PASS\ntopic_matrix=8/8\nservice_matrix=1/1\ntopic_exit=0\nservice_exit=0\n' > "$OUT/summary.txt"
