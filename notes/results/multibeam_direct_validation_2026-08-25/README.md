# Multibeam sonar direct validation — 2026-08-25

ROS 2 Lyrical + Gazebo Jetty에서 DAVE Multibeam Sonar 문서의 미검증 항목을
직접 실행한 기록이다. 사용한 DAVE checkout은 commit `6aef91c` 기반의 기존
migration 수정이 남아 있는 작업 트리였으며 pristine 상태가 아니었다. 사용자 정의
센서와 world는 DAVE checkout에 추가하지 않고 별도 overlay에서 만들었다.

## 최종 판정

| 검증 항목 | 판정 | 직접 확인한 내용 |
|---|---|---|
| Demo wrapper | PASS (출력 범위) | Apple M2 Metal WGPU, PointCloud2 513×301, image 513×399, raw sonar 513 beams × 399 ranges |
| 원본 `dave_sensor.launch.py` 명령 | PASS (출력 범위) | PointCloud2·image·raw sonar 구조 직접 확인 |
| 기본 RViz launch | PARTIAL | 프로세스와 구독은 존재했지만 macOS에서 `visible=true, windows=0`; 실제 창 미생성 |
| 사용자 정의 sonar/world | PASS | `codex_p900`, PointCloud2 65×61, image/raw sonar 65×319 |
| BlueROV2 예제 | FAIL (소나 예제로서) | 차량은 spawn됐지만 해당 모델에 multibeam sensor가 없고 sonar topic/plugin 증거도 없음 |
| Local Search | PASS (출력 범위) | Metal WGPU와 513×301 / 513×399 출력 직접 확인 |
| Docker RDP GUI | PASS (강제 CPU backend) | xrdp에서 Gazebo GUI와 raw sonar 513×399 직접 확인 |
| Mac/Docker 강제 CPU 비교 | 기능 PASS, 성능 비교는 제한적 | 동일 commit·Release·513×301×399. Mac 약 2.71 Hz, Docker 약 0.398 Hz로 Docker가 약 6.8배 낮음 |
| 평면 표적 CPU | PASS (단일 형상) | 기대 3.99 m, 5/5 프레임 peak 3.988294 m, 오차 −0.001706 m |
| 평면 표적 WGPU | FAIL (수치 동등성/거리 위치) | PointCloud는 3.990244 m지만 raw peak는 5/5 모두 6.396–6.446 m; 기대 bin rank 1 실패 |
| Apple M2 명시적 CUDA | CUDA 부재 확인, 실패 처리 FAIL | NVCC/toolkit 없음, raw topic 미생성, Gazebo 종료 및 launch/bridge 잔류 |
| `debug:=true` + `verbosity_level:=4` | FAIL | Gazebo 인자가 `-r-v 4`로 붙어 exit 109; 소나 backend 판정에 사용하지 않음 |

## 직접 확인된 결론

- PR #44 WGPU는 Apple M2 Metal에서 빌드·실행되고 구조화된 출력을 발행한다.
- CPU backend는 단일 평면 표적을 한 range bin 이내로 위치시켰다.
- 동일 장면에서 WGPU와 CPU의 raw-sonar range profile은 수치적으로 동등하지 않았다.
- 두 backend에서 측정한 PointCloud 중심 거리는 동일했다. 반면 raw-sonar
  결과는 달랐으므로 관찰된 불일치는 sonar-compute 출력에 나타난다.
  전체 PointCloud의 byte-level 동등성은 확인하지 않았다.
- Docker는 기존 xrdp 화면과 강제 CPU backend를 이용해 GUI와 raw sonar를 직접 확인했다.

## 확인하지 못한 범위

- 일반적인 음향 정확도, 재질 반사, 잡음 현실성, multipath
- WGPU 거리 불일치의 정확한 근본 원인
- NVIDIA GPU에서의 CUDA 기능
- macOS RViz 창의 실제 렌더링
- 순수 CPU kernel만의 Mac/Docker 비교
- 결과 폴더에는 test assets와 분석 스크립트를 보존했지만, overlay 재구성부터
  실행까지를 자동화한 one-command 재현 스크립트는 아직 없다.

## 회차 구분

- `07_cpu_backend_cross_platform/mac_release_cpu/launch.log`:
  `-r-v 4`가 생성되어 종료된 실패 회차이며 성능 근거로 사용하지 않는다.
- `07_cpu_backend_cross_platform/mac_release_cpu_attempt_02/`:
  Mac 강제 CPU 비교의 최종 유효 회차(약 2.716 Hz).
- `07_cpu_backend_cross_platform/docker_release_cpu_attempt_02/`:
  Docker 강제 CPU 비교의 최종 유효 회차(약 0.398 Hz).
- `07_cpu_backend_cross_platform/docker_rdp_gui/`:
  xrdp GUI와 raw-sonar 출력을 확인한 별도 회차이며 성능 비교 회차가 아니다.

## 증거 위치

- `01_demo_wrapper/`: 직접 출력 구조
- `03_rviz_default/rviz_window_state.txt`: `windows=0`
- `04_custom_sonar_world/test_assets/`: 직접 만든 model/config/world
- `05_bluerov2_original/`: sonar topic·plugin 부재
- `07_cpu_backend_cross_platform/`: Mac/Docker 강제 CPU 및 RDP 실행
- `08_planar_range_validation/`: CPU/WGPU JSON·CSV와 5프레임 반복
- `09_cuda_backend_availability/`: CUDA 환경·실패 로그·미생성 topic

`overlay_ws/build`, `install`, `log` 및 복제된 대용량 mesh는 실험 증거가 아닌
재생성 가능한 부산물이므로 커밋 대상에서 제외했다.
