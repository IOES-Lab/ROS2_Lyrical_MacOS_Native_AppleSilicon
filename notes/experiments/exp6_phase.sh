#!/usr/bin/env bash
# exp6_phase.sh — launch 직후부터 정상 상태까지 RTF 곡선을 찍는다
#
# 왜: 2026-07-23 맥에서 RTF 0.012~0.015 + 4분 정지가 관측됐는데
#     2026-07-31 4회 반복에서는 0.187~0.222 로 안정적이고 정지가 없다.
#     "초기화 구간을 쟀기 때문"이라는 설명은 이미 반증됨 — 어제 90~150초
#     구간 6회 측정이 전부 0.999(소나 미탑재)였다.
#     그러니 오늘 맥에 느린 구간이 아예 없는지를 곡선으로 확인한다.
#
# 출력: elapsed(초) 대 RTF. 소나가 올라온 시점을 표시.
set -e
SLICE="${SLICE:-25}"     # 한 구간 측정 길이
TOTAL="${TOTAL:-360}"    # 총 관측 시간
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/tmp/exp6_phase_$(date +%m%d_%H%M).csv"
LOG=/tmp/exp6_phase.log

cleanup () {
  pkill -f 'gz sim' 2>/dev/null || true; pkill -f gz-sim 2>/dev/null || true
  pkill -f 'ros2 launch' 2>/dev/null || true; pkill -f parameter_bridge 2>/dev/null || true
  sleep 6
}
trap 'cleanup; echo "[정리] 완료"' EXIT

cleanup
pgrep -f 'gz-sim|gz sim' >/dev/null 2>&1 && { echo "이전 gz-sim 이 살아있습니다. 중단."; exit 1; }

echo "elapsed_s,rtf,sim_delta,real_delta,msgs,sonar_up" > "$OUT"
T0=$(date +%s)
ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
    x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
    > "$LOG" 2>&1 &

echo "관측 시작 — ${SLICE}초 구간을 ${TOTAL}초까지 연속 측정"
while :; do
  EL=$(( $(date +%s) - T0 ))
  [ "$EL" -ge "$TOTAL" ] && break
  UP=0; grep -q 'Persistent GPU buffers allocated for 513' "$LOG" 2>/dev/null && UP=1
  R=$(bash "$HERE/rtf_probe.sh" /world/default/stats "$SLICE" "t=${EL}s" 2>/dev/null | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    RTF=$(echo "$R" | cut -d, -f3)
    printf '  t=%3ds  RTF %-9s  소나 %s\n' "$EL" "$RTF" "$([ $UP -eq 1 ] && echo 켜짐 || echo 아직)"
    echo "$EL,$(echo "$R" | cut -d, -f3,4,5,6),$UP" >> "$OUT"
  else
    printf '  t=%3ds  (샘플 없음)\n' "$EL"
    echo "$EL,,,,,$UP" >> "$OUT"
  fi
done

echo; echo "===== 곡선 ====="
python3 - "$OUT" <<'PY'
import csv,sys
rows=[r for r in csv.DictReader(open(sys.argv[1]))]
print(f"  {'t(s)':>6} {'RTF':>9}  소나  그래프")
lo=None
for r in rows:
    if not r['rtf']: print(f"  {r['elapsed_s']:>6} {'-':>9}   {r['sonar_up']}"); continue
    v=float(r['rtf']); bar='#'*max(1,int(v*40))
    print(f"  {r['elapsed_s']:>6} {v:>9.4f}   {r['sonar_up']}   {bar}")
    if r['sonar_up']=='1' and lo is None: lo=v
vals=[float(r['rtf']) for r in rows if r['rtf']]
on=[float(r['rtf']) for r in rows if r['rtf'] and r['sonar_up']=='1']
off=[float(r['rtf']) for r in rows if r['rtf'] and r['sonar_up']=='0']
print()
if off: print(f"  소나 전  n={len(off)}  평균 {sum(off)/len(off):.4f}  최소 {min(off):.4f}")
if on:  print(f"  소나 후  n={len(on)}  평균 {sum(on)/len(on):.4f}  최소 {min(on):.4f}")
if vals: print(f"  전체 최소 {min(vals):.4f}")
print()
print("  판정: 전 구간 최소가 0.15 이상 -> 오늘 맥에는 느린 구간이 없다.")
print("        중간에 0.01 대로 떨어지는 구간이 있다 -> 7/23 관측의 정체가 그것.")
PY
echo "저장: $OUT"
