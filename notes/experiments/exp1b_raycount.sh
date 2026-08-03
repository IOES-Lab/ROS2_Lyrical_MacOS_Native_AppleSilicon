#!/usr/bin/env bash
# exp1b_raycount.sh — 레이 수를 줄여서 RTF 변화를 본다
#
# 이게 지금 남은 유일한 후보다 (2026-08-03 기준).
#   소나를 켜면 RTF 0.9996 -> ~0.22. 약 4.5배 비용이 실재하고 재현되는데
#   원인을 모른다. 지금까지 바꿔본 것 중 이 수치를 움직인 것이 하나도 없다.
#     장면 내용  무관 (빈 장면 0.19~0.22 vs 하이트맵+14개 0.2241)
#     월드       무관 (두 소나 월드가 같은 값)
#     사거리     무관 (10m 0.2186 / 3m 0.2507 / 1m 0.1933 — 단조성 없음)
#   즉 장면을 훑는 비용이 아니라 **프레임당 고정 비용**으로 보인다.
#   남은 축은 레이 수와, 출력 점 수다.
#
# 판정 근거:
#   센서는 513 x 301 레이를 쏘고, FillPointCloudMsg 가 153,600 점 전부를
#   렌더 스레드 콜백에서 순회한다.
#     레이 수에 거의 선형     -> 점당 고정 비용. FillPointCloudMsg 유력.
#     선형보다 급하게 반응    -> Render() 레이캐스트 쪽.
#     여기서도 변화 없음      -> 둘 다 아니다. 원점에서 다시 봐야 한다.
#
# 2026-08-03 재작성. 이전 판은 소나 대기 패턴에 '...for 513' 이 하드코딩돼
# 있어서, beams 를 줄인 구간에서 로그 숫자가 달라지자 300초 대기 후 측정을
# **조용히 건너뛰게** 돼 있었다. 4개 중 2개가 사라지는 버그였다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
OUT="/tmp/exp1b_raycount_$(date +%m%d_%H%M).csv"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF  (SDF=경로 로 지정하세요)"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; cleanup; echo "[정리] SDF 원복"' EXIT

echo "beams,rays,total_rays,rtf,sim_delta,real_delta,msgs" > "$OUT"
echo "SDF: $SDF"
echo "4개 조건 · 건당 4~6분 · 총 20분 이상 걸립니다."

run () {  # $1=beams  $2=rays
  local TOT=$(( $1 * $2 ))
  echo; echo "=============== beams=$1  rays=$2  ($TOT rays/frame) ==============="
  python3 - "$SDF" "$1" "$2" <<'PY'
import sys, re
p, b, r = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
s, nb = re.subn(r"<beams>\d+</beams>", f"<beams>{b}</beams>", s)
s, nr = re.subn(r"<rays>\d+</rays>",   f"<rays>{r}</rays>",   s)
assert nb == 1 and nr == 1, f"SDF 치환 실패: beams {nb}건, rays {nr}건"
open(p, "w").write(s)
print(f"  적용됨: beams={b} rays={r}")
PY

  local R
  R=$(measure_once "beams=$1,rays=$2" "$WIN" "/tmp/exp1b_${1}x${2}.log" | tee /dev/stderr \
      | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    echo "$1,$2,$TOT,$(echo "$R" | cut -d, -f3,4,5,6)" >> "$OUT"
  else
    echo "  -> 이 조건은 기록하지 않습니다 (측정 실패)."
  fi
  cleanup
}

run 512 300     # 기준 (153,600)
run 512 60      # 레이 1/5   (30,720)
run 128 60      # 빔도 1/4   (7,680)
run 64  15      # 최소       (960)

echo; echo "===== 요약 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"
echo; echo "저장: $OUT"

python3 - "$OUT" <<'PY'
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
if len(rows) < 2:
    print("\n  측정이 2건 미만이라 판정할 수 없습니다."); raise SystemExit
base = rows[0]
bt, br = int(base['total_rays']), float(base['rtf'])
print(f"\n  기준: {bt} rays -> RTF {br:.4f}")
print(f"  {'rays':>8} {'배율(rays)':>11} {'RTF':>8} {'배율(RTF)':>10}")
for r in rows:
    t, v = int(r['total_rays']), float(r['rtf'])
    print(f"  {t:>8} {bt/t:>10.1f}x {v:>8.4f} {v/br:>9.2f}x")
print("""
  읽는 법 — 대조군은 소나 없음 RTF 0.9996 입니다.
    레이를 1/160 로 줄였는데 RTF 가 0.9996 에 근접  -> 레이/점 수가 원인. 확정.
    줄여도 0.2 근처에 머무름                        -> 레이 수와 무관.
      그러면 센서를 켜는 것 자체의 고정 비용이고, 지금까지 바꿔본 모든 축이
      무관하다는 뜻이 됩니다. 코드를 직접 봐야 합니다.
    중간 어딘가                                     -> 기울기를 보고 판단.""")
PY
echo
echo "주의: 4줄이 다 안 나왔으면 비교하지 마세요. 실패한 측정은 기록되지 않습니다."
