#!/usr/bin/env bash
# rtf_probe.sh — endpoint-delta RTF 측정
# 사용법: ./rtf_probe.sh <stats_topic> [측정초=60] [라벨]
# 예:    ./rtf_probe.sh /world/default/stats 60 "range10-baseline"
set +u
TOPIC="${1:?stats topic 필요}"; WIN="${2:-60}"; LABEL="${3:-run}"

# macOS에는 timeout 이 없다. gtimeout(coreutils) 로 폴백.
if command -v timeout >/dev/null 2>&1;      then TO=timeout
elif command -v gtimeout >/dev/null 2>&1;   then TO=gtimeout
else echo "  ! timeout/gtimeout 없음 -> brew install coreutils"; exit 1; fi
TMP=$(mktemp)
echo "[probe] $LABEL  topic=$TOPIC  window=${WIN}s"
"$TO" "$WIN" gz topic -e -t "$TOPIC" > "$TMP" 2>/dev/null
python3 - "$TMP" "$LABEL" "$WIN" <<'PY'
import sys, re
raw = open(sys.argv[1], errors="ignore").read()
label, win = sys.argv[2], float(sys.argv[3])

def blocks(name):
    out = []
    for m in re.finditer(name + r"\s*\{\s*(?:sec:\s*(-?\d+))?\s*(?:nsec:\s*(-?\d+))?\s*\}", raw):
        s = int(m.group(1) or 0); n = int(m.group(2) or 0)
        out.append(s + n / 1e9)
    return out

sim, real = blocks("sim_time"), blocks("real_time")
it = [int(x) for x in re.findall(r"iterations:\s*(\d+)", raw)]
if len(sim) < 2 or len(real) < 2:
    print(f"  ! 샘플 부족 (sim={len(sim)} real={len(real)}) — 월드가 안 떴거나 토픽명이 틀렸습니다")
    sys.exit(1)
ds, dr = sim[-1] - sim[0], real[-1] - real[0]
rtf = ds / dr if dr > 0 else 0
print(f"  메시지 {len(sim)}개 · sim +{ds:.3f}s · real +{dr:.3f}s")
print(f"  RTF (endpoint delta) = {rtf:.5f}")

# 정합성 검사 (2026-08-06 추가).
# 관측 창이 WIN 초인데 real 이 그보다 클 수는 없다. 실제로 exp11 에서
# 60초 창에 real +947.475s 가 한 번 나왔다 — sim 은 37.3 으로 이웃 회차
# (39.4, 42.5)와 정상이었고 real 만 터졌으므로 느린 실행이 아니라 깨진
# 측정이다. 그 값(RTF 0.0394)이 조용히 들어가면서 2Hz 평균을 0.814 에서
# 0.556 으로, 폭을 6% 에서 144% 로 만들었다.
# RESULT 줄을 내지 않으면 호출부가 알아서 그 회차를 버린다.
if dr > win * 1.5:
    print(f"  ! real 증가분 {dr:.1f}s 가 관측 창 {win:.0f}s 를 넘습니다 — 불가능한 값입니다.")
    print("    stats 의 real_time 이 튄 것으로 보입니다. 이 측정은 버립니다.")
    sys.exit(2)
if ds > dr * 1.05:
    print(f"  ! sim({ds:.1f}s) 이 real({dr:.1f}s) 을 넘습니다 — RTF>1 은 이 설정에서 불가능합니다.")
    sys.exit(2)
if it:
    print(f"  iterations {it[0]} -> {it[-1]}  (+{it[-1]-it[0]})")
    if it[-1] == it[0]:
        print("  ! iterations 증가 없음 = 완전 정지(stall)")
print(f"RESULT,{label},{rtf:.6f},{ds:.3f},{dr:.3f},{len(sim)}")
PY
rm -f "$TMP"
