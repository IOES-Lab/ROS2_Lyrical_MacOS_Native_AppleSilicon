#!/usr/bin/env bash
set -eo pipefail

WS=/Users/gwon-yeseol/ros_gz_ws_lyrical
OUT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/expanded_runtime
mkdir -p "$OUT"
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source "$WS/install/local_setup.bash"
export ROS_DOMAIN_ID=190
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
BIN="$WS/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge"
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
  ros2 topic echo "$topic" --once --timeout 60 > "$file" 2> "${file%.txt}.stderr" &
  local pid=$!
  for _ in $(seq 1 12); do
    sleep 1
    gz topic -t "$topic" -m "$gz_type" -p "$payload" || true
    test -s "$file" && break
    kill -0 "$pid" 2>/dev/null || break
  done
  wait "$pid"
  test -s "$file"
}

capture_r2g() {
  local topic="$1" ros_type="$2" payload="$3" file="$4"
  : > "$file"
  gz topic -e -t "$topic" -n 1 > "$file" 2> "${file%.txt}.stderr" &
  local pid=$!
  for _ in $(seq 1 12); do
    sleep 1
    ros2 topic pub "$topic" "$ros_type" "$payload" --once >/dev/null || true
    test -s "$file" && break
    kill -0 "$pid" 2>/dev/null || break
  done
  wait "$pid"
  test -s "$file"
}

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1

"$BIN" \
  '/mx_g2r_string@std_msgs/msg/String[gz.msgs.StringMsg' \
  '/mx_g2r_double@std_msgs/msg/Float64[gz.msgs.Double' \
  '/mx_g2r_vector@geometry_msgs/msg/Vector3[gz.msgs.Vector3d' \
  '/mx_g2r_pose@geometry_msgs/msg/Pose[gz.msgs.Pose' \
  '/mx_g2r_bool@std_msgs/msg/Bool[gz.msgs.Boolean' \
  '/mx_g2r_int32@std_msgs/msg/Int32[gz.msgs.Int32' \
  '/mx_g2r_uint32@std_msgs/msg/UInt32[gz.msgs.UInt32' \
  '/mx_g2r_float32@std_msgs/msg/Float32[gz.msgs.Float' \
  '/mx_g2r_quaternion@geometry_msgs/msg/Quaternion[gz.msgs.Quaternion' \
  '/mx_g2r_wrench@geometry_msgs/msg/Wrench[gz.msgs.Wrench' \
  '/mx_g2r_clock@rosgraph_msgs/msg/Clock[gz.msgs.Clock' \
  '/mx_g2r_pressure@sensor_msgs/msg/FluidPressure[gz.msgs.FluidPressure' \
  '/mx_r2g_string@std_msgs/msg/String]gz.msgs.StringMsg' \
  '/mx_r2g_double@std_msgs/msg/Float64]gz.msgs.Double' \
  '/mx_r2g_vector@geometry_msgs/msg/Vector3]gz.msgs.Vector3d' \
  '/mx_r2g_twist@geometry_msgs/msg/Twist]gz.msgs.Twist' \
  '/mx_r2g_bool@std_msgs/msg/Bool]gz.msgs.Boolean' \
  '/mx_r2g_int32@std_msgs/msg/Int32]gz.msgs.Int32' \
  '/mx_r2g_uint32@std_msgs/msg/UInt32]gz.msgs.UInt32' \
  '/mx_r2g_float32@std_msgs/msg/Float32]gz.msgs.Float' \
  '/mx_r2g_quaternion@geometry_msgs/msg/Quaternion]gz.msgs.Quaternion' \
  '/mx_r2g_wrench@geometry_msgs/msg/Wrench]gz.msgs.Wrench' \
  '/mx_r2g_clock@rosgraph_msgs/msg/Clock]gz.msgs.Clock' \
  '/mx_r2g_pressure@sensor_msgs/msg/FluidPressure]gz.msgs.FluidPressure' \
  > "$OUT/topic_bridge.log" 2>&1 &
topic_pid=$!
sleep 15

