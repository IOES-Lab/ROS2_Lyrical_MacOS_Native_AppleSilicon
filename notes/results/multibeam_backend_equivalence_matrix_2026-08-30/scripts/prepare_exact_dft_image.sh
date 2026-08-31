#!/usr/bin/env bash
set -euo pipefail
repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
root="$repo/notes/results/multibeam_backend_equivalence_matrix_2026-08-30"
base="${MATRIX_IMAGE:-dave-sonar-equivalence-matrix:20260830}"
out_image="${EXACT_DFT_IMAGE:-dave-sonar-equivalence-exact-dft:20260830}"
name="sonar-exact-dft-build-$$"
cleanup(){ docker stop "$name" >/dev/null 2>&1||true; docker rm "$name" >/dev/null 2>&1||true; }
trap cleanup EXIT INT TERM
docker run -d --name "$name" --entrypoint sleep "$base" infinity >"$root/test_assets/exact_dft_build_container_id.txt"
docker cp "$repo/patches/multibeam_wgpu_and_backend_fix.diff" "$name:/tmp/exact_dft.diff"
docker exec "$name" bash -lc '
set -eo pipefail
cd /home/docker/dave_ws/src/dave
git apply --check /tmp/exact_dft.diff
git apply /tmp/exact_dft.diff
grep -n "Exact DFT for non-power-of-two" gazebo/dave_gz_multibeam_sonar/wgpu_vendor/sonar_wgpu_rust/src/shaders/fft.wgsl
source /opt/ros/lyrical/setup.bash
source /home/docker/dave_ws/install/setup.bash
cd /home/docker/dave_ws
colcon build --merge-install --packages-select multibeam_sonar --cmake-args -DCMAKE_BUILD_TYPE=Release
cargo test --manifest-path src/dave/gazebo/dave_gz_multibeam_sonar/wgpu_vendor/sonar_wgpu_rust/Cargo.toml --release
' >"$root/test_assets/exact_dft_image_build.log" 2>&1
docker commit "$name" "$out_image" >"$root/test_assets/exact_dft_image_id.txt"
docker image inspect "$out_image" --format 'Id={{.Id}} Parent={{.Parent}} Size={{.Size}}' >"$root/test_assets/exact_dft_image_inspect.txt"
cat "$root/test_assets/exact_dft_image_inspect.txt"
