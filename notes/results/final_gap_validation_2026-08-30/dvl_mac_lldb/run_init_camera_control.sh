#!/bin/zsh

set -o pipefail

set +u
source /Users/gwon-yeseol/ros2_lyrical/.venv/bin/activate
source /Users/gwon-yeseol/ros2_lyrical/install/setup.zsh
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.zsh 2>/dev/null || true

root="$(cd "$(dirname "$0")" && pwd)"
world="$root/dvl_with_init_camera.sdf"
log="$root/init_camera_launch.log"

python3 - "$root" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
for name in (
    "init_camera_runtime_state.txt",
    "init_camera_dvl_message.txt",
    "init_camera_dvl_echo_exit_code.txt",
    "init_camera_gz_exit_code.txt",
    "init_camera_topics_latest.txt",
    "init_camera_process_before_shutdown.txt",
):
    path = root / name
    if path.exists():
        path.unlink()
PY

: > "$log"
(
  gtimeout --signal=TERM --kill-after=5 90 gz sim -s -r "$world" >"$log" 2>&1
  printf '%s\n' "$?" > "$root/init_camera_gz_exit_code.txt"
) &
wrapper=$!
echo "$wrapper" > "$root/init_camera_wrapper_pid.txt"

found=0
for i in $(seq 1 60); do
  if ! kill -0 "$wrapper" 2>/dev/null; then
    echo "process_exited_before_topic_poll=$i" > "$root/init_camera_runtime_state.txt"
    break
  fi

  topics=$(gtimeout 4 gz topic -l 2>/dev/null || true)
  printf '%s\n' "$topics" > "$root/init_camera_topics_latest.txt"
  if printf '%s\n' "$topics" | grep -q '^/dvl/velocity$'; then
    echo "dvl_topic_seen_at_poll=$i" > "$root/init_camera_runtime_state.txt"
    found=1
    break
  fi
  sleep 1
done

if [ "$found" -eq 1 ]; then
  gtimeout 20 gz topic -e -t /dvl/velocity -n 1 \
    > "$root/init_camera_dvl_message.txt" 2>&1
  echo "$?" > "$root/init_camera_dvl_echo_exit_code.txt"

  if kill -0 "$wrapper" 2>/dev/null; then
    echo 'alive_after_dvl_message=true' >> "$root/init_camera_runtime_state.txt"
  else
    echo 'alive_after_dvl_message=false' >> "$root/init_camera_runtime_state.txt"
  fi
fi

pgrep -fl 'gz-sim-main.*dvl_with_init_camera' \
  > "$root/init_camera_process_before_shutdown.txt" 2>&1 || true

# Deliberate cleanup only after evidence capture.
pkill -TERM -f 'gz-sim-main.*dvl_with_init_camera' 2>/dev/null || true
wait "$wrapper" 2>/dev/null || true
