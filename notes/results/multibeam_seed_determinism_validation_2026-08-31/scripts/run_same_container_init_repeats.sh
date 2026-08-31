#!/usr/bin/env bash
set -euo pipefail

root="${ROOT:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/multibeam_seed_determinism_validation_2026-08-31}"
image="${IMAGE:-dave-sonar-equivalence-exact-dft-v2:20260830}"
name="sonar-init-repeat-$$"
out="$root/init_same_container"
mkdir -p "$out"
cleanup(){ docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity >"$out/container_id.txt"
cat >"$out/inner.sh" <<'INNER'
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=232
export GZ_PARTITION=sonar_init_repeat_232
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_CACHE_HOME=/tmp/persistent-xdg-cache
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
printf 'run\twall_seconds_to_full_buffers\tpipeline_compile_ms\tprobe_gpu_ms\tready\n' >/tmp/summary.tsv

for run in 1 2 3; do
  log="/tmp/launch_${run}.log"
  start=$(date +%s)
  setsid ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=plane_4m_bright \
    paused:=false x:=4 y:=0 z:=2 roll:=0 pitch:=0 yaw:=3.14159265 \
    compute_backend:=wgpu gui:=true headless:=true >"$log" 2>&1 &
  pid=$!
  ready=0
  for i in $(seq 1 240); do
    kill -0 "$pid" 2>/dev/null || break
    if grep -q 'Persistent GPU buffers allocated for 513' "$log"; then ready=1; break; fi
    sleep 1
  done
  end=$(date +%s)
  pipeline=$(sed -n 's/.*GPU pipelines compiled in \([0-9][0-9]*\) ms.*/\1/p' "$log" | head -1)
  probe=$(sed -n 's/.*GPU #1[^|]*| *\([0-9.][0-9.]*\) ms.*/\1/p' "$log" | head -1)
  printf '%s\t%s\t%s\t%s\t%s\n' "$run" "$((end-start))" "${pipeline:-missing}" "${probe:-missing}" "$ready" >>/tmp/summary.tsv
  kill -INT -- "-$pid" 2>/dev/null || true
  for i in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill -TERM -- "-$pid" 2>/dev/null || true
  sleep 2
  kill -KILL -- "-$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  pkill -KILL -f 'gz-sim-main.*plane_4m_bright' 2>/dev/null || true
  pkill -KILL -f '/ros_gz_bridge/parameter_bridge' 2>/dev/null || true
  sleep 2
done
du -sh "$XDG_CACHE_HOME" >/tmp/cache_size.txt
INNER

docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh >"$out/runner_stdout.txt" 2>&1 || true
for f in summary.tsv launch_1.log launch_2.log launch_3.log cache_size.txt; do
  docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true
done
docker image inspect "$image" --format '{{.Id}}' >"$out/image_id.txt"
cat "$out/summary.tsv"
