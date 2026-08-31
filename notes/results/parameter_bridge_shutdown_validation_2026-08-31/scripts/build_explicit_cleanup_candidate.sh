#!/usr/bin/env bash
set -euo pipefail

repo="${REPO:-/Users/gwon-yeseol/ROS2_Lyrical_review_fixes}"
source_repo="${ROS_GZ_SOURCE:-/Users/gwon-yeseol/Documents/Codex/2026-07-15/dave-ros-2-lyrical-validation/work/ros_gz_3.0.9}"
root="$repo/notes/results/parameter_bridge_shutdown_validation_2026-08-31/explicit_cleanup_candidate"
base="${BASE_IMAGE:-dave-sonar-deferred-compute-test:20260830}"
image="${CANDIDATE_IMAGE:-dave-bridge-explicit-cleanup:20260831}"
name="bridge-cleanup-build-$$"
mkdir -p "$root/build"
cleanup(){ docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

git -C "$source_repo" rev-parse HEAD >"$root/build/source_commit.txt"
git -C "$source_repo" describe --tags --exact-match >"$root/build/source_tag.txt"
docker run -d --name "$name" --entrypoint sleep "$base" infinity >"$root/build/container_id.txt"

docker exec "$name" mkdir -p \
  /home/docker/bridge_candidate_ws/src/parameter_bridge_cleanup_candidate/src
docker cp "$source_repo/ros_gz_bridge/src/parameter_bridge.cpp" \
  "$name:/home/docker/bridge_candidate_ws/src/parameter_bridge_cleanup_candidate/src/parameter_bridge.cpp"

docker exec "$name" bash -lc '
set -eo pipefail
pkg=/home/docker/bridge_candidate_ws/src/parameter_bridge_cleanup_candidate
p="$pkg/src/parameter_bridge.cpp"
cp "$p" /tmp/parameter_bridge.cpp.before
python3 - <<"PY"
from pathlib import Path
p=Path("/home/docker/bridge_candidate_ws/src/parameter_bridge_cleanup_candidate/src/parameter_bridge.cpp")
s=p.read_text()
# This private source-tree header is redundant for the executable and is not
# exported by the binary package used for this focused rebuild.
s=s.replace("\n#include \"bridge_handle.hpp\"\n", "\n")
old="""  rclcpp::spin(bridge_node);\n\n  return 0;"""
new="""  rclcpp::spin(bridge_node);\n\n  // Validation candidate: destroy bridge handles and their DDS entities before\n  // process-wide shared-library finalizers run.\n  bridge_node.reset();\n  rclcpp::shutdown();\n\n  return 0;"""
assert s.count(old)==1, s.count(old)
p.write_text(s.replace(old,new))
PY
diff -u /tmp/parameter_bridge.cpp.before "$p" >/tmp/explicit_cleanup.patch || true
cat >"$pkg/CMakeLists.txt" <<"EOF"
cmake_minimum_required(VERSION 3.16)
project(parameter_bridge_cleanup_candidate)
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(ros_gz_bridge REQUIRED)
add_executable(parameter_bridge src/parameter_bridge.cpp)
target_link_libraries(parameter_bridge ros_gz_bridge::ros_gz_bridge rclcpp::rclcpp)
install(TARGETS parameter_bridge DESTINATION lib/${PROJECT_NAME})
ament_package()
EOF
cat >"$pkg/package.xml" <<"EOF"
<?xml version="1.0"?>
<package format="3">
  <name>parameter_bridge_cleanup_candidate</name>
  <version>0.0.0</version>
  <description>Focused validation rebuild of ros_gz_bridge parameter_bridge.</description>
  <maintainer email="validation@example.invalid">validation</maintainer>
  <license>Apache-2.0</license>
  <buildtool_depend>ament_cmake</buildtool_depend>
  <depend>rclcpp</depend>
  <depend>ros_gz_bridge</depend>
</package>
EOF
source /opt/ros/lyrical/setup.bash
cd /home/docker/bridge_candidate_ws
colcon build --packages-select parameter_bridge_cleanup_candidate \
  --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=OFF
candidate=/home/docker/bridge_candidate_ws/install/parameter_bridge_cleanup_candidate/lib/parameter_bridge_cleanup_candidate/parameter_bridge
installed=/opt/ros/lyrical/lib/ros_gz_bridge/parameter_bridge
sha256sum "$installed" > /tmp/original_binary_sha256.txt
sha256sum "$candidate" > /tmp/candidate_binary_sha256.txt
cp "$installed" /opt/ros/lyrical/lib/ros_gz_bridge/parameter_bridge.apt-original
cp "$candidate" "$installed"
sha256sum "$installed" > /tmp/installed_candidate_sha256.txt
' >"$root/build/candidate_build.log" 2>&1

docker cp "$name:/tmp/explicit_cleanup.patch" "$root/build/explicit_cleanup.patch" >/dev/null
docker cp "$name:/tmp/original_binary_sha256.txt" "$root/build/original_binary_sha256.txt" >/dev/null
docker cp "$name:/tmp/candidate_binary_sha256.txt" "$root/build/candidate_binary_sha256.txt" >/dev/null
docker cp "$name:/tmp/installed_candidate_sha256.txt" "$root/build/installed_candidate_sha256.txt" >/dev/null
docker commit "$name" "$image" >"$root/build/image_id.txt"
docker image inspect "$image" --format 'Id={{.Id}} Parent={{.Parent}} Size={{.Size}}' \
  >"$root/build/image_inspect.txt"
cat "$root/build/image_inspect.txt"
