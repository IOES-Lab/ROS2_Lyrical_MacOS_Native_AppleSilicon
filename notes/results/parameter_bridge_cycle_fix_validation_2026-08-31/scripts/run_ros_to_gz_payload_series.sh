#!/usr/bin/env bash
set -euo pipefail

root="${1:?output root required}"
image="${BRIDGE_IMAGE:-dave-bridge-cycle-fix:20260831}"
runs="${BRIDGE_RUNS:-20}"
mkdir -p "$root"
printf 'run\tpayload\tbridge_rc\tsegfault\tescalation\n' > "$root/summary.tsv"

for run in $(seq 1 "$runs"); do
  out="$root/run_$(printf '%02d' "$run")"
  mkdir -p "$out"
  name="bridge-cycle-r2g-${run}-$$"
  domain=$((180 + run))
  partition="bridge_cycle_r2g_${run}_$$"
  docker run -d --name "$name" --entrypoint sleep "$image" infinity > "$out/container_id.txt"

  cat > "$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/bridge_cycle_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

setsid /home/docker/bridge_cycle_ws/install/ros_gz_bridge/lib/ros_gz_bridge/parameter_bridge \
  '/cycle_ros_to_gz@std_msgs/msg/String]gz.msgs.StringMsg' \
  >/tmp/bridge.log 2>&1 &
bp=\$!
sleep 3

timeout 20 gz topic -e -t /cycle_ros_to_gz -n 1 >/tmp/gz_received.txt 2>&1 &
gz_echo=\$!
sleep 1
ros2 topic pub --once /cycle_ros_to_gz std_msgs/msg/String '{data: from_ros}' \
  >/tmp/ros_publish.txt 2>&1
wait \$gz_echo
gz_echo_rc=\$?
payload=0
[[ \$gz_echo_rc -eq 0 ]] && grep -q 'from_ros' /tmp/gz_received.txt && payload=1

kill -INT "\$bp" 2>/dev/null || true
escalation=none
for i in \$(seq 1 20); do
  kill -0 \$bp 2>/dev/null || break
  sleep 1
done
if kill -0 \$bp 2>/dev/null; then
  escalation=TERM
  kill -TERM "\$bp" 2>/dev/null || true
  sleep 2
fi
if kill -0 \$bp 2>/dev/null; then
  escalation=KILL
  kill -KILL "\$bp" 2>/dev/null || true
fi
wait \$bp
bridge_rc=\$?
printf '%s\n' \$payload >/tmp/payload.txt
printf '%s\n' \$bridge_rc >/tmp/bridge_rc.txt
printf '%s\n' \$escalation >/tmp/escalation.txt
exit 0
INNER

  docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
  docker exec "$name" chmod +x /tmp/inner.sh
  docker exec "$name" /tmp/inner.sh > "$out/runner_stdout.txt" 2>&1 || true
  for file in bridge.log ros_publish.txt gz_received.txt payload.txt bridge_rc.txt escalation.txt; do
    docker cp "$name:/tmp/$file" "$out/$file" >/dev/null 2>&1 || true
  done
  payload=$(cat "$out/payload.txt" 2>/dev/null || echo missing)
  bridge_rc=$(cat "$out/bridge_rc.txt" 2>/dev/null || echo missing)
  escalation=$(cat "$out/escalation.txt" 2>/dev/null || echo missing)
  segfault=0
  [[ "$bridge_rc" == 139 ]] && segfault=1
  grep -Eqi 'segmentation|stack trace|exit code -11' "$out/bridge.log" 2>/dev/null && segfault=1
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$run" "$payload" "$bridge_rc" "$segfault" "$escalation" >> "$root/summary.tsv"
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "run=$run payload=$payload rc=$bridge_rc seg=$segfault escalation=$escalation"
done

docker image inspect "$image" --format '{{.Id}}' > "$root/image_id.txt"
