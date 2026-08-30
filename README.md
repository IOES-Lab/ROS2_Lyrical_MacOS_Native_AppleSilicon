# ROS 2 Lyrical / Gazebo Jetty — DAVE migration verification

Can [DAVE](https://github.com/IOES-Lab/dave) and its CUDA-free WGPU multibeam sonar
([PR #44](https://github.com/IOES-Lab/dave/pull/44)) run on ROS 2 Lyrical + Gazebo Jetty?
DAVE is documented for Jazzy + Harmonic. Verified here on macOS (Apple Silicon, native) and
Docker (Ubuntu 26.04).

This is a verification record, not a distribution. It establishes scoped build, launch, topic
and service behavior. **General numerical, acoustic, optical and hydrodynamic correctness is not
established.** On 2026-08-29 ten candidate patch groups closed every remaining defect that could be
reproduced and discriminated in the available Mac and Docker environments. The ninth closes the
fifth-ROV sonar world-composition omission; the tenth sets an explicit valid ArduSub speedup after
the official Gazebo plugin exposed an arm64 logger FPE. The upstream DAVE checkout and the user's
installed workspace remain unchanged; the fixes live in [`patches/`](patches/) and are backed by
[`notes/results/remaining_defect_fixes_2026-08-29/`](notes/results/remaining_defect_fixes_2026-08-29/),
the [`open-gap revalidation`](notes/results/open_gap_revalidation_2026-08-29/) and the
[`external-stack validation`](notes/results/external_stack_validation_2026-08-29/). Hardware,
external-account and broad scientific-validation boundaries remain open in
[`notes/next-steps.md`](notes/next-steps.md).

## Results

| | |
|---|---|
| Worlds | 17/18 PASS-level, 1 PARTIAL **in the world-level matrix** — `dvl_world.world` remains PARTIAL because the distributed Homebrew/stock path is unchanged. An isolated exact-`gz-sim10_10.4.0` candidate now removes the custom-DVL initialization race: the unmodified official world passes 20/20 without a hidden camera, but this is not installed or upstreamed |
| Direct world-model audit | A candidate patch gives all 18 distributed files unique internal `<world name>` values; Mac/Docker scoped regression checks pass. The earlier 14-name/3-duplicate-group result remains historical evidence, not the patched verdict — [current evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct sonar check | The candidate WGPU fix removes the gross 6.4 m planar shift: for a 3.99 m target, five Mac/Metal peaks are 3.988–4.064 m (median 4.013 m, maximum absolute error 0.0736 m). The GPU path now rejects frequency counts above its 4096-bin workgroup-memory limit before GPU initialisation so C++ can fall back to CPU; explicit unavailable CUDA also falls back to CPU and still publishes raw sonar. This is one controlled scene plus a boundary unit test, not general acoustic validation — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct DVL check | DAVE-local candidate fixes still give 8/8 Docker descriptors. For the separate macOS stock Gazebo crash, a first `forceUpdate` predicate-only candidate was rejected after one `WaitForInit()` crash in 10 trials. A second exact-tag candidate also gates the render-thread handoff until main-thread `RenderUtil` initialization: the unmodified official DVL world passes 20/20 with four locks and clean exit, standard camera 3/3, no-render Sensors 3/3, and the official ROS bridge reports four valid beams. The distributed path remains PARTIAL because the candidate is isolated, not installed or upstreamed — [evidence](notes/results/dvl_macos_force_update_candidate_2026-08-30/) |
| Direct ROV-model check | Patched Mac REXROV remains 7/7 in the configured state/sensor scope, and the isolated ninth candidate makes the fifth ROV sonar publish 513×301 PointCloud2 on Mac. The exact Docker image separately passed all three control variants. A current combined replay now preserves the backend distinction: software WGPU/`llvmpipe` reproduces the OGRE2 null-`memcpy` crash and exits 139, while a forced-CPU run in the same derived candidate publishes 513×301 PointCloud2, completes MAVROS MANUAL arm/control/disarm, and moves X by +1.348464 m. The combined result is backend-dependent, not globally PASS or FAIL — [evidence](notes/results/final_gap_validation_2026-08-30/combined_sonar_control/) |
| Current Docker image recipe | **Fresh `--no-cache` PASS with rendered replay (2026-08-30).** After official BuildKit cache pruning, the current Dockerfile completed from scratch in 66.917 minutes and produced a 6,260,137,751-byte arm64 image (`53744d17f09d`). Package and pinned-source checks pass. A real FreeRDP/xrdp login started Xorg/XFCE; the retained framebuffer shows Gazebo and QGroundControl with MAVROS `connected: true`, MANUAL and QGC Ready/Manual. The earlier cache image separately passed three headless control loops and a Windows App rendered replay — [fresh evidence](notes/results/final_gap_validation_2026-08-30/docker_no_cache_build/) · [cache-image controls](notes/results/external_stack_validation_2026-08-29/dockerfile/) |
| Direct Glider-model check | Docker RDP reran both Wiki launches and all 9 bridge topics. State/sensor 6/6 passes with the local IMU patch; `cmd_thrust` changes propeller velocity. A repeated integrated deadband control delivered **50/50 ROS `true` messages to Gazebo with 0 false**, withdrawing the earlier one-shot asymmetry claim. Calibration, Mac stepping and long dynamics remain open — [evidence](notes/results/full_gap_validation_2026-08-27/06_glider_deadband_integrated/) |
| Direct Object-model check | Packaged, generic Fuel and copied-source descriptor paths pass. The candidate launch preflight now rejects a missing descriptor instead of printing false success on Mac and Docker. Fuel `/1` remains a client/external reproducibility limitation, not an immutable pin — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct USBL check | Candidate plugin changes pass `sigma=0`, paused callbacks, moving-target routing and fractional 1539/1541 m propagation-delay controls on Mac and Docker. Long-duration, multi-transceiver and real-acoustic accuracy remain outside this result — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct ocean-current check | All 12 global services pass in the tested scope. A separate fixed-depth two-vehicle Docker control closed the per-vehicle depth-force gap: the 5 m vehicle received 0 m/s and stayed at Δx 0, while the 15 m vehicle started at 0.750000 m/s and moved Δx 2.400436 m over 6 s — [evidence](notes/results/full_gap_validation_2026-08-27/08_ocean_depth_force/) |
| Direct underwater-camera check | The candidate channel fix preserves no-effect/default outputs and changes the discriminating murky centre to semantic BGR `[50, 103, 85]` on both Mac and Docker. The R/B implementation defect is closed in the tested patch; general underwater optical accuracy remains unverified — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct SeaPressure check | Candidate controls pass on Mac and Docker for Pa/Pa² units, surface/depth sign, saturation, noise, update rate, variance, frame ID, custom topic and depth-topic suppression. This closes the reproducible ROS-contract defects in the patched scope, not real-sensor accuracy — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
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
| [`patches/`](patches/) | **what was changed** — sixteen patches; the ten 2026-08-29 candidates include validation and dependency order |
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
| Gazebo | Jetty (Homebrew) | Jetty 10.5.0 in the fresh 2026-08-30 image (apt vendor build); older retained runs used 10.4.0 |
| Python | 3.14 | 3.14 |
| Rendering | Metal (real hardware) | Vulkan `llvmpipe` (CPU software renderer) — no `/dev/dri` passthrough. An isolated `ogre2` sonar/CPU-fallback run published PointCloud2, while the combined Heavy-multibeam software-WGPU run reproduced the OGRE2 sample-texture/null-`memcpy` crash; forced CPU passed in that same combined snapshot |
| Sonar compute | WGPU on the Metal adapter; CPU backend also run explicitly | CPU fallback and forced CPU are validated. Software WGPU can initialize on `llvmpipe`, but the combined run then crashes in the renderer; Docker hardware WGPU/CUDA remains untested |

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
