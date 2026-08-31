#!/usr/bin/env bash
set -eo pipefail

OUT=/evidence
mkdir -p "$OUT"
printf 'ROS_DISTRO=humble\nARCH=%s\nSOURCE_COMMIT=%s\n' \
  "$(dpkg --print-architecture)" \
  "$(cat /source_commit.txt)" > "$OUT/environment.txt"
uname -a >> "$OUT/environment.txt"

apt-get update > "$OUT/apt_update.log" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ros-humble-ros-gz-bridge \
  libignition-gazebo6-plugins \
  python3-colcon-common-extensions \
  > "$OUT/apt_install.log" 2>&1

source /opt/ros/humble/setup.bash
mkdir -p /ws/src/ros_gz
cp -a /source/ros_gz_interfaces /source/ros_gz_bridge /ws/src/ros_gz/
cd /ws
export MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2
set +e
colcon build --executor sequential \
  --packages-select ros_gz_interfaces ros_gz_bridge \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
  > "$OUT/build.log" 2>&1
build_rc=$?
set -e
echo "$build_rc" > "$OUT/build_rc.txt"
test "$build_rc" -eq 0

source /ws/install/local_setup.bash
PREFIX="$(ros2 pkg prefix ros_gz_bridge)"
printf 'PREFIX=%s\n' "$PREFIX" | tee "$OUT/install_prefix.txt"
test "$PREFIX" = /ws/install/ros_gz_bridge
BIN=/ws/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
test -x "$BIN"

if command -v gz >/dev/null 2>&1 && gz topic --help >/dev/null 2>&1; then
  TRANSPORT=gz
  SIM=(gz sim)
  MSG_PREFIX=gz.msgs
  PHYSICS_PLUGIN=gz-sim-physics-system
  COMMANDS_PLUGIN=gz-sim-user-commands-system
  SCENE_PLUGIN=gz-sim-scene-broadcaster-system
  PLUGIN_NS=gz::sim::systems
else
  TRANSPORT=ign
  SIM=(ign gazebo)
  MSG_PREFIX=ignition.msgs
  PHYSICS_PLUGIN=ignition-gazebo-physics-system
  COMMANDS_PLUGIN=ignition-gazebo-user-commands-system
  SCENE_PLUGIN=ignition-gazebo-scene-broadcaster-system
  PLUGIN_NS=ignition::gazebo::systems
fi
printf 'TRANSPORT=%s\nSIM=%s\nMSG_PREFIX=%s\n' \
  "$TRANSPORT" "${SIM[*]}" "$MSG_PREFIX" >> "$OUT/environment.txt"

export ROS_DOMAIN_ID=186
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

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
  set +e
  wait "$pid"
  rc=$?
  set -e
  echo "$rc" > "$OUT/${label}_rc.txt"
  test "$rc" -eq 0
}

transport_pub() {
  "$TRANSPORT" topic -t "$1" -m "$2" -p "$3"
}

transport_echo() {
  "$TRANSPORT" topic -e -t "$1" -n 1
}

ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1

"$BIN" \
  "/cross_g2r_string@std_msgs/msg/String[${MSG_PREFIX}.StringMsg" \
  "/cross_g2r_double@std_msgs/msg/Float64[${MSG_PREFIX}.Double" \
  "/cross_g2r_vector@geometry_msgs/msg/Vector3[${MSG_PREFIX}.Vector3d" \
  "/cross_g2r_pose@geometry_msgs/msg/Pose[${MSG_PREFIX}.Pose" \
  "/cross_r2g_string@std_msgs/msg/String]${MSG_PREFIX}.StringMsg" \
  "/cross_r2g_double@std_msgs/msg/Float64]${MSG_PREFIX}.Double" \
  "/cross_r2g_vector@geometry_msgs/msg/Vector3]${MSG_PREFIX}.Vector3d" \
  "/cross_r2g_twist@geometry_msgs/msg/Twist]${MSG_PREFIX}.Twist" \
  > "$OUT/topic_bridge.log" 2>&1 &
topic_pid=$!
sleep 3

