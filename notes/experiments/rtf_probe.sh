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
if it:
    print(f"  iterations {it[0]} -> {it[-1]}  (+{it[-1]-it[0]})")
    if it[-1] == it[0]:
        print("  ! iterations 증가 없음 = 완전 정지(stall)")
print(f"RESULT,{label},{rtf:.6f},{ds:.3f},{dr:.3f},{len(sim)}")
PY
rm -f "$TMP"
