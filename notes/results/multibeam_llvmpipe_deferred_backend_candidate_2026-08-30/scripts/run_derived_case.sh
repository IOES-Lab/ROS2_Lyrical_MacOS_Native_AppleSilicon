#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <wgpu|cpu|auto> <output-dir>" >&2
  exit 2
fi

backend="$1"
out="$2"
image="${DAVE_SONAR_TEST_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
name="sonar-derived-${backend}-$$"
domain=$((80 + ($$ % 30)))
partition="sonar_derived_${backend}_$$"
limit="${DAVE_SONAR_TEST_LIMIT:-600}"

mkdir -p "$out"
out="$(cd "$out" && pwd)"

cleanup() {
  docker stop "$name" >/dev/null 2>&1 || true
  docker rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity \
  >"$out/container_id.txt"

cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=$backend
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

timeout --signal=INT --kill-after=20s ${limit}s \
  ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=dave_multibeam_sonar \
    paused:=false x:=5.8 z:=2 yaw:=3.14 \
    compute_backend:=$backend gui:=true headless:=true \
    > /tmp/launch.log 2>&1 &
launch_pid=\$!

ready=0
for i in \$(seq 1 ${limit}); do
  if ! kill -0 "\$launch_pid" 2>/dev/null; then
    break
  fi
  if [[ "$backend" == cpu ]]; then
    grep -q 'Creating CPU backend' /tmp/launch.log 2>/dev/null && ready=1
  else
    grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1
  fi
  [[ \$ready -eq 1 ]] && break
  sleep 1
done

point_ok=0
raw_ok=0
if [[ \$ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
  sleep 5
  ros2 topic list | sort > /tmp/topic_list.txt 2>&1 || true

  for attempt in 1 2 3; do
    timeout 45 ros2 topic echo /sensor/multibeam_sonar/point_cloud \
      --filter 'm.width > 1' --once --no-arr > /tmp/point_cloud.txt 2>&1
    if grep -q '^width: 513' /tmp/point_cloud.txt; then
      point_ok=1
      break
    fi
    sleep 3
  done

  for attempt in 1 2 3; do
    timeout 90 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw \
      --once --no-arr > /tmp/raw_sonar.txt 2>&1
    if grep -q '^  beam_count: 513' /tmp/raw_sonar.txt; then
      raw_ok=1
      break
    fi
    sleep 3
  done
fi

if kill -0 "\$launch_pid" 2>/dev/null; then
  kill -INT "\$launch_pid" 2>/dev/null || true
fi
wait "\$launch_pid"
rc=\$?
printf '%s\n' "\$rc" >/tmp/launch_rc.txt
printf '%s\n' "\$ready" >/tmp/backend_ready.txt
printf '%s\n' "\$point_ok" >/tmp/point_ok.txt
printf '%s\n' "\$raw_ok" >/tmp/raw_ok.txt
exit 0
INNER

docker cp "$out/inner.sh" "$name":/tmp/inner.sh >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh

for f in launch.log point_cloud.txt raw_sonar.txt launch_rc.txt backend_ready.txt point_ok.txt raw_ok.txt daemon_restart.txt topic_list.txt; do
  docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true
done

docker exec "$name" bash -lc \
  'free -h; ps -eo pid,ppid,stat,comm,args | grep -E "[g]z-sim-main|[r]os2 launch|[p]arameter_bridge" || true' \
  >"$out/final_state.txt" 2>&1 || true

grep -E 'CreateComputeBackend|selected adapter|GPU #[0-9]+|Persistent GPU buffers allocated for 513|Creating CPU backend|SONAR PLUGIN LOADED|# of Beams|# of Rays|Stack trace|Segmentation fault|process has died|exit code' \
  "$out/launch.log" >"$out/key_lines.txt" || true

docker image inspect "$image" --format '{{.Id}}' >"$out/image_id.txt"
printf 'backend=%s\nimage=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\n' \
  "$backend" "$image" "$domain" "$partition" >"$out/environment.txt"

cat "$out/key_lines.txt"
printf 'launch_rc=%s backend_ready=%s point=%s raw=%s\n' \
  "$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)" \
  "$(cat "$out/backend_ready.txt" 2>/dev/null || echo missing)" \
  "$(cat "$out/point_ok.txt" 2>/dev/null || echo missing)" \
  "$(cat "$out/raw_ok.txt" 2>/dev/null || echo missing)"
