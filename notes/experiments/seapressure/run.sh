#!/usr/bin/env bash
# SeaPressure full validation — ten discriminating conditions, one platform.
#
#   bash run.sh mac    /abs/path/to/05_parameter_matrix
#   bash run.sh docker /abs/path/to/06_docker_validation
#
# One server hosts ten uniquely-namespaced static probes. This avoids relying on
# process-name cleanup between conditions; that exact mistake invalidated the
# first 2026-08-26 attempt when old worlds remained alive.
set -uo pipefail

PLATFORM="${1:-}"
OUTDIR="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$PLATFORM" || -z "$OUTDIR" ]]; then
  echo "usage: run.sh <mac|docker> <output-dir>" >&2
  exit 2
fi
if [[ "$PLATFORM" != "mac" && "$PLATFORM" != "docker" ]]; then
  echo "platform must be mac or docker" >&2
  exit 2
fi
if ! command -v ros2 >/dev/null 2>&1 || ! command -v gz >/dev/null 2>&1; then
  echo "!! ros2/gz not on PATH — source the workspace first" >&2
  exit 2
fi

mkdir -p "$OUTDIR" "$OUTDIR/test_assets" || exit 2
TMP_BASE="${SEAPRESSURE_TMP_BASE:-${TMPDIR:-/tmp}}"
mkdir -p "$TMP_BASE" || exit 2
WS="$(mktemp -d "$TMP_BASE/sp_overlay.XXXXXX")"
ASSETS="$WS/assets"
mkdir -p "$ASSETS"
echo "assets: $ASSETS"
WORLD_NAME="sp_validation_${PLATFORM}_$(date +%s)"
echo "$WORLD_NAME" > "$OUTDIR/world_name.txt"

cat > "$ASSETS/sp_validation.world" <<WORLD
<?xml version="1.0"?>
<sdf version="1.7">
  <world name="${WORLD_NAME}">
    <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
    <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
    <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
  </world>
</sdf>
WORLD
cp "$ASSETS/sp_validation.world" "$OUTDIR/test_assets/"

{
  echo "platform=$PLATFORM"
  uname -a
  echo "ROS_DISTRO=${ROS_DISTRO:-}"
  echo "dave_gz_sensor_plugins=$(ros2 pkg prefix dave_gz_sensor_plugins 2>&1)"
  gz sim --versions 2>&1 || true
} > "$OUTDIR/environment.txt"
ros2 interface show sensor_msgs/msg/FluidPressure > "$OUTDIR/fluid_pressure_interface.txt" 2>&1
ros2 interface show geometry_msgs/msg/PointStamped > "$OUTDIR/point_stamped_interface.txt" 2>&1

# name|z|optional XML|capture arguments
# The baseline omits every optional tag, testing the compiled defaults.
CONDITIONS=(
'sp_baseline|0||--standard-pressure 101.325 --expect-depth-topic'
'sp_depth10|-10||--standard-pressure 101.325 --expect-depth-topic'
'sp_above10|10||--standard-pressure 101.325 --expect-depth-topic'
'sp_saturation|-10|<saturation>50</saturation>|--standard-pressure 101.325 --saturation 50 --expect-depth-topic'
'sp_stdpress|0|<standard_pressure>200.0</standard_pressure>|--standard-pressure 200.0 --expect-depth-topic'
'sp_kpa|-10|<kPa_per_meter>1.0</kPa_per_meter>|--standard-pressure 101.325 --kpa-per-meter 1.0 --expect-depth-topic'
'sp_noise|0|<noise_sigma>0.123</noise_sigma>|--standard-pressure 101.325 --noise-sigma 0.123 --expect-depth-topic'
'sp_topic|0|<topic>custom_sp</topic>|--topic custom_sp --standard-pressure 101.325 --expect-depth-topic'
'sp_nodepth|-10|<estimate_depth_on>false</estimate_depth_on>|--standard-pressure 101.325 --expect-no-depth-topic'
'sp_rate|0|<update_rate>2</update_rate>|--standard-pressure 101.325 --update-rate 2 --expect-depth-topic'
)

