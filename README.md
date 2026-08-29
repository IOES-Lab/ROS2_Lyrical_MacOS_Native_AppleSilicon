# ROS 2 Lyrical / Gazebo Jetty — DAVE migration verification

Can [DAVE](https://github.com/IOES-Lab/dave) and its CUDA-free WGPU multibeam sonar
([PR #44](https://github.com/IOES-Lab/dave/pull/44)) run on ROS 2 Lyrical + Gazebo Jetty?
DAVE is documented for Jazzy + Harmonic. Verified here on macOS (Apple Silicon, native) and
Docker (Ubuntu 26.04).

This is a verification record, not a distribution. It establishes scoped build, launch, topic
and service behavior. **General numerical, acoustic, optical and hydrodynamic correctness is not
established.** On 2026-08-29 eight candidate patch groups closed every remaining defect that could
be reproduced and discriminated in the available Mac and Docker environments. The upstream DAVE
checkout and the user's installed workspace remain unchanged; the fixes live in [`patches/`](patches/)
and are backed by [`notes/results/remaining_defect_fixes_2026-08-29/`](notes/results/remaining_defect_fixes_2026-08-29/).
External-stack, hardware and broad scientific-validation boundaries remain open and are listed in
[`notes/next-steps.md`](notes/next-steps.md).

## Results

| | |
|---|---|
| Worlds | 17/18 PASS-level, 1 PARTIAL **in the world-level matrix** — `dvl_world.world` remains PARTIAL only because stock Gazebo Sensors still SIGSEGVs on the tested Mac; its Docker DAVE-local descriptor/configuration/bridge defects pass with the validated candidate patch |
| Direct world-model audit | A candidate patch gives all 18 distributed files unique internal `<world name>` values; Mac/Docker scoped regression checks pass. The earlier 14-name/3-duplicate-group result remains historical evidence, not the patched verdict — [current evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct sonar check | The candidate WGPU fix removes the gross 6.4 m planar shift: for a 3.99 m target, five Mac/Metal peaks are 3.988–4.064 m (median 4.013 m, maximum absolute error 0.0736 m). The GPU path now rejects frequency counts above its 4096-bin workgroup-memory limit before GPU initialisation so C++ can fall back to CPU; explicit unavailable CUDA also falls back to CPU and still publishes raw sonar. This is one controlled scene plus a boundary unit test, not general acoustic validation — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct DVL check | With the candidate patch, all 8 shipped descriptors publish four-beam Docker messages, frame IDs are populated, range initialization errors are absent, and an actual descriptor reports water-mass target with non-zero environmental velocity. Overall remains PARTIAL because the stock Gazebo Sensors DVL path still SIGSEGVs on the tested Mac — [evidence](notes/results/remaining_defect_fixes_2026-08-29/) |
| Direct ROV-model check | In the patched Mac ocean world REXROV published 7/7 configured message types. The fifth `bluerov2_heavy_multibeam_sonar` variant is no longer source-only: it spawned on Mac and Docker but published only odometry among the four tracked outputs. Standalone keyboard and WebSocket Joy paths pass in Docker, while the exact integrated BlueROV2 launch remains incomplete because the current image lacks `mavros`/`mavros_msgs` — [evidence](notes/results/rov_direct_validation_2026-08-27/) |
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
| [`patches/`](patches/) | **what was changed** — fourteen patches; the eight 2026-08-29 candidates include validation and dependency order |
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
