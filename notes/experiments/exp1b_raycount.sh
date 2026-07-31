#!/usr/bin/env bash
# exp1b_raycount.sh — 레이 수를 줄여서 RTF 변화를 본다
# exp1(사거리)에서 변화가 없었다면 이걸 돌린다.
#   사거리 무관 + 레이 수에 비례  -> FillPointCloudMsg (153,600회 루프)가 병목
#   둘 다 반응                    -> Render() 레이캐스트가 병목
set -e
SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; echo "[정리] SDF 원복"' EXIT

run () {  # $1=beams  $2=rays
  python3 - "$SDF" "$1" "$2" <<'PY'
import sys, re
p, b, r = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p).read()
s = re.sub(r"<beams>\d+</beams>", f"<beams>{b}</beams>", s)
s = re.sub(r"<rays>\d+</rays>",   f"<rays>{r}</rays>",   s)
open(p, "w").write(s)
PY
  LOG="/tmp/exp1b_${1}x${2}.log"
  echo; echo "=============== beams=$1  rays=$2  (총 $(( $1 * $2 )) rays/frame) ==============="
  ros2 launch dave_demos dave_sensor.launch.py \
      namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
      x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
      > "$LOG" 2>&1 &
  LP=$!
  echo "  launch 완료. 소나 초기화 대기 (최대 300초)..."
  if ! bash "$HERE/wait_sonar.sh" "$LOG" 300; then
    echo "  ! 소나가 안 올라왔습니다. 이 측정 건너뜁니다."; cleanup 2>/dev/null || true; return
  fi
  bash "$HERE/rtf_probe.sh" /world/default/stats "$WIN" "beams=$1,rays=$2"
  kill -INT $LP 2>/dev/null || true; sleep 8
  pkill -f gz-sim-server 2>/dev/null || true
  pkill -f 'ros2 launch' 2>/dev/null || true
  sleep 5
}

run 512 300     # 기준 (153,600)
run 512 60      # 레이 1/5   (30,720)
run 128 60      # 빔도 1/4   (7,680)
run 64  15      # 최소       (960)

echo
echo "판정:"
echo "  레이 수에 거의 선형으로 RTF 상승 -> 점당 고정 비용. FillPointCloudMsg 유력."
echo "  선형보다 급하게 상승             -> Render() 레이캐스트 쪽."
echo "  거의 변화 없음                   -> 둘 다 아님. 다른 데를 봐야 함."
