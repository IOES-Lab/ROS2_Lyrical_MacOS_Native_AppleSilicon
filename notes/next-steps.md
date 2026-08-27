<!-- README.md 에서 분리했다. 2026-08-19, 상류 저장소(IOES-Lab/dave, dockwater)의
     README 형식에 맞추면서 옮긴 것이다 — 그쪽 README 는 입구 역할만 하고
     내용은 별도 문서에 둔다. -->

# 남은 일

- [ ] **Spherical Coordinates 후속 3건** — (1) Wiki의 현재 world 원점과
  `(100,200,3)` 변환 결과를 2026-08-26 런타임 값으로 유지한다. (2) NaN과
  latitude `100°`/longitude `200°` 같은 비정상 입력을 거부하고 실패를 표현할 API를
  정한다. 변환 `.srv`에는 현재 success 필드가 없다. (3) Mac 설치의
  `GZ_SIM_SYSTEM_PLUGIN_PATH`와 실제 dylib 위치를 맞춘 clean rebuild를 확인한다.
  유한점 3개 왕복은 Mac·Docker 모두 통과했지만 독립 geodesy 정확도 검증은 아니다
- [ ] **SeaPressure 결함의 수정·보고 범위 결정** — 2026-08-26 Mac·Docker 10조건 행렬에서
  kPa→Pa 단위 오류, 무시되는 `saturation`·`noise_sigma`·`update_rate`, `abs(z)`의
  above-origin 대칭, 빈 ROS `frame_id`를 런타임 확인했다. 기존 이슈 초안 7·8은 단위와
  dead-parameter 범위를 갱신했지만, `abs(z)`와 `frame_id`를 같은 보고에 포함할지 별도
  이슈로 나눌지는 사람의 판단이 필요하다. 수정 후에는 깊이·발행 주기·메타데이터와
  기존 kPa 소비자 호환성을 다시 시험해야 한다
- [ ] **DVL 후속 3건** — (1) Mac에서 DAVE Wiki/headless/공식 ros_gz/`ogre` 통제가
  모두 Gazebo Sensors render thread에서 종료하는 원인을 좁힌다. (2) DAVE custom
  `DVLBridge`가 Gazebo의 frame ID를 ROS 메시지에 복사하도록 고치거나 공식 `ros_gz`
  변환으로 대체한다. (3) 배포 DVL 모델의 water-mass 태그를 실제 environmental variable
  이름과 preload에 연결한다. Docker bottom/velocity 및 수정된 water-mass control은
  직접 통과했지만 이 세 결함 때문에 전체 판정은 PARTIAL이다
- [ ] **USBL 후속 3건** — (1) `sigma == 0`이면 분포를 만들지 않고 평균을
  반환하며 음수는 거부하는 plugin-level guard를 구현해 Mac·Docker에서 다시 시험한다.
  (2) paused 상태에서 endpoint만 보이고 출력은 0인 현재 동작을 API/문서에 명시하거나
  callback pumping을 simulation pause와 분리할지 결정한다. (3) static tutorial geometry를
  넘어 이동 표적·travel time·장시간·다중 transceiver 정확성을 검증한다. 2026-08-27에
  common/individual과 두 transponder, 잘못된 Quickstart launcher는 직접 확인·정정했지만
  이 후속 범위와 upstream 보고는 열려 있다.
- [ ] **ROV 모델 후속 4건** — (1) 현재 RDP 이미지에 `mavros`·`mavros_msgs`와
  `libArduPilotPlugin.so`를 같은 환경으로 통합한 뒤 exact BlueROV2 launch에서 실제
  MAVROS/QGC 연결과 차량 제어를 확인한다. (2) `keyboard_publisher.py`의 non-TTY
  `.warn()` 실패 경로를 고친다. (3) `bluerov2_heavy_multibeam_sonar`의 silent sonar
  PointCloud2 원인을 분리하고 IMU topic·가짜 magnetometer bridge를 정리한다. (4) stock
  `empty.sdf`를 REXROV sensor 예제로 계속 쓸지, Sensors system이 있는 world로 문서를
  바꿀지 결정한다. 일반 thrust dynamics와 장시간·반복 안정성도 아직 검증하지 않았다.
