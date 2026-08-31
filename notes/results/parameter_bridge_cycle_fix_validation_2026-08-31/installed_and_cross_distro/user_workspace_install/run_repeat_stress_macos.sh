#!/usr/bin/env bash
set -eo pipefail
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export ROS_DOMAIN_ID=191
ROOT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/installed_and_cross_distro/user_workspace_install/repeat_stress_30
BIN=/Users/gwon-yeseol/ros_gz_ws_lyrical/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge
mkdir -p "$ROOT"
ros2 daemon stop >/dev/null 2>&1 || true
ros2 daemon start >/dev/null 2>&1
printf 'run\tverdict\trc\trss_kib\n' > "$ROOT/summary.tsv"
for i in $(seq -w 1 30); do
  OUT="$ROOT/run_$i"; mkdir -p "$OUT"
  "$BIN"     "/stress_g2r_$i@std_msgs/msg/String[gz.msgs.StringMsg"     "/stress_r2g_$i@std_msgs/msg/String]gz.msgs.StringMsg" > "$OUT/bridge.log" 2>&1 &
  pid=$!
  ready=0
  for _ in $(seq 1 30); do
    if ros2 topic list 2>/dev/null | grep -qx "/stress_g2r_$i"; then
      ready=1
      break
    fi
    sleep 1
  done
  test "$ready" -eq 1
  ps -o rss= -p "$pid" | tr -d ' ' > "$OUT/rss_kib.txt"

  ros2 topic echo "/stress_g2r_$i" --once --timeout 30 > "$OUT/g2r.txt" &
  e=$!
  for _ in $(seq 1 5); do
    sleep 1
    gz topic -t "/stress_g2r_$i" -m gz.msgs.StringMsg -p "data:\"g2r-$i\"" >/dev/null || true
    kill -0 "$e" 2>/dev/null || break
  done
  wait "$e"

  gz topic -e -t "/stress_r2g_$i" -n 1 > "$OUT/r2g.txt" &
  g=$!
  for _ in $(seq 1 5); do
    sleep 1
    ros2 topic pub "/stress_r2g_$i" std_msgs/msg/String "{data: r2g-$i}" --once >/dev/null || true
    kill -0 "$g" 2>/dev/null || break
  done
  wait "$g"

  grep -q "g2r-$i" "$OUT/g2r.txt"
  grep -q "r2g-$i" "$OUT/r2g.txt"
  kill -INT "$pid" 2>/dev/null || true
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  escalation=NONE
  if kill -0 "$pid" 2>/dev/null; then
    escalation=TERM
    kill -TERM "$pid" 2>/dev/null || true
  fi
  set +e; wait "$pid"; rc=$?; set -e
  echo "$rc" > "$OUT/bridge_rc.txt"
  echo "$escalation" > "$OUT/escalation.txt"
  test "$rc" -eq 0
  test "$escalation" = NONE
  ! grep -Eq 'recursive_mutex|Abort trap|terminating due to uncaught|SEVERE WARNING' "$OUT/bridge.log"
  printf '%s\tPASS\t%s\t%s\n' "$i" "$rc" "$(cat "$OUT/rss_kib.txt")" | tee -a "$ROOT/summary.tsv"
done
