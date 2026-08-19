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

     경로는 추측하지 않는다. 초안 파일이 있는 디렉터리를 기준으로 링크를
     실제로 해석해서, 저장소 루트 기준 경로를 얻는다. 2026-08-19 에 notes/ 를
     재편하면서 예전의 접두사 추측 방식(results/ 로 시작하면 notes/ 를 붙인다는
     식)이 전부 틀리게 됐다. 파일이 실제로 없으면 경고하고 원본을 남긴다.
  3) '## Title' 섹션을 본문에서 빼고 헤더로 올린다. 이슈 제목 칸에 들어갈 값이다.

출력: notes/upstream/submit/<이름>.md
"""
import re
import sys
from pathlib import Path

REPO = "https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon"
BLOB = f"{REPO}/blob/main"
TREE = f"{REPO}/tree/main"

HERE = Path(__file__).resolve().parent          # notes/upstream
DRAFT_DIR = HERE / "drafts"
OUT = HERE / "submit"
ROOT = HERE.parent.parent                        # 저장소 루트

DRAFTS = [
    "vehicle-imu-topic-issue-draft.md",
    "build-type-issue-draft.md",
    "updaterate-issue-draft.md",
    "usbl-upstream-issue-draft.md",
    "world-name-collision-issue-draft.md",
    "docker-sonar-crash-issue-draft.md",
]

warnings: list[str] = []


def absolutise(md: str, base: Path, source: str) -> str:
    """마크다운 링크의 상대 경로를 절대 URL 로 바꾼다.

    base 는 링크가 쓰인 파일이 있는 디렉터리다. 링크를 거기서 해석해
    저장소 루트 기준 경로로 만든다.
    """
    def fix(m):
        text, target = m.group(1), m.group(2)
        if target.startswith(("http://", "https://", "mailto:", "#")):
            return m.group(0)

        path, _, frag = target.partition("#")
        if not path:
            return m.group(0)

        resolved = (base / path).resolve()
        try:
            rel = resolved.relative_to(ROOT)
        except ValueError:
            warnings.append(f"{source}: 저장소 밖을 가리킴 — {target}")
            return m.group(0)

        if not resolved.exists():
            warnings.append(f"{source}: 대상 없음 — {target}")
            return m.group(0)

        url = f"{TREE if resolved.is_dir() else BLOB}/{rel.as_posix()}"
        if resolved.is_dir():
            url += "/"
        return f"[{text}]({url}{'#' + frag if frag else ''})"

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

    s = absolutise(s, path.parent, path.name).strip()
    return title, target, labels, s


def main() -> int:
    OUT.mkdir(exist_ok=True)
    made = []
    for name in DRAFTS:
        src = DRAFT_DIR / name
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
            f"     원본:     notes/upstream/drafts/{name}\n"
            f"     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->\n\n"
            f"## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)\n\n"
            f"{title}\n\n"
            f"## 이슈 본문 (아래 전체를 본문 칸에 붙여넣기)\n\n"
            f"---\n\n{body}\n"
        )
        made.append((dst.name, title))
        print(f"  {dst.relative_to(ROOT)}")

    print(f"\n  {len(made)}건 생성")

    if warnings:
        print("\n  링크 경고:")
        for w in warnings:
            print(f"    ! {w}")

    print("\n  남은 상대 링크 검사:")
    bad = 0
    for f in OUT.glob("*.md"):
        # README.md 는 리포 안에서 읽히는 목차라 상대 링크가 정상이다.
        # 이슈 본문으로 붙여넣는 파일이 아니므로 검사에서 제외한다.
        if f.name == "README.md":
            continue
        for m in re.finditer(r"\[([^\]]+)\]\((?!https?://|#)([^)]+)\)", f.read_text()):
            print(f"    ! {f.name}: {m.group(2)}")
            bad += 1
    print("    없음" if not bad else f"    {bad}건 남음")
    return 1 if (bad or warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
