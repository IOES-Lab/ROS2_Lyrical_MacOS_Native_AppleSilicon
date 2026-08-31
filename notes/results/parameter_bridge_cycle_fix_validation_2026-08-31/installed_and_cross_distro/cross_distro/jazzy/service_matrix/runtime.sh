#!/usr/bin/env bash
set -eo pipefail
OUT=/evidence/direct_service
mkdir -p "$OUT"
source /opt/ros/jazzy/setup.bash
source /ws2/install/local_setup.bash
export ROS_DOMAIN_ID=183
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
BIN=/ws2/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
stop_pid() {
  local pid="$1" label="$2" rc
  if kill -0 "$pid" 2>/dev/null; then kill -INT "$pid" 2>/dev/null || true; fi
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then echo TERM > "$OUT/${label}_escalation.txt"; kill -TERM "$pid" 2>/dev/null || true; else echo NONE > "$OUT/${label}_escalation.txt"; fi
  set +e; wait "$pid"; rc=$?; set -e
  echo "$rc" > "$OUT/${label}_rc.txt"
  test "$rc" -eq 0
}
cat > "$OUT/service_world.sdf" <<'SDF'
<?xml version="1.0"?>
<sdf version="1.10"><world name="bridge_matrix">
<plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
<plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
<plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
</world></sdf>
SDF
ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1
gz sim -s -r "$OUT/service_world.sdf" > "$OUT/gz_server.log" 2>&1 &
gpid=$!
found=0
for _ in $(seq 1 120); do
  if timeout 3 gz service -l 2>/dev/null | grep -q '^/world/bridge_matrix/control$'; then found=1; break; fi
  sleep 0.25
done
test "$found" -eq 1
timeout 5 gz service -l | grep '^/world/bridge_matrix/control$' > "$OUT/gz_control_service.txt"
"$BIN" '/world/bridge_matrix/control@ros_gz_interfaces/srv/ControlWorld' > "$OUT/service_bridge.log" 2>&1 &
spid=$!
found=0
for _ in $(seq 1 120); do
  if ros2 service list 2>/dev/null | grep -q '^/world/bridge_matrix/control$'; then found=1; break; fi
  sleep 0.25
done
test "$found" -eq 1
ros2 service type /world/bridge_matrix/control > "$OUT/ros_service_type.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld '{world_control: {pause: true}}' > "$OUT/pause_response.txt"
ros2 service call /world/bridge_matrix/control ros_gz_interfaces/srv/ControlWorld '{world_control: {pause: false}}' > "$OUT/unpause_response.txt"
grep -q 'success=True' "$OUT/pause_response.txt"
grep -q 'success=True' "$OUT/unpause_response.txt"
stop_pid "$spid" service_bridge
stop_pid "$gpid" gz_server
printf 'service_matrix=1/1\nservice_bridge_exit=0\ngz_server_exit=0\n' > "$OUT/summary.txt"
