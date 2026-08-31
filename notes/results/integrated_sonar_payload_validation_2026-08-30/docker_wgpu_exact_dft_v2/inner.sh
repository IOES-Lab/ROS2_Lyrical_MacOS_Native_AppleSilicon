#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=202 GZ_PARTITION=integrated_sonar_wgpu_95892 FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
ros2 launch dave_demos dave_sensor.launch.py   namespace:=blueview_p900 world_name:=dave_ocean_waves_sonar_integrated   paused:=false x:=5.8 y:=0 z:=2 yaw:=3.14   compute_backend:=wgpu gui:=true headless:=true   >/tmp/launch.log 2>&1 &
launch_pid=$!; echo "$launch_pid" >/tmp/launch_pid.txt
ready=0
for i in $(seq 1 360); do
  kill -0 "$launch_pid" 2>/dev/null || break
  if [[ 'wgpu' == cpu ]]; then grep -q 'Creating CPU backend' /tmp/launch.log && ready=1
  else grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log && ready=1; fi
  [[ $ready -eq 1 ]] && break
  sleep 1
done
echo "$ready" >/tmp/backend_ready.txt
ros2 daemon stop >/tmp/daemon.txt 2>&1 || true; ros2 daemon start >>/tmp/daemon.txt 2>&1 || true; sleep 5
ros2 topic list | sort >/tmp/ros_topics.txt 2>&1 || true
gz topic -l | sort >/tmp/gz_topics.txt 2>&1 || true
for n in 1 2 3; do
  timeout 120 ros2 topic echo /sensor/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >"/tmp/point_${n}.txt" 2>&1 || true
  timeout 180 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw --once --no-arr >"/tmp/raw_${n}.txt" 2>&1 || true
done
# stats may use the SDF world name rather than the filename.
for topic in /world/oceans_waves_sonar_integrated/stats /world/dave_ocean_waves_sonar_integrated/stats; do
  timeout 10 gz topic -e -t "$topic" -n 1 >/tmp/world_stats.txt 2>&1 && { echo "$topic" >/tmp/world_stats_topic.txt; break; }
done
gz topic -e -t /sensor/multibeam_sonar/sonar_image -n 1 >/tmp/gz_raw_sample.txt 2>&1 || true
p=$(pgrep -f 'gz-sim-main.*dave_ocean_waves_sonar_integrated.world' | head -1)
[[ -n "$p" ]] && ps -p "$p" -o pid=,rss=,vsz=,%cpu=,etime= >/tmp/gz_process.txt
kill -INT "$launch_pid" 2>/dev/null || true
for i in $(seq 1 30); do kill -0 "$launch_pid" 2>/dev/null || break; sleep 1; done
kill -TERM "$launch_pid" 2>/dev/null || true
wait "$launch_pid"; echo "$?" >/tmp/launch_rc.txt
