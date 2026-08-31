#!/usr/bin/env bash
set -u -o pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
runner="$repo/notes/results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/scripts/run_combined_control_v2.sh"
root="${1:-$repo/notes/results/multibeam_deferred_backend_extended_validation_2026-08-30/heavy_repeated_3}"
runs="${RUNS:-3}"
mkdir -p "$root"

printf 'run\tstart_utc\tend_utc\tseconds\tbackend\tpoint\traw\tconnected\tarmed\tcontrols\tdelta_x_m\tdisarmed\tsegfault\n' > "$root/summary.tsv"

for i in $(seq 1 "$runs"); do
  tag=$(printf 'run_%02d' "$i")
  out="$root/$tag"
  mkdir -p "$out"
  start=$(date +%s)
  start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "[$i/$runs] $tag start $start_utc"
  "$runner" "$out" >"$out/runner_stdout.txt" 2>&1
  runner_rc=$?
  end=$(date +%s)
  end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  python3 - "$out" "$tag" "$start_utc" "$end_utc" "$((end-start))" >> "$root/summary.tsv" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
try:
    summary = json.loads((out / "functional_summary.json").read_text())
except Exception:
    summary = {}
values = [
    sys.argv[2],
    sys.argv[3],
    sys.argv[4],
    sys.argv[5],
    int(bool(summary.get("backend_ready"))),
    int(bool(summary.get("pointcloud_513x301"))),
    int(bool(summary.get("raw_sonar_513x399"))),
    int(bool(summary.get("mavros_connected"))),
    int(bool(summary.get("armed"))),
    summary.get("manual_control_messages", 0),
    summary.get("odometry_x_delta_m", ""),
    int(bool(summary.get("disarmed"))),
    int(bool(summary.get("ogre2_segfault"))),
]
print("\t".join(map(str, values)))
PY
  echo "[$i/$runs] $tag done seconds=$((end-start)) runner_rc=$runner_rc"
done
