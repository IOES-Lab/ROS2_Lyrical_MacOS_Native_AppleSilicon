#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${1:-lyrical-no-cache-rdp}"
OUT="${2:-.}"
mkdir -p "$OUT"

display="$(docker exec "$CONTAINER" bash -lc \
  'find /tmp/.X11-unix -maxdepth 1 -type s -name "X*" -print 2>/dev/null | head -1' \
  | sed 's#.*/X##')"
test -n "$display"

docker exec -d -u docker "$CONTAINER" bash -lc "
  source /opt/ros/lyrical/setup.bash
  source /home/docker/dave_ws/install/setup.bash
  source /home/docker/mavros_ws/install/setup.bash
  export DISPLAY=:${display}
  export XAUTHORITY=/home/docker/.Xauthority
  export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
  export ROS_DOMAIN_ID=62
  exec ros2 launch dave_demos dave_robot.launch.py \\
    namespace:=bluerov2 world_name:=empty.sdf paused:=false \\
    x:=0 y:=0 z:=-0.5 roll:=0 pitch:=0 yaw:=0 \\
    gui:=true headless:=false \\
    use_teleop:=false use_web_joystick:=false \\
    open_qgc:=false open_virtual_joystick:=false \\
    > /home/docker/no_cache_integrated_launch.log 2>&1
"

connected=false
for _ in $(seq 1 90); do
  if docker exec -u docker "$CONTAINER" bash -lc '
    source /opt/ros/lyrical/setup.bash
    source /home/docker/dave_ws/install/setup.bash
    source /home/docker/mavros_ws/install/setup.bash
    export FASTDDS_BUILTIN_TRANSPORTS=UDPv4 ROS_DOMAIN_ID=62
    timeout 6 ros2 topic echo /mavros/state --once --no-arr 2>/dev/null
  ' > "$OUT/mavros_state_latest.txt" && \
     grep -q '^connected: true' "$OUT/mavros_state_latest.txt"; then
    connected=true
    break
  fi
  sleep 2
done
test "$connected" = true

docker exec -d -u docker "$CONTAINER" bash -lc "
  export DISPLAY=:${display}
  export XAUTHORITY=/home/docker/.Xauthority
  export QGC_NO_SYSTEM_GLIB=1
  exec /home/docker/QGC/AppRun --logging LinkManagerLog.debug=true --log-output \\
    > /home/docker/no_cache_qgc.log 2>&1
"

sleep 25
docker exec -u docker "$CONTAINER" bash -lc \
  "DISPLAY=:${display} XAUTHORITY=/home/docker/.Xauthority \
   xwd -root -silent -out /home/docker/no_cache_qgc_connected.xwd && \
   ffmpeg -y -loglevel error -i /home/docker/no_cache_qgc_connected.xwd \
     /home/docker/no_cache_qgc_connected.png"
docker cp "$CONTAINER":/home/docker/no_cache_qgc_connected.png \
  "$OUT/no_cache_qgc_connected.png"
docker cp "$CONTAINER":/home/docker/no_cache_integrated_launch.log \
  "$OUT/integrated_launch.log"
docker cp "$CONTAINER":/home/docker/no_cache_qgc.log "$OUT/qgc.log"

docker exec "$CONTAINER" bash -lc '
  ps -eo pid,comm,args | grep -E "[g]z-sim-main|[a]rdusub|[m]avros_node|[Q]GroundControl"
' | tee "$OUT/runtime_processes.txt"

cat > "$OUT/integrated_summary.json" <<EOF
{
  "rdp_display": ":${display}",
  "mavros_connected": true,
  "qgc_opt_out": "QGC_NO_SYSTEM_GLIB=1",
  "rendered_framebuffer_captured": true
}
EOF
