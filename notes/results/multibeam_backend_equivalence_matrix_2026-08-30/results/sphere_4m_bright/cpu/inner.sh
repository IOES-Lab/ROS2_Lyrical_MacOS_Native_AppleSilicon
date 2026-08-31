#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=209
export GZ_PARTITION=sonar_matrix_sphere_4m_bright_cpu_92549
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=cpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

timeout --signal=INT --kill-after=30s 1200s   ros2 launch dave_demos dave_sensor.launch.py     namespace:=blueview_p900 world_name:=sphere_4m_bright     paused:=false x:=4 y:=0 z:=2 roll:=0 pitch:=0 yaw:=3.14159265     compute_backend:=cpu gui:=true headless:=true     > /tmp/launch.log 2>&1 &
launch_pid=$!

ready=0
for i in $(seq 1 360); do
  if ! kill -0 "$launch_pid" 2>/dev/null; then break; fi
  if [[ "cpu" == "cpu" ]]; then
    grep -q 'Creating CPU backend' /tmp/launch.log 2>/dev/null && ready=1
  else
    grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1
  fi
  [[ $ready -eq 1 ]] && break
  sleep 1
done

capture_rc=99
if [[ $ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
  sleep 5
  timeout 700 python3 /home/docker/sonar_equivalence/capture_sonar_arrays.py     /tmp/capture sphere_4m_bright cpu 4.0 3     > /tmp/capture_stdout.txt 2>&1
  capture_rc=$?
fi

if kill -0 "$launch_pid" 2>/dev/null; then
  kill -INT "$launch_pid" 2>/dev/null || true
fi
wait "$launch_pid"
launch_rc=$?
printf '%s\n' "$ready" >/tmp/backend_ready.txt
printf '%s\n' "$capture_rc" >/tmp/capture_rc.txt
printf '%s\n' "$launch_rc" >/tmp/launch_rc.txt
exit 0
