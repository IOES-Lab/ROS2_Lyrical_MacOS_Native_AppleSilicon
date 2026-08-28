#!/usr/bin/env bash
set -o pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DISPLAY=:10
export XAUTHORITY=/home/docker/.Xauthority
ROOT=/home/docker/dvl_all_models
models=(
  nortek_dvl500_300
  nortek_dvl500_600
  nortek_dvl1000_300
  nortek_dvl1000_4000
  sonardyne_syrinx600
  teledyne_explorer1000
  teledyne_explorer4000
  teledyne_pathfinder
)
mkdir -p "$ROOT"
: > "$ROOT/verdicts.tsv"
printf 'model\tmessage_received\tbeam_markers\tframe_id_line\tserver_died\n' >> "$ROOT/verdicts.tsv"

cleanup() {
  if [[ -n "${LAUNCH_PID:-}" ]]; then
    kill -INT -- "-$LAUNCH_PID" 2>/dev/null || true
    sleep 4
    kill -TERM -- "-$LAUNCH_PID" 2>/dev/null || true
    sleep 2
    kill -KILL -- "-$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

for model in "${models[@]}"; do
  OUT="$ROOT/$model"
  mkdir -p "$OUT"
  echo "=== $model ==="
  LAUNCH_PID=
  setsid ros2 launch dave_demos dave_sensor.launch.py     namespace:="$model" world_name:=dvl_world paused:=false z:=-30     gui:=true headless:=true >"$OUT/launch.log" 2>&1 &
  LAUNCH_PID=$!
  got=0
  for i in $(seq 1 90); do
    if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then break; fi
    if timeout 2 ros2 topic info /dvl/velocity >"$OUT/topic_info.txt" 2>&1; then
      if grep -q 'Publisher count: [1-9]' "$OUT/topic_info.txt"; then
        if timeout 20 ros2 topic echo /dvl/velocity --once --no-arr >"$OUT/message.txt" 2>&1; then
          got=1
          break
        fi
      fi
    fi
    sleep 1
  done
  beams=$(grep -c '^-' "$OUT/message.txt" 2>/dev/null || true)
  frame=$(grep -m1 'frame_id:' "$OUT/message.txt" 2>/dev/null | sed 's/[[:space:]]\+/ /g' || true)
  died=0
  grep -q 'process has died' "$OUT/launch.log" && died=1
  printf '%s\t%s\t%s\t%s\t%s\n' "$model" "$got" "$beams" "$frame" "$died" >> "$ROOT/verdicts.tsv"
  cleanup
  LAUNCH_PID=
  ros2 daemon stop >/dev/null 2>&1 || true
  ros2 daemon start >/dev/null 2>&1 || true
  sleep 2
done

trap - EXIT
cat "$ROOT/verdicts.tsv"
