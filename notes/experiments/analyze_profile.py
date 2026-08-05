#!/usr/bin/env python3
"""analyze_profile.py — macOS sample(1) 출력을 제대로 읽는다.

왜 따로 만들었나 (2026-08-05):
  exp8_profile.sh 의 첫 판이 grep -c 로 요약을 냈는데, 그건 심볼이 등장한
  *줄 수*였다. sample 출력에서 한 줄은 서로 다른 콜스택 경로 하나이고
  실제 무게는 줄 앞의 숫자다. 그래서 "FillPointCloudMsg 6" 같은 값이 나왔고,
  그대로 읽으면 6샘플로 오독하게 된다. 경로가 6개라는 뜻일 뿐이다.

  또 하나: sample 은 자고 있는 스레드도 전부 샘플링한다. 25개 스레드가
  모두 총 5946 샘플로 찍히는데 대부분 __psynch_cvwait 에서 대기 중이다.
  필터 없이 합계를 내면 유휴 시간이 결과를 지배한다.

이 스크립트가 하는 일:
  1) 스레드별 총 샘플 / 유휴 / 실제 작업 샘플을 나눈다
  2) 작업 중인 스레드만 골라 self time (스택 최상단) 상위를 뽑는다
  3) 관심 함수의 포함 시간(inclusive)을 스레드별로 집계한다

사용법:
  python3 analyze_profile.py /tmp/exp8_profile_XXXX.txt
"""
import re
import sys
from collections import defaultdict

# 스택 최상단이 이거면 그 샘플은 '자고 있는' 것으로 본다. CPU 를 안 쓴다.
IDLE = (
    "__psynch_cvwait", "__psynch_mutexwait", "mach_msg2_trap", "mach_msg_trap",
    "__semwait_signal", "semaphore_wait_trap", "kevent", "kevent_id", "__select",
    "__poll", "poll", "__workq_kernreturn", "__accept", "__recvfrom", "__read",
    "read", "nanosleep", "__ulock_wait", "start_wqthread", "thread_start",
)

WATCH = [
    ("FillPointCloudMsg",   r"FillPointCloudMsg"),
    ("ComputeSonarImage",   r"ComputeSonarImage"),
    ("MultibeamSonarSensor",r"MultibeamSonarSensor"),
    ("OnNewFrame",          r"OnNewFrame"),
    ("gz-rendering",        r"libgz-rendering"),
    ("gz-sensors",          r"libgz-sensors"),
    ("gz-sim",              r"libgz-sim"),
    ("GpuRays",             r"GpuRays"),
    ("Metal / MTL",         r"\bMTL|Metal"),
    ("libm trig",           r"_platform_cos|_platform_sin|\b__cos\b|\b__sin\b|\bcos\b|\bsin\b"),
    ("sonar_wgpu (Rust)",   r"sonar_wgpu"),
]

# "  5946 Thread_5870460   DispatchQueue_1: com.apple.main-thread  (serial)"
THREAD = re.compile(r"^\s*(\d+)\s+Thread_(\w+)(.*)$")
# 트리 줄: 앞의 들여쓰기/트리문자, 카운트, 심볼
NODE = re.compile(r"^(\s*(?:[+!:|]\s*)*)(\d+)\s+(\S.*?)\s*$")


