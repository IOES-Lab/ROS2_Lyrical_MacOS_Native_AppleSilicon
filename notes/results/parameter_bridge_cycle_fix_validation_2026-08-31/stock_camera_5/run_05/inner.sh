#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/bridge_cycle_ws/install/setup.bash
export ROS_DOMAIN_ID=105
export GZ_PARTITION=bridge_stock_camera_5_35810
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
if [[ "camera" == camera ]]; then
  world=camera_sensor.sdf
  gz_topic=/camera
  bridge_arg='/camera@sensor_msgs/msg/Image[gz.msgs.Image'
  ros_topic=/camera
  marker='^width: 320'
else
  world=/opt/ros/lyrical/opt/gz_sim_vendor/share/gz/gz-sim/worlds/gpu_lidar_sensor.sdf
  if [[ 0 -eq 1 ]]; then
    cp "$world" /tmp/gpu_lidar_sonar_shape.sdf
    sed -i '0,/<samples>640<\/samples>/s//<samples>513<\/samples>/' /tmp/gpu_lidar_sonar_shape.sdf
    sed -i '0,/<samples>16<\/samples>/s//<samples>301<\/samples>/' /tmp/gpu_lidar_sonar_shape.sdf
    world=/tmp/gpu_lidar_sonar_shape.sdf
  fi
  gz_topic=/lidar/points
  bridge_arg='/lidar/points@sensor_msgs/msg/PointCloud2[gz.msgs.PointCloudPacked'
  ros_topic=/lidar/points
  if [[ 0 -eq 1 ]]; then
    marker='^width: 513'
  else
    marker='^width:'
  fi
fi
gz sim -s -r "$world" >/tmp/gz.log 2>&1 & gp=$!
ready=0
for i in $(seq 1 60); do
  gz topic -l 2>/dev/null | grep -qx "$gz_topic" && ready=1 && break
  kill -0 "$gp" 2>/dev/null || break
  sleep 1
done
ros2 run ros_gz_bridge parameter_bridge "$bridge_arg" >/tmp/bridge.log 2>&1 & bp=$!
sleep 3
payload=0
timeout 30 ros2 topic echo "$ros_topic" --once --no-arr >/tmp/payload.txt 2>&1
grep -q "$marker" /tmp/payload.txt && payload=1
kill -INT "$bp" 2>/dev/null || true
wait "$bp"; brc=$?
kill -INT "$gp" 2>/dev/null || true
wait "$gp"; grc=$?
printf '%s\n' "$payload" >/tmp/payload_ok.txt
printf '%s\n' "$brc" >/tmp/bridge_rc.txt
printf '%s\n' "$grc" >/tmp/gz_rc.txt
