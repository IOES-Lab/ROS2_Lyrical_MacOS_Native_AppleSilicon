#!/usr/bin/env bash
set -u -o pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
runner="$repo/notes/results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/scripts/run_derived_case.sh"
root="${1:-$repo/notes/results/multibeam_deferred_backend_extended_validation_2026-08-30/wgpu_cold_start_20}"
runs="${RUNS:-20}"
mkdir -p "$root"

printf 'run\tstart_utc\tend_utc\tseconds\tbackend_ready\tpoint_ok\traw_ok\tlaunch_rc\tllvmpipe\tsegfault\n' > "$root/summary.tsv"

for i in $(seq 1 "$runs"); do
  tag=$(printf 'run_%02d' "$i")
  out="$root/$tag"
  mkdir -p "$out"
  start_epoch=$(date +%s)
  start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '[%s/%s] %s start %s\n' "$i" "$runs" "$tag" "$start_utc"

  DAVE_SONAR_TEST_LIMIT="${DAVE_SONAR_TEST_LIMIT:-300}" \
    "$runner" wgpu "$out" >"$out/runner_stdout.txt" 2>&1
  runner_rc=$?

  end_epoch=$(date +%s)
  end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  seconds=$((end_epoch-start_epoch))
  ready=$(cat "$out/backend_ready.txt" 2>/dev/null || echo 0)
  point=$(cat "$out/point_ok.txt" 2>/dev/null || echo 0)
  raw=$(cat "$out/raw_ok.txt" 2>/dev/null || echo 0)
  launch_rc=$(cat "$out/launch_rc.txt" 2>/dev/null || echo missing)
  llvmpipe=0
  segfault=0
  grep -q 'selected adapter: llvmpipe' "$out/launch.log" 2>/dev/null && llvmpipe=1
  grep -Eq 'Stack trace|Segmentation fault|exit code 139' "$out/launch.log" 2>/dev/null && segfault=1

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$tag" "$start_utc" "$end_utc" "$seconds" "$ready" "$point" "$raw" \
    "$launch_rc" "$llvmpipe" "$segfault" >> "$root/summary.tsv"
  printf '[%s/%s] %s done seconds=%s ready=%s point=%s raw=%s llvmpipe=%s segfault=%s runner_rc=%s\n' \
    "$i" "$runs" "$tag" "$seconds" "$ready" "$point" "$raw" "$llvmpipe" "$segfault" "$runner_rc"
done
