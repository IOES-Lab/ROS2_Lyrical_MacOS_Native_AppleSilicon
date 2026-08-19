#!/usr/bin/env bash
# test_worlds.sh
#
# Repeatable smoke-test runner for all 18 DAVE world files, per README.md
# "August" next-step: "Define a shared PASS/PARTIAL/NOT TESTED matrix
# (validation_matrix.csv) and a repeatable test script (test_worlds.sh)
# before running the full sweep, so results are comparable run to run."
#
# WHAT THIS DOES: for each world, launches it headless with `ros2 launch`,
# waits up to $TIMEOUT_SEC seconds, then classifies the outcome as
# PASS / CRASH / REVIEW / EXITED / SKIPPED (corrected 2026-07-23 -- this
# comment previously said "PASS / CRASH / TIMEOUT / SKIPPED", which doesn't
# match the actual status values the script writes; there is no TIMEOUT
# status, and REVIEW/EXITED were missing) by checking whether the process is
# still alive and grepping its log for known crash signatures. It is a SMOKE TEST
# (does Gazebo load and stay up), not a functional test of each sensor's
# topic output -- cross-check against validation_matrix.csv's existing
# FUNCTIONAL PASS rows (ocean current, dvl_world, dave_ocean_waves, etc.)
# which were verified by actually reading topic/service data, not just
# process liveness. (multibeam sonar is a stale example here as of
# 2026-07-23 -- it's since been downgraded to PARTIAL after a confirmed
# simulation-progress stall, see validation_matrix.csv.)
#
# WHAT THIS DOES NOT DO: it does not know the correct vehicle/namespace/
# launch-args combination for every world. Worlds already confirmed in
# validation_matrix.csv use their known-good args below. The 3 manipulation
# worlds (dave_bimanual_example, dave_electrical_mating, dave_plug_and_socket)
# are marked "unknown" and SKIPPED BY DEFAULT -- their launch file,
# dave_world.launch.py, has no headless mode and always spawns a real Qt GUI
# client that aborts with no X display attached, so a default run always
# hits the same known dead end; pass --include-unknown to attempt them
# anyway. (Bug fixed 2026-07-23: the WORLDS array previously marked every
# entry, including these 3, as known=1, which silently made
# --include-unknown a no-op and ran the manipulation worlds by default every
# time, misclassifying their expected GUI abort as a surprise CRASH instead
# of a understood NOT AUTOMATED limitation.) The two sonar-demo-adjacent
# worlds (dave_ocean_waves_sonar, dave_ocean_waves_sonar_integrated) and
# dave_integrated already have confirmed-working args and are known=1.
#
# USAGE (run inside the Docker container or Mac native env, after sourcing
# install/setup.bash / install/setup.zsh):
#   ./test_worlds.sh                     # run all worlds with known/default args
#   ./test_worlds.sh --include-unknown   # also attempt the 3 manipulation worlds
#   ./test_worlds.sh --only dave_ocean_waves,usbl_tutorial   # just these worlds
#   TIMEOUT_SEC=45 ./test_worlds.sh      # override the default 30s wait
#
# OUTPUT:
#   results/<world>.log            -- full stdout+stderr of that world's launch attempt
#   results/test_worlds_results.csv -- one row per run, appended (not overwritten),
#                                       so repeated runs are comparable over time
#
# Exit code is always 0 (a world failing is a result to record, not a script
# error) unless the script itself is misconfigured (e.g. ros2 not sourced).

set -uo pipefail

TIMEOUT_SEC="${TIMEOUT_SEC:-30}"
RESULTS_DIR="results"
RESULTS_CSV="${RESULTS_DIR}/test_worlds_results.csv"
INCLUDE_UNKNOWN=0
ONLY_LIST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-unknown) INCLUDE_UNKNOWN=1; shift ;;
    --only) ONLY_LIST="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ERROR: ros2 not found on PATH. Source install/setup.bash (or .zsh) first." >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"
if [[ ! -f "$RESULTS_CSV" ]]; then
  echo "timestamp,world_file,launch_file,status,elapsed_sec,log_file,notes" > "$RESULTS_CSV"
fi

