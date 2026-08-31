#!/usr/bin/env bash
set -u -o pipefail
repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="$repo/notes/results/multibeam_backend_equivalence_matrix_2026-08-30"
runner="$root/scripts/run_matrix_case.sh"
outroot="$root/exact_dft_candidate_v2"
mkdir -p "$outroot/results"
cases=("plane_2m_dark 2.0" "plane_4m_dark 4.0" "plane_4m_bright 4.0" "plane_7m_dark 7.0" "sphere_4m_bright 4.0" "cylinder_4m_bright 4.0")
printf 'case\tseconds\tready\tcapture_rc\tlaunch_rc\tsegfault\n' >"$outroot/run_summary.tsv"
for item in "${cases[@]}"; do
 read -r case_name expected <<<"$item"; out="$outroot/results/$case_name/wgpu"; mkdir -p "$out"; start=$(date +%s); echo "EXACT DFT $case_name"
 MATRIX_IMAGE=dave-sonar-equivalence-exact-dft-v2:20260830 "$runner" "$case_name" wgpu "$expected" "$out" >"$out/runner_stdout.txt" 2>&1
 ready=$(cat "$out/backend_ready.txt" 2>/dev/null||echo 0); capture=$(cat "$out/capture_rc.txt" 2>/dev/null||echo missing); launch=$(cat "$out/launch_rc.txt" 2>/dev/null||echo missing); segfault=0; grep -Eq 'Stack trace|Segmentation fault|exit code 139' "$out/launch.log" 2>/dev/null&&segfault=1
 printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$case_name" "$(( $(date +%s)-start ))" "$ready" "$capture" "$launch" "$segfault" >>"$outroot/run_summary.tsv"
done
