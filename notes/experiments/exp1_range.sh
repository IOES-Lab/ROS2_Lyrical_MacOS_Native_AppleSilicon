#!/usr/bin/env bash
# exp1_range.sh — 소나 사거리를 줄여서 RTF가 달라지는지 본다
#
# 가설: 빈 장면에서 레이가 아무것도 안 맞고 10m를 끝까지 traverse 하는 게
#      비용이다 -> 사거리를 줄이면 RTF가 크게 좋아져야 한다.
#
# 무엇을 설명하려는 것인가: 맥에서 소나를 켜면 RTF 0.19~0.22, 끄면 0.9996.
# 약 4.5배 비용이 실재하는데 원인을 모른다. 사거리가 원인인지부터 가른다.
#
# 2026-08-03 재작성. 이전 판은 고정 `sleep 90` 으로 안정화를 기다렸는데,
# 소나 초기화가 145~175초 걸린다는 사실이 밝혀지면서 무효가 됐다. 90초
# 시점은 소나가 아직 없는 월드이고 RTF ~1.0 이 나오는데 겉보기엔 정상이다.
# 이전 판이 낸 "1m 0.824 / 3m 0.816" 은 그 상태에서 나온 값이라 신뢰할 수
# 없다. exp1c 헤더가 그 수치를 설계 전제로 인용하고 있으니 함께 재확인할 것.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
OUT="/tmp/exp1_range_$(date +%m%d_%H%M).csv"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF  (SDF=경로 로 지정하세요)"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; rm -f "$SDF".tmp; cleanup; echo "[정리] SDF 원복"' EXIT

echo "range_m,rtf,sim_delta,real_delta,msgs" > "$OUT"
echo "SDF: $SDF"
echo "측정창: ${WIN}초 · 사거리마다 소나 초기화를 기다리므로 건당 4~6분 걸립니다."

run () {   # $1 = max range
  echo; echo "=============== range = $1 m ==============="
  sed -i".tmp" "s|<max>[0-9.]*</max>|<max>$1</max>|" "$SDF"
  grep -o '<max>[0-9.]*</max>' "$SDF" | head -1 | sed 's/^/  적용됨: /'

  local R
  R=$(measure_once "range=$1" "$WIN" "/tmp/exp1_range_$1.log" | tee /dev/stderr \
      | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    echo "$1,$(echo "$R" | cut -d, -f3,4,5,6)" >> "$OUT"
  else
    echo "  -> 이 사거리는 기록하지 않습니다 (측정 실패)."
  fi
  cleanup
}

for r in 10.0 3.0 1.0; do run "$r"; done

echo; echo "===== 요약 ====="; column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"
echo; echo "저장: $OUT"
echo
echo "판정:"
echo "  사거리에 따라 RTF가 뚜렷이 오름  -> 빈 공간 traverse 비용이 원인 (Render 쪽)"
echo "  거의 그대로                       -> 사거리 무관. exp1b(레이 수)로 넘어갈 것"
echo
echo "주의: 3줄 다 안 나왔으면 비교하지 마세요. 실패한 측정은 기록되지 않습니다."