# --- Process-group cleanup infrastructure (fixed 2026-07-23) ---
# Bug found (documentation audit): the PID captured from "cmd &" is NOT
# automatically a process-group leader in a non-interactive script -- job
# control/monitor mode is off by default under plain `set -uo pipefail`, so
# a background job stays in the SCRIPT's own process group rather than
# getting a new one. `kill -KILL -- "-$pid"` therefore targeted a process
# group that doesn't exist and failed silently (masked by `2>/dev/null`) --
# confirmed via a minimal Bash repro showing "group -<pid> DOES NOT exist".
# Fixed by launching via `setsid`, which creates a real new session+process
# group with PGID equal to the launched process's own PID, so the
# negative-PID kill now actually targets the right group. A script-level
# trap also ensures Ctrl+C/kill of this script itself still cleans up
# whatever world is currently running, not just the normal end-of-iteration
# path.
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
# a SIGTERM and exited 0. The EXIT trap alone (which fires on every exit path,
# including one triggered by `exit N` from a signal handler) is enough to
# guarantee cleanup runs exactly once; the signal-specific traps below only
# need to actually terminate the script with the conventional 128+signum
# exit code.
trap cleanup_current EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# Bug fixed 2026-07-23 (caught in review): this script's own usage comment
# claims Docker OR Mac native support, but the launch code unconditionally
# called `setsid` -- which isn't a standard macOS command -- and only printed
# a warning before still trying to call it, so on Mac every world would fail
# to even launch (not just fail to clean up). USE_SETSID now picks a real
# strategy up front instead of guessing at launch time: `setsid` on
# Linux/Docker (has util-linux by default), bash's own job-control monitor
# mode (`set -m`, see run_one() below) as a portable Mac fallback -- same
# approach already used in benchmark_worlds_mac.sh.
if command -v setsid >/dev/null 2>&1; then
  USE_SETSID=1
else
  USE_SETSID=0
  echo "NOTE: 'setsid' not found (expected on macOS) -- using bash job-control (set -m) for process-group cleanup instead." >&2
fi

# world_file : launch_file : namespace : extra_args : known(1)/unknown(0)
# "known" worlds use the exact args already verified in README.md / notes/.
# "unknown" worlds are best-effort guesses -- see header comment.
#
# IMPORTANT (discovered 2026-07-22): dave_robot.launch.py ALWAYS requires a
# namespace matching one of dave_robot_models/config/{rexrov,bluerov2,
# bluerov2_heavy,bluerov2_heavy_multibeam_sonar,glider_slocum}/robot_config.py
# -- there is no generic/environment-only default. Omitting it fails with
# "No such file or directory: .../config/robot_config.py". Every
# dave_robot.launch.py world below defaults to namespace:=rexrov (the one
# confirmed working in README.md) purely to smoke-test the WORLD, not to
# validate REXROV-specific behavior on that world.
WORLDS=(
  "camera_tutorial.world:dave_sensor.launch.py:camera:1"
  "dave_Santorini.world:dave_robot.launch.py:rexrov:1"
  "dave_bimanual_example.world:dave_world.launch.py::0"
  "dave_electrical_mating.world:dave_world.launch.py::0"
  "dave_graded_seabed.world:dave_robot.launch.py:rexrov:1"
  "dave_integrated.world:dave_robot.launch.py:rexrov:1"
  "dave_multibeam_sonar.world:dave_sensor.launch.py:blueview_p900:1:x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu"
  "dave_ocean_models.world:dave_robot.launch.py:rexrov:1"
  "dave_ocean_waves.world:dave_robot.launch.py:rexrov:1"
  "dave_ocean_waves_mossy_ground.world:dave_robot.launch.py:rexrov:1"
  "dave_ocean_waves_sonar.world:dave_sensor.launch.py:blueview_p900:1:x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu"
  "dave_ocean_waves_sonar_integrated.world:dave_sensor.launch.py:blueview_p900:1:x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu"
  "dave_ocean_waves_transient_current.world:dave_robot.launch.py:rexrov:1"
  "dave_plug_and_socket.world:dave_world.launch.py::0"
  "dvl_world.world:dave_sensor.launch.py:dvl:1"
  "new_dvl.world:dave_sensor.launch.py:dvl:1"
  "ocean_current_plugin.world:dave_robot.launch.py:rexrov:1"
  "usbl_tutorial.world:dave_sensor.launch.py:usbl:1"
)

