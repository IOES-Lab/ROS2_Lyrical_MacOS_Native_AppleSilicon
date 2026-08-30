# 남은 일

## 기준

2026-08-29에 현재 Mac·Docker에서 재현하고 판별할 수 있던 로컬 결함은 10개 후보 패치
그룹으로 수정·검증했다. 상류 DAVE checkout과 사용자 설치 workspace는 수정하지 않았으므로,
아래의 `[x]`는 **격리된 후보 패치에서 검증 완료**라는 뜻이지 상류 병합 완료가 아니다.

근거: [`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/) ·
[`results/external_stack_validation_2026-08-29/`](results/external_stack_validation_2026-08-29/) ·
[`results/dvl_macos_force_update_candidate_2026-08-30/`](results/dvl_macos_force_update_candidate_2026-08-30/) ·
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

## 현재 재검증에서 닫힌 failure 판정

- [x] **Docker DAVE multibeam `ogre2` 현재 재검증** — 2026-08-29 isolated server run에서 실제 PointCloud를 발행해 2026-08-03 crash를 재현하지 못했다. software WGPU는 실패 후 CPU fallback했으며, 과거 crash의 image/state trigger 차이는 미확정이다.
- [x] **세 BlueROV variant Docker 통합 control loop** — pinned official ArduPilot Gazebo plugin과 `--speedup 1` 후보로 ArduSub FPE를 제거했다. 기존 baseline·Heavy bounded run에 이어 earlier exact cache image에서 baseline·Heavy·Heavy-multibeam이 각각 MAVROS 4/4 connected, MANUAL force-arm, 6초 manual control과 disarm을 통과했다. X 이동은 exact cache image에서 +1.697915 m, +1.125856 m, +0.818825 m였다. QGroundControl은 별도 baseline control에서 `QGC_NO_SYSTEM_GLIB=1`로 연결됐고 기본 AppRun exit 139는 required workaround로 남긴다.
- [x] **현재 Dockerfile cache-assisted end-to-end build** — 44.86분, 23.9GB, image `af9586fa8045`; package/source pin, plugin dependency, installed config 3/3와 exact-image control을 확인했다.
- [x] **Heavy-multibeam sonar+control 결합 snapshot 직접 실행·backend 분리** — current rerun이 software WGPU/`llvmpipe`의 OGRE2 null-`memcpy` stack과 Gazebo exit 139를 끝까지 보존했다. 같은 derived candidate의 forced-CPU control은 513×301 PointCloud2, MAVROS MANUAL arm, 100 control messages, X +1.348464 m와 disarm을 한 session에서 통과했다. 결합 기능은 backend-dependent다.

## 아직 열린 환경·외부 스택 항목

- [ ] **Mac DVL candidate의 upstream/Homebrew 적용과 독립 review** — stock control은 계속 exit 139다. predicate-only v1은 9/10이라 폐기했고, main-thread init 완료 전 render-thread handoff를 막는 v2는 unmodified official world 20/20, camera 3/3, no-render 3/3, ROS bridge four-good-beam을 통과했다. 현재 남은 것은 로컬 재현 결함이 아니라 상류 설계 검토·병합·배포 설치다.
- [ ] **Docker hardware WGPU·NVIDIA CUDA** — 현재 컨테이너는 `/dev/dri`/NVIDIA/Cargo가 없고
  sonar는 CPU fallback이다. explicit-unavailable fallback만 Mac에서 검증했다.
- [ ] **macOS 기본 RViz 창 영구 수정** — CoreGraphics는 RViz의 640×508 Cocoa/OGRE main window를 `onscreen=false`로 보고한다. 네 plain Qt/OpenGL controls는 모두 onscreen이고 software GL, scale/layer/fullscreen, splash/show/orderFront 후보는 실패했다. RViz–OGRE Cocoa external-NSView integration까지 좁혔지만 visible-window fix는 없다.
- [ ] **Fuel immutable pin/account upload, Windows/WSL, USB/gamepad/해양 HIL** — prerequisite가
  생기기 전에는 PASS/FAIL로 추론하지 않는다. 필요한 장비·계정과 공식 절차는
  [`remaining_external_validation_plan.md`](results/final_gap_validation_2026-08-30/remaining_external_validation_plan.md)에
  실행 순서로 남겼다.
- [ ] **Fast DDS 과거 간헐 create hang의 인과 trigger** — dirty pre-clean 5/5, official `fastdds shm clean` 뒤 5/5, 다섯 SIGKILL 주입 뒤 5/5, UDPv4 3/3으로 현재 hang은 18/18에서 미재현이다. 193개 SHM entry와 zombie cleanup은 확인했지만 historical 1/9의 원인임은 입증되지 않았다. 별도로 `ros_gz_sim create --help`는 help 출력 뒤 SHM clean 전후 모두 rc250/mutex abort한다.
- [x] **fresh Mac camera 과거 짧은 대기 실패 재판정** — exact Quickstart를 120초 창으로 default 3/3·UDPv4 3/3 반복했고 topic은 89.520–105.333초, image는 93.029–110.431초에 나타났다. 이전 짧은 관측의 topic 부재는 current camera/Fast DDS 결함이 아니라 이 환경의 startup latency였다.
- [x] **current Docker recipe의 fresh `--no-cache` build와 rendered replay** — official BuildKit cache prune 뒤 current recipe가 66.917분, return code 0으로 완주했고 package/pin/artifact 검사가 통과했다. fresh image의 FreeRDP/xrdp login은 Xorg `:10`·XFCE를 만들었고, framebuffer에서 Gazebo와 QGC Ready/Manual을 확인했으며 MAVROS는 `connected: true`, MANUAL이었다. 이전 exact cache image의 Windows App replay와 fresh FreeRDP replay는 별도 근거로 보존한다.
- [ ] **Heavy-multibeam software-WGPU Docker crash 수정** — current auto run은 OGRE2 GPU-rays sample-texture/null-`memcpy` stack과 exit 139를 보존했다. forced CPU control은 같은 combined snapshot에서 end-to-end PASS하므로 JSON starvation이 독립 원인이라는 옛 추정은 철회한다. 남은 일은 llvmpipe WGPU/renderer interaction 수정과 hardware WGPU 대조다.

## 과학적·장시간·설계 범위

- [ ] Multibeam 일반 acoustic accuracy, full point-cloud/backend equivalence, 여러 형상·거리·재질.
- [ ] Underwater Camera 여러 색·재질·산란 장면의 일반 optical accuracy.
- [ ] Ocean Current/SeaPressure/USBL/DVL의 계수·실해양·장시간·다중장치 정확도.
- [ ] ROV/Glider actuator calibration, navigation, battery depletion and long dynamics.
- [ ] `blueview_p900` 30 Hz 설정을 hardware/algorithm 목표에 맞출지 결정.
- [ ] 소나 확장 방향(Profiling / Mechanical scanning / Side-scan)과 검증용 실장비 결정.

## 상류·관리 결정

- [ ] 2026-08-29 후보 패치를 상류 이슈/PR 단위로 분리하고 API 호환성 검토.
  특히 Spherical의 세 response `success` 필드는 breaking interface change다.
- [ ] 기존 상류 이슈 초안 8건을 새 패치 결과에 맞춰 다시 작성한 뒤 제출 여부·명의·순서 결정.
- [ ] `package.xml` 의존성 PR, 저장소 이름 변경, LICENSE 선택.
- [ ] macOS ROS 2 Lyrical 소스 빌드의 기록 누락 단계 복원.

## 완료 이력

- [x] Ocean Current global 12 services, per-depth/two-namespace model path and vehicle response.
- [x] Spherical valid-input independent WGS-84 oracle (4 regions, 13 points).
- [x] DAVE Notion Wiki 검증 페이지들의 현재 판정 갱신 — 2026-08-29 후보 패치 문구는
  코드가 upstream에 이미 반영된 것으로 오독되지 않게 별도 표시한다.

전체 날짜별 이력은 [`progress-log.md`](progress-log.md)에 있다.
