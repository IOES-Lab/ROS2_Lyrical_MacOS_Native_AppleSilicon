#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=153
export GZ_PARTITION=sonar_soak_97023
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
ros2 launch dave_demos dave_sensor.launch.py   namespace:=blueview_p900 world_name:=dave_multibeam_sonar   paused:=false x:=5.8 z:=2 yaw:=3.14   compute_backend:=wgpu gui:=true headless:=true   > /tmp/launch.log 2>&1 &
launch_pid=$!
printf '%s\n' "$launch_pid" >/tmp/launch_pid.txt
ready=0
for i in $(seq 1 300); do
  kill -0 "$launch_pid" 2>/dev/null || break
  if grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null; then ready=1; break; fi
  sleep 1
done
printf '%s\n' "$ready" >/tmp/backend_ready.txt
if [[ $ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
  sleep 5
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/point_start.txt 2>&1
  timeout 180 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/raw_start.txt 2>&1
fi
wait "$launch_pid"
printf '%s\n' "$?" >/tmp/launch_rc.txt
