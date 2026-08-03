# Docker에서 기동 곡선 재측정하기

목적 하나입니다. **Docker의 RTF ~0.0018이 진짜인지, 아니면 맥과 똑같이 기동 구간을 잰 것인지** 판별합니다.

2026-08-03에 맥에서 확인된 것: launch 후 약 80초간 `/stats`가 거의 안 나오고, 소나는 145~175초가 지나야 올라옵니다. 그 전에 측정하면 정지처럼 보입니다. Docker의 0.0018은 이 보정 없이 나온 수치라 같은 함정에 빠졌을 수 있습니다.

**맥과 완전히 같은 스크립트를 씁니다.** 방법이 다르면 두 수치를 비교할 수 없습니다.

---

## 1. 컨테이너 준비

```bash
docker ps -a | grep lyrical
```

살아있는 컨테이너가 없으면 새로 띄웁니다.

```bash
docker run -d --name lyrical-phase \
  --shm-size=2g \
  lyrical-sim:jetty-rdp-pr1-ca-fix sleep infinity
```

`--shm-size`는 기본 64MB로는 Gazebo가 공유 메모리에서 막히는 일이 있어 올려둡니다.

## 2. 스크립트 복사

```bash
docker cp ~/ROS2_Lyrical_review_fixes/notes/experiments \
          lyrical-phase:/home/docker/experiments
```

## 3. 컨테이너 안에서 실행

```bash
docker exec -it lyrical-phase bash
```

아래부터는 컨테이너 안입니다.

```bash
source /opt/ros/lyrical/setup.bash
source ~/dave_ws/install/setup.bash     # 워크스페이스 경로는 아래 확인 참고
cd /home/docker/experiments
```

**돌리기 전에 확인 두 개.** 이걸 건너뛰면 실패 원인을 못 가립니다.

```bash
which ros2 timeout gz          # 셋 다 경로가 나와야 함
ls ~/dave_ws/src/dave 2>/dev/null || ls /root/dave_ws/src/dave
```

`timeout`은 리눅스에 기본으로 있으니 맥과 달리 `coreutils` 설치가 필요 없습니다.

이제 실행합니다. **Docker는 맥보다 훨씬 느리므로 관측 시간을 늘립니다.**

```bash
TAG=docker TOTAL=1200 SLICE=30 bash exp6_phase.sh
```

20분 걸립니다. 소나가 그 안에 안 올라오면 `TOTAL=2400`으로 다시 돌립니다.

---

## 무엇을 볼 것인가

`stats` 토픽명은 **자동 탐색**됩니다. 맥에서는 `/world/default/stats`, Docker에서는 2026-07-29에 `/world/oceans_waves/stats`로 관측된 적이 있어 하드코딩하지 않았습니다. 시작할 때 `[topic]` 줄에 실제로 찾은 이름이 찍히니 그걸 기록해 주세요.

결과는 셋 중 하나입니다.

**(A) 앞구간만 낮고 뒤가 평탄** — 맥과 같은 패턴입니다. Docker의 0.0018도 기동 구간을 잰 것이고, 정상 상태 수치는 따로 있습니다. Mac/Docker 격차 123배가 대폭 줄어듭니다.

**(B) 소나가 올라온 뒤에도 계속 0.00x대** — Docker는 진짜로 느립니다. 기동 문제가 아니라 정상 상태 자체의 문제이고, `llvmpipe` 소프트웨어 래스터라이저 가설이 힘을 얻습니다. 다만 그것만으로는 아직 확정이 아닙니다.

**(C) `iterations`가 안 늘어남** — 진짜 정지입니다. `rtf_probe.sh`가 그 자리에서 경고를 찍습니다. 이 경우에만 2026-07-23의 "deadlock 의심"이 살아납니다.

어느 쪽이 나오든 결론이 납니다. **(B)가 나와도 llvmpipe가 원인이라고 바로 적지는 마세요.** 그건 다음 실험(같은 컨테이너에서 소나를 뗀 대조군)이 필요합니다.

## 결과 꺼내오기

```bash
exit                                     # 컨테이너 밖으로
docker cp lyrical-phase:/tmp/. /tmp/exp6_docker/
ls /tmp/exp6_docker/exp6_phase_docker_*.csv
```

CSV와 화면 출력을 같이 보내주시면 정리하겠습니다.

## 정리

```bash
docker rm -f lyrical-phase
```

---

## 알려진 주의점

- **소나 로그 문구**가 Docker에서 다를 수 있습니다. 스크립트는 `Persistent GPU buffers allocated for 513`을 찾습니다. 곡선 내내 `소나 아직`으로만 찍히는데 RTF는 정상 범위라면, 문구가 다른 것이지 소나가 안 뜬 게 아닐 수 있습니다. 그때는 `/tmp/exp6_phase.log`에서 `grep -i 'beam\|buffer\|sonar'`로 실제 문구를 확인해 주세요.
- **컨테이너 안에서 다른 gz-sim이 돌고 있으면** 수치가 오염됩니다. 스크립트가 시작할 때 정리하고, 그래도 남아있으면 중단합니다. 2026-07-29에 실제로 이것 때문에 엉뚱한 프로세스를 붙잡은 적이 있습니다.
- 이 측정은 **RTF만** 봅니다. 정확도 벤치마크가 아닙니다.
