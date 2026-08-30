# What was changed

Seventeen retained patches describe the tested ROS 2 Lyrical / Gazebo Jetty port and the defects
found while directly validating it. **They are not all independent and they are not applied
upstream.** The ten dated 2026-08-29 candidates were generated against the tested local
migration baseline: PR #44 commit `6aef91c` plus the existing migration/runtime fixes already
documented in this folder. Apply the base port first, then the new candidates.

## Base port and earlier fixes

| Patch | Scope | Status |
|---|---|---|
| [`dave_lyrical_jetty_migration_mac.diff`](dave_lyrical_jetty_migration_mac.diff) | DAVE Jetty/Lyrical migration | Required base port; original logic rebuilt on Mac/Docker |
| [`ros_gz_lyrical_jetty_mac.diff`](ros_gz_lyrical_jetty_mac.diff) | `ros_gz` macOS source build | Required on the tested Mac source workspace |
| [`dave_world_launch_headless_fix.diff`](dave_world_launch_headless_fix.diff) | Original world-launch headless support | Runtime-confirmed on the three manipulation worlds |
| [`vehicle_imu_topic_fix.diff`](vehicle_imu_topic_fix.diff) | Four vehicle IMU topic declarations | Runtime-confirmed |
| [`usbl_sigma_fix.diff`](usbl_sigma_fix.diff) | Historical world-level `sigma` workaround | Superseded by the plugin-level 2026-08-29 USBL candidate |
| [`new_dvl_uri_fix.diff`](new_dvl_uri_fix.diff) | Malformed Fuel URI | Runtime-confirmed |

## 2026-08-29 validated candidate patches

| Patch | Scope | Validation |
|---|---|---|
| [`multibeam_wgpu_and_backend_fix.diff`](multibeam_wgpu_and_backend_fix.diff) | Exact non-power-of-two WGPU DFT, explicit 4096-bin GPU boundary and unavailable-backend CPU fallback | Mac/Metal planar target, 4097-bin pre-GPU unit test and explicit-CUDA small raw-sonar control |
| [`underwater_camera_channel_fix.diff`](underwater_camera_channel_fix.diff) | Semantic RGB tags mapped to BGR storage | Mac and Docker discriminating arrays equal `[50,103,85]` |
| [`seapressure_contract_fix.diff`](seapressure_contract_fix.diff) | Pa/Pa², sign, saturation, noise, rate, frame/topic controls | Full Mac and Docker control summaries PASS |
| [`dvl_configuration_and_bridge_fix.diff`](dvl_configuration_and_bridge_fix.diff) | Frame ID, named water velocity, descriptor far boundaries | Docker 8/8 four-beam output plus actual water-mass target |
| [`spherical_validation_fix.diff`](spherical_validation_fix.diff) | Invalid-input rejection, explicit response status, safe no-config and paused callbacks | Mac/Docker configured and no-config controls; **service API change** |
| [`plugin_discovery_hooks_fix.diff`](plugin_discovery_hooks_fix.diff) | Installed plugin search paths for world/ROS/sonar packages | Clean sourced-overlay discovery checks on Mac/Docker |
| [`usbl_runtime_fix.diff`](usbl_runtime_fix.diff) | `sigma<=0`, paused callbacks and fractional propagation delay | Mac/Docker zero-noise, moving and 1539/1541 m controls |
| [`launch_object_world_build_fix.diff`](launch_object_world_build_fix.diff) | Server-only launch, debug args, object preflight, non-TTY logging, Release docs and unique world names | Scoped Mac/Docker launch regressions and 18/18 name audit |
| [`fifth_rov_sonar_world_fix.diff`](fifth_rov_sonar_world_fix.diff) | Add the custom multibeam system to the ocean world used by the fifth ROV example | Isolated Mac candidate publishes 513×301 PointCloud2 on Apple-M2 WGPU. A combined Docker derived-image run applies/rebuilds but fails after 60053 ms `llvmpipe` startup and a Gazebo stack trace, before JSON/MAVROS, PointCloud2 or control |
| [`bluerov2_ardusub_speedup_fix.diff`](bluerov2_ardusub_speedup_fix.diff) | Pass explicit valid `--speedup 1` in all three BlueROV ArduSub launch configurations | Applies on the exact nine-candidate snapshot; 3/3 Python files compile; the exact current Docker image completes JSON, MAVROS 4/4 and arm/control/disarm for baseline, Heavy and Heavy-multibeam without the reproduced logger FPE |

The first eight candidates are documented in
[`../notes/results/remaining_defect_fixes_2026-08-29/`](../notes/results/remaining_defect_fixes_2026-08-29/);
the ninth patch, hashes and nine-patch reconstruction are in
[`../notes/results/open_gap_revalidation_2026-08-29/`](../notes/results/open_gap_revalidation_2026-08-29/).
The tenth patch, its SHA-256 and its apply/compile/runtime controls are in
[`../notes/results/external_stack_validation_2026-08-29/`](../notes/results/external_stack_validation_2026-08-29/).
The first nine still reconstruct the exact isolated modified snapshot; the tenth passes
`git apply --check` on top of that snapshot and all three edited Python files compile. The WGPU crate also passes its Rust unit test and `cargo check`; its
source guides now describe the exact-DFT path, actual `n_freq` buffer dimensions and 4096-bin
boundary. Docker has no Cargo toolchain, so the modified WGPU implementation was built and run on
Mac/Metal; Docker sonar validation remains CPU fallback.


## 2026-08-30 isolated Gazebo candidate

| Patch | Scope | Validation |
|---|---|---|
| [`gz_sim_macos_dvl_force_render_init.diff`](gz_sim_macos_dvl_force_render_init.diff) | Initialize DVL `forceUpdate` rendering on the Apple main thread and prevent the parallel `PostUpdate` handoff from winning the race | Exact `gz-sim10_10.4.0`: stock control exit 139; predicate-only v1 rejected at 9/10; v2 official DVL 20/20, standard camera 3/3, no-render Sensors 3/3, ROS bridge four valid beams |

This patch targets upstream `gz-sim`, not DAVE. It was built and run in an isolated exact-tag tree
and was not installed into Homebrew or submitted upstream. Full provenance, the rejected candidate,
repeat summaries and the compatibility-harness limitation are in
[`../notes/results/dvl_macos_force_update_candidate_2026-08-30/`](../notes/results/dvl_macos_force_update_candidate_2026-08-30/).

## What remains outside these patches

- upstream review, merge and installed distribution of the validated Mac Gazebo Sensors DVL candidate
- historical 2026-08-03 DAVE multibeam `ogre2` crash trigger (not reproduced in the current 2026-08-29 scoped PointCloud run)
- NVIDIA CUDA / Docker hardware GPU, Windows/WSL and physical HIL
- default RViz Mac window creation; root cause/fix for the directly reproduced combined Heavy-multibeam sonar-candidate + control Docker failure
- QGroundControl's retained DailyBuild default AppRun crash without `QGC_NO_SYSTEM_GLIB=1`
- a fresh `--no-cache` rebuild and exact-image rendered RDP/QGC vehicle-connection replay of the current Dockerfile recipe (cache-assisted full build, headless controls, xrdp service and QGC offscreen smoke pass)
- Fuel immutable content pin/account upload
- general acoustic, optical, hydrodynamic and long-duration scientific accuracy
- upstream submission, repository naming, licensing and research-direction decisions

See [`../notes/next-steps.md`](../notes/next-steps.md). A scoped runtime fix is not evidence for
general physical correctness, and a local candidate is not an upstream fix.
