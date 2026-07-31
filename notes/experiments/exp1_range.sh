#!/usr/bin/env bash
# exp1_range.sh — 소나 사거리를 줄여서 RTF가 달라지는지 본다
# 가설: 빈 장면에서 레이가 아무것도 안 맞고 10m를 끝까지 traverse하는 게 비용이다
#      -> 사거리를 줄이면 RTF가 크게 좋아져야 한다
set -e
SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF  (SDF=경로 로 지정하세요)"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; echo "[정리] SDF 원복"' EXIT

run () {   # $1 = max range
  sed -i".tmp" "s|<max>[0-9.]*</max>|<max>$1</max>|" "$SDF"
  echo; echo "=============== range = $1 m ==============="
  ros2 launch dave_demos dave_sensor.launch.py \
      namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
      x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
      > /tmp/exp1_range$1.log 2>&1 &
  LP=$!
  echo "  90초 안정화 대기..."; sleep 90
  bash "$HERE/rtf_probe.sh" /world/default/stats "$WIN" "range=$1"
  kill -INT $LP 2>/dev/null || true; sleep 8
  pkill -f gz-sim-server 2>/dev/null || true
  pkill -f 'ros2 launch' 2>/dev/null || true
  sleep 5
}

run 10.0    # 기준값 (현재 설정)
run 3.0     # 축소
run 1.0     # 더 축소

echo
echo "판정:"
echo "  RTF가 사거리에 따라 뚜렷이 올라감  -> 빈 공간 traverse 비용이 원인 (Render 쪽)"
echo "  RTF가 거의 그대로                   -> 사거리 무관. exp2 로 넘어갈 것"
