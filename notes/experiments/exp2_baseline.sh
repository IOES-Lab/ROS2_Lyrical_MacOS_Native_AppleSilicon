#!/usr/bin/env bash
# exp2_baseline.sh — 소나 없이 같은 월드만 띄워서 대조군 RTF 를 잡는다
# 이게 있어야 "소나가 원인이다"를 수치로 말할 수 있다.
#
# 2026-08-06 전면 재작성. 이 조사 전체가 딛고 선 대조군 0.9996 은 이 스크립트의
# 옛 판에서 나왔는데, 거기엔 다른 데서 이미 다 고친 결함이 그대로 있었다:
#   - 고정 sleep 60 으로 안정화 판정 (2026-08-03 에 무효로 결론난 방식)
#   - wait_until_stepping 없음 — 스텝이 도는지 확인하지 않음
#   - 측정 전 정리·잔여 프로세스 확인 없음 (2026-07-31 오염 전력)
#   - Fast DDS 공유메모리 회피 없음
#   - n=1
# 소나 없는 월드라 60초면 대체로 충분했을 것이고 ~1.0 도 그럴듯하지만,
# 그 '그럴듯함' 은 검증이 아니다. 같은 프로토콜로 다시 잰다.
#
# 2026-08-06 에 다시 재는 진짜 이유:
#   FASTDDS_BUILTIN_TRANSPORTS=UDPv4 가 기본이 되면서 DDS 전송이 통째로
#   바뀌었다. 소나 있는 기준선은 0.515 로 새로 잡았는데(baseline_udp_2026-08-06),
#   **분모가 없다.** 대조군이 0.99 인지 0.85 인지에 따라 "소나 비용" 의 크기가
#   전혀 달라지고, 이 조사의 서술 대부분이 그 숫자 위에 서 있다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

N="${N:-3}"
WIN="${WIN:-60}"
WORLD="${WORLD:-dave_multibeam_sonar}"
OUT="${OUT:-/tmp/exp2_nosonar_$(date +%m%d_%H%M).csv}"

trap 'cleanup; echo "[정리] 완료"' EXIT

echo "run,rtf,sim_delta,real_delta,msgs" > "$OUT"
echo "소나 없이 '$WORLD' · ${N}회 · 건당 3~5분"
echo "저장: $OUT"

# 소나 없는 월드는 dave_world.launch.py 로 띄운다 (센서를 스폰하지 않는다).
# common.sh 의 launch_sonar_world 는 dave_sensor.launch.py 라 여기 못 쓴다.
launch_nosonar () {
  local LOG="${1:?로그 경로 필요}"
  ros2 launch dave_demos dave_world.launch.py \
      world_name:="$WORLD" gui:=true headless:=true \
      > "$LOG" 2>&1 &
  LAUNCH_PID=$!
}

for i in $(seq 1 "$N"); do
  echo; echo "=============== 반복 $i / $N ==============="
  LOG="/tmp/exp2_nosonar_run$i.log"

  preflight || exit 1
  cleanup
  assert_clean || exit 2

  launch_nosonar "$LOG"
  echo "  launch 완료 (로그 $LOG)"
  if ! assert_launch_alive "$LOG"; then cleanup; continue; fi

  # 소나가 없으므로 settle_for_sonar 는 쓰지 않는다. 대신 스텝 판정만 한다 —
  # 그게 어차피 유일하게 믿을 수 있는 기준이다.
  TOPIC=$(resolve_topic 60) || { echo "  ! stats 토픽 없음"; cleanup; continue; }
  echo "  topic = $TOPIC"

  if ! wait_until_stepping "$TOPIC" "${STEP_MAX:-300}" "${STEP_MIN:-60}"; then
    echo "  -> 이 회차는 기록하지 않습니다 (스텝 미확인)."
    cleanup; continue
  fi

  R=$(bash "$HERE/rtf_probe.sh" "$TOPIC" "$WIN" "nosonar$i" | tee /dev/stderr \
      | grep '^RESULT' || true)
  if [ -n "$R" ]; then
    echo "$i,$(echo "$R" | cut -d, -f3,4,5,6)" >> "$OUT"
  else
    echo "  -> 이 회차는 기록하지 않습니다 (측정 실패)."
  fi
  cleanup
done

echo; echo "===== 결과 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"

python3 - "$OUT" "$N" <<'PY'
import csv, sys, statistics as st
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r['rtf']]
v = [float(r['rtf']) for r in rows]
n_planned = int(sys.argv[2])

if len(v) < n_planned:
    print(f"\n  주의: {n_planned}회 중 {len(v)}회만 측정됐습니다.")
if not v:
    print("\n  측정된 회차가 없습니다."); raise SystemExit

mean = st.mean(v)
print(f"\n  대조군 평균 {mean:.4f}" + (f" · 최소 {min(v):.4f} · 최대 {max(v):.4f}" if len(v) > 1 else ""))

SONAR = 0.5147   # baseline_udp_2026-08-06, 같은 조건, n=2
print(f"  소나 있음 기준선 {SONAR:.4f} (baseline_udp_2026-08-06, 같은 조건)")
if mean > 0:
    print(f"  -> 소나 비용 {(1/SONAR - 1/mean):.3f} (1/RTF 차이) · 배율 {mean/SONAR:.2f}x")

print("""
  판정:
    대조군 ~1.0        -> 느린 원인은 전부 소나. 기존 서술 유지.
    대조군도 낮음      -> "소나 4.5배" 프레임 자체를 다시 써야 한다.
                          이 조사의 서술 대부분이 0.9996 위에 서 있다.

  주의: 2026-08-05 이전의 0.9996 과 직접 비교하지 마세요. DDS 전송과
        스텝 판정이 둘 다 바뀌었습니다. 이 값이 새 분모입니다.""")
PY
