#!/usr/bin/env bash
# exp13_gpu_lidar.sh — DAVE 없이 stock gpu_lidar 만으로 Docker 크래시를 재현해본다
#
# 왜:
#   dave_multibeam_sonar 는 Docker 에서 뜨지 않는다. 있는 그대로(ogre2)는
#   Ogre2GpuRays::CreateSampleTexture() 에서 세그폴트(exit 139, 2/2 재현),
#   ogre 로 바꾸면 RenderSystem_GL 의 dllStartPlugin 에서 abort(exit 134).
#   notes/docker-sonar-crash-issue-draft.md 의 'Before filing' 이 요구하는 검사가
#   바로 이것이다: **DAVE 플러그인 없이 stock gpu_lidar 로도 같은 일이 나는가.**
#
#   여기서도 죽으면 DAVE 는 무관하고 gazebosim/gz-rendering 문제다.
#   여기서 안 죽으면 소나 쪽 사용 방식이 용의자로 남는다.
#   어느 쪽이든 초안이 제출 가능해진다.
#
# 판정 (돌리기 전에 못박는다):
#   513x301 에서 exit 139 + CreateSampleTexture  -> gz-rendering. DAVE 무관.
#   513x301 은 죽고 작은 해상도는 산다             -> 해상도/메모리 문제. 임계점을 기록한다.
#   전부 산다                                      -> stock lidar 는 멀쩡하다.
#                                                     소나의 사용 방식이 용의자.
#   ogre 에서 exit 134                             -> 렌더 엔진 로드 자체 문제.
#                                                     소나와 무관하게 재현된 셈.
#
# 사용법:
#   bash exp13_gpu_lidar.sh                 # 기본: ogre2, 해상도 3단계
#   ENGINE=ogre bash exp13_gpu_lidar.sh     # ogre 로
#   SIZES="513x301" bash exp13_gpu_lidar.sh # 한 조건만
#
# 맥에서도 돌아간다. 맥이 대조군이다 — 거기선 소나 월드가 뜨므로
# 이 프로브도 떠야 정상이고, 안 뜨면 프로브 자체가 잘못된 것이다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WORLD_SRC="$HERE/gpu_lidar_probe.world"
ENGINE="${ENGINE:-ogre2}"
SIZES="${SIZES:-513x301 128x64 16x1}"
RUN="${RUN:-40}"          # 관측 시간(초)
OUT="${OUT:-/tmp/exp13_gpu_lidar_$(date +%m%d_%H%M).csv}"

[ -f "$WORLD_SRC" ] || { echo "! 월드 파일 없음: $WORLD_SRC"; exit 1; }
command -v gz >/dev/null 2>&1 || { echo "! gz 가 PATH 에 없습니다."; exit 1; }

TO=timeout; command -v timeout >/dev/null 2>&1 || TO=gtimeout
command -v "$TO" >/dev/null 2>&1 || { echo "! timeout/gtimeout 없음"; exit 1; }

echo "engine,h_samples,v_samples,total_rays,exit_code,outcome,sensor_data,signature" > "$OUT"
echo "엔진 $ENGINE · 해상도 [$SIZES] · 건당 최대 ${RUN}초"
echo "저장: $OUT"

cleanup_gz () {
  pkill -9 -f gz-sim 2>/dev/null || true
  pkill -9 -f 'gz sim' 2>/dev/null || true
  sleep 2
}
trap 'cleanup_gz; echo "[정리] 완료"' EXIT

