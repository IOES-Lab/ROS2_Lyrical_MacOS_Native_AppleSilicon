#!/usr/bin/env bash
# common.sh — 측정 프로토콜 공용 정의. 각 실험 스크립트가 source 한다.
#
# 왜 만들었나: 실험 스크립트마다 launch/대기/정리를 따로 구현해두니, 방법을
# 한 번 고칠 때마다 한두 개가 옛날 버전으로 남았다. 실제로 2026-08-03 기준
# exp1_range.sh 와 exp3_heightmap.sh 에는 무효로 판명된 고정 sleep 이 남아
# 있었고, 그중 exp1 의 결과가 exp1c 의 설계 전제로 인용돼 있었다.
# 프로토콜은 여기 한 곳에만 둔다.
#
# 프로토콜 (2026-08-03 확정):
#   1) 측정 전 반드시 정리하고, 남은 gz-sim 이 있으면 중단한다.
#      (2026-07-31 에 남은 프로세스가 수치를 오염시킨 적 있음)
#   2) 고정 sleep 으로 안정화를 기다리지 않는다. 소나 초기화는 맥에서
#      145~175초 걸리고 런마다 20~30초 흔들린다. 로그를 폴링한다.
#   3) stats 토픽명을 하드코딩하지 않는다. 월드 내부 이름이 플랫폼마다
#      다르다 (맥 /world/default, Docker /world/oceans_waves 관측됨).

set +u

COMMON_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 정리 -------------------------------------------------------------------
cleanup () {
  pkill -f 'gz sim'        2>/dev/null || true
  pkill -f gz-sim          2>/dev/null || true
  pkill -f 'ros2 launch'   2>/dev/null || true
  pkill -f parameter_bridge 2>/dev/null || true
  sleep 6
}

# gz-sim 프로세스 PID 찾기. macOS 의 pgrep 은 'a|b' 교대를 안 받으므로
# 패턴을 하나씩 따로 시도한다. 2026-08-03 에 exp4 가 이것 때문에 PID 를
# 60초간 못 찾고 죽었다.
find_gz_pid () {
  local pat pid
  for pat in 'gz-sim-server' 'gz-sim' 'gz sim'; do
    pid=$(pgrep -f "$pat" 2>/dev/null | head -1)
    [ -n "$pid" ] && { echo "$pid"; return 0; }
  done
  return 1
}

# 남은 프로세스가 있으면 측정하지 않는다. 오염된 수치는 없느니만 못하다.
assert_clean () {
  if find_gz_pid >/dev/null; then
    echo "  ! 이전 gz-sim 이 살아있습니다. 수동 정리 후 다시 돌리세요:"
    echo "      pkill -f gz-sim; pkill -f 'ros2 launch'"
    return 1
  fi
  return 0
}

# --- 토픽 -------------------------------------------------------------------
# resolve_topic [최대대기초=120]  -> stdout 에 토픽명
resolve_topic () {
  bash "$COMMON_HERE/stats_topic.sh" "${1:-120}"
}

# --- 사전 점검 --------------------------------------------------------------
# 측정을 시작하기 전에 환경이 맞는지 확인한다. 여기서 안 걸러내면 "토픽 없음"
# 이 관측 시간 내내 찍히는데, 그건 데이터가 아니라 환경 오류다. 그런데 화면
# 상으로는 "월드가 완전히 죽었다"처럼 보인다.
# 2026-08-03 Docker 첫 시도에서 정확히 이것 때문에 20분을 버렸다.
preflight () {
  local ok=0
  if ! command -v ros2 >/dev/null 2>&1; then
    echo "  ! ros2 가 PATH 에 없습니다. setup 을 먼저 source 하세요."; ok=1
  elif ! ros2 pkg prefix dave_demos >/dev/null 2>&1; then
    echo "  ! dave_demos 패키지를 못 찾습니다."
    echo "    워크스페이스 setup 이 안 됐거나 경로가 틀렸습니다. 찾는 법:"
    echo "      find / -maxdepth 6 -name dave_demos -type d 2>/dev/null | head"
    echo "    컨테이너에서 root 로 들어가면 워크스페이스가 /home/<user> 에"
    echo "    있을 수 있습니다 (\$HOME 이 /root 로 잡힘)."
    ok=1
  fi
  if ! command -v gz >/dev/null 2>&1; then
    echo "  ! gz 가 PATH 에 없습니다."; ok=1
  fi
  if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
    echo "  ! timeout/gtimeout 이 없습니다 (맥: brew install coreutils)."; ok=1
  fi
  return $ok
}

