# wiki/ — DAVE 문서 정정

DAVE 의 공식 문서는 [`dave-ros2.notion.site`](http://dave-ros2.notion.site) 다. GitHub wiki 가
아니라 노션 사이트이므로, 정정은 PR 이 아니라 페이지를 직접 편집하는 방식이다.

**스물두 차례에 걸쳐 반영했다. 이 폴더의 초안들은 그 근거 기록이다.**

## 1차 — 2026-07-20

[`wiki-error-report-final-EN.md`](wiki-error-report-final-EN.md) 의 4건. 전체 20 페이지를
읽으면서 찾은 것들이다.

| 항목 | 어느 페이지 |
|---|---|
| `dave_robot_launch` 패키지가 존재하지 않음, 토픽 이름도 틀림 | SeaPressure Plugin |
| 빈 페이지 2개 | Create New Robot Model · Build World using Heightmap |
| 같은 주제의 중복 페이지 | Multi-beam Sonar Plugin (하이픈) |
| 브랜치 참조에 링크 없음 | Multibeam Sonar Plugin |

초안 문서에는 아직 "전달 방법 미정"이라고 적혀 있지만 **실제로는 반영이 끝났다.**
2026-08-20 에 확인했다 — SeaPressure 페이지에 `Corrected 2026-07-20` 인용 블록이 있고,
중복 페이지에는 경고 배너가 붙어 있다.

## 2차 — 2026-08-20

7월 이후 검증에서 나온 것들. **문서에 들어갈 성격의 16건**을 12개 페이지에 넣었다.

20 페이지를 하나씩 열어 대조했다. 나머지 5개(Spherical Coordinates, Migration Progress,
빈 페이지 2개, 중복 스텁)는 우리 발견과 겹치는 내용이 없다.

| 항목 | 어느 페이지 | 근거 |
|---|---|---|
| 빌드에 `-O` 플래그가 없음 | **8곳** — 설치 매뉴얼 2 · 모델 4 · DVL · Underwater Camera | RTF 0.2180 → 0.4380 |
| `<sigma>0.0</sigma>` 이 Gazebo **서버**를 죽임 | USBL Plugin | 튜토리얼 예제가 그 값을 가르치고 있었다 |
| `paused:=false` 없으면 모든 ROS 콜백 차단 | USBL Plugin | Quick Start 명령에 없었다 |
| `update_rate` 30 Hz 도달 불가 · P900 SDF 불일치 | Multibeam Sonar | 데이터시트 "up to 15 Hz" |
| 소나가 145~175초 뒤에야 살아남 | Multibeam Sonar | 그 전 측정은 전부 무효 |
| world 내부 이름 충돌(당시 `oceans_waves` 2파일만 확인, 12차에서 전체 범위 재정정) | Dave World Models | 우리가 실제로 측정을 잘못 귀속시켰다 |
| 차량 IMU 가 ROS 에 도달하지 않음 | ROV · Glider Models | 4대 전후 측정 |
| Fast DDS 스폰 무한 대기 | Installation Tutorial | 공유메모리 1/9, UDPv4 5/5 |
| `gui:=true headless:=true` 조합 | Installation Tutorial | |
| `dave_world.launch.py` headless 부재 | Installation Tutorial | manipulation world 3개가 막혀 있었다 |
| `ogre` 우회에 인가된 X 디스플레이 필요 | Native 매뉴얼 | [`ogre-x-display-doc-correction.md`](ogre-x-display-doc-correction.md) |
| ~~aarch64 OGRE2 미지원~~ · 2026-08-03 소나 segfault · WGPU CPU 폴백 | Docker 매뉴얼 | **OGRE2 미지원은 2026-08-21 철회, 현재 항상-crash 판정은 2026-08-29 철회** — isolated OGRE2 DAVE-sonar run이 PointCloud를 발행했고 software WGPU는 CPU로 fallback |
| **해류 서비스 이름에 네임스페이스 누락** | Ocean Current Plugin | 문서는 `/set_current_velocity`, 실제는 `/hydrodynamics/` 아래. **예제 12개가 그대로는 전부 실패한다** |
| **NVIDIA 카드 필수라는 서술** | Native 매뉴얼 · CUDA 페이지 · System Requirements | PR #44 의 WGPU 로 CUDA 없이 동작. 맥 Metal 에서 PointCloud2 확인 |
| 백엔드가 수치적으로 같지 않음 | CUDA 페이지 | ~~CPU 폴백에는 위상 항이 없다~~ **표현 정정 2026-08-21** — 위상 항은 있다. 다만 거리 기반이 아니다 |
| Lyrical 은 Ubuntu 26.04 필요 | System Requirements | 24.04 에서 `apt-cache search ros-lyrical` 이 빈 결과 |

형식은 1차와 맞췄다 — **기존 문장을 지우지 않고** `Added 2026-08-20` /
`Corrected 2026-08-20` 으로 표시해 무엇이 왜 바뀌었는지 남게 했다.

### 16건이 다 "오류"는 아니다

"오류 16건 정정"이라고 쓰면 과하다. 성격이 넷으로 갈린다.

| 성격 | 건수 | 무엇 |
|---|---|---|
| **문서대로 하면 실패한다** | 4 | USBL `sigma=0`(서버 종료) · USBL `paused` 누락(콜백 차단) · 해류 서비스명(명령 12개 실패) · `ogre` 우회 설명 불완전 |
| **낡은 서술** | 2 | NVIDIA 카드 필수 · Ubuntu 버전 |
| **빌드 설정 누락** | 1건이 8곳에 | 실패하지 않고 성능만 절반이 된다 |
| **우리 검증 결과를 주의사항으로 추가** | 9 | world 이름 충돌 · 차량 IMU · 스폰 무한대기 · 소나 기동 시간 · `update_rate` · P900 SDF 불일치 · aarch64 제약 · 백엔드 차이 · Lyrical/Jetty 맥락 |

**마지막 줄이 절반이다.** 그것들은 위키의 오류가 아니라 **코드의 결함이거나 우리 검증에서 나온 관찰**이고, 읽는 사람이 걸려 넘어지지 않도록 해당 페이지에 경고로 붙인 것이다.

보고서에 쓴다면 **"정정·보완 16건"** 이 정확하다.


## 3차 — 2026-08-21

앞선 두 차례에서 **우리 쪽 서술이 틀렸던 것**을 고친 회차다. 위키의 오류가 아니라
우리가 위키에 붙인 주의사항 두 개가 잘못돼 있었다.

| 항목 | 어디 | 무엇이 틀렸나 |
|---|---|---|
| **aarch64 에서 OGRE2 미지원** | Docker 매뉴얼 · 전체 현황 「핵심 발견 3」 · CMake 패턴 7 | **철회.** stock `gpu_lidar`가 OGRE2에서 3/3 발행했다. DAVE sonar의 2026-08-03 `CreateSampleTexture()` crash도 현재 항상-fails 판정은 아니다: 2026-08-29 같은 컨테이너의 isolated OGRE2 run이 실제 PointCloud를 발행했다. 과거 stack은 날짜 붙은 이력으로만 유지하고 trigger 차이는 미확정으로 둔다 |
| **CPU 폴백에는 위상 항이 없다** | CUDA 페이지 | **부정확.** `sonar_compute_cpu.cc:99-101` 에 위상 항이 있고 복소 진폭 합산도 한다. 틀린 건 그 위상이 **거리에서 나오지 않는다**는 점이다 — CUDA/WGPU 는 `2·d·k` (`sonar_calculation_cuda.cu:284`), CPU 는 beam·ray 인덱스의 결정론적 함수. 백엔드가 다르다는 결론은 유지되지만 근거가 다르다 |
| `xvfb-run -a` 를 검증된 해결책처럼 서술 | CMake 패턴 7 | **미검증.** 시도 기록이 없다. 실제로 통한 건 `DISPLAY=:10` + `XAUTHORITY=/home/docker/.Xauthority` + `-u docker` 이고, `DISPLAY` 만으로는 거부된다(2026-08-03 확인) |
| SeaPressure 를 다른 센서와 묶어 통과로 표기 | 전체 현황 · 저장소 | 발행은 되지만 값이 1000배 틀리고 `<noise_sigma>` 가 무시된다. **liveness 는 통과, 수치 정확성은 아니다** |
| USBL Quick Start 명령 · `Vector3` 타입 표기 | USBL 페이지 | 실제 검증 명령(`paused:=false`)과 실제 타입(`dave_interfaces/msg/Location`)으로 교체 |
| Docker 결과를 PointCloud2 내용 확인처럼 서술 | CUDA 페이지 | 2026-08-07 은 **발행만** 확인했고 내용은 안 봤다. 소나 연산은 CPU 폴백이었다 |

**이 회차의 성격이 앞의 둘과 다르다.** 1·2차는 위키를 고친 것이고, 3차는 **우리가
위키에 잘못 붙인 것을 떼어낸 것**이다. 경위는 [`../what-we-got-wrong.md`](../what-we-got-wrong.md).

## 4차 — 2026-08-25

「Multibeam Sonar Plugin」 페이지에서 직접 실행하지 않았던 예제와 판정을 다시 검증했다.
사용한 DAVE checkout은 commit `6aef91c` 기반의 기존 migration 수정이 남은
작업 트리였으며 pristine 상태가 아니었다. 사용자 정의 센서와 world는 DAVE
checkout에 추가하지 않고 별도 overlay에서 만들었다.

| 항목 | 직접 확인한 판정 |
|---|---|
| Demo wrapper와 원본 `dave_sensor.launch.py` | Mac Metal WGPU에서 PointCloud2 513×301, image/raw sonar 513×399 발행 |
| 기본 RViz launch | 프로세스·구독은 존재하지만 macOS에서 `visible=true, windows=0`; 실제 창은 생성되지 않음 |
| 사용자 정의 sonar/world | 65×61 PointCloud2와 65×319 image/raw sonar 발행 |
| BlueROV2 예제 | 차량은 spawn되지만 선택된 모델에 multibeam sensor가 없어 소나 예제로는 실패 |
| Local Search | Mac Metal WGPU에서 원본 513×301/399 출력 확인 |
| Docker RDP | Gazebo GUI와 강제 CPU backend의 513×399 raw sonar 직접 확인 |
| 평면 3.99 m 표적 | CPU는 5/5 프레임 3.988294 m로 PASS; WGPU는 6.396–6.446 m로 FAIL |
| 명시적 CUDA 요청 | Apple M2에는 CUDA가 없으며, 요청 시 clean rejection이 아니라 Gazebo 종료와 잔류 프로세스 발생 |
| `debug` + `verbosity_level` | 인자가 `-r-v 4`로 붙어 Gazebo exit 109 |

근거:
[`../results/multibeam_direct_validation_2026-08-25/`](../results/multibeam_direct_validation_2026-08-25/).

이 회차는 일반적인 음향 정확도를 입증하지 않는다. 한 평면 장면에서 CPU와 WGPU의
range profile이 다르다는 것까지만 직접 확인했다.

## 5차 — 2026-08-25 Ocean Current 직접 재검증

「Ocean Current Plugin」 페이지의 서비스 예제와 실행 범위를 Mac Lyrical+Jetty에서
직접 확인했다.

- `/hydrodynamics/` 아래 사용자 서비스 12개의 실제 타입과 정상·비정상 호출 확인
- Constant/Stratified/Gauss-Markov 출력 변경과 원상복구 확인
- 전역 `/ocean_current`가 REXROV 운동을 바꾸는 paired trial 확인
- Gazebo constant/stratified topic과 ROS wrapper topic 이름을 분리해 문서 수정
- `flow_velocity_topic`이 상대 suffix라는 점과 namespace 예시 불일치 수정
- 현재 REXROV에서는 `OceanCurrentModelPlugin`이 주석 처리돼 있으므로 해당 절에
  직접 미검증 경고 추가

근거:
[`../results/ocean_current_direct_validation_2026-08-25/`](../results/ocean_current_direct_validation_2026-08-25/).

## 6차 — 2026-08-26 Underwater Camera 직접 검증

「Underwater Camera Plugin」 페이지를 Mac 과 Docker 에서 직접 재실행하고 고쳤다.
**Notion 수정 페이지에는 이미 반영돼 있다.**

- Wiki Quickstart 를 두 플랫폼에서 재실행 — `/underwater_camera/simulated_image` 가
  `sensor_msgs/msg/Image` 320×240 `bgr8` step 960, 230400 바이트로 발행되는 것 확인
- 통제된 세 조건(no effect / defaults / murky)의 중심 픽셀을 구현식과 대조
- 기본 감쇠 `1/30` 과 background `0` 이 `[48.175, 68.320, 95.473]` 을 예측하고
  런타임과 일치하는 것 확인
- **`attenuationR`/`backgroundR` 가 Blue 에, `attenuationB`/`backgroundB` 가 Red 에
  적용된다는 것을 런타임에서 확인**하고 페이지에 경고 추가
- **`<scattering>` 은 별도 SDF 파라미터가 아니라는 점 정정** — `Configure()` 가 읽는
  것은 `attenuationR/G/B` 와 `backgroundR/G/B` 6개뿐이다
- launch 인자는 `verbose`/기본값 `0` 이 아니라 **`verbosity_level`/기본값 `1`** 이다.
  현재 `dave_sensor.launch.py` 의 선언과 실행 경로를 다시 대조해 표를 고쳤다

이 회차가 입증하지 않는 것: 일반 수중 광학 정확성. 정적 장면 하나, 원본 색 하나이고
murky 태그 6개를 동시에 바꿨다. **이 제한은 15차에서 보완했다** — 여섯 태그를 하나씩
분리하고 1·2·4·6 m 거리 조건을 Docker에서 직접 실행했다. 일반 수중 광학 정확성은
여전히 입증하지 않았다.

근거:
[`../results/underwater_camera_direct_validation_2026-08-26/`](../results/underwater_camera_direct_validation_2026-08-26/).

## 7차 — 2026-08-26 DVL 직접 검증

「DVL Plugin」 페이지의 Quickstart, launch 인자, bridge 설명과 water-mass 범위를
소스와 직접 실행 결과에 맞췄다.

- launch 인자는 `verbose`가 아니라 `verbosity_level`, 기본값은 `1`이다
- `ros_gz`에 DVL 변환이 없다는 문구를 철회했다 — 공식 demo와 C++ subscriber로
  populated `marine_acoustic_msgs/msg/Dvl`을 직접 읽었다
- exact DAVE Quickstart, 평면 bottom range, 1 m/s 이동과 수정된 water-mass control은
  Docker에서 통과했다
- **Mac 판정은 FAIL** — Wiki GUI, headless DAVE, 공식 ros_gz demo와 `ogre` 통제가
  모두 Gazebo Sensors render thread에서 종료한다
- DAVE custom `DVLBridge`가 `frame_id`를 복사하지 않는 점과, 배포 water-mass 태그의
  `0.`이 환경변수 이름으로 해석되지 않아 20/20 unspecified/no-lock이 되는 점을 경고했다

이 회차는 일반 DVL 정확도를 입증하지 않는다. 통제된 bottom range와 속도 변환,
water-mass 기능을 확인한 것이며 Mac crash의 하위 원인은 미확정이다.

근거:
[`../results/dvl_direct_validation_2026-08-26/`](../results/dvl_direct_validation_2026-08-26/).

## 8차 — 2026-08-26 SeaPressure 직접 재검증

「SeaPressure Plugin」 페이지의 기존 2026-08-21 정정을 Mac·Docker 통제 행렬로
확장했다. 발행 여부와 소스만 본 것이 아니라, 10개 조건의 pressure·variance·depth와
topic graph를 양쪽 플랫폼에서 직접 읽었다.

- surface `101.325`, `|z|=10 m` `199.3888`이 ROS Pascal 필드에 들어가는 단위 오류 확인
- `standard_pressure`·`kPa_per_meter`·`topic`·`estimate_depth_on`이 동작함을 양성 대조로 확인
- `saturation=50`·`noise_sigma=0.123`·`update_rate=2`가 각각 clamp·variance·주기를
  바꾸지 않는다는 것을 런타임 확인
- `z=+10 m`과 `z=-10 m`이 같은 pressure와 depth `10`을 내는 `abs(z)` 동작 확인
- retained ROS pressure frame의 `header.frame_id`가 두 플랫폼 모두 비어 있음을 확인
- Gazebo Transport는 Docker 10조건과 Mac baseline에서 직접 읽음

첫 full-matrix 시도는 기존 world 정리에 실패하고 두 SDF 태그를 중복 생성해 제외했다.
정정 runner는 한 서버, 고유 world·namespace, 태그당 단일 값으로 재실행했다. 정적 probe와
최대 `|z|=10 m`만 다루므로 실제 센서 정확도·장기 noise 통계·극심도 동작은 입증하지 않는다.

근거:
[`../results/seapressure_full_validation_2026-08-26/`](../results/seapressure_full_validation_2026-08-26/).

## 9차 — 2026-08-26 Spherical Coordinates 직접 재검증

「Spherical Coordinates Plugin」 페이지의 네 서비스를 Mac·Docker 통제 행렬과 현재
`dave_bimanual_example.world`에 맞춰 다시 썼다.

- 현재 world 원점은 `(35.074823, 129.084798, 0)`이다. 페이지의 오래된 North Sea
  원점을 현재 기본값처럼 읽히지 않게 했다
- Wiki 원점을 명시적으로 설정한 뒤 local `(100,200,3)`의 실제 변환 결과는
  `(-24.71717115826974, -46.51463667787355, 103.00393470935524)`였다
- 기존 문서 결과는 역변환하면 약 `(-100,-200,3)`이므로 X/Y 방향이 반대라고 경고했다
- 네 서비스의 필드가 `float64`인 기존 정정은 유지했다
- NaN 변환은 NaN을 반환하고, 위도 `100°`·경도 `200°` 원점도 `success=true`로
  받아들이므로 입력 검증이 없다는 범위를 추가했다
- Mac의 생성된 nested plugin path에서는 네 서비스가 없었고 실제 `lib/` 추가 후
  나타났다. Docker 기본 환경에서는 `install/lib`가 `LD_LIBRARY_PATH`에 있어 수동
  Gazebo 경로 추가 없이 네 서비스가 나타났다

유한점 3개를 플랫폼별로 왕복한 최대 축 오차는 `9.71e-10 m`였지만, 독립 geodesy
구현이나 측량값과 비교하지 않았으므로 일반 좌표 정확도 검증으로 확대하지 않는다.
소스에서 본 optional-empty→zero fallback은 런타임에서 유발하지 못했고 별도 코드
문제로 남긴다.

근거:
[`../results/spherical_coordinates_direct_validation_2026-08-26/`](../results/spherical_coordinates_direct_validation_2026-08-26/).

## 10차 — 2026-08-27 USBL 직접 재검증

「USBL Plugin」 페이지의 Quickstart와 두 trigger path를 Mac·Docker에서 직접 다시
실행했다.

- common mode에서 transponder 1·2의 spherical/Cartesian 출력을 양쪽 플랫폼에서 확인
- individual channel 1/2는 선택한 ID만 출력하고 cross-channel ID는 없음을 확인
- `sigma=0.0001` 정적 좌표의 retained run 최대 축 오차는 `0.000258 m`
- paused 상태는 endpoint가 보여도 두 플랫폼 모두 출력 0 — `spin_some()` pause gate 재확인
- literal `sigma=0`은 Mac/libc++에서는 finite output, Docker/libstdc++에서는 첫 ping에
  assertion abort(exit 134) — 플랫폼 의존 결함으로 범위 수정
- 기존 `dave_sensor.launch.py namespace:=usbl` Quickstart는 world plugin 출력이 나와도
  없는 `description/usbl/model.sdf`를 spawn하려는 오류를 함께 발생시킴
- Quickstart를 검증된 world-only launcher
  `ros2 launch dave_demos dave_world.launch.py world_name:=usbl_tutorial`로 교체

이 회차는 static tutorial geometry와 routing만 확인한다. 일반 USBL 음향·travel-time
정확도, 이동 표적, 장시간·다중 transceiver는 검증하지 않았다.

근거:
[`../results/usbl_direct_validation_2026-08-27/`](../results/usbl_direct_validation_2026-08-27/).


## 11차 — 2026-08-27 Dave ROV Models 직접 재검증

「Dave ROV Models」 페이지의 네 명령과 입력 보조 경로를 Mac·Docker에서 직접 확인했다.

- patched Mac `dave_ocean_waves`에서 REXROV 7/7 메시지 내용을 직접 읽음
- stock `empty.sdf`는 spawn 예제로만 범위를 축소 — Docker는 4/7이며 world에 Sensors
  system이 없고 image에는 local IMU patch가 없음
- BlueROV2·Heavy의 기존 4/5 PARTIAL 범위를 유지하되 2026-08-27 직접 recheck 범위를 분리
- formerly source-only `bluerov2_heavy_multibeam_sonar`를 Mac·Docker에서 처음 실행:
  양쪽 모두 odometry만 발행, IMU·magnetometer·sonar PointCloud2는 120초 동안 미발행
- Docker standalone WebSocket/keyboard Joy는 실제 non-neutral message로 PASS
- exact BlueROV2 통합 launch는 당시 shell에서 `mavros_msgs`/`mavros`가 보이지 않아 종료.
  **2026-08-29 1차 정정:** image 안의 기존 MAVROS overlay를 source하면 ArduSub·MAVROS는 시작했다.
  그 시점에는 plugin 부재·disconnected MAVROS·QGC SIGSEGV로 PARTIAL이었지만, 같은 날 19차가
  official plugin·speedup 후보·QGC opt-out으로 baseline control loop를 직접 닫았다

이 회차는 일반 ROV dynamics나 QGC 제어를 입증하지 않는다. thrust command response,
MAVROS 실제 연결, 반복·장시간 안정성은 후속 범위다. fifth variant sonar root cause는
2026-08-29 world의 `MultibeamSonarSystem` 누락으로 확정돼 9번째 후보 패치에서 닫혔다.

근거:
[`../results/rov_direct_validation_2026-08-27/`](../results/rov_direct_validation_2026-08-27/).


## 12차 — 2026-08-27 Dave World Models 전체 감사

「Dave World Models」 페이지의 Quickstart와 18개 배포 world 파일을 전체 대조했다.

- 현재 world-level matrix는 `FUNCTIONAL PASS` 5, `FUNCTIONAL PASS WITH REQUIRED
  WORKAROUNDS` 1, `SMOKE PASS` 11, `PARTIAL` 1 — 17/18 PASS-level이지만 기능 17개
  완전 통과라는 뜻은 아님
- 18개 파일의 내부 `<world name>`은 14개뿐이며, **7개 파일이 세 중복 그룹**에 속함:
  `oceans_waves` 3개, `default` 2개, `dvl_world` 2개
- 기존 페이지와 이슈 초안은 `oceans_waves` 2파일만 적고 `default`를 unique라고 했으므로 철회
- Mac source·Docker source·Docker install의 filename/name inventory가 일치함
- 18/18 파일이 remote Fuel URI를 가지며 총 remote include URI는 128개 — 빈 cache의 첫
  실행은 네트워크가 필요함
- `dave_ocean_waves` Quickstart를 Mac의 검증된 headless extension과 Docker RDP/X의
  정확한 Wiki 명령으로 재실행했고, 양쪽에서 `/world/oceans_waves/stats` 진행을 확인

이 회차의 single stats sample은 launch/liveness 근거이지 성능 benchmark가 아니다.
그날 다시 실행한 world는 `dave_ocean_waves` 하나뿐이며, 나머지 17행은 기존 날짜의
evidence를 유지한다. source inventory만으로 어떤 SMOKE도 FUNCTIONAL로 올리지 않았다.

근거:
[`../results/world_models_audit_2026-08-27/`](../results/world_models_audit_2026-08-27/).

## 13차 — 2026-08-27 Dave Glider Models 직접 재검증

「Dave Glider Models」 페이지의 `empty.sdf`와 `dave_ocean_waves` 예제를 Docker RDP에서
직접 다시 실행하고, 기존 `6/6`의 분모를 원본 스크립트까지 역추적했다.

- 두 Wiki launch 모두 model을 spawn하고 config의 9개 bridge topic을 전부 노출
- as-shipped `empty.sdf`는 state/sensor 5/6 — IMU만 silent
- local IMU `<topic>` overlay의 ocean run은 state/sensor 6/6
- 과거 `6/6` extractor는 `grep -v '^joint'`로 joint 3개를 제외했으므로, thruster가
  여섯에 포함됐다는 문구를 철회
- ROS `cmd_thrust=25.0`이 Gazebo `data: 25`로 도달하고 `ang_vel`이 `-0`에서
  `55776.3435`로 변함 — command coupling만 확인, calibration은 미검증
- 13차의 one-shot integrated `enable_deadband`는 Gazebo→ROS `true`만 보고 ROS→Gazebo는
  timeout이었다. **15차 반복 통제에서 ROS `true` 50개가 Gazebo `true` 50개로 도달하고
  false 0을 확인해, 그 비대칭 주장을 철회했다**
- fresh Mac 두 예제는 `/stats`와 model data가 진행되지 않은 `NOT_STEPPING` 재현으로
  미확정이며 현재 functional 근거에 사용하지 않음
- ROV page의 `bluerov2_heavy_multibeam_sonar` source-only 문구도 11차 runtime 결과로 갱신

이 회차는 Wiki launch, 여섯 state/sensor output과 한 thrust-command coupling을 검증한다.
일반 glider dynamics, actuator calibration, battery depletion, navigation 성능과 장시간
안정성은 검증하지 않았다.

근거:
[`../results/glider_direct_validation_2026-08-27/`](../results/glider_direct_validation_2026-08-27/).

## 14차 — 2026-08-27 Object Models 직접 재검증

「Object Models」 페이지의 배포 object launch와 일반 Fuel include 예제를 직접 실행했다.

- 이 checkout이 배포하는 object descriptor는 `mossy_cinder_block` 하나임을 명시
- exact Wiki launch를 Mac의 빈 Fuel cache와 Docker/RDP의 기존 cache에서 각각 실행하고,
  model 존재와 simulation progress를 확인
- 양쪽 cache의 10개 상대 파일명과 SHA-256이 같음을 확인
- generic Teledyne Fuel URL을 isolated cache로 내려받아 SDF를 검증하고 Mac·Docker
  minimal world에서 model spawn까지 확인; bundled sensor 동작은 미검증
- copied source package에 `description/codex_versioned_block/`을 추가해 Mac·Docker에서
  build·install·spawn을 확인. `/1`을 붙인 URI는 양쪽 client가 latest tip만 지원한다고
  경고했으므로 immutable version pin으로 인정하지 않음
- 없는 descriptor는 서버에서 file error와 entity 부재가 나는데 client는 exit 0과
  `Entity creation successful`, launch handler는 `Object Model Uploaded`를 출력하는
  false-success 경로를 경고
- descriptor를 추가할 위치를 install tree가 아니라 source package의
  `description/<namespace>/`로 정정
- 뒤의 DVL 예제는 Object Models 완료 근거가 아니라 DVL의 Docker PASS/Mac crash 범위로 연결

이 회차는 한 개의 배포 object, 한 개의 일반 Fuel model과 한 개의 copied-source custom
descriptor를 확인한 것이다. visual, collision, inertial/contact physics, offline operation,
Fuel account upload, Resource Spawner GUI와 장기 dynamics는 검증하지 않았다.

근거:
[`../results/object_models_direct_validation_2026-08-27/`](../results/object_models_direct_validation_2026-08-27/).

## 당시 일부러 문서 정정에 넣지 않은 코드 항목 — 현재 상태 갱신

2026-08-20에는 문서에 우회만 적는 대신 코드로 고쳐야 한다고 분리했다. 현재 상태는 다음과 같다.

- `multibeam_sonar_system` 의 `package.xml` 의존성 누락 — 상류 PR 결정이 아직 필요하다.
- `SphericalCoords.cc`의 silent 0/origin fallback — 2026-08-29 검증 후보 패치에 포함됐다.
- Jetty 빌드의 "Harmonic" 로그 문구 — 2026-07-23 기존 migration patch에서 이미 고쳤다.

그리고 **우리 환경 얘기**라 DAVE 문서에 들어갈 내용이 아닌 것들: Docker 이미지 비밀번호,
`--privileged` 불필요, `rosdep || true` 가 실패를 가리던 것, mavros 소스 빌드, xrdp 권한.

ArduSub 의 Python 3.14 호환성 문제는 위키에 ArduSub 페이지가 없어 붙일 곳이 없었다.

## 이 폴더의 파일

| 파일 | 내용 |
|---|---|
| [`wiki-error-report-final-EN.md`](wiki-error-report-final-EN.md) | 1차 정정 4건. 영문 완성본 |
| [`wiki-error-reports.md`](wiki-error-reports.md) | 위 문서의 작업 메모 |
| [`dave-wiki-inaccuracies.md`](dave-wiki-inaccuracies.md) | 20 페이지를 읽으며 남긴 원본 기록 |
| [`ogre-x-display-doc-correction.md`](ogre-x-display-doc-correction.md) | `ogre` 우회의 X 디스플레이 요건. **버그가 아니라 문서 정정** — 우회는 동작하는데 설명이 불완전해 정상 설정이 고장난 것처럼 보인다 |

## 2026-08-20 확인의 한계 — 당시 기준

2026-08-20 에 **20 페이지를 전부 열어** 우리 발견과 대조했다. 그전 두 번은 검색 결과와
기억에 기댔고, 그래서 두 번 다 빠뜨렸다 — DVL 과 Underwater Camera 의 `colcon build`
는 검색이 상위 10건만 돌려주는 바람에 안 보였다.

**보장할 수 있는 범위는 "우리가 검증한 것과 대조했을 때 빠진 게 없다"까지다.**
우리가 손대지 않은 영역(매니퓰레이터, Migration Progress 등)에
다른 오류가 있는지는 확인한 적이 없으므로 알 수 없다.

## 15차 — 2026-08-28 전체 잔여 직접 검증

Notion 전 페이지 감사에서 아직 직접 실행되지 않았다고 남은 항목 중 현재 Mac·Docker에서
실행 가능한 범위를 다시 시험했다.

- Spherical Coordinates: 독립 WGS-84/ECEF/ENU oracle, 4지역 13점 통과
- DVL: 배포 descriptor 8개 전수 실행, 4개 output·4개 range 설정 초기화 실패
- Underwater Camera: 여섯 태그 개별 활성화와 1·2·4·6 m 추세, fresh Mac recheck 분리
- SeaPressure: paused 5초, ±1000 m, surface 10,000-frame 안정성
- Glider: integrated deadband 50/50 통과로 one-shot 비대칭 주장 철회
- USBL: 이동 표적 통과, integer-second travel-delay 양자화 발견
- Ocean Current ModelPlugin: 고정 깊이 두 차량·두 namespace의 current→motion 확인
- Ocean/Spherical plugin discovery: source `.dsv` hook을 nested path의 출처로 확정

NVIDIA CUDA, Windows/WSL, MAVROS/QGroundControl 통합, 실제 USB/gamepad/해양 HIL과 Fuel
account upload는 현재 prerequisite가 없어 **BLOCKED**로 적었다. 실행하지 못한 것을 PASS로
올리지 않는다.

근거:
[`../results/full_gap_validation_2026-08-27/`](../results/full_gap_validation_2026-08-27/).


## 16차 — 2026-08-29 후보 패치 판정 전파

2026-08-28 감사에서 재현된 로컬 결함을 격리된 source snapshot에서 수정하고 Mac·Docker의
가능한 범위를 다시 실행했다. Notion의 16개 현재 페이지에 2026-08-29 callout을 추가해,
수정 전 PARTIAL 블록을 역사로 남기면서 현재 후보 패치 판정을 맨 위에서 분리했다.

- Multibeam WGPU gross range shift와 explicit CUDA CPU fallback
- Underwater Camera R/B 의미론, SeaPressure ROS 계약·설정
- Spherical invalid-input/status/no-config/paused와 plugin discovery
- DVL frame ID·water variable·8/8 descriptor Docker 경로
- USBL zero-noise·paused·fractional delay
- World 18/18 unique names, Object missing-descriptor preflight
- Ocean Current discovery, ROV/Glider의 공유 launch 범위
- 전체 현황·다음 연구 방향·소나 코드/이론·대조표의 현재 판정

**후보 패치는 상류 DAVE나 사용자 설치 workspace에 아직 반영되지 않았다.** Mac stock Gazebo
DVL SIGSEGV, NVIDIA/hardware GPU, RViz Mac 창, BlueROV2 통합,
Fuel/Windows/HIL 및 일반 과학 정확도는 계속 열린 범위로 남겼다. Docker sonar `ogre2`의
현재 always-crash 판정은 18차 재검증에서 철회됐다.

근거:
[`../results/remaining_defect_fixes_2026-08-29/`](../results/remaining_defect_fixes_2026-08-29/).

## 17차 — 2026-08-29 후속 경계·전파 감사

후보 패치를 커밋하기 직전의 판별 입력만 다시 보는 대신, 구현 경계와 현재형 문서까지
역방향으로 감사했다. WGPU exact-DFT shader의 workgroup 배열은 4096개이므로 기존
`min(4096)`만으로는 4097개 이상의 입력을 안전하게 처리하지 못한다는 것을 확인했다.

- host와 WGSL에 4096 frequency-bin 경계를 명시
- 4097 bins는 GPU 초기화 전에 null을 반환해 기존 C++ CPU fallback으로 넘김
- 4097-bin Rust 단위 시험과 `cargo check` 통과
- 두 source guide의 오래된 zero-padded `fft_len` 설명을 현재 exact-N DFT 구조로 정정
- CMake 패턴 6, Multibeam 현재 표·범위·launch callout, 전체 현황, 다음 연구 방향,
  소나 코드·이론·대조표를 후보 판정과 동일하게 갱신
- Notion 7페이지를 다시 fetch해 새 문구 존재와 현재형 stale 문구 부재를 확인

이 회차는 **경계 단위·정적 검사**다. 4097-bin 전체 소나 runtime, 일반 음향 정확도,
상류 병합 또는 설치 workspace 수정으로 확대하지 않는다.

근거:
[`../results/remaining_defect_fixes_2026-08-29/post_commit_audit.txt`](../results/remaining_defect_fixes_2026-08-29/post_commit_audit.txt).

## 18차 — 2026-08-29 전체 open-gap 재실행

후보 패치 커밋 뒤에도 현재형으로 남은 실행 가능 항목을 새 partition/domain과 직접 출력
구독으로 다시 시험했다.

- 공식 stock DVL Mac SIGSEGV와 RViz `visible=true, windows=0`는 재현됨
- Underwater Camera exact Mac Quickstart는 3/3 이미지 발행(54/58/72초), 과거 topic 부재는
  현재 failure가 아니라 historical trigger 조사로 축소
- Fast DDS 최소 create는 SHM 5/5·UDPv4 5/5, 과거 1/9 trigger는 미재현
- Docker isolated OGRE2 DAVE sonar는 실제 PointCloud를 발행; software WGPU는 CPU fallback
- fifth ROV sonar silence는 `dave_ocean_waves.world`의 `MultibeamSonarSystem` 누락으로 확정,
  9번째 후보에서 513×301 PointCloud2 발행
- Docker 기존 MAVROS overlay를 source하면 ArduSub·MAVROS와 TCP endpoint는 시작했지만,
  이 18차 시점에는 `libArduPilotPlugin.so` 부재, disconnected MAVROS, QGroundControl 반복
  SIGSEGV로 통합 control loop를 PARTIAL로 유지했다. **같은 날 19차 검증이 이 현재 판정을
  대체한다**

따라서 “MAVROS가 image에 없다”, “fifth sonar 원인 미확정”, “Docker OGRE2 sonar는 현재도
항상 crash”, “fresh Mac camera는 현재 topic 부재”를 현재 판정으로 쓰지 않는다. 이 시점의
후보 9개는 순서대로 apply되고 Rust/Python/XML/SDF 검사와 snapshot equality를 통과했다.
상류와 사용자 설치 workspace에는 적용하지 않았다.

근거:
[`../results/open_gap_revalidation_2026-08-29/`](../results/open_gap_revalidation_2026-08-29/).

## 19차 — 2026-08-29 BlueROV2 외부 스택 직접 검증

18차의 “plugin 부재·disconnected MAVROS·QGC SIGSEGV”를 종착점으로 두지 않고 필요한 공식
구성요소와 wrapper 동작을 직접 추적했다.

- official `ArduPilot/ardupilot_gazebo`를 commit `082a0fe`에 고정해 Ubuntu 26.04 arm64,
  ROS 2 Lyrical, Gazebo Jetty에서 `libArduPilotPlugin.so` 빌드
- JSON sensor 입력 뒤 ArduSub가 `AP_Logger_File::periodic_1Hz()`에서 `SIGFPE`하는 것을 GDB로
  재현하고, 세 BlueROV config에 `--speedup 1`을 넣는 10번째 후보 패치 작성
- baseline BlueROV2에서 MAVROS connected 4/4, MANUAL force-arm, 6초 manual control,
  X odometry +2.182964 m, disarm 성공
- BlueROV2 Heavy에서도 별도 1회 bounded run으로 MAVROS connected 4/4, MANUAL force-arm,
  6초 manual control, X odometry +2.375679 m, disarm 성공
- current Dockerfile은 cache-assisted end-to-end로 44.86분에 23.9GB image를 생성했고, 그 exact
  image에서 baseline·Heavy·Heavy-multibeam 모두 MAVROS 4/4와 arm/control/disarm 통과
- QGroundControl retained DailyBuild는 기본 AppRun exit 139, AppRun이 지원하는
  `QGC_NO_SYSTEM_GLIB=1` opt-out에서는 45초 clean control과 integrated vehicle 연결 PASS
- current exact image의 xrdp 서비스 기동과 QGC opt-out/offscreen 20초 생존 PASS; 실제 RDP
  login·rendered GUI·vehicle connection을 그 image에서 재실행한 것은 아님
- Docker에는 `/dev/dri`·NVIDIA device request가 없고 llvmpipe software rendering만 존재;
  Windows/WSL, Fuel credential, 외부 gamepad/HIL 장비도 실제 inventory에 없음

따라서 세 BlueROV variant의 tested Docker control loop는 FUNCTIONAL PASS로 올린다. 19차
시점에는 Heavy-multibeam control과 sonar 출력이 별도 snapshot이어서 한 결합 결과로 쓰지
않았다. 이 미실행 범위는 아래 20차에서 직접 실행해 실패 판정으로 닫았다. fresh `--no-cache`,
exact-image rendered RDP/QGC
vehicle connection, QGC 기본 경로, hardware GPU·Windows·Fuel upload·physical HIL,
calibration과 장시간/실차 정확도는
별도 범위다. 후보 패치와 Docker recipe는 상류 DAVE 및 사용자 설치 workspace에 적용하지 않았다.

근거:
[`../results/external_stack_validation_2026-08-29/`](../results/external_stack_validation_2026-08-29/).


## 20차 — 2026-08-30 Heavy-multibeam sonar+control 결합 Docker 검증

19차에서 별도였던 두 결과를 한 실행에 합쳤다. exact current Docker image의 source tree에
9번째 fifth-ROV sonar-world 후보를 live-apply하고 `dave_worlds`를 재빌드한 뒤,
`bluerov2_heavy_multibeam_sonar`와 ArduSub/MAVROS를 함께 시작했다.

- 후보 marker 확인과 `dave_worlds` 재빌드 PASS
- WGPU가 Docker software adapter `llvmpipe` 선택
- 첫 1×1×4 probe가 **60053.0 ms** 소요
- sonar plugin이 513 beams × 301 rays × 399 bins 설정을 출력
- 직후 Gazebo stack trace가 시작되고 ArduSub는 no-JSON 경고를 105회 출력
- MAVROS state probe 0 byte, PointCloud2 미수집, arm/control/disarm 단계 미도달

이 회차에서는 결합 경로를 **FAIL/PARTIAL**로 판정했다. 다만 수동 cleanup 전에 완전한
backtrace와 최종 exit status를 보존하지 못했고 backend도 분리하지 않았다. 아래 21차 재실행이
이 판정을 supersede한다: software WGPU는 exit 139, forced CPU는 output·control PASS이므로 현재
판정은 backend-dependent다. 별도 exact-image control PASS와 Mac fifth-sonar PointCloud PASS는
각각의 원래 범위에서 유지한다.

근거:
[`../results/external_stack_validation_2026-08-29/dockerfile/combined_sonar_control/`](../results/external_stack_validation_2026-08-29/dockerfile/combined_sonar_control/).


## 21차 — 2026-08-30 최종 실행 가능 gap 직접 검증

인터넷의 공식 문서와 현재 로컬 실행을 결합해 남은 실행 가능 범위를 다시 분리했다.

- Mac DVL stock crash를 LLDB `EXC_BAD_ACCESS`와 `gz-sim10_10.4.0` source로 null-scene
  초기화 누락까지 좁히고, hidden 8×8 camera를 둔 official-world control로 four-beam output 복구
- RViz main window가 Cocoa/OGRE 경로에서 CoreGraphics `onscreen=false`인 것을 plain Qt/OpenGL
  controls 및 software/show/orderFront 후보와 대조; 영구 fix는 찾지 못해 open 유지
- Fast DDS dirty/clean/SIGKILL/UDP matrix 18/18; stale SHM은 청소했지만 historical hang 인과는 미확정
- Underwater Camera exact Quickstart default 3/3·UDP 3/3; 90–110초 startup latency로 과거 short-wait 판정 정정
- exact Docker image를 Windows App으로 실제 RDP login해 Xorg/XFCE framebuffer와
  Gazebo+QGroundControl vehicle-connected 화면 직접 확인
- Heavy-multibeam 결합을 backend별로 재실행: software WGPU/llvmpipe exit 139, forced CPU는
  513×301 PointCloud2와 MANUAL arm/control/disarm, X +1.348464 m로 PASS
- current Dockerfile은 official BuildKit cache prune 뒤 fresh `--no-cache`로 66.917분에 완주했고 package/pin 검사를 통과했다. fresh image도 FreeRDP/xrdp로 Xorg/XFCE를 띄워 Gazebo+QGC Ready/Manual과 MAVROS connected/Manual을 실제 framebuffer에서 재확인

따라서 위키의 DVL·Installation/환경·Underwater Camera·ROV/Multibeam 및 전체 현황 페이지는
이 범위로 맞춘다. fresh run은 FreeRDP이고 이전 exact cache run은 Windows App이므로 client 범위도 분리한다. scientific accuracy, hardware CUDA/WGPU, Windows/WSL, HIL과 upstream 적용은
이 회차의 PASS 범위가 아니다.

근거:
[`../results/final_gap_validation_2026-08-30/`](../results/final_gap_validation_2026-08-30/).

## 22차 — 2026-08-30 Mac stock DVL initialization 후보 직접 검증

21차의 LLDB 진단과 hidden-camera workaround에서 멈추지 않고 exact `gz-sim10_10.4.0`
source에 두 후보를 만들었다.

- stock plugin control은 같은 격리 실행 환경에서 `WaitForInit()` exit 139 재현
- `forceUpdate`를 Apple main-thread predicate에만 넣은 v1은 9/10; 동일 crash 1회로 폐기
- main-thread `RenderUtil::Init()` 완료 전 render-thread handoff도 막은 v2는 hidden camera 없이
  unmodified official DVL world 20/20, four locks 20/20, clean exit 20/20
- official standard-camera regression 3/3, Sensors-without-render-sensor regression 3/3
- official `ros_gz_bridge` 뒤 C++ subscriber가 frame ID, `num_good_beams=4`,
  range/velocity validity true와 네 range를 직접 수집

따라서 「DVL Plugin」 페이지의 현재 문구는 “Mac은 원인만 진단되고 hidden-camera workaround만
있다”가 아니라, **격리 후보는 통과했으나 Homebrew/상류에는 아직 적용되지 않았다**로 바꾼다.
일반 DVL 물리 정확성·장시간·다중장치와 upstream acceptance는 여전히 검증 밖이다.

같은 현재 판정이 다른 문서에서 다시 어긋나지 않도록 live Notion의 「Dave World Models」,
「Object Models」, 전체 현황 허브, 다음 연구 방향, 날짜별 작업 기록과 Wiki 대조표에도 전파했다.
허브·타임라인의 보존 diff는 17건, `progress-log.md`는 104행으로 함께 맞췄다. 원본 Wiki
database는 역사 원본이므로 수정하지 않았다.

근거:
[`../results/dvl_macos_force_update_candidate_2026-08-30/`](../results/dvl_macos_force_update_candidate_2026-08-30/).

## 23차 — 2026-08-30 Docker software-WGPU 소나 deferred-backend 후보 검증

21차에서 backend-dependent PARTIAL로 남긴 Heavy-multibeam 경로를 최소 소나와 결합 차량으로
다시 분리했다. 현재 배포 baseline은 최소 world에서도 Docker `llvmpipe` WGPU를 선택한 뒤
OGRE2 sample-texture/null-`memcpy` SIGSEGV와 exit 139를 재현한다.

- backend 생성·probe를 render callback으로 옮긴 v3는 같은 crash를 재현해 폐기
- 첫 populated `GpuRays` frame을 처리하는 기존 compute thread까지 생성을 지연하고, 사용하지
  않는 ROS parameter service/event endpoint를 끈 v5를 retained isolated candidate로 보존
- fresh Docker에서 WGPU 2/2, auto 1/1, CPU 1/1 모두 513×301 PointCloud2와 513×399 raw sonar 수집
- 같은 후보의 Heavy 결합 1회에서 `llvmpipe` WGPU, MAVROS connected/arm, manual-control 100개,
  X +0.191291 m와 disarm 확인
- Mac에서는 같은 후보 library가 Apple M2 Metal을 선택해 513×301×399 compute frame을 반복했고
  crash가 없었지만, host upgrade 뒤 ROS observer가 멈춰 이 실행의 새 payload 증거는 추가하지 않음

따라서 Notion과 현재 GitHub 문서에는 **격리 후보 범위의 FUNCTIONAL PASS**와 **배포/설치
baseline의 PARTIAL**을 동시에 적는다. 후보는 사용자 설치 workspace·상류 DAVE에 적용되지
않았고, NVIDIA/hardware GPU, 장시간, shutdown-only bridge crash 및 일반 음향 정확성은 검증
밖이다. `progress-log.md` 현재 행 수는 105다.

근거:
[`../results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/`](../results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/).

## 24차 — 2026-08-30 소나 반복·수치 matrix·통합 payload·BlueROV contract 확장

23차의 단발 후보 범위를 다시 넓히되 startup, raw-sonar 수치, world payload, 차량 sensor
contract를 하나의 PASS로 합치지 않았다.

- deferred-backend 후보는 fresh Docker software-WGPU cold start 20/20과
  Heavy+ArduSub/MAVROS 3/3을 통과했다. Heavy X 이동은 0.624–0.687 m, 중앙값 0.667 m였다.
- bounded 1,861초 soak에서 시작·종료 PointCloud2 513×301과 raw sonar 513×399를 모두 보존했고,
  WGPU frame은 3,850 증가했으며 runtime stack trace/exit 139는 없었다. 작은 양의 memory slope는
  한 bounded run의 관측값일 뿐 leak으로 판정하지 않는다.
- process-group SIGINT에서는 launch가 10/10 escalation 없이 clean exit했지만
  `parameter_bridge`가 종료 중 7/10 exit -11을 냈다. background shell PID에 SIGINT를 보낸
  첫 harness는 TERM 10/10이 필요해 Ctrl-C 근거에서 제외했다.
- 2/4/7 m plane과 4 m sphere/cylinder의 여섯 Docker 장면에서 CPU와 배포 WGPU PointCloud
  finite XYZ/intensity는 정확히 같았다. 배포 WGPU raw peak는 +0.584 m, 약 +1.14–1.17 m,
  +1.980 m 이동했다. Rust archive를 실제 재빌드하고 sonar를 clean relink한 exact-N 후보는
  18/18 peak를 0.0736 m 안으로 되돌렸지만 fresh `llvmpipe` probe가 88.2–115.3초여서
  production performance fix로 부르지 않는다.
- integrated ocean-waves sonar world는 같은 격리 후보에서 PointCloud/raw 3/3과 진행하는
  world stats를 직접 냈다. 이 결과는 candidate/output FUNCTIONAL PASS이지 installed/upstream
  또는 복합 장면 acoustic accuracy PASS가 아니다.
- exact Docker image의 세 BlueROV 모델 contract를 autopilot과 분리해 읽자 camera·odometry와
  default Gazebo IMU는 나오지만 bridged IMU·magnetometer는 조용했고 fifth variant sonar도
  installed world에서 조용했다. local source/world 후보 결과와 exact-image sensor 범위를
  섞어 5/5라고 쓰지 않는다.

따라서 「Multibeam Sonar Plugin」, 「Dave ROV Models」, 전체 현황과 다음 연구 방향은
**startup candidate runtime PASS**, **distributed raw WGPU·bridge teardown·sensor contract·배포
PARTIAL**, **exact-N correctness discriminator의 performance 한계**를 따로 표시해야 한다.
이 24차 정정 직후 `progress-log.md`는 107행이었다.

근거:
[`../results/multibeam_deferred_backend_extended_validation_2026-08-30/`](../results/multibeam_deferred_backend_extended_validation_2026-08-30/) ·
[`../results/multibeam_backend_equivalence_matrix_2026-08-30/`](../results/multibeam_backend_equivalence_matrix_2026-08-30/) ·
[`../results/integrated_sonar_payload_validation_2026-08-30/`](../results/integrated_sonar_payload_validation_2026-08-30/) ·
[`../results/bluerov_sensor_contract_validation_2026-08-30/`](../results/bluerov_sensor_contract_validation_2026-08-30/).

## 25차 — 2026-08-31 장치 matrix·결정론·teardown·Ocean tide 범위 갱신

문서 페이지의 Quickstart 성공과 아직 남은 일반 정확도 사이를 더 세분화했다.

- DVL: 8 simultaneous descriptors, 20 messages each(총 160), four beams/bottom lock/distinct frame/rate PASS.
- USBL: two transceivers/four transponders, A/B namespace isolation and concurrent interrogation PASS.
- Underwater Camera: all six attenuation/background tags individually isolated; analytic centre values 0 LSB error.
- SeaPressure: seven devices, about 200 simulated seconds, 2,000 noisy frames and rate/statistics controls PASS.
- Multibeam: fixed seed/frame gives byte-identical raw/point arrays across three fresh containers; empty-cache software probe remains 94.192–101 s. CPU/WGPU full raw equality is not used as an oracle because their phase/noise algorithms differ.
- Bridge teardown: no-publisher 40/40 and stock active 30/30 clean, DAVE-sonar active one-way 9/10 SIGSEGV and PointCloud-only 2/10. The old generic 7/10 statement is withdrawn.
- Ocean Current: 400-sample Gauss–Markov variation and documented per-model tidal path pass. The initial unchanged-global-topic interpretation was the wrong oracle, not a tidal defect.
- `dave_ocean_waves_sonar` now has clean single-instance candidate/output evidence; all three manipulation worlds have Docker world-progress smoke evidence.

These updates do not claim upstream installation, hardware GPU, physical acoustic/optical/hydrodynamic
accuracy or mission endurance. After the four new dated rows, `progress-log.md` has 111 rows.

Evidence:
[`../results/fastdds_create_stress_2026-08-31/`](../results/fastdds_create_stress_2026-08-31/) ·
[`../results/parameter_bridge_shutdown_validation_2026-08-31/`](../results/parameter_bridge_shutdown_validation_2026-08-31/) ·
[`../results/sensor_long_multi_validation_2026-08-31/`](../results/sensor_long_multi_validation_2026-08-31/) ·
[`../results/usbl_multi_namespace_validation_2026-08-31/`](../results/usbl_multi_namespace_validation_2026-08-31/) ·
[`../results/underwater_camera_channel_isolation_validation_2026-08-31/`](../results/underwater_camera_channel_isolation_validation_2026-08-31/) ·
[`../results/multibeam_seed_determinism_validation_2026-08-31/`](../results/multibeam_seed_determinism_validation_2026-08-31/) ·
[`../results/ocean_current_tidal_noise_validation_2026-08-31/`](../results/ocean_current_tidal_noise_validation_2026-08-31/) ·
[`../results/ocean_waves_sonar_clean_validation_2026-08-31/`](../results/ocean_waves_sonar_clean_validation_2026-08-31/) ·
[`../results/manipulation_docker_replay_2026-08-31/`](../results/manipulation_docker_replay_2026-08-31/).

## 26차 — 2026-08-31 `parameter_bridge` ownership-cycle 후보

25차에서 현재 실패로 남긴 DAVE-sonar active-endpoint teardown을 source ownership까지 따라갔다.
`RosGzBridge`는 `shared_ptr<BridgeHandle>` vector를 소유하고, 각 handle은 다시 owner node의
`SharedPtr`를 보유해 strong-reference cycle을 만들었다. `spin()` 뒤 local pointer를 reset하는
후보가 실패한 이유도 cycle 때문에 node와 middleware endpoint가 파괴되지 않았기 때문이다.

- retained exact-`ros_gz` 3.0.9 후보는 handle back-reference만 `WeakPtr`로 교체
- baseline DAVE-sonar process-group shutdown: `parameter_bridge` exit -11 **9/10**
- candidate DAVE bridge-first: PointCloud/raw **20/20**, bridge clean **20/20**, exit -11 **0/20**
- candidate DAVE process-group: PointCloud/raw **10/10**, launch rc0 **10/10**, exit -11 **0/10**
- direct ROS→GZ payload/clean exit **20/20**
- stock active camera와 PointCloud GZ→ROS **5/5 each**

따라서 Notion의 「Multibeam Sonar Plugin」, 「Dave ROV Models」와 전체 현황에서 `parameter_bridge` teardown을
현재 로컬 후보의 미해결 결함으로 쓰면 안 된다. 로컬 격리·cross-distribution 뒤 실제 사용자
`ros_gz` workspace에도 네 파일을 적용해 기존 CMake 편집 2건을 보존한 채 빌드했다. bounded
24/24, generated mapping 73쌍의 양방향 payload 73/73 each, ordered bridge rc0, repeat 5/5,
lifecycle 11/11을 통과했다. 이슈 [#951](https://github.com/gazebosim/ros_gz/issues/951)과
signed PR [#952](https://github.com/gazebosim/ros_gz/pull/952)이 열려 있고 DCO PASS·mergeable이며
maintainer review/merge 대기다. 다만 별도 ordered component는 topic 3/3·service 1/1 assertion 뒤
test helper rc134와 `bridge_node` SIGINT exit139라 **PR #952의 완료 범위에 포함하지 않는다.**
native x86_64 hardware, Windows, hardware GPU도 외부 범위다. `ros2 run` wrapper와 child에 SIGINT를
동시에 준 잘못된 harness와 CLI timeout이 걸린 중단 harness는 각각 `INVALID_ATTEMPT`로 보존했으며
판정에서 제외했다.

이 행 추가 뒤 `progress-log.md`는 112행이다.

근거:
[`../results/parameter_bridge_cycle_fix_validation_2026-08-31/`](../results/parameter_bridge_cycle_fix_validation_2026-08-31/) ·
[`../../patches/ros_gz_bridge_handle_cycle_fix.diff`](../../patches/ros_gz_bridge_handle_cycle_fix.diff).
