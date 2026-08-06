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
OUT="/tmp/exp11_updaterate_$(date +%m%d_%H%M).csv"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; rm -f "$SDF.bak"; cleanup; echo "[정리] SDF 원복"' EXIT

echo "rate_hz,rtf,sim_delta,real_delta,msgs,frames" > "$OUT"
echo "SDF: $SDF"
echo "4개 조건 · 건당 5~8분 · 총 25분 이상"
echo "저장: $OUT"

run () {   # $1 = update_rate (Hz)
  echo; echo "=============== update_rate = $1 Hz ==============="

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

  local LOG="/tmp/exp11_rate$1.log" R FRAMES
  R=$(measure_once "rate$1" "$WIN" "$LOG" | tee /dev/stderr | grep '^RESULT' || true)

  # 프레임 수를 같이 기록한다. RTF 가 안 변해도 프레임이 줄었으면
  # 'update_rate 는 먹었는데 소나가 임계경로가 아니다' 로 읽어야 한다.
  FRAMES=$(grep -o 'GPU #[0-9]*' "$LOG" 2>/dev/null | tail -1 | tr -dc '0-9')

  if [ -n "$R" ]; then
    echo "$1,$(echo "$R" | cut -d, -f3,4,5,6),${FRAMES:-}" >> "$OUT"
    echo "  마지막 프레임 번호: ${FRAMES:-?}"
  else
    echo "  -> 기록하지 않습니다 (측정 실패). 마지막 프레임 ${FRAMES:-?}"
  fi
  cleanup
}

run 30    # 현재 SDF 값 = 대조군
run 10
run 5
run 2

echo; echo "===== 요약 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"

python3 - "$OUT" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
if len(rows) < 2:
    print("\n  측정이 2건 미만이라 판정할 수 없습니다."); raise SystemExit
base = next((r for r in rows if r['rate_hz'] == '30'), rows[0])
b, bf = float(base['rtf']), (int(base['frames']) if base['frames'] else 0)
print(f"\n  기준 {base['rate_hz']}Hz -> RTF {b:.4f}, 프레임 {bf or '?'}")
print(f"  {'Hz':>5} {'RTF':>8} {'배율':>7} {'프레임':>8} {'프레임비':>9}")
for r in rows:
    v = float(r['rtf']); f = int(r['frames']) if r['frames'] else 0
    fr = f"{f/bf:.2f}x" if (bf and f) else "?"
    print(f"  {r['rate_hz']:>5} {v:>8.4f} {v/b:>6.2f}x {f or '?':>8} {fr:>9}")
print("""
  대조군(소나 없음) = 0.9974 · 소나 있음 기준선 = 0.5147 · 판정 폭 5%

  읽는 법:
    RTF 상승 + 프레임 감소  -> update_rate 가 손잡이. 권고안 성립.
    둘 다 그대로            -> update_rate 가 무시되고 있다. 그것도 보고감.
    프레임만 감소           -> 소나는 임계경로가 아니다.

  n=1 입니다. baseline 폭이 5% 였으므로 그보다 작은 차이는 읽지 마세요.""")
PY
