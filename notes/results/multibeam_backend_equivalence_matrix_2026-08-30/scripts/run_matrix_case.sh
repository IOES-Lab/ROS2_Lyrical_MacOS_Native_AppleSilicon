#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <case> <cpu|wgpu> <expected-range-m> <output-dir>" >&2
  exit 2
fi

case_name="$1"
backend="$2"
expected="$3"
out="$4"
image="${MATRIX_IMAGE:-dave-sonar-equivalence-matrix:20260830}"
name="sonar-matrix-${case_name}-${backend}-$$"
domain=$((180 + ($$ % 30)))
partition="sonar_matrix_${case_name}_${backend}_$$"
limit="${MATRIX_CASE_LIMIT:-1200}"

mkdir -p "$out"
out="$(cd "$out" && pwd)"

cleanup() {
  docker stop "$name" >/dev/null 2>&1 || true
  docker rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity \
  > "$out/container_id.txt"

cat > "$out/inner.sh" <<INNER
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

timeout --signal=INT --kill-after=30s ${limit}s \
  ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=$case_name \
    paused:=false x:=4 y:=0 z:=2 roll:=0 pitch:=0 yaw:=3.14159265 \
    compute_backend:=$backend gui:=true headless:=true \
    > /tmp/launch.log 2>&1 &
launch_pid=\$!

ready=0
for i in \$(seq 1 360); do
  if ! kill -0 "\$launch_pid" 2>/dev/null; then break; fi
  if [[ "$backend" == "cpu" ]]; then
    grep -q 'Creating CPU backend' /tmp/launch.log 2>/dev/null && ready=1
  else
    grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1
  fi
  [[ \$ready -eq 1 ]] && break
  sleep 1
done

capture_rc=99
if [[ \$ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
  sleep 5
  timeout 700 python3 /home/docker/sonar_equivalence/capture_sonar_arrays.py \
    /tmp/capture $case_name $backend $expected 3 \
    > /tmp/capture_stdout.txt 2>&1
  capture_rc=\$?
fi

if kill -0 "\$launch_pid" 2>/dev/null; then
  kill -INT "\$launch_pid" 2>/dev/null || true
fi
wait "\$launch_pid"
launch_rc=\$?
printf '%s\n' "\$ready" >/tmp/backend_ready.txt
printf '%s\n' "\$capture_rc" >/tmp/capture_rc.txt
printf '%s\n' "\$launch_rc" >/tmp/launch_rc.txt
exit 0
INNER

docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh

for f in launch.log daemon_restart.txt capture_stdout.txt backend_ready.txt capture_rc.txt launch_rc.txt; do
  docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true
done
docker cp "$name:/tmp/capture/." "$out/" >/dev/null 2>&1 || true

grep -E 'CreateComputeBackend|selected adapter|Persistent GPU buffers allocated for 513|Creating CPU backend|GPU #[0-9]+|Stack trace|Segmentation fault|process has died|exit code' \
  "$out/launch.log" > "$out/key_lines.txt" || true
docker image inspect "$image" --format '{{.Id}}' > "$out/image_id.txt"
printf 'case=%s\nbackend=%s\nexpected_range_m=%s\nimage=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\n' \
  "$case_name" "$backend" "$expected" "$image" "$domain" "$partition" \
  > "$out/environment.txt"

cat "$out/key_lines.txt"
printf 'ready=%s capture_rc=%s launch_rc=%s\n' \
  "$(cat "$out/backend_ready.txt" 2>/dev/null || echo missing)" \
  "$(cat "$out/capture_rc.txt" 2>/dev/null || echo missing)" \
  "$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)"
