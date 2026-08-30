#!/usr/bin/env bash
set -euo pipefail

out="${1:?usage: $0 <output-dir>}"
repo="/Users/gwon-yeseol/ROS2_Lyrical_review_fixes"
patch="$repo/patches/fifth_rov_sonar_world_fix.diff"
image="${DAVE_SONAR_TEST_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
name="sonar-combined-fixed-$$"
domain=$((140 + ($$ % 30)))
partition="sonar_combined_fixed_$$"
limit=420

mkdir -p "$out"
out="$(cd "$out" && pwd)"

cleanup() {
  docker stop "$name" >/dev/null 2>&1 || true
  docker rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$image" infinity \
  >"$out/container_id.txt"
docker cp "$patch" "$name":/tmp/world.patch >/dev/null

docker exec "$name" bash -lc '
set -eo pipefail
cd /home/docker/dave_ws/src/dave
git apply --check /tmp/world.patch
git apply /tmp/world.patch
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
cd /home/docker/dave_ws
colcon build --merge-install --packages-select dave_worlds --cmake-args -DCMAKE_BUILD_TYPE=Release
' >"$out/world_build.log" 2>&1

cat >"$out/inner.sh" <<INNER
#!/usr/bin/env bash
set +e
source /opt/ros/lyrical/setup.bash
source /home/docker/mavros_ws/install/setup.bash
source /home/docker/dave_ws/install/setup.bash
export ROS_DOMAIN_ID=$domain
export GZ_PARTITION=$partition
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=auto
export XDG_RUNTIME_DIR=/tmp/runtime-root
mkdir -p "\$XDG_RUNTIME_DIR"
chmod 700 "\$XDG_RUNTIME_DIR"

timeout --signal=INT --kill-after=30s ${limit}s \
  ros2 launch dave_demos dave_robot.launch.py \
    namespace:=bluerov2_heavy_multibeam_sonar \
    world_name:=dave_ocean_waves paused:=false \
    gui:=true headless:=true use_teleop:=false use_web_joystick:=false \
    open_qgc:=false open_virtual_joystick:=false \
    > /tmp/launch.log 2>&1 &
launch_pid=\$!

backend_ready=0
for i in \$(seq 1 220); do
  if ! kill -0 "\$launch_pid" 2>/dev/null; then break; fi
  if grep -q 'Persistent GPU buffers allocated for 513' /tmp/launch.log 2>/dev/null; then
    backend_ready=1
    break
  fi
  sleep 1
done

ros2 daemon stop >/tmp/daemon_restart.txt 2>&1 || true
ros2 daemon start >>/tmp/daemon_restart.txt 2>&1 || true
sleep 6
ros2 topic list | sort >/tmp/topic_list.txt 2>&1 || true
ros2 service list | sort >/tmp/service_list.txt 2>&1 || true

point_ok=0
raw_ok=0
timeout 60 ros2 topic echo \
  /model/bluerov2_heavy_multibeam_sonar/multibeam_sonar/point_cloud \
  --filter 'm.width > 1' --once --no-arr >/tmp/point_cloud.txt 2>&1
grep -q '^width: 513' /tmp/point_cloud.txt && point_ok=1

timeout 120 ros2 topic echo \
  /model/bluerov2_heavy_multibeam_sonar/multibeam_sonar/sonar_image_raw \
  --once --no-arr >/tmp/raw_sonar.txt 2>&1
grep -q '^  beam_count: 513' /tmp/raw_sonar.txt && raw_ok=1

connected=0
for i in \$(seq 1 30); do
  timeout 10 ros2 topic echo /mavros/state --once --no-arr >/tmp/state_poll.txt 2>&1
  if grep -q '^connected: true' /tmp/state_poll.txt; then connected=1; break; fi
  sleep 2
done
cp /tmp/state_poll.txt /tmp/state_before.txt 2>/dev/null || true

ros2 service call /mavros/set_mode mavros_msgs/srv/SetMode \
  "{base_mode: 0, custom_mode: 'MANUAL'}" >/tmp/set_mode.txt 2>&1
sleep 2
ros2 service call /mavros/cmd/arming mavros_msgs/srv/CommandBool \
  "{value: true}" >/tmp/arm_normal.txt 2>&1
armed=0
: >/tmp/arm_state_history.txt
for i in \$(seq 1 20); do
  timeout 10 ros2 topic echo /mavros/state --once --no-arr >/tmp/state_after_normal_arm.txt 2>&1
  cat /tmp/state_after_normal_arm.txt >>/tmp/arm_state_history.txt
  if grep -q '^connected: true' /tmp/state_after_normal_arm.txt && grep -q '^armed: true' /tmp/state_after_normal_arm.txt; then
    armed=1
    cp /tmp/state_after_normal_arm.txt /tmp/state_armed.txt
    break
  fi
  sleep 1
done

if [ "\$armed" -ne 1 ]; then
  ros2 service call /mavros/cmd/command mavros_msgs/srv/CommandLong \
    "{broadcast: false, command: 400, confirmation: 0, param1: 1.0, param2: 21196.0, param3: 0.0, param4: 0.0, param5: 0.0, param6: 0.0, param7: 0.0}" \
    >/tmp/arm_force.txt 2>&1
  for i in \$(seq 1 20); do
    timeout 10 ros2 topic echo /mavros/state --once --no-arr >/tmp/state_force_arm.txt 2>&1
    cat /tmp/state_force_arm.txt >>/tmp/arm_state_history.txt
    if grep -q '^connected: true' /tmp/state_force_arm.txt && grep -q '^armed: true' /tmp/state_force_arm.txt; then
      armed=1
      cp /tmp/state_force_arm.txt /tmp/state_armed.txt
      break
    fi
    sleep 1
  done
fi

timeout 30 ros2 topic echo \
  /model/bluerov2_heavy_multibeam_sonar/odometry --once --no-arr \
  >/tmp/odometry_before.txt 2>&1

ros2 topic pub --rate 20 --times 100 /mavros/manual_control/send \
  mavros_msgs/msg/ManualControl \
  "{x: 300.0, y: 0.0, z: 500.0, r: 0.0}" \
  >/tmp/manual_control.txt 2>&1
sleep 2

timeout 30 ros2 topic echo \
  /model/bluerov2_heavy_multibeam_sonar/odometry --once --no-arr \
  >/tmp/odometry_after.txt 2>&1

ros2 service call /mavros/cmd/arming mavros_msgs/srv/CommandBool \
  "{value: false}" >/tmp/disarm.txt 2>&1
disarmed=0
: >/tmp/disarm_state_history.txt
for i in \$(seq 1 20); do
  timeout 10 ros2 topic echo /mavros/state --once --no-arr >/tmp/state_disarmed.txt 2>&1
  cat /tmp/state_disarmed.txt >>/tmp/disarm_state_history.txt
  if grep -q '^connected: true' /tmp/state_disarmed.txt && grep -q '^armed: false' /tmp/state_disarmed.txt; then
    disarmed=1
    break
  fi
  sleep 1
done

if kill -0 "\$launch_pid" 2>/dev/null; then kill -INT "\$launch_pid" 2>/dev/null || true; fi
wait "\$launch_pid"
launch_rc=\$?

printf '%s\n' "\$backend_ready" >/tmp/backend_ready.txt
printf '%s\n' "\$point_ok" >/tmp/point_ok.txt
printf '%s\n' "\$raw_ok" >/tmp/raw_ok.txt
printf '%s\n' "\$connected" >/tmp/connected.txt
printf '%s\n' "\$armed" >/tmp/armed.txt
printf '%s\n' "\$disarmed" >/tmp/disarmed.txt
printf '%s\n' "\$launch_rc" >/tmp/launch_rc.txt
exit 0
INNER

docker cp "$out/inner.sh" "$name":/tmp/inner.sh >/dev/null
docker exec "$name" chmod +x /tmp/inner.sh
docker exec "$name" /tmp/inner.sh

for f in launch.log daemon_restart.txt topic_list.txt service_list.txt point_cloud.txt raw_sonar.txt \
  state_before.txt set_mode.txt arm_normal.txt arm_force.txt state_after_normal_arm.txt \
  state_armed.txt arm_state_history.txt odometry_before.txt manual_control.txt odometry_after.txt disarm.txt \
  state_disarmed.txt disarm_state_history.txt backend_ready.txt point_ok.txt raw_ok.txt connected.txt armed.txt \
  disarmed.txt launch_rc.txt; do
  docker cp "$name:/tmp/$f" "$out/$f" >/dev/null 2>&1 || true
done

grep -E 'CreateComputeBackend|selected adapter|GPU #[0-9]+|Persistent GPU buffers allocated for 513|SONAR PLUGIN LOADED|# of Beams|# of Rays|Stack trace|Segmentation fault|process has died|exit code' \
  "$out/launch.log" >"$out/key_lines.txt" || true

python3 - "$out" <<'PY'
import json, re, sys
from pathlib import Path
out=Path(sys.argv[1])
def flag(name):
    try: return int((out/f'{name}.txt').read_text().strip())
    except Exception: return 0
def x_from(name):
    s=(out/name).read_text(errors='replace')
    m=re.search(r'position:\s*\n\s*x:\s*([-+0-9.eE]+)',s)
    return float(m.group(1)) if m else None
before=x_from('odometry_before.txt')
after=x_from('odometry_after.txt')
summary={
  'candidate':'defer compute-backend creation until after first GpuRays frame',
  'backend_ready':bool(flag('backend_ready')),
  'pointcloud_513x301':bool(flag('point_ok')),
  'raw_sonar_513x399':bool(flag('raw_ok')),
  'mavros_connected':bool(flag('connected')),
  'armed':bool(flag('armed')),
  'manual_control_messages':(out/'manual_control.txt').read_text(errors='replace').count('publishing #'),
  'odometry_x_before_m':before,
  'odometry_x_after_m':after,
  'odometry_x_delta_m':None if before is None or after is None else after-before,
  'disarmed':bool(flag('disarmed')),
  'ogre2_segfault':bool(re.search(r'Stack trace|Segmentation fault|exit code 139',(out/'launch.log').read_text(errors='replace'))),
}
(out/'functional_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
PY

docker image inspect "$image" --format '{{.Id}}' >"$out/image_id.txt"
printf 'image=%s\nROS_DOMAIN_ID=%s\nGZ_PARTITION=%s\n' \
  "$image" "$domain" "$partition" >"$out/environment.txt"
