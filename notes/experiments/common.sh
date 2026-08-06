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

# --- Fast DDS 공유메모리 회피 (2026-08-06) ----------------------------------
# ros_gz_sim create 가 무한 대기하던 원인. 멈춘 프로세스를 sample 로 뜨니
# 4218/4218 샘플이 전부 같은 스택이었다. SDF 도 gz 서비스도 근처에 못 갔다:
#
#   rclcpp::Node::make_shared -> rmw_create_node
#     -> rmw_fastrtps_cpp::create_subscription -> DataReaderImpl::enable()
#       -> RTPSDomain::createRTPSReader          <- 여기서 정지
#
# 즉 DAVE 도 Gazebo 도 아니고 Fast DDS 가 노드를 만들다 멈춘 것이다.
#
# 실측:
#   FASTDDS_BUILTIN_TRANSPORTS=UDPv4 있음 -> 5/5 성공
#   없음                                   -> 9번 중 1번 성공
#
# !!! 이건 측정 조건을 바꾼다 !!!
#   2026-08-05 프로파일에서 공유메모리 전송 스레드가 busy 의 16% 를 스핀으로
#   태우고 있었다. 그걸 끄면 RTF 가 달라진다. 이 설정으로 잰 값은 자기만의
#   기준선이 필요하다. 2026-08-06 이전 수치와 비교하지 말 것.
#   SHM=1 로 끄고 원래 동작을 재현할 수 있다 (대신 대부분 스폰이 실패한다).
if [ "${SHM:-0}" != 1 ]; then
  export FASTDDS_BUILTIN_TRANSPORTS="${FASTDDS_BUILTIN_TRANSPORTS:-UDPv4}"
  echo "  [dds] FASTDDS_BUILTIN_TRANSPORTS=$FASTDDS_BUILTIN_TRANSPORTS (스폰 행 회피)"
fi

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