ros2 topic echo /cross_g2r_string --once > "$OUT/g2r_string.txt" & p=$!; sleep 1
transport_pub /cross_g2r_string "${MSG_PREFIX}.StringMsg" 'data:"humble-g2r"'; wait "$p"
ros2 topic echo /cross_g2r_double --once > "$OUT/g2r_double.txt" & p=$!; sleep 1
transport_pub /cross_g2r_double "${MSG_PREFIX}.Double" 'data:42.25'; wait "$p"
ros2 topic echo /cross_g2r_vector --once > "$OUT/g2r_vector.txt" & p=$!; sleep 1
transport_pub /cross_g2r_vector "${MSG_PREFIX}.Vector3d" 'x:1.5 y:2.5 z:3.5'; wait "$p"
ros2 topic echo /cross_g2r_pose --once > "$OUT/g2r_pose.txt" & p=$!; sleep 1
transport_pub /cross_g2r_pose "${MSG_PREFIX}.Pose" 'position:{x:4.0 y:5.0 z:6.0} orientation:{w:1.0}'; wait "$p"

transport_echo /cross_r2g_string > "$OUT/r2g_string.txt" & p=$!; sleep 1
ros2 topic pub /cross_r2g_string std_msgs/msg/String '{data: humble-r2g}' --once >/dev/null; wait "$p"
transport_echo /cross_r2g_double > "$OUT/r2g_double.txt" & p=$!; sleep 1
ros2 topic pub /cross_r2g_double std_msgs/msg/Float64 '{data: 84.5}' --once >/dev/null; wait "$p"
transport_echo /cross_r2g_vector > "$OUT/r2g_vector.txt" & p=$!; sleep 1
ros2 topic pub /cross_r2g_vector geometry_msgs/msg/Vector3 '{x: -1.25, y: 4.5, z: 8.75}' --once >/dev/null; wait "$p"
transport_echo /cross_r2g_twist > "$OUT/r2g_twist.txt" & p=$!; sleep 1
ros2 topic pub /cross_r2g_twist geometry_msgs/msg/Twist \
  '{linear: {x: 1.0, y: 2.0, z: 3.0}, angular: {x: 0.1, y: 0.2, z: 0.3}}' \
  --once >/dev/null; wait "$p"

grep -q 'humble-g2r' "$OUT/g2r_string.txt"
grep -q '42.25' "$OUT/g2r_double.txt"
grep -q '1.5' "$OUT/g2r_vector.txt"
grep -q 'x: 4.0' "$OUT/g2r_pose.txt"
grep -q 'humble-r2g' "$OUT/r2g_string.txt"
grep -q '84.5' "$OUT/r2g_double.txt"
grep -q -- '-1.25' "$OUT/r2g_vector.txt"
grep -q 'linear' "$OUT/r2g_twist.txt"
stop_pid "$topic_pid" topic_bridge

cat > "$OUT/service_world.sdf" <<SDF
<?xml version="1.0"?>
<sdf version="1.8"><world name="bridge_matrix">
<plugin filename="${PHYSICS_PLUGIN}" name="${PLUGIN_NS}::Physics"/>
<plugin filename="${COMMANDS_PLUGIN}" name="${PLUGIN_NS}::UserCommands"/>
<plugin filename="${SCENE_PLUGIN}" name="${PLUGIN_NS}::SceneBroadcaster"/>
</world></sdf>
SDF
"${SIM[@]}" -s -r "$OUT/service_world.sdf" > "$OUT/gz_server.log" 2>&1 &
sim_pid=$!
found=0
for _ in $(seq 1 120); do
  if timeout 3 "$TRANSPORT" service -l 2>/dev/null | grep -q '^/world/bridge_matrix/control$'; then
    found=1
    break
  fi
  sleep 0.25
done
test "$found" -eq 1
timeout 5 "$TRANSPORT" service -l | grep '^/world/bridge_matrix/control$' > "$OUT/gz_control_service.txt"
"$BIN" '/world/bridge_matrix/control@ros_gz_interfaces/srv/ControlWorld' \
  > "$OUT/service_bridge.log" 2>&1 &
service_pid=$!
found=0
for _ in $(seq 1 120); do
  if ros2 service list 2>/dev/null | grep -q '^/world/bridge_matrix/control$'; then
    found=1
    break
  fi
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

printf 'build=PASS\ntopic_matrix=8/8\nservice_matrix=1/1\ntopic_exit=0\nservice_exit=0\n' \
  > "$OUT/summary.txt"
