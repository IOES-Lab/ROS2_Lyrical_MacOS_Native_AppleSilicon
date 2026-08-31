#!/usr/bin/env bash
set -euo pipefail

root="${ROOT:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/multibeam_seed_determinism_validation_2026-08-31}"
image="${IMAGE:-dave-sonar-equivalence-exact-dft-v2:20260830}"
out="$root/init_cross_container_cache"
cache="$out/mesa_cache_work"
rm -rf "$out"
mkdir -p "$cache"
printf 'run\tcache_state\twall_seconds_to_full_buffers\tpipeline_compile_ms\tprobe_gpu_ms\tready\n' >"$out/summary.tsv"

for spec in '1 empty' '2 reused'; do
  read -r run state <<<"$spec"
  name="sonar-cache-${run}-$$"
  domain=$((220 + run))
  partition="sonar_cache_${run}_$$"
  docker run -d --name "$name" --entrypoint sleep \
    -v "$cache:/persistent-cache" "$image" infinity >"$out/container_${run}.txt"
  cat >"$out/inner_${run}.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_CACHE_HOME=/persistent-cache
mkdir -p "\$XDG_RUNTIME_DIR" "\$XDG_CACHE_HOME"
chmod 700 "\$XDG_RUNTIME_DIR"
start=\$(date +%s)
setsid ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=plane_4m_bright \
  paused:=false x:=4 y:=0 z:=2 roll:=0 pitch:=0 yaw:=3.14159265 \
  compute_backend:=wgpu gui:=true headless:=true >/tmp/launch.log 2>&1 &
pid=\$!
ready=0
for i in \$(seq 1 240); do
  kill -0 "\$pid" 2>/dev/null || break
  grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log && ready=1 && break
  sleep 1
done
end=\$(date +%s)
pipeline=\$(sed -n 's/.*GPU pipelines compiled in \([0-9][0-9]*\) ms.*/\1/p' /tmp/launch.log | head -1)
probe=\$(sed -n 's/.*GPU #1[^|]*| *\([0-9.][0-9.]*\) ms.*/\1/p' /tmp/launch.log | head -1)
printf '%s\n' "\$((end-start))" >/tmp/wall.txt
printf '%s\n' "\${pipeline:-missing}" >/tmp/pipeline.txt
printf '%s\n' "\${probe:-missing}" >/tmp/probe.txt
printf '%s\n' "\$ready" >/tmp/ready.txt
kill -INT -- "-\$pid" 2>/dev/null || true
for i in \$(seq 1 30); do kill -0 "\$pid" 2>/dev/null || break; sleep 1; done
kill -TERM -- "-\$pid" 2>/dev/null || true
sleep 2
kill -KILL -- "-\$pid" 2>/dev/null || true
wait "\$pid" 2>/dev/null || true
INNER
  docker cp "$out/inner_${run}.sh" "$name:/tmp/inner.sh" >/dev/null
  docker exec "$name" chmod +x /tmp/inner.sh
  docker exec "$name" /tmp/inner.sh >"$out/runner_${run}.txt" 2>&1 || true
  for f in launch.log wall.txt pipeline.txt probe.txt ready.txt; do
    docker cp "$name:/tmp/$f" "$out/${run}_${f}" >/dev/null 2>&1 || true
  done
  docker rm -f "$name" >/dev/null 2>&1 || true
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$state" \
    "$(cat "$out/${run}_wall.txt")" "$(cat "$out/${run}_pipeline.txt")" \
    "$(cat "$out/${run}_probe.txt")" "$(cat "$out/${run}_ready.txt")" >>"$out/summary.tsv"
done

find "$cache" -type f -print0 | sort -z | xargs -0 shasum -a 256 >"$out/cache_files_sha256.txt"
du -sh "$cache" >"$out/cache_size.txt"
rm -rf "$cache"
cat "$out/summary.tsv"
