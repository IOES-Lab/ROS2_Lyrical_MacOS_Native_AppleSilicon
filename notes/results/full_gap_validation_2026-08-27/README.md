# Full remaining-gap validation — 2026-08-27/28

## Scope

This batch re-opened every outstanding runtime item in the repository and Notion audit.
Items executable on the attached Mac or Docker environment were run directly. Items requiring
unavailable hardware, Windows/WSL, NVIDIA CUDA, MAVROS/QGroundControl integration or an external
Fuel account are recorded as **BLOCKED**, not as passes.

## Direct results

| Area | Direct result |
|---|---|
| Spherical Coordinates | Independent WGS-84/ECEF/ENU oracle, 13 points across Busan, southern hemisphere, dateline and near-pole cases. Max error: 6.64e-12° latitude, 3.13e-13° longitude, 5.16e-07 m altitude, 1.8e-07 m inverse ENU axis. |
| DVL descriptors | All 8 shipped descriptors run on Docker: 4 publish four-beam messages; 4 fail sensor initialization because water-mass far boundary 100 m exceeds their maximum range (75/81/66/90 m). All 4 published DAVE messages retain empty `frame_id`. |
| Underwater Camera | 12-condition Docker matrix. Each `attenuationR/G/B` and `backgroundR/G/B` tag affects the same raw BGR array index; R therefore acts on Blue and B on Red. At 1/2/4/6 m, centre BGR decreases `[45,64,89]` → `[37,52,73]` → `[24,35,49]` → `[16,23,32]`. Fresh Mac controls on 2026-08-27 emitted no image topic, so they do not replace the successful 2026-08-26 Mac artifacts. |
| SeaPressure | No frames during 5 wall seconds paused; 10,000 monotonic 1 kHz frames across 9.999 simulated seconds at the surface; ±1000 m both produce 9907.705 under the implemented `abs(z)` formula. This is stability of the flawed implementation, not ROS-unit correctness. |
| Glider deadband | Integrated ROS→Gazebo path passes when published repeatedly: 50 ROS `true` messages, 50 Gazebo `true` observations, 0 false. The previous one-shot timeout was a timing/observation artifact and is withdrawn. |
| USBL | Moving transponder output changes from median x 2.999954 m to 8.999973 m. Travel delay is quantized: median 0.002803 s at 1539 m but 1.010797 s at 1541 m with sound speed 1540 m/s, matching integer-second `sleep()` truncation rather than continuous propagation time. |
| Ocean Current ModelPlugin | In one simultaneous fixed-depth Docker control, the 5 m REXROV receives 0 m/s and stays at Δx 0; the 15 m REXROV starts at 0.750000 m/s and moves Δx 2.400436 m over 6 s. Unique namespaces prove the two-vehicle path in this scope. |
| Plugin discovery | The nested Gazebo paths originate in DAVE `.dsv` hooks. Ocean/Spherical libraries install one level higher (`<prefix>/lib`), so the generated Mac path misses them; adding the actual directory makes them load. This supersedes the earlier “origin unknown” wording. |

## New or refined defects

1. Four of eight shipped DVL descriptors cannot initialize because `water_mass` far boundary is
   hard-coded to 100 m although their maximum ranges are below 100 m.
2. USBL propagation delay uses integer-second `sleep()`: sub-second delays truncate to zero and
   the response jumps by roughly one second across the 1540 m boundary.
3. The Glider integrated deadband path is not asymmetric under repeated publication; the prior
   one-shot result is withdrawn.
4. The DAVE environment hooks are the confirmed source of the Ocean/Spherical Mac plugin-path
   mismatch.

## Evidence map

- [`00_environment_boundaries/`](00_environment_boundaries/)
- [`01_plugin_path_origin/`](01_plugin_path_origin/)
- [`02_spherical_independent_geodesy/`](02_spherical_independent_geodesy/)
- [`03_dvl_all_models_docker/`](03_dvl_all_models_docker/)
- [`04_underwater_tag_and_range_matrix/`](04_underwater_tag_and_range_matrix/)
- [`05_seapressure_extreme_pause_long/`](05_seapressure_extreme_pause_long/)
- [`06_glider_deadband_integrated/`](06_glider_deadband_integrated/)
- [`07_usbl_motion_latency/`](07_usbl_motion_latency/)
- [`08_ocean_depth_force/`](08_ocean_depth_force/)
- [`summary.json`](summary.json)

## Explicit limits

- General acoustic, optical, geodetic, hydrodynamic or real-ocean accuracy is not established.
- Long-duration endurance beyond the recorded windows, USBL multi-transceiver isolation, Ocean
  tidal/noise evolution, and hardware-in-the-loop behavior remain separate research tasks.
- Blocked environment items are evidence of missing prerequisites only; they are not product
  failures and are not silently promoted to PASS.
