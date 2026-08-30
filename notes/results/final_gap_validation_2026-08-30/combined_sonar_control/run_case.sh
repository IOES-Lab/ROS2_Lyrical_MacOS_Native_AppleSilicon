#!/usr/bin/env bash
set -uo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <auto|cpu> <output-dir> [timeout-seconds]" >&2
  exit 2
fi

backend="$1"
out="$2"
limit_s="${3:-300}"
image="lyrical-sim:jetty-rdp-external-stack-check"
repo="$(git rev-parse --show-toplevel)"
patch="$repo/patches/fifth_rov_sonar_world_fix.diff"
name="dave-combined-${backend}-$$"
domain=$((170 + ($$ % 20)))
partition="dave_combined_${backend}_$$"

case "$backend" in
  auto|cpu) ;;
  *) echo "unsupported backend: $backend" >&2; exit 2 ;;
esac

mkdir -p "$out"
out="$(cd "$out" && pwd)"
exec > >(tee "$out/runner.log") 2>&1

cleanup() {
  docker rm -f "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

printf 'image=%s\nbackend=%s\nlimit_s=%s\ncontainer=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\n' \
  "$image" "$backend" "$limit_s" "$name" "$domain" "$partition" \
  >"$out/environment.txt"
docker image inspect "$image" --format '{{.Id}}' >>"$out/environment.txt"

docker run -d \
  --name "$name" \
  --ulimit core=-1 \
  --cap-add SYS_PTRACE \
  --security-opt seccomp=unconfined \
  --entrypoint sleep \
  "$image" infinity >"$out/container_id.txt"

docker cp "$patch" "$name":/tmp/fifth_rov_sonar_world_fix.diff

docker exec "$name" bash -lc '
set -euo pipefail
cd /home/docker/dave_ws/src/dave
git apply --check /tmp/fifth_rov_sonar_world_fix.diff
git apply /tmp/fifth_rov_sonar_world_fix.diff
grep -n -A3 -B3 custom::MultibeamSonarSystem \
  models/dave_worlds/worlds/dave_ocean_waves.world
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
cd /home/docker/dave_ws
colcon build --packages-select dave_worlds --cmake-args -DCMAKE_BUILD_TYPE=Release
' >"$out/candidate_build.txt" 2>&1

launch_inner="/tmp/run_combined_${backend}.sh"
cat >"$out/launch_inner.sh" <<INNER
#!/usr/bin/env bash
set +e
ulimit -c unlimited
cd /home/docker
source /opt/ros/lyrical/setup.bash
source /home/docker/mavros_ws/install/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=$backend
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"
timeout --signal=INT --kill-after=30s ${limit_s}s \\
  ros2 launch dave_demos dave_robot.launch.py \\
    namespace:=bluerov2_heavy_multibeam_sonar \\
    world_name:=dave_ocean_waves \\
    paused:=false gui:=true headless:=true \\
    use_teleop:=false use_web_joystick:=false \\
    open_qgc:=false open_virtual_joystick:=false
rc=\$?
printf '%s\n' "\$rc" >/tmp/launch_exit_code.txt
exit "\$rc"
INNER
docker cp "$out/launch_inner.sh" "$name":"$launch_inner"
docker exec "$name" chmod +x "$launch_inner"

set +e
docker exec "$name" "$launch_inner" >"$out/launch.log" 2>&1 &
launch_host_pid=$!
echo "$launch_host_pid" >"$out/launch_host_pid.txt"

stack_seen=0
gz_seen=0
for ((i=1; i<=limit_s; i++)); do
  if ! kill -0 "$launch_host_pid" 2>/dev/null; then
    break
  fi
  if docker exec "$name" pgrep -f 'gz-sim-main.*dave_ocean_waves.world' \
      >"$out/gz_pid_latest.txt" 2>/dev/null; then
    gz_seen=1
  fi
  if [[ $stack_seen -eq 0 ]] && grep -q 'Stack trace' "$out/launch.log" 2>/dev/null; then
    stack_seen=1
    date -u +%FT%TZ >"$out/stack_trace_seen_at.txt"
    gzpid="$(head -1 "$out/gz_pid_latest.txt" 2>/dev/null || true)"
    if [[ -n "$gzpid" ]]; then
      docker exec "$name" bash -lc \
        "timeout 90 gdb -q -batch \
          -ex 'set pagination off' \
          -ex 'info program' \
          -ex 'info threads' \
          -ex 'thread apply all bt full' \
          -ex 'detach' \
          -p $gzpid" \
        >"$out/gdb_live_backtrace.txt" 2>&1 || true
    fi
  fi
  sleep 1
done

wait "$launch_host_pid"
launch_exec_rc=$?
printf '%s\n' "$launch_exec_rc" >"$out/docker_exec_exit_code.txt"

docker exec "$name" cat /tmp/launch_exit_code.txt \
  >"$out/launch_exit_code.txt" 2>/dev/null || true
docker exec "$name" bash -lc \
  "printf 'core_pattern='; cat /proc/sys/kernel/core_pattern; \
   printf 'ulimit_core='; ulimit -c; \
   find /home/docker /tmp -maxdepth 3 -type f -name 'core*' -printf '%p %s bytes\\n' 2>/dev/null" \
  >"$out/core_inventory.txt" 2>&1 || true

if grep -q '^/home/docker/core ' "$out/core_inventory.txt"; then
  docker exec "$name" bash -lc \
    "file /home/docker/core" >"$out/core_file_identity.txt" 2>&1 || true
  if grep -q 'parameter_bridge' "$out/core_file_identity.txt"; then
    core_exe=/opt/ros/lyrical/lib/ros_gz_bridge/parameter_bridge
  else
    core_exe=/opt/ros/lyrical/opt/gz_sim_vendor/libexec/gz/sim10/gz-sim-main
  fi
  docker exec "$name" bash -lc \
    "timeout 120 gdb -q -batch \
       -ex 'set pagination off' \
       -ex 'info program' \
       -ex 'info threads' \
       -ex 'thread apply all bt' \
       '$core_exe' /home/docker/core" \
    >"$out/gdb_core_backtrace.txt" 2>&1 || true
fi

docker exec "$name" bash -lc \
  "source /opt/ros/lyrical/setup.bash; \
   source /home/docker/mavros_ws/install/setup.bash; \
   source /home/docker/dave_ws/install/setup.bash; \
   export ROS_DOMAIN_ID=$domain GZ_PARTITION=$partition FASTDDS_BUILTIN_TRANSPORTS=UDPv4; \
   ros2 topic list 2>&1 | sort" \
  >"$out/topic_list_after.txt" 2>&1 || true

docker exec "$name" ps -eo pid,ppid,stat,comm,args \
  >"$out/processes_after.txt" 2>&1 || true

grep -E \
  'selected adapter|GPU #[0-9]+|Creating CPU backend|SONAR PLUGIN LOADED|# of Beams|# of Rays|# of Time data|Stack trace|process has died|exit code|No JSON sensor message' \
  "$out/launch.log" >"$out/key_lines.txt" || true

printf 'stack_trace_seen=%s\ngz_process_seen=%s\nno_json_count=%s\n' \
  "$stack_seen" "$gz_seen" \
  "$(grep -c 'No JSON sensor message' "$out/launch.log" 2>/dev/null || true)" \
  >"$out/observations.txt"

exit 0
