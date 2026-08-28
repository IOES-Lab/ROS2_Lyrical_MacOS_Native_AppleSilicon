# ROS 2 Lyrical / Gazebo Jetty — DAVE migration verification

Can [DAVE](https://github.com/IOES-Lab/dave) and its CUDA-free WGPU multibeam sonar
([PR #44](https://github.com/IOES-Lab/dave/pull/44)) run on ROS 2 Lyrical + Gazebo Jetty?
DAVE is documented for Jazzy + Harmonic. Verified here on macOS (Apple Silicon, native) and
Docker (Ubuntu 26.04).

This is a verification record, not a distribution. It establishes scoped build, launch, topic
and service behavior. **General numerical and acoustic correctness is not established.**
A controlled planar test on 2026-08-25 found correct range localisation on the CPU backend but
a repeatable WGPU raw-sonar mismatch; SeaPressure also remains a known numerical exception.

## Results

| | |
|---|---|
| Worlds | 17/18 PASS-level, 1 PARTIAL **in the world-level matrix** — `dvl_world.world` is PARTIAL after direct cross-platform testing; vehicle/sensor-specific findings are tracked separately |
| Direct world-model audit | The 18 distributed files expose only 14 internal `<world name>` values: 7 files fall into 3 duplicate groups (`oceans_waves`, `default`, `dvl_world`). The Wiki Quickstart was rerun with advancing `/world/oceans_waves/stats` on Mac and Docker; this is liveness, not a performance benchmark — [evidence](notes/results/world_models_audit_2026-08-27/) |
| Direct sonar check | Mac WGPU publishes structured 513×301 PointCloud2 and 513×399 raw sonar, but in one controlled 3.99 m planar scene the CPU peak was 3.988 m while WGPU produced 6.396–6.446 m in 5/5 frames — [evidence](notes/results/multibeam_direct_validation_2026-08-25/) |
| Direct DVL check | Docker functional controls pass, but the all-descriptor matrix is **4/8 output, 4/8 initialization failure** because four shipped models hard-code a 100 m water-mass far boundary above their 66–90 m maximum ranges. Mac still crashes in Gazebo Sensors, DAVE's custom bridge drops `frame_id`, and shipped water-variable names remain invalid — [evidence](notes/results/full_gap_validation_2026-08-27/03_dvl_all_models_docker/) |
| Direct ROV-model check | In the patched Mac ocean world REXROV published 7/7 configured message types. The fifth `bluerov2_heavy_multibeam_sonar` variant is no longer source-only: it spawned on Mac and Docker but published only odometry among the four tracked outputs. Standalone keyboard and WebSocket Joy paths pass in Docker, while the exact integrated BlueROV2 launch remains incomplete because the current image lacks `mavros`/`mavros_msgs` — [evidence](notes/results/rov_direct_validation_2026-08-27/) |
| Direct Glider-model check | Docker RDP reran both Wiki launches and all 9 bridge topics. State/sensor 6/6 passes with the local IMU patch; `cmd_thrust` changes propeller velocity. A repeated integrated deadband control delivered **50/50 ROS `true` messages to Gazebo with 0 false**, withdrawing the earlier one-shot asymmetry claim. Calibration, Mac stepping and long dynamics remain open — [evidence](notes/results/full_gap_validation_2026-08-27/06_glider_deadband_integrated/) |
| Direct Object-model check | The only packaged descriptor, `mossy_cinder_block`, passed the exact Wiki launch on Mac and Docker. The generic Teledyne URL and a copied-source custom descriptor also spawned on both platforms. **PARTIAL:** missing descriptors still print false success, and `/1` is not an immutable Fuel pin because both clients warn that only the latest tip is supported — [evidence](notes/results/object_models_direct_validation_2026-08-27/) |
| Direct USBL check | Static common/individual routing and a moving-target update pass. Required workarounds remain for the old launcher, paused callback pumping and Docker `sigma=0`; additionally, propagation delay is integer-second quantized: median 0.002803 s at 1539 m and 1.010797 s at 1541 m for sound speed 1540 m/s — [evidence](notes/results/full_gap_validation_2026-08-27/07_usbl_motion_latency/) |
| Direct ocean-current check | All 12 global services pass in the tested scope. A separate fixed-depth two-vehicle Docker control closed the per-vehicle depth-force gap: the 5 m vehicle received 0 m/s and stayed at Δx 0, while the 15 m vehicle started at 0.750000 m/s and moved Δx 2.400436 m over 6 s — [evidence](notes/results/full_gap_validation_2026-08-27/08_ocean_depth_force/) |
| Direct underwater-camera check | The Wiki Quickstart and controlled transform pass in the retained Mac/Docker evidence. A 12-condition Docker extension changed all six tags individually and tested 1/2/4/6 m; every channel decreased with range. **R still acts on Blue and B on Red.** Fresh 2026-08-27 Mac controls emitted no image topic and are retained as a current recheck failure, not used to erase the 2026-08-26 Mac success — [evidence](notes/results/full_gap_validation_2026-08-27/04_underwater_tag_and_range_matrix/) |
| Direct SeaPressure check | The known contract defects remain. Added stress controls found no frames during 5 wall seconds paused, recorded 10,000 monotonic 1 kHz frames over 9.999 simulated seconds, and found the same 9907.705 at ±1000 m under the implemented `abs(z)` formula. This is stability of the flawed implementation, not numerical correctness — [evidence](notes/results/full_gap_validation_2026-08-27/05_seapressure_extreme_pause_long/) |
| Direct Spherical Coordinates check | The four services now pass an independent WGS-84/ECEF/ENU oracle at 13 points across Busan, the southern hemisphere, dateline and near-pole cases; maximum altitude error was 5.16e-7 m and inverse ENU-axis error 1.80e-7 m. Overall remains PARTIAL because invalid NaN/out-of-range inputs are accepted and the generated Mac plugin path misses the installed libraries — [evidence](notes/results/full_gap_validation_2026-08-27/02_spherical_independent_geodesy/) |
| Direct Model Plugin check | Interpolation and vehicle motion had already passed separately. A simultaneous fixed-depth Docker control now verifies depth-dependent application and two namespaces: 5 m → 0 m/s and Δx 0; 15 m → about 0.75 m/s and Δx 2.400436 m over 6 s. Coefficient and real-ocean accuracy remain outside this result — [evidence](notes/results/full_gap_validation_2026-08-27/08_ocean_depth_force/) |
| Sonar cost | RTF **0.5243** against a **0.9974** no-sonar control — 1.90x, not the 4.5x reported earlier |
| Largest win | `update_rate` 30 Hz → 2 Hz removes 75% of that cost, with no code change |
| Build trap | The documented build sets no `CMAKE_BUILD_TYPE`, so nothing gets an `-O` flag. `Release` doubled RTF on the sonar world (0.218 → 0.438, n=1) |

Measurement detail and how these numbers replaced the earlier ones:
[`notes/sonar-performance.md`](notes/sonar-performance.md).

## Build

```bash
extras/build-dave-lyrical-linux.sh     # Ubuntu 26.04 — complete build path; prints the validated launch command
extras/build-dave-lyrical-macos.sh     # macOS Apple Silicon — see the platform notes for one gap
```

Platform-specific caveats: [`extras/README.md`](extras/README.md).

Both refuse to finish if the sonar was compiled without an `-O` flag. That is not caution: this
workspace built unoptimised for a month, and the sonar figures taken in that time were about half
what they should have been. **The measured effect is one condition of one world** — RTF 0.218 →
0.438 on `dave_multibeam_sonar` at its shipped sensor configuration, n=1 — so treat 2.01x as that
result rather than as a workspace-wide multiplier. Other packages were not re-measured.

Building by hand instead, the one thing that must not be omitted:

```bash
colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# expect -O3, not an empty result
grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
```

Without it colcon leaves the build type empty and nothing gets an `-O` flag. On the sonar world
that is RTF 0.2180 against 0.4380. Every performance figure here dated before 2026-08-05 was
taken without it.

The full procedure as prose, with the reasoning for each argument:
[`notes/setup/reproduction.md`](notes/setup/reproduction.md). For Docker, [`docker/`](docker/).

## Documentation

Everything is under [`notes/`](notes/) — start from its [index](notes/README.md).

| | |
|---|---|
| [`notes/what-we-got-wrong.md`](notes/what-we-got-wrong.md) | **claims that turned out false, and how each was caught.** Read this before trusting any number here |
| [`patches/`](patches/) | **what was changed** — six patches, what each fixes and whether it is complete |
| [`notes/verified-demos.md`](notes/verified-demos.md) | what each PASS rests on |
| [`notes/known-issues.md`](notes/known-issues.md) | 48 entries, including open, resolved and withdrawn findings, with cause and workaround |
| [`notes/progress-log.md`](notes/progress-log.md) | what was done each day, and what later turned out wrong |
| [`notes/setup/reproduction.md`](notes/setup/reproduction.md) | annotated build and launch procedure |
| [`notes/validation_matrix.csv`](notes/validation_matrix.csv) | every world and vehicle, with its label |
| [`notes/upstream/submit/`](notes/upstream/submit/) | eight issue reports prepared for `IOES-Lab/dave`, none filed |
| [`docker/`](docker/) | Docker image build, RDP desktop, verification commands |
| [`notes/next-steps.md`](notes/next-steps.md) | what is still open |
| [`notes/wiki/`](notes/wiki/) | corrections applied to the DAVE documentation, and what was deliberately left out |

## Test labels

| Label | Meaning |
|---|---|
| `SMOKE PASS` | Launches and stays alive for the test window. Topic data was **not** checked |
| `FUNCTIONAL PASS` | Expected topics, services or sensor data were actually read |
| `PARTIAL` | Runs and produces some output, but has a confirmed functional or performance problem |
| `NOT AUTOMATED` | Not reachable through the current headless path. Not a claim that it cannot be tested |

## Environment

| | macOS (native) | Docker |
|---|---|---|
| OS | macOS 15.7.3, Apple Silicon (M2) | Ubuntu 26.04 Resolute (arm64) |
| ROS 2 | Lyrical (source build) | Lyrical (apt, `ros-lyrical-desktop`) |
| Gazebo | Jetty (Homebrew) | Jetty 10.4.0 (apt vendor build) |
| Python | 3.14 | 3.14 |
| Rendering | Metal (real hardware) | Vulkan `llvmpipe` (CPU software renderer) — no `/dev/dri` passthrough. Gazebo engine varied: `ogre2` in the crash reproduction, `ogre` + authorised X in the 2026-08-07 output run |
| Sonar compute | WGPU on the Metal adapter; CPU backend also run explicitly | **CPU fallback in the 2026-08-07 run; explicitly forced CPU in the 2026-08-25 RDP run.** The earlier no-X probe selected the WGPU `llvmpipe` software adapter |

Pinned source revisions and the migration patch:
[`notes/patch-and-pinned-commits.md`](notes/patch-and-pinned-commits.md).

## References

- Choi, W.-S., "Ray-Based Physical Modeling and Simulation of Multibeam Sonar for Underwater
  Robotics in ROS-Gazebo Framework," *Sensors* 2025, 25(5), 1516.
  [10.3390/s25051516](https://doi.org/10.3390/s25051516) — the method PR #44 implements
- Choi, W. et al., "Physics-Based Modelling and Simulation of Multibeam Echosounder Perception
  for Autonomous Underwater Manipulation," *Frontiers in Robotics and AI*, 2021.
  [10.3389/frobt.2021.706646](https://doi.org/10.3389/frobt.2021.706646) — the earlier
  raster-based work this sonar lineage descends from
- [DAVE documentation](http://dave-ros2.notion.site) · [ROS 2 Lyrical Luth](https://docs.ros.org/en/lyrical/)
