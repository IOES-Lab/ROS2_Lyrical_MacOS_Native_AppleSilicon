# ROS 2 Lyrical / Gazebo Jetty — DAVE Migration Verification

[DAVE](https://github.com/IOES-Lab/dave)(수중 로봇 시뮬레이션 라이브러리)와 그
멀티빔 소나 플러그인([PR #44](https://github.com/IOES-Lab/dave/pull/44), CUDA 없는 WGPU 백엔드)을
**ROS 2 Lyrical + Gazebo Jetty** 로 올릴 수 있는지 검증한 기록이다.
DAVE 공식 문서는 아직 Jazzy + Harmonic 기준이다.

macOS(Apple Silicon 네이티브)와 Docker(Ubuntu 26.04) 양쪽에서 확인했다.

```text
상태        실험적 / 검증 환경
월드 커버리지  18/18 PASS 수준 · PARTIAL 0 (2026-08-07)
소나 비용     대조군 RTF 0.9974 대비 0.5243 — 1.90배 (n=3)
가장 큰 개선  update_rate 30Hz → 2Hz 로 소나 추가 비용의 75% 제거, 코드 수정 없음
빌드 함정     문서대로 빌드하면 -O 플래그가 없다. Release 로 다시 빌드하면 RTF 2배
```

> **이 저장소는 검증 기록이지 배포물이 아니다.** 여기서 확인한 것은 "빌드되고
> 실행되며 예상한 데이터가 나온다"이고, **음향학적 정확도는 검증한 적이 없다.**

## 무엇을 믿어도 되나

판정 라벨은 이 문서 전체에서 같은 뜻으로 쓴다.

| 라벨 | 뜻 |
|---|---|
| `SMOKE PASS` | 프로세스가 뜨고 시험 구간 동안 죽지 않았다. **토픽 데이터는 확인하지 않았다** |
| `FUNCTIONAL PASS` | 기대한 토픽·서비스·센서 데이터를 실제로 읽어 확인했다 |
| `PARTIAL` | 실행되고 일부 출력은 나오지만 확인된 기능·성능 문제가 있다 |
| `NOT AUTOMATED` | 현재 자동(headless) 경로로는 확인 불가. 다른 방법으로도 불가하다는 뜻은 아니다 |

## 고정한 커밋

빌드 산출물 자체가 비트 단위로 재현되지는 않는다 — 이유는 [Docker 이미지](#docker-이미지) 참고.

| 저장소 | 브랜치 | 커밋 |
|---|---|---|
| `naitikpahwa18/dave` | `wgpu_integration` | [`6aef91c`](https://github.com/IOES-Lab/dave/pull/44/commits/6aef91c823af5da073329b84ba617b572965e79e) ([PR #44](https://github.com/IOES-Lab/dave/pull/44)) |
| `IOES-Lab/dave` | `sonar-demo` (참고용, 검증에 미사용) | `8f6314f` |
| `ArduPilot/ardupilot` | `ArduSub-stable` | `30257f0` |

## 환경

| | macOS (네이티브) | Docker |
|---|---|---|
| OS | macOS 15.7.3, Apple Silicon (M2) | Ubuntu 26.04 Resolute (arm64) |
| ROS 2 | Lyrical (소스 빌드) | Lyrical (apt, `ros-lyrical-desktop`) |
| Gazebo | Jetty (Homebrew) | Jetty 10.4.0 (apt 벤더 빌드) |
| Python | 3.14 | 3.14 |
| GPU | Metal (실제 하드웨어) | Vulkan `llvmpipe` (CPU 소프트웨어 렌더러) |

## 소나 성능 — 현재 값

2026-08-06 에 이전 수치를 전부 대체했다. 세 가지가 바뀌었다.

**빌드 설정** — 워크스페이스가 `-O` 없이 빌드되고 있었다. `Release` 로 다시 빌드하니 RTF 가 2.01배 올랐다.

**측정 조건** — `ros_gz_sim create` 가 Fast DDS 공유메모리에서 무한 대기해서
`FASTDDS_BUILTIN_TRANSPORTS=UDPv4` 를 쓰게 됐다(안 쓰면 스폰이 9번 중 1번만 성공).
소나 기동 판정도 고쳤다 — 옛 판정은 플러그인의 더미 `1 beams` 프레임에 걸려
실제 센서가 아니라 기동 구간을 재고 있었다.

**반복 측정** — 조건마다 n≥2 로 다시 쟀다.

| 조건 | n | 평균 RTF | 폭 |
|---|---|---|---|
| 소나 없음 (대조군) | 3 | 0.9974 | 0.2% |
| 소나 있음, 출하 설정 (30 Hz) | 3 | 0.5243 | 7.9% |
| `update_rate` 10 Hz | 3 | 0.5984 | 4.3% |
| `update_rate` 2 Hz | 2 | 0.8140 | 6.2% |

**소나 비용은 4.5배가 아니라 1.90배다.** 판정 폭은 8% 로 본다.

가장 큰 개선은 코드 수정 없이 나왔다. `blueview_p900` 의 `<update_rate>` 가 도달 불가능한
30 Hz 로 설정돼 있는데 실측은 약 2.8 fps 이고 실물 하드웨어도 데이터시트상 15 Hz 가 상한이다.

반대로 소나를 *빠르게* 만드는 시도는 실패했고 하나는 역효과였다 — 시각화를 생략하니
compute 스레드가 프레임을 2.4배 더 처리해서 RTF 가 40% 나빠졌다.
**이 센서에서는 속도가 아니라 빈도가 손잡이다.**

근거: [`notes/results/`](notes/results/) · 자세한 경위는 [`notes/progress-log.md`](notes/progress-log.md) 의 2026-08-05·08-06 항목


## 검증된 데모

각 판정의 **근거**는 [`notes/verified-demos.md`](notes/verified-demos.md) 에 있다.
아래는 판정만 추린 것이다.

| 데모 | 판정 |
|---|---|
| Multibeam sonar (PR #44, WGPU) — build, adapter selection, sensor output | FUNCTIONAL PASS (scoped) |
| Multibeam sonar (PR #44, WGPU) — simulation-progress stability, `dave_multibeam_sonar` world | PARTIAL |
| REXROV vehicle | FUNCTIONAL PASS |
| ArduSub SITL build + launch (BlueROV2 flight-controller stack) | FUNCTIONAL PASS (scoped) |
| Slocum Glider spawn + sensor/actuator bridges in a DAVE world (`dave_ocean_waves`) | FUNCTIONAL PASS (2026-07-27) |
| BlueROV2 spawn + sensor bridges in a DAVE world (`dave_ocean_waves`) | PARTIAL (2026-07-27) |
| DVL, underwater camera, ocean current, sea pressure | FUNCTIONAL PASS (4/4) |
| USBL | FUNCTIONAL PASS (combined evidence, workaround) |
| Docker RDP desktop (XFCE) | PASS |
| `dave_ocean_waves_sonar` | SMOKE PASS |
| `dave_ocean_waves_sonar_integrated` | PARTIAL |
| `dave_bimanual_example`, `dave_electrical_mating`, `dave_plug_and_socket` (manipulation) | SMOKE PASS (2026-07-27, all 3) |

월드는 `models/dave_worlds/worlds/` 아래 18개가 있고, 전체 표는
[`notes/validation_matrix.csv`](notes/validation_matrix.csv) 다.

## 알려진 문제

25건. 각 항목의 증상·원인·우회는 [`notes/known-issues.md`](notes/known-issues.md) 에 있다.

- `gui`/`headless` launch argument interaction
- The `ogre2` → `ogre` workaround needs an X display, and the documentation does not say so
- WGPU falls back to the CPU compute backend under the Docker X configuration
- OGRE2 unavailable on Ubuntu 26.04 aarch64
- Docker: `dave_multibeam_sonar` segfaults at sensor initialisation as shipped (`ogre2`)
- Two world files share the internal name `oceans_waves`
- `multibeam_sonar_system` missing `package.xml` dependencies
- No vehicle's IMU data reaches ROS — `imu_sensor` omits `<topic>` on all four models
- `ros_gz_sim create` intermittently hangs in Fast DDS, producing a sonar-free world that looks healthy
- `blueview_p900` ships `<update_rate>30</update_rate>`, which the sensor cannot meet and the hardware does not do
- The documented DAVE build produces an unoptimised plugin
- ArduSub SITL build vs. Python 3.14
- `xrdp` group permission (RDP screen setup)
- GNOME was not usable as the RDP desktop in the tested image
- Docker image password
- `--privileged` on `docker run` was tested and found unnecessary for container startup and XFCE/xrdp login
- DAVE Wiki inaccuracies found while cross-checking
- `rosdep install ... || true` was masking a real failure
- `usbl_tutorial.world` crashed the Gazebo server, not the GUI — root-caused and worked around, plugin-level fix still open
- `SphericalCoords.cc`'s Lyrical/Jetty migration patch can silently mask a real conversion failure as zero/origin, in *both* conversion directions
- Build output prints "Compiling against Gazebo Harmonic" even though this is a Gazebo Jetty build
- Resolved 2026-07-27 (was PRELIMINARY):
- `dave_multibeam_sonar` world is unreliable/unbenchmarkable under ROS 2 Lyrical + Gazebo Jetty
- `dave_world.launch.py` had no headless mode, blocking the 3 manipulation worlds — fixed and confirmed on all 3, 2026-07-27
- mavros built from source and validated

이 중 6건은 상류 보고 문서로 정리했다 — [`notes/upstream/submit/`](notes/upstream/submit/) 참고.

## 재현

주석 붙은 전체 절차는 [`notes/setup/reproduction.md`](notes/setup/reproduction.md) 에 있다.
명령마다 왜 그 인자가 필요한지가 적혀 있으니 처음 따라 할 때는 그쪽을 볼 것.

**빠뜨리면 안 되는 것 하나** — 모든 `colcon build` 에 `--cmake-args -DCMAKE_BUILD_TYPE=Release` 를 붙인다.
없으면 colcon 이 빌드 타입을 비워 두고 **아무것도 `-O` 없이 컴파일된다.**
소나 월드 기준 RTF 0.2180 → 0.4380, 코드 수정 없이 2.01배다.
2026-08-05 이전의 모든 성능 수치는 이것 없이 측정된 것이다.

확인:

```bash
grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
# 빈 결과가 아니라 -O3 가 나와야 한다
```

## 진행 기록

각 행이 무엇을 어떻게 확인했고 무엇이 나중에 뒤집혔는지는
[`notes/progress-log.md`](notes/progress-log.md) 에 Notes 열로 남아 있다.

| 날짜 | 작업 | 결과 |
|---|---|---|
| 2026-07-06 | ROS 2 Lyrical native source build (Mac) | Done |
| 2026-07-06 | Gazebo Jetty apt availability check (Docker) | Failed |
| 2026-07-07 | PR #44 multibeam sonar without Nvidia (Jazzy+Harmonic, Mac Metal) | Done |
| 2026-07-07 | `ros_gz` bridge build for Lyrical+Jetty (Mac) | Done |
| 2026-07-08 | DAVE core packages ported to Lyrical+Jetty (Mac) | Done |
| 2026-07-08 | Gazebo Jetty source build retry (Docker) | Done |
| 2026-07-11 | DAVE + PR #44 sonar demo actually run in Docker | Done |
| 2026-07-13 | Mac vs Docker frame timing measured | Done |
| 2026-07-13 | Confirmed Ubuntu 26.04 is the official target OS for ROS 2 Lyrical | Done |
| 2026-07-13 | REXROV vehicle launch verified | Done |
| 2026-07-13 | Real GUI confirmed visually via RDP (Docker) | Done |
| 2026-07-14 | Full world list catalogued (18 worlds) | Done |
| 2026-07-14 | DVL / underwater camera / ocean current / sea pressure sensors verified; USBL attempted | PASS 4 / PARTIAL 1 |
| 2026-07-14 | BlueROV2 + ArduSub SITL built and launched | Done |
| 2026-07-14 | `git diff --stat` compared Mac vs Docker | Done |
| 2026-07-15 | Root-caused Docker RDP desktop crash | Done |
| 2026-07-15 | Clean (`--no-cache`) Docker build + RDP re-verified | Done |
| 2026-07-17 | Docker CA-certificate bootstrap fix + clean (`--no-cache`) rebuild (Docker) | Done |
| 2026-07-18 | Ocean Current service names verified against a running container (Docker) | Done |
| 2026-07-18 | Tested narrowing `--privileged` on `docker run` (Docker) | Done |
| 2026-07-18 | `rosdep \ | \ |
| 2026-07-20 | RAM/CPU measured under an active demo workload (Docker) | Done |
| 2026-07-20 | Added and fully validated Lyrical/Jetty support for `dockwater` (Docker) | Done, end-to-end |
| 2026-07-20 | Added xrdp/XFCE to `lyrical/Dockerfile` and root-caused + fixed the resulting RDP black-screen bug (Docker) | Done, end-to-end |
| 2026-07-22 | Defined `validation_matrix.csv` + `test_worlds.sh` (August prerequisite) | Done |
| 2026-07-22 | USBL crash — source-level root-cause investigation (initial pass) | Superseded same day |
| 2026-07-22 | Ran `test_worlds.sh` for the first time (6/18 worlds; 10 skipped by design, 2 out of scope) — **USBL root cause CONFIRMED** | Done |
| 2026-07-22 | USBL crash — fix applied and verified live | Done |
| 2026-07-22 | Root-caused `dave_robot.launch.py`'s `robot_config.py` gap, then swept 7 more worlds (11/18 → all PASS) | Done |
| 2026-07-22 | `new_dvl.world` bug fixed and verified live | Done |
| 2026-07-22 | Found and fixed a process-cleanup bug in `test_worlds.sh`/`benchmark_worlds.sh`; ran quantitative benchmark (RTF + CPU/RAM) | Done |
| 2026-07-22 | Started long-duration stability test | In progress |
| 2026-07-22 | Baked the USBL and `new_dvl` world-file fixes into the Docker image build | Done |
| 2026-07-22 | Resolved the `sonar-demo`-branch discrepancy (now PASS) and root-caused the 3 manipulation worlds' untestability | Done |
| 2026-07-23 | Reviewed the long-duration stability test — CRASHED, initially looked like a real DAVE bug | Done |
| 2026-07-23 | Root-caused the "crash" to leftover test-script processes, not a DAVE bug — fixed cleanup in all 4 scripts | Done |
| 2026-07-23 | Ran the bug-fixed Mac benchmark end-to-end; reproduced and characterized a real `dave_multibeam_sonar` performance/stability issue | Done, with an open finding |
| 2026-07-23 | Re-ran the Docker benchmark with the same fixed methodology; confirmed `dave_multibeam_sonar` is broken on *both* platforms, not a Mac-only quirk | Done, with an open finding |
| 2026-07-23 | Documentation audit — resolved contradictions between the latest findings and how they were phrased in `README.md`/`docker/README.md` | Done |
| 2026-07-23 | Fixed the macOS reproduction section and added a `main`-branch banner | Done |
| 2026-07-23 | Fifth documentation/code audit — fixed a broken CSV row, real process-group cleanup, a stability-test leak-detection gap, `test_worlds.sh` classifier bugs, and remaining reproduction/traceability gaps | Done, two items still open |
| 2026-07-23 | Branch synchronization and closed the two remaining reproduction gaps from the row above | Done |
| 2026-07-23 | Sixth documentation/code audit — signal-handling, cross-platform, and factual-accuracy fixes | Done |
| 2026-07-27 | Retrieved and reviewed the 2026-07-23 clean 4h stability re-run — found it also predates the real fix, like the benchmark finding above | Preliminary, clean rerun still needed |
| 2026-07-27 | Re-ran the Mac/Docker RTF benchmark clean, using the current post-`fc48555` scripts | Done |
| 2026-07-27 | First BlueROV2 spawn test inside a DAVE world (`dave_ocean_waves`) | PARTIAL |
| 2026-07-27 | First Slocum Glider spawn test inside a DAVE world (`dave_ocean_waves`) | Done |
| 2026-07-27 | Fixed `dave_world.launch.py`'s missing headless mode, unblocking the manipulation worlds | Done, 1/3 confirmed |
| 2026-07-27 | Re-tested `dave_electrical_mating` and `dave_plug_and_socket` with the `dave_world.launch.py` headless fix — all 3 manipulation worlds now confirmed | Done |
| 2026-07-29 | Live-debugged and closed `usbl_tutorial`'s remaining FUNCTIONAL PASS gap — found and worked around a second real bug (`paused:=false`), after ruling out several red herrings | Done — upgraded PARTIAL → FUNCTIONAL PASS |
| 2026-07-29 | Re-investigated `dave_multibeam_sonar`'s simulation-progress stall in Docker | Refined finding, not yet root-caused |
| 2026-07-29 | Completed a genuinely clean 4h stability re-run, closing the long-open gap | Done |
| 2026-07-29 | Re-investigated `dave_ocean_waves_sonar_integrated`'s simulation-progress in Docker with the same corrected method | Superseded a stale figure |
| 2026-07-31 | Established the first no-sonar control baseline for `dave_multibeam_sonar` on Mac, re-measured the world with the sonar enabled, and identified a sensor-initialisation delay that invalidates several earlier short-window measurements | Refined finding — Mac figure not reproduced |
| 2026-08-03 | Mapped `dave_multibeam_sonar`'s startup phase continuously on Mac and reproduced the 2026-07-23 stall symptom | Root-caused — the 2026-07-23 stall was the startup window |
| 2026-08-03 | Attempted the Docker re-measurement; found the world no longer starts, and found the 2026-07-29 Docker RTF figure was read from the wrong topic | **Figure withdrawn** — no valid Docker measurement exists |
| 2026-08-03 | Measured `dave_ocean_waves_sonar_integrated` on Mac for the first time with the corrected method | Two prior claims refuted |
| 2026-08-03 | Ray-traversal hypothesis tested by sweeping sonar max range on Mac | Refuted — range has no effect |
| 2026-08-05 | Identified what the sonar's ~4.5x cost actually scales with, and replaced the settle criterion that had been invalidating measurements | **Root cause found — ~90% of the cost is proportional to ray count** |
| 2026-08-05 | Re-ran `exp1` (range) and `exp4` (integrated) under the stepping criterion | **One conclusion corrected, two confirmed** |
| 2026-08-05 | Separated the sonar compute stage from the raycast using `raySkips` | **Compute is not the bottleneck — ~8% of the overhead** |
| 2026-08-05 | Found the workspace builds with no optimisation, and rebuilt the sonar packages `Release` | **Two thirds of the sonar cost was build configuration** |
| 2026-08-05 | Profiled the running process instead of inferring from RTF deltas | **The leading hypothesis was wrong** |
| 2026-08-06 | Attributed the TBB pool, by controlled comparison | **It is the sonar's, via OpenCV** |
| 2026-08-06 | Root-caused the intermittent spawn hang that had been blocking measurement | **Fast DDS shared-memory transport, not DAVE or Gazebo** |
| 2026-08-06 | Re-established both baselines after the DDS switch and the settle fix | **Sonar cost is 1.90x, not 4.5x** |
| 2026-08-06 | Tried three interventions; the one that backfired showed why | **Frequency is the knob, not speed** |
| 2026-08-06 | Fixed six measurement-tool defects, two of which had already corrupted results | **All of them silently produced wrong numbers** |
| 2026-08-07 | Reclassified the two PARTIAL rows in the validation matrix, whose stated grounds no longer held | **17/18 PASS-level, 1 PARTIAL** |
| 2026-08-07 | Closed the vehicle axis of the validation matrix — the world axis had been complete for weeks, the vehicle axis never was | **No vehicle's IMU had ever reached ROS** |
| 2026-08-07 | Ran a stock `gpu_lidar` with no DAVE code, to answer the question blocking the Docker crash report | **The two Docker failures have different causes and only one is DAVE's** |
| 2026-08-07 | Gave the Docker container a properly authorised X display and re-ran the sonar world | **It runs. 18/18 PASS-level, 0 PARTIAL** |
| 2026-08-07 | Echoed the sonar's `PointCloud2` on Mac, closing the traceability gap in this file's own Purpose statement | **Confirmed, on the WGPU GPU path** |

## Patch

[`patches/dave_lyrical_jetty_migration_mac.diff`](patches/dave_lyrical_jetty_migration_mac.diff) — base commit [`6aef91c`](https://github.com/IOES-Lab/dave/pull/44/commits/6aef91c823af5da073329b84ba617b572965e79e) on `naitikpahwa18/dave` (`wgpu_integration`, part of [PR #44](https://github.com/IOES-Lab/dave/pull/44)), currently **8 files changed, +177/−152** (updated 2026-07-23, second pass: +1/−1 from the previous +176/−151 figure, from fixing the 4th remaining stale "Compiling against Gazebo Harmonic" build-log message in `dave_gz_sensor_plugins/CMakeLists.txt`, confirmed present via `sed` on the real checkout and now corrected to say "Jetty" — see Known issues; +176/−151 itself was +4/−4 from the original +172/−147, from the first 3 message fixes plus 1 stale comment fix). The original +172/−147 version was verified to apply identically and produce identical `git diff --stat` output on both macOS and Docker/Ubuntu 26.04, and rebuilt successfully on both (2026-07-14) — that full rebuild-and-compare has **not** been independently re-run against the current +177/−152 version; all 5 message/comment-text-only additions apply cleanly (each confirmed against the real checkout) but haven't themselves been rebuilt on either platform to reconfirm the build still succeeds, though they're single string literals with no logic change. Full pattern breakdown in [`notes/cmake-migration-patterns.md`](notes/cmake-migration-patterns.md).

## Docker image

A verified, repeatable Docker build procedure (build instructions, verification commands, RDP desktop) lives in [`docker/`](docker/) — see [`docker/README.md`](docker/README.md) for the full build/run/verify walkthrough. **Caveat (added 2026-07-23):** "repeatable," not bit-for-bit reproducible — the Dockerfile intentionally pulls a few floating dependencies (plain `apt-get install` with no version pins, Firefox via `firefox-latest-ssl`, QGroundControl via a `DailyBuild` AppImage URL with no version/commit pin), so a rebuild weeks or months later can legitimately produce a different image than the one actually tested, even from the exact same Dockerfile.

## 남은 일

- [ ] **상류 보고 7건 제출** — 전부 작성 완료, 하나도 안 보냄. 6건은 이슈 초안,
  1건은 문서 정정이다. 붙여넣기용 변환본과 제출 순서는
  [`notes/upstream/submit/README.md`](notes/upstream/submit/README.md) 에 있다.
  `IOES-Lab/dave` 는 공개 저장소이고 Issues 가 열려 있어 계정만 있으면 된다
- [ ] **DAVE 문서 오류 보고** — [`notes/wiki/wiki-error-report-final-EN.md`](notes/wiki/wiki-error-report-final-EN.md) 를 전달.
  문서는 GitHub wiki 가 아니라 `dave-ros2.notion.site` 이므로 PR 이 아니라 코멘트·메시지다.
  보내기 전에 [`notes/wiki/ogre-x-display-doc-correction.md`](notes/wiki/ogre-x-display-doc-correction.md) 를 합칠 것
- [ ] **`package.xml` 의존성 수정을 상류에 제안** — 이슈가 아니라 fork 후 PR 이어야 한다.
  OGRE2 미지원 건도 같이
- [ ] **저장소 이름 변경** — `ROS2_Lyrical_MacOS_Native_AppleSilicon` → `ROS2_Lyrical`.
  현재 이름은 macOS·Apple Silicon 만 말하지만 Docker/Linux 도 다뤘다.
  **조직 owner 만 할 수 있다** — 이 저장소에 대한 권한이 Maintain 이라 설정에 이름 칸이 없다.
  문서의 절대 URL 은 옛 이름으로 두었다. GitHub 이 옛 이름을 새 이름으로 리다이렉트하므로
  지금도 이름을 바꾼 뒤에도 동작한다 (반대 방향은 안 된다)
- [ ] **소나 확장 방향 결정** — Profiling / Mechanical scanning / Side-scan.
  장비 분류·스펙·타 시뮬레이터 현황은 Notion 「소나 종류 분류」 에,
  코드 구조와 논문 수식 대응은 Notion 「DAVE 소나 코드 구조」 에 정리했다.
  **이 문서들은 결정하지 않는다** — 어느 응용을 지원할지, 정확도를 어떻게 검증할지,
  대조할 실장비가 있는지가 먼저다

완료된 항목의 이력은 [`notes/progress-log.md`](notes/progress-log.md) 에 있다.

## References

- [DAVE (IOES-Lab fork)](https://github.com/IOES-Lab/dave)
- [PR #44 (IOES-Lab/dave)](https://github.com/IOES-Lab/dave/pull/44) — vendor-agnostic WGPU sonar backend
- [Pinned commit `6aef91c` (naitikpahwa18/dave, wgpu_integration)](https://github.com/naitikpahwa18/dave/commit/6aef91c823af5da073329b84ba617b572965e79e)
- [DAVE ROS2 Wiki](http://dave-ros2.notion.site)
- [ROS 2 Lyrical Luth — official docs](https://docs.ros.org)
- Choi, W.-S., "Ray-Based Physical Modeling and Simulation of Multibeam Sonar for Underwater Robotics in ROS-Gazebo Framework," *Sensors* **2025**, *25*(5), 1516. [10.3390/s25051516](https://doi.org/10.3390/s25051516) — **this is the method [PR #44](https://github.com/IOES-Lab/dave/pull/44) implements.** Ray-based: the scene is captured with the Gazebo GPU Ray plugin, an acoustic model is applied per ray, rays are combined into beams, beam-pattern effects are assessed, then windowing and FFT produce range-intensity data. Its stated advantage over the raster-based approach is controllable data resolution at equal image quality.
- Choi, W. et al., "Physics-based modelling and simulation of Multibeam Echosounder perception for Autonomous Underwater Manipulation," *Frontiers in Robotics and AI*, 2021. [10.3389/frobt.2021.706646](https://doi.org/10.3389/frobt.2021.706646) — the earlier raster-based work this repository's sonar lineage descends from, retained for context.

**Citation check (2026-08-05):** both papers are real and distinct; they are not
alternative citations for the same work. Until this check the README listed only
the 2021 Frontiers paper, which describes the *raster-based* method — while the
entire sonar subject of this repository is the *ray-based* backend of PR #44,
described in the 2025 Sensors paper. The 2025 paper is now listed first. A
monthly-report deck cited Sensors 2025 for the ray-based content, which was
correct; the mismatch was in this README.
