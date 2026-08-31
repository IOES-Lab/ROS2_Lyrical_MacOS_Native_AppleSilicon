# ROS 2 Lyrical / Gazebo Jetty — DAVE migration verification

Can [DAVE](https://github.com/IOES-Lab/dave) and its CUDA-free WGPU multibeam sonar
([PR #44](https://github.com/IOES-Lab/dave/pull/44)) run on ROS 2 Lyrical + Gazebo Jetty?
DAVE is documented for Jazzy + Harmonic. Verified here on macOS (Apple Silicon, native) and
Docker (Ubuntu 26.04).

This is a verification record, not a distribution. It establishes scoped build, launch, topic
and service behavior. **General numerical, acoustic, optical and hydrodynamic correctness is not
established.** On 2026-08-29 ten candidate patch groups addressed the defects reproduced and
discriminated in that round's available Mac and Docker environments. The ninth closes the
fifth-ROV sonar world-composition omission; the tenth sets an explicit valid ArduSub speedup after
the official Gazebo plugin exposed an arm64 logger FPE. The upstream DAVE checkout and the user's
installed workspace remain unchanged; the fixes live in [`patches/`](patches/) and are backed by
[`notes/results/remaining_defect_fixes_2026-08-29/`](notes/results/remaining_defect_fixes_2026-08-29/),
the [`open-gap revalidation`](notes/results/open_gap_revalidation_2026-08-29/) and the
[`external-stack validation`](notes/results/external_stack_validation_2026-08-29/). Later isolated
Gazebo DVL, sonar startup and `parameter_bridge` ownership-cycle candidates are indexed in
[`patches/README.md`](patches/README.md). Hardware,
external-account and broad scientific-validation boundaries remain open in
[`notes/next-steps.md`](notes/next-steps.md).

## Results

| | |
|---|---|
| Worlds | 17/18 PASS-level, 1 PARTIAL **in the world-level matrix** — `dvl_world.world` remains PARTIAL because the distributed Homebrew/stock path is unchanged. An isolated exact-`gz-sim10_10.4.0` candidate now removes the custom-DVL initialization race: the unmodified official world passes 20/20 without a hidden camera, but this is not installed or upstreamed |
| Direct world-model audit | A candidate patch gives all 18 distributed files unique internal `<world name>` values; Mac/Docker scoped regression checks pass. The earlier 14-name/3-duplicate-group result remains historical evidence, not the patched verdict — [current evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct sonar check | The six-scene Docker matrix still separates incorrect distributed WGPU raw bins from the exact-N candidate. A 2026-08-31 fixed-seed/frame control then ran three fresh containers and captured nine raw plus nine point frames: each class was byte-identical within and across runs, and every raw peak was 4.013377666 m (error +0.013377666 m). Empty-cache software probing remained expensive (94.192–101 s versus about 5 s reused), so this is a deterministic correctness discriminator, not a production-performance or general-acoustic result — [matrix](notes/results/multibeam_backend_equivalence_matrix_2026-08-30/) · [determinism/cache evidence](notes/results/multibeam_seed_determinism_validation_2026-08-31/) |
| Direct DVL check | The isolated macOS exact-tag candidate still passes the official world 20/20, while the distributed Homebrew path remains PARTIAL. Separately, one Docker world instantiated all eight DAVE descriptors simultaneously and captured 20 valid messages from each (160 total): four beams, bottom lock, eight distinct nonempty frame IDs and descriptor-specific 8/12/7 Hz rates all passed. This closes bounded multi-device behavior, not physical calibration, mission endurance or upstream installation — [Mac candidate](notes/results/dvl_macos_force_update_candidate_2026-08-30/) · [multi-device evidence](notes/results/sensor_long_multi_validation_2026-08-31/) |
| Direct ROV-model check | Patched Mac REXROV remains 7/7 in the configured state/sensor scope, and the isolated sonar/Heavy candidates retain their bounded output and control passes. The baseline shutdown defect was DAVE-sonar endpoint-dependent (group shutdown exit -11 in 9/10), but an exact-`ros_gz` 3.0.9 ownership-cycle candidate now keeps PointCloud/raw payloads and gives bridge-first 20/20 clean plus process-group 10/10 rc0; direct ROS→GZ is 20/20 and stock active camera/PointCloud controls are 5/5 each. A constrained package build succeeded and 17/18 CTest targets passed; the sole remote-schema xmllint timeout passed with the canonical schema supplied locally. A normal isolated Lyrical source/install overlay then passed 8/8 topic conversions, 1/1 ControlWorld service and 10/10 active bidirectional teardowns; equivalent ARM64 Jazzy and Kilted branch-local builds each passed 8/8 topics and 1/1 service with clean bridge exit. A read-only readiness review found 0 duplicates across eight focused issue/PR searches. Humble remains static-only, and upstream submission/maintainer review/merge plus installation into the user's ordinary workspace remain open. The exact tested image still has the documented IMU/magnetometer sensor-contract gaps — [cycle-fix candidate](notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/) · [baseline bridge matrix](notes/results/parameter_bridge_shutdown_validation_2026-08-31/) · [sensor contract](notes/results/bluerov_sensor_contract_validation_2026-08-30/) |
| Current Docker image recipe | **Fresh `--no-cache` PASS with rendered replay (2026-08-30).** After official BuildKit cache pruning, the current Dockerfile completed from scratch in 66.917 minutes and produced a 6,260,137,751-byte arm64 image (`53744d17f09d`). Package and pinned-source checks pass. A real FreeRDP/xrdp login started Xorg/XFCE; the retained framebuffer shows Gazebo and QGroundControl with MAVROS `connected: true`, MANUAL and QGC Ready/Manual. The earlier cache image separately passed three headless control loops and a Windows App rendered replay — [fresh evidence](notes/results/final_gap_validation_2026-08-30/docker_no_cache_build/) · [cache-image controls](notes/results/external_stack_validation_2026-08-29/dockerfile/) |
| Direct Glider-model check | Docker RDP reran both Wiki launches and all 9 bridge topics. State/sensor 6/6 passes with the local IMU patch; `cmd_thrust` changes propeller velocity. A repeated integrated deadband control delivered **50/50 ROS `true` messages to Gazebo with 0 false**, withdrawing the earlier one-shot asymmetry claim. Calibration, Mac stepping and long dynamics remain open — [evidence](notes/results/full_gap_validation_2026-08-27/06_glider_deadband_integrated/) |
| Direct Object-model check | Packaged, generic Fuel and copied-source descriptor paths pass. The candidate launch preflight now rejects a missing descriptor instead of printing false success on Mac and Docker. Fuel `/1` remains a client/external reproducibility limitation, not an immutable pin — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct USBL check | Candidate controls pass zero-noise, paused callbacks, moving targets and fractional 1539/1541 m delay on Mac/Docker. A 2026-08-31 Docker matrix additionally ran two transceivers and four transponders in namespaces A/B with reused IDs 1/2: A-only, B-only and concurrent phases delivered only the intended namespace, with maximum axis error 5.55e-17 m. Mission endurance and physical acoustic accuracy remain outside scope — [candidate controls](notes/results/remaining_defect_fixes_2026-08-29/) · [namespace matrix](notes/results/usbl_multi_namespace_validation_2026-08-31/) |
| Direct ocean-current check | The 12 global services, two-depth/two-namespace model path and vehicle response pass in their controlled scopes. A 2026-08-31 Docker control added 400 Gauss–Markov samples with all three axes varying and a documented per-model tidal path: the no-tide model stayed fixed for 200 messages while the tide-enabled model produced 200 distinct X values over a 0.507469 m/s range. The earlier global-topic tide comparison is withdrawn as the wrong oracle because tidal oscillation is applied downstream per model — [depth/vehicle evidence](notes/results/full_gap_validation_2026-08-27/08_ocean_depth_force/) · [noise/tide evidence](notes/results/ocean_current_tidal_noise_validation_2026-08-31/) |
| Direct underwater-camera check | The semantic R/B candidate remains validated. A separate 2026-08-31 Docker isolation matrix exercised all six attenuation/background tags plus controls simultaneously, captured 10 frames per camera and matched every analytic centre-pixel prediction within 0 LSB; each semantic R/G/B tag affected the intended output channel. General underwater optical accuracy across materials, scattering and real water remains unverified — [candidate fix](notes/results/remaining_defect_fixes_2026-08-29/) · [six-tag matrix](notes/results/underwater_camera_channel_isolation_validation_2026-08-31/) |
| Direct SeaPressure check | Candidate controls pass Pa/Pa² units, sign, saturation, noise, rate, variance, frame and topic behavior on Mac/Docker. A 2026-08-31 Docker run kept seven devices active to about 200 simulated seconds; 2,000 noisy frames had mean 101325.214 Pa, standard deviation 119.914 Pa for target 123 Pa, exact variance 15129 and all unique values, while 2/10 Hz controls passed. This is bounded synthetic contract/statistical validation, not real-sensor calibration or mission endurance — [candidate controls](notes/results/remaining_defect_fixes_2026-08-29/) · [long/multi evidence](notes/results/sensor_long_multi_validation_2026-08-31/) |
| Direct Spherical Coordinates check | The candidate patch keeps the independent valid-input oracle result, rejects NaN/out-of-range requests, returns explicit failure status, responds while paused, fails safely without world spherical configuration and fixes plugin discovery on Mac/Docker. Adding `success` fields is an interface change — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct Model Plugin check | Interpolation and vehicle motion had already passed separately. A simultaneous fixed-depth Docker control now verifies depth-dependent application and two namespaces: 5 m → 0 m/s and Δx 0; 15 m → about 0.75 m/s and Δx 2.400436 m over 6 s. Coefficient and real-ocean accuracy remain outside this result — [evidence](notes/results/full_gap_validation_2026-08-27/08_ocean_depth_force/) |
| Sonar cost | RTF **0.5243** against a **0.9974** no-sonar control — 1.90x, not the 4.5x reported earlier |
| Largest win | `update_rate` 30 Hz → 2 Hz removes 75% of that cost, with no code change |
| Build trap (pre-fix history) | The old guides set no `CMAKE_BUILD_TYPE`, so nothing received an `-O` flag. The candidate patch adds Release build commands to both guides; the measured sonar-world change was 0.218 → 0.438 (n=1) |

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
| [`patches/`](patches/) | **what was changed** — eighteen retained patches; the ten 2026-08-29 candidates and two 2026-08-30 isolated candidates include validation and dependency order |
| [`notes/verified-demos.md`](notes/verified-demos.md) | what each PASS rests on |
| [`notes/known-issues.md`](notes/known-issues.md) | 48 entries, including open, resolved and withdrawn findings, with cause and workaround |
| [`notes/progress-log.md`](notes/progress-log.md) | 112 dated rows: what was done each day, and what later turned out wrong |
| [`notes/setup/reproduction.md`](notes/setup/reproduction.md) | annotated build and launch procedure |
| [`notes/validation_matrix.csv`](notes/validation_matrix.csv) | every world and vehicle, with its label |
| [`notes/upstream/submit/`](notes/upstream/submit/) | eleven issue drafts prepared (ten for `IOES-Lab/dave`, one for `gazebosim/ros_gz`), none filed; one is explicitly historical/do-not-file |
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
| Gazebo | Jetty (Homebrew) | Jetty 10.5.0 in the fresh 2026-08-30 image (apt vendor build); older retained runs used 10.4.0 |
| Python | 3.14 | 3.14 |
| Rendering | Metal (real hardware) | Vulkan `llvmpipe` (CPU software renderer) — no `/dev/dri` passthrough. The distributed software-WGPU ordering still reproduces the OGRE2 sample-texture/null-`memcpy` crash; an isolated deferred-backend candidate preserves `ogre2` output across 20/20 cold starts and 3/3 Heavy-control repetitions |
| Sonar compute | WGPU on the Metal adapter; CPU backend also run explicitly | CPU fallback and forced CPU are validated. An isolated candidate also runs WGPU on Docker `llvmpipe` and Mac Metal, but it is not installed or upstream. The exact-N correctness discriminator is too slow on fresh `llvmpipe` (88.2–115.3 s first probe). Docker hardware WGPU/CUDA remains untested |

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
