#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <mac|docker> <output-dir>" >&2
  exit 2
fi

platform=$1
output=$2
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$output"

case "$platform" in
  mac)
    plugin_dir=${SPHERICAL_COORDS_PLUGIN_DIR:-$HOME/dave_ws_lyrical/install/dave_ros_gz_plugins/lib}
    ;;
  docker)
    # The Docker workspace uses a merged install, so the plugin is directly
    # under install/lib rather than install/<package>/lib.
    plugin_dir=${SPHERICAL_COORDS_PLUGIN_DIR:-/home/docker/dave_ws/install/lib}
    ;;
  *)
    echo "unknown platform: $platform" >&2
    exit 2
    ;;
esac

export GZ_SIM_SYSTEM_PLUGIN_PATH="$plugin_dir:${GZ_SIM_SYSTEM_PLUGIN_PATH:-}"
export FASTDDS_BUILTIN_TRANSPORTS=UDPv4
export ROS_LOG_DIR="$output/ros_logs"
mkdir -p "$ROS_LOG_DIR"

cp "$script_dir/sc_validation.sdf" "$output/sc_validation.sdf"
gz sim -s -r "$output/sc_validation.sdf" >"$output/server.log" 2>&1 &
server_pid=$!
printf '%s\n' "$server_pid" >"$output/server.pid"

cleanup() {
  kill -INT "$server_pid" 2>/dev/null || true
  sleep 2
  kill -TERM "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

python3 "$script_dir/validate_services.py" "$output" "$platform" \
  >"$output/client.log" 2>&1
