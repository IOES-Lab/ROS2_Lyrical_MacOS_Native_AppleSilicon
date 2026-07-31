# PARTIAL 2건 원인 규명 실험

대상
- `dave_multibeam_sonar` — RTF ~0.0018 (2026-07-29, Docker)
- `dave_ocean_waves_sonar_integrated` — RTF ~0.1–0.4, CPU 32%→47%→69% 상승 미설명

## 관찰된 사실

두 월드가 **같은 센서(blueview_p900), 같은 step size(0.001)** 를 쓰는데 RTF가 50~200배 차이난다.

| | multibeam_sonar | ocean_waves_sonar_integrated |
|---|---|---|
| include | 5 (cylinder target ×2) | 14 (Vase ×3, Lionfish, Coral, Kelp ×2, **Sand Heightmap**) |
| 하이트맵 | 없음 | 있음 |
| RTF | ~0.0018 | ~0.1–0.4 |

**더 단순한 장면이 더 느리다.** 이게 단서다.

## 가설

blueview_p900은 사거리 10m에 512×300 = 153,600 rays/frame.
빈 장면에서는 레이 대부분이 아무것도 못 맞고 10m를 끝까지 traverse한다.
integrated는 바로 아래 하이트맵이 있어 레이가 일찍 종료된다.

→ 비용이 hit이 아니라 **miss(빈 공간 traverse)** 에 있다는 가설.
   2026-07-29 노트의 `Render()` 의심과 방향이 같다.

## 실행 순서

```bash
./exp2_baseline.sh    # 먼저. 소나 없는 기준 RTF 확보
./exp1_range.sh       # 사거리 10 → 3 → 1
./exp3_heightmap.sh   # 빈 장면에 바닥 추가
./exp4_integrated_isolated.sh   # integrated CPU 상승 격리 재측정
```

경로가 다르면 환경변수로 지정한다.

```bash
SDF=/path/to/blueview_p900/model.sdf ./exp1_range.sh
W=/path/to/dave_multibeam_sonar.world ./exp3_heightmap.sh
MIN=20 ./exp4_integrated_isolated.sh
```

## 주의

- 모든 스크립트가 원본을 `.bak`으로 백업하고 종료 시 되돌린다.
- `--symlink-install` 체크아웃이면 SDF·world 수정은 재빌드 없이 즉시 반영된다.
- stats 토픽명은 월드의 내부 `<world name>` 기준이다.
  - `dave_multibeam_sonar.world` → `<world name="default">` → `/world/default/stats`
  - `dave_ocean_waves_sonar_integrated.world` → `/world/oceans_waves_sonar_integrated/stats`
