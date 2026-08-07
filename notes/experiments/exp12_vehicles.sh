#!/usr/bin/env bash
# exp12_vehicles.sh — 문서화된 차량들을 실제 월드 안에서 검증한다
#
# 왜:
#   18개 월드는 전부 검증했지만 차량 축은 REXROV 하나로만 훑었다.
#   BlueROV2 는 ArduSub/mavros 빌드와 런치만 확인됐고 월드 안 동작은 미검증,
#   BlueROV2 Heavy 는 한 번도 쓰지 않았다. 검증 매트릭스에 남은 마지막
#   커버리지 구멍이다 (README 'Exhaustive validation' 항목 참고).
#
# 무엇을 보나:
#   smoke test 가 아니다. 각 차량의 robot_config.py 가 브리지하는 ROS 토픽에서
#   실제 메시지가 나오는지 본다 — imu / magnetometer / odometry / pose.
#   그래야 FUNCTIONAL 수준의 근거가 된다. 프로세스가 안 죽는 것과
#   차량이 실제로 시뮬레이션되는 것은 다르다.
#
# 판정 (돌리기 전에 못박는다):
#   모델 스폰 + 4개 토픽 전부 수신  -> FUNCTIONAL PASS
#   모델 스폰 + 일부 토픽만          -> PARTIAL. 어느 토픽이 빠졌는지 기록한다.
#   모델 스폰만, 토픽 없음           -> SMOKE PASS 이상으로 올리지 않는다.
#   스폰 실패                        -> 실패. 로그를 남기고 다음 차량으로.
#
# 주의:
#   use_teleop / use_web_joystick 을 끈다. 기본값이 true 라 웹 조이스틱
#   서버(포트 8765)가 뜨는데, 반복 실행에서 포트 충돌이 날 수 있고
#   측정에 필요하지도 않다.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/common.sh"

VEHICLES="${VEHICLES:-bluerov2 bluerov2_heavy}"
WORLD="${WORLD:-dave_ocean_waves}"
SETTLE="${SETTLE:-45}"       # 스폰 후 토픽 확인까지 대기(초)
TOPIC_WAIT="${TOPIC_WAIT:-15}"
OUT="${OUT:-/tmp/exp12_vehicles_$(date +%m%d_%H%M).csv}"

TO=timeout; command -v timeout >/dev/null 2>&1 || TO=gtimeout

echo "vehicle,world,spawned,imu,magnetometer,odometry,pose,verdict" > "$OUT"
echo "차량 [$VEHICLES] · 월드 $WORLD · 건당 3~5분"
echo "저장: $OUT"

trap 'cleanup; echo "[정리] 완료"' EXIT

# ROS 토픽에서 메시지가 실제로 오는지. 1=옴 0=안옴
# ros2 topic echo 는 컨테이너에서 rclpy 문제로 실패한 전력이 있어(2026-07-29),
# 실패 시 gz 쪽 토픽으로 폴백한다. 둘 다 안 되면 0.
topic_has_data () {   # $1 = ROS 토픽  $2 = gz 토픽
  if "$TO" "$TOPIC_WAIT" ros2 topic echo "$1" --once >/dev/null 2>&1; then
    echo 1; return
  fi
  if [ -n "$2" ] && "$TO" "$TOPIC_WAIT" gz topic -e -t "$2" -n 1 >/dev/null 2>&1; then
    echo 1; return
  fi
  echo 0
}

run_vehicle () {
  local NS="$1"
  echo; echo "=============== $NS  (월드 $WORLD) ==============="
  local LOG="/tmp/exp12_${NS}.log"

  preflight || return 1
  cleanup
  assert_clean || return 2

  ros2 launch dave_demos dave_robot.launch.py \
      namespace:="$NS" world_name:="$WORLD" paused:=false \
      gui:=true headless:=true use_teleop:=false use_web_joystick:=false \
      > "$LOG" 2>&1 &
  LAUNCH_PID=$!
  echo "  launch 완료 (로그 $LOG)"
  if ! assert_launch_alive "$LOG"; then
    echo "$NS,$WORLD,no,-,-,-,-,LAUNCH_FAILED" >> "$OUT"; cleanup; return
  fi

  local TOPIC
  TOPIC=$(resolve_topic 60) || {
    echo "  ! stats 토픽 없음"
    echo "$NS,$WORLD,no,-,-,-,-,NO_STATS" >> "$OUT"; cleanup; return; }
  wait_until_stepping "$TOPIC" "${STEP_MAX:-240}" "${STEP_MIN:-60}" || {
    echo "  ! 스텝 미확인"
    echo "$NS,$WORLD,?,-,-,-,-,NOT_STEPPING" >> "$OUT"; cleanup; return; }

  echo "  ${SETTLE}초 안정화 후 토픽 확인"
  sleep "$SETTLE"

  local SP=no
  assert_model_spawned "$NS" 30 && SP=yes

  local IMU MAG ODO POSE
  IMU=$(topic_has_data  "/model/$NS/imu"           "/model/$NS/imu")
  MAG=$(topic_has_data  "/model/$NS/magnetometer"  "/model/$NS/magnetometer")
  ODO=$(topic_has_data  "/model/$NS/odometry"      "/model/$NS/odometry")
  POSE=$(topic_has_data "/model/$NS/pose"          "/model/$NS/pose")
  printf '  imu=%s  magnetometer=%s  odometry=%s  pose=%s\n' "$IMU" "$MAG" "$ODO" "$POSE"

  local SUM=$(( IMU + MAG + ODO + POSE )) V
  if   [ "$SP" = no ];   then V=SPAWN_FAILED
  elif [ "$SUM" -eq 4 ]; then V=FUNCTIONAL
  elif [ "$SUM" -gt 0 ]; then V=PARTIAL
  else                        V=SMOKE_ONLY
  fi
  echo "  -> $V"
  echo "$NS,$WORLD,$SP,$IMU,$MAG,$ODO,$POSE,$V" >> "$OUT"
  cleanup
}

for V in $VEHICLES; do
  run_vehicle "$V" || echo "  ! $V 준비 단계에서 중단"
done

echo; echo "===== 결과 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"
echo
echo "  판정 기준:"
echo "    FUNCTIONAL   스폰 + 4개 토픽 전부 -> 매트릭스 FUNCTIONAL PASS 근거"
echo "    PARTIAL      일부 토픽만 — 어느 것이 빠졌는지 위 표에 있음"
echo "    SMOKE_ONLY   스폰은 됐지만 데이터 없음 — SMOKE PASS 이상 올리지 말 것"
echo
echo "  주의: 토픽이 안 잡혔다고 곧바로 '차량 결함' 으로 읽지 마세요."
echo "        브리지(parameter_bridge)가 안 떴을 수도 있습니다. 확인:"
echo "          ros2 topic list | grep model"
echo "          grep -i bridge /tmp/exp12_<차량>.log"
