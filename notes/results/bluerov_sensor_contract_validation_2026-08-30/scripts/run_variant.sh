#!/usr/bin/env bash
set -u -o pipefail
if [[ $# -ne 3 ]]; then echo "usage: $0 <variant> <out> <backend>" >&2; exit 2; fi
variant="$1"; out="$2"; backend="$3"
image="${DAVE_SONAR_TEST_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
name="sensor-audit-${variant//_/-}-$$"
# Keep the Fast DDS domain well below its implementation-specific upper
# transport-port limit.  The first harness used 220..239; IDs above 232 made
# create and bridge processes fail before the model was spawned.
domain=$((80 + ($$ % 40))); partition="sensor_audit_${variant}_$$"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
cleanup(){ docker stop "$name" >/dev/null 2>&1||true; docker rm "$name" >/dev/null 2>&1||true; }
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity >"$out/container_id.txt"
cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/mavros_ws/install/setup.bash 2>/dev/null || true
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain GZ_PARTITION=$partition FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=$backend XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"; chmod 700 "\$XDG_RUNTIME_DIR"
ros2 launch dave_demos dave_robot.launch.py \
  namespace:=$variant world_name:=dave_ocean_waves paused:=false \
  gui:=true headless:=true use_ardusub:=false use_teleop:=false \
  use_web_joystick:=false open_qgc:=false open_virtual_joystick:=false \
  >/tmp/launch.log 2>&1 &
launch_pid=\$!; echo "\$launch_pid" >/tmp/launch_pid.txt
for i in \$(seq 1 240); do
  grep -q 'Entity creation successful' /tmp/launch.log && break
  kill -0 "\$launch_pid" 2>/dev/null || break
  sleep 1
done
sleep 12
ros2 daemon stop >/tmp/daemon.txt 2>&1||true; ros2 daemon start >>/tmp/daemon.txt 2>&1||true; sleep 5
ros2 topic list | sort >/tmp/ros_topics_before_manual_bridge.txt 2>&1||true
gz topic -l | sort >/tmp/gz_topics.txt 2>&1||true
ros2 run ros_gz_bridge parameter_bridge "/model/$variant/camera@sensor_msgs/msg/Image[gz.msgs.Image" >/tmp/camera_bridge.log 2>&1 &
cam_bridge_pid=\$!
sleep 3
ros2 daemon stop >/dev/null 2>&1||true; ros2 daemon start >/dev/null 2>&1||true; sleep 3
ros2 topic list | sort >/tmp/ros_topics_after_manual_bridge.txt 2>&1||true
for spec in \
  "imu:/model/$variant/imu:45" \
  "magnetometer:/model/$variant/magnetometer:20" \
  "camera:/model/$variant/camera:90" \
  "odometry:/model/$variant/odometry:30"; do
  IFS=: read -r label topic seconds <<<"\$spec"
  timeout "\$seconds" ros2 topic echo "\$topic" --once --no-arr >"/tmp/\${label}.txt" 2>&1||true
done
if [[ '$variant' == bluerov2_heavy_multibeam_sonar ]]; then
 timeout 90 ros2 topic echo /model/$variant/multibeam_sonar/point_cloud --filter 'm.width > 1' --once --no-arr >/tmp/sonar_point.txt 2>&1||true
 timeout 150 ros2 topic echo /model/$variant/multibeam_sonar/sonar_image_raw --once --no-arr >/tmp/sonar_raw.txt 2>&1||true
fi
# Default sensor path is important for the fifth model's IMU contract mismatch.
default_imu=\$(grep -E "/world/.*/model/$variant/.*/sensor/imu_sensor/imu" /tmp/gz_topics.txt | head -1)
if [[ -n "\$default_imu" ]]; then timeout 20 gz topic -e -t "\$default_imu" -n 1 >/tmp/default_imu_gz.txt 2>&1||true; fi
kill -INT "\$cam_bridge_pid" 2>/dev/null||true
kill -INT "\$launch_pid" 2>/dev/null||true
for i in \$(seq 1 30); do kill -0 "\$launch_pid" 2>/dev/null||break; sleep 1; done
kill -TERM "\$launch_pid" 2>/dev/null||true
wait "\$launch_pid"; echo "\$?" >/tmp/launch_rc.txt
INNER
docker cp "$out/inner.sh" "$name:/tmp/inner.sh" >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh >"$out/inner_stdout.txt" 2>&1
for f in launch.log daemon.txt ros_topics_before_manual_bridge.txt ros_topics_after_manual_bridge.txt gz_topics.txt camera_bridge.log imu.txt magnetometer.txt camera.txt odometry.txt sonar_point.txt sonar_raw.txt default_imu_gz.txt launch_rc.txt; do docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1||true; done
printf 'variant=%s\nbackend=%s\nimage=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\n' "$variant" "$backend" "$image" "$domain" "$partition" >"$out/environment.txt"
python3 - "$out" "$variant" <<'PY'
from pathlib import Path
import json,re,sys
p=Path(sys.argv[1]); v=sys.argv[2]
def read(n):
 q=p/n
 return q.read_text(errors='replace') if q.exists() else ''
signatures={
 'imu': r'^orientation:',
 'magnetometer': r'^magnetic_field:',
 'camera': r'^height: [1-9][0-9]*\nwidth: [1-9][0-9]*$',
 'odometry': r'^child_frame_id:',
}
def received(label):
 return bool(re.search(signatures[label], read(label+'.txt'), re.M))
s={'variant':v,'ros_message_received':{x:received(x) for x in signatures},'default_path_gz_imu_received':bool(re.search(r'^entity_name:.*imu_sensor',read('default_imu_gz.txt'),re.M)),'sonar_point_513x301':bool(re.search(r'^height: 301\nwidth: 513$',read('sonar_point.txt'),re.M)),'sonar_raw_513x399':bool(re.search(r'^  beam_count: 513$',read('sonar_raw.txt'),re.M) and "length: 399" in read('sonar_raw.txt')),'runtime_segfault':bool(re.search(r'Stack trace|exit code 139|Segmentation fault',read('launch.log')))}
(p/'summary.json').write_text(json.dumps(s,indent=2)+'\n'); print(json.dumps(s,indent=2))
PY