- [ ] **Glider 모델 후속 3건** — (1) integrated `enable_deadband`에서 Gazebo→ROS는
  통과하지만 ROS→Gazebo가 관측되지 않은 원인을 좁힌다. 동일 Bool bridge의 isolated
  control은 양방향 통과했다. (2) `cmd_thrust=25.0`에서 관측된 `ang_vel=55776.3435`의
  설정·단위·calibration을 검토한다. 현재 결과는 coupling만 입증한다. (3) 이번 Mac
  `NOT_STEPPING`을 clean isolated session에서 반복하고, battery depletion·navigation·
  장시간 dynamics 범위를 별도 시험한다. 이전 `6/6`은 joint 세 경로를 제외했으므로
  actuator 완료 근거로 재사용하지 않는다.
- [ ] **World 내부 이름 중복 3그룹 정리·보고** — 2026-08-27 전체 18파일 감사에서 `oceans_waves` 3파일, `default` 2파일, `dvl_world` 2파일이 같은 내부 이름을 공유함을 확인했다. 파일명과 맞는 고유 이름으로 바꾸면 `/world/<name>/...` API가 달라지므로, 호환성 공지·launch/test 갱신 범위를 정한 뒤 확장된 issue 5를 제출해야 한다.
- [ ] **Object Models 실패 보고와 Fuel 재현성 정리** — 없는 descriptor를 요청하면 Gazebo
  서버는 파일 오류를 내고 entity를 만들지 않지만 `ros_gz_sim create`는 exit 0과
  `Entity creation successful`을 내며, `upload_object.launch.py`의 무조건적인
  `OnProcessExit`도 `Object Model Uploaded`를 출력한다. descriptor 존재를 launch 전에
  검사하고 server failure를 client exit로 전달한 뒤 성공 로그를 조건부로 바꿔야 한다.
  copied-source descriptor에 `/1` suffix를 넣어 Mac·Docker에서 build·spawn까지 했지만 두
  client 모두 requested version을 무시하고 latest tip만 지원한다고 경고했다. 따라서 이 환경의
  URL suffix를 pin으로 부르지 말고 vendoring 또는 별도 content-lock 방식을 정한다. Fuel account
  upload·Resource Spawner GUI·일반 object physics는 별도 범위다.
- [ ] **Underwater Camera 의 R/B 매핑 결정** — `attenuationR`/`backgroundR` 가 Blue 에,
  `attenuationB`/`backgroundB` 가 Red 에 적용된다(2026-08-26 런타임 확인,
  [`known-issues.md`](known-issues.md)). 고치는 방법은 두 가지이고 **어느 쪽인지는 상류가
  정할 문제다** — 루프에서 채널 index 를 뒤집거나, 태그 이름이 BGR 순서를 뜻한다고 문서화하거나.
  전자는 기존 world 파일의 출력을 바꾸고 후자는 안 바꾼다. 상류 보고 초안은 아직 없다
- [ ] **Underwater Camera 남은 범위** — 장면 1개·원본 색 1개로만 쟀고 murky 태그 6개를
  동시에 바꿨다. 태그를 하나씩 바꾼 확인, 여러 거리에서의 감쇠 곡선, scattering 관련 문서
  표현 점검은 아직이다. **`<scattering>` 은 별도 SDF 파라미터가 아니다** —
  `Configure()` 가 읽는 것은 `attenuationR/G/B` 와 `backgroundR/G/B` 6개뿐이다
- [ ] **깊이에 따라 힘이 달라지는지 확인** — 2026-08-25에 ModelPlugin 검증을 마쳤지만
  두 시험 모두 깊이 의존성을 의도적으로 제거했다. 보간은 **정지 프로브**로 쟀고(운동 없음),
  차량 반응 시험은 **12개 층을 같은 값으로 설정**한 뒤 측정했다. 따라서 "발행되는 해류가
  깊이에 따라 보간된다"까지는 확인됐고, **"서로 다른 깊이의 차량이 서로 다른 힘을 받는다"는
  아직 미확인**이다. 같은 world에서 깊이만 다른 두 차량, 또는 하강하는 한 차량으로 봐야 한다.
