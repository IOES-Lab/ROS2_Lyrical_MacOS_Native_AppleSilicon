#!/usr/bin/env bash
set -u -o pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
runner="$repo/notes/results/multibeam_deferred_backend_extended_validation_2026-08-30/scripts/run_clean_shutdown_case.sh"
root="${1:-$repo/notes/results/multibeam_deferred_backend_extended_validation_2026-08-30/clean_shutdown_10}"
runs="${RUNS:-10}"
mkdir -p "$root"

printf 'run\tbackend_ready\tpoint_ok\traw_ok\tlaunch_rc\tescalation\tbridge_exit_minus_11\tgazebo_sigint\tsegfault\n' > "$root/summary.tsv"
for i in $(seq 1 "$runs"); do
  tag=$(printf 'run_%02d' "$i")
  out="$root/$tag"
  echo "[$i/$runs] $tag"
  "$runner" wgpu "$out" > "$out.runner_stdout.txt" 2>&1
  ready=$(cat "$out/backend_ready.txt" 2>/dev/null || echo 0)
  point=$(cat "$out/point_ok.txt" 2>/dev/null || echo 0)
  raw=$(cat "$out/raw_ok.txt" 2>/dev/null || echo 0)
  launch_rc=$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)
  escalation=$(cat "$out/shutdown_escalation.txt" 2>/dev/null || echo missing)
  bridge=0
  gazebo_sigint=0
  segfault=0
  grep -Eq 'parameter_bridge.*exit code -11' "$out/launch.log" 2>/dev/null && bridge=1
  grep -Eq 'gazebo.*exit code -2' "$out/launch.log" 2>/dev/null && gazebo_sigint=1
  grep -Eq 'Stack trace|Segmentation fault|exit code 139' "$out/launch.log" 2>/dev/null && segfault=1
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$tag" "$ready" "$point" "$raw" "$launch_rc" "$escalation" \
    "$bridge" "$gazebo_sigint" "$segfault" >> "$root/summary.tsv"
done
