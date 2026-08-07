#!/usr/bin/env bash
# exp1c_range_sweep.sh — 3m ~ 10m 구간을 촘촘히. 오염 방지 포함.
#
# 2026-08-03 정정 — 이 스크립트의 원래 전제가 무효다.
#   이전 헤더는 "exp1 결과 1m 0.824 / 3m 0.816 이므로 3m 이하는 거의 공짜,
#   3~10m 사이에서 무너진다"고 적혀 있었다. 그런데 그 exp1 은 고정
#   `sleep 90` 으로 측정했고, 소나 초기화가 145~175초 걸린다는 사실이
#   나중에 밝혀졌다. 90초 시점은 소나가 아직 없는 월드다.
#   따라서 0.824 / 0.816 이 무엇을 잰 값인지 알 수 없다.
#
#   exp1_range.sh 는 2026-08-03 에 고쳤다. **이 스윕을 돌리기 전에
#   exp1(go.sh 1)을 먼저 다시 돌려서 전제를 세우는 것을 권한다.**
#   그래야 어느 구간을 촘촘히 볼지 정할 수 있다.
#
# 확정된 대조군 (맥, 보정된 방법):
#   소나 없음        RTF 0.9996  (2026-07-31)
#   소나 있음 10m    RTF 0.19~0.22 (2026-07-31 4회 + 2026-08-03 8구간)
set -e
SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"
OUT="/tmp/exp1c_$(date +%H%M%S).csv"

[ -f "$SDF" ] || { echo "SDF 없음: $SDF"; exit 1; }
cp "$SDF" "$SDF.bak"
trap 'cp "$SDF.bak" "$SDF"; cleanup; echo "[정리] SDF 원복"' EXIT

cleanup () {
  pkill -f 'gz sim' 2>/dev/null || true
  pkill -f gz-sim-server 2>/dev/null || true
  pkill -f gz-sim-gui 2>/dev/null || true
  pkill -f 'ros2 launch' 2>/dev/null || true
  pkill -f parameter_bridge 2>/dev/null || true
  sleep 6
}

echo "range_m,rtf,sim_delta,real_delta,msgs" > "$OUT"

run () {  # $1 = max range
  echo; echo "=============== range = $1 m ==============="
  cleanup
  # 살아있는 잔여 프로세스가 있으면 중단 — 오염된 수치를 만들지 않는다
  if pgrep -f 'gz-sim-server|gz sim' >/dev/null 2>&1; then
    echo "  ! 이전 gz-sim이 안 죽었습니다. 수동 정리 후 다시 돌리세요."; exit 1
  fi

  LOG="/tmp/exp1c_r$1.log"
  sed -i".tmp" "s|<max>[0-9.]*</max>|<max>$1</max>|" "$SDF"
  ros2 launch dave_demos dave_sensor.launch.py \
      namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
      x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
      > "$LOG" 2>&1 &
  echo "  launch 완료. 소나 초기화 대기 (최대 300초)..."
  if ! bash "$HERE/wait_sonar.sh" "$LOG" 300; then
    echo "  ! 소나가 안 올라왔습니다. 이 측정 건너뜁니다."; cleanup 2>/dev/null || true; return
  fi


  R=$(bash "$HERE/rtf_probe.sh" "$(bash "$HERE/stats_topic.sh" 60)" "$WIN" "range=$1" | tee /dev/stderr | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    echo "$1,$(echo "$R" | cut -d, -f3,4,5,6)" >> "$OUT"
  fi
  cleanup
}

for r in 10.0 8.0 6.0 5.0 4.0 3.0; do run "$r"; done

echo; echo "===== 요약 ====="; column -s, -t < "$OUT"
echo; echo "저장: $OUT"
echo "sim_delta 가 음수이거나 인스턴스 수가 1이 아닌 줄은 버리세요."
