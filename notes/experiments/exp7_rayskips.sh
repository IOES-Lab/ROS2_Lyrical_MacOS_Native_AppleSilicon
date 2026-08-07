#!/usr/bin/env bash
# exp7_rayskips.sh — 비용이 "레이캐스트"인지 "그 뒤 연산"인지 가른다
#
# 왜 이게 필요한가 (2026-08-05):
#   exp1b 에서 소나 비용의 약 90% 가 레이 수에 비례한다는 게 나왔다.
#   그런데 exp1b 는 <beams>/<rays> 를 바꿨고, 그건 세 가지를 한꺼번에 바꾼다.
#     (1) GPU 레이캐스트 해상도
#     (2) 소나 연산량 (backscatter/matmul/FFT)
#     (3) 출력 PointCloud2 점 수
#   그래서 "레이 수에 비례"까지만 알고, 셋 중 어디인지는 모른다.
#
# raySkips 가 이걸 가른다. SDF 구조상:
#     <ray><scan>  beams 512 / rays 300   <- 레이캐스트 해상도
#     <spec>       raySkips 10            <- 연산 단계에서만 솎아냄
#   raySkips 만 바꾸면 레이캐스트는 513x301 그대로이고 연산량만 달라진다.
#   플러그인이 실효 레이 수를 로그에 찍는다:
#     [sonar_wgpu] GPU #50 | 21.5 ms | 513 beams x 30 rays x 399 freq
#   rays=300, raySkips=10 -> 30. 이 값을 읽어서 파라미터가 실제로 먹었는지
#   확인하고, 분석에도 쓴다.
#
# 판정:
#   raySkips 를 올렸더니 RTF 가 뚜렷이 오름
#     -> 비용은 레이캐스트 뒤의 연산 단계에 있다. 최적화 지점이 거기다.
#   거의 안 변함
#     -> 비용은 레이캐스트 자체이거나 PointCloud2 채우기다. raySkips 가
#        건드리지 않는 두 곳 중 하나. 그다음은 코드를 읽어야 한다.
#
# raySkips=1 은 양성 대조군이다. 솎아내기를 끄면 30배 더 계산하므로 확실히
# 느려져야 한다. 여기서도 안 느려지면 이 파라미터가 아무 효과가 없다는 뜻이고,
# 그러면 위 판정 자체가 성립하지 않는다. 그래서 반드시 같이 잰다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
OUT="/tmp/exp7_rayskips_$(date +%m%d_%H%M).csv"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF  (SDF=경로 로 지정하세요)"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; cleanup; echo "[정리] SDF 원복"' EXIT

echo "rayskips,effective_rays,rtf,sim_delta,real_delta,msgs" > "$OUT"
echo "SDF: $SDF"
echo "beams/rays 는 기본값(512/300) 고정. raySkips 만 바꿉니다."
echo "5개 조건 · 건당 4~6분 · 총 25분 이상. raySkips=1 은 더 걸릴 수 있습니다."

