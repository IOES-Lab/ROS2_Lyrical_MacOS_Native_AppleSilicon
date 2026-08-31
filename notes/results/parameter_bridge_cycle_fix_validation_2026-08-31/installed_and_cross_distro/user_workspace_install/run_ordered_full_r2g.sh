#!/usr/bin/env bash
set -o pipefail
source /Users/gwon-yeseol/ros2_lyrical/.venv/bin/activate
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash
set -u
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DYLD_LIBRARY_PATH="/opt/homebrew/lib:${DYLD_LIBRARY_PATH:-}"
OUT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/ordered_full_r2g
rm -rf "$OUT"
mkdir -p "$OUT"
TSV=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/factory_inventory/registered_pairs.tsv
GEN=/Users/gwon-yeseol/ros_gz_ws_lyrical/build/ros_gz_bridge/generated/test/gz_subscriber.cpp
python3 - "$TSV" "$GEN" "$OUT" <<'PY'
import re, sys
from pathlib import Path
tsv, gen, out = map(Path, sys.argv[1:])
pairs=[]
for line in tsv.read_text().splitlines()[1:]:
    pkg, ros, gz=line.split("\t")
    pairs.append((ros,gz))
names=re.findall(r'TEST\(GzSubscriberTest, ([^)]+)\)', gen.read_text())
assert len(pairs)==len(names)==73, (len(pairs),len(names))
args=[f'/{name}@{ros}]{gz}' for name,(ros,gz) in zip(names,pairs)]
(out/'bridge_args.txt').write_text("\n".join(args)+"\n")
(out/'expected.txt').write_text(f"pairs={len(pairs)}\nhandles={len(args)}\n")
PY
ARGS=()
while IFS= read -r arg; do
  ARGS+=("$arg")
done < "$OUT/bridge_args.txt"
BIN=/Users/gwon-yeseol/ros_gz_ws_lyrical/install/ros_gz_bridge/lib/ros_gz_bridge
"$BIN/parameter_bridge" "${ARGS[@]}" >"$OUT/bridge.log" 2>&1 &
BRIDGE_PID=$!
echo "$BRIDGE_PID" >"$OUT/bridge_pid.txt"
"$BIN/test_ros_publisher" >"$OUT/ros_publisher.log" 2>&1 &
PUB_PID=$!
echo "$PUB_PID" >"$OUT/publisher_pid.txt"
cleanup() {
  if [ -n "${PUB_PID:-}" ]; then kill -INT "$PUB_PID" 2>/dev/null || true; fi
  if [ -n "${BRIDGE_PID:-}" ]; then kill -INT "$BRIDGE_PID" 2>/dev/null || true; fi
  sleep 2
  if [ -n "${PUB_PID:-}" ]; then kill -TERM "$PUB_PID" 2>/dev/null || true; fi
  if [ -n "${BRIDGE_PID:-}" ]; then kill -TERM "$BRIDGE_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM
ready=0
for i in $(seq 1 240); do
  count=$(grep -c 'Creating ROS->GZ Bridge' "$OUT/bridge.log" 2>/dev/null || true)
  echo "$(date +%s) $count" >>"$OUT/readiness.tsv"
  if [ "$count" -eq 73 ]; then ready=1; break; fi
  if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then break; fi
  sleep 1
done
echo "$ready" >"$OUT/ready.txt"
grep -c 'Creating ROS->GZ Bridge' "$OUT/bridge.log" >"$OUT/created_handle_count.txt" || true
if [ "$ready" -ne 1 ]; then
  wait "$BRIDGE_PID"; echo $? >"$OUT/bridge_early_rc.txt"
  exit 2
fi
# Both the bridge and the generated publisher create all 73 endpoints
# serially on this macOS build.  Starting them together and waiting until
# the bridge has created its final handle avoids the upstream launch test's
# discovery/startup race before the subscriber assertions begin.
sleep 10
set +e
"$BIN/test_gz_subscriber" --gtest_output=xml:"$OUT/gz_subscriber.xml" >"$OUT/gz_subscriber.log" 2>&1
SUB_RC=$?
set -e
echo "$SUB_RC" >"$OUT/gz_subscriber_rc.txt"
grep -c '\[       OK \]' "$OUT/gz_subscriber.log" >"$OUT/payload_pass_count.txt" || true
grep -c '\[  FAILED  \]' "$OUT/gz_subscriber.log" >"$OUT/failed_line_count.txt" || true
kill -INT "$PUB_PID" 2>/dev/null || true
wait "$PUB_PID" 2>/dev/null || true
kill -INT "$BRIDGE_PID" 2>/dev/null || true
for i in $(seq 1 30); do
  kill -0 "$BRIDGE_PID" 2>/dev/null || break
  sleep 1
done
if kill -0 "$BRIDGE_PID" 2>/dev/null; then
  echo TERM >"$OUT/bridge_escalation.txt"
  kill -TERM "$BRIDGE_PID" 2>/dev/null || true
else
  echo NONE >"$OUT/bridge_escalation.txt"
fi
set +e
wait "$BRIDGE_PID" 2>/dev/null
BRIDGE_RC=$?
set -e
echo "$BRIDGE_RC" >"$OUT/bridge_rc.txt"
{
 echo "factory_pairs=73"
 echo "bridge_handles=$(cat "$OUT/created_handle_count.txt")"
 echo "payload_tests_passed=$(cat "$OUT/payload_pass_count.txt")/73"
 echo "subscriber_process_rc=$SUB_RC"
 echo "bridge_exit=$(cat "$OUT/bridge_rc.txt")"
 echo "bridge_escalation=$(cat "$OUT/bridge_escalation.txt")"
} | tee "$OUT/result.txt"
trap - EXIT INT TERM
