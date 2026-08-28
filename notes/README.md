# notes/ — 무엇이 어디에 있나

이 폴더는 검증 과정에서 나온 **원자료와 작업 문서**다. 결론은 저장소 루트의
[`README.md`](../README.md)에 있고, 여기에는 그 결론을 뒷받침하는 것들이 있다.

2026-08-19 에 재편했다. 그전에는 31개 파일이 이 층에 성격 구분 없이 쌓여 있었다.

## 폴더

| 폴더 | 내용 |
|---|---|
| [`upstream/`](upstream/) | 상류에 보고할 것. [`drafts/`](upstream/drafts/) 가 원본, [`submit/`](upstream/submit/) 이 붙여넣기용 변환본, [`make_submittable.py`](upstream/make_submittable.py) 가 변환기 |
| [`wiki/`](wiki/) | DAVE 문서(`dave-ros2.notion.site`) 정정. **2026-07-20·08-20·08-21·08-25(소나·해류)·08-26(카메라·DVL·SeaPressure·Spherical Coordinates)·08-27(USBL·ROV·World·Glider·Object Models) 열다섯 차례 반영 완료** — 경위와 일부러 빼놓은 것은 [`wiki/README.md`](wiki/README.md) |
| [`results/`](results/) | 날짜별 실험 결과. [`worlds/`](results/worlds/) 는 world 18종 스모크 테스트 로그 |
| [`experiments/`](experiments/) | 실험 스크립트. [`common.sh`](experiments/common.sh) 가 공통 측정 절차 |
| [`benchmarks/`](benchmarks/) | 초기 벤치마크 스크립트와 결과 (7월). `bench_results/SUPERSEDED_*` 는 폐기된 회차 |
| [`stability/`](stability/) | 장시간 안정성 시험. 폴더명의 `CONTAMINATED`·`PRE_LEAKFIX_SCRIPT` 는 **그 회차를 신뢰하지 말라는 표시** |
| [`setup/`](setup/) | 환경 구축 메모 (ArduSub SITL, `ros_gz` repos, dockwater 초안) |
| [`evidence/`](evidence/) | 개별 주장에 대한 근거 문서 |
| [`meeting/`](meeting/) | 랩 미팅 보고서 |

최신 소나 직접 검증:
[`results/multibeam_direct_validation_2026-08-25/`](results/multibeam_direct_validation_2026-08-25/).
Wiki 명령, 사용자 정의 센서/world, Docker RDP, CPU/WGPU 평면 표적과 CUDA 실패 경로를
실제로 실행한 기록이다.


최신 해류 직접 검증:
[`results/ocean_current_direct_validation_2026-08-25/`](results/ocean_current_direct_validation_2026-08-25/)와
[`results/full_gap_validation_2026-08-27/08_ocean_depth_force/`](results/full_gap_validation_2026-08-27/08_ocean_depth_force/).
전역 12개 서비스와 REXROV 반응에 더해, 고정 깊이 두 차량을 동시에 둔 Docker 통제에서
5 m 차량은 0 m/s·Δx 0, 15 m 차량은 시작 0.750000 m/s·6초 Δx 2.400436 m였다.
차량별 깊이 의존 경로와 두 namespace는 검증 범위 내 PASS이며, 계수·실해양 정확도는 아니다.

최신 수중 카메라 직접 검증:
[`results/underwater_camera_direct_validation_2026-08-26/`](results/underwater_camera_direct_validation_2026-08-26/)와
[`results/full_gap_validation_2026-08-27/04_underwater_tag_and_range_matrix/`](results/full_gap_validation_2026-08-27/04_underwater_tag_and_range_matrix/).
Docker 12조건에서 여섯 태그를 각각 바꾸고 1·2·4·6 m를 대조했다. 모든 BGR 채널은
거리와 함께 감소했지만, `R` 태그는 Blue에, `B` 태그는 Red에 적용되는 의미론 결함이
재확인됐다. 2026-08-27 fresh Mac 재시험은 image topic이 없어 이전 Mac 성공과 별도로 보존한다.

최신 DVL 직접 검증:
[`results/dvl_direct_validation_2026-08-26/`](results/dvl_direct_validation_2026-08-26/)와
[`results/full_gap_validation_2026-08-27/03_dvl_all_models_docker/`](results/full_gap_validation_2026-08-27/03_dvl_all_models_docker/).
기존 bottom·velocity·수정 water-mass 통제에 이어 배포 descriptor 8개를 Docker에서 모두
실행했다. 4개는 four-beam 메시지를 냈고 4개는 100 m water-mass far boundary가 각 센서의
66–90 m maximum range를 넘어 초기화에 실패했다. Mac crash·빈 `frame_id`·배포 water-variable
이름 문제도 남아 전체 판정은 PARTIAL이다.

최신 SeaPressure 직접 검증:
[`results/seapressure_full_validation_2026-08-26/`](results/seapressure_full_validation_2026-08-26/)와
[`results/full_gap_validation_2026-08-27/05_seapressure_extreme_pause_long/`](results/full_gap_validation_2026-08-27/05_seapressure_extreme_pause_long/).
기존 10조건의 단위·무시 설정·`abs(z)`·빈 frame 결함은 유지된다. 추가 Mac 통제에서 paused
5초 동안 0프레임, surface 10,000개 monotonic 1 kHz 프레임, ±1000 m에서 같은 9907.705를
확인했다. 이는 결함 있는 구현의 실행 안정성이지 ROS 계약 정확성 PASS가 아니다.

