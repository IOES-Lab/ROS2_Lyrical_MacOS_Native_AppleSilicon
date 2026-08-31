#!/usr/bin/env bash
set -eo pipefail
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export ROS_DOMAIN_ID=193
ROOT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/factory_inventory
BIN=/Users/gwon-yeseol/ros_gz_ws_lyrical/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
args=()
i=0
while IFS=$'\t' read -r package ros_type gz_type; do
  test "$package" = package && continue
  i=$((i+1))
  args+=("/factory_g2r_${i}@${ros_type}[${gz_type}")
  args+=("/factory_r2g_${i}@${ros_type}]${gz_type}")
done < "$ROOT/registered_pairs.tsv"
expected=$((i*2))
printf 'registered_pairs=%s\nexpected_handles=%s\n' "$i" "$expected" > "$ROOT/lifecycle_expected.txt"
"$BIN" "${args[@]}" > "$ROOT/lifecycle_bridge.log" 2>&1 &
pid=$!
ready=0
for _ in $(seq 1 1200); do
  created=$(grep -c 'Creating .* Bridge' "$ROOT/lifecycle_bridge.log" 2>/dev/null || true)
  if test "$created" -eq "$expected"; then ready=1; break; fi
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.1
done
created=$(grep -c 'Creating .* Bridge' "$ROOT/lifecycle_bridge.log" 2>/dev/null || true)
echo "$created" > "$ROOT/created_handle_count.txt"
test "$ready" -eq 1
ps -o rss= -p "$pid" | tr -d ' ' > "$ROOT/rss_kib.txt"
kill -INT "$pid" 2>/dev/null || true
for _ in $(seq 1 200); do kill -0 "$pid" 2>/dev/null || break; sleep 0.05; done
escalation=NONE
if kill -0 "$pid" 2>/dev/null; then escalation=TERM; kill -TERM "$pid" 2>/dev/null || true; fi
set +e
wait "$pid"
rc=$?
set -e
echo "$rc" > "$ROOT/bridge_rc.txt"
echo "$escalation" > "$ROOT/escalation.txt"
test "$rc" -eq 0
test "$escalation" = NONE
! grep -Eq 'recursive_mutex|Abort trap|terminating due to uncaught|SEVERE WARNING' "$ROOT/lifecycle_bridge.log"
printf 'factory_pairs=%s/%s\nhandle_instantiations=%s/%s\nbridge_exit=%s\nescalation=%s\n' \
  "$i" "$i" "$created" "$expected" "$rc" "$escalation" > "$ROOT/result.txt"
cat "$ROOT/result.txt"
