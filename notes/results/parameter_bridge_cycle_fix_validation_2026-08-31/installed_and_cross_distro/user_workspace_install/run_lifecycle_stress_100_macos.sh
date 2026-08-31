#!/usr/bin/env bash
set -eo pipefail
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export ROS_DOMAIN_ID=192
ROOT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/lifecycle_stress_100
BIN=/Users/gwon-yeseol/ros_gz_ws_lyrical/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
mkdir -p "$ROOT"
printf 'run\tverdict\trc\trss_kib\tescalation\n' > "$ROOT/summary.tsv"
for i in $(seq -w 1 100); do
  log="$ROOT/run_$i.log"
  "$BIN"     "/lifecycle_g2r@std_msgs/msg/String[gz.msgs.StringMsg"     "/lifecycle_r2g@std_msgs/msg/String]gz.msgs.StringMsg" > "$log" 2>&1 &
  pid=$!
  ready=0
  for _ in $(seq 1 100); do
    if test "$(grep -c 'Creating .* Bridge' "$log" 2>/dev/null || true)" -ge 2; then
      ready=1
      break
    fi
    sleep 0.05
  done
  test "$ready" -eq 1
  rss=$(ps -o rss= -p "$pid" | tr -d ' ')
  kill -INT "$pid" 2>/dev/null || true
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.05; done
  escalation=NONE
  if kill -0 "$pid" 2>/dev/null; then
    escalation=TERM
    kill -TERM "$pid" 2>/dev/null || true
  fi
  set +e; wait "$pid"; rc=$?; set -e
  test "$rc" -eq 0
  test "$escalation" = NONE
  ! grep -Eq 'recursive_mutex|Abort trap|terminating due to uncaught|SEVERE WARNING' "$log"
  printf '%s\tPASS\t%s\t%s\t%s\n' "$i" "$rc" "$rss" "$escalation" | tee -a "$ROOT/summary.tsv"
done
