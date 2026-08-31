#!/usr/bin/env bash
set -euo pipefail

root="${ROOT:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes/notes/results/multibeam_seed_determinism_validation_2026-08-31}"
base="${BASE_IMAGE:-dave-sonar-equivalence-exact-dft-v2:20260830}"
image="${FIXED_FRAME_IMAGE:-dave-sonar-fixed-frame-exact-dft:20260831}"
name="sonar-fixed-frame-build-$$"
mkdir -p "$root/build"
cleanup(){ docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$base" infinity \
  >"$root/build/container_id.txt"
docker exec "$name" bash -lc '
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
src=/home/docker/dave_ws/src/dave/gazebo/dave_gz_multibeam_sonar/multibeam_sonar/MultibeamSonarSensor.cc
cp "$src" /tmp/MultibeamSonarSensor.cc.before
python3 - <<"PY"
from pathlib import Path
p=Path("/home/docker/dave_ws/src/dave/gazebo/dave_gz_multibeam_sonar/multibeam_sonar/MultibeamSonarSensor.cc")
s=p.read_text()
old="input.frameIndex = this->frameCounter++;"
new="input.frameIndex = 0;  // validation-only fixed random frame"
assert s.count(old)==1, s.count(old)
p.write_text(s.replace(old,new))
PY
diff -u /tmp/MultibeamSonarSensor.cc.before "$src" >/tmp/fixed_frame.patch || true
cd /home/docker/dave_ws
colcon build --merge-install --packages-select multibeam_sonar \
  --cmake-clean-cache --cmake-args -DCMAKE_BUILD_TYPE=Release
grep -n "validation-only fixed random frame" "$src"
sha256sum install/lib/multibeam_sonar/libmultibeam_sonar.so
' >"$root/build/build.log" 2>&1
docker cp "$name:/tmp/fixed_frame.patch" "$root/build/fixed_frame.patch" >/dev/null
docker commit "$name" "$image" >"$root/build/image_id.txt"
docker image inspect "$image" --format 'Id={{.Id}} Parent={{.Parent}} Size={{.Size}}' \
  >"$root/build/image_inspect.txt"
cat "$root/build/image_inspect.txt"
