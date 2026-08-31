#!/usr/bin/env bash
set -euo pipefail

root="${1:?output root required}"
image="${BRIDGE_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
runs="${BRIDGE_RUNS:-10}"
early_stop="${BRIDGE_EARLY_STOP:-0}"
tracing_disable="${BRIDGE_TRACETOOLS_DISABLE:-0}"
early_signal="${BRIDGE_EARLY_SIGNAL:-INT}"
point_only="${BRIDGE_POINT_ONLY:-0}"
extra_setup="${BRIDGE_EXTRA_SETUP:-}"
mkdir -p "$root"
printf 'run\tbackend_ready\tpoint\traw\tlaunch_rc\tlaunch_escalation\tbridge_early_result\tbridge_exit_minus11\n' >"$root/summary.tsv"

cleanup_container() {
  local name="$1"
  docker rm -f "$name" >/dev/null 2>&1 || true
}

for run in $(seq 1 "$runs"); do
  out="$root/run_$(printf '%02d' "$run")"
  mkdir -p "$out"
  name="bridge-oneway-active-${run}-$$"
  domain=$((150 + run))
  partition="bridge_oneway_active_${run}_$$"
  cleanup_container "$name"
  docker run -d --name "$name" --entrypoint sleep "$image" infinity >"$out/container_id.txt"

  cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
if [[ -n "$extra_setup" && -f "$extra_setup" ]]; then
  source "$extra_setup"
fi
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export TRACETOOLS_RUNTIME_DISABLE=$tracing_disable
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

config=/home/docker/dave_ws/src/dave/models/dave_sensor_models/config/blueview_p900/sensor_config.py
cp "\$config" /tmp/sensor_config.original.py
sed -i 's/@gz\.msgs/[gz.msgs/g' "\$config"
if [[ $point_only -eq 1 ]]; then
  sed -i '/sensor\/camera@/d; /sensor\/camera_info@/d; /sensor\/depth_camera@/d' "\$config"
fi
grep -n 'sensor/.*\[gz.msgs' "\$config" >/tmp/bridge_arguments.txt

setsid bash -c 'trap - INT TERM; exec ros2 launch dave_demos dave_sensor.launch.py namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true' >/tmp/launch.log 2>&1 &
launch_pid=\$!

ready=0
for i in \$(seq 1 240); do
  kill -0 "\$launch_pid" 2>/dev/null || break
  grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1 && break
  sleep 1
done

point=0
raw=0
if [[ \$ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon.txt 2>&1 || true
  sleep 4
  timeout 60 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/point.txt 2>&1
  grep -q '^width: 513' /tmp/point.txt && point=1
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/raw.txt 2>&1
  grep -q '^  beam_count: 513' /tmp/raw.txt && raw=1
fi

early_result=not_requested
if [[ $early_stop -eq 1 ]]; then
  bridge_pid=\$(pgrep -f '/ros_gz_bridge/parameter_bridge' | head -1)
  if [[ -n "\$bridge_pid" ]]; then
    kill -$early_signal "\$bridge_pid" 2>/dev/null || true
    for i in \$(seq 1 20); do
      kill -0 "\$bridge_pid" 2>/dev/null || break
      sleep 1
    done
    if kill -0 "\$bridge_pid" 2>/dev/null; then
      early_result=still_running
    else
      sleep 2
      if grep -q '\[ERROR\] \[parameter_bridge-.*exit code -11' /tmp/launch.log; then
        early_result=segfault
      elif grep -q '\[INFO\] \[parameter_bridge-.*process has finished cleanly' /tmp/launch.log; then
        early_result=clean
      else
        early_result=exited_unknown
      fi
    fi
  else
    early_result=pid_missing
  fi
fi

kill -INT -- "-\$launch_pid" 2>/dev/null || true
escalation=none
for i in \$(seq 1 30); do
  kill -0 "\$launch_pid" 2>/dev/null || break
  sleep 1
done
if kill -0 "\$launch_pid" 2>/dev/null; then
  escalation=TERM
  kill -TERM -- "-\$launch_pid" 2>/dev/null || true
  sleep 3
fi
if kill -0 "\$launch_pid" 2>/dev/null; then
  escalation=KILL
  kill -KILL -- "-\$launch_pid" 2>/dev/null || true
fi
wait "\$launch_pid"
rc=\$?
printf '%s\n' "\$ready" >/tmp/backend_ready.txt
printf '%s\n' "\$point" >/tmp/point_ok.txt
printf '%s\n' "\$raw" >/tmp/raw_ok.txt
printf '%s\n' "\$rc" >/tmp/launch_rc.txt
printf '%s\n' "\$escalation" >/tmp/escalation.txt
printf '%s\n' "\$early_result" >/tmp/bridge_early_result.txt
exit 0
INNER

  docker cp "$out/inner.sh" "$name":/tmp/inner.sh >/dev/null
  docker exec "$name" chmod +x /tmp/inner.sh
  docker exec "$name" /tmp/inner.sh >"$out/runner_stdout.txt" 2>&1 || true
  for file in launch.log bridge_arguments.txt backend_ready.txt point_ok.txt raw_ok.txt launch_rc.txt escalation.txt bridge_early_result.txt point.txt raw.txt daemon.txt; do
    docker cp "$name:/tmp/$file" "$out/$file" >/dev/null 2>&1 || true
  done
  ready=$(cat "$out/backend_ready.txt" 2>/dev/null || echo missing)
  point=$(cat "$out/point_ok.txt" 2>/dev/null || echo missing)
  raw=$(cat "$out/raw_ok.txt" 2>/dev/null || echo missing)
  rc=$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)
  escalation=$(cat "$out/escalation.txt" 2>/dev/null || echo missing)
  early_result=$(cat "$out/bridge_early_result.txt" 2>/dev/null || echo missing)
  bridge11=0
  grep -q '\[ERROR\] \[parameter_bridge-.*exit code -11' "$out/launch.log" 2>/dev/null && bridge11=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$run" "$ready" "$point" "$raw" "$rc" "$escalation" "$early_result" "$bridge11" >>"$root/summary.tsv"
  docker image inspect "$image" --format '{{.Id}}' >"$out/image_id.txt"
  cleanup_container "$name"
  echo "run=$run ready=$ready point=$point raw=$raw rc=$rc escalation=$escalation early=$early_result bridge11=$bridge11"
done

docker image inspect "$image" --format '{{.Id}}' >"$root/image_id.txt"
