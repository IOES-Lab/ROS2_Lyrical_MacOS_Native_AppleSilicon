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
  5)  S="$HERE/exp5_repeat.sh" ;;
  6)  S="$HERE/exp6_phase.sh" ;;
  7)  S="$HERE/exp7_rayskips.sh" ;;
  8)  S="$HERE/exp8_profile.sh" ;;
  9)  S="$HERE/exp9_threads.sh" ;;
  11) S="$HERE/exp11_updaterate.sh" ;;
  12) S="$HERE/exp12_vehicles.sh" ;;
  13) S="$HERE/exp13_gpu_lidar.sh" ;;
  *)  echo "사용법: go.sh [6|2|4|1|3|1c|1b|5|7|8|9|11|12|13]   (권장 순서대로 나열)"
      echo "  6   launch~정상상태 RTF 곡선 (무엇을 재고 있는지부터 확인)"
      echo "  2   기준선 — 소나 없이"
      echo "  4   integrated 격리 (맥 미측정 — 폐기된 전제를 다시 세우는 단계)"
      echo "  1   사거리 10/3/1"
      echo "  3   하이트맵 추가"
      echo "  1c  사거리 스윕 (1 결과를 보고 구간을 정할 것)"
      echo "  1b  레이 수 축소 (사거리가 무관으로 판명되면)"
      echo "  5   같은 조건 반복 — 재현성"
      echo "  7   raySkips — 레이캐스트 vs 그 뒤 연산 판별"
      echo "  8   프로파일링 — 추론 말고 실제로 어느 함수가 비싼지 (sample, macOS)"
      echo "  9   스레드 수 캡 — 스핀 49.3% 가 원인인지 증상인지 (리빌드 불필요)"
      echo "  11  update_rate 스윕 — 속도가 아니라 빈도가 손잡이인지 (리빌드 불필요)"
      echo "  12  차량 in-world 검증 — BlueROV2 / BlueROV2 Heavy (매트릭스 마지막 구멍)"
      echo "  13  stock gpu_lidar 프로브 — Docker 크래시가 DAVE 것인지 gz-rendering 것인지"
      echo
      echo "  건당 4~6분. Docker 는 RUN_DOCKER.md 참고."
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
