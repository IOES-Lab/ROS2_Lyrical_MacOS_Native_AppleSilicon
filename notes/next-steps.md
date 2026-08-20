<!-- README.md 에서 분리했다. 2026-08-19, 상류 저장소(IOES-Lab/dave, dockwater)의
     README 형식에 맞추면서 옮긴 것이다 — 그쪽 README 는 입구 역할만 하고
     내용은 별도 문서에 둔다. -->

# 남은 일

- [ ] **상류 보고 6건 제출** — 전부 작성 완료, 하나도 안 보냄. 붙여넣기용 변환본과
  제출 순서는 [`upstream/submit/README.md`](upstream/submit/README.md) 에 있다.
  `IOES-Lab/dave` 는 공개 저장소이고 Issues 가 열려 있어 계정만 있으면 된다
- [ ] **`package.xml` 의존성 수정을 상류에 제안** — 이슈가 아니라 fork 후 PR 이어야 한다
- [ ] **저장소 이름 변경** — `ROS2_Lyrical_MacOS_Native_AppleSilicon` → `ROS2_Lyrical`.
  현재 이름은 macOS·Apple Silicon 만 말하지만 Docker/Linux 도 다뤘다.
  **조직 owner 만 할 수 있다** — 이 저장소에 대한 권한이 Maintain 이라 설정에 이름 칸이 없다.
  문서의 절대 URL 은 옛 이름으로 두었다. GitHub 이 옛 이름을 새 이름으로 리다이렉트하므로
  지금도, 이름을 바꾼 뒤에도 동작한다 (반대 방향은 안 된다)
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

- [x] **DAVE 문서(Wiki) 정정** — 2026-08-20 완료. 경위는
  [`wiki/README.md`](wiki/README.md) 참고. 7월 보고서 4건은 이미 2026-07-20 에
  반영돼 있었고, 8월에 나온 12건을 페이지 9곳에 넣었다.
  **초안을 "전달"한 게 아니라 문서를 직접 고쳤다**

완료된 항목의 전체 이력은 [`progress-log.md`](progress-log.md) 에 있다.
