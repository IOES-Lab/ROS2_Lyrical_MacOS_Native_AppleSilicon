#!/usr/bin/env bash
# exp3_heightmap.sh — 빈 장면에 바닥(Sand Heightmap)을 넣으면 빨라지는지 본다
#
# 원래 가설: integrated 월드는 하이트맵이 있고 훨씬 빠르다. 레이가 금방
#           뭔가에 맞으니 싸고, 빈 장면은 10m 를 끝까지 훑어서 비싸다.
#
# 2026-08-03 경고 — 이 가설의 근거가 무너졌다.
#   "integrated 가 50~200배 빠르다"는 비교는 Docker 의 multibeam(~0.0018)과
#   Docker 의 integrated(~0.03)를 놓고 나온 것이다. 그런데 맥에서 보정된
#   방법으로 다시 재보니 multibeam 은 0.19~0.22 다. integrated 는 맥에서
#   보정된 방법으로 잰 적이 아직 없다.
#   즉 지금 남아있는 두 수치는 플랫폼이 서로 달라 비교 자체가 성립하지 않고,
#   맥 기준으로는 오히려 multibeam 쪽이 빠를 수도 있다.
#
#   따라서 이 실험은 exp4(맥에서 integrated 격리 측정) 를 먼저 돌린 뒤에
#   해석해야 한다. 지금 돌려도 숫자는 나오지만, 비교 대상이 없다.
#
# 그래도 단독으로 의미는 있다: "같은 맥, 같은 월드, 바닥만 추가" 이므로
# 하이트맵 유무의 효과를 그 자체로 잰다. 대조군은 0.19~0.22 (맥 빈 장면).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

W="${W:-$HOME/dave_ws/src/dave/models/dave_worlds/worlds/dave_multibeam_sonar.world}"
WIN="${WIN:-60}"

[ -f "$W" ] || { echo "월드 없음: $W  (W=경로 로 지정하세요)"; exit 1; }
cp "$W" "$W.bak"
trap 'cp "$W.bak" "$W"; cleanup; echo "[정리] 월드 원복"' EXIT

# </world> 바로 앞에 하이트맵 include 삽입
python3 - "$W" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
inc = """
    <include>
      <pose>0 0 -10 0 0 0</pose>
      <uri>https://fuel.gazebosim.org/1.0/hmoyen/models/Sand Heightmap</uri>
    </include>
"""
i = s.rfind("</world>")
open(p, "w").write(s[:i] + inc + s[i:])
print("  하이트맵 include 삽입 완료")
PY

echo
echo "Fuel 에서 하이트맵을 처음 받는 경우 시간이 더 걸립니다."
echo "고정 sleep 은 쓰지 않습니다 — 소나 로그를 폴링합니다 (최대 300초)."

R=$(measure_once "with-heightmap" "$WIN" /tmp/exp3_heightmap.log | tee /dev/stderr \
    | grep '^RESULT' || true)

echo
if [ -z "$R" ]; then
  echo "측정 실패. /tmp/exp3_heightmap.log 를 확인하세요."
  echo "  Fuel 다운로드가 300초를 넘겼을 수 있습니다. 한 번 더 돌리면"
  echo "  캐시가 남아 있어 빨라집니다."
  exit 1
fi

RTF=$(echo "$R" | cut -d, -f3)
echo "===== 결과 ====="
echo "  하이트맵 있음: RTF $RTF"
echo "  대조군(맥 빈 장면, 2026-08-03): RTF 0.19~0.22"
echo "  대조군(소나 없음, 2026-07-31): RTF 0.9996"
echo
echo "판정:"
echo "  0.19~0.22 보다 뚜렷이 높음 -> 빈 장면 traverse 가 비용. 가설 지지."
echo "  비슷하거나 더 낮음         -> 장면 내용은 무관. 센서 자체 비용."
echo
echo "주의: 이 한 줄로 integrated 월드와 비교하지 마세요. 그 수치는 Docker"
echo "      에서, 보정 전 방법으로 나온 것입니다. 맥 비교는 exp4 를 돌린 뒤에."
