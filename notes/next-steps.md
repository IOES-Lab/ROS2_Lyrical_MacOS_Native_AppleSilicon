# 남은 일

## 기준

2026-08-29에 현재 Mac·Docker에서 재현하고 판별할 수 있던 로컬 결함은 8개 후보 패치
그룹으로 수정·검증했다. 상류 DAVE checkout과 사용자 설치 workspace는 수정하지 않았으므로,
아래의 `[x]`는 **격리된 후보 패치에서 검증 완료**라는 뜻이지 상류 병합 완료가 아니다.

근거: [`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/) ·
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

## 아직 열린 환경·외부 스택 항목

- [ ] **Mac stock Gazebo Sensors DVL SIGSEGV** — DAVE 밖 official DVL 예제에서도 재현된다.
  DAVE-local DVL 결함은 Docker 후보 패치에서 닫혔지만 이 플랫폼 crash는 별개다.
- [ ] **Docker DAVE multibeam `ogre2` crash** — stock `gpu_lidar`의 OGRE2 동작과 구분된다.
- [ ] **Docker hardware WGPU·NVIDIA CUDA** — 현재 컨테이너는 `/dev/dri`/NVIDIA/Cargo가 없고
  sonar는 CPU fallback이다. explicit-unavailable fallback만 Mac에서 검증했다.
- [ ] **macOS 기본 RViz 창 생성** — process/node는 생기지만 window 0인 재현이 남아 있다.
- [ ] **BlueROV2 통합 MAVROS/QGroundControl과 fifth sonar** — 현재 이미지의 패키지·plugin과
  실장비/네트워크 prerequisite가 부족하다.
- [ ] **Fuel immutable pin/account upload, Windows/WSL, USB/gamepad/해양 HIL** — prerequisite가
  생기기 전에는 PASS/FAIL로 추론하지 않는다.
- [ ] **Fast DDS 간헐적 create hang** — UDPv4 workaround 밖의 middleware 원인 규명.
- [ ] **fresh Mac camera 재현성 차이** — 후보 패치의 통제 world는 Mac/Docker에서 통과했지만,
  2026-08-27 기존 quickstart fresh run의 topic 부재 원인은 별도 재현성 이력으로 남긴다.

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
