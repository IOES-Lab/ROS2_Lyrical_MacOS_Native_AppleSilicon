# wiki/ — DAVE 문서 정정

DAVE 의 공식 문서는 [`dave-ros2.notion.site`](http://dave-ros2.notion.site) 다. GitHub wiki 가
아니라 노션 사이트이므로, 정정은 PR 이 아니라 페이지를 직접 편집하는 방식이다.

**두 차례에 걸쳐 반영했다. 이 폴더의 초안들은 그 근거 기록이다.**

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

7월 이후 검증에서 나온 것들. **문서에 들어갈 성격의 12건**을 9개 페이지에 넣었다.

| 항목 | 어느 페이지 | 근거 |
|---|---|---|
| 빌드에 `-O` 플래그가 없음 | 설치 매뉴얼 2 + 모델 4 | RTF 0.2180 → 0.4380 |
| `<sigma>0.0</sigma>` 이 Gazebo **서버**를 죽임 | USBL Plugin | 튜토리얼 예제가 그 값을 가르치고 있었다 |
| `paused:=false` 없으면 모든 ROS 콜백 차단 | USBL Plugin | Quick Start 명령에 없었다 |
| `update_rate` 30 Hz 도달 불가 · P900 SDF 불일치 | Multibeam Sonar | 데이터시트 "up to 15 Hz" |
| 소나가 145~175초 뒤에야 살아남 | Multibeam Sonar | 그 전 측정은 전부 무효 |
| world 이름 `oceans_waves` 충돌 | Dave World Models | 우리가 실제로 측정을 잘못 귀속시켰다 |
| 차량 IMU 가 ROS 에 도달하지 않음 | ROV · Glider Models | 4대 전후 측정 |
| Fast DDS 스폰 무한 대기 | Installation Tutorial | 공유메모리 1/9, UDPv4 5/5 |
| `gui:=true headless:=true` 조합 | Installation Tutorial | |
| `dave_world.launch.py` headless 부재 | Installation Tutorial | manipulation world 3개가 막혀 있었다 |
| `ogre` 우회에 인가된 X 디스플레이 필요 | Native 매뉴얼 | [`ogre-x-display-doc-correction.md`](ogre-x-display-doc-correction.md) |
| aarch64 OGRE2 미지원 · 소나 segfault · WGPU CPU 폴백 | Docker 매뉴얼 | |

형식은 1차와 맞췄다 — **기존 문장을 지우지 않고** `Added 2026-08-20` /
`Corrected 2026-08-20` 으로 표시해 무엇이 왜 바뀌었는지 남게 했다.

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
