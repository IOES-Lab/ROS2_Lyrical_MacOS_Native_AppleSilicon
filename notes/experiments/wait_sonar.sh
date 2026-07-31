#!/usr/bin/env bash
# wait_sonar.sh <로그경로> [최대대기초=300]
# 소나가 실제로 올라올 때까지 기다린다. 고정 sleep 은 쓰지 않는다.
# (맥 기준 launch 후 약 163초 걸림 — 90초 대기로는 못 잡는다)
L="${1:?로그 경로 필요}"; MAX="${2:-300}"; T=0
printf '  소나 대기'
while [ "$T" -lt "$MAX" ]; do
  if grep -q '513×301×399\|Persistent GPU buffers allocated for 513' "$L" 2>/dev/null; then
    echo " -> 올라옴 (${T}초)"; sleep 20; return 0 2>/dev/null || exit 0
  fi
  sleep 5; T=$((T+5))
  [ $((T % 30)) -eq 0 ] && printf ' %ds' "$T"
done
echo " -> 시간초과 (${MAX}초). 소나 미확인."
exit 1