make_model () {
  local name="$1" z="$2" optional="$3"
  cat > "$ASSETS/${name}.sdf" <<SDF
<?xml version="1.0"?>
<sdf version="1.7">
  <model name="${name}">
    <static>true</static>
    <pose>0 0 ${z} 0 0 0</pose>
    <link name="base_link"/>
    <plugin filename="sea_pressure_sensor"
            name="dave_gz_sensor_plugins::SubseaPressureSensorPlugin">
      <namespace>${name}</namespace>
      ${optional}
    </plugin>
  </model>
</sdf>
SDF
}

for row in "${CONDITIONS[@]}"; do
  IFS='|' read -r NAME Z OPTIONAL CAPARGS <<< "$row"
  make_model "$NAME" "$Z" "$OPTIONAL"
  cp "$ASSETS/${NAME}.sdf" "$OUTDIR/test_assets/"
done

gz sim -s -r -v 4 "$ASSETS/sp_validation.world" > "$OUTDIR/server.log" 2>&1 &
SIM_PID=$!
echo "$SIM_PID" > "$OUTDIR/server.pid"

server_cleanup () {
  kill -INT "$SIM_PID" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8; do
    kill -0 "$SIM_PID" 2>/dev/null || { wait "$SIM_PID" 2>/dev/null || true; return; }
    sleep 1
  done
  kill -TERM "$SIM_PID" 2>/dev/null || true
  sleep 2
  kill -KILL "$SIM_PID" 2>/dev/null || true
  wait "$SIM_PID" 2>/dev/null || true
}
trap server_cleanup EXIT INT TERM

READY=0
for _ in $(seq 1 30); do
  if gz service -l 2>/dev/null | grep -qx "/world/${WORLD_NAME}/create"; then
    READY=1
    break
  fi
  sleep 1
done
if [[ "$READY" != 1 ]]; then
  echo "!! create service did not appear" | tee "$OUTDIR/server_not_ready.txt"
  exit 1
fi

for row in "${CONDITIONS[@]}"; do
  IFS='|' read -r NAME Z OPTIONAL CAPARGS <<< "$row"
  DEST="$OUTDIR/$NAME"
  mkdir -p "$DEST"
  echo "=== $NAME (z=$Z) ==="

  gz service -s "/world/${WORLD_NAME}/create" \
    --reqtype gz.msgs.EntityFactory --reptype gz.msgs.Boolean --timeout 10000 \
    --req "sdf_filename: \"$ASSETS/${NAME}.sdf\"" \
    > "$DEST/spawn.txt" 2>&1
  SPAWN_RC=$?
  echo "$SPAWN_RC" > "$DEST/spawn.exit_code"
  sleep 3

  ros2 topic list > "$DEST/topic_list.txt" 2>&1
  TOPIC="sea_pressure"
  [[ "$CAPARGS" == *"--topic custom_sp"* ]] && TOPIC="custom_sp"
  ros2 topic info "/model/${NAME}/${TOPIC}" -v > "$DEST/topic_info.txt" 2>&1

  gz topic -i -t "/model/${NAME}/${TOPIC}" > "$DEST/gz_topic_info.txt" 2>&1
  gz topic -e -t "/model/${NAME}/${TOPIC}" -n 1 > "$DEST/gz_sample.txt" 2>&1 &
  GZ_CAPTURE_PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$GZ_CAPTURE_PID" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$GZ_CAPTURE_PID" 2>/dev/null; then
    kill -TERM "$GZ_CAPTURE_PID" 2>/dev/null || true
    echo 124 > "$DEST/gz_capture.exit_code"
  else
    wait "$GZ_CAPTURE_PID" 2>/dev/null
    echo "$?" > "$DEST/gz_capture.exit_code"
  fi

  python3 "$HERE/capture_seapressure.py" \
    --condition "$NAME" --namespace "$NAME" --z "$Z" \
    $CAPARGS --out "$DEST/summary.json" \
    > "$DEST/capture.log" 2>&1
  CAPTURE_RC=$?
  echo "$CAPTURE_RC" > "$DEST/capture.exit_code"
  echo "  spawn=$SPAWN_RC capture=$CAPTURE_RC -> $DEST/summary.json"
done

server_cleanup
trap - EXIT INT TERM
echo "platform=$PLATFORM done. results under $OUTDIR"
echo "temporary assets were copied to $OUTDIR/test_assets"
