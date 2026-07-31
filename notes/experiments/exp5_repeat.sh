#!/usr/bin/env bash
# exp5_repeat.sh — 같은 조건을 N회 반복해서 재현성을 본다
#
# 배경: dave_multibeam_sonar 가 같은 코드·같은 설정에서 세 번 다 다르게 나왔다.
#   2026-07-23 Mac    RTF 0.012~0.015 + 간헐적 4분 정지
#   2026-07-29 Docker RTF 0.0008~0.0077, 정지 없음
#   2026-07-31 Mac    RTF 0.2223, 정지 없음 (대조군 0.9996)
# 0.2223 이 재현되는지, 아니면 실행마다 편차가 큰 것인지 가른다.
set -e
N="${N:-3}"; WIN="${WIN:-120}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/tmp/exp5_repeat_$(date +%m%d_%H%M).csv"

cleanup () {
  pkill -f 'gz sim' 2>/dev/null || true; pkill -f gz-sim 2>/dev/null || true
  pkill -f 'ros2 launch' 2>/dev/null || true; pkill -f parameter_bridge 2>/dev/null || true
  sleep 6
}
trap 'cleanup; echo "[정리] 완료"' EXIT

echo "run,rtf,sim_delta,real_delta,msgs,sonar_wait_s" > "$OUT"

for i in $(seq 1 "$N"); do
  echo; echo "=============== 반복 $i / $N ==============="
  cleanup
  if pgrep -f 'gz-sim|gz sim' >/dev/null 2>&1; then
    echo "  ! 이전 gz-sim 이 안 죽었습니다. 중단."; exit 1
  fi

  LOG="/tmp/exp5_run$i.log"
  T0=$(date +%s)
  ros2 launch dave_demos dave_sensor.launch.py \
      namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
      x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
      > "$LOG" 2>&1 &

  echo "  소나 초기화 대기 (최대 300초)..."
  if ! bash "$HERE/wait_sonar.sh" "$LOG" 300; then
    echo "  ! 소나 미확인 — 이 회차 건너뜀"; continue
  fi
  WAIT=$(( $(date +%s) - T0 ))
  echo "  소나까지 ${WAIT}초"

  R=$(bash "$HERE/rtf_probe.sh" /world/default/stats "$WIN" "run$i" | tee /dev/tty | grep '^RESULT' || true)
  [ -n "$R" ] && echo "$i,$(echo "$R" | cut -d, -f3,4,5,6),$WAIT" >> "$OUT"
  cleanup
done

echo; echo "===== 결과 ====="; column -s, -t < "$OUT"
python3 - "$OUT" <<'PY'
import csv,sys,statistics as st
rows=[r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
v=[float(r['rtf']) for r in rows]
if len(v)>=2:
    print(f"\n  평균 {st.mean(v):.4f} · 최소 {min(v):.4f} · 최대 {max(v):.4f} · 최대/최소 {max(v)/min(v):.1f}배")
    print("  판정: 배수 2 미만 -> 재현됨. 5 이상 -> 실행마다 편차 큼(그 자체가 발견).")
PY
