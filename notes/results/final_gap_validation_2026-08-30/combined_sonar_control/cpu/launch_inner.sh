#!/usr/bin/env bash
set +e
ulimit -c unlimited
cd /home/docker
source /opt/ros/lyrical/setup.bash
source /home/docker/mavros_ws/install/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=181
export GZ_PARTITION=dave_combined_cpu_12531
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=cpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
timeout --signal=INT --kill-after=30s 180s \
  ros2 launch dave_demos dave_robot.launch.py \
    namespace:=bluerov2_heavy_multibeam_sonar \
    world_name:=dave_ocean_waves \
    paused:=false gui:=true headless:=true \
    use_teleop:=false use_web_joystick:=false \
    open_qgc:=false open_virtual_joystick:=false
rc=$?
printf '%s\n' "$rc" >/tmp/launch_exit_code.txt
exit "$rc"
