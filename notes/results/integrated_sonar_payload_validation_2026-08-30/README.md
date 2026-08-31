# Integrated ocean-waves sonar payload — 2026-08-30

The historical `dave_ocean_waves_sonar_integrated.world` row had only process / world-stats
evidence.  This run directly captured its sensor payload in a fresh Docker container using the
isolated deferred-backend plus correctly relinked exact-N WGPU candidate.

## Result

- WGPU selected software Vulkan `llvmpipe`.
- The backend allocated the full 513×301×399 workload.
- PointCloud2 **513×301: 3/3** captures.
- raw sonar **513 beams × 399 ranges: 3/3** captures.
- `/world/oceans_waves_sonar_integrated/stats` was read at iteration 77,902 with the sampled
  message reporting RTF `0.02268`.
- The retained end snapshot was `696.01%` container CPU, `1.639 GiB` memory and 134 PIDs; the
  Gazebo process snapshot was `393%` CPU and 1,734,652 KiB RSS.  These are one end snapshots, not
  steady-state means.
- no runtime stack trace or exit 139 occurred.

This upgrades the world to a **FUNCTIONAL PASS in the isolated candidate/output scope**.  It does
not say that the unchanged distributed installation uses this code, and it does not establish
raw-sonar accuracy in this complex scene.  Numerical localisation was tested separately in the
controlled-scene matrix.

The exact-N software-WGPU path incurred an 88.756 s first 1×1×4 probe in this fresh container and
later full-frame logs around 534–547 ms.  The bounded harness then terminated the launch, yielding
rc 143; that is not a runtime sensor failure.

The initial harness attempted an unbounded Gazebo echo of a non-publishing raw sample topic and was
manually released after all required ROS captures had already completed.  The retained script now
places a 30 s bound on that optional diagnostic and clears inherited `/tmp` artifacts before launch.

## Evidence

- [`summary.json`](summary.json)
- [`docker_wgpu_exact_dft_v2/summary.json`](docker_wgpu_exact_dft_v2/summary.json)
- [`docker_wgpu_exact_dft_v2/point_1.txt`](docker_wgpu_exact_dft_v2/point_1.txt) through `point_3.txt`
- [`docker_wgpu_exact_dft_v2/raw_1.txt`](docker_wgpu_exact_dft_v2/raw_1.txt) through `raw_3.txt`
- [`docker_wgpu_exact_dft_v2/world_stats.txt`](docker_wgpu_exact_dft_v2/world_stats.txt)
- [`docker_wgpu_exact_dft_v2/launch.log`](docker_wgpu_exact_dft_v2/launch.log)
- [`scripts/run_integrated_sonar.sh`](scripts/run_integrated_sonar.sh)
