#!/usr/bin/env bash
set -euo pipefail

ROOT=/home/docker/object_models_additional_20260827_retry
OUT="$ROOT/07_fuel_snippet_spawn_docker"
CACHE="$ROOT/fuel_cache"
WORLD="$ROOT/test_world.sdf"

if [ -e "$ROOT" ]; then
  echo "Refusing to overwrite existing $ROOT" >&2
  exit 2
fi

mkdir -p "$OUT" "$CACHE"
cp /tmp/object_models_test_world.sdf "$WORLD"

set +u
source /opt/ros/lyrical/setup.bash
if [ -f /home/docker/dave_ws/install/setup.bash ]; then
  source /home/docker/dave_ws/install/setup.bash
fi
set -u

export HOME=/home/docker
export GZ_FUEL_CACHE_PATH="$CACHE"
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4

{
  echo "user=$(id -un)"
  echo "uid=$(id -u)"
  echo "arch=$(uname -m)"
  echo "ROS_DISTRO=${ROS_DISTRO:-}"
  echo "GZ_FUEL_CACHE_PATH=$GZ_FUEL_CACHE_PATH"
  gz sim --versions
} > "$OUT/environment.txt" 2>&1

gz sim -s -r "$WORLD" > "$OUT/launch.log" 2>&1 &
SIM_PID=$!
echo "$SIM_PID" > "$OUT/sim_pid.txt"

cleanup() {
  if kill -0 "$SIM_PID" 2>/dev/null; then
    kill -INT "$SIM_PID" 2>/dev/null || true
    sleep 3
  fi
  if kill -0 "$SIM_PID" 2>/dev/null; then
    kill -TERM "$SIM_PID" 2>/dev/null || true
    sleep 2
  fi
}
trap cleanup EXIT

ready=0
for _ in $(seq 1 180); do
  if ! kill -0 "$SIM_PID" 2>/dev/null; then
    echo "Gazebo exited before becoming ready" >&2
    tail -200 "$OUT/launch.log" >&2
    exit 3
  fi
  if gz topic -l 2>/dev/null | grep -q '^/world/object_snippet/stats$'; then
    ready=1
    break
  fi
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "Timed out waiting for object_snippet stats" >&2
  exit 4
fi

gz topic -l | sort > "$OUT/gz_topic_list.txt"
timeout 30 gz model --list > "$OUT/model_list.txt" 2>&1
timeout 30 gz topic -e -t /world/object_snippet/pose/info -n 1 \
  > "$OUT/pose_sample.txt" 2>&1
timeout 30 gz topic -e -t /world/object_snippet/stats -n 2 \
  > "$OUT/stats_sample.txt" 2>&1

find "$CACHE" -type f -print | sed "s#^$CACHE/##" | sort \
  > "$OUT/cache_file_list.txt"
find "$CACHE" -type f -print0 | sort -z | xargs -0 sha256sum \
  | sed "s#$CACHE/##" > "$OUT/cache_sha256.txt"

MODEL_SDF=$(find "$CACHE" -path '*/teledyne_whn_uuvsim_bare_model/*/model.sdf' -print -quit)
if [ -z "$MODEL_SDF" ]; then
  echo "Resolved model.sdf not found" >&2
  exit 5
fi
cp "$MODEL_SDF" "$OUT/resolved_model.sdf"
gz sdf -k "$MODEL_SDF" > "$OUT/sdf_validation.txt" 2>&1

grep -c 'Sensor type LIDAR not supported yet' "$OUT/launch.log" \
  > "$OUT/lidar_warning_count.txt" || true
grep -E 'teledyne_whn_uuvsim|sim_time|iterations' \
  "$OUT/model_list.txt" "$OUT/pose_sample.txt" "$OUT/stats_sample.txt" \
  > "$OUT/key_evidence.txt" || true

grep -q '^teledyne_whn_uuvsim$' "$OUT/model_list.txt"
grep -q 'sim_time' "$OUT/stats_sample.txt"
grep -q '^Valid\.$' "$OUT/sdf_validation.txt"

echo "DOCKER GENERIC FUEL SPAWN PASS"