최신 Spherical Coordinates 직접 검증:
[`results/spherical_coordinates_direct_validation_2026-08-26/`](results/spherical_coordinates_direct_validation_2026-08-26/)와
[`results/full_gap_validation_2026-08-27/02_spherical_independent_geodesy/`](results/full_gap_validation_2026-08-27/02_spherical_independent_geodesy/).
독립 WGS-84/ECEF/ENU oracle로 4지역 13점을 검증했다. 최대 오차는 위도 6.64e-12°,
경도 3.13e-13°, 고도 5.16e-7 m, 역변환 ENU 축 1.80e-7 m였다. 유효 입력 정확도는
검증 범위 내 PASS지만 NaN·범위 밖 입력 수락과 Mac plugin-path 결함 때문에 전체는 PARTIAL이다.

최신 USBL 직접 검증:
[`results/usbl_direct_validation_2026-08-27/`](results/usbl_direct_validation_2026-08-27/)와
[`results/full_gap_validation_2026-08-27/07_usbl_motion_latency/`](results/full_gap_validation_2026-08-27/07_usbl_motion_latency/).
정적 common/individual routing에 더해 이동 표적의 median x가 2.999954 m에서 8.999973 m로
변하는 것을 확인했다. 그러나 sound speed 1540 m/s에서 1539 m median latency는 0.002803초,
1541 m는 1.010797초여서 integer-second `sleep()` 양자화 결함이 드러났다. 기존 launcher,
paused callback, Docker `sigma=0` 우회도 유지된다.

최신 ROV 모델 직접 검증:
[`results/rov_direct_validation_2026-08-27/`](results/rov_direct_validation_2026-08-27/).
REXROV는 Mac의 sensor-enabled ocean world에서 7/7 메시지 내용을 직접 확인했다. 다섯 번째
`bluerov2_heavy_multibeam_sonar` 변형은 이제 source-only가 아니다 — Mac·Docker에서 spawn과
odometry는 통과했지만 IMU·magnetometer·sonar PointCloud2가 120초 동안 발행되지 않았다.
Docker의 standalone keyboard/WebSocket Joy 경로는 통과했지만, exact BlueROV2 통합 launch는
현재 이미지의 `mavros`·`mavros_msgs` 부재로 완료되지 않는다.

최신 Glider 모델 직접 검증:
[`results/glider_direct_validation_2026-08-27/`](results/glider_direct_validation_2026-08-27/)와
[`results/full_gap_validation_2026-08-27/06_glider_deadband_integrated/`](results/full_gap_validation_2026-08-27/06_glider_deadband_integrated/).
상태/센서 6/6과 `cmd_thrust` coupling에 더해 integrated deadband를 반복 송신했다.
ROS `true` 50개가 Gazebo `true` 50개로 관측되고 false는 0개여서, 이전 one-shot timeout의
비대칭 주장은 철회했다. Calibration, fresh Mac stepping과 장시간 dynamics는 여전히 별도다.

최신 World Models 전체 감사:
[`results/world_models_audit_2026-08-27/`](results/world_models_audit_2026-08-27/).
18개 배포 world의 내부 이름을 Mac source·Docker source·Docker install에서 대조했다. 고유 이름은 14개뿐이고 **7개 파일이 `oceans_waves`·`default`·`dvl_world` 세 중복 그룹**에 속한다. `dave_ocean_waves` Quickstart는 Mac·Docker에서 다시 진행을 확인했지만, 나머지 17행은 기존 날짜의 증거를 유지하며 SMOKE를 기능 검증으로 올리지 않았다.

최신 Object Models 직접 검증:
[`results/object_models_direct_validation_2026-08-27/`](results/object_models_direct_validation_2026-08-27/).
배포된 유일한 descriptor `mossy_cinder_block`의 정확한 Wiki 명령을 Mac·Docker에서
실행해 model 존재와 simulation progress를 확인했다. 일반 Teledyne URL과 copied-source
custom descriptor도 양쪽에서 spawn했다. **전체는 PARTIAL**이다 — 없는 descriptor는 entity가
없어도 성공 문구를 내고, `/1` 요청도 두 client가 latest tip만 지원한다고 경고하므로 immutable
Fuel pin이 아니다.

## 이 층의 파일

루트 [`README.md`](../README.md) 는 입구 역할만 한다. 상류 저장소(`IOES-Lab/dave`,
`dockwater`)의 README 도 그렇게 쓰므로 형식을 맞췄다. 실제 내용은 아래에 있다.

| 파일 | 내용 |
|---|---|
| [`what-we-got-wrong.md`](what-we-got-wrong.md) | **틀렸던 주장과 그걸 잡아낸 경위.** 여기 수치를 믿기 전에 읽을 것 |
| [`validation_matrix.csv`](validation_matrix.csv) | 검증 항목 전체 표. **무엇이 PASS 이고 무엇이 안 해본 것인지**의 기준 |
| [`verified-demos.md`](verified-demos.md) | 각 판정이 무엇에 근거하는지 |
| [`known-issues.md`](known-issues.md) | 48개 항목(현재 문제·해결·철회 이력 포함), 증상·원인·우회 |
| [`progress-log.md`](progress-log.md) | 날짜별 작업 96행. 무엇이 나중에 뒤집혔는지가 Notes 열에 있다 |
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
