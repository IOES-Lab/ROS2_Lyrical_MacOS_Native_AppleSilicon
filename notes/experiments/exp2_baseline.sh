#!/usr/bin/env bash
# exp2_baseline.sh — 소나 없이 같은 월드만 띄워서 기준 RTF를 잡는다
# 이게 있어야 "소나가 원인이다"를 수치로 말할 수 있다
set -e
WIN="${WIN:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "=============== 소나 없이 월드만 (dave_world.launch.py) ==============="
ros2 launch dave_demos dave_world.launch.py \
    world_name:=dave_multibeam_sonar gui:=true headless:=true \
    > /tmp/exp2_baseline.log 2>&1 &
LP=$!
echo "  60초 안정화 대기..."; sleep 60
bash "$HERE/rtf_probe.sh" "$(bash "$HERE/stats_topic.sh" 60)" "$WIN" "no-sonar-baseline"
kill -INT $LP 2>/dev/null || true; sleep 8
pkill -f gz-sim-server 2>/dev/null || true

echo
echo "판정:"
echo "  기준 RTF ~1.0        -> 느린 원인은 전부 소나 센서. 정상."
echo "  기준 RTF도 낮음      -> 소나 문제가 아니라 월드/물리 쪽. 방향 전환 필요."
