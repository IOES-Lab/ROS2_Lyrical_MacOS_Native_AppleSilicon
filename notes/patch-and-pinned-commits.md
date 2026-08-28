<!-- README.md 에서 분리했다. 2026-08-19, 상류 저장소(IOES-Lab/dave, dockwater)의
     README 형식에 맞추면서 옮긴 것이다 — 그쪽 README 는 입구 역할만 하고
     내용은 별도 문서에 둔다. 내용은 그대로다. -->

# 패치와 고정 커밋

## 고정한 커밋


빌드 산출물 자체가 비트 단위로 재현되지는 않는다 — 이유는 [`docker/README.md`](../docker/README.md) 참고.

| 저장소 | 브랜치 | 커밋 |
|---|---|---|
| `naitikpahwa18/dave` | `wgpu_integration` | [`6aef91c`](https://github.com/IOES-Lab/dave/pull/44/commits/6aef91c823af5da073329b84ba617b572965e79e) ([PR #44](https://github.com/IOES-Lab/dave/pull/44)) |
| `IOES-Lab/dave` | `sonar-demo` (참고용, 검증에 미사용) | `8f6314f` |
| `ArduPilot/ardupilot` | `ArduSub-stable` | `30257f0` |

## 패치


[`patches/dave_lyrical_jetty_migration_mac.diff`](../patches/dave_lyrical_jetty_migration_mac.diff) — base commit [`6aef91c`](https://github.com/IOES-Lab/dave/pull/44/commits/6aef91c823af5da073329b84ba617b572965e79e) on `naitikpahwa18/dave` (`wgpu_integration`, part of [PR #44](https://github.com/IOES-Lab/dave/pull/44)), currently **8 files changed, +177/−152** (updated 2026-07-23, second pass: +1/−1 from the previous +176/−151 figure, from fixing the 4th remaining stale "Compiling against Gazebo Harmonic" build-log message in `dave_gz_sensor_plugins/CMakeLists.txt`, confirmed present via `sed` on the real checkout and now corrected to say "Jetty" — see Known issues; +176/−151 itself was +4/−4 from the original +172/−147, from the first 3 message fixes plus 1 stale comment fix). The original +172/−147 version was verified to apply identically and produce identical `git diff --stat` output on both macOS and Docker/Ubuntu 26.04, and rebuilt successfully on both (2026-07-14) — that full rebuild-and-compare has **not** been independently re-run against the current +177/−152 version; all 5 message/comment-text-only additions apply cleanly (each confirmed against the real checkout) but haven't themselves been rebuilt on either platform to reconfirm the build still succeeds, though they're single string literals with no logic change. Full pattern breakdown in [`notes/cmake-migration-patterns.md`](cmake-migration-patterns.md).


## 2026-08-29 후보 패치 기준선

새 8개 패치는 raw `6aef91c`에 독립적으로 적용하는 패치가 아니다. `6aef91c` 위에 이 문서의
기존 Jetty/Lyrical migration과 runtime 수정이 들어간 2026-08-29 테스트 기준선을 대상으로
생성했다. 순서와 범위는 [`../patches/README.md`](../patches/README.md), 해시와 적용 검사는
[`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/)에 있다.

상류 checkout과 설치 workspace는 read-only로 유지했다. 따라서 "해결"은 해당 후보 패치를
적용한 격리 snapshot에서 재현 실패가 사라졌다는 뜻이며, 상류 병합이나 사용자 설치 반영을
뜻하지 않는다.
