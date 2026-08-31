# notes/ — 무엇이 어디에 있나

이 폴더는 검증 과정에서 나온 **원자료와 작업 문서**다. 결론은 저장소 루트의
[`README.md`](../README.md)에 있고, 여기에는 그 결론을 뒷받침하는 것들이 있다.

2026-08-19에 재편했고, 2026-08-29에 재현 가능한 잔여 결함을 후보 패치로 닫은 뒤
현재 판정과 역사 기록을 다시 분리했다.

## 폴더

| 폴더 | 내용 |
|---|---|
| [`upstream/`](upstream/) | 상류 보고 원본·붙여넣기본. bridge lifecycle은 2026-08-31 [issue #951](https://github.com/gazebosim/ros_gz/issues/951)과 signed [PR #952](https://github.com/gazebosim/ros_gz/pull/952)로 제출됐고, 나머지는 미제출이다 |
| [`wiki/`](wiki/) | DAVE Notion Wiki 정정 이력과 범위 |
| [`results/`](results/) | 날짜별 실험 결과와 기계 판독 가능한 요약 |
| [`experiments/`](experiments/) | 실험 스크립트와 공통 측정 절차 |
| [`benchmarks/`](benchmarks/) | 초기 벤치마크와 superseded 결과 |
| [`stability/`](stability/) | 장시간 시험; 폴더명 경고를 먼저 읽어야 한다 |
| [`setup/`](setup/) | 환경 구축 기록 |
| [`evidence/`](evidence/) | 개별 주장 근거 |
| [`meeting/`](meeting/) | 랩 미팅 자료 |

## 현재 기준선 — 2026-08-31

[`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/)은
기존 감사에서 남은 재현 가능한 결함을 수정한 최초 **8개 후보 패치**의 Mac/Docker 결과다.
최종 open-gap sweep에서 fifth-ROV sonar world 누락을 닫은 9번째 후보는
[`results/open_gap_revalidation_2026-08-29/`](results/open_gap_revalidation_2026-08-29/)에 있다.
공식 ArduPilot Gazebo plugin·ArduSub·MAVROS·QGroundControl 통합을 닫은 10번째 후보와 Docker
recipe 근거는 [`results/external_stack_validation_2026-08-29/`](results/external_stack_validation_2026-08-29/)에 있다.
2026-08-30의 DVL LLDB, RViz, Fast DDS, camera startup, 결합 sonar/control,
fresh Docker build와 rendered RDP/QGC 근거는
[`results/final_gap_validation_2026-08-30/`](results/final_gap_validation_2026-08-30/)에 있다.
같은 날 exact Gazebo tag에서 만든 Mac DVL initialization 후보의 baseline·rejected 9/10 후보·20/20 최종 후보·ROS bridge·회귀 근거는
[`results/dvl_macos_force_update_candidate_2026-08-30/`](results/dvl_macos_force_update_candidate_2026-08-30/)에 있다.
Docker software-WGPU/OGRE2 sonar crash의 최소 재현, 폐기 후보, WGPU 2회·auto·CPU 회귀와
Heavy+ArduSub/MAVROS 결합 통과 근거는
[`results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/`](results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/)에 있다.
그 후보의 20회 cold start, Heavy 3회 반복, process-group 종료 10회와 bounded 30분 soak는
[`results/multibeam_deferred_backend_extended_validation_2026-08-30/`](results/multibeam_deferred_backend_extended_validation_2026-08-30/)에 있다.
CPU·배포 WGPU·정확히 relink한 exact-N 후보의 6개 장면 수치 대조는
[`results/multibeam_backend_equivalence_matrix_2026-08-30/`](results/multibeam_backend_equivalence_matrix_2026-08-30/),
integrated ocean-waves world의 직접 payload·stats·resource snapshot은
[`results/integrated_sonar_payload_validation_2026-08-30/`](results/integrated_sonar_payload_validation_2026-08-30/),
세 BlueROV image/source sensor contract 분리는
[`results/bluerov_sensor_contract_validation_2026-08-30/`](results/bluerov_sensor_contract_validation_2026-08-30/)에 있다.
2026-08-31에는 Fast DDS 160-create stress, focused bridge teardown와 ownership-cycle 후보,
sensor long/multi, camera six-tag, USBL namespace, sonar determinism/cache,
clean ocean-sonar/manipulation replay, Ocean Current noise/tide controls를 추가했다. Bridge 후보는
[`results/parameter_bridge_cycle_fix_validation_2026-08-31/`](results/parameter_bridge_cycle_fix_validation_2026-08-31/)에 있고,
나머지 근거는 같은 날짜의 `results/*_2026-08-31/` 폴더에 있다. 특히 tide는 global topic이 아니라
documented per-model output으로 판정한다. DAVE와 Gazebo 후보는 여전히 격리본이며 해당
설치 workspace를 바꾸지 않았다. 예외는 `ros_gz_bridge` ownership 후보로, 이후 실제 사용자
`ros_gz` workspace에 적용·빌드하고 signed upstream PR #952까지 열었다.

검증된 후보 패치 범위:

- Multibeam WGPU의 한 평면 장면 gross range shift, 4096-bin GPU 경계와 명시적 CUDA 실패 경로
- Underwater Camera R/B 의미론
- SeaPressure ROS 계약과 여섯 설정 제어
- Spherical 입력 검증·실패 상태·paused/no-config·plugin discovery
- DVL 8/8 descriptor 초기화, frame ID, water-mass 변수
- USBL `sigma=0`, paused callback, 이동 표적, fractional delay
- object missing-descriptor preflight, launch headless/debug/non-TTY, 18/18 world 이름
- Ocean/Spherical/sonar package plugin-discovery hooks와 Release build 안내
- `dave_ocean_waves`의 fifth-ROV sonar용 `MultibeamSonarSystem` world 누락
- 세 BlueROV variant ArduSub의 명시적 speedup, 공식 Gazebo plugin, MAVROS 통합 제어와 baseline QGroundControl 경로
- `ros_gz_bridge` handle→owner strong-reference cycle와 DAVE-sonar shutdown-only exit -11
- 현재 Dockerfile의 fresh `--no-cache` 빌드(66.917분, 6,260,137,751 bytes), pin/package 검사, real RDP/XFCE framebuffer와 Gazebo+QGC connected replay; 이전 cache image의 세 variant full control

여전히 열린 범위는 Docker hardware WGPU/NVIDIA CUDA, macOS RViz의 영구 창 수정,
QGroundControl 기본 AppRun의 GLib 충돌(검증 recipe는 opt-out 적용), sonar 30 Hz·ROV/Glider
calibration 결정, Fuel immutable pin/upload, Windows/WSL·실물 gamepad/HIL과 일반
음향·광학·유체역학·장시간 정확도다. Mac stock DVL crash는 exact-tag 후보에서 hidden camera 없이
20/20 복구됐고 ROS four-beam bridge와 camera/no-render 회귀도 통과했다. 다만 후보는 격리 빌드일 뿐
Homebrew/상류 Gazebo에 적용되지 않아 배포 경로는 여전히 PARTIAL이다. Heavy-multibeam의
distributed software-WGPU/llvmpipe 경로는 exit 139를 재현하지만, 격리 startup-order 후보는
fresh WGPU cold start 20/20, Heavy arm/control/disarm 3/3과 bounded 1,861초 soak를 통과했다.
teardown baseline은 no-publisher 40/40·stock active 30/30 clean이지만 DAVE-sonar active one-way
9/10과 PointCloud-only 2/10이 SIGSEGV였다. Exact-`ros_gz` 3.0.9 ownership-cycle 후보는
bridge-first 20/20 clean, process-group 10/10 rc0, direct ROS→GZ 20/20과 stock active
camera/PointCloud 5/5 each를 통과했다. 제한된 upstream package suite는 17/18 CTest target이
통과했고, 유일한 remote-schema `xmllint` timeout도 canonical schema를 로컬로 공급한 exact XML
검사에서 통과했다. 따라서 로컬 재현 결함은 후보에서 닫혔다. 이어 normal isolated install에서 8/8 topic, 1/1 ControlWorld service, active teardown 10/10을 통과했고 official-image ARM64 Humble/Jazzy/Kilted branch-local overlay도 각각 8/8+1/1과 clean bridge exit를 통과했다. Apple-Silicon 위 Jazzy `linux/amd64` Docker 에뮬레이션도 같은 8/8+1/1을 통과했다. ordinary-layout 격리 복제본은 24/24 방향(고유 topic type pair 13개)과 exact-3.0.9 service factory 4/4를 통과했다. 이후 실제 사용자 `ros_gz` workspace에도 후보를 적용해 기존 CMake 편집 2건을 보존한 채 빌드했고, 모든 generated topic mapping 73쌍을 양방향으로 생성해 payload 73/73 each, ordered bridge rc0, 반복 payload 5/5와 lifecycle 11/11을 통과했다. 다만 ordered component는 topic 3/3·service 1/1 assertion 뒤 `bridge_node`가 SIGINT에서 139로 종료돼 별도 macOS teardown 결함으로 남는다. issue [#951](https://github.com/gazebosim/ros_gz/issues/951)과 signed PR [#952](https://github.com/gazebosim/ros_gz/pull/952)이 열려 있다. upstream maintainer merge, native x86_64 hardware, Windows와 hardware GPU는 외부 범위다. Fast DDS create
hang은 2026-08-31 dirty/20-SIGKILL/clean/UDP stress 160/160에서도 재현되지 않았고, exact camera Quickstart는
120초 창에서 default 3/3·UDP 3/3 통과해 이전 짧은 대기 실패를 startup latency로 정정했다.
이전 exact cache image는 Windows App RDP login/rendering과 QGC vehicle connection을 통과했다.
current recipe도 fresh `--no-cache`로 66.917분에 완주했고, 별도 FreeRDP/xrdp 세션에서 Xorg/XFCE framebuffer와 Gazebo+QGC connected 화면을 다시 통과했다. 두 클라이언트 실행을 같은 것으로 섞지 않는다.

이전 날짜의 직접 검증 폴더는 삭제하지 않는다. 2026-08-29 패치가 무엇을 바꿨는지
확인하려면 이전 실패 근거와 현재 결과를 함께 읽어야 한다.

## 이 층의 파일

루트 [`README.md`](../README.md) 는 입구 역할만 한다. 상류 저장소(`IOES-Lab/dave`,
`dockwater`)의 README 도 그렇게 쓰므로 형식을 맞췄다. 실제 내용은 아래에 있다.

| 파일 | 내용 |
|---|---|
| [`what-we-got-wrong.md`](what-we-got-wrong.md) | **틀렸던 주장과 그걸 잡아낸 경위.** 여기 수치를 믿기 전에 읽을 것 |
| [`validation_matrix.csv`](validation_matrix.csv) | 검증 항목 전체 표. **무엇이 PASS 이고 무엇이 안 해본 것인지**의 기준 |
| [`verified-demos.md`](verified-demos.md) | 각 판정이 무엇에 근거하는지 |
| [`known-issues.md`](known-issues.md) | 49개 항목(열림·후보 패치 해결·철회 이력 포함), 현재 처리는 문서 맨 위 표 참고 |
| [`progress-log.md`](progress-log.md) | 날짜별 작업 112행. 무엇이 나중에 뒤집혔는지가 Notes 열에 있다 |
| [`sonar-performance.md`](sonar-performance.md) | 소나 측정값과 이전 수치를 대체한 경위 |
| [`patch-and-pinned-commits.md`](patch-and-pinned-commits.md) | 고정 커밋과 이식 패치의 현재 상태 |
| [`next-steps.md`](next-steps.md) | 아직 열려 있는 항목 |
| [`status-history.md`](status-history.md) | 옛 상태 요약. 어떤 주장이 언제 철회됐는지 추적용 |
| [`cmake-migration-patterns.md`](cmake-migration-patterns.md) | Harmonic→Jetty 이식에서 반복된 패턴 |
| [`usbl-gui-crash-investigation.md`](usbl-gui-crash-investigation.md) | USBL 크래시 추적. 초기 가설(GUI 문제)이 틀렸던 과정이 남아 있다 |

## 읽는 순서

처음이면 루트 [`README.md`](../README.md) → [`validation_matrix.csv`](validation_matrix.csv) →
[`progress-log.md`](progress-log.md) → 관심 있는 항목의 [`results/`](results/) 하위 폴더.

상류 보고를 맡았다면 [`upstream/submit/README.md`](upstream/submit/README.md) 하나만 보면 된다.

## 폐기된 자료를 지우지 않는 이유

`SUPERSEDED_*`, `CONTAMINATED`, `PRE_LEAKFIX_SCRIPT` 가 붙은 것들은 **틀린 결과이지만
남겨둔다.** 어떤 수치가 언제 왜 바뀌었는지 추적할 수 있어야 하고, 지우면 그 이력이
사라진다. 인용할 때는 이름에 붙은 표시를 먼저 볼 것.
