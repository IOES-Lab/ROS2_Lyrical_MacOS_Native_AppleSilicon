# ROS 2 Lyrical / Gazebo Jetty — DAVE migration verification

Can [DAVE](https://github.com/IOES-Lab/dave) and its CUDA-free WGPU multibeam sonar
([PR #44](https://github.com/IOES-Lab/dave/pull/44)) run on ROS 2 Lyrical + Gazebo Jetty?
DAVE is documented for Jazzy + Harmonic. Verified here on macOS (Apple Silicon, native) and
Docker (Ubuntu 26.04).

This is a verification record, not a distribution. It establishes scoped build, launch, topic
and service behavior. **Numerical and acoustic correctness are not generally verified;
SeaPressure is a known numerical exception.**

## Results

| | |
|---|---|
| Worlds | 18/18 PASS-level, 0 PARTIAL **in the world-level matrix** — vehicle/sensor-specific PARTIAL findings are tracked separately |
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
| [`notes/known-issues.md`](notes/known-issues.md) | 25 entries, including open, resolved and withdrawn findings, with cause and workaround |
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
| Sonar compute | WGPU on the Metal adapter | **CPU fallback in the 2026-08-07 validated run**; the earlier no-X probe had selected the WGPU `llvmpipe` software adapter |

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