run_one () {   # $1 = HxV
  local H="${1%x*}" V="${1#*x}" TOT=$(( ${1%x*} * ${1#*x} ))
  local W="/tmp/exp13_${ENGINE}_${H}x${V}.world"
  local LOG="/tmp/exp13_${ENGINE}_${H}x${V}.log"

  echo; echo "=============== $ENGINE · ${H}x${V}  (${TOT} rays) ==============="
  cleanup_gz

  # 해상도와 렌더 엔진을 치환한다. sed 로 두 <samples> 를 따로 바꿔야 하므로
  # 순서에 의존하지 않도록 python 을 쓴다.
  python3 - "$WORLD_SRC" "$W" "$H" "$V" "$ENGINE" <<'PY'
import sys, re
src, dst, h, v, eng = sys.argv[1:6]
s = open(src).read()
s, n1 = re.subn(r"(<horizontal>\s*<samples>)\d+(</samples>)", rf"\g<1>{h}\g<2>", s)
s, n2 = re.subn(r"(<vertical>\s*<samples>)\d+(</samples>)",   rf"\g<1>{v}\g<2>", s)
s, n3 = re.subn(r"<render_engine>[^<]*</render_engine>", f"<render_engine>{eng}</render_engine>", s)
assert n1 == 1 and n2 == 1 and n3 == 1, f"치환 실패: h={n1} v={n2} engine={n3}"
open(dst, "w").write(s)
PY
  [ $? -eq 0 ] || { echo "  ! 월드 생성 실패"; return; }

  # 백그라운드로 띄우고, 사는지 죽는지 + **센서가 실제로 발행하는지** 를 본다.
  # 2026-08-07 추가: 살아남았다는 것만으로는 아무것도 증명 못 한다. 센서가
  # 아예 생성되지 않아도 프로세스는 멀쩡히 산다 — 어제 소나 월드가 정확히
  # 그랬고(모델 미스폰, RTF ~1.0, 겉보기 정상), 오늘 아침 IMU 도 토픽만 있고
  # 조용했다. Docker 에서 ALIVE 가 나와도 '센서가 안 만들어져서 안 죽은 것'
  # 이면 이 실험은 아무 말도 못 한다.
  gz sim -s -r -v 3 "$W" > "$LOG" 2>&1 &
  local PID=$!
  local DATA=no ALIVE_AT_CHECK=no
  sleep 20
  if kill -0 "$PID" 2>/dev/null; then
    ALIVE_AT_CHECK=yes
    "$TO" -k 3 15 gz topic -e -t /gpu_lidar -n 1 >/dev/null 2>&1 && DATA=yes
  fi
  # 남은 관측 시간을 채운다 (초기화 직후가 아니라 좀 지나서 죽는 경우가 있다)
  local WAITED=35
  while [ "$WAITED" -lt "$RUN" ] && kill -0 "$PID" 2>/dev/null; do
    sleep 5; WAITED=$(( WAITED + 5 ))
  done
  local RC
  if kill -0 "$PID" 2>/dev/null; then
    kill -9 "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; RC=124
  else
    wait "$PID" 2>/dev/null; RC=$?
  fi
  echo "  센서 데이터: $DATA   (체크 시점 생존: $ALIVE_AT_CHECK)"

  # 시그니처를 찾는다. 하나만 grep 하면 안 된다 — 2026-08-03 에 실패 형태가
  # 세그폴트에서 abort 로 바뀌었는데 'Segmentation fault' 만 세고 있어서
  # 0건을 성공으로 읽을 뻔했다.
  local SIG="-"
  grep -q 'CreateSampleTexture'            "$LOG" && SIG="CreateSampleTexture"
  [ "$SIG" = "-" ] && grep -q 'dllStartPlugin' "$LOG" && SIG="dllStartPlugin"
  [ "$SIG" = "-" ] && grep -qi 'segmentation fault' "$LOG" && SIG="segfault(기타)"
  [ "$SIG" = "-" ] && grep -qi 'abort'     "$LOG" && SIG="abort(기타)"

  local OUTCOME
  case "$RC" in
    124) if [ "$DATA" = yes ]; then OUTCOME="ALIVE_WITH_DATA"; else OUTCOME="ALIVE_NO_DATA"; fi ;;
    139) OUTCOME="SEGFAULT" ;;
    134) OUTCOME="ABORT" ;;
    0)   OUTCOME="EXITED_CLEAN" ;;   # -r 인데 스스로 끝났다면 그것도 이상하다
    *)   OUTCOME="EXIT_$RC" ;;
  esac

  echo "  exit=$RC  -> $OUTCOME   시그니처: $SIG"
  case "$OUTCOME" in ALIVE_WITH_DATA) ;; *) echo "  --- 로그 마지막 15줄 ---"; tail -15 "$LOG" | sed 's/^/    /';; esac
  echo "$ENGINE,$H,$V,$TOT,$RC,$OUTCOME,$DATA,$SIG" >> "$OUT"
  cleanup_gz
}

for S in $SIZES; do run_one "$S"; done

echo; echo "===== 결과 ====="
column -s, -t < "$OUT" 2>/dev/null || cat "$OUT"
cat <<'EOF'

  읽는 법 (ALIVE = 관측 시간 내내 살아있었음, timeout 이 죽인 것):

    513x301 이 SEGFAULT + CreateSampleTexture
        -> DAVE 무관. gazebosim/gz-rendering 문제로 확정.
           초안에서 DAVE 를 빼고 gz-rendering 에 제출한다.

    513x301 만 죽고 작은 해상도는 ALIVE
        -> 해상도/메모리 임계. 초안에 임계점을 넣는다.

    전부 ALIVE
        -> stock lidar 는 멀쩡하다. 소나의 GpuRays 사용 방식이 용의자로 남고,
           초안은 DAVE 쪽에 그대로 낸다.

    ENGINE=ogre 에서 ABORT + dllStartPlugin
        -> 렌더 엔진 로드 자체 문제. 소나와 무관하게 재현된다.

  주의: 맥에서 돌리면 전부 ALIVE 여야 정상이다. 맥에서 죽으면 프로브가
        잘못된 것이므로, Docker 결과를 해석하기 전에 그것부터 고쳐야 한다.
EOF
