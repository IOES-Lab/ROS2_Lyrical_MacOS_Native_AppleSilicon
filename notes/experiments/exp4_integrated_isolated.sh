#!/usr/bin/env bash
# exp4_integrated_isolated.sh — integrated 월드를 격리해서 재측정
#
# 두 가지를 동시에 얻는다.
#   (1) CPU 상승(32%->47%->69%) 재확인. 지난 측정은 다른 gz-sim 2개가 같이
#       돌던 상태였다. 이번엔 혼자 돌린다.
#   (2) **맥에서의 integrated RTF.** 이게 지금 더 중요하다 — 아래 참고.
#
# 왜 이게 다음 실험들의 전제인가 (2026-08-03):
#   "빈 장면(multibeam)이 하이트맵 있는 장면(integrated)보다 느리다"는 관찰이
#   exp1/exp1c/exp3 의 설계 근거였는데, 그 비교는 Docker 의 두 수치
#   (0.0018 / 0.03)로 만들어진 것이었다. 그중 0.0018 은 2026-08-03 에
#   **다른 월드를 잰 값으로 밝혀져 폐기**됐고, 맥에서 multibeam 은 0.19~0.22 다.
#   integrated 는 맥에서 보정된 방법으로 잰 적이 아직 없다.
#   즉 그 비대칭이 실재하는지조차 확인되지 않았다. 이 실험이 그걸 정한다.
#
# 2026-08-03 재작성. 이전 판은 고정 `sleep 60` 뒤에 CPU 를 재기 시작했는데,
# 소나 초기화가 145~175초 걸리므로 앞부분 표본이 기동 구간이었다. CPU 상승이
# 실제 누적인지 그냥 기동인지 구분이 안 된다. 이제 매 표본마다 소나 상태를
# 같이 기록한다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

MIN="${MIN:-15}"
WIN="${WIN:-60}"
LOG=/tmp/exp4_launch.log
OUT="/tmp/exp4_integrated_$(date +%m%d_%H%M).csv"

preflight || { echo; echo "사전 점검 실패 — 측정하지 않습니다."; exit 1; }

cleanup
assert_clean || exit 1
trap 'cleanup; echo "[정리] 완료"' EXIT

echo "[launch] dave_ocean_waves_sonar_integrated"
launch_sonar_world "$LOG" dave_ocean_waves_sonar_integrated
assert_launch_alive "$LOG" || exit 1

# PID 확보 — 맥/리눅스에서 프로세스명이 다를 수 있어 두 패턴을 본다
PID=""
for _ in $(seq 1 20); do
  PID=$(find_gz_pid) && [ -n "$PID" ] && break
  PID=""
  sleep 3
done
if [ -z "$PID" ]; then
  echo "  ! gz-sim 프로세스를 60초 안에 못 찾았습니다."
  echo "    launch 는 살아있는데 시뮬레이터가 안 뜬 것이거나, 그새 죽은 것입니다."
  echo "  --- 지금 떠 있는 관련 프로세스 ---"
  ps -eo pid,pcpu,etime,comm 2>/dev/null | grep -i -e gz -e ruby | grep -v grep | sed 's/^/    /' || echo "    (없음)"
  echo "  --- $LOG 마지막 30줄 ---"
  tail -30 "$LOG" 2>/dev/null | sed 's/^/    /'
  exit 1
fi

echo "[관측] PID=$PID · ${MIN}분 · 30초 간격 · 소나 상태 동시 기록"
echo "elapsed_s,cpu_pct,rss_kb,sonar_up" > "$OUT"
printf '  %6s %8s %10s  소나\n' 't(s)' 'CPU%' 'RSS(KB)'

for i in $(seq 1 $((MIN*2))); do
  read -r CPU RSS <<< "$(ps -o %cpu=,rss= -p "$PID" 2>/dev/null)"
  [ -n "${CPU:-}" ] || { echo "  프로세스 종료됨 — 이후 표본 없음"; break; }
  UP=$(sonar_is_up "$LOG")
  printf '  %6s %8s %10s  %s\n' "$((i*30))" "$CPU" "$RSS" "$([ "$UP" = 1 ] && echo 켜짐 || echo 아직)"
  echo "$((i*30)),$CPU,$RSS,$UP" >> "$OUT"
  sleep 30
done

echo
if [ "$(sonar_is_up "$LOG")" != 1 ]; then
  echo "  ! 관측이 끝날 때까지 소나가 안 올라왔습니다."
  echo "    RTF 를 재도 소나 없는 월드를 재는 것이므로 측정하지 않습니다."
  echo "    로그: $LOG"
  exit 1
fi

TOPIC=$(resolve_topic 60) || { echo "  ! stats 토픽을 못 찾음"; exit 1; }
echo "[RTF] topic = $TOPIC"
R=$(bash "$HERE/rtf_probe.sh" "$TOPIC" "$WIN" "integrated-isolated" | tee /dev/stderr \
    | grep '^RESULT' || true)

echo; echo "===== 결과 ====="
echo "  CPU/RSS 원본: $OUT"
if [ -n "$R" ]; then
  echo "  integrated RTF (맥, 보정된 방법): $(echo "$R" | cut -d, -f3)"
else
  echo "  RTF 측정 실패"
fi
echo
echo "  대조군 (맥, 보정된 방법):"
echo "    multibeam 소나 있음 10m   0.19~0.22"
echo "    multibeam 소나 없음        0.9996"
echo
echo "판정 — 폐기된 전제에 대하여:"
echo "  integrated 가 multibeam(0.19~0.22)보다 뚜렷이 빠름"
echo "    -> '빈 장면이 더 느리다'가 맥에서도 성립. exp1/exp3 진행할 근거가 생김."
echo "  비슷하거나 더 느림"
echo "    -> 그 전제는 Docker 오측정의 산물이었음. exp1/exp3 는 목적을 다시 정해야 함."
echo
echo "판정 — CPU 상승에 대하여:"
echo "  sonar_up=0 구간에서만 오르고 1 이후 평탄 -> 기동 구간이었음. 결함 아님."
echo "  sonar_up=1 이후로도 계속 오름 + RSS 동반 상승 -> 버퍼/로그 누적."
echo "  sonar_up=1 이후로도 오르는데 RSS 평탄 -> 스레드/락 경합 쪽."
echo "  전 구간 평탄 -> 지난 상승은 다른 인스턴스 간섭. PARTIAL 해제 근거."
