#!/usr/bin/env bash
# stability_test.sh
#
# Long-duration stability test for the DAVE/ROS2-Lyrical/Gazebo-Jetty port,
# per README.md "August" next-step: "Long-running stability test."
#
# WHAT THIS DOES: launches one world and lets it run continuously for
# DURATION_HOURS, sampling memory/CPU every SAMPLE_INTERVAL_SEC and checking
# whether the process is still alive. Designed to run detached (nohup) so it
# survives the launching terminal/SSH session closing -- check back on
# stability_results/ later rather than waiting live.
#
# WHAT COUNTS AS A FAILURE: the gz-sim-main process dying before
# DURATION_HOURS elapses (crash), OR RSS growing monotonically/unboundedly
# across samples (memory leak signature) -- both are flagged, not just
# outright crashes. A single long run can't distinguish a slow leak from
# normal steady-state fluctuation with certainty, but a clearly monotonic
# multi-hour climb is a strong signal either way.
#
# USAGE (run inside the Docker container, after sourcing dave_ws/install;
# run detached so it survives the terminal closing):
#   nohup ./stability_test.sh > stability_test_nohup.log 2>&1 &
#   disown
#   # ... check back later ...
#   tail -f stability_results/dave_ocean_waves-stability.csv
#
#   Override world/duration:
#   WORLD=dave_multibeam_sonar DURATION_HOURS=2 nohup ./stability_test.sh ... &
#
# OUTPUT:
#   stability_results/<world>-stability.csv  -- timestamp,elapsed_min,alive,rss_mib,cpu_pct
#   stability_results/<world>-launch.log     -- full launch stdout+stderr
#   stability_results/<world>-summary.txt    -- written at the end (or on crash)

set -uo pipefail

WORLD="${WORLD:-dave_ocean_waves}"
LAUNCH_FILE="${LAUNCH_FILE:-dave_robot.launch.py}"
NAMESPACE="${NAMESPACE:-rexrov}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
DURATION_HOURS="${DURATION_HOURS:-4}"
SAMPLE_INTERVAL_SEC="${SAMPLE_INTERVAL_SEC:-120}"

RESULTS_DIR="stability_results"
CSV="${RESULTS_DIR}/${WORLD}-stability.csv"
LAUNCH_LOG="${RESULTS_DIR}/${WORLD}-launch.log"
SUMMARY="${RESULTS_DIR}/${WORLD}-summary.txt"

mkdir -p "$RESULTS_DIR"
echo "timestamp,elapsed_min,alive,rss_mib,cpu_pct" > "$CSV"

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ERROR: ros2 not found on PATH. Source install/setup.bash first." >&2
  exit 1
fi

cmd=(ros2 launch dave_demos "$LAUNCH_FILE" "world_name:=${WORLD}" "paused:=false" "gui:=true" "headless:=true" "namespace:=${NAMESPACE}")
if [[ -n "$EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_arr=($EXTRA_ARGS)
  cmd+=("${extra_arr[@]}")
fi

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) starting stability test: ${cmd[*]}"
echo "Duration: ${DURATION_HOURS}h, sample every ${SAMPLE_INTERVAL_SEC}s"

"${cmd[@]}" > "$LAUNCH_LOG" 2>&1 &
launch_pid=$!

start_epoch=$(date +%s)
end_epoch=$(( start_epoch + DURATION_HOURS * 3600 ))
crashed=0
max_rss=0
first_rss=""

while [[ $(date +%s) -lt $end_epoch ]]; do
  sleep "$SAMPLE_INTERVAL_SEC"
  now=$(date +%s)
  elapsed_min=$(( (now - start_epoch) / 60 ))
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  rss_mib="0"
  cpu_pct="0"
  alive="0"
  # Sum RSS/CPU across this specific world's gz-sim-main process only.
  sample=$(ps aux | grep "gz-sim-main" | grep "worlds/${WORLD}.world" | grep -v grep)
  if [[ -n "$sample" ]]; then
    alive="1"
    rss_kib=$(echo "$sample" | awk '{sum+=$6} END {print sum+0}')
    rss_mib=$(( rss_kib / 1024 ))
    cpu_pct=$(echo "$sample" | awk '{sum+=$3} END {print sum+0}')
    [[ -z "$first_rss" ]] && first_rss="$rss_mib"
    (( rss_mib > max_rss )) && max_rss="$rss_mib"
  fi

  echo "${ts},${elapsed_min},${alive},${rss_mib},${cpu_pct}" >> "$CSV"
  echo "[$ts] elapsed=${elapsed_min}min alive=${alive} rss=${rss_mib}MiB cpu=${cpu_pct}%"

  if [[ "$alive" == "0" ]]; then
    crashed=1
    echo "!!! Process died at elapsed=${elapsed_min}min -- stopping early"
    break
  fi
done

# cleanup regardless of outcome
# Bug fixed 2026-07-23: world_name:=/worlds/*.world patterns don't match
# parameter_bridge/static_transform_publisher siblings (their command lines
# only have topic names) -- also kill the whole process group so nothing
# from this run's `ros2 launch` tree survives.
kill -KILL -- "-${launch_pid}" 2>/dev/null
kill -KILL "$launch_pid" 2>/dev/null
pkill -9 -f "world_name:=${WORLD}[[:space:]]" 2>/dev/null
pkill -9 -f "worlds/${WORLD}.world" 2>/dev/null

{
  echo "Stability test summary"
  echo "World: ${WORLD}"
  echo "Planned duration: ${DURATION_HOURS}h"
  echo "Outcome: $([[ $crashed == 1 ]] && echo "CRASHED before planned duration" || echo "SURVIVED full planned duration")"
  echo "Started RSS: ${first_rss:-N/A} MiB"
  echo "Max RSS observed: ${max_rss} MiB"
  echo "Full sample log: ${CSV}"
  echo "Launch log: ${LAUNCH_LOG}"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee "$SUMMARY"
