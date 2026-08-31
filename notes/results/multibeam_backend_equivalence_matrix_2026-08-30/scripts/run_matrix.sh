#!/usr/bin/env bash
set -u -o pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="$repo/notes/results/multibeam_backend_equivalence_matrix_2026-08-30"
runner="$root/scripts/run_matrix_case.sh"
mkdir -p "$root/results"

cases=(
  "plane_2m_dark 2.0"
  "plane_4m_dark 4.0"
  "plane_4m_bright 4.0"
  "plane_7m_dark 7.0"
  "sphere_4m_bright 4.0"
  "cylinder_4m_bright 4.0"
)

printf 'case\tbackend\tstart_utc\tend_utc\tseconds\tready\tcapture_rc\tlaunch_rc\tsegfault\n' > "$root/run_summary.tsv"
for item in "${cases[@]}"; do
  read -r case_name expected <<< "$item"
  for backend in cpu wgpu; do
    out="$root/results/$case_name/$backend"
    mkdir -p "$out"
    start=$(date +%s)
    start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "CASE $case_name BACKEND $backend"
    "$runner" "$case_name" "$backend" "$expected" "$out" \
      > "$out/runner_stdout.txt" 2>&1
    runner_rc=$?
    end=$(date +%s)
    end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    ready=$(cat "$out/backend_ready.txt" 2>/dev/null || echo 0)
    capture_rc=$(cat "$out/capture_rc.txt" 2>/dev/null || echo missing)
    launch_rc=$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)
    segfault=0
    grep -Eq 'Stack trace|Segmentation fault|exit code 139' "$out/launch.log" 2>/dev/null && segfault=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$case_name" "$backend" "$start_utc" "$end_utc" "$((end-start))" \
      "$ready" "$capture_rc" "$launch_rc" "$segfault" >> "$root/run_summary.tsv"
    echo "DONE $case_name $backend seconds=$((end-start)) runner_rc=$runner_rc capture_rc=$capture_rc"
  done
done

python3 "$root/scripts/analyze_matrix.py" > "$root/analysis_stdout.txt"
