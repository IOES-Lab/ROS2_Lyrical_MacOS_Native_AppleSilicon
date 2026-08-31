#!/usr/bin/env bash
set -euo pipefail

root="${1:?output root required}"
image="${BRIDGE_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
runs="${BRIDGE_RUNS:-10}"
delay="${BRIDGE_SIM_FIRST_DELAY:-5}"
mkdir -p "$root"
printf 'run\tbackend_ready\tpoint\traw\tsimulator_exit\tdelay_s\tbridge_result\tlaunch_rc\n' >"$root/summary.tsv"

cleanup_container() {
  docker rm -f "$1" >/dev/null 2>&1 || true
}

for run in $(seq 1 "$runs"); do
  out="$root/run_$(printf '%02d' "$run")"
  mkdir -p "$out"
  name="bridge-sim-first-${run}-$$"
  domain=$((190 + run))
  partition="bridge_sim_first_${run}_$$"
  cleanup_container "$name"
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
mkdir -p "\$XDG_RUNTIME_DIR" && chmod 700 "\$XDG_RUNTIME_DIR"

config=/home/docker/dave_ws/src/dave/models/dave_sensor_models/config/blueview_p900/sensor_config.py
sed -i 's/@gz\.msgs/[gz.msgs/g' "\$config"

setsid bash -c 'trap - INT TERM; exec ros2 launch dave_demos dave_sensor.launch.py namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true' >/tmp/launch.log 2>&1 &
launch_pid=\$!

ready=0
for i in \$(seq 1 240); do
  kill -0 "\$launch_pid" 2>/dev/null || break
  grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1 && break
  sleep 1
done

point=0; raw=0
if [[ \$ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon.txt 2>&1 || true
  sleep 3
  timeout 60 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/point.txt 2>&1
  grep -q '^width: 513' /tmp/point.txt && point=1
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/raw.txt 2>&1
  grep -q '^  beam_count: 513' /tmp/raw.txt && raw=1
fi

gz_pid=\$(pgrep -f 'gz-sim-main.*dave_multibeam_sonar.world' | head -1)
bridge_pid=\$(pgrep -f '/ros_gz_bridge/parameter_bridge' | head -1)
printf '%s\n' "\$gz_pid" >/tmp/gz_pid.txt
printf '%s\n' "\$bridge_pid" >/tmp/bridge_pid.txt

sim_result=pid_missing
if [[ -n "\$gz_pid" ]]; then
  kill -INT "\$gz_pid" 2>/dev/null || true
  for i in \$(seq 1 30); do
    kill -0 "\$gz_pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "\$gz_pid" 2>/dev/null; then
    kill -TERM "\$gz_pid" 2>/dev/null || true
    sleep 3
  fi
  if kill -0 "\$gz_pid" 2>/dev/null; then
    sim_result=still_running
  else
    sim_result=exited
  fi
fi

sleep $delay
bridge_result=pid_missing
if [[ -n "\$bridge_pid" ]] && kill -0 "\$bridge_pid" 2>/dev/null; then
  kill -INT "\$bridge_pid" 2>/dev/null || true
  for i in \$(seq 1 30); do
    kill -0 "\$bridge_pid" 2>/dev/null || break
    sleep 1
  done
  sleep 2
  if kill -0 "\$bridge_pid" 2>/dev/null; then
    bridge_result=still_running
  elif grep -q '\[ERROR\] \[parameter_bridge-.*exit code -11' /tmp/launch.log; then
    bridge_result=segfault
  elif grep -q '\[INFO\] \[parameter_bridge-.*process has finished cleanly' /tmp/launch.log; then
    bridge_result=clean
  else
    bridge_result=exited_unknown
  fi
fi

kill -INT -- "-\$launch_pid" 2>/dev/null || true
for i in \$(seq 1 20); do
  kill -0 "\$launch_pid" 2>/dev/null || break
  sleep 1
done
kill -TERM -- "-\$launch_pid" 2>/dev/null || true
sleep 2
kill -KILL -- "-\$launch_pid" 2>/dev/null || true
wait "\$launch_pid"; rc=\$?

printf '%s\n' "\$ready" >/tmp/backend_ready.txt
printf '%s\n' "\$point" >/tmp/point_ok.txt
printf '%s\n' "\$raw" >/tmp/raw_ok.txt
printf '%s\n' "\$sim_result" >/tmp/simulator_result.txt
printf '%s\n' "\$bridge_result" >/tmp/bridge_result.txt
printf '%s\n' "\$rc" >/tmp/launch_rc.txt
exit 0
INNER

  docker cp "$out/inner.sh" "$name":/tmp/inner.sh >/dev/null
  docker exec "$name" chmod +x /tmp/inner.sh
  docker exec "$name" /tmp/inner.sh >"$out/runner_stdout.txt" 2>&1 || true
  for file in launch.log daemon.txt point.txt raw.txt backend_ready.txt point_ok.txt raw_ok.txt simulator_result.txt bridge_result.txt launch_rc.txt gz_pid.txt bridge_pid.txt; do
    docker cp "$name:/tmp/$file" "$out/$file" >/dev/null 2>&1 || true
  done
  ready=$(cat "$out/backend_ready.txt" 2>/dev/null || echo missing)
  point=$(cat "$out/point_ok.txt" 2>/dev/null || echo missing)
  raw=$(cat "$out/raw_ok.txt" 2>/dev/null || echo missing)
  sim=$(cat "$out/simulator_result.txt" 2>/dev/null || echo missing)
  bridge=$(cat "$out/bridge_result.txt" 2>/dev/null || echo missing)
  rc=$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$ready" "$point" "$raw" "$sim" "$delay" "$bridge" "$rc" >>"$root/summary.tsv"
  cleanup_container "$name"
  echo "run=$run ready=$ready point=$point raw=$raw sim=$sim delay=$delay bridge=$bridge rc=$rc"
done

docker image inspect "$image" --format '{{.Id}}' >"$root/image_id.txt"
