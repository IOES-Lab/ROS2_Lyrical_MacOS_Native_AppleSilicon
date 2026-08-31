# 남은 일

## 기준

2026-08-29에 현재 Mac·Docker에서 재현하고 판별할 수 있던 로컬 결함은 10개 후보 패치
그룹으로 수정·검증했고, 2026-08-30에는 Mac DVL과 Docker software-WGPU sonar startup의
격리 후보 2개를 추가했다. 2026-08-31에는 teardown focus 뒤 `parameter_bridge` ownership-cycle
후보, sensor long/multi, USBL namespace, camera six-tag, fixed-seed sonar, Ocean tide/noise와
Docker world replay를 더했다. 대부분의 DAVE/Gazebo 후보는 여전히 격리본이지만,
`ros_gz_bridge` ownership 후보는 2026-08-31 실제 사용자 workspace에도 적용·빌드·검증했다.
아래의 `[x]`는 **명시된 후보 범위에서 검증 완료**라는 뜻이지 상류 병합 완료가 아니다.

근거: [`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/) ·
[`results/external_stack_validation_2026-08-29/`](results/external_stack_validation_2026-08-29/) ·
[`results/dvl_macos_force_update_candidate_2026-08-30/`](results/dvl_macos_force_update_candidate_2026-08-30/) ·
[`results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/`](results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/) ·
[`results/multibeam_deferred_backend_extended_validation_2026-08-30/`](results/multibeam_deferred_backend_extended_validation_2026-08-30/) ·
[`results/multibeam_backend_equivalence_matrix_2026-08-30/`](results/multibeam_backend_equivalence_matrix_2026-08-30/) ·
[`results/parameter_bridge_cycle_fix_validation_2026-08-31/`](results/parameter_bridge_cycle_fix_validation_2026-08-31/) ·
패치 순서: [`../patches/README.md`](../patches/README.md).

## 후보 패치로 닫힌 재현 가능 결함

- [x] WGPU non-power-of-two range-bin 처리와 explicit CUDA 실패 시 CPU fallback
- [x] Underwater Camera R/G/B 의미론
- [x] SeaPressure Pa/Pa²·깊이 부호·saturation·noise·rate·frame/topic 계약
- [x] Spherical invalid-input rejection·명시적 status·paused/no-config·plugin discovery
- [x] DVL frame ID·water-variable·8개 descriptor far-boundary
- [x] Mac Gazebo Sensors custom-DVL `forceUpdate` main-thread initialization race — exact-tag candidate 20/20, camera/no-render 3/3
- [x] USBL `sigma<=0`·paused callback·fractional propagation delay
- [x] Ocean/Spherical/sonar plugin-discovery hook
- [x] launch server-only/headless/debug·non-TTY keyboard·object preflight·Release 안내·18/18 world 이름
- [x] fifth ROV sonar가 쓰이는 `dave_ocean_waves` world의 `MultibeamSonarSystem` 누락
- [x] 세 BlueROV ArduSub launch의 invalid default speedup 경계 — 명시적 `--speedup 1`
- [x] Docker software-WGPU/`llvmpipe` sonar startup crash — deferred-backend candidate runtime scope passes.
- [x] `parameter_bridge` shutdown-only owner/handle cycle — focused baseline은 DAVE-sonar group shutdown 9/10 exit -11이었고 signal/order/tracing/node-reset 후보는 실패했다. WeakPtr 후보는 bridge-first 20/20 clean, process-group 10/10 rc0, direct ROS→GZ 20/20, stock active camera/PointCloud 5/5 each를 통과했다. Normal isolated install과 cross-distribution matrix에 이어 실제 사용자 workspace에서도 빌드, 24/24 bounded directions, generated mapping 73/73 payload each direction, repeat 5/5, lifecycle 11/11과 ordered bridge rc0를 통과했다. Issue [#951](https://github.com/gazebosim/ros_gz/issues/951)과 signed PR [#952](https://github.com/gazebosim/ros_gz/pull/952)이 열려 있다. 다만 ordered component는 3/3 topic·1/1 service assertion 뒤 `bridge_node` exit 139라 별도 결함으로 남는다.

## 현재 재검증에서 닫힌 failure 판정

- [x] **Docker DAVE multibeam `ogre2` 2026-08-29 CPU-fallback 재검증** — 당시 isolated server run은 실제 PointCloud를 발행했고 software WGPU 초기화 실패 뒤 CPU fallback했다. 이 제한된 결과는 아래 2026-08-30 최소 distributed baseline의 software-WGPU exit 139 및 deferred-backend 후보 검증으로 supersede됐다.
- [x] **세 BlueROV variant Docker 통합 control loop** — pinned official ArduPilot Gazebo plugin과 `--speedup 1` 후보로 ArduSub FPE를 제거했다. 기존 baseline·Heavy bounded run에 이어 earlier exact cache image에서 baseline·Heavy·Heavy-multibeam이 각각 MAVROS 4/4 connected, MANUAL force-arm, 6초 manual control과 disarm을 통과했다. X 이동은 exact cache image에서 +1.697915 m, +1.125856 m, +0.818825 m였다. QGroundControl은 별도 baseline control에서 `QGC_NO_SYSTEM_GLIB=1`로 연결됐고 기본 AppRun exit 139는 required workaround로 남긴다.
- [x] **현재 Dockerfile cache-assisted end-to-end build** — 44.86분, 23.9GB, image `af9586fa8045`; package/source pin, plugin dependency, installed config 3/3와 exact-image control을 확인했다.
- [x] **Heavy-multibeam sonar+control 결합 snapshot 직접 실행·backend 분리·startup 후보 반복 검증** — 첫 rerun은 distributed software WGPU/`llvmpipe`의 OGRE2 null-`memcpy` exit 139와 forced-CPU PASS를 분리했다. startup-order 후보는 이후 3/3 독립 session에서 PointCloud2 513×301·raw sonar 513×399, MAVROS connect/arm, 100 controls, X 0.624–0.687 m(중앙값 0.667 m), disarm을 모두 통과했다. local candidate 범위에서는 backend failure가 닫혔고 distributed/upstream 범위는 아직 PARTIAL이다.

## 아직 열린 환경·외부 스택 항목

- [ ] **Mac DVL candidate의 upstream/Homebrew 적용과 독립 review** — stock control은 계속 exit 139다. predicate-only v1은 9/10이라 폐기했고, main-thread init 완료 전 render-thread handoff를 막는 v2는 unmodified official world 20/20, camera 3/3, no-render 3/3, ROS bridge four-good-beam을 통과했다. 현재 남은 것은 로컬 재현 결함이 아니라 상류 설계 검토·병합·배포 설치다.
- [ ] **Docker hardware WGPU·NVIDIA CUDA** — 현재 컨테이너는 `/dev/dri`/NVIDIA가 없고,
  retained candidate의 WGPU 검증은 software Vulkan `llvmpipe`다. NVIDIA CUDA와 실제 Docker
  hardware WGPU의 성능·수치·startup behavior는 검증하지 않았다.
- [ ] **macOS 기본 RViz 창 영구 수정** — CoreGraphics는 RViz의 640×508 Cocoa/OGRE main window를 `onscreen=false`로 보고한다. 네 plain Qt/OpenGL controls는 모두 onscreen이고 software GL, scale/layer/fullscreen, splash/show/orderFront 후보는 실패했다. RViz–OGRE Cocoa external-NSView integration까지 좁혔지만 visible-window fix는 없다.
- [ ] **Fuel immutable pin/account upload, Windows/WSL, USB/gamepad/해양 HIL** — prerequisite가
  생기기 전에는 PASS/FAIL로 추론하지 않는다. 필요한 장비·계정과 공식 절차는
  [`remaining_external_validation_plan.md`](results/final_gap_validation_2026-08-30/remaining_external_validation_plan.md)에
  실행 순서로 남겼다.
- [ ] **Fast DDS 과거 간헐 create hang의 인과 trigger** — 2026-08-31 fresh-Docker stress is 160/160 success across dirty default, 20-SIGKILL injection, official SHM cleanup and UDPv4 phases (40 each; max 5.861 s). The historical host 1/9 cause is still unproven, so only causal diagnosis remains open.
- [x] **fresh Mac camera 과거 짧은 대기 실패 재판정** — exact Quickstart를 120초 창으로 default 3/3·UDPv4 3/3 반복했고 topic은 89.520–105.333초, image는 93.029–110.431초에 나타났다. 이전 짧은 관측의 topic 부재는 current camera/Fast DDS 결함이 아니라 이 환경의 startup latency였다.
- [x] **current Docker recipe의 fresh `--no-cache` build와 rendered replay** — official BuildKit cache prune 뒤 current recipe가 66.917분, return code 0으로 완주했고 package/pin/artifact 검사가 통과했다. fresh image의 FreeRDP/xrdp login은 Xorg `:10`·XFCE를 만들었고, framebuffer에서 Gazebo와 QGC Ready/Manual을 확인했으며 MAVROS는 `connected: true`, MANUAL이었다. 이전 exact cache image의 Windows App replay와 fresh FreeRDP replay는 별도 근거로 보존한다.
- [ ] **Heavy-multibeam hardware GPU 대조·bridge 상류 merge·macOS component teardown** — deferred-backend startup/control/soak와 fixed-seed determinism은 후보 범위에서 통과했다. `parameter_bridge`는 actual-workspace 적용과 generated topic 73쌍 양방향 payload까지 끝났고 PR #952가 열렸다. 남은 것은 maintainer review/merge, native x86_64, Windows, 실제 Docker hardware WGPU/NVIDIA CUDA다. 별도로 ordered `bridge_node`는 payload/service 4/4 뒤 SIGINT exit 139, test helper는 mutex abort가 남아 있어 ownership PR의 완료 범위와 분리한다.

## 과학적·장시간·설계 범위

- [ ] Multibeam 일반 acoustic accuracy와 hardware-GPU/실물 대조. Fixed seed 12345 and frame index 0 produced byte-identical raw/point arrays across three fresh containers and nine frames, so deterministic reproducibility is closed. CPU/WGPU full raw-array equality is not a valid oracle because the backends intentionally use different phase/noise algorithms.
- [ ] Underwater Camera 여러 색·재질·산란 장면의 일반 optical accuracy. 여섯 attenuation/background 태그의 개별 semantic-channel 동작은 8-camera/10-frame matrix에서 0 LSB analytic error로 닫혔다.
- [ ] Ocean Current/SeaPressure/USBL/DVL의 계수·실해양·mission-endurance 정확도. Bounded multi-device/namespace controls are closed: SeaPressure 7 devices/2,000 noisy frames, DVL 8 devices/160 messages, USBL 2 transceivers/4 transponders; Ocean Gauss–Markov and per-model tide data paths also pass synthetic controls.
- [ ] ROV/Glider actuator calibration, navigation, battery depletion and long dynamics.
- [ ] `blueview_p900` 30 Hz 설정을 hardware/algorithm 목표에 맞출지 결정.
- [ ] 소나 확장 방향(Profiling / Mechanical scanning / Side-scan)과 검증용 실장비 결정.

## 상류·관리 결정

- [ ] 2026-08-29~31 후보 패치를 상류 이슈/PR 단위로 분리하고 API 호환성 검토.
  특히 Spherical의 세 response `success` 필드는 breaking interface change다.
- [ ] 상류 이슈 기록 11건 중 bridge lifecycle은 [gazebosim/ros_gz#951](https://github.com/gazebosim/ros_gz/issues/951), signed fix는 [gazebosim/ros_gz#952](https://github.com/gazebosim/ros_gz/pull/952)로 제출 완료(DCO PASS, review/merge 대기). 나머지 10건은 제출 여부·명의·순서 결정 대기. 9번은 WGPU range-grid,
  10번은 deferred-backend startup, 11번은 `gazebosim/ros_gz` bridge ownership cycle이며 기존
  6번은 historical/do-not-file이다.
- [ ] `package.xml` 의존성 PR, 저장소 이름 변경, LICENSE 선택.
- [ ] macOS ROS 2 Lyrical 소스 빌드의 기록 누락 단계 복원.

## 완료 이력

- [x] Ocean Current global 12 services, per-depth/two-namespace model path, vehicle response, 400-sample Gauss–Markov variation and per-model tidal oscillation.
- [x] SeaPressure seven-device bounded run and 2,000-frame noise statistics; DVL eight-device/160-message descriptor-rate matrix.
- [x] USBL two-transceiver/four-transponder namespace isolation and concurrent interrogation.
- [x] Underwater Camera all six attenuation/background tags isolated against analytic BGR predictions.
- [x] Fixed-seed/frame exact-N sonar determinism across three fresh containers; clean Docker replay of all three manipulation worlds and `dave_ocean_waves_sonar`.
- [x] Spherical valid-input independent WGS-84 oracle (4 regions, 13 points).
- [x] DAVE Notion Wiki 검증 페이지들의 현재 판정 갱신 — 2026-08-29 후보 패치 문구는
  코드가 upstream에 이미 반영된 것으로 오독되지 않게 별도 표시한다.

전체 날짜별 이력은 [`progress-log.md`](progress-log.md)에 있다.
