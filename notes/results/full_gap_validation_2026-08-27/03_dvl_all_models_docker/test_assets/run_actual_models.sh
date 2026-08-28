#!/usr/bin/env bash
set -o pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DISPLAY=:10
export XAUTHORITY=/home/docker/.Xauthority
ROOT=/home/docker/dvl_actual_models_20260827_fresh
models=(
  nortek_dvl500_300
  nortek_dvl500_6000
  nortek_dvl1000_300
  nortek_dvl1000_4000
  sonardyne_syrinx600
  teledyne_explorer1000
  teledyne_explorer4000
  teledyne_whn
)

if [[ -e "$ROOT" ]]; then
  echo "Refusing to overwrite existing result directory: $ROOT" >&2
  exit 2
fi
mkdir -p "$ROOT"
printf 'model\tdescriptor_exists\tmessage_received\tbeam_length\tframe_id\tinitialization_error\tserver_died\n' > "$ROOT/verdicts.tsv"

cleanup_launch() {
  if [[ -n "${LAUNCH_PID:-}" ]]; then
    kill -INT -- "-$LAUNCH_PID" 2>/dev/null || true
    sleep 3
    kill -TERM -- "-$LAUNCH_PID" 2>/dev/null || true
    sleep 2
    kill -KILL -- "-$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
  fi
  LAUNCH_PID=
}
trap cleanup_launch EXIT

for model in "${models[@]}"; do
  OUT="$ROOT/$model"
  mkdir -p "$OUT"
  echo "=== $model ==="
  descriptor="/home/docker/dave_ws/install/share/dave_sensor_models/description/$model/model.sdf"
  descriptor_exists=0
  [[ -f "$descriptor" ]] && descriptor_exists=1
  cp "$descriptor" "$OUT/model.sdf" 2>/dev/null || true

  LAUNCH_PID=
  setsid ros2 launch dave_demos dave_sensor.launch.py \
    namespace:="$model" world_name:=dvl_world paused:=false z:=-30 \
    gui:=true headless:=true >"$OUT/launch.log" 2>&1 &
  LAUNCH_PID=$!

  got=0
  for i in $(seq 1 45); do
    if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then break; fi
    if grep -Eq 'Failed to initialize|Error finding file|Unable to read file' "$OUT/launch.log"; then break; fi
    if timeout -k 2 3 ros2 topic info /dvl/velocity >"$OUT/topic_info.txt" 2>&1 \
       && grep -q 'Publisher count: [1-9]' "$OUT/topic_info.txt"; then
      if timeout -k 3 15 ros2 topic echo /dvl/velocity --once --no-arr >"$OUT/message.txt" 2>&1; then
        got=1
      fi
      break
    fi
    sleep 1
  done

  beam_length=$(grep -o 'beams: .*length: [0-9]*' "$OUT/message.txt" 2>/dev/null | grep -o '[0-9]*' | tail -1 || true)
  frame_id=$(grep -m1 'frame_id:' "$OUT/message.txt" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]\+/ /g' || true)
  init_error=0
  grep -Eq 'Failed to initialize|Error finding file|Unable to read file' "$OUT/launch.log" && init_error=1
  died=0
  grep -q 'process has died' "$OUT/launch.log" && died=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$model" "$descriptor_exists" "$got" "$beam_length" "$frame_id" "$init_error" "$died" >> "$ROOT/verdicts.tsv"

  cleanup_launch
  ros2 daemon stop >/dev/null 2>&1 || true
  ros2 daemon start >/dev/null 2>&1 || true
  sleep 2
done

trap - EXIT
cat "$ROOT/verdicts.tsv"