def main(path):
    lines = open(path, errors="replace").read().splitlines()

    threads = []          # (tid, label, total, idle, busy, [(count, sym, depth)])
    cur = None
    in_graph = False

    for ln in lines:
        if ln.startswith("Call graph:"):
            in_graph = True
            continue
        if in_graph and (ln.startswith("Total number in stack")
                         or ln.startswith("Sort by top of stack")
                         or ln.startswith("Binary Images:")):
            in_graph = False
        if not in_graph:
            continue

        m = THREAD.match(ln)
        if m:
            cur = {"tid": m.group(2), "label": m.group(3).strip(),
                   "total": int(m.group(1)), "nodes": []}
            threads.append(cur)
            continue
        if cur is None:
            continue
        m = NODE.match(ln)
        if m:
            depth = len(m.group(1))
            cur["nodes"].append((int(m.group(2)), m.group(3), depth))

    if not threads:
        print("! Call graph 를 못 찾았습니다. sample 출력이 맞는지 확인하세요.")
        return 1

    # --- self time: 각 스레드에서 자식이 없는(=최상단) 노드 ------------------
    # 다음 줄의 depth 가 현재보다 크지 않으면 그 노드가 리프다.
    for t in threads:
        leaves = []
        ns = t["nodes"]
        for i, (c, sym, d) in enumerate(ns):
            is_leaf = (i + 1 >= len(ns)) or (ns[i + 1][2] <= d)
            if is_leaf:
                leaves.append((c, sym))
        t["leaves"] = leaves
        t["idle"] = sum(c for c, s in leaves if any(k in s for k in IDLE))
        t["busy"] = sum(c for c, s in leaves) - t["idle"]

    total_busy = sum(t["busy"] for t in threads)
    grand = max((t["total"] for t in threads), default=0)

    print("=" * 74)
    print(f" 파일 {path}")
    print(f" 스레드 {len(threads)}개 · 스레드당 총 샘플 {grand}")
    print(f" 실제 CPU 를 쓴 샘플 합계: {total_busy}")
    print("=" * 74)

    print("\n===== 스레드별 (작업 샘플 많은 순) =====")
    print(f"  {'busy':>7} {'idle':>7}  {'busy%':>6}  thread")
    for t in sorted(threads, key=lambda x: -x["busy"]):
        if t["busy"] == 0:
            continue
        pct = 100.0 * t["busy"] / total_busy if total_busy else 0
        lbl = t["label"] or f"Thread_{t['tid']}"
        print(f"  {t['busy']:>7} {t['idle']:>7}  {pct:>5.1f}%  {lbl[:48]}")
    idle_only = sum(1 for t in threads if t["busy"] == 0)
    print(f"  (완전히 유휴한 스레드 {idle_only}개 생략)")

    # --- 전역 self time 상위 -----------------------------------------------
    self_time = defaultdict(int)
    for t in threads:
        for c, sym in t["leaves"]:
            if any(k in sym for k in IDLE):
                continue
            self_time[clean(sym)] += c

    print("\n===== self time 상위 20 (스택 최상단, 유휴 제외) =====")
    print("  이게 실제로 CPU 를 태운 곳입니다.")
    if not self_time:
        print("  (없음 — 샘플 구간에 CPU 작업이 거의 없었다는 뜻입니다)")
    for sym, c in sorted(self_time.items(), key=lambda x: -x[1])[:20]:
        pct = 100.0 * c / total_busy if total_busy else 0
        print(f"  {c:>7} {pct:>5.1f}%  {sym[:62]}")

    # --- 관심 함수 포함 시간 (CPU 만) ---------------------------------------
    # 2026-08-05 수정. 첫 판은 매칭된 노드의 카운트를 그대로 더했는데, 그
    # 카운트에는 그 서브트리 안에서 *막혀 있던* 시간이 다 들어간다. 그래서
    # gz-sim 이 124% 로 나왔다 — 분모는 busy 인데 분자는 대기를 포함했다.
    # 이제는 유휴가 아닌 리프만 세고, 그 리프의 조상 사슬에 심볼이 있으면
    # 그쪽으로 귀속시킨다. 즉 "이 함수 아래에서 실제로 CPU 를 태운 시간".
    rxs = [(name, re.compile(pat)) for name, pat in WATCH]
    incl = defaultdict(int)
    incl_thread = defaultdict(lambda: defaultdict(int))

    for t in threads:
        stack = []                       # [(depth, sym)]
        ns = t["nodes"]
        lbl = t["label"] or f"Thread_{t['tid']}"
        for i, (c, sym, d) in enumerate(ns):
            while stack and stack[-1][0] >= d:
                stack.pop()
            stack.append((d, sym))
            is_leaf = (i + 1 >= len(ns)) or (ns[i + 1][2] <= d)
            if not is_leaf:
                continue
            if any(k in sym for k in IDLE):
                continue                 # 자고 있던 샘플은 CPU 가 아니다
            chain = [s for _, s in stack]
            for name, rx in rxs:
                if any(rx.search(s) for s in chain):
                    incl[name] += c
                    incl_thread[name][lbl] += c

    print("\n===== 관심 함수 아래에서 실제로 태운 CPU (busy inclusive) =====")
    print("  막혀 있던 시간은 뺐습니다. 분모는 위의 busy 합계입니다.")
    for name, _ in WATCH:
        c = incl.get(name, 0)
        pct = 100.0 * c / total_busy if total_busy else 0
        print(f"  {c:>7} {pct:>5.1f}%  {name}")
        for lbl, cc in sorted(incl_thread[name].items(), key=lambda x: -x[1])[:3]:
            print(f"          {cc:>7}   ({lbl[:44]})")

    # --- 양보/경합이 어디서 나오는지 ----------------------------------------
    # swtch_pri / psynch_* 는 계산이 아니라 '남을 기다리며 CPU 를 태우는' 것이다.
    # 이게 상위에 오면 병목은 연산량이 아니라 직렬화다. 누가 부르는지가 중요.
    SPIN = ("swtch_pri", "__psynch_cvbroad", "__psynch_mutexdrop",
            "__psynch_cvsignal", "os_unfair_lock", "spin")
    print("\n===== 경합 신호 (양보/락) 를 부르는 쪽 =====")
    print("  계산이 아니라 기다리면서 태운 CPU 입니다. 상위면 병목은 직렬화입니다.")
    callers = defaultdict(int)
    spin_total = 0
    for t in threads:
        stack = []
        ns = t["nodes"]
        lbl = t["label"] or f"Thread_{t['tid']}"
        for i, (c, sym, d) in enumerate(ns):
            while stack and stack[-1][0] >= d:
                stack.pop()
            stack.append((d, sym))
            is_leaf = (i + 1 >= len(ns)) or (ns[i + 1][2] <= d)
            if not is_leaf or not any(k in sym for k in SPIN):
                continue
            spin_total += c
            # 시스템 라이브러리가 아닌 가장 가까운 조상 = 실제 호출 주체
            who = "(불명)"
            for _, s in reversed(stack[:-1]):
                if "libsystem" not in s and "dyld" not in s:
                    who = clean(s)
                    break
            callers[f"{who[:52]}  @{lbl[:20]}"] += c
    pct = 100.0 * spin_total / total_busy if total_busy else 0
    print(f"  합계 {spin_total} ({pct:.1f}% of busy)")
    for who, c in sorted(callers.items(), key=lambda x: -x[1])[:12]:
        print(f"  {c:>7}  {who}")

    print("\n" + "=" * 74)
    print(" 판정 (exp8_profile.sh 헤더에 미리 정해둔 기준):")
    print("   FillPointCloudMsg 가 busy 의 상당 부분  -> 삼각함수 패치 정당")
    print("   gz-rendering 이 대부분                   -> 플러그인 패치는 헛수고")
    print("   둘 다 아님                                -> 전제 재검토")
    print()
    print(" 주의: computeThread_ (ComputeSonarImage) 는 아무리 무거워도")
    print("       exp7 이 이미 임계경로 밖으로 배제한 축입니다.")
    print("=" * 74)
    return 0


def clean(sym):
    # "foo(bar)  (in libbaz.dylib) + 123  [0x...]" -> "foo(bar)  (in libbaz.dylib)"
    s = re.sub(r"\s*\+\s*\d+\s*\[0x[0-9a-f]+\]\s*$", "", sym)
    return re.sub(r"\s*\[0x[0-9a-f]+\]\s*$", "", s)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