run_one() {
  local world="$1" launch_file="$2" namespace="$3" known="$4" extra="${5:-}"
  local log_file="${RESULTS_DIR}/${world%.world}.log"
  local ts start end elapsed status notes cmd

  cmd=(ros2 launch dave_demos "$launch_file" "world_name:=${world%.world}" "paused:=false" "gui:=true" "headless:=true")
  [[ -n "$namespace" ]] && cmd+=("namespace:=${namespace}")
  if [[ -n "$extra" ]]; then
    # shellcheck disable=SC2206
    local extra_args=($extra)
    cmd+=("${extra_args[@]}")
  fi

  echo "=== $world ($([[ $known == 1 ]] && echo known-good args || echo BEST-EFFORT args)) ==="
  echo "cmd: ${cmd[*]}"

  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start=$(date +%s)

  if [[ "$USE_SETSID" == 1 ]]; then
    setsid "${cmd[@]}" > "$log_file" 2>&1 < /dev/null &
  else
    set -m
    "${cmd[@]}" > "$log_file" 2>&1 &
    set +m
  fi
  local pid=$!
  CURRENT_PID="$pid"
  CURRENT_WORLD="${world%.world}"

  sleep "$TIMEOUT_SEC"

  # "Hard" signatures are treated as real crash evidence on their own.
  # "stack trace (most recent call last)" alone is kept separate (see below)
  # -- fixed 2026-07-23 after docker/README.md documented a confirmed
  # non-fatal case of this exact log line (gz-sim-main stayed alive and
  # working 7+ minutes after it appeared, 2026-07-20 RAM/CPU load test).
  # Bug fixed 2026-07-23 (caught in review): the USBL server abort this repo
  # actually root-caused (UsblTransponder.cc's std::normal_distribution
  # assertion, SIGABRT/exit 134 -- see Known issues) wasn't matched by any
  # pattern here. If the sigma world-file workaround ever regressed, this
  # classifier would have called it EXITED, not CRASH. Added assertion/abort
  # patterns.
  local hard_crash_re='segmentation fault|core dumped|terminate called|failed to load plugin|could not connect to display|qt\.qpa|assertion.*failed|aborted|sigabrt|exit code 134'
  local stack_trace_re='stack trace \(most recent call last\)'

  if kill -0 "$pid" 2>/dev/null; then
    # still alive after the wait window -- treat as PASS (smoke test only;
    # does not confirm topic data, cross-check validation_matrix.csv),
    # then clean up.
    # Bug fixed 2026-07-22: being "still alive" at the timeout check does NOT
    # mean nothing crashed -- a sub-process (e.g. dave_world.launch.py's GUI
    # client, which has no headless mode and unconditionally spawns a real
    # Qt window) can abort while the top-level launch process and/or the
    # Gazebo server component stay alive, producing a false PASS. Confirmed:
    # dave_plug_and_socket.world showed "alive after 30s" here despite its
    # log containing the identical qt.qpa.xcb/SIGABRT trace seen in
    # dave_bimanual_example.world and dave_electrical_mating.world (which
    # DID get caught as CRASH, purely due to a timing race in when the
    # overall launch process happened to exit relative to the check). Now
    # always grep the log regardless of alive/dead status.
    #
    # Bug fixed 2026-07-23: a bare "stack trace (most recent call last)" log
    # line does NOT reliably mean the process is dying/dead -- only classify
    # as CRASH here when a harder signal (segfault/abort/plugin-load
    # failure/no-display) accompanies it. A stack-trace-only line on a
    # confirmed-alive process is downgraded to REVIEW so it's still
    # surfaced, not silently hidden and not falsely called CRASH either.
    if grep -qiE "$hard_crash_re" "$log_file"; then
      status="CRASH"
      notes="alive after ${TIMEOUT_SEC}s but crash signature found in log -- $(grep -iE "$hard_crash_re" "$log_file" | head -1)"
    elif grep -qiE "$stack_trace_re" "$log_file"; then
      status="REVIEW"
      notes="alive after ${TIMEOUT_SEC}s, but a 'stack trace' log line was seen with no other crash signature -- process did not die; treat as a non-fatal log artifact pending manual check, not a confirmed crash"
    else
      status="PASS"
      notes="alive after ${TIMEOUT_SEC}s"
    fi
  else
    wait "$pid" 2>/dev/null
    if grep -qiE "$hard_crash_re" "$log_file"; then
      status="CRASH"
      notes="$(grep -iE "$hard_crash_re" "$log_file" | head -1)"
    elif grep -qiE "$stack_trace_re" "$log_file"; then
      status="CRASH"
      notes="process exited before ${TIMEOUT_SEC}s; only signature found was a 'stack trace' log line (no segfault/abort/etc) -- likely but not conclusively related to the exit, inspect $log_file"
    else
      status="EXITED"
      notes="process exited before ${TIMEOUT_SEC}s with no recognized crash signature -- inspect $log_file"
    fi
  fi

  # Unconditional aggressive cleanup, regardless of PASS/CRASH/EXITED.
  # `ros2 launch`'s own child (the "gazebo-1" wrapper -> gz-sim-main) does
  # NOT reliably die just because the top-level launch_pid got SIGTERM'd --
  # confirmed 2026-07-22: after 3 test_worlds.sh runs, 14 orphaned
  # gz-sim-main processes were still alive and accumulating CPU/RAM (one had
  # grown to 3.2GB RSS / 108% CPU). SIGKILL by pattern match is the reliable
  # fix; a plain SIGTERM in the PASS branch alone was not enough.
  #
  # Bug fixed 2026-07-23: the world_name:=/worlds/*.world patterns above only
  # match the gz-sim process's own command line -- they do NOT match sibling
  # processes ros2 launch also spawns, like ros_gz_bridge's parameter_bridge
  # or tf2_ros's static_transform_publisher, whose command lines only contain
  # topic names (e.g. "/sensor/camera", "/model/rexrov/imu"), never the world
  # name. Confirmed real damage: leftover parameter_bridge processes from
  # earlier dave_multibeam_sonar runs were found still alive HOURS later,
  # each pegged near 100% CPU, inflating the container to 204% CPU / 6GB RAM
  # and starving/SIGKILLing unrelated later test runs (surfaced during a
  # stability-test investigation). Fixed by also killing the whole process
  # GROUP of the backgrounded `ros2 launch` job -- everything it spawns
  # (gazebo-1, create-2, parameter_bridge, static_transform_publisher, ...)
  # shares that process group unless a child explicitly detaches, so this
  # catches siblings the command-line pattern match cannot.
  cleanup_current
  sleep 1
  # Verify the cleanup actually worked (fixed 2026-07-23, per audit request):
  # warn loudly instead of silently trusting `2>/dev/null`-suppressed kills.
  if pgrep -f "world_name:=${world%.world}[[:space:]]" >/dev/null 2>&1 || \
     pgrep -f "worlds/${world%.world}.world" >/dev/null 2>&1; then
    echo "WARNING: cleanup for ${world} may be incomplete -- a matching process is still running after kill/pkill" >&2
  fi
  CURRENT_PID=""
  CURRENT_WORLD=""

  end=$(date +%s)
  elapsed=$((end - start))

  [[ $known == 0 ]] && notes="[best-effort args, unverified] ${notes}"

  echo "${ts},${world},${launch_file},${status},${elapsed},${log_file},\"${notes}\"" >> "$RESULTS_CSV"
  echo "--> ${status} (${elapsed}s)"
  echo
}

IFS=',' read -ra ONLY_ARR <<< "$ONLY_LIST"

for entry in "${WORLDS[@]}"; do
  IFS=':' read -r world launch_file namespace known extra <<< "$entry"

  if [[ -n "$ONLY_LIST" ]]; then
    match=0
    for o in "${ONLY_ARR[@]}"; do
      [[ "${world%.world}" == "$o" || "$world" == "$o" ]] && match=1
    done
    [[ $match == 0 ]] && continue
  fi

  if [[ $known == 0 && $INCLUDE_UNKNOWN == 0 && -z "$ONLY_LIST" ]]; then
    echo "=== $world SKIPPED (no headless path -- dave_world.launch.py always spawns a GUI client, pass --include-unknown to attempt anyway) ==="
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${world},${launch_file},SKIPPED,0,,\"no headless path -- dave_world.launch.py always spawns a GUI client with no X display here, not attempted by default -- see validation_matrix.csv\"" >> "$RESULTS_CSV"
    echo
    continue
  fi

  run_one "$world" "$launch_file" "$namespace" "$known" "$extra"
done

echo "Done. Results appended to ${RESULTS_CSV}"
