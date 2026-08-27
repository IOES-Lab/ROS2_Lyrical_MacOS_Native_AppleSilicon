# wiki/ — DAVE 문서 정정

DAVE 의 공식 문서는 [`dave-ros2.notion.site`](http://dave-ros2.notion.site) 다. GitHub wiki 가
아니라 노션 사이트이므로, 정정은 PR 이 아니라 페이지를 직접 편집하는 방식이다.

**열두 차례에 걸쳐 반영했다. 이 폴더의 초안들은 그 근거 기록이다.**

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
| ~~aarch64 OGRE2 미지원~~ · 소나 segfault · WGPU CPU 폴백 | Docker 매뉴얼 | **OGRE2 미지원 부분은 2026-08-21 철회** — 3차 정정 참고 |
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
| **aarch64 에서 OGRE2 미지원** | Docker 매뉴얼 · 전체 현황 「핵심 발견 3」 · CMake 패턴 7 | **철회.** 7월에 `Failed to load plugin [ogre2]` 를 보고 적었는데, 같은 컨테이너에서 표준 `gpu_lidar` 가 소나와 같은 513×301 형상으로 `ogre2` 에서 3/3 발행한다. DAVE 소나는 `Ogre2Scene::PreRender` 안에서 죽는데, 플러그인이 로드 안 됐으면 거기까지 갈 수 없다. **OGRE2 가용성 문제가 아니라 소나 전용 크래시다** |
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

이 회차가 입증하지 않는 것: 일반 수중 광학 정확성. 정적 장면 하나, 원본 색 하나이고
murky 태그 6개를 동시에 바꿨다. 태그를 하나씩 분리한 확인은 하지 않았다.

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
- exact BlueROV2 통합 launch는 QGC·Firefox·ArduSub startup까지 가지만 현재 image의
  `mavros_msgs`/`mavros` 부재로 종료 — process startup을 vehicle-control PASS로 쓰지 않음

이 회차는 일반 ROV dynamics나 QGC 제어를 입증하지 않는다. thrust command response,
MAVROS 연결, 반복·장시간 안정성과 fifth variant sonar root cause는 후속 범위다.

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

## 일부러 넣지 않은 것

문서가 아니라 **코드로 고쳐야 하는 것들**이다. 문서에 "이거 없으면 실패한다"고
적는 건 해결이 아니다.

- `multibeam_sonar_system` 의 `package.xml` 의존성 누락 — fork 후 PR
- `SphericalCoords.cc` 패치가 변환 실패를 0/원점으로 감출 수 있는 문제 — 우리 패치 쪽
- 빌드 로그가 Jetty 빌드인데 "Harmonic" 이라고 찍는 것 — 상류 코드

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

## 이 확인의 한계

2026-08-20 에 **20 페이지를 전부 열어** 우리 발견과 대조했다. 그전 두 번은 검색 결과와
기억에 기댔고, 그래서 두 번 다 빠뜨렸다 — DVL 과 Underwater Camera 의 `colcon build`
는 검색이 상위 10건만 돌려주는 바람에 안 보였다.

**보장할 수 있는 범위는 "우리가 검증한 것과 대조했을 때 빠진 게 없다"까지다.**
우리가 손대지 않은 영역(매니퓰레이터, Object Models 세부, Migration Progress 등)에
다른 오류가 있는지는 확인한 적이 없으므로 알 수 없다.
