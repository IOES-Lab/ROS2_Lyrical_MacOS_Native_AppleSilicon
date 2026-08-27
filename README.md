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
| Direct sonar check | Mac WGPU publishes structured 513×301 PointCloud2 and 513×399 raw sonar, but in one controlled 3.99 m planar scene the CPU peak was 3.988 m while WGPU produced 6.396–6.446 m in 5/5 frames — [evidence](notes/results/multibeam_direct_validation_2026-08-25/) |
| Direct DVL check | The exact DAVE Wiki Quickstart and controlled bottom/velocity/water-mass tests pass in Docker, including 8 Hz output, four locked beams and the official `ros_gz` bridge. **PARTIAL overall:** all four Mac controls crash in Gazebo Sensors, DAVE's custom bridge drops `frame_id`, and the shipped water-mass tags do not name environmental variables — [evidence](notes/results/dvl_direct_validation_2026-08-26/) |
| Direct USBL check | Common and individual interrogation paths passed on Mac and Docker for both tutorial transponders; the largest retained static-coordinate axis error was 0.258 mm. **Required workarounds remain:** the old Wiki sensor-launch command tries to spawn a nonexistent model, paused simulations pump no USBL ROS callbacks, and literal `sigma=0` aborts Docker/libstdc++ although macOS/libc++ accepts it — [evidence](notes/results/usbl_direct_validation_2026-08-27/) |
| Direct ocean-current check | Mac Lyrical+Jetty exposed and called all 12 `/hydrodynamics/` services. A controlled 8.98 s REXROV comparison measured an X-displacement difference of +9.05087 m for a +1.5 m/s current. This validates the global `/ocean_current` Hydrodynamics path — [evidence](notes/results/ocean_current_direct_validation_2026-08-25/) |
| Direct underwater-camera check | The Wiki Quickstart runs on Mac and Docker and publishes 320×240 `bgr8`, 230400 bytes. Three controlled conditions produced byte-identical frames across the two platforms, and the default `1/30` attenuation matched its predicted output exactly. **But `attenuationR` acts on Blue and `attenuationB` on Red** — output PASS, parameter semantics PARTIAL — [evidence](notes/results/underwater_camera_direct_validation_2026-08-26/) |
| Direct SeaPressure check | Ten controlled conditions were run on Mac and Docker with matching results. Working controls include `standard_pressure`, `kPa_per_meter`, `topic` and `estimate_depth_on`; **PARTIAL overall:** kPa-sized values enter a Pascal field, `saturation`/`noise_sigma`/`update_rate` are ignored, `abs(z)` treats +10 m like −10 m, and ROS `frame_id` is empty — [evidence](notes/results/seapressure_full_validation_2026-08-26/) |
| Direct Spherical Coordinates check | All four services passed get/set/restore and three finite round trips on Mac and Docker (maximum axis error `9.71e-10 m`). **PARTIAL overall:** the Wiki origin/result are stale or sign-reversed, NaN and latitude 100°/longitude 200° are accepted, and this Mac needs the actual installed `lib/` path for plugin discovery — [evidence](notes/results/spherical_coordinates_direct_validation_2026-08-26/) |
| Direct Model Plugin check | Enabling `OceanCurrentModelPlugin` in copied test assets, the per-vehicle current interpolated correctly at two layer midpoints (5 m and 15 m) and moved REXROV. **Depth-dependent force is still untested** — the interpolation used static probes and the motion run set all 12 layers alike — [evidence](notes/results/ocean_current_model_plugin_validation_2026-08-25/) |
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
| [`notes/known-issues.md`](notes/known-issues.md) | 41 entries, including open, resolved and withdrawn findings, with cause and workaround |
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
