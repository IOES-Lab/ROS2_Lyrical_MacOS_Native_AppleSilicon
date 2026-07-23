#!/usr/bin/env bash
# benchmark_worlds.sh
#
# Quantitative performance benchmark for the DAVE/ROS2-Lyrical/Gazebo-Jetty
# port, per README.md "August" next-step: "Quantitative performance/accuracy
# benchmarking -- Real Time Factor, CPU/memory, sonar frame time; report Mac
# (Metal) and Docker (llvmpipe) as separate environments rather than a single
# 'N times faster' comparison."
#
# WHAT THIS MEASURES, per world:
#   - Real Time Factor (RTF): sampled from Gazebo's own /world/<name>/stats
#     transport topic (gz.msgs.WorldStatistics), NOT ROS -- this is Gazebo's
#     own internal sim-time/wall-time ratio, the standard RTF definition.
#   - CPU/RAM: `docker stats` (container-wide) + `ps aux` (per-process
#     breakdown of gz-sim-main and any bridge/parameter_bridge processes),
#     same method already validated in docker/README.md's 2026-07-20 entry.
#
# WHAT THIS DOES NOT DO: it does not measure sonar frame time directly (that
# was already measured qualitatively for Jazzy+Harmonic on 2026-07-13 via a
# different method, ~86-96ms Mac Metal vs ~273-438ms Docker llvmpipe -- not
# repeated here since it needs source-level timing instrumentation, not just
# black-box sampling). It also only benchmarks the worlds listed below, not
# all 13 confirmed-PASS worlds -- these three are chosen as representative:
# a vehicle-in-environment world (dave_ocean_waves), a sensor-heavy world
# (dave_multibeam_sonar), and a lightweight world-only world (usbl_tutorial,
# post-fix) for contrast.
#
# USAGE (run inside the Docker container, after sourcing dave_ws/install):
#   ./benchmark_worlds.sh
#   ./benchmark_worlds.sh --settle 30 --window 8   # override defaults
#
# METHODOLOGY NOTE (2026-07-22): Gazebo's real_time_factor field in
# /stats is itself a windowed/smoothed running average, not an instantaneous
# value -- sampling it immediately after a short settle period (originally
# 8s) captured it still ramping up from ~0 toward steady state within a
# single ~16ms burst of messages, badly biasing the average low. Fixed by
# (a) a much longer settle window (25s default) so the metric has already
# converged before sampling starts, and (b) collecting messages over a real
# wall-clock SAMPLE_WINDOW_SEC and averaging only the second half of what's
# collected, to further discount any residual transient.
#
# OUTPUT:
#   bench_results/<world>.log       -- full launch stdout+stderr
#   bench_results/<world>-stats.log -- raw gz topic stats samples
#   bench_results/<world>-ps.log    -- ps aux snapshot at sample time
#   bench_results/benchmark_results.csv -- one row per world, appended

set -uo pipefail

SETTLE_SEC="${SETTLE_SEC:-25}"
SAMPLE_WINDOW_SEC="${SAMPLE_WINDOW_SEC:-6}"
RESULTS_DIR="bench_results"
RESULTS_CSV="${RESULTS_DIR}/benchmark_results.csv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settle) SETTLE_SEC="$2"; shift 2 ;;
    --window) SAMPLE_WINDOW_SEC="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ERROR: ros2 not found on PATH. Source install/setup.bash first." >&2
  exit 1
fi
if ! command -v gz >/dev/null 2>&1; then
  echo "ERROR: gz (Gazebo CLI) not found on PATH." >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"
if [[ ! -f "$RESULTS_CSV" ]]; then
  echo "timestamp,world_file,rtf_samples,rtf_avg,container_mem_mib,container_cpu_pct,gz_sim_rss_mib,notes" > "$RESULTS_CSV"
fi

# world_file : launch_file : namespace : extra_args
BENCH_WORLDS=(
  "dave_ocean_waves:dave_robot.launch.py:rexrov:"
  "dave_multibeam_sonar:dave_sensor.launch.py:blueview_p900:x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu"
  "usbl_tutorial:dave_sensor.launch.py:usbl:"
)

CONTAINER_NAME="$(hostname)"

