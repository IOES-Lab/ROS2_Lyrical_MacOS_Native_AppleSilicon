#!/usr/bin/env bash
# wait_sonar.sh <로그경로> [최대대기초=300]
# 소나가 실제로 올라올 때까지 기다린다. 고정 sleep 은 쓰지 않는다.
# (맥 기준 launch 후 약 163초 걸림 — 90초 대기로는 못 잡는다)
L="${1:?로그 경로 필요}"; MAX="${2:-300}"; T=0
# 소나가 "실제로 프레임을 계산 중"인지 본다.
#
# 2026-08-03: 원래 '...allocated for 513' 로 하드코딩돼 있었다. 빔 수를 바꾸면
# 숫자가 달라지므로 일반화했는데, 그러자 플러그인이 먼저 찍는 더미 할당
#   [sonar_wgpu] Persistent GPU buffers allocated for 1x1x4
# 에 걸려 20초 만에 통과해버렸다. exp1b 4개 측정이 전부 무효가 됐다.
#
# 그래서 할당 메시지 대신 프레임 진행 로그를 기다린다. 이건 빔/레이 수와
# 무관하고, "버퍼를 잡았다"보다 강한 증거다 — 실제로 계산이 돌고 있다는 뜻.
#   [sonar_wgpu] GPU #50    |   21.5 ms | 65 beams x 2 rays x 399 freq
PAT="${SONAR_PAT:-sonar_wgpu] GPU #}"
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
