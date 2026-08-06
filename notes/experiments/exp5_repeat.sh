#!/usr/bin/env bash
# exp5_repeat.sh — 같은 조건을 N회 반복해서 재현성을 본다
#
# 배경: dave_multibeam_sonar 가 같은 코드·같은 설정에서 세 번 다 다르게 나왔다.
#   2026-07-23 Mac    RTF 0.012~0.015 + 간헐적 4분 정지
#   2026-07-29 Docker RTF 0.0008~0.0077, 정지 없음
#   2026-07-31 Mac    RTF 0.2223, 정지 없음 (대조군 0.9996)
#
# 2026-08-06 전면 재작성. 이 스크립트는 common.sh 이전에 쓰였고, 그 뒤
# 프로토콜이 여러 번 고쳐지는 동안 옛날 버전으로 남아 있었다. 빠져 있던 것:
#   - Fast DDS 공유메모리 회피 (없으면 스폰이 9번 중 1번만 성공한다)
#   - 더미 1 beams 를 거르는 소나 판정 (옛 판정은 0~20초에 통과했다)
#   - wait_until_stepping (로그만 믿으면 기동 구간을 측정한다)
#   - 스폰 행 재시도
#   - macOS 에서 동작하는 프로세스 탐색 (pgrep -f 'a|b' 는 맥에서 무효)
# 이제 전부 common.sh 한 곳에서 온다.
#
# 지금 이걸 돌리는 이유(2026-08-06): FASTDDS_BUILTIN_TRANSPORTS=UDPv4 가
# 기본이 되면서 측정 조건이 바뀌었다. 이전 수치는 비교 대상이 아니다.
# **새 기준선을 n>1 로 잡는 것이 이 실행의 목적이다.**
# 어제까지의 n=1 측정에서 조건 간 12% 차이를 봤으므로, 변동 폭부터 알아야
# 이후의 before/after 를 판정할 수 있다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

N="${N:-3}"
WIN="${WIN:-60}"
LABEL="${LABEL:-baseline}"
OUT="${OUT:-/tmp/exp5_repeat_$(date +%m%d_%H%M).csv}"

trap 'cleanup; echo "[정리] 완료"' EXIT

echo "run,rtf,sim_delta,real_delta,msgs,sonar_wait_s" > "$OUT"
echo "조건 '$LABEL' · ${N}회 · 건당 5~8분"
echo "저장: $OUT"

for i in $(seq 1 "$N"); do
  echo; echo "=============== 반복 $i / $N ==============="
  LOG="/tmp/exp5_${LABEL}_run$i.log"
  T0=$(date +%s)

  R=$(measure_once "${LABEL}$i" "$WIN" "$LOG" | tee /dev/stderr | grep '^RESULT' || true)
  WAIT=$(( $(date +%s) - T0 ))

  if [ -n "$R" ]; then
    echo "$i,$(echo "$R" | cut -d, -f3,4,5,6),$WAIT" >> "$OUT"
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
n_planned = int(sys.argv[2])
v = [float(r['rtf']) for r in rows]

if len(v) < len(range(n_planned)):
    print(f"\n  주의: {n_planned}회 중 {len(v)}회만 측정됐습니다.")
    print("  실패한 회차를 '값이 같았다'로 읽으면 안 됩니다.")

if len(v) < 2:
    print("\n  측정이 2건 미만이라 변동 폭을 낼 수 없습니다."); raise SystemExit

mean = st.mean(v)
print(f"\n  평균 {mean:.4f} · 최소 {min(v):.4f} · 최대 {max(v):.4f}")
print(f"  최대/최소 {max(v)/min(v):.2f}배 · 폭 {(max(v)-min(v))/mean*100:.1f}% of mean")
if len(v) >= 3:
    print(f"  표준편차 {st.stdev(v):.4f} ({st.stdev(v)/mean*100:.1f}%)")
print(f"""
  이 값이 앞으로의 판정 기준입니다.
  before/after 실험에서 이 폭보다 작은 차이는 읽으면 안 됩니다.
  (2026-08-06 이전 수치와 비교 금지 — DDS 전송이 바뀌었습니다.)""")
PY
