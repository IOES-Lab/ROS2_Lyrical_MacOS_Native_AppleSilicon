#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/bridge_normal_ws/install/local_setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
ROOT=/home/docker/bridge_normal_ws/repeat_teardown_valid
mkdir -p "$ROOT"
for i in $(seq -w 1 10); do
  OUT="$ROOT/run_$i"; mkdir -p "$OUT"
  export ROS_DOMAIN_ID=$((160 + 10#$i))
  ros2 daemon stop >/dev/null 2>&1 || true
  ros2 daemon start >/dev/null 2>&1
  ros2 run ros_gz_bridge parameter_bridge \
    '/repeat_g2r@std_msgs/msg/String[gz.msgs.StringMsg' \
    '/repeat_r2g@std_msgs/msg/String]gz.msgs.StringMsg' > "$OUT/bridge.log" 2>&1 &
  pid=$!
  sleep 2
  ros2 topic echo /repeat_g2r --once --timeout 20 > "$OUT/g2r.txt" & e=$!
  sleep 0.5
  gz topic -t /repeat_g2r -m gz.msgs.StringMsg -p "data:\"g2r-$i\""
  wait "$e"
  gz topic -e -t /repeat_r2g -n 1 > "$OUT/r2g.txt" & g=$!
  sleep 0.5
  ros2 topic pub /repeat_r2g std_msgs/msg/String "{data: r2g-$i}" --once >/dev/null
  wait "$g"
  grep -q "g2r-$i" "$OUT/g2r.txt"
  grep -q "r2g-$i" "$OUT/r2g.txt"
  kill -INT "$pid" 2>/dev/null || true
  for _ in $(seq 1 80); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if kill -0 "$pid" 2>/dev/null; then kill -TERM "$pid" 2>/dev/null || true; echo TERM > "$OUT/escalation.txt"; fi
  set +e; wait "$pid"; rc=$?; set -e
  echo "$rc" > "$OUT/bridge_rc.txt"
  test "$rc" -eq 0
  printf '%s\tPASS\t%s\n' "$i" "$rc"
done | tee "$ROOT/summary.tsv"