run () {  # $1 = raySkips
  local LOG="/tmp/exp7_skip$1.log"
  echo; echo "=============== raySkips = $1 ==============="

  python3 - "$SDF" "$1" <<'PY'
import sys, re
p, k = sys.argv[1], sys.argv[2]
s = open(p).read()
# beams/rays 는 건드리지 않는다 — 기본값이어야 비교가 성립한다.
b = re.search(r"<beams>(\d+)</beams>", s)
r = re.search(r"<rays>(\d+)</rays>", s)
assert b and r, "beams/rays 를 못 찾음"
assert (b.group(1), r.group(1)) == ("512", "300"), \
    f"beams/rays 가 기본값이 아님: {b.group(1)}/{r.group(1)} — 다른 실험이 원복 안 하고 끝났을 수 있음"
s, n = re.subn(r"<raySkips>\d+</raySkips>", f"<raySkips>{k}</raySkips>", s)
assert n == 1, f"raySkips 치환 실패: {n}건"
open(p, "w").write(s)
print(f"  적용됨: raySkips={k}  (beams=512 rays=300 고정)")
PY

  local R
  R=$(measure_once "skip$1" "$WIN" "$LOG" | tee /dev/stderr | grep '^RESULT' || true)

  # 플러그인이 보고한 실효 레이 수를 읽는다. 파라미터가 실제로 먹었는지 확인.
  local EFF
  EFF=$(grep -o '[0-9]* beams × [0-9]* rays' "$LOG" 2>/dev/null | tail -1 \
        | grep -o '× [0-9]* rays' | grep -o '[0-9]*' || true)
  EFF="${EFF:-?}"
  echo "  플러그인 보고 실효 레이 수: $EFF"

  if [ -n "$R" ]; then
    echo "$1,$EFF,$(echo "$R" | cut -d, -f3,4,5,6)" >> "$OUT"
  else
    echo "  -> 이 조건은 기록하지 않습니다 (측정 실패)."
  fi
  cleanup
}

run 10     # 기본값
run 30
run 100
run 300
run 1      # 양성 대조군 — 솎아내기 없음. 확실히 느려져야 한다.

echo; echo "===== 요약 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"
echo; echo "저장: $OUT"

python3 - "$OUT" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
if len(rows) < 2:
    print("\n  측정이 2건 미만이라 판정할 수 없습니다."); raise SystemExit

base_rtf = 0.9996          # 소나 없음 (2026-07-31)
print(f"\n  {'raySkips':>9} {'실효레이':>8} {'RTF':>8} {'overhead':>9}")
data = []
for r in rows:
    k, eff, v = int(r['rayskips']), r['effective_rays'], float(r['rtf'])
    oh = 1/v - 1/base_rtf
    data.append((k, eff, v, oh))
    print(f"  {k:>9} {eff:>8} {v:>8.4f} {oh:>9.3f}")

d = {k: (eff, v, oh) for k, eff, v, oh in data}
print()
if 10 in d and 300 in d:
    o10, o300 = d[10][2], d[300][2]
    print(f"  raySkips 10 -> 300 (연산량 1/30): overhead {o10:.3f} -> {o300:.3f}"
          f"  ({(o10-o300)/o10*100:.0f}% 감소)")
if 1 in d and 10 in d:
    o1, o10 = d[1][2], d[10][2]
    print(f"  양성 대조군 raySkips 1 (솎아내기 없음): overhead {o10:.3f} -> {o1:.3f}"
          f"  ({(o1-o10)/o10*100:+.0f}%)")
    if o1 <= o10 * 1.2:
        print("    ! 1 로 낮춰도 안 느려졌습니다. raySkips 가 실효가 없다는 뜻이고,")
        print("      그러면 아래 판정은 성립하지 않습니다. 실효 레이 수 열을 확인하세요.")

print("""
  참고 — exp1b (beams/rays 를 바꾼 경우, 2026-08-05):
    153,600 rays  RTF 0.2180      30,720  0.5017
      7,680       0.6632             960  0.6835
    overhead = 0.345 + 2.111e-5 x N  (레이 수 비례가 기본 설정에서 90%)

  판정:
    raySkips 로도 비슷한 폭으로 움직임
      -> 비용은 레이캐스트 뒤 연산 단계. exp1b 의 '레이 수 비례'는 연산량 비례였다.
    raySkips 로는 거의 안 움직임 (양성 대조군은 반응함)
      -> 비용은 레이캐스트 자체이거나 PointCloud2 채우기.
         raySkips 가 안 건드리는 두 곳이고, 다음은 코드를 읽어야 한다.""")
PY
echo
echo "주의: 5줄이 다 안 나왔으면 비교하지 마세요. 실패한 측정은 기록되지 않습니다."
echo "      '실효레이' 열이 raySkips 에 따라 안 변하면 파라미터가 안 먹은 것입니다."
