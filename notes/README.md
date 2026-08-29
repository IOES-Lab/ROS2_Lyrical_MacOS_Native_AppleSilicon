# notes/ — 무엇이 어디에 있나

이 폴더는 검증 과정에서 나온 **원자료와 작업 문서**다. 결론은 저장소 루트의
[`README.md`](../README.md)에 있고, 여기에는 그 결론을 뒷받침하는 것들이 있다.

2026-08-19에 재편했고, 2026-08-29에 재현 가능한 잔여 결함을 후보 패치로 닫은 뒤
현재 판정과 역사 기록을 다시 분리했다.

## 폴더

| 폴더 | 내용 |
|---|---|
| [`upstream/`](upstream/) | 상류 보고 초안. 2026-08-29 패치 결과를 반영하기 전에는 그대로 제출하지 않는다 |
| [`wiki/`](wiki/) | DAVE Notion Wiki 정정 이력과 범위 |
| [`results/`](results/) | 날짜별 실험 결과와 기계 판독 가능한 요약 |
| [`experiments/`](experiments/) | 실험 스크립트와 공통 측정 절차 |
| [`benchmarks/`](benchmarks/) | 초기 벤치마크와 superseded 결과 |
| [`stability/`](stability/) | 장시간 시험; 폴더명 경고를 먼저 읽어야 한다 |
| [`setup/`](setup/) | 환경 구축 기록 |
| [`evidence/`](evidence/) | 개별 주장 근거 |
| [`meeting/`](meeting/) | 랩 미팅 자료 |

## 현재 기준선 — 2026-08-29

[`results/remaining_defect_fixes_2026-08-29/`](results/remaining_defect_fixes_2026-08-29/)은
기존 감사에서 남은 재현 가능한 결함을 수정한 최초 **8개 후보 패치**의 Mac/Docker 결과다.
최종 open-gap sweep에서 fifth-ROV sonar world 누락을 닫은 9번째 후보와 현재 재검증은
[`results/open_gap_revalidation_2026-08-29/`](results/open_gap_revalidation_2026-08-29/)에 있다.
상류 DAVE checkout과 사용자 설치 workspace를 수정했다는 뜻은 아니다.

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

여전히 열린 범위는 Mac stock Gazebo DVL SIGSEGV, NVIDIA/하드웨어 GPU, RViz Mac 창,
BlueROV2의 누락된 ArduPilot Gazebo plugin·QGC SIGSEGV·disconnected MAVROS loop, Fast DDS와
fresh Mac camera의 **과거 실패 trigger** 재현, sonar 30 Hz·ROV/Glider calibration 결정,
Fuel immutable pin/upload, Windows/WSL·HIL과 일반 음향·광학·유체역학·장시간 정확도다.
Docker `ogre2` sonar와 fresh Mac camera는 2026-08-29 현재 재검증에서 각각 출력 1회와 3/3을
통과했으므로 현재 기능 실패로 쓰지 않는다. 자세한 목록은
[`next-steps.md`](next-steps.md)에 있다.

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
| [`known-issues.md`](known-issues.md) | 48개 항목(열림·후보 패치 해결·철회 이력 포함), 현재 처리는 문서 맨 위 표 참고 |
| [`progress-log.md`](progress-log.md) | 날짜별 작업 99행. 무엇이 나중에 뒤집혔는지가 Notes 열에 있다 |
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
