# Open-gap revalidation — 2026-08-29

This folder records the final locally executable gap sweep after the eight-candidate snapshot.
No upstream DAVE checkout or installed user workspace was modified. The only new source change is
an isolated ninth candidate patch, [`../../../patches/fifth_rov_sonar_world_fix.diff`](../../../patches/fifth_rov_sonar_world_fix.diff).

## Current findings

- **Candidate stack:** all 9 patches apply in dependency order. Rust boundary test 1/1, `cargo check`,
  19 Python compiles, 32 XML parses and 17 `gz sdf -k` checks pass; reconstructed files equal the
  isolated candidate snapshot (`246/246` tracked and `5/5` added).
- **Mac stock DVL:** the official `ros_gz_sim_demos dvl.launch.py` still exits `-11` in Gazebo
  Sensors `RenderThread` / `WaitForInit`. This is outside DAVE-local descriptor fixes.
- **Mac Underwater Camera Quickstart:** three isolated fresh launches all published a 320×240 BGR8
  image after 54, 58 and 72 seconds. The 2026-08-27 topic-absence observation was not reproduced;
  its trigger remains unknown rather than fixed.
- **Mac RViz:** the process and ROS node remain alive, but macOS reports `visible=true, windows=0`
  after 30 seconds. The window defect remains reproduced.
- **Fast DDS:** a bounded minimal model-create probe passed 5/5 with default SHM and 5/5 with
  `UDPv4`. This does not erase the historical 1/9 run; current intermittency did not reproduce.
- **Fifth ROV sonar:** `dave_ocean_waves.world` has no `MultibeamSonarSystem`, while the dedicated
  sonar world does. Adding that world system in an isolated candidate made the fifth variant publish
  a 513×301 PointCloud2 (5 fields, Apple-M2 WGPU) after 42 seconds. The prior “unexplained silent
  declared sonar” diagnosis is superseded by a world-composition omission.
- **Docker OGRE2:** a current isolated OGRE2 server run published a real sonar PointCloud. Explicit
  software WGPU initialization failed and correctly fell back to CPU. The historical DAVE sonar
  OGRE2 crash did not reproduce in this current scoped run; hardware WGPU was not tested.
- **Docker BlueROV2 integration:** sourcing the existing MAVROS overlay starts ArduSub and MAVROS;
  their TCP endpoint opens. Therefore “MAVROS absent from the image” was an environment error.
  The loop remains incomplete: `libArduPilotPlugin.so` is absent, ArduSub receives no JSON sensor
  messages, `/mavros/state` remains `connected: false`, and QGroundControl repeatedly SIGSEGVs.

## Evidence map

- `candidate_rebuild_checks.txt`
- `mac_stock_dvl_crash_excerpt.txt`
- `mac_camera_3runs.csv`, `mac_camera_image_structure.txt`
- `mac_rviz_window_state.txt`, `mac_rviz_process.txt`, `mac_rviz_node_list.txt`
- `mac_fastdds_5x5.csv`
- `world_system_comparison.txt`, `fifth_sonar_result.txt`, `fifth_sonar_pointcloud.txt`,
  `fifth_sonar_backend_excerpt.txt`
- `docker_ogre2_result.txt`, `docker_ogre2_pointcloud.txt`, `docker_ogre2_backend_lines.txt`
- `docker_bluerov2_environment.txt`, `docker_bluerov2_summary.txt`,
  `docker_bluerov2_mavros_state.txt`, `docker_bluerov2_key_lines.txt`
- `summary.json`

These observations establish the stated runtime and configuration behavior only. They do not
establish broad acoustic, hydrodynamic, optical, control-system or hardware-platform accuracy.
