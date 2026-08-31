#!/usr/bin/env bash
set -u -o pipefail
repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
out="${1:-$repo/notes/results/integrated_sonar_payload_validation_2026-08-30/docker_wgpu}"
image="${DAVE_SONAR_TEST_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
backend="${BACKEND:-wgpu}"
world_name="${WORLD_NAME:-dave_ocean_waves_sonar_integrated}"
sdf_world_name="${SDF_WORLD_NAME:-oceans_waves_sonar_integrated}"
stats_messages="${STATS_MESSAGES:-1}"
name="integrated-sonar-${backend}-$$"
domain=$((190 + ($$ % 30)))
partition="integrated_sonar_${backend}_$$"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
cleanup(){ docker stop "$name" >/dev/null 2>&1 || true; docker rm "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity >"$out/container_id.txt"
cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
rm -f /tmp/{launch.log,backend_ready.txt,daemon.txt,ros_topics.txt,gz_topics.txt,point_1.txt,point_2.txt,point_3.txt,raw_1.txt,raw_2.txt,raw_3.txt,world_stats.txt,world_stats_topic.txt,gz_raw_sample.txt,gz_process.txt,launch_rc.txt}
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain GZ_PARTITION=$partition FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=$backend XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"; chmod 700 "\$XDG_RUNTIME_DIR"
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=$world_name \
  paused:=false x:=5.8 y:=0 z:=2 yaw:=3.14 \
  compute_backend:=$backend gui:=true headless:=true \
  >/tmp/launch.log 2>&1 &
launch_pid=\$!; echo "\$launch_pid" >/tmp/launch_pid.txt
ready=0
for i in \$(seq 1 360); do
  kill -0 "\$launch_pid" 2>/dev/null || break
  if [[ '$backend' == cpu ]]; then grep -q 'Creating CPU backend' /tmp/launch.log && ready=1
  else grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log && ready=1; fi
  [[ \$ready -eq 1 ]] && break
  sleep 1
done
echo "\$ready" >/tmp/backend_ready.txt
ros2 daemon stop >/tmp/daemon.txt 2>&1 || true; ros2 daemon start >>/tmp/daemon.txt 2>&1 || true; sleep 5
ros2 topic list | sort >/tmp/ros_topics.txt 2>&1 || true
gz topic -l | sort >/tmp/gz_topics.txt 2>&1 || true
for n in 1 2 3; do
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >"/tmp/point_\${n}.txt" 2>&1 || true
  timeout 180 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >"/tmp/raw_\${n}.txt" 2>&1 || true
done
# stats may use the SDF world name rather than the filename.
for topic in /world/$sdf_world_name/stats /world/$world_name/stats; do
  timeout 60 gz topic -e -t "\$topic" -n $stats_messages >/tmp/world_stats.txt 2>&1 && { echo "\$topic" >/tmp/world_stats_topic.txt; break; }
done
timeout 30 gz topic -e -t /sensor/multibeam_sonar/sonar_image -n 1 >/tmp/gz_raw_sample.txt 2>&1 || true
p=\$(pgrep -f 'gz-sim-main.*$world_name.world' | head -1)
[[ -n "\$p" ]] && ps -p "\$p" -o pid=,rss=,vsz=,%cpu=,etime= >/tmp/gz_process.txt
kill -INT "\$launch_pid" 2>/dev/null || true
for i in \$(seq 1 30); do kill -0 "\$launch_pid" 2>/dev/null || break; sleep 1; done
kill -TERM "\$launch_pid" 2>/dev/null || true
wait "\$launch_pid"; echo "\$?" >/tmp/launch_rc.txt
INNER
docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh >"$out/inner_stdout.txt" 2>&1
for f in launch.log backend_ready.txt daemon.txt ros_topics.txt gz_topics.txt point_{1,2,3}.txt raw_{1,2,3}.txt world_stats.txt world_stats_topic.txt gz_raw_sample.txt gz_process.txt launch_rc.txt; do docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true; done
docker stats --no-stream "$name" >"$out/docker_stats_end.txt" 2>&1 || true
docker image inspect "$image" --format '{{.Id}}' >"$out/image_id.txt"
printf 'image=%s\nbackend=%s\nworld=%s\nsdf_world=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\n' "$image" "$backend" "$world_name" "$sdf_world_name" "$domain" "$partition" >"$out/environment.txt"
python3 - "$out" <<'PY'
from pathlib import Path
import json,re,sys
p=Path(sys.argv[1])
def ok(pattern, files): return all(re.search(pattern,(p/f).read_text(errors='replace'),re.M) for f in files)
points=[f'point_{i}.txt' for i in range(1,4)]
raws=[f'raw_{i}.txt' for i in range(1,4)]
summary={
 'backend_ready': (p/'backend_ready.txt').read_text().strip()=='1' if (p/'backend_ready.txt').exists() else False,
 'pointcloud_frames_513x301': sum(bool(re.search(r'^height: 301\nwidth: 513$',(p/f).read_text(errors='replace'),re.M)) for f in points),
 'raw_frames_513x399': sum(bool(re.search(r'^  beam_count: 513$',(p/f).read_text(errors='replace'),re.M) and re.search(r"ranges: '<sequence type: float, length: 399>'",(p/f).read_text(errors='replace'))) for f in raws),
 'world_stats_captured': (p/'world_stats.txt').exists() and (p/'world_stats.txt').stat().st_size>0,
 'segfault_during_runtime': bool(re.search(r'Segmentation fault|exit code 139|Stack trace',(p/'launch.log').read_text(errors='replace'))),
}
(p/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
PY
