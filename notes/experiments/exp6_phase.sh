#!/usr/bin/env bash
# exp6_phase.sh — launch 직후부터 정상 상태까지 RTF 곡선을 찍는다
#
# 왜: 2026-07-23 에 RTF 0.012~0.015 + 4분 정지가 관측됐는데, 이후 반복 측정
#     에서는 0.187~0.222 로 안정적이고 정지가 없었다. 고정 settle 로 한 점만
#     재면 어느 쪽이 맞는지 알 수 없으므로, launch 부터 연속으로 훑는다.
#
# 2026-08-03 맥 결과: 기동 구간(t~54-106s)에 /stats 가 25초당 2건 미만으로
#     떨어지는 구간이 실재했고, 정상 상태는 t>=160s 에서 0.187~0.222 로 평탄.
#     즉 그날의 "정지"는 기동 구간이었다.
#
# 이 스크립트는 맥과 Docker 에서 같은 방법으로 돌아가야 한다. 그래야 두
# 플랫폼 수치를 비교할 수 있다. 그래서 토픽명을 하드코딩하지 않는다.
#
# 환경변수:
#   SLICE=25    한 구간 측정 길이(초)
#   TOTAL=360   총 관측 시간(초). Docker 는 훨씬 느리므로 900 이상 권장.
#   TOPIC=auto  stats 토픽. auto 면 gz topic -l 에서 찾는다.
#   TAG=""      출력 파일명에 붙일 라벨 (예: TAG=docker)
#
# 출력: /tmp/exp6_phase_<TAG>_<날짜시각>.csv
set -e
SLICE="${SLICE:-25}"
TOTAL="${TOTAL:-360}"
TOPIC="${TOPIC:-auto}"
TAG="${TAG:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/tmp/exp6_phase${TAG:+_$TAG}_$(date +%m%d_%H%M).csv"
LOG=/tmp/exp6_phase.log

cleanup () {
  pkill -f 'gz sim' 2>/dev/null || true; pkill -f gz-sim 2>/dev/null || true
  pkill -f 'ros2 launch' 2>/dev/null || true; pkill -f parameter_bridge 2>/dev/null || true
  sleep 6
}
trap 'cleanup; echo "[정리] 완료"' EXIT

cleanup
pgrep -f 'gz-sim|gz sim' >/dev/null 2>&1 && { echo "이전 gz-sim 이 살아있습니다. 중단."; exit 1; }

echo "elapsed_s,rtf,sim_delta,real_delta,msgs,sonar_up,topic" > "$OUT"
T0=$(date +%s)
ros2 launch dave_demos dave_sensor.launch.py \
    namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
    x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
    > "$LOG" 2>&1 &

echo "관측 시작 — ${SLICE}초 구간을 ${TOTAL}초까지 연속 측정"
[ "$TOPIC" = auto ] && echo "[topic] 매 구간 자동 탐색 (플랫폼마다 월드 내부 이름이 다르다)" \
                    || echo "[topic] 지정됨: $TOPIC"
echo

RESOLVED=""
[ "$TOPIC" != auto ] && RESOLVED="$TOPIC"

while :; do
  EL=$(( $(date +%s) - T0 ))
  [ "$EL" -ge "$TOTAL" ] && break

  UP=0; grep -q 'Persistent GPU buffers allocated for 513' "$LOG" 2>/dev/null && UP=1

  # 토픽을 아직 못 찾았으면 이번 구간에 한 번만 시도한다 (블로킹하지 않는다).
  # 여기서 기다려버리면 우리가 보려는 기동 구간을 통째로 놓친다.
  if [ -z "$RESOLVED" ]; then
    RESOLVED=$(gz topic -l 2>/dev/null | grep -E '^/world/[^/]+/stats$' | head -1) || true
    [ -n "$RESOLVED" ] && printf '  t=%3ds  [topic] %s\n' "$EL" "$RESOLVED"
  fi

  if [ -z "$RESOLVED" ]; then
    # 토픽 자체가 아직 없다 = 월드가 아직 안 올라왔다.
    # "토픽은 있는데 조용하다"와 반드시 구분해서 기록한다. 2026-07-29 에
    # 이 둘을 못 가려서 엉뚱한 결론으로 갈 뻔했다.
    printf '  t=%3ds  (토픽 없음 — 월드 미기동)\n' "$EL"
    echo "$EL,,,,,$UP," >> "$OUT"
    sleep "$SLICE"
    continue
  fi

  R=$(bash "$HERE/rtf_probe.sh" "$RESOLVED" "$SLICE" "t=${EL}s" 2>/dev/null | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    RTF=$(echo "$R" | cut -d, -f3)
    printf '  t=%3ds  RTF %-9s  소나 %s\n' "$EL" "$RTF" "$([ $UP -eq 1 ] && echo 켜짐 || echo 아직)"
    echo "$EL,$(echo "$R" | cut -d, -f3,4,5,6),$UP,$RESOLVED" >> "$OUT"
  else
    # 토픽은 있는데 25초 안에 메시지가 2건 미만 = 발행 멈춤
    printf '  t=%3ds  (토픽 있음 / 샘플 없음 — 발행 멈춤)\n' "$EL"
    echo "$EL,,,,,$UP,$RESOLVED" >> "$OUT"
  fi
done

echo; echo "===== 곡선 ====="
python3 - "$OUT" <<'PY'
import csv,sys
rd=csv.DictReader(open(sys.argv[1]))
rows=list(rd)
# 'topic' 열은 2026-08-03 이후에만 있다. 그 이전 CSV 에서 빈 rtf 는
# "토픽 없음"이 아니라 "발행 멈춤"이었다(토픽명이 하드코딩돼 있었으므로).
# 열이 없으면 분류하지 않는다 — 없는 근거로 단정하면 결론이 뒤집힌다.
HAS_TOPIC = 'topic' in (rd.fieldnames or [])
print(f"  {'t(s)':>6} {'RTF':>9}  소나  그래프")
lo=None
for r in rows:
    if not r['rtf']:
        why = ("토픽없음" if not r.get('topic') else "발행멈춤") if HAS_TOPIC else "샘플없음"
        print(f"  {r['elapsed_s']:>6} {'-':>9}   {r['sonar_up']}   ({why})")
        continue
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
blank=[r for r in rows if not r['rtf']]
if HAS_TOPIC:
    nt=[r for r in blank if not r.get('topic')]
    ns=[r for r in blank if r.get('topic')]
    if nt: print(f"  토픽 없음  {len(nt)}구간 (월드 미기동)")
    if ns: print(f"  발행 멈춤  {len(ns)}구간 (토픽은 존재)")
elif blank:
    print(f"  샘플 없음  {len(blank)}구간 (구버전 CSV — 토픽 유무 미기록,")
    print( "             둘을 구분할 수 없다. 새로 측정하면 구분된다)")
print()
print("  읽는 법:")
print("   - 앞구간에만 저(低)RTF/무샘플이 있고 뒤가 평탄하면 -> 기동 구간 (맥 2026-08-03 패턴)")
print("   - 소나가 올라온 뒤에도 계속 낮으면 -> 정상 상태 자체가 느린 것 (기동 문제 아님)")
print("   - iterations 가 안 늘면 진짜 정지. rtf_probe 가 그때 경고를 찍는다.")
PY
echo "저장: $OUT"