# 소나가 실제로 프레임을 계산 중인지 (대기하지 않고 즉시 판정). 1=예 0=아직
#
# 고정 문자열을 쓰면 안 된다. 플러그인은 진짜 센서를 올리기 전에 더미를
# 먼저 찍는데, 그 줄이 어떤 패턴에도 걸린다:
#     [sonar_wgpu] Persistent GPU buffers allocated for 1x1x4
#     [sonar_wgpu] GPU #1   |   13.1 ms | 1 beams x 1 rays x 4 freq
# 2026-08-03 에 'allocated for' 로 당했고, 'GPU #' 로 바꿨더니 2026-08-06 에
# 같은 더미 줄이 'GPU #' 도 갖고 있어서 또 당했다. 두 번 다 0~20초 만에
# 통과해서 기동 구간을 측정할 뻔했다.
#
# 그래서 문자열이 아니라 **빔 수**를 본다. 더미는 1 beams 다. 실제 센서는
# SDF 의 beams 값(기본 512, 플러그인 보고는 513)이다. 2 이상이면 진짜다.
# 이러면 beams 를 줄이는 실험(exp1b)에서도 안전하다 — 최소 조건이 64 다.
sonar_is_up () {
  awk '
    /beams/ {
      for (i = 2; i <= NF; i++)
        if ($i == "beams" && $(i-1) + 0 > 1) { found = 1; exit }
    }
    END { print (found ? 1 : 0) }
  ' "$1" 2>/dev/null || echo 0
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

# --- 실제로 스텝이 돌기 시작할 때까지 대기 --------------------------------
# 이게 유일하게 믿을 수 있는 기준이다.
#
# 2026-08-03 확인: 이 월드는 런치 후 약 60~75초간 시뮬레이션이 사실상 멈춰
# 있다가 갑자기 풀린다. 30초 간격 실측:
#     t=30s  iterations=8      t=90s   6536
#     t=60s  iterations=11     t=120s  15116   (+8580)
#                              t=150s  24389   (+9273)
# 즉 60초 시점까지 30초에 3스텝, 그 뒤로는 30초에 ~9000스텝.
#
# 로그 줄로 판정하면 안 된다. '[sonar_wgpu] GPU #' 도 'Persistent GPU buffers'
# 도 이 전환보다 훨씬 먼저 찍힌다(20~25초). 실제로 하루 종일 그 줄들의 등장
# 시각이 163초에서 20초까지 당겨졌는데 정지 구간 길이는 그대로였다. 로그는
# 센서가 준비됐다는 뜻이지 시뮬레이터가 돈다는 뜻이 아니다.
#
# wait_until_stepping <토픽> [최대대기초=420] [최소증가/15초=1000]
# 15초 간격으로 iterations 를 보고, 기준 이상 증가한 구간이 연속 2회
# 나오면 통과. 한 번만으로는 전환 직후 과도구간을 잡을 수 있다.
#
# 2026-08-06 수정: gz topic -e -n 1 은 메시지가 올 때까지 무한 대기한다.
# stats 가 아직 안 나오는 구간(소나 초기화 중)에 들어가면 여기서 영영
# 멈추고 바깥 루프가 한 바퀴도 못 돌아 MAX 타임아웃조차 동작하지 않는다.
# 화면에는 '스텝 대기' 만 찍힌 채 정지한 것처럼 보인다. 반드시 감싼다.
_iterations_now () {   # <토픽> -> stdout 에 iterations 값 (없으면 빈 문자열)
  local TO
  if command -v timeout >/dev/null 2>&1;    then TO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then TO=gtimeout
  else TO=""; fi
  if [ -n "$TO" ]; then
    "$TO" 10 gz topic -e -t "$1" -n 1 2>/dev/null \
      | grep -m1 -o 'iterations: [0-9]*' | awk '{print $2}'
  else
    gz topic -e -t "$1" -n 1 2>/dev/null \
      | grep -m1 -o 'iterations: [0-9]*' | awk '{print $2}'
  fi
}

wait_until_stepping () {
  local TOPIC="${1:?토픽 필요}" MAX="${2:-420}" MIN="${3:-1000}"
  local T=0 PREV="" CUR="" OK=0
  echo "  스텝 대기 (기준: 15초당 ${MIN}회 이상 증가, 연속 2회)"
  while [ "$T" -lt "$MAX" ]; do
    CUR=$(_iterations_now "$TOPIC")
    if [ -z "$CUR" ]; then
      printf '    t=%3ds  stats 응답 없음\n' "$T"
      PREV=""; OK=0; sleep 15; T=$(( T + 15 )); continue
    fi
    if [ -n "$CUR" ] && [ -n "$PREV" ]; then
      local D=$(( CUR - PREV ))
      if [ "$D" -ge "$MIN" ]; then
        OK=$(( OK + 1 ))
        printf '    t=%3ds  iterations=%-9s +%-7s OK(%d/2)\n' "$T" "$CUR" "$D" "$OK"
        [ "$OK" -ge 2 ] && { echo "  -> 정상 스텝 확인 (${T}초)"; return 0; }
      else
        OK=0
        printf '    t=%3ds  iterations=%-9s +%-7s 아직\n' "$T" "$CUR" "$D"
      fi
    fi
    PREV="$CUR"; sleep 15; T=$(( T + 15 ))
  done
  echo "  ! ${MAX}초 안에 정상 스텝을 확인하지 못했습니다."
  return 1
}

# --- 직접 경로 (ros2 launch 우회) -------------------------------------------
# 2026-08-06 추가. ros_gz_sim create 가 간헐적으로 무한 대기해서, 모델이 안
# 뜬 채로 월드만 도는 일이 반복됐다. 그러면 소나가 없으니 RTF 가 ~1.0 이
# 나오는데 겉보기엔 정상이다. settle_for_sonar 가 세 번 다 막아줬다.
# 자세한 내용: notes/results/spawn_hang_2026-08-05/
#
# gz service 로 직접 스폰하면 즉시 성공한다(확인됨: data: true).
#
# !!! 이 경로는 기존 경로의 대체가 아니다 !!!
#   ros2 launch 는 parameter_bridge 와 static_transform_publisher 도 띄운다.
#   여기서는 안 띄운다. 2026-08-05 프로파일에서 DDS 스레드가 busy 의 16% 를
#   스핀으로 태우고 있었으므로, 브리지가 빠지면 RTF 가 달라질 수 있다.
#   이 경로로 잰 값은 자기만의 기준선이 필요하다. 이전 수치와 비교하지 말 것.

find_ws () {
  local c
  for c in "$HOME/dave_ws_lyrical" "$HOME/dave_ws" /root/dave_ws; do
    [ -d "$c/src/dave" ] && { echo "$c"; return 0; }
  done
  return 1
}

world_file () {   # <월드명>
  local WS f; WS=$(find_ws) || return 1
  f="$WS/install/dave_worlds/share/dave_worlds/worlds/$1.world"
  [ -f "$f" ] && { echo "$f"; return 0; }
  return 1
}

sonar_model_sdf () {
  local WS f; WS=$(find_ws) || return 1
  f="$WS/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf"
  [ -f "$f" ] && { echo "$f"; return 0; }
  return 1
}

launch_world_direct () {   # <로그> [월드=dave_multibeam_sonar]
  local LOG="${1:?로그 경로 필요}" WORLD="${2:-dave_multibeam_sonar}" WF
  WF=$(world_file "$WORLD") || { echo "  ! 월드 파일을 못 찾음: $WORLD"; return 1; }
  gz sim -s -r "$WF" > "$LOG" 2>&1 &
  LAUNCH_PID=$!
}

# create 서비스가 뜰 때까지 기다린다. 월드가 준비되기 전에 스폰하면 실패한다.
wait_for_create_service () {   # [최대대기초=120]  -> stdout 에 서비스명
  local MAX="${1:-120}" T=0 SVC=""
  while [ "$T" -lt "$MAX" ]; do
    SVC=$(gz service -l 2>/dev/null | grep -m1 -E '^/world/[^/]+/create$' || true)
    [ -n "$SVC" ] && { echo "$SVC"; return 0; }
    sleep 5; T=$(( T + 5 ))
  done
  return 1
}

spawn_sonar_direct () {   # [서비스명]
  local SVC="$1" SDF R
  SDF=$(sonar_model_sdf) || { echo "  ! 소나 model.sdf 를 못 찾음"; return 1; }
  [ -n "$SVC" ] || SVC=$(wait_for_create_service 120) || {
    echo "  ! create 서비스가 안 뜹니다"; return 1; }
  # yaw 3.14 -> quaternion (z≈1, w≈0). 기존 launch 의 x:=5.8 z:=2 yaw:=3.14 와 동일.
  R=$(gz service -s "$SVC" \
        --reqtype gz.msgs.EntityFactory --reptype gz.msgs.Boolean --timeout 20000 \
        --req "sdf_filename: \"$SDF\", name: \"blueview_p900\", \
               pose: {position: {x: 5.8, y: 0, z: 2}, orientation: {x: 0, y: 0, z: 1, w: 0}}" \
        2>&1)
  echo "$R" | grep -q 'data: true' && return 0
  echo "  ! 스폰 실패: $R"
  return 1
}

# 모델이 실제로 월드에 있는지 확인한다. 이게 없으면 소나 없는 월드를
# 조용히 측정하게 된다 — 그게 정확히 2026-08-05 에 세 번 일어난 일이다.
#
# 폴링한다. 서비스가 data: true 를 돌려준 직후에도 모델이 목록에 바로
# 뜨지는 않는다 (2026-08-06 에 5초 고정 대기로는 놓쳤다).
#
# 중요: '모델이 없다' 와 '물어볼 수 없다' 를 구분한다.
#   gz model --list 는 /world/<name>/state 서비스를 부르는데, 소나가
#   초기화되는 동안 이 서비스가 타임아웃한다 (2026-08-06 관측). 그걸
#   '모델 없음' 으로 처리하면 멀쩡한 측정을 버리게 된다.
#   확실히 목록을 받았는데 거기 없을 때만 실패로 본다.
#   물어보지 못한 경우는 통과시킨다 — 어차피 settle_for_sonar 가
#   소나 없는 월드를 뒤에서 다시 걸러낸다.
assert_model_spawned () {   # [모델명=blueview_p900] [최대대기초=60]
  local NAME="${1:-blueview_p900}" MAX="${2:-60}" T=0 OUT="" GOT=0
  while [ "$T" -lt "$MAX" ]; do
    OUT=$(gz model --list 2>&1)
    if echo "$OUT" | grep -q -- "$NAME"; then
      [ "$T" -gt 0 ] && echo "  [direct] 모델 확인 (${T}초)"
      return 0
    fi
    # 'Available models:' 가 보이면 목록을 실제로 받은 것이다.
    echo "$OUT" | grep -q 'Available models' && GOT=1
    sleep 5; T=$(( T + 5 ))
  done

  if [ "$GOT" = 1 ]; then
    echo "  ! 월드 목록을 받았는데 $NAME 이 없습니다. 이 측정은 무효입니다."
    echo "  --- gz model --list ---"
    echo "$OUT" | sed 's/^/    /' | head -20
    return 1
  fi

  echo "  ! 모델 목록을 조회하지 못했습니다 (/world/*/state 타임아웃)."
  echo "    '모델 없음' 이 아니라 '확인 불가' 입니다. 계속 진행하고"
  echo "    settle_for_sonar 의 판정에 맡깁니다."
  return 0
}

# --- 한 번 측정 --------------------------------------------------------------
# measure_once <라벨> [측정초=60] [로그경로]
#   정리 -> launch -> 소나 대기 -> 토픽 탐색 -> 측정
#   성공하면 stdout 에 "RESULT,라벨,rtf,sim,real,msgs" 한 줄. 실패하면 비0.
#   측정이 끝나도 정리하지 않는다 (호출부가 SDF/월드 원복 순서를 통제한다).
#
# DIRECT=1 이면 ros2 launch 대신 gz sim + gz service 로 띄운다. 위의 경고를
# 반드시 읽을 것 — 조건이 달라지므로 기준선을 새로 잡아야 한다.
#
# RETRIES=N (기본 2) — 실패하면 다시 시도한다.
#   ros_gz_sim create 가 간헐적으로 무한 대기해서 모델이 안 뜨는 일이
#   2026-08-05~06 에 절반 가까이 발생했다. 원인은 아직 모른다. 하지만
#   실패는 settle_for_sonar 가 확실히 잡아내므로(조용히 통과하지 않는다)
#   그냥 다시 돌리면 된다. 원인 규명 없이도 실험은 진행할 수 있다.
#   측정값이 이상해서 재시도하는 게 아니라 **측정 자체가 성립하지 않은**
#   경우에만 재시도한다 — 그 구분이 중요하다.
measure_once () {
  local LABEL="${1:?라벨 필요}" WIN="${2:-60}" LOG="${3:-/tmp/measure_$$.log}"
  local N="${RETRIES:-2}" I=0 RC=0

  if [ "${DIRECT:-0}" = 1 ]; then
    measure_once_direct "$LABEL" "$WIN" "$LOG"; return $?
  fi

  while : ; do
    _measure_once_impl "$LABEL" "$WIN" "$LOG"; RC=$?
    [ "$RC" = 0 ] && return 0

    # 재시도해서 달라질 수 있는 것만 다시 한다.
    #   3 소나 미기동 · 5 launch 즉사 · 6 스텝 미확인  -> 스폰 행 계열, 재시도
    #   1 환경 · 2 잔여 프로세스 · 4 토픽 없음         -> 다시 해도 같다, 중단
    case "$RC" in
      3|5|6) ;;
      *) echo "  ! exit=$RC — 재시도해도 달라지지 않는 실패입니다."
         return "$RC" ;;
    esac

    I=$(( I + 1 ))
    [ "$I" -gt "$N" ] && {
      echo "  ! ${I}회 시도 모두 실패했습니다 (마지막 exit=$RC)."
      return "$RC"; }
    echo "  재시도 ${I}/${N} (exit=$RC) — 스폰 행일 가능성이 큽니다."
    cleanup
  done
}

