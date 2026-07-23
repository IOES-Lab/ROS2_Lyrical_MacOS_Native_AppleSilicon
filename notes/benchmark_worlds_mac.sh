#!/usr/bin/env bash
# benchmark_worlds_mac.sh
#
# macOS-native counterpart to notes/benchmark_worlds.sh, for the same
# README.md "August" next-step: "report Mac (Metal) and Docker (llvmpipe) as
# separate environments rather than a single 'N times faster' comparison."
# Same methodology as the Docker script (same settle/window logic, same RTF
# averaging over the second half of samples) so the two are comparable --
# see benchmark_worlds.sh's header comment for why that methodology matters
# (Gazebo's real_time_factor field needs time to converge after launch).
#
# DIFFERENCES FROM THE DOCKER VERSION (adapted for macOS, not just copied):
#   - No /sys/fs/cgroup (Linux-only) -- macOS memory/CPU comes from `ps`
#     alone here; if you want a whole-process-tree view, Activity Monitor
#     or `top -pid <pid>` alongside this script fills that gap.
#   - Does not assume the Docker/apt install paths -- discovers the actual
#     installed world-file directory via `ros2 pkg prefix dave_worlds`,
#     since the native colcon build's install layout (this workspace uses
#     --symlink-install, not --merge-install) differs from the Docker image.
#   - Process match pattern is `gz-sim` (not the more specific
#     `gz-sim-main`) OR'd with the world file path, since Homebrew's Gazebo
#     binary naming wasn't independently confirmed identical to the Docker
#     image's ROS-vendored build -- broaden the match rather than assume.
#
# USAGE (run from the DAVE workspace root on macOS, after sourcing
# install/setup.zsh or install/setup.bash -- use bash to run this script
# regardless of which you source, since #!/usr/bin/env bash is the shebang):
#   ./benchmark_worlds_mac.sh
#   ./benchmark_worlds_mac.sh --settle 30 --window 8
#
# OUTPUT: bench_results_mac/<world>.log, <world>-stats.log, <world>-ps.log,
#         bench_results_mac/benchmark_results_mac.csv

set -uo pipefail

SETTLE_SEC="${SETTLE_SEC:-25}"
SAMPLE_WINDOW_SEC="${SAMPLE_WINDOW_SEC:-10}"
# Grace period after a topic first appears in `gz topic -l` before actually
# subscribing to it. Bug found 2026-07-22 (4th mac benchmark run): topic
# discovery succeeded immediately ("~0s beyond settle") for all 3 worlds, yet
# `gz topic -e` still captured 0 samples in every case, even though the exact
# same command worked fine manually earlier (but only after the topic had
# already existed for a while by the time it was tried by hand). Hypothesis:
# a topic being LISTED (one discovery beacon) is not the same as a subscriber
# finishing its pub/sub handshake with the publisher -- on macOS's measurably
# slower transport discovery, that handshake can still be in progress right
# when the topic first becomes listable, so an immediate short sample window
# can end before the first message ever arrives. This sleep gives the
# handshake real time to finish before the timed sampling window starts.
TOPIC_GRACE_SEC="${TOPIC_GRACE_SEC:-5}"
RESULTS_DIR="bench_results_mac"
RESULTS_CSV="${RESULTS_DIR}/benchmark_results_mac.csv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settle) SETTLE_SEC="$2"; shift 2 ;;
    --window) SAMPLE_WINDOW_SEC="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ERROR: ros2 not found on PATH. Source install/setup.zsh (or .bash) first." >&2
  exit 1
fi
if ! command -v gz >/dev/null 2>&1; then
  echo "ERROR: gz (Gazebo CLI) not found on PATH." >&2
  exit 1
fi

# Resolve which timeout command to use ONCE, up front -- do not chain via
# `cmd1 || cmd2` at call time. Bug fixed 2026-07-22: timeout/gtimeout's exit
# code when it successfully kills a still-running child at the deadline is
# 124, which is the EXPECTED/SUCCESSFUL outcome here (it means RTF sampling
# ran for the full window), not a failure -- chaining with `||` treated that
# nonzero-but-successful exit as "this command doesn't work, try the next
# one," so neither `timeout` nor `gtimeout` was ever actually used even when
# both were present and working, and every world silently got 0 RTF samples.
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
else
  echo "WARNING: neither 'timeout' nor 'gtimeout' found on PATH -- RTF sampling will be skipped for every world." >&2
  echo "Install with: brew install coreutils (provides gtimeout)" >&2
fi

