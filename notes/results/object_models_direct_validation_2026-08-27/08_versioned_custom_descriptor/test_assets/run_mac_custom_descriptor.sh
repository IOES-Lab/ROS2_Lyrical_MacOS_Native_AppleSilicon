#!/usr/bin/env bash
set -eo pipefail

ROOT=/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/object_models_direct_validation_2026-08-27/08_versioned_custom_descriptor
WS="$ROOT/overlay_ws"
OUT="$ROOT/mac_launch_retry"
CACHE="$ROOT/mac_fuel_cache_retry"

if pgrep -f "gz-sim-main|ros2 launch|parameter_bridge|rviz2" >/dev/null; then
  echo "Refusing to run: related process already active" >&2
  pgrep -fl "gz-sim-main|ros2 launch|parameter_bridge|rviz2" >&2
  exit 2
fi
mkdir -p "$OUT" "$CACHE"

set +u
source /Users/gwon-yeseol/ros2_lyrical/.venv/bin/activate
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash
source /Users/gwon-yeseol/dave_ws_lyrical/install/local_setup.bash
source "$WS/install/local_setup.bash"
set -u

export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export GZ_FUEL_CACHE_PATH="$CACHE"
export ROS_LOG_DIR="$OUT/ros_logs"
mkdir -p "$ROS_LOG_DIR"

ros2 launch dave_demos dave_object.launch.py \
  namespace:=codex_versioned_block paused:=false \
  gui:=true headless:=true \
  2>&1 | tee "$OUT/launch.log" &
LAUNCH_PIPE_PID=$!

cleanup() {
  if kill -0 "$LAUNCH_PIPE_PID" 2>/dev/null; then
    kill -INT "$LAUNCH_PIPE_PID" 2>/dev/null || true
    sleep 3
  fi
  pkill -TERM -f "gz-sim-main.*empty.sdf" 2>/dev/null || true
  pkill -TERM -f "ros2 launch dave_demos dave_object.launch.py.*codex_versioned_block" 2>/dev/null || true
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 180); do
  if ! kill -0 "$LAUNCH_PIPE_PID" 2>/dev/null; then
    echo "Launch pipeline exited before model appeared" >&2
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
pgrep -fl "gz-sim-main|ros2 launch.*codex_versioned_block" > "$OUT/processes.txt" || true

find "$CACHE" -type f -print | sed "s#^$CACHE/##" | sort > "$OUT/cache_file_list.txt"
find "$CACHE" -type f -print0 | sort -z | xargs -0 shasum -a 256 \
  | sed "s#$CACHE/##" > "$OUT/cache_sha256.txt"
MODEL_SDF=$(find "$CACHE" -path '*/mossy_cinder_block/*/model.sdf' -print -quit)
test -n "$MODEL_SDF"
gz sdf -k "$MODEL_SDF" > "$OUT/resolved_sdf_validation.txt" 2>&1

grep -q '^    - codex_versioned_block$' "$OUT/model_list.txt"
grep -q 'sim_time' "$OUT/stats_sample.txt"
grep -q '^Valid\.$' "$OUT/resolved_sdf_validation.txt"
grep -E 'Requested version|Entity creation successful|Object Model Uploaded' "$OUT/launch.log" \
  > "$OUT/launch_key_evidence.txt" || true

echo "MAC CUSTOM DESCRIPTOR LAUNCH PASS"