_measure_once_impl () {
  local LABEL="$1" WIN="$2" LOG="$3"

  preflight || return 1
  cleanup
  assert_clean || return 2

  launch_sonar_world "$LOG" "${WORLD:-dave_multibeam_sonar}"
  echo "  launch 완료 (로그 $LOG)"
  assert_launch_alive "$LOG" || return 5

  if ! settle_for_sonar "$LOG" 300; then
    echo "  ! 소나가 300초 안에 안 올라왔습니다 — 이 측정은 버립니다."
    return 3
  fi

  local TOPIC
  TOPIC=$(resolve_topic 60) || {
    echo "  ! stats 토픽을 못 찾았습니다. 확인: gz topic -l | grep stats"
    return 4
  }
  echo "  topic = $TOPIC"

  # 소나 로그만 믿으면 안 된다 — 아직 정지 구간일 수 있다.
  wait_until_stepping "$TOPIC" "${STEP_MAX:-420}" "${STEP_MIN:-1000}" || return 6

  bash "$COMMON_HERE/rtf_probe.sh" "$TOPIC" "$WIN" "$LABEL"
}

# measure_once 와 같은 프로토콜이되 ros2 launch 를 쓰지 않는다.
# 반환값은 measure_once 와 같은 의미를 유지한다 (3=소나 미기동, 4=토픽없음 ...).
measure_once_direct () {
  local LABEL="${1:?라벨 필요}" WIN="${2:-60}" LOG="${3:-/tmp/measure_$$.log}"
  local SVC TOPIC

  command -v gz >/dev/null 2>&1 || { echo "  ! gz 가 PATH 에 없습니다."; return 1; }
  cleanup
  assert_clean || return 2

  launch_world_direct "$LOG" "${WORLD:-dave_multibeam_sonar}" || return 1
  echo "  [direct] gz sim 기동 (로그 $LOG)"
  assert_launch_alive "$LOG" || return 5

  SVC=$(wait_for_create_service 120) || {
    echo "  ! create 서비스가 120초 안에 안 떴습니다."; return 7; }
  echo "  [direct] 서비스 = $SVC"

  spawn_sonar_direct "$SVC" || return 8
  echo "  [direct] 스폰 성공"
  assert_model_spawned blueview_p900 60 || return 9

  if ! settle_for_sonar "$LOG" 300; then
    echo "  ! 소나가 300초 안에 안 올라왔습니다 — 이 측정은 버립니다."
    return 3
  fi

  TOPIC=$(resolve_topic 60) || {
    echo "  ! stats 토픽을 못 찾았습니다."; return 4; }
  echo "  topic = $TOPIC"

  wait_until_stepping "$TOPIC" "${STEP_MAX:-420}" "${STEP_MIN:-1000}" || return 6

  bash "$COMMON_HERE/rtf_probe.sh" "$TOPIC" "$WIN" "$LABEL"
}
