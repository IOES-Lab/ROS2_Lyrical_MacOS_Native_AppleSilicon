#!/usr/bin/env bash
set -u -o pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="$repo/notes/results/multibeam_seed_determinism_validation_2026-08-31"
runner="$repo/notes/results/multibeam_backend_equivalence_matrix_2026-08-30/scripts/run_matrix_case.sh"
image="${FIXED_FRAME_IMAGE:-dave-sonar-fixed-frame-exact-dft:20260831}"
runs="${FIXED_FRAME_RUNS:-3}"
mkdir -p "$root/repeats"
printf 'run\tseconds\tready\tcapture_rc\tlaunch_rc\tfirst_raw_hash\tunique_raw_hashes\n' >"$root/repeats/summary.tsv"

for run in $(seq 1 "$runs"); do
  out="$root/repeats/run_$(printf '%02d' "$run")"
  start=$(date +%s)
  MATRIX_IMAGE="$image" MATRIX_CASE_LIMIT=900 "$runner" \
    plane_4m_bright wgpu 4.0 "$out" >"$out.runner.log" 2>&1
  seconds=$(( $(date +%s) - start ))
  ready=$(cat "$out/backend_ready.txt" 2>/dev/null || echo missing)
  capture=$(cat "$out/capture_rc.txt" 2>/dev/null || echo missing)
  launch=$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)
  read -r hash unique < <(python3 - "$out/capture_summary.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1]))
h=[x['data_sha256'] for x in d['raw_frames']]
print(h[0],len(set(h)))
PY
  )
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$seconds" "$ready" "$capture" "$launch" "$hash" "$unique" >>"$root/repeats/summary.tsv"
  echo "run=$run seconds=$seconds hash=$hash unique=$unique"
done
