#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=154
export GZ_PARTITION=bridge_oneway_active_4_11398
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

config=/home/docker/dave_ws/src/dave/models/dave_sensor_models/config/blueview_p900/sensor_config.py
cp "$config" /tmp/sensor_config.original.py
sed -i 's/@gz\.msgs/[gz.msgs/g' "$config"
grep -n 'sensor/.*\[gz.msgs' "$config" >/tmp/bridge_arguments.txt

setsid bash -c 'trap - INT TERM; exec ros2 launch dave_demos dave_sensor.launch.py namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true' >/tmp/launch.log 2>&1 &
launch_pid=$!

ready=0
for i in $(seq 1 240); do
  kill -0 "$launch_pid" 2>/dev/null || break
  grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1 && break
  sleep 1
done

point=0
raw=0
if [[ $ready -eq 1 ]]; then
  ros2 daemon stop >/tmp/daemon.txt 2>&1 || true
  ros2 daemon start >>/tmp/daemon.txt 2>&1 || true
  sleep 4
  timeout 60 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/point.txt 2>&1
  grep -q '^width: 513' /tmp/point.txt && point=1
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/raw.txt 2>&1
  grep -q '^  beam_count: 513' /tmp/raw.txt && raw=1
fi

kill -INT -- "-$launch_pid" 2>/dev/null || true
escalation=none
for i in $(seq 1 30); do
  kill -0 "$launch_pid" 2>/dev/null || break
  sleep 1
done
if kill -0 "$launch_pid" 2>/dev/null; then
  escalation=TERM
  kill -TERM -- "-$launch_pid" 2>/dev/null || true
  sleep 3
fi
if kill -0 "$launch_pid" 2>/dev/null; then
  escalation=KILL
  kill -KILL -- "-$launch_pid" 2>/dev/null || true
fi
wait "$launch_pid"
rc=$?
printf '%s\n' "$ready" >/tmp/backend_ready.txt
printf '%s\n' "$point" >/tmp/point_ok.txt
printf '%s\n' "$raw" >/tmp/raw_ok.txt
printf '%s\n' "$rc" >/tmp/launch_rc.txt
printf '%s\n' "$escalation" >/tmp/escalation.txt
exit 0
