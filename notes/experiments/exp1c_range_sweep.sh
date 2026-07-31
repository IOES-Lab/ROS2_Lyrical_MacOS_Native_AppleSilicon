#!/usr/bin/env bash
# exp1c_range_sweep.sh — 3m ~ 10m 구간을 촘촘히. 오염 방지 포함.
#
# exp1 결과: 1m 0.824 / 3m 0.816 / (10m 오염) · 소나 없음 0.9996
# -> 3m 이하에서는 거의 공짜. 3~10m 사이에서 무너진다. 그 지점을 찾는다.
set -e
SDF="${SDF:-$HOME/dave_ws/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf}"
WIN="${WIN:-60}"
HERE="$(cd "$(dirname "$0")" && pwd)"
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


  R=$(bash "$HERE/rtf_probe.sh" /world/default/stats "$WIN" "range=$1" | tee /dev/tty | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    echo "$1,$(echo "$R" | cut -d, -f3,4,5,6)" >> "$OUT"
  fi
  cleanup
}

for r in 10.0 8.0 6.0 5.0 4.0 3.0; do run "$r"; done

echo; echo "===== 요약 ====="; column -s, -t < "$OUT"
echo; echo "저장: $OUT"
echo "sim_delta 가 음수이거나 인스턴스 수가 1이 아닌 줄은 버리세요."
