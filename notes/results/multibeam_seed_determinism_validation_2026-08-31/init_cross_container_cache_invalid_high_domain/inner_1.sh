#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=236
export GZ_PARTITION=sonar_cache_1_16410
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_CACHE_HOME=/persistent-cache
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
start=$(date +%s)
setsid ros2 launch dave_demos dave_sensor.launch.py   namespace:=blueview_p900 world_name:=plane_4m_bright   paused:=false x:=4 y:=0 z:=2 roll:=0 pitch:=0 yaw:=3.14159265   compute_backend:=wgpu gui:=true headless:=true >/tmp/launch.log 2>&1 &
pid=$!
ready=0
for i in $(seq 1 240); do
  kill -0 "$pid" 2>/dev/null || break
  grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log && ready=1 && break
  sleep 1
done
end=$(date +%s)
pipeline=$(sed -n 's/.*GPU pipelines compiled in \([0-9][0-9]*\) ms.*/\1/p' /tmp/launch.log | head -1)
probe=$(sed -n 's/.*GPU #1[^|]*| *\([0-9.][0-9.]*\) ms.*/\1/p' /tmp/launch.log | head -1)
printf '%s\n' "$((end-start))" >/tmp/wall.txt
printf '%s\n' "${pipeline:-missing}" >/tmp/pipeline.txt
printf '%s\n' "${probe:-missing}" >/tmp/probe.txt
printf '%s\n' "$ready" >/tmp/ready.txt
kill -INT -- "-$pid" 2>/dev/null || true
for i in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
kill -TERM -- "-$pid" 2>/dev/null || true
sleep 2
kill -KILL -- "-$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
