# notes/ — 무엇이 어디에 있나

이 폴더는 검증 과정에서 나온 **원자료와 작업 문서**다. 결론은 저장소 루트의
[`README.md`](../README.md)에 있고, 여기에는 그 결론을 뒷받침하는 것들이 있다.

2026-08-19 에 재편했다. 그전에는 31개 파일이 이 층에 성격 구분 없이 쌓여 있었다.

## 폴더

| 폴더 | 내용 |
|---|---|
| [`upstream/`](upstream/) | 상류에 보고할 것. [`drafts/`](upstream/drafts/) 가 원본, [`submit/`](upstream/submit/) 이 붙여넣기용 변환본, [`make_submittable.py`](upstream/make_submittable.py) 가 변환기 |
| [`wiki/`](wiki/) | DAVE 문서(`dave-ros2.notion.site`) 정정. **2026-07-20·08-20·08-21·08-25(소나·해류)·08-26(카메라·DVL·SeaPressure·Spherical Coordinates) 아홉 차례 반영 완료** — 경위와 일부러 빼놓은 것은 [`wiki/README.md`](wiki/README.md) |
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
[`results/ocean_current_direct_validation_2026-08-25/`](results/ocean_current_direct_validation_2026-08-25/).
12개 서비스, 정상·비정상 입력, 원상복구와 전역 `/ocean_current`가 REXROV 운동에
미치는 효과를 직접 확인했다. 차량별 `OceanCurrentModelPlugin` 경로는 같은 날
[`results/ocean_current_model_plugin_validation_2026-08-25/`](results/ocean_current_model_plugin_validation_2026-08-25/)
에서 따로 검증했다 — 층 중점 두 곳의 보간과 차량 운동까지 확인했고,
**깊이에 따라 힘이 달라지는지는 아직 미검증**이다.

최신 수중 카메라 직접 검증:
[`results/underwater_camera_direct_validation_2026-08-26/`](results/underwater_camera_direct_validation_2026-08-26/).
Wiki Quickstart 를 Mac 과 Docker 에서 재실행하고, 통제된 세 조건의 픽셀값을 구현식과
대조했다. **출력은 FUNCTIONAL PASS 이지만 `attenuationR` 이 Blue 에, `attenuationB` 가
Red 에 적용된다** — 파라미터 의미론은 PARTIAL 이다. 일반 수중 광학 정확성은 검증하지 않았다.

최신 DVL 직접 검증:
[`results/dvl_direct_validation_2026-08-26/`](results/dvl_direct_validation_2026-08-26/).
Docker 에서 Wiki Quickstart, 평면 bottom range, 1 m/s 이동, 공식 `ros_gz` bridge와
환경변수 기반 water-mass tracking을 직접 확인했다. **전체 판정은 PARTIAL**이다 — 같은
DVL 센서 경로가 Mac에서 네 가지 통제 조건 모두 Gazebo Sensors render thread에서
종료하고, DAVE custom bridge는 `frame_id`를 잃으며, 배포 모델의 water-mass 태그는
환경변수 이름 대신 `0.`을 사용한다.

최신 SeaPressure 직접 검증:
[`results/seapressure_full_validation_2026-08-26/`](results/seapressure_full_validation_2026-08-26/).
Mac·Docker에서 통제 조건 10개를 실행했고 압력·variance·depth-topic 존재 여부가 모두
일치했다. `standard_pressure`·`kPa_per_meter`·`topic`·`estimate_depth_on`은 동작하지만,
**Pascal 필드의 kPa 크기 값, 무시되는 `saturation`·`noise_sigma`·`update_rate`, `abs(z)`,
빈 ROS `frame_id` 때문에 전체 판정은 PARTIAL**이다.

최신 Spherical Coordinates 직접 검증:
[`results/spherical_coordinates_direct_validation_2026-08-26/`](results/spherical_coordinates_direct_validation_2026-08-26/).
Mac·Docker에서 네 서비스를 호출하고 유한점 3개를 왕복 변환했다. 양성 경로의 최대 축
오차는 `9.71e-10 m`이었지만, Wiki 원점·변환 결과가 현재 world/runtime과 맞지 않고
NaN·범위 밖 원점을 받아들이며, Mac 기본 플러그인 경로에서는 서비스가 나타나지 않아
**전체 판정은 PARTIAL**이다. Docker 기본 경로에서는 `install/lib`가
`LD_LIBRARY_PATH`에 있어 네 서비스가 그대로 나타났다.

## 이 층의 파일

루트 [`README.md`](../README.md) 는 입구 역할만 한다. 상류 저장소(`IOES-Lab/dave`,
`dockwater`)의 README 도 그렇게 쓰므로 형식을 맞췄다. 실제 내용은 아래에 있다.

| 파일 | 내용 |
|---|---|
| [`what-we-got-wrong.md`](what-we-got-wrong.md) | **틀렸던 주장과 그걸 잡아낸 경위.** 여기 수치를 믿기 전에 읽을 것 |
| [`validation_matrix.csv`](validation_matrix.csv) | 검증 항목 전체 표. **무엇이 PASS 이고 무엇이 안 해본 것인지**의 기준 |
| [`verified-demos.md`](verified-demos.md) | 각 판정이 무엇에 근거하는지 |
| [`known-issues.md`](known-issues.md) | 41개 항목(현재 문제·해결·철회 이력 포함), 증상·원인·우회 |
| [`progress-log.md`](progress-log.md) | 날짜별 작업 83행. 무엇이 나중에 뒤집혔는지가 Notes 열에 있다 |
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