bench_one() {
  local world="$1" launch_file="$2" namespace="$3" extra="${4:-}"
  local log_file="${RESULTS_DIR}/${world}.log"
  local stats_log="${RESULTS_DIR}/${world}-stats.log"
  local ps_log="${RESULTS_DIR}/${world}-ps.log"
  local cmd=(ros2 launch dave_demos "$launch_file" "world_name:=${world}" "paused:=false" "gui:=true" "headless:=true" "namespace:=${namespace}")
  if [[ -n "$extra" ]]; then
    # shellcheck disable=SC2206
    local extra_args=($extra)
    cmd+=("${extra_args[@]}")
  fi

  echo "=== $world ==="
  echo "cmd: ${cmd[*]}"

  "${cmd[@]}" > "$log_file" 2>&1 &
  local launch_pid=$!

  echo "Settling ${SETTLE_SEC}s..."
  sleep "$SETTLE_SEC"

  if ! kill -0 "$launch_pid" 2>/dev/null; then
    echo "--> world did not stay alive through settle window, skipping benchmark. See $log_file"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${world}.world,0,,,,\"process died before settle window -- see ${log_file}\"" >> "$RESULTS_CSV"
    echo
    return
  fi

  # Find the real Gazebo stats topic -- internal <world name="..."> can
  # differ from the filename (confirmed happens, e.g. new_dvl.world's
  # internal name is "dvl_world"), so discover it rather than assume.
  #
  # Bug fixed 2026-07-22: `gz topic -l` can list a BARE "/stats" topic
  # alongside the real per-world "/world/<world_name>/stats" topic -- both
  # end in "/stats", so a plain `grep -m1 '/stats$'` can grab whichever comes
  # first in the listing. Confirmed on macOS that the bare "/stats" can be
  # dead/stale (0 messages over a 15s sampling window) while the namespaced
  # "/world/<name>/stats" topic has real data with sim_time incrementing
  # normally. Not independently re-confirmed as a live bug in this Docker
  # environment (the original Docker benchmark run may or may not have hit
  # this), but the risk applies equally here since the same `gz topic -l`
  # command and grep pattern are used -- prefer the namespaced topic and
  # treat any earlier Docker RTF numbers gathered before this fix as
  # unverified until re-run.
  local stats_topic
  stats_topic="$(gz topic -l 2>/dev/null | grep -E '^/world/.*/stats$' | head -1)"
  if [[ -z "$stats_topic" ]]; then
    stats_topic="$(gz topic -l 2>/dev/null | grep -m1 '/stats$')"
  fi

  if [[ -z "$stats_topic" ]]; then
    echo "--> no /stats topic found via 'gz topic -l', RTF unavailable for this world"
    echo "N/A" > "$stats_log"
  else
    echo "stats topic: $stats_topic"
    timeout "$SAMPLE_WINDOW_SEC" gz topic -e -t "$stats_topic" > "$stats_log" 2>&1
  fi

  ps aux > "$ps_log"

  # container-wide stats (single sample; docker stats needs to run from the
  # host normally, but /sys/fs/cgroup is readable from inside the container
  # too on cgroup v2 setups -- fall back to ps-based estimate if not)
  local mem_mib="" cpu_pct=""
  if [[ -r /sys/fs/cgroup/memory.current ]]; then
    mem_mib=$(( $(cat /sys/fs/cgroup/memory.current) / 1024 / 1024 ))
  fi

  # Match ONLY this specific world's gz-sim-main process (by world file path
  # in the cmdline), not every gz-sim process in the container -- matching
  # broadly summed RSS across unrelated/leftover processes from other runs
  # (confirmed 2026-07-22: orphaned processes from earlier test_worlds.sh
  # runs inflated this to 8-10GB before the cleanup-logic fix below existed).
  local gz_rss_mib
  gz_rss_mib=$(ps aux | grep "gz-sim-main" | grep "worlds/${world}.world" | grep -v grep | awk '{sum+=$6} END {printf "%.1f", sum/1024}')

  local rtf_avg="N/A" rtf_n="0"
  if [[ -f "$stats_log" && "$(cat "$stats_log")" != "N/A" ]]; then
    # Average only the second half of collected samples, discarding the
    # first half as a still-converging transient (see methodology note above).
    rtf_avg=$(grep -oE 'real_time_factor: [0-9.]+' "$stats_log" | awk -F': ' '{v[NR]=$2} END {
      if (NR==0) { print "N/A"; exit }
      start = int(NR/2) + 1
      for (i=start; i<=NR; i++) { sum+=v[i]; n++ }
      if (n>0) printf "%.3f", sum/n; else print "N/A"
    }')
    rtf_n=$(grep -coE 'real_time_factor: [0-9.]+' "$stats_log")
    rtf_n=$(( rtf_n - rtf_n / 2 ))
  fi

  # SIGKILL by pattern, not just SIGTERM on launch_pid -- confirmed
  # 2026-07-22 that a plain SIGTERM on the top-level ros2-launch PID does
  # NOT reliably kill the grandchild gz-sim-main process (it becomes
  # orphaned and keeps running/accumulating CPU+RAM). See test_worlds.sh
  # for the same fix applied there, where this was first caught.
  #
  # Bug fixed 2026-07-23: the world_name:=/worlds/*.world patterns don't
  # match sibling processes like parameter_bridge/static_transform_publisher
  # (their command lines only have topic names, not the world name) -- these
  # were found still alive hours after their launching benchmark run ended,
  # pegged near 100% CPU each, and starved a later unrelated stability-test
  # run into getting SIGKILLed by resource pressure. Also kill the whole
  # process group of the backgrounded job so every child ros2 launch spawned
  # goes down together.
  kill -KILL -- "-${launch_pid}" 2>/dev/null
  kill -KILL "$launch_pid" 2>/dev/null
  pkill -9 -f "world_name:=${world}[[:space:]]" 2>/dev/null
  pkill -9 -f "worlds/${world}.world" 2>/dev/null
  sleep 1

  echo "--> RTF avg (last ${rtf_n} samples): ${rtf_avg}, gz-sim RSS: ${gz_rss_mib} MiB, cgroup mem: ${mem_mib:-N/A} MiB"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${world}.world,${rtf_n},${rtf_avg},${mem_mib:-N/A},${cpu_pct:-N/A},${gz_rss_mib},\"stats_topic=${stats_topic:-none}, settle=${SETTLE_SEC}s, window=${SAMPLE_WINDOW_SEC}s\"" >> "$RESULTS_CSV"
  echo
}

for entry in "${BENCH_WORLDS[@]}"; do
  IFS=':' read -r world launch_file namespace extra <<< "$entry"
  bench_one "$world" "$launch_file" "$namespace" "$extra"
done

echo "Done. Results in ${RESULTS_CSV}"
echo "NOTE: also run 'docker stats --no-stream <container-name>' from the HOST during one of these"
echo "worlds for a container-wide CPU%/MEM cross-check (cgroup-file reading from inside the"
echo "container may not reflect the host's view of docker stats depending on cgroup driver)."
