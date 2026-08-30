#!/usr/bin/env bash
set -eo pipefail

out="${1:?usage: $0 <output-dir>}"
root="/Users/gwon-yeseol/Documents/Codex/2026-07-15/dave-ros-2-lyrical-validation/work/heavy_sonar_wgpu_fix_2026-08-30"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

source /Users/gwon-yeseol/ros2_lyrical/.venv/bin/activate
source /Users/gwon-yeseol/ros2_lyrical/install/setup.bash
source /Users/gwon-yeseol/ros_gz_ws_lyrical/install/local_setup.bash
source /Users/gwon-yeseol/dave_ws_lyrical/install/local_setup.bash
source "$root/mac_overlay/install/local_setup.bash"

# The host was upgraded to FFmpeg 9 after gz-sim10 was bottled against FFmpeg
# 8 and x265 4.2.  Keep this validation isolated: load locally built/extracted
# ABI-compatible libraries without changing Homebrew or adding global symlinks.
export DYLD_LIBRARY_PATH="$root/mac_overlay/build/multibeam_sonar_system/multibeam_sonar:$root/ffmpeg8_compat/lib:$root/x265_4_2_bottle/x265/4.2/lib:$DYLD_LIBRARY_PATH"

export ROS_DOMAIN_ID=177
export GZ_PARTITION=sonar_deferred_mac_20260830
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export DAVE_SONAR_COMPUTE_BACKEND=wgpu
export ROS_LOG_DIR="$out/ros_logs"
mkdir -p "$ROS_LOG_DIR"

cleanup() {
  if [[ -n "${launch_pid:-}" ]] && kill -0 "$launch_pid" 2>/dev/null; then
    kill -INT "$launch_pid" 2>/dev/null || true
    sleep 4
    kill -TERM "$launch_pid" 2>/dev/null || true
  fi
  pkill -TERM -f "gz-sim-main.*dave_multibeam_sonar.world" 2>/dev/null || true
  pkill -TERM -f "parameter_bridge.*/sensor/multibeam_sonar/point_cloud" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

{
  echo "multibeam_prefix=$(ros2 pkg prefix multibeam_sonar)"
  echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
  echo "GZ_PARTITION=$GZ_PARTITION"
  uname -m
  system_profiler SPDisplaysDataType | grep -E 'Chipset Model|Metal Support' | head -4
} >"$out/environment.txt"

ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 \
  world_name:=dave_multibeam_sonar \
  paused:=false x:=5.8 z:=2 yaw:=3.14 \
  compute_backend:=wgpu gui:=true headless:=true \
  >"$out/launch.log" 2>&1 &
launch_pid=$!

backend_ready=0
for _ in $(seq 1 150); do
  if ! kill -0 "$launch_pid" 2>/dev/null; then
    break
  fi
  if grep -q 'Persistent GPU buffers allocated for 513' "$out/launch.log"; then
    backend_ready=1
    break
  fi
  sleep 1
done

# Query directly rather than through the long-lived ROS daemon.  This keeps
# discovery in the exact domain / RMW environment used by this validation.
ros2 topic list --no-daemon --spin-time 10 | sort >"$out/topic_list.txt" 2>&1 || true

point_ok=0
raw_ok=0
timeout 90 ros2 topic echo /sensor/multibeam_sonar/point_cloud \
  --no-daemon --spin-time 10 --filter 'm.width > 1' --once --no-arr \
  >"$out/point_cloud.txt" 2>&1 || true
grep -q '^width: 513' "$out/point_cloud.txt" && point_ok=1

timeout 120 ros2 topic echo /sensor/multibeam_sonar/sonar_image_raw \
  --no-daemon --spin-time 10 --once --no-arr >"$out/raw_sonar.txt" 2>&1 || true
grep -q '^  beam_count: 513' "$out/raw_sonar.txt" && raw_ok=1

grep -nE 'SONAR PLUGIN LOADED|Deferring sonar|Initializing deferred|CreateComputeBackend|selected adapter|GPU device acquired|Persistent GPU buffers allocated for 513|GPU #[0-9]+|Stack trace|Segmentation fault|process has died' \
  "$out/launch.log" >"$out/key_lines.txt" || true

python3 - "$out" "$backend_ready" "$point_ok" "$raw_ok" <<'PY'
import json, re, sys
from pathlib import Path
out = Path(sys.argv[1])
log = (out / "launch.log").read_text(errors="replace")
lines = log.splitlines()
def first_line(pattern):
    rx = re.compile(pattern)
    return next((i + 1 for i, line in enumerate(lines) if rx.search(line)), None)
summary = {
    "candidate": "defer compute-backend creation to the compute thread after the first GpuRays frame",
    "platform": "macOS Apple Silicon",
    "requested_backend": "wgpu",
    "selected_adapter_apple_m2": "selected adapter: Apple M2" in log,
    "backend_ready": bool(int(sys.argv[2])),
    "pointcloud_513x301": bool(int(sys.argv[3])),
    "raw_sonar_513x399": bool(int(sys.argv[4])),
    "plugin_loaded_line": first_line(r"SONAR PLUGIN LOADED"),
    "deferred_backend_create_line": first_line(r"CreateComputeBackend called with: wgpu"),
    "ogre2_segfault": bool(re.search(r"Stack trace|Segmentation fault|exit code 139", log)),
}
summary["backend_created_after_plugin_loaded"] = (
    summary["plugin_loaded_line"] is not None
    and summary["deferred_backend_create_line"] is not None
    and summary["deferred_backend_create_line"] > summary["plugin_loaded_line"]
)
(out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
PY

cleanup
trap - EXIT INT TERM
