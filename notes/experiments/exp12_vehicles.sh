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
#   실제 메시지가 나오는지 본다. 그래야 FUNCTIONAL 수준의 근거가 된다.
#   프로세스가 안 죽는 것과 차량이 실제로 시뮬레이션되는 것은 다르다.
#   검사 목록은 차량마다 다르므로 설정 파일에서 읽는다 (bridged_topics).
#
# 판정 (돌리기 전에 못박는다):
#   모델 스폰 + 브리지 토픽 전부 수신 -> FUNCTIONAL PASS
#   모델 스폰 + 일부만                -> PARTIAL. 빠진 토픽을 기록한다.
#   모델 스폰만, 데이터 없음          -> SMOKE PASS 이상으로 올리지 않는다.
#   스폰 실패                         -> 실패. 로그를 남기고 다음 차량으로.
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

# 검사할 토픽은 차량마다 다르다. 하드코딩하면 안 된다 — 첫 판이 imu/
# magnetometer/odometry/pose 를 고정으로 박아뒀는데, glider_slocum 은 자기계
# 대신 navsat 을 브리지하므로 있지도 않은 센서를 찾고 PARTIAL 로 판정했다.
# 각 차량의 robot_config.py 에서 실제 브리지 목록을 읽는다.
# 2026-08-07 두 번째 수정: 정규식이 '/' 에서 끊기면 안 된다. 첫 판은
# [a-z_]* 였는데 설정의 실제 토픽이 /model/{ns}/camera/image 와
# /model/{ns}/battery/battery/state 라서 각각 camera, battery 로 잘렸고,
# 존재하지 않는 토픽을 찾은 뒤 rexrov 와 glider_slocum 을 결손으로 판정했다.
# 하드코딩을 걷어내면서 새 오류를 들여온 경우다.
bridged_topics () {   # $1 = 차량명 -> stdout 에 토픽 접미사 목록
  local WS CFG
  WS=$(find_ws) || return 1
  CFG="$WS/src/dave/models/dave_robot_models/config/$1/robot_config.py"
  [ -f "$CFG" ] || return 1
  grep -o '/model/{namespace}/[A-Za-z0-9_/]*' "$CFG" \
    | sed 's|/model/{namespace}/||' | sed 's|/*$||' | sort -u \
    | grep -v '^joint'          # joint 는 스러스터별로 갈려서 단일 토픽이 아니다
}

echo "vehicle,world,spawned,ok,total,missing,verdict" > "$OUT"
echo "차량 [$VEHICLES] · 월드 $WORLD · 건당 3~5분"
echo "저장: $OUT"

trap 'cleanup; echo "[정리] 완료"' EXIT

# ROS 토픽에서 메시지가 실제로 오는지. 1=옴 0=안옴
# ros2 topic echo 는 컨테이너에서 rclpy 문제로 실패한 전력이 있어(2026-07-29),
# 실패 시 gz 쪽 토픽으로 폴백한다. 둘 다 안 되면 0.
#
# 2026-08-07: -k 를 반드시 붙인다. rclpy 가 SIGTERM 을 잡아서 timeout 의
# 기본 시그널로는 안 죽는다 (어제 ros_gz_sim create 를 Ctrl-C 로 못 죽인 것과
# 같은 현상). 처음 판은 이것 때문에 두 번째 차량에서 30분 넘게 멈춰 있었다.
# -k 3 = TERM 3초 뒤에도 살아있으면 KILL.
topic_has_data () {   # $1 = ROS 토픽  $2 = gz 토픽
  if "$TO" -k 3 "$TOPIC_WAIT" ros2 topic echo "$1" --once >/dev/null 2>&1; then
    echo 1; return
  fi
  if [ -n "$2" ] && "$TO" -k 3 "$TOPIC_WAIT" gz topic -e -t "$2" -n 1 >/dev/null 2>&1; then
    echo 1; return
  fi
  echo 0
}