WORLDS_DIR="$(ros2 pkg prefix dave_worlds 2>/dev/null)/share/dave_worlds/worlds"
if [[ ! -d "$WORLDS_DIR" ]]; then
  echo "ERROR: could not find dave_worlds install directory via 'ros2 pkg prefix dave_worlds'." >&2
  echo "(Looked for: $WORLDS_DIR) Make sure install/setup.zsh or .bash is sourced." >&2
  exit 1
fi
echo "Using worlds directory: $WORLDS_DIR"

mkdir -p "$RESULTS_DIR"
if [[ ! -f "$RESULTS_CSV" ]]; then
  echo "timestamp,world_file,rtf_samples,rtf_avg,gz_sim_rss_mib,notes" > "$RESULTS_CSV"
fi

# --- Process-group cleanup infrastructure (fixed 2026-07-23) ---
# Same bug/fix as benchmark_worlds.sh (Docker) and test_worlds.sh: a
# background job's PID is not automatically a process-group leader without
# job control enabled, so `kill -KILL -- "-$pid"` was silently targeting a
# nonexistent group (confirmed via a minimal Bash repro on this Mac: "group
# -<pid> DOES NOT exist"). `setsid` (the fix used on the Linux/Docker
# scripts) isn't a standard macOS command, so this script instead enables
# bash's own job-control monitor mode (`set -m`) around the launch, which
# makes bash itself put the background job in its own new process group.
# This script is meant to be run interactively from a Terminal (not
# detached via nohup like stability_test.sh), so a controlling terminal is
# expected to be present. Also fixed: the early "process died before
# settle" return path used to skip cleanup entirely.
CURRENT_PID=""
CURRENT_WORLD=""
cleanup_current() {
  if [[ -n "$CURRENT_PID" ]]; then
    kill -KILL -- "-${CURRENT_PID}" 2>/dev/null
    kill -KILL "${CURRENT_PID}" 2>/dev/null
  fi
  if [[ -n "$CURRENT_WORLD" ]]; then
    pkill -9 -f "world_name:=${CURRENT_WORLD}[[:space:]]" 2>/dev/null
    pkill -9 -f "worlds/${CURRENT_WORLD}.world" 2>/dev/null
  fi
}
# Bug fixed 2026-07-23 (caught in review): a single `trap cleanup_current EXIT
# INT TERM HUP` runs cleanup_current on a signal but does NOT terminate the
# script -- confirmed via a minimal repro that the script kept running past
# a SIGTERM and exited 0. The EXIT trap alone (fires on every exit path,
# including one triggered by `exit N` from a signal handler) guarantees
# cleanup runs exactly once; the signal-specific traps below just need to
# actually terminate the script with the conventional 128+signum exit code.
trap cleanup_current EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# world_file : launch_file : namespace : extra_args -- same 3 representative
# worlds as the Docker script, for a direct comparison.
BENCH_WORLDS=(
  "dave_ocean_waves:dave_robot.launch.py:rexrov:"
  "dave_multibeam_sonar:dave_sensor.launch.py:blueview_p900:x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu"
  "usbl_tutorial:dave_sensor.launch.py:usbl:"
)

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

  set -m
  "${cmd[@]}" > "$log_file" 2>&1 &
  local launch_pid=$!
  set +m
  CURRENT_PID="$launch_pid"
  CURRENT_WORLD="$world"

  echo "Settling ${SETTLE_SEC}s..."
  sleep "$SETTLE_SEC"

  if ! kill -0 "$launch_pid" 2>/dev/null; then
    echo "--> world did not stay alive through settle window, skipping benchmark. See $log_file"
    cleanup_current
    CURRENT_PID=""
    CURRENT_WORLD=""
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${world}.world,0,,,\"process died before settle window -- see ${log_file}\"" >> "$RESULTS_CSV"
    echo
    return
  fi

  # Bug fixed 2026-07-22: a single check right after SETTLE_SEC isn't
  # reliable on macOS -- confirmed via manual test that gz transport topic
  # discovery/service registration here can take 25-30+ real seconds (the
  # ros_gz_sim create node was still retrying "[/world/default/create]" at
  # that point), noticeably slower than the Docker/Linux environment. Retry
  # discovery for up to 60s instead of trusting one fixed sleep.
  # Bug fixed 2026-07-22 (5th mac benchmark run): `gz topic -l` on this
  # machine lists a BARE "/stats" topic alongside the real per-world
  # "/world/<world_name>/stats" topic -- both end in "/stats", so the
  # previous plain `grep -m1 '/stats$'` grabbed whichever came first in the
  # listing, which was the bare one. Manually confirmed the bare "/stats" is
  # dead/stale (0 messages over a 15s window) while "/world/oceans_waves/
  # stats" (the real per-world topic, for dave_ocean_waves) had 224 messages
  # with sim_time incrementing normally over the same window. Prefer the
  # namespaced /world/.../stats topic; only fall back to a bare /stats match
  # if no namespaced one is found (e.g. if some other world's naming scheme
  # doesn't produce one).
  local stats_topic="" discovery_waited=0
  while [[ -z "$stats_topic" && $discovery_waited -lt 60 ]]; do
    stats_topic="$(gz topic -l 2>/dev/null | grep -E '^/world/.*/stats$' | head -1)"
    if [[ -z "$stats_topic" ]]; then
      stats_topic="$(gz topic -l 2>/dev/null | grep -m1 '/stats$')"
    fi
    if [[ -z "$stats_topic" ]]; then
      sleep 3
      discovery_waited=$(( discovery_waited + 3 ))
    fi
  done
  [[ -n "$stats_topic" ]] && echo "(topic discovery took ~${discovery_waited}s beyond the ${SETTLE_SEC}s settle)"

  if [[ -n "$stats_topic" ]]; then
    echo "Waiting ${TOPIC_GRACE_SEC}s grace period for subscriber handshake to finish..."
    sleep "$TOPIC_GRACE_SEC"
  fi

  if [[ -z "$stats_topic" ]]; then
    echo "--> no /stats topic found via 'gz topic -l', RTF unavailable for this world"
    echo "N/A" > "$stats_log"
  elif [[ -z "$TIMEOUT_CMD" ]]; then
    echo "--> no timeout/gtimeout available, skipping RTF sampling for this world"
    echo "N/A" > "$stats_log"
  else
    echo "stats topic: $stats_topic (sampling via $TIMEOUT_CMD)"
    "$TIMEOUT_CMD" "$SAMPLE_WINDOW_SEC" gz topic -e -t "$stats_topic" > "$stats_log" 2>&1
    # exit code 124 here means "ran the full window, then killed" -- that IS
    # success for this use case, not an error, so it's intentionally not
    # checked/branched on.
  fi

  ps aux > "$ps_log"

  local gz_rss_mib
  gz_rss_mib=$(ps aux | grep -i "gz-sim\|gz sim" | grep "worlds/${world}.world" | grep -v grep | awk '{sum+=$6} END {printf "%.1f", sum/1024}')

  local rtf_avg="N/A" rtf_n="0"
  if [[ -f "$stats_log" && "$(cat "$stats_log")" != "N/A" ]]; then
    rtf_avg=$(grep -oE 'real_time_factor: [0-9.]+' "$stats_log" | awk -F': ' '{v[NR]=$2} END {
      if (NR==0) { print "N/A"; exit }
      start = int(NR/2) + 1
      for (i=start; i<=NR; i++) { sum+=v[i]; n++ }
      if (n>0) printf "%.3f", sum/n; else print "N/A"
    }')
    rtf_n=$(grep -coE 'real_time_factor: [0-9.]+' "$stats_log")
    rtf_n=$(( rtf_n - rtf_n / 2 ))
  fi

  # Bug fixed 2026-07-23: also kill the whole process group, not just
  # launch_pid by pattern -- parameter_bridge/static_transform_publisher
  # command lines don't contain the world name, so they can survive
  # world_name:=/worlds/*.world pkill patterns and keep running indefinitely
  # (confirmed on Docker: leftover ones from an earlier dave_multibeam_sonar
  # run were still alive hours later, ~100% CPU each).
  cleanup_current
  sleep 1
  if pgrep -f "world_name:=${world}[[:space:]]" >/dev/null 2>&1 || \
     pgrep -f "worlds/${world}.world" >/dev/null 2>&1; then
    echo "WARNING: cleanup for ${world} may be incomplete -- a matching process is still running after kill/pkill" >&2
  fi
  CURRENT_PID=""
  CURRENT_WORLD=""

  echo "--> RTF avg (last ${rtf_n} samples): ${rtf_avg}, gz-sim RSS: ${gz_rss_mib} MiB"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${world}.world,${rtf_n},${rtf_avg},${gz_rss_mib},\"stats_topic=${stats_topic:-none}, settle=${SETTLE_SEC}s, window=${SAMPLE_WINDOW_SEC}s\"" >> "$RESULTS_CSV"
  echo
}

for entry in "${BENCH_WORLDS[@]}"; do
  IFS=':' read -r world launch_file namespace extra <<< "$entry"
  bench_one "$world" "$launch_file" "$namespace" "$extra"
done

echo "Done. Results in ${RESULTS_CSV}"
echo "Compare against notes/bench_results/benchmark_results.csv (Docker/llvmpipe) for the"
echo "same-methodology Mac-vs-Docker numbers README.md's August next-step asks for."
