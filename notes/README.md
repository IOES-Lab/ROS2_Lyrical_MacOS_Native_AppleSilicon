# notes/ — 무엇이 어디에 있나

이 폴더는 검증 과정에서 나온 **원자료와 작업 문서**다. 결론은 저장소 루트의
[`README.md`](../README.md)에 있고, 여기에는 그 결론을 뒷받침하는 것들이 있다.

2026-08-19 에 재편했다. 그전에는 31개 파일이 이 층에 성격 구분 없이 쌓여 있었다.

## 폴더

| 폴더 | 내용 |
|---|---|
| [`upstream/`](upstream/) | 상류에 보고할 것. [`drafts/`](upstream/drafts/) 가 원본, [`submit/`](upstream/submit/) 이 붙여넣기용 변환본, [`make_submittable.py`](upstream/make_submittable.py) 가 변환기 |
| [`wiki/`](wiki/) | DAVE 문서(`dave-ros2.notion.site`)의 오류 정정. 이슈가 아니라 문서 수정 제안 |
| [`results/`](results/) | 날짜별 실험 결과. [`worlds/`](results/worlds/) 는 world 18종 스모크 테스트 로그 |
| [`experiments/`](experiments/) | 실험 스크립트. [`common.sh`](experiments/common.sh) 가 공통 측정 절차 |
| [`benchmarks/`](benchmarks/) | 초기 벤치마크 스크립트와 결과 (7월). `bench_results/SUPERSEDED_*` 는 폐기된 회차 |
| [`stability/`](stability/) | 장시간 안정성 시험. 폴더명의 `CONTAMINATED`·`PRE_LEAKFIX_SCRIPT` 는 **그 회차를 신뢰하지 말라는 표시** |
| [`setup/`](setup/) | 환경 구축 메모 (ArduSub SITL, `ros_gz` repos, dockwater 초안) |
| [`evidence/`](evidence/) | 개별 주장에 대한 근거 문서 |
| [`meeting/`](meeting/) | 랩 미팅 보고서 |

## 이 층의 파일

루트 [`README.md`](../README.md) 는 입구 역할만 한다. 상류 저장소(`IOES-Lab/dave`,
`dockwater`)의 README 도 그렇게 쓰므로 형식을 맞췄다. 실제 내용은 아래에 있다.

| 파일 | 내용 |
|---|---|
| [`validation_matrix.csv`](validation_matrix.csv) | 검증 항목 전체 표. **무엇이 PASS 이고 무엇이 안 해본 것인지**의 기준 |
| [`verified-demos.md`](verified-demos.md) | 각 판정이 무엇에 근거하는지 |
| [`known-issues.md`](known-issues.md) | 알려진 문제 25건, 증상·원인·우회 |
| [`progress-log.md`](progress-log.md) | 날짜별 작업 73행. 무엇이 나중에 뒤집혔는지가 Notes 열에 있다 |
| [`sonar-performance.md`](sonar-performance.md) | 소나 측정값과 이전 수치를 대체한 경위 |
| [`patch-and-pinned-commits.md`](patch-and-pinned-commits.md) | 고정 커밋과 이식 패치의 현재 상태 |
| [`next-steps.md`](next-steps.md) | 아직 열려 있는 항목 |
| [`status-history.md`](status-history.md) | 옛 상태 요약. 어떤 주장이 언제 철회됐는지 추적용 |
| [`cmake-migration-patterns.md`](cmake-migration-patterns.md) | Harmonic→Jetty 이식에서 반복된 패턴 |
| [`usbl-gui-crash-investigation.md`](usbl-gui-crash-investigation.md) | USBL 크래시 추적. 초기 가설(GUI 문제)이 틀렸던 과정이 남아 있다 |

## 읽는 순서

처음이면 [`validation_matrix.csv`](validation_matrix.csv) → 루트 `README.md` 의 Progress Log →
관심 있는 항목의 [`results/`](results/) 하위 폴더.

상류 보고를 맡았다면 [`upstream/submit/README.md`](upstream/submit/README.md) 하나만 보면 된다.

## 폐기된 자료를 지우지 않는 이유

`SUPERSEDED_*`, `CONTAMINATED`, `PRE_LEAKFIX_SCRIPT` 가 붙은 것들은 **틀린 결과이지만
남겨둔다.** 어떤 수치가 언제 왜 바뀌었는지 추적할 수 있어야 하고, 지우면 그 이력이
사라진다. 인용할 때는 이름에 붙은 표시를 먼저 볼 것.
