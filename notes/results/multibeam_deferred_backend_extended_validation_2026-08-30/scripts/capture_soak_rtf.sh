#!/usr/bin/env bash
set -u -o pipefail
name="${1:?container name}"
partition="${2:?GZ partition}"
out="${3:?output directory}"
count="${4:-4}"
interval="${5:-180}"
mkdir -p "$out"
for i in $(seq 1 "$count"); do
  date -u +%Y-%m-%dT%H:%M:%SZ >"$out/world_stats_sample_${i}.utc.txt"
  if ! docker inspect "$name" >/dev/null 2>&1; then
    printf 'container no longer exists\n' >"$out/world_stats_sample_${i}.txt"
    exit 0
  fi
  docker exec "$name" bash -lc \
    "source /opt/ros/lyrical/setup.bash; source /home/docker/dave_ws/install/setup.bash; export GZ_PARTITION=$partition; timeout 30 gz topic -e -t /world/default/stats -n 50" \
    >"$out/world_stats_sample_${i}.txt" 2>&1 || true
  if [[ "$i" -lt "$count" ]]; then sleep "$interval"; fi
done
