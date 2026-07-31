#!/usr/bin/env bash
# go.sh — 환경 설정까지 알아서 하는 실행기
# 사용법:  ~/ROS2_Lyrical_review_fixes/notes/experiments/go.sh 1
#          2=기준선  1=사거리  1b=레이수  3=하이트맵  4=integrated격리
#
# 주의: 여기서는 set -u 를 쓰지 않는다.
#       ROS setup.bash 가 미정의 변수를 참조해서 set -u 면 조용히 죽는다.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WHICH="${1:-}"

case "$WHICH" in
  2)  S="$HERE/exp2_baseline.sh" ;;
  1)  S="$HERE/exp1_range.sh" ;;
  1b) S="$HERE/exp1b_raycount.sh" ;;
  1c) S="$HERE/exp1c_range_sweep.sh" ;;
  3)  S="$HERE/exp3_heightmap.sh" ;;
  4)  S="$HERE/exp4_integrated_isolated.sh" ;;
  *)  echo "사용법: go.sh [2|1|1b|3|4]"
      echo "  2  기준선(소나 없이)   1  사거리   1b 레이 수"
      echo "  3  하이트맵            4  integrated 격리"
      exit 1 ;;
esac
[ -f "$S" ] || { echo "스크립트 없음: $S"; exit 1; }

# --- 워크스페이스 탐지 -----------------------------------------------------
WS=""
for c in "$HOME/dave_ws_lyrical" "$HOME/dave_ws" /root/dave_ws; do
  if [ -d "$c/src/dave" ]; then WS="$c"; break; fi
done
[ -n "$WS" ] || { echo "dave 워크스페이스를 못 찾음"; exit 1; }
echo "[env] workspace = $WS"

# --- 환경 확인 --------------------------------------------------------------
# 맥에서는 setup.bash 를 소싱하면 안 된다 (README: COLCON_CURRENT_PREFIX 깨짐).
# 이미 소싱된 환경이면 그대로 쓰고, 아니면 사용자에게 맡긴다.
set +u
if command -v ros2 >/dev/null 2>&1 && [ -n "${GZ_SIM_SYSTEM_PLUGIN_PATH:-}${IGN_GAZEBO_SYSTEM_PLUGIN_PATH:-}${AMENT_PREFIX_PATH:-}" ]; then
  echo "[env] 기존 환경 사용 (ros2 = $(command -v ros2))"
else
  echo "[env] ! ROS 환경이 안 잡혀 있습니다."
  echo
  echo "  터미널에서 아래를 먼저 실행한 뒤 다시 돌리세요:"
  echo "    source $WS/install/setup.zsh"
  echo
  exit 1
fi

export SDF="$WS/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf"
export W="$WS/src/dave/models/dave_worlds/worlds/dave_multibeam_sonar.world"
[ -f "$SDF" ] || { echo "[env] ! SDF 없음: $SDF"; exit 1; }
[ -f "$W" ]   || { echo "[env] ! world 없음: $W"; exit 1; }
echo "[env] SDF / world 확인됨"
echo "[go ] $(basename "$S") 시작"
echo

bash "$S"
