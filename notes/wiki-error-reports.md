# DAVE ROS2 Wiki — 오류 신고 초안

[DAVE ROS2 Wiki](http://dave-ros2.notion.site) 전체(20페이지)를 정독하며 발견한 사항을 신고 형식으로 정리했다. Wiki 관리자에게 전달할 초안이며, 카테고리별로 분류했다. 근거 자료는 [`dave-wiki-inaccuracies.md`](dave-wiki-inaccuracies.md) 참조.

## 카테고리 1 — 기능 오류 (패키지/토픽명 등 잘못된 실행 정보)

### 1. SeaPressure Plugin 페이지

```text
Page: SeaPressure Plugin
Current text: ros2 launch dave_robot_launch robot_in_world.launch.py ...
              (토픽: /rexrov/Pressure)
Observed problem: `dave_robot_launch` 패키지가 존재하지 않음 (`ros2 pkg list` 확인).
                   토픽명도 실제와 다름.
Verified correction: SeaPressure 플러그인은 별도 launch 파일 없이 표준 REXROV spawn
                   (`dave_demos dave_robot.launch.py`)에 자동으로 포함되어 있음.
                   실제 토픽은 `/model/rexrov/sea_pressure`,
                   `/model/rexrov/sea_pressure_depth`.
Evidence/command: ros2 pkg list | grep dave_robot_launch   # 결과 없음
                   ros2 launch dave_demos dave_robot.launch.py z:=-5 \
                     namespace:=rexrov world_name:=dave_ocean_waves paused:=false
                   ros2 topic list | grep sea_pressure
Suggested replacement: launch 명령어를 `dave_demos dave_robot.launch.py` 기준으로 교체,
                   토픽명을 `/model/rexrov/sea_pressure`,
                   `/model/rexrov/sea_pressure_depth`로 수정.
```

## 카테고리 2 — 빈 페이지

### 2. "Create New Robot Model" 페이지

```text
Page: Create New Robot Model
Current text: (제목만 있고 본문 없음)
Observed problem: 완전히 빈 placeholder 페이지.
Verified correction: 해당 없음 (내용 자체가 없어 별도 검증 불가).
Evidence/command: Wiki 페이지 직접 확인, 2026-07-14 기준 본문 0줄.
Suggested replacement: 내용 작성 또는 "작성 예정" 명시 필요.
```

### 3. "Build World using Heightmap" 페이지

```text
Page: Build World using Heightmap
Current text: (제목만 있고 본문 없음)
Observed problem: 완전히 빈 placeholder 페이지.
Verified correction: 해당 없음 (내용 자체가 없어 별도 검증 불가).
Evidence/command: Wiki 페이지 직접 확인, 2026-07-14 기준 본문 0줄.
Suggested replacement: 내용 작성 또는 "작성 예정" 명시 필요.
```

## 카테고리 3 — 중복/오래된 페이지

### 4. "Multi-beam Sonar Plugin" (하이픈 표기) 페이지

```text
Page: Multi-beam Sonar Plugin (hyphenated)
Current text: 4줄짜리 `apt install` 스니펫만 있음.
Observed problem: 현재 정식 페이지인 "Multibeam Sonar Plugin"(하이픈 없음)의
                   오래된 중복본으로 보임 — 두 페이지가 동시에 존재해 혼동 유발.
Verified correction: "Multibeam Sonar Plugin"(하이픈 없음) 페이지가 최신·완전한 버전.
Evidence/command: 두 페이지 내용 비교, 마지막 수정일 비교.
Suggested replacement: 하이픈 표기 페이지를 삭제하거나 최신 페이지로 리다이렉트.
```

## 카테고리 4 — 문서 누락

### 5. "Local Search Scenario" 데모 (sonar-demo 브랜치 의존)

```text
Page: Multibeam Sonar Plugin
Current text: "(currently available in the sonar-demo branch - TO BE MERGED)"
              — 링크 없는 일반 텍스트로만 표기.
Observed problem: 어느 저장소/브랜치인지 URL이 전혀 없음.
Verified correction: `sonar-demo` 브랜치는 `IOES-Lab/dave`에 존재함
                   (`naitikpahwa18/dave`에는 없음) — GitHub API로 확인.
Evidence/command: curl -s https://api.github.com/repos/IOES-Lab/dave/branches/sonar-demo
Suggested replacement: 실제 브랜치 링크
                   (https://github.com/IOES-Lab/dave/tree/sonar-demo) 추가.
```

## 참고 — 페이지별 오류는 아니지만 공유할 만한 사항

- Wiki 전체 20페이지 중 **"Lyrical" 또는 "Jetty" 언급이 단 한 번도 없음** — 최근에 수정된 페이지(Native Local Installation Manual, System Requirements 등)도 포함. 현재 Wiki는 전적으로 ROS 2 Jazzy + Gazebo Harmonic 기준으로 작성되어 있다.
- "Migration Progress" 인라인 Notion 데이터베이스는 원래 ROS 1 → ROS 2/Harmonic 마이그레이션만 추적하고 있어(마지막 수정 2025-02-11), 이번 Lyrical/Jetty 검증과는 관련이 없다 — 새 항목을 추가할지, 별도 트래커를 만들지는 Wiki 관리자·교수님과 논의가 필요.

## 보내는 방법 (결정 필요)

이 초안을 실제로 어떻게 전달할지는 아직 정하지 않았다 — Notion 페이지에 코멘트로 남길지, 교수님을 통해 전달할지, 별도 이슈 트래커가 있는지 확인 필요.
