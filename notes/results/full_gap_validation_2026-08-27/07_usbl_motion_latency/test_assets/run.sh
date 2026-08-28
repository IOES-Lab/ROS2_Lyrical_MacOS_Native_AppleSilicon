#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
set -u

export ROS_DOMAIN_ID=188
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
ROOT=/home/docker/full_gap_validation_2026-08-27/07_usbl_motion_latency
OUT="$ROOT/run"
test ! -e "$OUT"
mkdir -p "$OUT"

setsid gz sim -s -r "$ROOT/test_assets/usbl_motion_latency.sdf" >"$OUT/server.log" 2>&1 &
SERVER_PID=$!
PGID=$(ps -o pgid= -p "$SERVER_PID" | tr -d ' ')
printf 'server_pid=%s\npgid=%s\n' "$SERVER_PID" "$PGID" >"$OUT/process_ids.txt"
cleanup() {
  kill -INT -- "-$PGID" 2>/dev/null || true; sleep 4
  kill -TERM -- "-$PGID" 2>/dev/null || true; sleep 2
  kill -KILL -- "-$PGID" 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 120); do
  if gz service -l 2>/dev/null | grep -Fxq /world/usbl_gap/set_pose; then break; fi
  sleep 0.5
done
gz service -i -s /world/usbl_gap/set_pose >"$OUT/set_pose_service_info.txt" 2>&1 || true
OUT="$OUT" python3 "$ROOT/test_assets/run_probe.py" >"$OUT/client.log" 2>&1

cleanup; trap - EXIT
ps -eo pid,ppid,pgid,comm,args | grep -E '[g]z-sim-main|[r]os2 launch|[p]arameter_bridge' >"$OUT/processes_after_cleanup.txt" || true
cat "$OUT/results.json"
