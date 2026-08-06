#!/usr/bin/env bash
# exp9_threads.sh — 스레드 수를 줄여서 RTF 가 오르는지 본다
#
# 왜:
#   2026-08-05 프로파일에서 busy CPU 의 49.3% 가 스핀 대기였다.
#     21.8%  tbb::stealing_loop_backoff::pause()   워커 7개, 8코어 머신
#     16.1%  boost::interprocess::spin_wait::yield()  Fast DDS 공유메모리
#      4.3%  Ogre::pthread_barrier_wait
#   병목이 특정 함수가 아니라 오버서브스크립션이라면, 스레드 수를 줄이는
#   것만으로 RTF 가 올라야 한다. 리빌드도 코드 수정도 필요 없다.
#
# 판정 (돌리기 전에 못박는다):
#   어느 조건이든 기준선 대비 유의하게 개선  -> 오버서브스크립션 가설 지지.
#                                              어느 축인지까지 좁혀진다.
#   전부 기준선과 같음                        -> 스핀은 증상이지 원인이 아니다.
#                                              가설 폐기.
#   악화                                      -> 그 축은 실제로 일하고 있었다.
#
# 정직하게 남겨둘 것:
#   TBB 풀을 누가 소유하는지 아직 모른다 (OpenCV 일 수도, gz/DART 일 수도).
#   그래서 아래 환경변수 중 무엇이 실제로 먹히는지도 모른다. 이 스크립트는
#   그걸 알아내려고 돌리는 것이지, 안다고 가정하고 돌리는 게 아니다.
#   변수가 안 먹었는데 "변화 없음" 이 나오면 가설을 기각하면 안 된다.
#   그래서 VERIFY=1 이면 조건마다 프로파일을 떠서 스핀이 실제로 줄었는지 본다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

WIN="${WIN:-60}"
VERIFY="${VERIFY:-1}"     # 1이면 조건마다 5초 프로파일도 뜬다
STAMP="$(date +%m%d_%H%M)"
OUT="/tmp/exp9_threads_$STAMP.csv"

echo "condition,rtf,sim_delta,real_delta,msgs,spin_pct" > "$OUT"
echo "4개 조건 · 건당 5~7분 · 총 25분 이상 걸립니다."
echo "저장: $OUT"

# 조건마다 환경변수 묶음을 정의한다. 라벨에 쉼표를 넣지 않는다(CSV 열이 밀림).
run () {   # $1=라벨  나머지=VAR=VAL ...
  local LABEL="$1"; shift
  echo; echo "=============== $LABEL ==============="
  [ $# -gt 0 ] && printf '  env: %s\n' "$*"

  local LOG="/tmp/exp9_${LABEL}_$STAMP.log"
  local R SPIN=""

  R=$(env "$@" bash -c "
        . '$HERE/common.sh'
        measure_once '$LABEL' '$WIN' '$LOG'
      " | tee /dev/stderr | grep '^RESULT' || true)

  if [ -z "$R" ]; then
    echo "  -> 기록하지 않습니다 (측정 실패)."
    cleanup; return
  fi

  # 변수가 실제로 먹었는지 확인한다. 이게 없으면 '변화 없음' 을 잘못 읽는다.
  if [ "$VERIFY" = 1 ]; then
    local PID PROF="/tmp/exp9_prof_${LABEL}_$STAMP.txt"
    if PID=$(find_gz_pid); then
      echo "  프로파일 5초 (스핀이 실제로 줄었는지 확인)"
      if sample "$PID" 5 1 -f "$PROF" 2>/dev/null; then
        SPIN=$(python3 "$HERE/analyze_profile.py" "$PROF" 2>/dev/null \
               | grep -o '합계 [0-9]* ([0-9.]*% of busy)' \
               | grep -o '[0-9.]*% of busy' | grep -o '^[0-9.]*' || true)
        echo "  -> 스핀 ${SPIN:-?}% of busy   ($PROF)"
      fi
    fi
  fi

  echo "$LABEL,$(echo "$R" | cut -d, -f3,4,5,6),${SPIN:-}" >> "$OUT"
  cleanup
}

# 1) 기준선. 같은 세션에서 다시 잰다 — 다른 날 수치와 비교하지 않는다.
run baseline

# 2) CPU 병렬 라이브러리 축. OpenCV/OpenMP/TBB 중 무엇이 걸리는지는 모른다.
#    한꺼번에 눌러서 '이 축이 관련 있나' 부터 본다. 있으면 다음에 쪼갠다.
run cpu1 \
    OMP_NUM_THREADS=1 \
    OPENCV_FOR_THREADS_NUM=1 \
    TBB_NUM_THREADS=1

# 3) DDS 공유메모리 축. Fast DDS 의 shm 전송이 스핀하고 있었다.
run noshm FASTDDS_BUILTIN_TRANSPORTS=UDPv4

# 4) 둘 다.
run both \
    OMP_NUM_THREADS=1 \
    OPENCV_FOR_THREADS_NUM=1 \
    TBB_NUM_THREADS=1 \
    FASTDDS_BUILTIN_TRANSPORTS=UDPv4

echo; echo "===== 요약 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"

python3 - "$OUT" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
if len(rows) < 2:
    print("\n  측정이 2건 미만이라 판정할 수 없습니다."); raise SystemExit
base = next((r for r in rows if r['condition'] == 'baseline'), None)
if base is None:
    print("\n  기준선이 없습니다. 비교할 수 없습니다."); raise SystemExit
b = float(base['rtf'])
print(f"\n  기준선 RTF {b:.4f}")
print(f"  {'조건':<10} {'RTF':>8} {'배율':>7} {'스핀%':>7}")
for r in rows:
    v = float(r['rtf'])
    print(f"  {r['condition']:<10} {v:>8.4f} {v/b:>6.2f}x {r.get('spin_pct') or '-':>7}")
print("""
  읽는 법:
    RTF 가 올랐고 스핀% 도 내렸다   -> 오버서브스크립션 가설 지지. 강한 증거.
    RTF 그대로인데 스핀% 는 내렸다  -> 스핀은 증상이었다. 가설 폐기.
    RTF 도 스핀% 도 그대로          -> 환경변수가 안 먹었다. 기각하지 말 것.
                                       무엇이 TBB 풀을 소유하는지부터 찾아야 한다.
    RTF 가 내렸다                    -> 그 스레드들은 실제로 일하고 있었다.

  n=1 입니다. 차이가 10% 안쪽이면 반복 없이 결론내지 마세요.""")
PY
echo
echo "주의: 소나가 안 올라온 조건은 기록되지 않습니다 (ros_gz_sim create 행 —"
echo "      notes/results/spawn_hang_2026-08-05/ 참고). 4줄이 다 안 나왔으면"
echo "      빠진 조건을 '변화 없음' 으로 읽지 마세요."
