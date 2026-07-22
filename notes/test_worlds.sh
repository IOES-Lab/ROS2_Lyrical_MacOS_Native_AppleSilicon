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
# PASS / CRASH / TIMEOUT / SKIPPED by checking whether the process is still
# alive and grepping its log for known crash signatures. It is a SMOKE TEST
# (does Gazebo load and stay up), not a functional test of each sensor's
# topic output -- cross-check against validation_matrix.csv's existing PASS
# rows (multibeam sonar, ocean current, etc.) which were verified by
# actually reading topic/service data, not just process liveness.
#
# WHAT THIS DOES NOT DO: it does not know the correct vehicle/namespace/
# launch-args combination for every world. Worlds already confirmed in
# validation_matrix.csv use their known-good args below. Worlds marked
# "unknown" launch file in the matrix (manipulation scenarios, sonar-demo
# worlds, dave_integrated) are SKIPPED BY DEFAULT -- pass --include-unknown
# to attempt them anyway with a best-effort default (results should be
# treated as exploratory, not authoritative, until the correct launch args
# are confirmed and the matrix updated).
#
# USAGE (run inside the Docker container or Mac native env, after sourcing
# install/setup.bash / install/setup.zsh):
#   ./test_worlds.sh                     # run all worlds with known/default args
#   ./test_worlds.sh --include-unknown   # also attempt manipulation/sonar-demo/integrated worlds
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

# world_file : launch_file : namespace : extra_args : known(1)/unknown(0)
# "known" worlds use the exact args already verified in README.md / notes/.
# "unknown" worlds are best-effort guesses -- see header comment.
WORLDS=(
  "camera_tutorial.world:dave_sensor.launch.py:camera:1"
  "dave_Santorini.world:dave_robot.launch.py::0"
  "dave_bimanual_example.world:dave_robot.launch.py::0"
  "dave_electrical_mating.world:dave_robot.launch.py::0"
  "dave_graded_seabed.world:dave_robot.launch.py::0"
  "dave_integrated.world:dave_robot.launch.py::0"
  "dave_multibeam_sonar.world:dave_sensor.launch.py:blueview_p900:1:x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu"
  "dave_ocean_models.world:dave_robot.launch.py::0"
  "dave_ocean_waves.world:dave_robot.launch.py:rexrov:1"
  "dave_ocean_waves_mossy_ground.world:dave_robot.launch.py::0"
  "dave_ocean_waves_sonar.world:dave_sensor.launch.py::0"
  "dave_ocean_waves_sonar_integrated.world:dave_sensor.launch.py::0"
  "dave_ocean_waves_transient_current.world:dave_robot.launch.py::0"
  "dave_plug_and_socket.world:dave_robot.launch.py::0"
  "dvl_world.world:dave_sensor.launch.py:dvl:1"
  "new_dvl.world:dave_sensor.launch.py:dvl:0"
  "ocean_current_plugin.world:dave_robot.launch.py::1"
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

  "${cmd[@]}" > "$log_file" 2>&1 &
  local pid=$!

  sleep "$TIMEOUT_SEC"

  if kill -0 "$pid" 2>/dev/null; then
    # still alive after the wait window -- treat as PASS (smoke test only;
    # does not confirm topic data, cross-check validation_matrix.csv),
    # then clean up.
    status="PASS"
    notes="alive after ${TIMEOUT_SEC}s"
    kill -TERM "$pid" 2>/dev/null
    sleep 2
    kill -KILL "$pid" 2>/dev/null
    pkill -TERM -f "world_name:=${world%.world}" 2>/dev/null
  else
    wait "$pid" 2>/dev/null
    if grep -qiE 'segmentation fault|core dumped|terminate called|stack trace \(most recent call last\)|failed to load plugin' "$log_file"; then
      status="CRASH"
      notes="$(grep -iE 'segmentation fault|core dumped|terminate called|failed to load plugin' "$log_file" | head -1)"
    else
      status="EXITED"
      notes="process exited before ${TIMEOUT_SEC}s with no recognized crash signature -- inspect $log_file"
    fi
  fi

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
    echo "=== $world SKIPPED (unknown launch args -- pass --include-unknown to attempt) ==="
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),${world},${launch_file},SKIPPED,0,,\"unknown launch args, not attempted -- see validation_matrix.csv\"" >> "$RESULTS_CSV"
    echo
    continue
  fi

  run_one "$world" "$launch_file" "$namespace" "$known" "$extra"
done

echo "Done. Results appended to ${RESULTS_CSV}"