- [ ] **Ocean Current/Spherical Coordinates 플러그인 설치 경로 정리** — Mac 런타임
  `GZ_SIM_SYSTEM_PLUGIN_PATH` 에는
  `lib/<package>/` 가 들어 있었고 dylib 는 `lib/` 에 설치돼 있었다. **그 항목이 어디서
  주입되는지가 먼저다** — 두 패키지의 install 트리에는 `GZ_SIM_SYSTEM_PLUGIN_PATH` 를
  쓰는 파일이 없다([`known-issues.md`](known-issues.md) 참고). 출처를 찾은 뒤 한쪽을
  고치고 clean build 해서, 수동 경로 추가 없이 launch 되는지 확인해야 한다.
- [ ] **Ocean Current 후속 범위** — paused 상태 서비스 timeout 반복검증, ENU/NED
  의미 확인, tidal harmonic/CSV 시간 변화, non-zero Gauss-Markov noise,
  다중 차량 namespace 격리와 장시간 안정성은 아직 미검증이다.
- [ ] **상류 보고 8건 제출** — 전부 작성 완료, 하나도 안 보냄. 붙여넣기용 변환본과
  제출 순서는 [`upstream/submit/README.md`](upstream/submit/README.md) 에 있다.
  `IOES-Lab/dave` 는 공개 저장소이고 Issues 가 열려 있어 계정만 있으면 된다.
  7·8번은 SeaPressure 단위 오류와 동작하지 않는 설정을 다룬다. 2026-08-26에 Mac·Docker
  10조건 행렬로 다시 확인하고, `saturation`과 `update_rate`까지 런타임 근거를 추가했다:
  [`results/seapressure_full_validation_2026-08-26/`](results/seapressure_full_validation_2026-08-26/).
  **2026-08-25의 WGPU/CUDA/launch/Wiki 예제 발견은 이 기존 8건에 아직 포함되지 않는다**
- [ ] **`package.xml` 의존성 수정을 상류에 제안** — 이슈가 아니라 fork 후 PR 이어야 한다
- [ ] **저장소 이름 변경** — `ROS2_Lyrical_MacOS_Native_AppleSilicon` → `ROS2_Lyrical`.
  현재 이름은 macOS·Apple Silicon 만 말하지만 Docker/Linux 도 다뤘다.
  **조직 owner 만 할 수 있다** — 이 저장소에 대한 권한이 Maintain 이라 설정에 이름 칸이 없다.
  문서의 절대 URL 은 옛 이름으로 두었다. GitHub 이 옛 이름을 새 이름으로 리다이렉트하므로
  지금도, 이름을 바꾼 뒤에도 동작한다 (반대 방향은 안 된다)
- [ ] **WGPU 평면 거리 불일치 원인 규명** — PointCloud는 CPU/WGPU 모두 3.990244 m지만
  raw sonar는 CPU 3.988294 m, WGPU 6.396–6.446 m다. 범위 변환·버퍼 배치·FFT 이후
  index 해석을 단계별로 대조해야 한다. 현재는 원인 미확정
- [ ] **백엔드 실패 경로와 새 발견의 상류 보고 여부 결정** — Apple M2에서 명시적 CUDA 요청이
  clean rejection이 아니라 Gazebo 종료와 잔류 프로세스로 이어졌다. `-r-v 4` launch 인자,
  BlueROV2 소나 예제, RViz 창 미생성도 기존 준비된 8개 이슈에는 포함되지 않는다
- [ ] **소나 확장 방향 결정** — Profiling / Mechanical scanning / Side-scan.
  장비 분류·스펙·타 시뮬레이터 현황은 Notion 「소나 종류 분류」 에,
  코드 구조와 논문 수식 대응은 Notion 「DAVE 소나 코드 구조」 에 정리했다.
  **이 문서들은 결정하지 않는다** — 어느 응용을 지원할지, 정확도를 어떻게 검증할지,
  대조할 실장비가 있는지가 먼저다
