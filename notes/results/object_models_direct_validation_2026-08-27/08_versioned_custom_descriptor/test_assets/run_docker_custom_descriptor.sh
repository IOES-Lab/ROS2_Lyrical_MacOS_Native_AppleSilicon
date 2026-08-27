#!/usr/bin/env bash
set -eo pipefail

ROOT=/home/docker/object_models_custom_20260827
WS="$ROOT/overlay_ws"
OUT="$ROOT/docker_launch"
CACHE="$ROOT/docker_fuel_cache"
PROBE="$ROOT/version_probe_docker"

if [ -e "$ROOT/results_started" ]; then
  echo "Refusing to reuse an already-started result directory" >&2
  exit 2
fi
touch "$ROOT/results_started"
mkdir -p "$OUT" "$CACHE" "$PROBE/cache"

set +u
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
set -u
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

cd "$WS"
colcon build --packages-select dave_object_models \
  --cmake-args -DCMAKE_BUILD_TYPE=Release \
  > "$ROOT/docker_build.log" 2>&1

set +u
source "$WS/install/local_setup.bash"
set -u
printf 'OBJECT_PREFIX=%s\n' "$(ros2 pkg prefix dave_object_models)" \
  > "$ROOT/docker_active_prefix.txt"
test "$(ros2 pkg prefix dave_object_models)" = "$WS/install/dave_object_models"
test -f "$WS/install/dave_object_models/share/dave_object_models/description/codex_versioned_block/model.sdf"

GZ_FUEL_CACHE_PATH="$PROBE/cache" gz fuel download \
  -u 'https://fuel.gazebosim.org/1.0/hmoyen/models/mossy_cinder_block/1' \
  -v 4 > "$PROBE/download.log" 2>&1
find "$PROBE/cache" -type f -print | sed "s#^$PROBE/cache/##" | sort \
  > "$PROBE/cache_file_list.txt"
grep 'Requested version \[1\].*latest.*version is supported' "$PROBE/download.log" \
  > "$PROBE/version_warning.txt"

export GZ_FUEL_CACHE_PATH="$CACHE"
export ROS_LOG_DIR="$OUT/ros_logs"
mkdir -p "$ROS_LOG_DIR"

ros2 launch dave_demos dave_object.launch.py \
  namespace:=codex_versioned_block paused:=false \
  gui:=true headless:=true \
  > "$OUT/launch.log" 2>&1 &
LAUNCH_PID=$!

cleanup() {
  if kill -0 "$LAUNCH_PID" 2>/dev/null; then
    kill -INT "$LAUNCH_PID" 2>/dev/null || true
    sleep 5
  fi
  pkill -TERM -f "gz-sim-main.*empty.sdf" 2>/dev/null || true
  pkill -TERM -f "ros2 launch dave_demos dave_object.launch.py.*codex_versioned_block" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 180); do
  if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    echo "Launch exited before model appeared" >&2
    tail -200 "$OUT/launch.log" >&2
    exit 3
  fi
  if timeout 30 gz model --list > "$OUT/model_list_probe.txt" 2>/dev/null \
      && grep -q '^    - codex_versioned_block$' "$OUT/model_list_probe.txt"; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "Timed out waiting for codex_versioned_block" >&2
  exit 4
fi

mv "$OUT/model_list_probe.txt" "$OUT/model_list.txt"
gz topic -l | sort > "$OUT/gz_topic_list.txt"
STATS_TOPIC=$(grep '/stats$' "$OUT/gz_topic_list.txt" | head -1)
POSE_TOPIC=$(grep '/pose/info$' "$OUT/gz_topic_list.txt" | head -1)
printf 'stats_topic=%s\npose_topic=%s\n' "$STATS_TOPIC" "$POSE_TOPIC" > "$OUT/topic_selection.txt"
timeout 30 gz topic -e -t "$STATS_TOPIC" -n 2 > "$OUT/stats_sample.txt" 2>&1
timeout 30 gz topic -e -t "$POSE_TOPIC" -n 1 > "$OUT/pose_sample.txt" 2>&1
ps -eo pid,comm,args | grep -E '[g]z-sim-main|[r]os2 launch.*codex_versioned_block' \
  > "$OUT/processes.txt" || true

find "$CACHE" -type f -print | sed "s#^$CACHE/##" | sort > "$OUT/cache_file_list.txt"
find "$CACHE" -type f -print0 | sort -z | xargs -0 sha256sum \
  | sed "s#$CACHE/##" > "$OUT/cache_sha256.txt"
MODEL_SDF=$(find "$CACHE" -path '*/mossy_cinder_block/*/model.sdf' -print -quit)
test -n "$MODEL_SDF"
gz sdf -k "$MODEL_SDF" > "$OUT/resolved_sdf_validation.txt" 2>&1

grep -q '^    - codex_versioned_block$' "$OUT/model_list.txt"
grep -q 'sim_time' "$OUT/stats_sample.txt"
grep -q '^Valid\.$' "$OUT/resolved_sdf_validation.txt"
grep -E 'Requested version|Entity creation successful|Object Model Uploaded' "$OUT/launch.log" \
  > "$OUT/launch_key_evidence.txt" || true

echo "DOCKER CUSTOM DESCRIPTOR LAUNCH PASS"
