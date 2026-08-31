#!/usr/bin/env bash
set -euo pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="$repo/notes/results/multibeam_backend_equivalence_matrix_2026-08-30"
base_image="${BASE_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
matrix_image="${MATRIX_IMAGE:-dave-sonar-equivalence-matrix:20260830}"
name="sonar-matrix-build-$$"

cleanup() {
  docker stop "$name" >/dev/null 2>&1 || true
  docker rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

docker run -d --name "$name" --entrypoint sleep "$base_image" infinity \
  > "$root/test_assets/build_container_id.txt"

for world in "$root"/test_assets/worlds/*.world; do
  docker cp "$world" \
    "$name:/home/docker/dave_ws/src/dave/models/dave_worlds/worlds/$(basename "$world")"
done
docker exec "$name" mkdir -p /home/docker/sonar_equivalence
docker cp "$root/scripts/capture_sonar_arrays.py" \
  "$name:/home/docker/sonar_equivalence/capture_sonar_arrays.py"

docker exec "$name" bash -lc '
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
cd /home/docker/dave_ws
colcon build --merge-install --packages-select dave_worlds \
  --cmake-args -DCMAKE_BUILD_TYPE=Release
for f in /home/docker/dave_ws/install/share/dave_worlds/worlds/*.world; do
  case "$f" in
    *plane_2m_dark.world|*plane_4m_dark.world|*plane_4m_bright.world|*plane_7m_dark.world|*sphere_4m_bright.world|*cylinder_4m_bright.world)
      echo "INSTALLED $f" ;;
  esac
done
python3 -m py_compile /home/docker/sonar_equivalence/capture_sonar_arrays.py
' > "$root/test_assets/matrix_image_build.log" 2>&1

docker commit "$name" "$matrix_image" > "$root/test_assets/matrix_image_id.txt"
docker image inspect "$matrix_image" \
  --format 'Id={{.Id}} Parent={{.Parent}} Size={{.Size}}' \
  > "$root/test_assets/matrix_image_inspect.txt"
cat "$root/test_assets/matrix_image_inspect.txt"