- [ ] **LICENSE 추가** — 공개 저장소인데 라이선스가 없어 남이 법적으로 쓸 수 없다.
  `IOES-Lab/dave` 는 Apache 2.0 이다. 랩 저장소이므로 어느 라이선스로 할지는 확인이 필요하다
- [ ] **맥 재현 절차의 빈 단계** — `extras/build-dave-lyrical-macos.sh` 가 ROS 2 Lyrical
  소스 빌드 단계에서 멈춘다. 2026-07-06 에 쓴 명령이 기록에 없다.
  `.zsh_history` 에 남아 있으면 복원 가능하고, 아니면 Docker 경로가 완전한 대안이다

## 완료

- [x] **DAVE 문서(Wiki) 정정** — 2026-08-27까지 열네 차례 완료. 경위는
  [`wiki/README.md`](wiki/README.md) 참고. 2026-07-20에 4건, 2026-08-20에
  16건을 12페이지에 반영했고, 2026-08-21에는 우리 쪽의 잘못되거나 오래된
  주석 6건을 다시 정정했다. 2026-08-25에는 Multibeam 페이지의 미검증 예제를
  직접 실행해 CPU/WGPU·RViz·BlueROV2·CUDA 판정을 갱신했다. 같은 날 Ocean Current 페이지도 12개 서비스와 전역 Hydrodynamics 차량 반응을 직접 재검증하고, Model Plugin 미검증 범위를 분리했다.
  2026-08-26에는 Underwater Camera 페이지를 Mac·Docker에서 재실행해 출력 구조와
  감쇠식을 확인하고, R/B 파라미터가 뒤바뀌어 적용된다는 경고와 `<scattering>`이
  별도 파라미터가 아니라는 정정을 넣었다. 같은 날 DVL 페이지의 launch 인자와
  bridge 설명을 소스·런타임에 맞추고, Docker 통과 범위와 Mac crash·frame ID·water-mass
  한계를 분리해 기록했다. 이어 SeaPressure 페이지를 Mac·Docker 10조건 행렬에 맞춰
  갱신해 단위·무시되는 세 설정·`abs(z)`·빈 `frame_id`와 실제 동작하는 네 설정을 분리했다.
  Spherical Coordinates 페이지의 현재 world 원점, 부호가 뒤집힌 변환 예제,
  입력 검증과 Mac/Docker 플러그인 발견 범위를 직접 실행 결과로 교체했다.
  2026-08-27에는 USBL common/individual 경로와 paused·`sigma=0` 통제를 양쪽 플랫폼에서
  재실행하고, 없는 센서 모델을 spawn하던 Quickstart를 world-only launcher로 교체했다.
  같은 날 Dave ROV Models의 exact/isolated 경로를 Mac·Docker에서 실행해 REXROV 7/7,
  fifth multibeam variant의 runtime PARTIAL, standalone Joy PASS와 통합 MAVROS blocker를
  현재 판정으로 반영했다.
  이어 Dave World Models의 18개 파일 전체를 대조해 14개 내부 이름과 3개 중복 그룹을
  기록하고, Mac·Docker Quickstart의 진행을 다시 확인했다.
  Dave Glider Models는 두 Wiki launch와 9개 bridge topic을 다시 실행해 state/sensor와
  actuator 범위를 분리했다. Object Models는 유일한 배포 descriptor와 일반 Fuel URL,
  copied-source custom descriptor를 Mac·Docker에서 확인하고, missing-descriptor 성공 오보고와
  현재 client가 `/1`을 immutable pin으로 보장하지 않는다는 점을 현재 판정에 반영했다.
  **초안을 "전달"한 게 아니라 문서를 직접 고쳤다**

완료된 항목의 전체 이력은 [`progress-log.md`](progress-log.md) 에 있다.
