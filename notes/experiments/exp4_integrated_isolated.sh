#!/usr/bin/env bash
# exp4_integrated_isolated.sh — integrated 월드를 격리해서 CPU 상승을 재확인
# 지난 측정은 다른 gz-sim 인스턴스 2개가 같이 돌던 상태였다. 이번엔 혼자 돌린다.
set -e
MIN="${MIN:-15}"          # 관측 분
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/tmp/exp4_integrated_$(date +%H%M%S).csv"

echo "[사전] 다른 gz-sim 인스턴스 정리"
pkill -f gz-sim-server 2>/dev/null || true; sleep 3
if pgrep -f gz-sim-server >/dev/null; then echo "  ! 아직 살아있음. 수동 정리 필요"; exit 1; fi

ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=dave_ocean_waves_sonar_integrated paused:=false \
    compute_backend:=wgpu gui:=true headless:=true \
    > /tmp/exp4_launch.log 2>&1 &
sleep 60
PID=$(pgrep -f gz-sim-server | head -1)
[ -n "$PID" ] || { echo "gz-sim-server 못 찾음"; exit 1; }
echo "[관측] PID=$PID · ${MIN}분 · 30초 간격"
echo "elapsed_s,cpu_pct,rss_kb" > "$OUT"

for i in $(seq 1 $((MIN*2))); do
  read -r CPU RSS <<< "$(ps -o %cpu=,rss= -p "$PID" 2>/dev/null)"
  [ -n "${CPU:-}" ] || { echo "  프로세스 종료됨"; break; }
  printf '%s,%s,%s\n' "$((i*30))" "$CPU" "$RSS" | tee -a "$OUT"
  sleep 30
done

bash "$HERE/rtf_probe.sh" /world/oceans_waves_sonar_integrated/stats 60 "integrated-isolated"
kill -INT %1 2>/dev/null || true; pkill -f gz-sim-server 2>/dev/null || true

echo; echo "저장: $OUT"
echo "판정:"
echo "  CPU 상승 + RSS 상승  -> 버퍼/로그 누적. 어디서 쌓이는지 찾으면 됨."
echo "  CPU만 상승, RSS 평탄 -> 누적 아님. 스레드/락 경합 쪽."
echo "  둘 다 평탄           -> 지난 상승은 다른 인스턴스 간섭이었음. PARTIAL 해제 근거."
