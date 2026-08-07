#!/usr/bin/env bash
# diag.sh — 소나가 왜 안 올라오는지 진단
L="${1:-/tmp/exp1c_r10.0.log}"
echo "=============== 환경 ==============="
for v in GZ_SIM_SYSTEM_PLUGIN_PATH GZ_SIM_RESOURCE_PATH IGN_GAZEBO_SYSTEM_PLUGIN_PATH AMENT_PREFIX_PATH; do
  printf '%-32s ' "$v"
  eval "val=\${$v:-}"
  if [ -z "$val" ]; then echo "(비어있음)"; else echo "$(echo "$val" | tr ':' '\n' | wc -l | tr -d ' ')개 경로"; fi
done
echo
echo "multibeam_sonar_system 라이브러리 위치:"
find "$HOME/dave_ws_lyrical/install" -name '*multibeam_sonar_system*' 2>/dev/null | head -5
echo
echo "=============== 로그: 플러그인/센서 관련 ==============="
grep -inE 'multibeam|sonar|Failed to load|Unable to find|could not|plugin' "$L" 2>/dev/null | head -20
echo
echo "=============== 로그: 에러 전부 ==============="
grep -inE '\[error\]|\[err\]|error:|exception' "$L" 2>/dev/null | head -12
echo
echo "=============== 로그 첫 25줄 ==============="
head -25 "$L" 2>/dev/null