capture_g2r /mx_g2r_string gz.msgs.StringMsg 'data:"matrix-g2r"' "$OUT/g2r_string.txt"
capture_g2r /mx_g2r_double gz.msgs.Double 'data:42.25' "$OUT/g2r_double.txt"
capture_g2r /mx_g2r_vector gz.msgs.Vector3d 'x:1.5 y:2.5 z:3.5' "$OUT/g2r_vector.txt"
capture_g2r /mx_g2r_pose gz.msgs.Pose 'position:{x:4 y:5 z:6} orientation:{w:1}' "$OUT/g2r_pose.txt"
capture_g2r /mx_g2r_bool gz.msgs.Boolean 'data:true' "$OUT/g2r_bool.txt"
capture_g2r /mx_g2r_int32 gz.msgs.Int32 'data:-123' "$OUT/g2r_int32.txt"
capture_g2r /mx_g2r_uint32 gz.msgs.UInt32 'data:456' "$OUT/g2r_uint32.txt"
capture_g2r /mx_g2r_float32 gz.msgs.Float 'data:7.25' "$OUT/g2r_float32.txt"
capture_g2r /mx_g2r_quaternion gz.msgs.Quaternion 'x:0.1 y:0.2 z:0.3 w:0.9' "$OUT/g2r_quaternion.txt"
capture_g2r /mx_g2r_wrench gz.msgs.Wrench 'force:{x:1 y:2 z:3} torque:{x:0.1 y:0.2 z:0.3}' "$OUT/g2r_wrench.txt"
capture_g2r /mx_g2r_clock gz.msgs.Clock 'sim:{sec:123 nsec:456000000}' "$OUT/g2r_clock.txt"
capture_g2r /mx_g2r_pressure gz.msgs.FluidPressure 'pressure:101325 variance:9' "$OUT/g2r_pressure.txt"

capture_r2g /mx_r2g_string std_msgs/msg/String '{data: matrix-r2g}' "$OUT/r2g_string.txt"
capture_r2g /mx_r2g_double std_msgs/msg/Float64 '{data: 84.5}' "$OUT/r2g_double.txt"
capture_r2g /mx_r2g_vector geometry_msgs/msg/Vector3 '{x: -1.25, y: 4.5, z: 8.75}' "$OUT/r2g_vector.txt"
capture_r2g /mx_r2g_twist geometry_msgs/msg/Twist '{linear: {x: 1, y: 2, z: 3}, angular: {x: 0.1, y: 0.2, z: 0.3}}' "$OUT/r2g_twist.txt"
capture_r2g /mx_r2g_bool std_msgs/msg/Bool '{data: true}' "$OUT/r2g_bool.txt"
capture_r2g /mx_r2g_int32 std_msgs/msg/Int32 '{data: -321}' "$OUT/r2g_int32.txt"
capture_r2g /mx_r2g_uint32 std_msgs/msg/UInt32 '{data: 654}' "$OUT/r2g_uint32.txt"
capture_r2g /mx_r2g_float32 std_msgs/msg/Float32 '{data: 8.5}' "$OUT/r2g_float32.txt"
capture_r2g /mx_r2g_quaternion geometry_msgs/msg/Quaternion '{x: 0.4, y: 0.3, z: 0.2, w: 0.8}' "$OUT/r2g_quaternion.txt"
capture_r2g /mx_r2g_wrench geometry_msgs/msg/Wrench '{force: {x: 4, y: 5, z: 6}, torque: {x: 0.4, y: 0.5, z: 0.6}}' "$OUT/r2g_wrench.txt"
capture_r2g /mx_r2g_clock rosgraph_msgs/msg/Clock '{clock: {sec: 321, nanosec: 654000000}}' "$OUT/r2g_clock.txt"
capture_r2g /mx_r2g_pressure sensor_msgs/msg/FluidPressure '{fluid_pressure: 202650.0, variance: 4.0}' "$OUT/r2g_pressure.txt"

