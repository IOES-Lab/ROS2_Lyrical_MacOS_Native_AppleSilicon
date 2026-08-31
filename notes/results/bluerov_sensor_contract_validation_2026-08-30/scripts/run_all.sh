#!/usr/bin/env bash
set -u -o pipefail
repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="${1:-$repo/notes/results/bluerov_sensor_contract_validation_2026-08-30}"
runner="$root/scripts/run_variant.sh"
for variant in bluerov2 bluerov2_heavy bluerov2_heavy_multibeam_sonar; do
  echo "=== $variant ==="
  "$runner" "$variant" "$root/runtime/$variant" auto
 done
