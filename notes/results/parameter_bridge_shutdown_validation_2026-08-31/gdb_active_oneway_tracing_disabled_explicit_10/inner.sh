#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=191
export GZ_PARTITION=bridge_gdb_shutdown_191
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

config=/home/docker/dave_ws/src/dave/models/dave_sensor_models/config/blueview_p900/sensor_config.py
sed -i 's/LaunchDescription(\[bridge, tf_node\])/LaunchDescription([tf_node])/' "$config"
grep -n 'return LaunchDescription' "$config" >/tmp/bridge_disabled.txt

setsid bash -c 'trap - INT TERM; exec ros2 launch dave_demos dave_sensor.launch.py namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true' >/tmp/launch.log 2>&1 &
launch_pid=$!

ready=0
for i in $(seq 1 240); do
  kill -0 "$launch_pid" 2>/dev/null || break
  grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null && ready=1 && break
  sleep 1
done
printf '%s\n' "$ready" >/tmp/backend_ready.txt

printf 'run\tsegfault\trc\n' >/tmp/gdb_summary.tsv
exe=/opt/ros/lyrical/lib/ros_gz_bridge/parameter_bridge
arg='/sensor/multibeam_sonar/point_cloud@sensor_msgs/msg/PointCloud2[gz.msgs.PointCloudPacked'
for run in $(seq 1 10); do
  log="/tmp/gdb_run_$(printf '%02d' "$run").txt"
  timeout -s INT -k 15 10 \
    gdb -q -batch \
      -ex 'set pagination off' \
      -ex 'set confirm off' \
      -ex 'set environment TRACETOOLS_RUNTIME_DISABLE 1' \
      -ex 'set environment TRACETOOLS_VERBOSE 1' \
      -ex 'handle SIGINT pass nostop noprint' \
      -ex run \
      -ex 'thread apply all bt full' \
      --args "$exe" "$arg" >"$log" 2>&1
  rc=$?
  seg=0
  grep -Eq 'Program received signal SIGSEGV|signal SIGSEGV|Segmentation fault' "$log" && seg=1
  printf '%s\t%s\t%s\n' "$run" "$seg" "$rc" >>/tmp/gdb_summary.tsv
  sleep 2
done

kill -INT -- "-$launch_pid" 2>/dev/null || true
for i in $(seq 1 30); do
  kill -0 "$launch_pid" 2>/dev/null || break
  sleep 1
done
kill -TERM -- "-$launch_pid" 2>/dev/null || true
wait "$launch_pid" 2>/dev/null || true
exit 0
