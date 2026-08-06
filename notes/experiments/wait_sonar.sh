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
# 그래서 할당 메시지 대신 프레임 진행 로그를 기다리도록 바꿨다:
#   [sonar_wgpu] GPU #50    |   21.5 ms | 65 beams x 2 rays x 399 freq
#
# 2026-08-06: 그것도 틀렸다. 더미도 같은 형식으로 찍힌다 —
#   [sonar_wgpu] GPU #1     |   13.1 ms | 1 beams x 1 rays x 4 freq
# 'GPU #' 패턴이 여기 걸려 또 0초에 통과했다. 같은 함정 두 번째다.
#
# 문자열 패턴으로는 계속 진다. 이제 **빔 수**를 본다. 더미는 1 beams 이고
# 실제 센서는 SDF 값(기본 512 -> 플러그인 보고 513)이다. 2 이상이면 진짜다.
# 빔을 줄이는 실험(exp1b)의 최소 조건도 64 라 안전하다.
is_up () {
  awk '
    /beams/ {
      for (i = 2; i <= NF; i++)
        if ($i == "beams" && $(i-1) + 0 > 1) { found = 1; exit }
    }
    END { exit (found ? 0 : 1) }
  ' "$1" 2>/dev/null
}
printf '  소나 대기'
while [ "$T" -lt "$MAX" ]; do
  if is_up "$L"; then
    echo " -> 올라옴 (${T}초)"; sleep 20; return 0 2>/dev/null || exit 0
  fi
  sleep 5; T=$((T+5))
  [ $((T % 30)) -eq 0 ] && printf ' %ds' "$T"
done
echo " -> 시간초과 (${MAX}초). 소나 미확인."
exit 1
