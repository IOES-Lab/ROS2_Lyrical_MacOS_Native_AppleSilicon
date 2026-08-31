#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/bridge_normal_ws/install/local_setup.bash
export ROS_DOMAIN_ID=231
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
OUT=/home/docker/bridge_normal_ws/runtime_matrix
mkdir -p "$OUT"

stop_pid() {
  local pid="$1" label="$2" rc=0
  if kill -0 "$pid" 2>/dev/null; then kill -INT "$pid" 2>/dev/null || true; fi
  for _ in $(seq 1 60); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "$label TERM escalation" >> "$OUT/escalations.txt"
    kill -TERM "$pid" 2>/dev/null || true
    sleep 1
  fi
  set +e
  wait "$pid" 2>/dev/null
  rc=$?
  set -e
  echo "$rc" > "$OUT/${label}_rc.txt"
  test "$rc" -ne 139
  test "$rc" -ne 245
}

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start > "$OUT/daemon.txt" 2>&1

BRIDGE_ARGS=(
  '/gz_to_ros_string@std_msgs/msg/String[gz.msgs.StringMsg'
  '/gz_to_ros_double@std_msgs/msg/Float64[gz.msgs.Double'
  '/gz_to_ros_vector@geometry_msgs/msg/Vector3[gz.msgs.Vector3d'
  '/gz_to_ros_pose@geometry_msgs/msg/Pose[gz.msgs.Pose'
  '/ros_to_gz_string@std_msgs/msg/String]gz.msgs.StringMsg'
  '/ros_to_gz_double@std_msgs/msg/Float64]gz.msgs.Double'
  '/ros_to_gz_vector@geometry_msgs/msg/Vector3]gz.msgs.Vector3d'
  '/ros_to_gz_twist@geometry_msgs/msg/Twist]gz.msgs.Twist'
)
ros2 run ros_gz_bridge parameter_bridge "${BRIDGE_ARGS[@]}" > "$OUT/topic_bridge.log" 2>&1 &
BPID=$!
echo "$BPID" > "$OUT/topic_bridge_pid.txt"
sleep 4

ros2 topic echo /gz_to_ros_string --once --timeout 30 > "$OUT/gz_to_ros_string.txt" & E1=$!
sleep 1
gz topic -t /gz_to_ros_string -m gz.msgs.StringMsg -p 'data:"g2r-string-231"'
wait "$E1"

ros2 topic echo /gz_to_ros_double --once --timeout 30 > "$OUT/gz_to_ros_double.txt" & E2=$!
sleep 1
gz topic -t /gz_to_ros_double -m gz.msgs.Double -p 'data:42.25'
wait "$E2"

ros2 topic echo /gz_to_ros_vector --once --timeout 30 > "$OUT/gz_to_ros_vector.txt" & E3=$!
sleep 1
gz topic -t /gz_to_ros_vector -m gz.msgs.Vector3d -p 'x:1.25 y:-2.5 z:3.75'
wait "$E3"

ros2 topic echo /gz_to_ros_pose --once --timeout 30 > "$OUT/gz_to_ros_pose.txt" & E4=$!
sleep 1
gz topic -t /gz_to_ros_pose -m gz.msgs.Pose -p 'position:{x:4.0 y:5.0 z:6.0} orientation:{w:1.0}'
wait "$E4"

gz topic -e -t /ros_to_gz_string -n 1 > "$OUT/ros_to_gz_string.txt" & G1=$!
sleep 1
ros2 topic pub /ros_to_gz_string std_msgs/msg/String "{data: r2g-string-231}" --once >/dev/null
wait "$G1"

gz topic -e -t /ros_to_gz_double -n 1 > "$OUT/ros_to_gz_double.txt" & G2=$!
sleep 1
ros2 topic pub /ros_to_gz_double std_msgs/msg/Float64 "{data: 84.5}" --once >/dev/null
wait "$G2"

gz topic -e -t /ros_to_gz_vector -n 1 > "$OUT/ros_to_gz_vector.txt" & G3=$!
sleep 1
ros2 topic pub /ros_to_gz_vector geometry_msgs/msg/Vector3 "{x: -1.5, y: 2.25, z: 9.0}" --once >/dev/null
wait "$G3"

gz topic -e -t /ros_to_gz_twist -n 1 > "$OUT/ros_to_gz_twist.txt" & G4=$!
sleep 1
ros2 topic pub /ros_to_gz_twist geometry_msgs/msg/Twist "{linear: {x: 1.0, y: 2.0, z: 3.0}, angular: {x: 0.1, y: 0.2, z: 0.3}}" --once >/dev/null
wait "$G4"

stop_pid "$BPID" topic_bridge

grep -q 'g2r-string-231' "$OUT/gz_to_ros_string.txt"
grep -q '42.25' "$OUT/gz_to_ros_double.txt"
grep -q '1.25' "$OUT/gz_to_ros_vector.txt"
grep -q 'x: 4.0' "$OUT/gz_to_ros_pose.txt"
grep -q 'r2g-string-231' "$OUT/ros_to_gz_string.txt"
grep -q '84.5' "$OUT/ros_to_gz_double.txt"
grep -q -- '-1.5' "$OUT/ros_to_gz_vector.txt"
grep -q 'linear' "$OUT/ros_to_gz_twist.txt"

echo 'TOPIC_MATRIX_PASS=8/8' > "$OUT/topic_summary.txt"

cat > "$OUT/service_world.sdf" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.10">
  <world name="bridge_matrix">
    <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
    <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
    <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
  </world>
</sdf>
SDF

gz sim -s -r "$OUT/service_world.sdf" > "$OUT/gz_server.log" 2>&1 &
GPID=$!
for _ in $(seq 1 60); do
  gz service -l 2>/dev/null | grep -q '^/world/bridge_matrix/control$' && break
  sleep 0.5
done
gz service -l | grep '^/world/bridge_matrix/control$' > "$OUT/gz_control_service.txt"

ros2 run ros_gz_bridge parameter_bridge '/world/bridge_matrix/control@ros_gz_interfaces/srv/ControlWorld' > "$OUT/service_bridge.log" 2>&1 &
SPID=$!
for _ in $(seq 1 60); do
  ros2 service list 2>/dev/null | grep -q '^/world/bridge_matrix/control$' && break
  sleep 0.5
done
ros2 service type /world/bridge_matrix/control > "$OUT/ros_service_type.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld '{world_control: {pause: true}}' > "$OUT/pause_response.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld '{world_control: {pause: false}}' > "$OUT/unpause_response.txt"
grep -q 'success=True' "$OUT/pause_response.txt"
grep -q 'success=True' "$OUT/unpause_response.txt"
stop_pid "$SPID" service_bridge
stop_pid "$GPID" gz_server

echo 'SERVICE_MATRIX_PASS=1/1' > "$OUT/service_summary.txt"
printf 'topic=8/8\nservice=1/1\ninstalled_prefix=/home/docker/bridge_normal_ws/install/ros_gz_bridge\n' > "$OUT/summary.txt"
