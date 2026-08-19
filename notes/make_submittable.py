#!/usr/bin/env python3
"""make_submittable.py — 초안을 GitHub 이슈에 그대로 붙일 수 있는 형태로 변환한다.

왜 스크립트인가:
  초안이 6건이고 각각 링크가 여러 개다. 손으로 고치면 하나쯤 빠뜨리고,
  빠뜨린 링크는 이슈에서 깨진 채로 남는다. 변환 규칙을 한 곳에 둔다.

무엇을 바꾸나:
  1) Status / Suggested target / Suggested labels 블록 제거.
     그건 우리 메모지 이슈 본문이 아니다. 대신 제목/대상/라벨을 파일 맨 위에
     주석으로 따로 뽑아서, 복사할 때 헷갈리지 않게 한다.
  2) 상대 링크를 절대 URL 로. GitHub 이슈는 다른 리포의 상대 경로를 해석하지
     못하므로 그대로 두면 전부 깨진다.
       (results/foo/)        -> .../blob/main/notes/results/foo/
       (notes/results/foo/)  -> .../blob/main/notes/results/foo/
       (../patches/foo.diff) -> .../blob/main/patches/foo.diff
       (experiments/foo.sh)  -> .../blob/main/notes/experiments/foo.sh
  3) '## Title' 섹션을 본문에서 빼고 헤더로 올린다. 이슈 제목 칸에 들어갈 값이다.

출력: notes/submit/<이름>.md
"""
import re
import sys
from pathlib import Path

REPO = "https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon"
BLOB = f"{REPO}/blob/main"
TREE = f"{REPO}/tree/main"

HERE = Path(__file__).resolve().parent
OUT = HERE / "submit"

DRAFTS = [
    "vehicle-imu-topic-issue-draft.md",
    "build-type-issue-draft.md",
    "updaterate-issue-draft.md",
    "usbl-upstream-issue-draft.md",
    "world-name-collision-issue-draft.md",
    "docker-sonar-crash-issue-draft.md",
]


def absolutise(md: str) -> str:
    """마크다운 링크의 상대 경로를 절대 URL 로 바꾼다."""
    def fix(m):
        text, target = m.group(1), m.group(2)
        if target.startswith(("http://", "https://", "#")):
            return m.group(0)
        t = target.lstrip("./")
        while t.startswith("../"):
            t = t[3:]
        # notes/ 하위 경로들을 정규화한다. 초안마다 기준이 달라서
        # results/... 로도 notes/results/... 로도 쓰여 있다.
        if t.startswith("notes/") or t.startswith("patches/") or t.startswith("docker/"):
            path = t
        elif t.startswith(("results/", "experiments/")) or t.endswith(".md"):
            path = f"notes/{t}"
        else:
            path = t
        base = TREE if path.endswith("/") else BLOB
        return f"[{text}]({base}/{path.rstrip('/')}{'/' if path.endswith('/') else ''})"
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", fix, md)


def convert(path: Path) -> tuple[str, str, str, str]:
    """-> (제목, 대상, 라벨, 본문)"""
    s = path.read_text()

    title = ""
    m = re.search(r"^## Title\s*\n(.*?)(?=\n## )", s, re.S | re.M)
    if m:
        title = " ".join(m.group(1).split())
        s = s[: m.start()] + s[m.end():]

    target = ""
    m = re.search(r"\*\*Suggested target(?: repo)?:\*\*(.*?)(?=\n\*\*|\n---)", s, re.S)
    if m:
        target = " ".join(m.group(1).split())

    labels = ""
    m = re.search(r"\*\*Suggested labels:\*\*(.*)", s)
    if m:
        labels = m.group(1).strip()

    # 헤더 블록(첫 '---' 까지)과 최상단 제목 줄을 제거한다.
    s = re.sub(r"^# .*?\n", "", s, count=1)
    s = re.sub(r"^.*?\n---\n", "", s, count=1, flags=re.S)

    s = absolutise(s).strip()
    return title, target, labels, s


def main() -> int:
    OUT.mkdir(exist_ok=True)
    made = []
    for name in DRAFTS:
        src = HERE / name
        if not src.exists():
            print(f"  ! 없음: {name}")
            continue
        title, target, labels, body = convert(src)
        if not title:
            print(f"  ! '## Title' 을 못 찾음: {name}")
            continue
        dst = OUT / name.replace("-issue-draft", "").replace("-upstream", "")
        dst.write_text(
            f"<!-- 제출 대상: {target}\n"
            f"     라벨:     {labels}\n"
            f"     원본:     notes/{name}\n"
            f"     자동 생성: notes/make_submittable.py — 직접 고치지 말 것 -->\n\n"
            f"## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)\n\n"
            f"{title}\n\n"
            f"## 이슈 본문 (아래 전체를 본문 칸에 붙여넣기)\n\n"
            f"---\n\n{body}\n"
        )
        made.append((dst.name, title))
        print(f"  {dst.relative_to(HERE.parent)}")

    print(f"\n  {len(made)}건 생성")
    print("\n  남은 상대 링크 검사:")
    bad = 0
    for f in OUT.glob("*.md"):
        for m in re.finditer(r"\[([^\]]+)\]\((?!https?://|#)([^)]+)\)", f.read_text()):
            print(f"    ! {f.name}: {m.group(2)}")
            bad += 1
    print("    없음" if not bad else f"    {bad}건 남음")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
