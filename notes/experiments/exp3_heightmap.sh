#!/usr/bin/env bash
# exp3_heightmap.sh — 빈 장면에 바닥(Sand Heightmap)을 넣으면 빨라지는지 본다
# integrated 월드는 하이트맵이 있고 50~200배 빠르다. 그게 원인인지 확인한다.
set -e
W="${W:-$HOME/dave_ws/src/dave/models/dave_worlds/worlds/dave_multibeam_sonar.world}"
WIN="${WIN:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -f "$W" ] || { echo "월드 없음: $W  (W=경로 로 지정하세요)"; exit 1; }
cp "$W" "$W.bak"
trap 'cp "$W.bak" "$W"; echo "[정리] 월드 원복"' EXIT

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

ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
    x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
    > /tmp/exp3_heightmap.log 2>&1 &
LP=$!
echo "  하이트맵 Fuel 다운로드가 있어 120초 대기..."; sleep 120
bash "$HERE/rtf_probe.sh" /world/default/stats "$WIN" "with-heightmap"
kill -INT $LP 2>/dev/null || true; sleep 8
pkill -f gz-sim-server 2>/dev/null || true

echo
echo "판정:"
echo "  RTF가 integrated 수준(0.1~0.4)으로 상승 -> 빈 장면이 원인. 결론 확정."
echo "  변화 없음                                -> 장면 무관. 센서 자체 문제."
