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
# WHAT COUNTS AS A FAILURE OR WARNING: the gz-sim-main process dying before
# DURATION_HOURS elapses is CRASHED. For memory growth: this script computes
# a simple heuristic at the end of the run -- average RSS of the first half
# of alive samples vs. the second half -- and flags WARNING (not CRASH) if
# the second half is both >50 MiB and >50% higher than the first half. This
# is a coarse two-bucket comparison, not a real regression/slope fit, and a
# single run can't distinguish a slow leak from normal steady-state
# fluctuation with certainty -- treat WARNING as "worth a closer manual
# look at the CSV," not a confirmed leak. (Fixed 2026-07-23: earlier
# versions of this comment claimed monotonic-growth detection that was
# never actually implemented -- only first_rss/max_rss/liveness were
# tracked. This is the first version that actually computes a growth
# signal from the collected samples.)
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

# --- Process-group cleanup infrastructure (fixed 2026-07-23) ---
# Same bug/fix as test_worlds.sh/benchmark_worlds.sh: a background job's PID
# is not automatically a process-group leader without job control, so
# `kill -KILL -- "-$pid"` was silently targeting a nonexistent group. Fixed
# via `setsid`. A script-level trap also ensures this cleans up correctly
# if the script itself is killed/interrupted mid-run (relevant here since
# this script is specifically meant to be run detached via nohup/disown).
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
# a SIGTERM and exited 0. Since this script is specifically meant to be run
# detached/killed later, this mattered: the EXIT trap alone (fires on every
# exit path, including one triggered by `exit N` from a signal handler)
# guarantees cleanup runs exactly once; the signal-specific traps below just
# need to actually terminate the script with the conventional 128+signum
# exit code.
trap cleanup_current EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Hard-fail, not just warn (fixed 2026-07-23): this script is Docker/Linux-only
# (no Mac fallback exists here) and the launch line below unconditionally calls
# `setsid`, so a bare warning followed by a guaranteed "command not found" just
# produces a confusing failure well into a supposedly multi-hour run instead of
# a clean, immediate error before anything starts.
if ! command -v setsid >/dev/null 2>&1; then
  echo "ERROR: 'setsid' not found -- required for reliable process-group cleanup on this Docker/Linux-only script. Install util-linux (normally preinstalled on Ubuntu/Debian)." >&2
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

setsid "${cmd[@]}" > "$LAUNCH_LOG" 2>&1 < /dev/null &
launch_pid=$!
CURRENT_PID="$launch_pid"
CURRENT_WORLD="$WORLD"

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
cleanup_current
sleep 1
if pgrep -f "world_name:=${WORLD}[[:space:]]" >/dev/null 2>&1 || \
   pgrep -f "worlds/${WORLD}.world" >/dev/null 2>&1; then
  echo "WARNING: cleanup for ${WORLD} may be incomplete -- a matching process is still running after kill/pkill" >&2
fi
CURRENT_PID=""
CURRENT_WORLD=""

# Memory-growth heuristic (added 2026-07-23, see header comment): compare
# average RSS of the first half vs. second half of alive samples. This is a
# coarse two-bucket comparison, not a slope/regression fit -- flags WARNING,
# not CRASH, since a single run can't distinguish a real leak from
# steady-state fluctuation with certainty.
leak_line=$(awk -F, 'NR>1 && $3==1 {n++; rss[n]=$4} END {
    if (n < 4) { print "OK not enough alive samples (need >= 4) to assess a trend"; exit }
    half = int(n/2)
    for (i=1; i<=half; i++) { fsum+=rss[i] }
    for (i=n-half+1; i<=n; i++) { ssum+=rss[i] }
    favg = fsum/half
    savg = ssum/half
    growth = savg - favg
    pct = (favg>0) ? (growth/favg*100) : 0
    incr=0; maxincr=0
    for (i=2;i<=n;i++) { if (rss[i] >= rss[i-1]) { incr++ } else { incr=0 }; if (incr>maxincr) maxincr=incr }
    flag = (pct > 50 && growth > 50) ? "WARNING" : "OK"
    printf "%s first-half avg %.1f MiB, second-half avg %.1f MiB, growth %.1f MiB (%.0f%%), longest run of consecutive non-decreasing samples: %d\n", flag, favg, savg, growth, pct, maxincr
}' "$CSV")
leak_flag="${leak_line%% *}"
leak_detail="${leak_line#* }"

{
  echo "Stability test summary"
  echo "World: ${WORLD}"
  echo "Planned duration: ${DURATION_HOURS}h"
  echo "Outcome: $([[ $crashed == 1 ]] && echo "CRASHED before planned duration" || echo "SURVIVED full planned duration")"
  echo "Started RSS: ${first_rss:-N/A} MiB"
  echo "Max RSS observed: ${max_rss} MiB"
  echo "Memory-growth heuristic: ${leak_flag} -- ${leak_detail}"
  echo "  (heuristic only: coarse first-half-vs-second-half RSS comparison, not a slope fit or a confirmed leak diagnosis -- treat WARNING as worth a manual look at ${CSV}, not a verdict)"
  echo "Full sample log: ${CSV}"
  echo "Launch log: ${LAUNCH_LOG}"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} | tee "$SUMMARY"
