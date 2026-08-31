#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=99
export GZ_PARTITION=sonar_derived_wgpu_89809
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

timeout --signal=INT --kill-after=20s 300s   ros2 launch dave_demos dave_sensor.launch.py     namespace:=blueview_p900 world_name:=dave_multibeam_sonar     paused:=false x:=5.8 z:=2 yaw:=3.14     compute_backend:=wgpu gui:=true headless:=true     > /tmp/launch.log 2>&1 &
launch_pid=$!

ready=0
for i in $(seq 1 300); do
  if ! kill -0 "$launch_pid" 2>/dev/null; then
    break
  fi
  if [[ "wgpu" == cpu ]]; then
    grep -q 'Creating CPU backend' /tmp/launch.log 2>/dev/null && ready=1
  else
    grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1
  fi
  [[ $ready -eq 1 ]] && break
  sleep 1
done

point_ok=0
raw_ok=0
if [[ $ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
  sleep 5
  ros2 topic list | sort > /tmp/topic_list.txt 2>&1 || true

  for attempt in 1 2 3; do
    timeout 45 ros2 topic echo /sensor/multibeam_sonar/point_cloud       --filter 'm.width > 1' --once --no-arr > /tmp/point_cloud.txt 2>&1
    if grep -q '^width: 513' /tmp/point_cloud.txt; then
      point_ok=1
      break
    fi
    sleep 3
  done

  for attempt in 1 2 3; do
    timeout 90 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw       --once --no-arr > /tmp/raw_sonar.txt 2>&1
    if grep -q '^  beam_count: 513' /tmp/raw_sonar.txt; then
      raw_ok=1
      break
    fi
    sleep 3
  done
fi

if kill -0 "$launch_pid" 2>/dev/null; then
  kill -INT "$launch_pid" 2>/dev/null || true
fi
wait "$launch_pid"
rc=$?
printf '%s\n' "$rc" >/tmp/launch_rc.txt
printf '%s\n' "$ready" >/tmp/backend_ready.txt
printf '%s\n' "$point_ok" >/tmp/point_ok.txt
printf '%s\n' "$raw_ok" >/tmp/raw_ok.txt
exit 0
