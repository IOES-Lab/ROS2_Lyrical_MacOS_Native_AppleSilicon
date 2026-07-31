# 맥에서 돌리는 법

터미널에 그대로 붙여넣으세요.

```bash
cd ~/ROS2_Lyrical_review_fixes/notes/experiments
source ~/dave_ws_lyrical/install/setup.zsh

export SDF=~/dave_ws_lyrical/src/dave/models/dave_sensor_models/description/blueview_p900/model.sdf
export W=~/dave_ws_lyrical/src/dave/models/dave_worlds/worlds/dave_multibeam_sonar.world

./exp2_baseline.sh
```

`exp2`가 끝나고 숫자 나오면 다음.

```bash
./exp1_range.sh
./exp3_heightmap.sh
```

`timeout` 이 없다고 나오면 먼저 이거 한 번.

```bash
brew install coreutils
```

# 컨테이너에서 돌리는 법

7/29 수치와 직접 비교하려면 Docker 쪽에서 돌려야 합니다.

```bash
docker cp ~/ROS2_Lyrical_review_fixes/notes/experiments lyrical-theme-test:/home/docker/experiments
docker exec -it lyrical-theme-test bash

cd /home/docker/experiments
source ~/dave_ws/install/setup.bash
./exp2_baseline.sh
```

컨테이너는 기본 경로(`$HOME/dave_ws/...`)를 쓰므로 `SDF`, `W` 를 따로 안 줘도 됩니다.
