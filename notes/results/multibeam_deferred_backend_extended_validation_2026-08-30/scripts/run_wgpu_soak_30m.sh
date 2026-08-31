#!/usr/bin/env bash
set -u -o pipefail
repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
out="${1:-$repo/notes/results/multibeam_deferred_backend_extended_validation_2026-08-30/wgpu_soak_30m}"
image="${DAVE_SONAR_TEST_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
minutes="${SOAK_MINUTES:-30}"
name="sonar-soak-$$"
domain=$((150 + ($$ % 30)))
partition="sonar_soak_$$"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cleanup() {
  docker stop "$name" >/dev/null 2>&1 || true
  docker rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity >"$out/container_id.txt"
cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"; chmod 700 "\$XDG_RUNTIME_DIR"
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar \
  paused:=false x:=5.8 z:=2 yaw:=3.14 \
  compute_backend:=wgpu gui:=true headless:=true \
  > /tmp/launch.log 2>&1 &
launch_pid=\$!
printf '%s\n' "\$launch_pid" >/tmp/launch_pid.txt
ready=0
for i in \$(seq 1 300); do
  kill -0 "\$launch_pid" 2>/dev/null || break
  if grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null; then ready=1; break; fi
  sleep 1
done
printf '%s\n' "\$ready" >/tmp/backend_ready.txt
if [[ \$ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
  sleep 5
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/point_start.txt 2>&1
  timeout 180 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/raw_start.txt 2>&1
fi
wait "\$launch_pid"
printf '%s\n' "\$?" >/tmp/launch_rc.txt
INNER

docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh >"$out/inner_stdout.txt" 2>&1 &
exec_pid=$!

ready=0
for i in $(seq 1 300); do
  if docker exec "$name" grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null; then ready=1; break; fi
  kill -0 "$exec_pid" 2>/dev/null || break
  sleep 1
done
printf '%s\n' "$ready" >"$out/backend_ready.txt"
if [[ "$ready" -ne 1 ]]; then
  docker cp "$name:/tmp/launch.log" "$out/launch.log" >/dev/null 2>&1 || true
  echo 'backend did not become ready' >&2
  exit 1
fi

printf 'sample\twall_utc\telapsed_s\tcontainer_cpu_pct\tcontainer_mem_bytes\tcontainer_pids\tgz_pid\tgz_rss_kib\tgz_vsz_kib\tgz_cpu_pct\tgpu_frame\tgpu_ms\n' >"$out/resource_samples.tsv"
start_epoch=$(date +%s)
for sample in $(seq 0 "$minutes"); do
  now=$(date +%s); elapsed=$((now-start_epoch)); wall=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  stats=$(docker stats --no-stream --format '{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}' "$name" 2>/dev/null || true)
  cpu=$(printf '%s' "$stats" | awk -F '\t' '{gsub(/%/,"",$1); print $1}')
  mem_h=$(printf '%s' "$stats" | awk -F '\t' '{split($2,a," / "); print a[1]}')
  pids=$(printf '%s' "$stats" | awk -F '\t' '{print $3}')
  mem_bytes=$(docker exec -i "$name" python3 - "$mem_h" <<'PY' 2>/dev/null || echo 0
import re,sys
s=sys.argv[1]
m=re.fullmatch(r'([0-9.]+)([KMG]i?B|B)',s)
scale={'B':1,'kB':1000,'KB':1000,'KiB':1024,'MB':1000**2,'MiB':1024**2,'GB':1000**3,'GiB':1024**3}
print(int(float(m.group(1))*scale[m.group(2)]) if m else 0)
PY
)
  proc=$(docker exec "$name" bash -lc 'p=$(pgrep -f "gz-sim-main.*dave_multibeam_sonar.world" | head -1); [[ -n "$p" ]] && ps -p "$p" -o pid=,rss=,vsz=,%cpu=' 2>/dev/null || true)
  gz_pid=$(printf '%s' "$proc" | awk '{print $1}'); rss=$(printf '%s' "$proc" | awk '{print $2}'); vsz=$(printf '%s' "$proc" | awk '{print $3}'); gz_cpu=$(printf '%s' "$proc" | awk '{print $4}')
  gpu=$(docker exec "$name" bash -lc "grep -E '\[sonar_wgpu\] GPU #[0-9]+' /tmp/launch.log | tail -1" 2>/dev/null || true)
  gpu_frame=$(printf '%s' "$gpu" | sed -nE 's/.*GPU #([0-9]+).*/\1/p')
  gpu_ms=$(printf '%s' "$gpu" | sed -nE 's/.*\|[[:space:]]*([0-9.]+) ms.*/\1/p')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$sample" "$wall" "$elapsed" "${cpu:-}" "${mem_bytes:-0}" "${pids:-}" "${gz_pid:-}" "${rss:-}" "${vsz:-}" "${gz_cpu:-}" "${gpu_frame:-}" "${gpu_ms:-}" >>"$out/resource_samples.tsv"
  if [[ "$sample" -lt "$minutes" ]]; then sleep 60; fi
done

docker exec "$name" bash -lc \
  'source /opt/ros/lyrical/setup.bash; source /home/docker/dave_ws/install/setup.bash; export ROS_DOMAIN_ID='"$domain"' GZ_PARTITION='"$partition"' FASTDDS_BUILTIN_TRANSPORTS=UDPv4; ros2 daemon stop >/dev/null 2>&1 || true; ros2 daemon start >/dev/null 2>&1 || true; sleep 3; timeout 120 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter '"'"'m.width > 1'"'"' --once --no-arr >/tmp/point_end.txt 2>&1; timeout 180 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/raw_end.txt 2>&1' || true

docker exec "$name" bash -lc 'p=$(cat /tmp/launch_pid.txt); kill -INT "$p" 2>/dev/null || true; for i in $(seq 1 30); do kill -0 "$p" 2>/dev/null || exit 0; sleep 1; done; kill -TERM "$p" 2>/dev/null || true' >"$out/shutdown_command.txt" 2>&1 || true
for i in $(seq 1 40); do kill -0 "$exec_pid" 2>/dev/null || break; sleep 1; done
kill -0 "$exec_pid" 2>/dev/null && kill -TERM "$exec_pid" 2>/dev/null || true
wait "$exec_pid" 2>/dev/null || true

for f in launch.log point_start.txt raw_start.txt point_end.txt raw_end.txt launch_rc.txt daemon_restart.txt; do docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true; done
docker image inspect "$image" --format '{{.Id}}' >"$out/image_id.txt"
printf 'image=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\nminutes=%s\n' "$image" "$domain" "$partition" "$minutes" >"$out/environment.txt"
grep -E 'selected adapter|Persistent GPU buffers allocated for 513|GPU #[0-9]+|Stack trace|Segmentation fault|process has died|exit code' "$out/launch.log" >"$out/key_lines.txt" || true
