#!/usr/bin/env bash
set -u

if [ "$#" -lt 2 ]; then
  echo "usage: $0 OUT_DIR WORLD [extra ros2 launch args...]" >&2
  exit 2
fi

OUT=$1
WORLD=$2
shift 2
TOPIC_TIMEOUT=${TOPIC_TIMEOUT:-12}
TO=$(command -v gtimeout || command -v timeout || true)
if [ -z "$TO" ]; then
  echo "GNU timeout/gtimeout is required" >&2
  exit 4
fi
mkdir -p "$OUT/ros_logs"
export ROS_LOG_DIR="$OUT/ros_logs"

if pgrep -f 'gz-sim-main|ros2 launch.*dave_robot.launch.py|parameter_bridge.*glider_slocum' > "$OUT/preexisting_processes.txt"; then
  echo "Refusing to mix evidence with an existing simulation" >&2
  cat "$OUT/preexisting_processes.txt" >&2
  exit 3
fi

ros2 launch dave_demos dave_robot.launch.py \
  namespace:=glider_slocum world_name:="$WORLD" paused:=false \
  "$@" > "$OUT/launch.log" 2>&1 &
LAUNCH_PID=$!
echo "$LAUNCH_PID" > "$OUT/launch.pid"

cleanup() {
  kill -INT "$LAUNCH_PID" 2>/dev/null || true
  sleep 5
  kill -TERM "$LAUNCH_PID" 2>/dev/null || true
  pkill -TERM -f 'gz-sim-main.*empty.sdf' 2>/dev/null || true
  pkill -TERM -f 'gz-sim-main.*dave_ocean_waves.world' 2>/dev/null || true
  pkill -TERM -f 'parameter_bridge.*model/glider_slocum' 2>/dev/null || true
  sleep 2
  kill -KILL "$LAUNCH_PID" 2>/dev/null || true
  pkill -KILL -f 'gz-sim-main.*empty.sdf' 2>/dev/null || true
  pkill -KILL -f 'gz-sim-main.*dave_ocean_waves.world' 2>/dev/null || true
  pkill -KILL -f 'parameter_bridge.*model/glider_slocum' 2>/dev/null || true
}
trap cleanup EXIT

for _ in $(seq 1 90); do
  if grep -q 'Entity creation successful' "$OUT/launch.log" 2>/dev/null; then
    break
  fi
  if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

# The bridge is launched only after the model-creation process exits. On the
# Mac source build, creation of all nine endpoints can take more than 30 s, so
# entity creation alone is not a sufficient readiness condition.
for _ in $(seq 1 90); do
  if grep -q 'Creating ROS->GZ Bridge: \[/model/glider_slocum/imu' "$OUT/launch.log" 2>/dev/null; then
    break
  fi
  if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done
sleep 3
# The long-lived daemon was stale during the 2026-08-27 Mac retest. Use direct
# graph discovery so every observation is made in this run's ROS domain.
for _ in $(seq 1 60); do
  if "$TO" -k 2 8 ros2 topic list --no-daemon --spin-time 3 2>/dev/null | \
     grep -Fxq '/model/glider_slocum/imu'; then
    echo 'bridge_topics_discovered=yes' > "$OUT/readiness.txt"
    break
  fi
  sleep 1
done
if [ ! -f "$OUT/readiness.txt" ]; then
  echo 'bridge_topics_discovered=no' > "$OUT/readiness.txt"
fi

ps -eo pid,comm,args | grep -E '[g]z-sim-main|[p]arameter_bridge|[r]os2 launch.*dave_robot.launch.py' \
  > "$OUT/processes.txt" || true
"$TO" -k 2 12 ros2 node list --no-daemon --spin-time 5 | sort > "$OUT/node_list.txt" 2>&1 || true
"$TO" -k 2 12 ros2 topic list --no-daemon --spin-time 5 | sort > "$OUT/topic_list.txt" 2>&1 || true
gz topic -l | sort > "$OUT/gz_topic_list.txt" 2>&1 || true

topics=(
  battery/battery/state
  navsat
  odometry
  odometry_with_covariance
  pose
  imu
  joint/propeller_joint/cmd_thrust
  joint/propeller_joint/ang_vel
  joint/propeller_joint/enable_deadband
)

: > "$OUT/topic_probe_summary.csv"
echo 'suffix,listed,info_rc,message_rc,bytes' >> "$OUT/topic_probe_summary.csv"
for suffix in "${topics[@]}"; do
  topic="/model/glider_slocum/$suffix"
  safe=${suffix//\//__}
  if grep -Fxq "$topic" "$OUT/topic_list.txt"; then listed=yes; else listed=no; fi
  "$TO" -k 2 12 ros2 topic info -v --no-daemon --spin-time 5 "$topic" > "$OUT/${safe}_info.txt" 2>&1
  info_rc=$?
  if [ "$suffix" = 'joint/propeller_joint/cmd_thrust' ] || \
     [ "$suffix" = 'joint/propeller_joint/enable_deadband' ]; then
    : > "$OUT/${safe}_message.txt"
    message_rc=NA
  else
    "$TO" -k 3 "$TOPIC_TIMEOUT" ros2 topic echo "$topic" --once --no-arr > "$OUT/${safe}_message.txt" 2>&1
    message_rc=$?
  fi
  bytes=$(wc -c < "$OUT/${safe}_message.txt" | tr -d ' ')
  echo "$suffix,$listed,$info_rc,$message_rc,$bytes" >> "$OUT/topic_probe_summary.csv"
done

grep -E 'Entity creation successful|Robot Model Uploaded|Creating GZ->ROS Bridge|Creating ROS->GZ Bridge|process has died|ERROR|Error' \
  "$OUT/launch.log" > "$OUT/launch_evidence.txt" || true

cleanup
trap - EXIT
ps -eo pid,comm,args | grep -E '[g]z-sim-main|[p]arameter_bridge|[r]os2 launch.*dave_robot.launch.py' \
  > "$OUT/processes_after_cleanup.txt" || true
