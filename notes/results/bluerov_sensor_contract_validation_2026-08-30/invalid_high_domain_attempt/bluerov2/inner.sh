#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/mavros_ws/install/setup.bash 2>/dev/null || true
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=237 GZ_PARTITION=sensor_audit_bluerov2_96177 FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=auto XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
ros2 launch dave_demos dave_robot.launch.py   namespace:=bluerov2 world_name:=dave_ocean_waves paused:=false   gui:=true headless:=true use_ardusub:=false use_teleop:=false   use_web_joystick:=false open_qgc:=false open_virtual_joystick:=false   >/tmp/launch.log 2>&1 &
launch_pid=$!; echo "$launch_pid" >/tmp/launch_pid.txt
for i in $(seq 1 240); do
  grep -q 'Entity creation successful' /tmp/launch.log && break
  kill -0 "$launch_pid" 2>/dev/null || break
  sleep 1
done
sleep 12
ros2 daemon stop >/tmp/daemon.txt 2>&1||true; ros2 daemon start >>/tmp/daemon.txt 2>&1||true; sleep 5
ros2 topic list | sort >/tmp/ros_topics_before_manual_bridge.txt 2>&1||true
gz topic -l | sort >/tmp/gz_topics.txt 2>&1||true
ros2 run ros_gz_bridge parameter_bridge "/model/bluerov2/camera@sensor_msgs/msg/Image[gz.msgs.Image" >/tmp/camera_bridge.log 2>&1 &
cam_bridge_pid=$!
sleep 3
ros2 daemon stop >/dev/null 2>&1||true; ros2 daemon start >/dev/null 2>&1||true; sleep 3
ros2 topic list | sort >/tmp/ros_topics_after_manual_bridge.txt 2>&1||true
for spec in   "imu:/model/bluerov2/imu:45"   "magnetometer:/model/bluerov2/magnetometer:20"   "camera:/model/bluerov2/camera:90"   "odometry:/model/bluerov2/odometry:30"; do
  IFS=: read -r label topic seconds <<<"$spec"
  timeout "$seconds" ros2 topic echo "$topic" --once --no-arr >"/tmp/${label}.txt" 2>&1||true
done
if [[ 'bluerov2' == bluerov2_heavy_multibeam_sonar ]]; then
 timeout 90 ros2 topic echo /model/bluerov2/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/sonar_point.txt 2>&1||true
 timeout 150 ros2 topic echo /model/bluerov2/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/sonar_raw.txt 2>&1||true
fi
# Default sensor path is important for the fifth model's IMU contract mismatch.
default_imu=$(grep -E "/world/.*/model/bluerov2/.*/sensor/imu_sensor/imu" /tmp/gz_topics.txt | head -1)
if [[ -n "$default_imu" ]]; then timeout 20 gz topic -e -t "$default_imu" -n 1 >/tmp/default_imu_gz.txt 2>&1||true; fi
kill -INT "$cam_bridge_pid" 2>/dev/null||true
kill -INT "$launch_pid" 2>/dev/null||true
for i in $(seq 1 30); do kill -0 "$launch_pid" 2>/dev/null||break; sleep 1; done
kill -TERM "$launch_pid" 2>/dev/null||true
wait "$launch_pid"; echo "$?" >/tmp/launch_rc.txt
