#!/usr/bin/env bash
set -euo pipefail
repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="$repo/notes/results/multibeam_backend_equivalence_matrix_2026-08-30"
base="${EXACT_DFT_SOURCE_IMAGE:-dave-sonar-equivalence-exact-dft:20260830}"
out_image="${EXACT_DFT_LINKED_IMAGE:-dave-sonar-equivalence-exact-dft-v2:20260830}"
name="sonar-exact-dft-linked-build-$$"
cleanup(){ docker stop "$name" >/dev/null 2>&1||true; docker rm "$name" >/dev/null 2>&1||true; }
trap cleanup EXIT INT TERM
docker run -d --name "$name" --entrypoint sleep "$base" infinity >"$root/test_assets/exact_dft_v2_build_container_id.txt"
docker exec "$name" bash -lc '
set -eo pipefail
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
cd /home/docker/dave_ws
colcon build --merge-install --packages-select wgpu_vendor --cmake-clean-cache --cmake-args -DCMAKE_BUILD_TYPE=Release
source install/setup.bash
colcon build --merge-install --packages-select multibeam_sonar --cmake-clean-cache --cmake-args -DCMAKE_BUILD_TYPE=Release
sha256sum install/lib/libsonar_wgpu.a install/lib/multibeam_sonar/libmultibeam_sonar.so
' >"$root/test_assets/exact_dft_v2_image_build.log" 2>&1
docker commit "$name" "$out_image" >"$root/test_assets/exact_dft_v2_image_id.txt"
docker image inspect "$out_image" --format 'Id={{.Id}} Parent={{.Parent}} Size={{.Size}}' >"$root/test_assets/exact_dft_v2_image_inspect.txt"
cat "$root/test_assets/exact_dft_v2_image_inspect.txt"
