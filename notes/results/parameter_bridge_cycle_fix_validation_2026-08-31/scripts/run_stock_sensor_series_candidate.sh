#!/usr/bin/env bash
set -euo pipefail

root="${1:?output root required}"
kind="${2:?camera or pointcloud required}"
image="${BRIDGE_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
runs="${BRIDGE_RUNS:-10}"
sonar_shape="${STOCK_LIDAR_SONAR_SHAPE:-0}"
mkdir -p "$root"
printf 'case\trun\tpayload\tbridge_rc\tbridge_segfault\tgz_rc\n' >"$root/summary.tsv"

for run in $(seq 1 "$runs"); do
  out="$root/run_$(printf '%02d' "$run")"; mkdir -p "$out"
  name="bridge-stock-${kind}-${run}-$$"
  domain=$((100 + run))
  partition="bridge_stock_${kind}_${run}_$$"
  docker run -d --name "$name" --entrypoint sleep "$image" infinity >"$out/container_id.txt"
  cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/bridge_cycle_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"; chmod 700 "\$XDG_RUNTIME_DIR"
if [[ "$kind" == camera ]]; then
  world=camera_sensor.sdf
  gz_topic=/camera
  bridge_arg='/camera@sensor_msgs/msg/Image[gz.msgs.Image'
  ros_topic=/camera
  marker='^width: 320'
else
  world=/opt/ros/lyrical/opt/gz_sim_vendor/share/gz/gz-sim/worlds/gpu_lidar_sensor.sdf
  if [[ $sonar_shape -eq 1 ]]; then
    cp "\$world" /tmp/gpu_lidar_sonar_shape.sdf
    sed -i '0,/<samples>640<\/samples>/s//<samples>513<\/samples>/' /tmp/gpu_lidar_sonar_shape.sdf
    sed -i '0,/<samples>16<\/samples>/s//<samples>301<\/samples>/' /tmp/gpu_lidar_sonar_shape.sdf
    world=/tmp/gpu_lidar_sonar_shape.sdf
  fi
  gz_topic=/lidar/points
  bridge_arg='/lidar/points@sensor_msgs/msg/PointCloud2[gz.msgs.PointCloudPacked'
  ros_topic=/lidar/points
  if [[ $sonar_shape -eq 1 ]]; then
    marker='^width: 513'
  else
    marker='^width:'
  fi
fi
gz sim -s -r "\$world" >/tmp/gz.log 2>&1 & gp=\$!
ready=0
for i in \$(seq 1 60); do
  gz topic -l 2>/dev/null | grep -qx "\$gz_topic" && ready=1 && break
  kill -0 "\$gp" 2>/dev/null || break
  sleep 1
done
ros2 run ros_gz_bridge parameter_bridge "\$bridge_arg" >/tmp/bridge.log 2>&1 & bp=\$!
sleep 3
payload=0
timeout 30 ros2 topic echo "\$ros_topic" --once --no-arr >/tmp/payload.txt 2>&1
grep -q "\$marker" /tmp/payload.txt && payload=1
kill -INT "\$bp" 2>/dev/null || true
wait "\$bp"; brc=\$?
kill -INT "\$gp" 2>/dev/null || true
wait "\$gp"; grc=\$?
printf '%s\n' "\$payload" >/tmp/payload_ok.txt
printf '%s\n' "\$brc" >/tmp/bridge_rc.txt
printf '%s\n' "\$grc" >/tmp/gz_rc.txt
INNER
  docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
  docker exec "$name" chmod +x /tmp/inner.sh
  docker exec "$name" /tmp/inner.sh >"$out/runner_stdout.txt" 2>&1 || true
  for f in gz.log bridge.log payload.txt payload_ok.txt bridge_rc.txt gz_rc.txt; do
    docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true
  done
  payload=$(cat "$out/payload_ok.txt" 2>/dev/null || echo missing)
  brc=$(cat "$out/bridge_rc.txt" 2>/dev/null || echo missing)
  grc=$(cat "$out/gz_rc.txt" 2>/dev/null || echo missing)
  seg=0; [[ "$brc" == 139 ]] && seg=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$run" "$payload" "$brc" "$seg" "$grc" >>"$root/summary.tsv"
  docker rm -f "$name" >/dev/null 2>&1 || true
  echo "$kind run=$run payload=$payload bridge_rc=$brc seg=$seg gz_rc=$grc"
done