# --- launch -----------------------------------------------------------------
# launch_sonar_world <로그경로>   -> 백그라운드로 띄운다
# launch_sonar_world <로그경로> [월드명=dave_multibeam_sonar]
# 주의: 위치 인자(x/z/yaw)는 multibeam 월드 기준이라 다른 월드에는 안 넘긴다.
launch_sonar_world () {
  local LOG="${1:?로그 경로 필요}" WORLD="${2:-dave_multibeam_sonar}"
  if [ "$WORLD" = dave_multibeam_sonar ]; then
    ros2 launch dave_demos dave_sensor.launch.py \
        namespace:=blueview_p900 world_name:="$WORLD" paused:=false \
        x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true \
        > "$LOG" 2>&1 &
  else
    ros2 launch dave_demos dave_sensor.launch.py \
        namespace:=blueview_p900 world_name:="$WORLD" paused:=false \
        compute_backend:=wgpu gui:=true headless:=true \
        > "$LOG" 2>&1 &
  fi
  LAUNCH_PID=$!
}

# 소나가 로그상 올라왔는지 (대기하지 않고 즉시 판정). 1=올라옴 0=아직
# 숫자를 넣지 않는다 — 빔/레이 수를 바꾸면 로그 숫자도 바뀐다.
SONAR_PAT="${SONAR_PAT:-Persistent GPU buffers allocated for}"
sonar_is_up () {
  grep -q "$SONAR_PAT" "$1" 2>/dev/null && echo 1 || echo 0
}

# launch 가 15초 뒤에도 살아있는지 확인한다. 죽었으면 로그를 보여준다.
assert_launch_alive () {
  local LOG="$1"
  sleep 15
  if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    echo "  ! ros2 launch 가 15초 안에 죽었습니다. 환경 문제입니다."
    echo "  --- $LOG 마지막 25줄 ---"
    tail -25 "$LOG" 2>/dev/null | sed 's/^/    /'
    return 1
  fi
  return 0
}

# --- 안정화 -----------------------------------------------------------------
# settle_for_sonar <로그경로> [최대대기초=300]
# 소나가 실제로 올라온 뒤 20초 더 기다린다. 실패하면 비0 반환 — 호출부는
# 반드시 그 측정을 버려야 한다. 여기서 그냥 진행하면 소나 없는 월드를
# 측정하고 RTF ~1.0 을 얻는데, 겉보기에 정상이라 알아채기 어렵다.
settle_for_sonar () {
  bash "$COMMON_HERE/wait_sonar.sh" "$1" "${2:-300}"
}

# --- 한 번 측정 --------------------------------------------------------------
# measure_once <라벨> [측정초=60] [로그경로]
#   정리 -> launch -> 소나 대기 -> 토픽 탐색 -> 측정
#   성공하면 stdout 에 "RESULT,라벨,rtf,sim,real,msgs" 한 줄. 실패하면 비0.
#   측정이 끝나도 정리하지 않는다 (호출부가 SDF/월드 원복 순서를 통제한다).
measure_once () {
  local LABEL="${1:?라벨 필요}" WIN="${2:-60}" LOG="${3:-/tmp/measure_$$.log}"

  preflight || return 1
  cleanup
  assert_clean || return 2

  launch_sonar_world "$LOG" "${WORLD:-dave_multibeam_sonar}"
  echo "  launch 완료 (로그 $LOG)"
  assert_launch_alive "$LOG" || return 5

  if ! settle_for_sonar "$LOG" 300; then
    echo "  ! 소나가 300초 안에 안 올라왔습니다 — 이 측정은 버립니다."
    echo "    (고정 sleep 으로 대신 진행하면 소나 없는 월드를 재게 됩니다)"
    return 3
  fi

  local TOPIC
  TOPIC=$(resolve_topic 60) || {
    echo "  ! stats 토픽을 못 찾았습니다. 확인: gz topic -l | grep stats"
    return 4
  }
  echo "  topic = $TOPIC"

  bash "$COMMON_HERE/rtf_probe.sh" "$TOPIC" "$WIN" "$LABEL"
}
