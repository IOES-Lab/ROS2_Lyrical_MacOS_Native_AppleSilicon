# 남은 일

## 기준

2026-08-29에 현재 Mac·Docker에서 재현하고 판별할 수 있던 로컬 결함은 10개 후보 패치
그룹으로 수정·검증했다. 상류 DAVE checkout과 사용자 설치 workspace는 수정하지 않았으므로,
아래의 `[x]`는 **격리된 후보 패치에서 검증 완료**라는 뜻이지 상류 병합 완료가 아니다.

근거: [`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/) ·
[`results/external_stack_validation_2026-08-29/`](results/external_stack_validation_2026-08-29/) ·
패치 순서: [`../patches/README.md`](../patches/README.md).

## 후보 패치로 닫힌 재현 가능 결함

- [x] WGPU non-power-of-two range-bin 처리와 explicit CUDA 실패 시 CPU fallback
- [x] Underwater Camera R/G/B 의미론
- [x] SeaPressure Pa/Pa²·깊이 부호·saturation·noise·rate·frame/topic 계약
- [x] Spherical invalid-input rejection·명시적 status·paused/no-config·plugin discovery
- [x] DVL frame ID·water-variable·8개 descriptor far-boundary
- [x] USBL `sigma<=0`·paused callback·fractional propagation delay
- [x] Ocean/Spherical/sonar plugin-discovery hook
- [x] launch server-only/headless/debug·non-TTY keyboard·object preflight·Release 안내·18/18 world 이름
- [x] fifth ROV sonar가 쓰이는 `dave_ocean_waves` world의 `MultibeamSonarSystem` 누락
- [x] 세 BlueROV ArduSub launch의 invalid default speedup 경계 — 명시적 `--speedup 1`

## 현재 재검증에서 닫힌 failure 판정

- [x] **Docker DAVE multibeam `ogre2` 현재 재검증** — 2026-08-29 isolated server run에서 실제 PointCloud를 발행해 2026-08-03 crash를 재현하지 못했다. software WGPU는 실패 후 CPU fallback했으며, 과거 crash의 image/state trigger 차이는 미확정이다.
- [x] **세 BlueROV variant Docker 통합 control loop** — pinned official ArduPilot Gazebo plugin과 `--speedup 1` 후보로 ArduSub FPE를 제거했다. 기존 baseline·Heavy bounded run에 이어 exact current image에서 baseline·Heavy·Heavy-multibeam이 각각 MAVROS 4/4 connected, MANUAL force-arm, 6초 manual control과 disarm을 통과했다. X 이동은 exact image에서 +1.697915 m, +1.125856 m, +0.818825 m였다. QGroundControl은 별도 baseline control에서 `QGC_NO_SYSTEM_GLIB=1`로 연결됐고 기본 AppRun exit 139는 required workaround로 남긴다.
- [x] **현재 Dockerfile cache-assisted end-to-end build** — 44.86분, 23.9GB, image `af9586fa8045`; package/source pin, plugin dependency, installed config 3/3와 exact-image control을 확인했다.
- [x] **Heavy-multibeam sonar+control 결합 snapshot 직접 실행** — exact image source에 ninth sonar-world 후보를 live-apply하고 `dave_worlds`를 재빌드했다. `llvmpipe` WGPU 첫 probe 60053 ms와 513×301×399 설정 뒤 Gazebo stack trace가 시작됐고, ArduSub는 JSON을 받지 못해 MAVROS·PointCloud2·control에 도달하지 못했다. 결합 시험의 미실행 gap은 닫혔지만 기능 판정은 FAIL/PARTIAL이다.

## 아직 열린 환경·외부 스택 항목

- [ ] **Mac stock Gazebo Sensors DVL SIGSEGV** — DAVE 밖 official DVL 예제에서도 재현된다.
  DAVE-local DVL 결함은 Docker 후보 패치에서 닫혔지만 이 플랫폼 crash는 별개다.
- [ ] **Docker hardware WGPU·NVIDIA CUDA** — 현재 컨테이너는 `/dev/dri`/NVIDIA/Cargo가 없고
  sonar는 CPU fallback이다. explicit-unavailable fallback만 Mac에서 검증했다.
- [ ] **macOS 기본 RViz 창 생성** — process/node는 생기지만 window 0인 재현이 남아 있다.
- [ ] **Fuel immutable pin/account upload, Windows/WSL, USB/gamepad/해양 HIL** — prerequisite가
  생기기 전에는 PASS/FAIL로 추론하지 않는다.
- [ ] **Fast DDS 과거 간헐 create hang trigger** — 2026-08-29 최소 통제는 SHM 5/5와 UDPv4 5/5 모두 성공해 현재 실패를 재현하지 못했다. 과거 1/9의 stale-segment/플랫폼 trigger를 규명하기 전에는 해결로 단정하지 않는다.
- [ ] **fresh Mac camera 과거 실패 trigger** — 2026-08-29 고유 partition/domain의 exact Quickstart는 3/3 이미지 발행(54/58/72 s)이라 2026-08-27 topic 부재를 재현하지 못했다. 현재 기능 실패가 아니라 과거 환경·격리 차이의 원인 규명 항목이다.
- [ ] **current Docker recipe의 fresh `--no-cache` + exact-image rendered GUI replay** — cache-assisted full build와 exact-image 세 control loop, xrdp service startup, QGC opt-out/offscreen 20초 생존은 PASS다. 현재 약 47GiB만 남았고 무관한 Docker 자산을 삭제하지 않았으므로 fresh build는 하지 않았다. 저장공간을 확보한 뒤 `--no-cache`, 실제 RDP login/rendering, QGC vehicle 연결을 exact image에서 한 번 재현한다.
- [ ] **Heavy-multibeam 결합 Docker 실패 원인 규명·수정** — stack trace가 시작된 뒤 수동 cleanup해 최종 signal/exit code와 완전한 backtrace를 보존하지 못했다. `llvmpipe` 60초 probe, render thread/sonar 상호작용과 JSON starvation 중 어느 것이 원인인지 분리하고, 수정 후 PointCloud2와 arm/control/disarm을 한 session에서 재검증한다.

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