grep -q 'matrix-g2r' "$OUT/g2r_string.txt"
grep -q '42.25' "$OUT/g2r_double.txt"
grep -q 'x: 1.5' "$OUT/g2r_vector.txt"
grep -q 'x: 4.0' "$OUT/g2r_pose.txt"
grep -q 'data: true' "$OUT/g2r_bool.txt"
grep -q -- '-123' "$OUT/g2r_int32.txt"
grep -q '456' "$OUT/g2r_uint32.txt"
grep -q '7.25' "$OUT/g2r_float32.txt"
grep -q 'w: 0.9' "$OUT/g2r_quaternion.txt"
grep -q 'force:' "$OUT/g2r_wrench.txt"
grep -q 'sec: 123' "$OUT/g2r_clock.txt"
grep -q '101325' "$OUT/g2r_pressure.txt"
grep -q 'matrix-r2g' "$OUT/r2g_string.txt"
grep -q '84.5' "$OUT/r2g_double.txt"
grep -q -- '-1.25' "$OUT/r2g_vector.txt"
grep -q 'linear' "$OUT/r2g_twist.txt"
grep -q 'data: true' "$OUT/r2g_bool.txt"
grep -q -- '-321' "$OUT/r2g_int32.txt"
grep -q '654' "$OUT/r2g_uint32.txt"
grep -q '8.5' "$OUT/r2g_float32.txt"
grep -q 'w: 0.8' "$OUT/r2g_quaternion.txt"
grep -q 'force' "$OUT/r2g_wrench.txt"
grep -q 'sec: 321' "$OUT/r2g_clock.txt"
grep -q '202650' "$OUT/r2g_pressure.txt"
stop_pid "$topic_pid" topic_bridge

cat > "$OUT/service_world.sdf" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.10"><world name="expanded_matrix">
<plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
<plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
<plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
</world></sdf>
SDF
gz sim -s -r "$OUT/service_world.sdf" > "$OUT/gz_server.log" 2>&1 &
sim_pid=$!
found=0
for _ in $(seq 1 160); do
  if timeout 3 gz service -l 2>/dev/null | grep -q '^/world/expanded_matrix/control$'; then found=1; break; fi
  sleep 0.25
done
test "$found" -eq 1
timeout 5 gz service -l | grep '^/world/expanded_matrix/' | sort > "$OUT/gz_world_services.txt"

"$BIN" \
  '/world/expanded_matrix/control@ros_gz_interfaces/srv/ControlWorld' \
  '/world/expanded_matrix/create@ros_gz_interfaces/srv/SpawnEntity' \
  '/world/expanded_matrix/set_pose@ros_gz_interfaces/srv/SetEntityPose' \
  '/world/expanded_matrix/remove@ros_gz_interfaces/srv/DeleteEntity' \
  > "$OUT/service_bridge.log" 2>&1 &
service_pid=$!
found=0
for _ in $(seq 1 160); do
  count=$(ros2 service list 2>/dev/null | grep -c '^/world/expanded_matrix/' || true)
  if test "$count" -ge 4; then found=1; break; fi
  sleep 0.25
done
test "$found" -eq 1
ros2 service list | grep '^/world/expanded_matrix/' | sort > "$OUT/ros_world_services.txt"

ros2 service call /world/expanded_matrix/control ros_gz_interfaces/srv/ControlWorld \
  '{world_control: {pause: true}}' > "$OUT/control_response.txt"
ros2 service call /world/expanded_matrix/create ros_gz_interfaces/srv/SpawnEntity \
  "{entity_factory: {name: bridge_box, allow_renaming: false, sdf: '<sdf version=\"1.10\"><model name=\"bridge_box\"><static>true</static><link name=\"link\"><visual name=\"visual\"><geometry><box><size>1 1 1</size></box></geometry></visual></link></model></sdf>', pose: {position: {x: 0, y: 0, z: 0.5}, orientation: {w: 1.0}}, relative_to: world}}" \
  > "$OUT/spawn_response.txt"
ros2 service call /world/expanded_matrix/set_pose ros_gz_interfaces/srv/SetEntityPose \
  '{entity: {name: bridge_box, type: 2}, pose: {position: {x: 2.0, y: 0.0, z: 0.5}, orientation: {w: 1.0}}}' \
  > "$OUT/set_pose_response.txt"
ros2 service call /world/expanded_matrix/remove ros_gz_interfaces/srv/DeleteEntity \
  '{entity: {name: bridge_box, type: 2}}' > "$OUT/delete_response.txt"
for f in control spawn set_pose delete; do grep -q 'success=True' "$OUT/${f}_response.txt"; done
stop_pid "$service_pid" service_bridge
stop_pid "$sim_pid" gz_server

printf 'user_workspace_runtime=PASS\ntopic_conversions=24/24\nunique_topic_type_pairs=13\nservice_factories=4/4\ntopic_exit=0\nservice_exit=0\n' \
  > "$OUT/summary.txt"