# 토픽이 아예 존재하지 않는 것과, 존재하는데 데이터가 안 오는 것을 구분한다.
# 이 구분이 없으면 '차량 결함' 과 '브리지 미기동' 을 섞어 읽게 된다.
topic_exists () {   # $1 = ROS 토픽
  "$TO" -k 3 10 ros2 topic list 2>/dev/null | grep -qx -- "$1" && echo 1 || echo 0
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
    echo "$NS,$WORLD,no,0,0,-,LAUNCH_FAILED" >> "$OUT"; cleanup; return
  fi

  local TOPIC
  TOPIC=$(resolve_topic 60) || {
    echo "  ! stats 토픽 없음"
    echo "$NS,$WORLD,no,0,0,-,NO_STATS" >> "$OUT"; cleanup; return; }
  wait_until_stepping "$TOPIC" "${STEP_MAX:-240}" "${STEP_MIN:-60}" || {
    echo "  ! 스텝 미확인"
    echo "$NS,$WORLD,?,0,0,-,NOT_STEPPING" >> "$OUT"; cleanup; return; }

  echo "  ${SETTLE}초 안정화 후 토픽 확인"
  sleep "$SETTLE"

  local SP=no
  assert_model_spawned "$NS" 30 && SP=yes

  local TOPICS OK=0 TOTAL=0 MISSING="" t n
  TOPICS=$(bridged_topics "$NS") || {
    echo "  ! $NS 의 robot_config.py 를 못 읽었습니다"
    echo "$NS,$WORLD,$SP,0,0,CONFIG_UNREADABLE,ERROR" >> "$OUT"; cleanup; return; }
  echo "  브리지 대상: $(echo "$TOPICS" | tr '\n' ' ')"

  for t in $TOPICS; do
    TOTAL=$(( TOTAL + 1 ))
    n=$(topic_has_data "/model/$NS/$t" "/model/$NS/$t")
    if [ "$n" = 1 ]; then
      OK=$(( OK + 1 )); printf '    %-26s 데이터 있음\n' "$t"
    else
      MISSING="${MISSING}${MISSING:+ }$t"
      # 데이터가 안 온 토픽은 존재 여부까지 본다. 없으면 브리지/센서 설정
      # 문제, 있는데 조용하면 센서가 발행을 안 하는 것 — 원인이 다르다.
      if [ "$(topic_exists "/model/$NS/$t")" = 1 ]; then
        printf '    %-26s 토픽은 있으나 %s초간 메시지 없음\n' "$t" "$TOPIC_WAIT"
      else
        printf '    %-26s 토픽 자체가 없음\n' "$t"
      fi
    fi
  done

  local V
  if   [ "$SP" = no ];        then V=SPAWN_FAILED
  elif [ "$OK" -eq "$TOTAL" ]; then V=FUNCTIONAL
  elif [ "$OK" -gt 0 ];        then V=PARTIAL
  else                              V=SMOKE_ONLY
  fi
  echo "  -> $V  ($OK/$TOTAL)"
  echo "$NS,$WORLD,$SP,$OK,$TOTAL,${MISSING:--},$V" >> "$OUT"
  cleanup
}

for V in $VEHICLES; do
  run_vehicle "$V" || echo "  ! $V 준비 단계에서 중단"
done

echo; echo "===== 결과 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"
echo
echo "  판정 기준:"
echo "    FUNCTIONAL   스폰 + 브리지 토픽 전부 -> 매트릭스 FUNCTIONAL PASS 근거"
echo "    PARTIAL      일부만 — missing 열에 빠진 토픽이 있음"
echo "    SMOKE_ONLY   스폰은 됐지만 데이터 없음 — SMOKE PASS 이상 올리지 말 것"
echo
echo "  주의: 토픽이 안 잡혔다고 곧바로 '차량 결함' 으로 읽지 마세요."
echo "        브리지(parameter_bridge)가 안 떴을 수도 있습니다. 확인:"
echo "          ros2 topic list | grep model"
echo "          grep -i bridge /tmp/exp12_<차량>.log"
