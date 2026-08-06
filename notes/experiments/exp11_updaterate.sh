#!/usr/bin/env bash
# exp11_updaterate.sh — 소나 <update_rate> 를 낮춰서 RTF 변화를 본다
#
# 왜 이걸 하는가 (2026-08-06):
#   오늘 두 번의 개입이 모두 실패했고, 그중 하나는 역효과였다.
#     cv::setNumThreads(1)   -0.5147 -> 0.5054   변화 없음
#     시각화 생략            -0.5147 -> 0.3012   40% 악화
#   후자의 이유가 프레임 카운터로 확인됐다:
#     baseline  GPU #550     noimg  GPU #1300
#   시각화를 걷어내니 compute 스레드가 프레임을 2.4배 더 처리했고, 그만큼
#   시뮬레이션이 쓸 CPU 를 더 가져갔다. **가볍게 만들면 더 자주 돈다.**
#   exp7 에서 raySkips=1 로 연산을 늘렸을 때 +73% 가 나온 것과 같은 축이다.
#
#   그러면 손잡이는 '속도' 가 아니라 '빈도' 다.
#
# 지금 상태:
#   SDF 는 <update_rate>30.0</update_rate> 인데 실측은 ~2.8 fps 다(550프레임
#   / 소나 가동 약 200초). 즉 센서가 30Hz 를 전혀 못 따라가고 있고,
#   update_rate 가 상한으로 기능하지 못한다. 실제로 도달 가능한 값보다
#   훨씬 높게 잡혀 있어서 사실상 "가능한 한 빨리" 와 같다.
#   참고로 BlueView P900 실물은 최대 ~15Hz 다. 30 은 물리적으로도 과하다.
#
# 판정 (돌리기 전에 못박는다):
#   rate 를 낮출수록 RTF 상승 + 프레임 수 감소
#       -> update_rate 가 실제 손잡이다. 코드 수정 없이 쓸 수 있는 권고안이 된다.
#   RTF 도 프레임 수도 그대로
#       -> gz-sensors 가 이 커스텀 센서에 update_rate 를 적용하지 않는 것이다.
#          그 자체가 업스트림 보고감이다 (SDF 값이 무시되고 있다는 뜻).
#   프레임 수만 줄고 RTF 는 그대로
#       -> 소나는 임계경로가 아니다. 비용은 다른 데 있다.
#
# 주의: 이 실험은 SDF 를 수정하고 trap 으로 원복한다. 중간에 kill -9 하면
#       .bak 이 남는다. 2026-08-05 에 실제로 남아 있었다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

WS=$(find_ws) || { echo "dave 워크스페이스를 못 찾음"; exit 1; }
SDF="${SDF:-$WS/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
N="${N:-1}"                       # 조건당 반복 횟수
RATES="${RATES:-30 10 5 2}"       # 훑을 rate 목록
OUT="${OUT:-/tmp/exp11_updaterate_$(date +%m%d_%H%M).csv}"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; rm -f "$SDF.bak"; cleanup; echo "[정리] SDF 원복"' EXIT

echo "rate_hz,rep,rtf,sim_delta,real_delta,msgs,frames" > "$OUT"
echo "SDF: $SDF"
NTOT=0; for r in $RATES; do for k in $(seq 1 "$N"); do NTOT=$((NTOT+1)); done; done
echo "조건 [$RATES] × ${N}회 = ${NTOT}건 · 건당 5~8분"
echo "저장: $OUT"

run () {   # $1 = update_rate (Hz)  $2 = 반복 번호
  echo; echo "=============== update_rate = $1 Hz  (반복 $2/$N) ==============="

  # 소나 센서의 update_rate 만 바꾼다. camera/depth_camera 것도 같은 태그라
  # 위치로 구분해야 한다 — multibeam_sonar 센서 블록 안의 것만 교체한다.
  python3 - "$SDF" "$1" <<'PY'
import sys, re
p, rate = sys.argv[1], sys.argv[2]
s = open(p).read()
i = s.find('name="multibeam_sonar"')
if i < 0:
    sys.exit("SDF 에서 multibeam_sonar 센서 블록을 못 찾음")
head, tail = s[:i], s[i:]
tail, n = re.subn(r"<update_rate>[^<]*</update_rate>",
                  f"<update_rate>{rate}</update_rate>", tail, count=1)
if n != 1:
    sys.exit("multibeam_sonar 블록 안에서 update_rate 를 못 바꿈")
open(p, "w").write(head + tail)
print(f"  적용됨: update_rate={rate}")
PY

  local LOG="/tmp/exp11_rate$1_r$2.log" R FRAMES
  R=$(measure_once "rate$1r$2" "$WIN" "$LOG" | tee /dev/stderr | grep '^RESULT' || true)

  # 프레임 수를 같이 기록한다. RTF 가 안 변해도 프레임이 줄었으면
  # 'update_rate 는 먹었는데 소나가 임계경로가 아니다' 로 읽어야 한다.
  # 단 플러그인은 50프레임마다 한 줄만 찍으므로 해상도가 50이다. 그리고
  # 이 값은 프로브 창이 아니라 실행 전체 구간의 것이다. 정밀 비교 금지.
  FRAMES=$(grep -o 'GPU #[0-9]*' "$LOG" 2>/dev/null | tail -1 | tr -dc '0-9')

  if [ -n "$R" ]; then
    echo "$1,$2,$(echo "$R" | cut -d, -f3,4,5,6),${FRAMES:-}" >> "$OUT"
    echo "  마지막 프레임 번호: ${FRAMES:-?}"
  else
    echo "  -> 기록하지 않습니다 (측정 실패). 마지막 프레임 ${FRAMES:-?}"
  fi
  cleanup
}

for RATE in $RATES; do
  for REP in $(seq 1 "$N"); do
    run "$RATE" "$REP"
  done
done

echo; echo "===== 요약 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"

python3 - "$OUT" <<'PY'
import csv, sys, statistics as st
from collections import defaultdict

rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
if len(rows) < 2:
    print("\n  측정이 2건 미만이라 판정할 수 없습니다."); raise SystemExit

CONTROL = 0.9974          # exp2, 같은 날 같은 조건, n=3
by = defaultdict(list)
for r in rows:
    by[float(r['rate_hz'])].append(float(r['rtf']))

rates = sorted(by, reverse=True)
base = by.get(30.0)
b = st.mean(base) if base else st.mean(by[rates[0]])

print(f"\n  {'Hz':>5} {'n':>2} {'평균RTF':>9} {'폭%':>6} {'배율':>7} {'남은비용':>9} {'감소':>6}")
ob = 1/b - 1/CONTROL
for hz in rates:
    v = by[hz]; m = st.mean(v)
    spread = (max(v)-min(v))/m*100 if len(v) > 1 else float('nan')
    o = 1/m - 1/CONTROL
    sp = f"{spread:5.1f}" if len(v) > 1 else "    -"
    print(f"  {hz:>5.0f} {len(v):>2} {m:>9.4f} {sp:>6} {m/b:>6.2f}x {o:>9.3f} {(ob-o)/ob*100:>5.0f}%")

print(f"""
  대조군(소나 없음) = {CONTROL} (exp2, n=3, 폭 0.2%)
  남은비용 = 1/RTF - 1/대조군

  판정 폭: 기준선 반복에서 5% 였습니다. 위 '폭%' 가 그보다 크게 나오면
  그 조건은 반복을 더 해야 합니다.""")

if any(len(v) < 2 for v in by.values()):
    print("  주의: n=1 인 조건이 있습니다. 그 값은 확정으로 쓰지 마세요.")
PY
