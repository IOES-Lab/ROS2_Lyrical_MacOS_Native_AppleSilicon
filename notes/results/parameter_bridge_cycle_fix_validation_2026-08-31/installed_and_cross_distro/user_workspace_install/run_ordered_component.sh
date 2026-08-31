#!/usr/bin/env bash
set -o pipefail
source /Users/gwon-yeseol/ros2_lyrical/.venv/bin/activate
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash || true
set -u
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DYLD_LIBRARY_PATH="/opt/homebrew/lib:${DYLD_LIBRARY_PATH:-}"
BIN=/Users/gwon-yeseol/ros_gz_ws_lyrical/install/ros_gz_bridge/lib/ros_gz_bridge
CONFIG=/Users/gwon-yeseol/ros_gz_ws_lyrical/src/ros_gz/ros_gz_bridge/test/config/test-config.yaml
OUT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/ordered_component
rm -rf "$OUT"
mkdir -p "$OUT"
"$BIN/bridge_node" --ros-args -p config_file:="$CONFIG" --log-level info >"$OUT/bridge_node.log" 2>&1 &
BRIDGE_PID=$!
"$BIN/test_gz_publisher" >"$OUT/gz_publisher.log" 2>&1 &
PUB_PID=$!
"$BIN/test_gz_server" >"$OUT/gz_server.log" 2>&1 &
SERVER_PID=$!
printf '%s\n' "$BRIDGE_PID" >"$OUT/bridge_pid.txt"
cleanup() {
  for p in "${SUB_PID:-}" "${PUB_PID:-}" "${SERVER_PID:-}" "${BRIDGE_PID:-}"; do
    if [ -n "$p" ]; then kill -INT "$p" 2>/dev/null || true; fi
  done
  sleep 2
  for p in "${SUB_PID:-}" "${PUB_PID:-}" "${SERVER_PID:-}" "${BRIDGE_PID:-}"; do
    if [ -n "$p" ]; then kill -TERM "$p" 2>/dev/null || true; fi
  done
}
trap cleanup EXIT INT TERM
ready=0
for i in $(seq 1 240); do
  topics=$(grep -c 'Creating .*Bridge' "$OUT/bridge_node.log" 2>/dev/null || true)
  services=$(grep -c 'Creating ROS->GZ service bridge' "$OUT/bridge_node.log" 2>/dev/null || true)
  echo "$(date +%s) $topics $services" >>"$OUT/readiness.tsv"
  if [ "$topics" -ge 3 ] && [ "$services" -ge 1 ]; then ready=1; break; fi
  if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then break; fi
  sleep 1
done
echo "$ready" >"$OUT/ready.txt"
if [ "$ready" -ne 1 ]; then
  set +e; wait "$BRIDGE_PID"; rc=$?; set -e
  echo "$rc" >"$OUT/bridge_early_rc.txt"
  exit 2
fi
sleep 10
set +e
"$BIN/test_launch_action_subscriber" --gtest_output=xml:"$OUT/subscriber.xml" >"$OUT/subscriber.log" 2>&1
SUB_RC=$?
set -e
echo "$SUB_RC" >"$OUT/subscriber_rc.txt"
grep -c '\[       OK \]' "$OUT/subscriber.log" >"$OUT/assertion_pass_count.txt" || true
grep -c '\[  FAILED  \]' "$OUT/subscriber.log" >"$OUT/failed_line_count.txt" || true
kill -INT "$BRIDGE_PID" 2>/dev/null || true
for i in $(seq 1 30); do kill -0 "$BRIDGE_PID" 2>/dev/null || break; sleep 1; done
if kill -0 "$BRIDGE_PID" 2>/dev/null; then
  echo TERM >"$OUT/bridge_escalation.txt"
  kill -TERM "$BRIDGE_PID" 2>/dev/null || true
else
  echo NONE >"$OUT/bridge_escalation.txt"
fi
set +e; wait "$BRIDGE_PID" 2>/dev/null; BRIDGE_RC=$?; set -e
echo "$BRIDGE_RC" >"$OUT/bridge_rc.txt"
kill -INT "$PUB_PID" "$SERVER_PID" 2>/dev/null || true
wait "$PUB_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
{
 echo "component_handles_ready=$ready"
 echo "payload_service_assertions=$(cat "$OUT/assertion_pass_count.txt")/4"
 echo "subscriber_process_rc=$SUB_RC"
 echo "bridge_node_exit=$BRIDGE_RC"
 echo "bridge_node_escalation=$(cat "$OUT/bridge_escalation.txt")"
} | tee "$OUT/result.txt"
trap - EXIT INT TERM
