#!/usr/bin/env bash
# stats_topic.sh — /world/<name>/stats 토픽을 자동으로 찾는다.
#
# 왜 필요한가: 월드의 내부 이름은 파일명과 다르다.
#   dave_multibeam_sonar.world -> 맥에서는 /world/default/stats,
#   Docker 에서는 /world/oceans_waves/stats 로 관측된 적이 있다 (2026-07-29).
# 토픽명을 하드코딩하면 플랫폼이 바뀔 때 "샘플 없음"이 나오는데,
# 그건 월드가 느린 것과 구분이 안 된다. 그 혼동을 없애려고 분리했다.
#
# 사용법: stats_topic.sh [최대대기초=120]
# 출력  : 토픽명 한 줄 (stdout). 못 찾으면 종료코드 1.
set +u
MAX="${1:-120}"; T=0
while [ "$T" -lt "$MAX" ]; do
  TOPIC=$(gz topic -l 2>/dev/null | grep -E '^/world/[^/]+/stats$' | head -1)
  if [ -n "$TOPIC" ]; then echo "$TOPIC"; exit 0; fi
  sleep 3; T=$((T+3))
done
exit 1
