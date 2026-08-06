#!/usr/bin/env bash
# exp8_profile.sh — 실행 중인 gz-sim 을 프로파일링한다 (macOS `sample`)
#
# 왜 이걸 하는가:
#   하루 종일 RTF 델타로 "어느 코드가 비싼가"를 *추론*해왔다. exp7 이 연산
#   단계를 배제했고, Release 리빌드가 비용을 플러그인 쪽으로 좁혔다. 하지만
#   FillPointCloudMsg 를 직접 잰 적은 한 번도 없다. 지금까지 전부 정황이다.
#
#   sample(1) 은 붙어 있는 프로세스의 콜스택을 1ms 간격으로 뜬다. 리빌드도
#   코드 수정도 필요 없고, 10초면 수천 개 샘플이 쌓인다 — 지금까지의 n=1
#   측정과 달리 이건 분포다.
#
# 판정 기준 (측정 전에 못박아 둔다. 결과를 보고 정하면 안 된다):
#   FillPointCloudMsg 가 스텝 스레드 샘플의 상당 부분  -> 삼각함수 패치가 정당.
#                                                        before/after 를 잴 대상.
#   Render()/gz-rendering 이 대부분                    -> 플러그인 패치는 헛수고.
#                                                        업스트림 gz-rendering 문제.
#   둘 다 아님                                          -> 전제가 틀렸다. 재검토.
#
# 주의: 심볼이 안 나올 수 있다. Release 는 -g 를 안 붙이므로 주소만 뜰 수 있다.
#       그때는 RelWithDebInfo 로 다시 빌드해야 한다 (스크립트가 알려준다).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

DUR="${DUR:-10}"          # 샘플링 시간(초)
INTERVAL="${INTERVAL:-1}" # 샘플 간격(ms)
STAMP="$(date +%m%d_%H%M)"
OUT="${OUT:-/tmp/exp8_profile_$STAMP.txt}"
LOG="/tmp/exp8_launch_$STAMP.log"

command -v sample >/dev/null 2>&1 || {
  echo "! sample(1) 이 없습니다. macOS 전용 스크립트입니다."; exit 1; }

echo "=========================================================="
echo " exp8 — 실행 중인 소나 월드 프로파일링"
echo "   샘플링   ${DUR}초 @ ${INTERVAL}ms"
echo "   출력     $OUT"
echo "=========================================================="

preflight || exit 1
cleanup
assert_clean || exit 2

launch_sonar_world "$LOG" "${WORLD:-dave_multibeam_sonar}"
echo "  launch 완료 (로그 $LOG)"
trap 'cleanup; echo "[정리] 완료"' EXIT
assert_launch_alive "$LOG" || exit 5

settle_for_sonar "$LOG" 300 || {
  echo "  ! 소나가 300초 안에 안 올라왔습니다. 프로파일해도 의미 없습니다."; exit 3; }

TOPIC=$(resolve_topic 60) || { echo "  ! stats 토픽 없음"; exit 4; }
echo "  topic = $TOPIC"

# 로그만 믿으면 안 된다 — 아직 정지 구간이면 소나가 아니라 기동을 프로파일한다.
wait_until_stepping "$TOPIC" "${STEP_MAX:-420}" "${STEP_MIN:-60}" || exit 6

PID=$(find_gz_pid) || { echo "  ! gz-sim PID 를 못 찾았습니다"; exit 7; }
echo
echo "  PID $PID 에 붙습니다. ${DUR}초 대기..."

# 프로파일과 *같은 창*에서 RTF 를 잰다. 이게 없으면 어느 구간을 떴는지
# 알 수 없다. 2026-08-05 첫 프로파일이 정확히 이 문제였다: 스텝 속도로
# 역산하면 RTF ~0.94 인데 같은 빌드의 측정값은 0.438 이었고, 둘 중 어느
# 쪽을 프로파일한 건지 판단할 근거가 없었다.
RTFOUT="/tmp/exp8_rtf_$STAMP.txt"
bash "$HERE/rtf_probe.sh" "$TOPIC" "$DUR" "profile_window" > "$RTFOUT" 2>&1 &
RTF_BG=$!

if ! sample "$PID" "$DUR" "$INTERVAL" -f "$OUT" 2>/dev/null; then
  echo "  ! sample 실패. 권한 문제일 수 있습니다. 다시 시도:"
  echo "      sudo sample $PID $DUR $INTERVAL -f $OUT"
  kill "$RTF_BG" 2>/dev/null || true
  exit 8
fi
wait "$RTF_BG" 2>/dev/null || true
echo "  -> 저장: $OUT"

echo
echo "===== 프로파일 창의 RTF ====="
echo "  이 값이 기준선(Release 0.438)과 크게 다르면, 위 프로파일은 그"
echo "  기준선과 다른 구간을 뜬 것이므로 그대로 인용하면 안 됩니다."
grep '^RESULT' "$RTFOUT" 2>/dev/null | sed 's/^/  /' || sed 's/^/  /' "$RTFOUT"

# --- 심볼이 실제로 나왔는지 먼저 확인한다 ---------------------------------
# 주소만 있는 프로파일은 읽을 수 없다. 여기서 안 걸러내면 아래 grep 이 전부
# 0 건으로 나오고, 그걸 "그 함수가 안 비싸다"로 잘못 읽게 된다.
echo
echo "===== 심볼 확인 ====="
if grep -q 'MultibeamSonar\|multibeam_sonar' "$OUT"; then
  echo "  OK — 소나 플러그인 심볼이 보입니다."
else
  echo "  ! 소나 플러그인 심볼이 안 보입니다."
  echo "    아래 결과를 '그 함수가 안 비싸다'로 읽으면 안 됩니다."
  echo "    심볼 없이 잡힌 것일 수 있습니다. RelWithDebInfo 로 다시 빌드:"
  echo "      colcon build --packages-select multibeam_sonar multibeam_sonar_system \\"
  echo "        --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo"
fi

# --- 분석 -------------------------------------------------------------------
# 여기서 grep -c 를 쓰면 안 된다. sample 출력의 한 줄은 서로 다른 콜스택
# 경로 하나이고, 무게는 줄 앞의 숫자다. 2026-08-05 첫 판이 grep -c 로
# 요약을 내는 바람에 "FillPointCloudMsg 6" 같은 값이 나왔는데, 그건
# 6샘플이 아니라 경로가 6개라는 뜻이었다. 무게는 알 수 없는 값이었다.
#
# 또 sample 은 자고 있는 스레드도 전부 샘플링한다 (25개 스레드가 모두
# 총 5946 으로 찍힌다). 유휴를 안 걷어내면 합계가 무의미하다.
echo
python3 "$HERE/analyze_profile.py" "$OUT"

echo
echo "=========================================================="
echo " 다음: 전체 파일을 직접 읽으세요. 위 카운트는 요약일 뿐입니다."
echo "   less $OUT"
echo
echo " 읽는 법 — 스레드별로 나뉘어 있습니다. 소나는 스레드가 셋입니다:"
echo "   메인/스텝 스레드   시뮬레이션 루프"
echo "   렌더 스레드        Render() 와 OnNewFrame -> FillPointCloudMsg"
echo "   computeThread_     ComputeSonarImage (비동기, 임계경로 밖)"
echo " computeThread_ 가 아무리 무거워도 그건 exp7 이 이미 배제한 축입니다."
echo " 봐야 할 곳은 렌더 스레드입니다."
echo "=========================================================="
