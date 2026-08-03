#!/usr/bin/env bash
# wait_sonar.sh <로그경로> [최대대기초=300]
# 소나가 실제로 올라올 때까지 기다린다. 고정 sleep 은 쓰지 않는다.
# (맥 기준 launch 후 약 163초 걸림 — 90초 대기로는 못 잡는다)
L="${1:?로그 경로 필요}"; MAX="${2:-300}"; T=0
# 빔/레이 수를 바꾸면 로그의 숫자도 바뀐다. 숫자를 넣지 않는다.
# 2026-08-03: '...for 513' 로 하드코딩돼 있어서, exp1b 가 beams 를 줄인
# 구간에서 300초 대기 후 조용히 측정을 건너뛰게 돼 있었다.
PAT="${SONAR_PAT:-Persistent GPU buffers allocated for}"
printf '  소나 대기'
while [ "$T" -lt "$MAX" ]; do
  if grep -q "$PAT" "$L" 2>/dev/null; then
    echo " -> 올라옴 (${T}초)"; sleep 20; return 0 2>/dev/null || exit 0
  fi
  sleep 5; T=$((T+5))
  [ $((T % 30)) -eq 0 ] && printf ' %ds' "$T"
done
echo " -> 시간초과 (${MAX}초). 소나 미확인."
exit 1
