<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave). The two build guides that carry the problem (`gazebo/DEMO_GUIDE.md`, `gazebo/DEMO_GUIDE_AppleSilicon_MacOSX.md`) arrived with the WGPU sonar work, so a comment on [PR #44](https://github.com/IOES-Lab/dave/pull/44) may reach the right person faster. Verified against `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`.
     라벨:     `bug`, `performance`, `documentation`
     원본:     notes/build-type-issue-draft.md
     자동 생성: notes/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

Documented build sets no `CMAKE_BUILD_TYPE`, so `multibeam_sonar` compiles at `-O0` — `-DCMAKE_BUILD_TYPE=Release` doubles real-time factor

## 이슈 본문 (아래 전체를 본문 칸에 붙여넣기)

---

## Summary

Neither build guide passes `--cmake-args -DCMAKE_BUILD_TYPE=Release`, and no package
`CMakeLists.txt` sets a default. colcon does not supply one either, so following the
documentation as written produces a build with **no `-O` flag at all**.

Rebuilding only `multibeam_sonar` and `multibeam_sonar_system` with
`-DCMAKE_BUILD_TYPE=Release` **doubled RTF** on the `dave_multibeam_sonar` world at the
shipped sensor configuration — 0.218 → 0.438 — and removed about **64%** of the sonar's
measured cost over a no-sonar control.

Nothing else changed. Same machine, same world, same measurement procedure, same Gazebo
binaries.

## Evidence that the build is unoptimised

Following `gazebo/DEMO_GUIDE.md` verbatim, then:

```
$ grep -E "^CMAKE_BUILD_TYPE:|^CMAKE_CXX_FLAGS:" build/multibeam_sonar/CMakeCache.txt
CMAKE_BUILD_TYPE:STRING=
CMAKE_CXX_FLAGS:STRING=
```

Both empty. CMake only appends `CMAKE_CXX_FLAGS_<CONFIG>` when a build type is set, so with
both empty the compile line carries no optimisation flag and Clang/GCC default to `-O0`.

This is not one package. Every DAVE package in the workspace is the same:

```
dave_demos  dave_gz_model_plugins  dave_gz_sensor_plugins  dave_gz_world_plugins
dave_interfaces  dave_multibeam_sonar_demo  dave_object_models  dave_robot_models
dave_ros_gz_plugins  dave_sensor_models  dave_worlds  multibeam_sonar
multibeam_sonar_system  wgpu_vendor         <- CMAKE_BUILD_TYPE empty in all 14
```

The `CMakeLists.txt` files do not set it either — grepped all 14 for `CMAKE_BUILD_TYPE`,
`add_compile_options`, `target_compile_options` and `-O`. The only hits are
`-Wno-psabi` and `-Wall -Wextra -Wpedantic`; no optimisation flag anywhere.

**One detail suggests this is an oversight rather than a choice.** `wgpu_vendor` builds the
Rust crate with an explicit `--release`:

```cmake
COMMAND ${CARGO_EXECUTABLE} build --release --target-dir ${RUST_TARGET_DIR}
```

So the compute backend is optimised while the C++ that calls it is not.

## Measured impact

Same world, same procedure, same machine; only the build changed. `overhead` is
`1/RTF − 1/0.9996` — the added cost over a no-sonar control measured on the same setup.

| rays/frame | RTF as documented | RTF with `Release` | speed-up | overhead before | after | removed |
|---|---|---|---|---|---|---|
| **153,600 (shipped default)** | 0.2180 | **0.4380** | **2.01x** | 3.587 | 1.283 | **64%** |
| 30,720 | 0.5017 | 0.5382 | 1.07x | 0.993 | 0.858 | 14% |
| 7,680 | 0.6632 | 0.6611 | 1.00x | 0.508 | 0.512 | −1% |
| 960 | 0.6835 | 0.7829 | 1.15x | 0.463 | 0.277 | 40% |

Release was confirmed to have taken effect before measuring:

```
$ grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
   4 -O3
```

**The effect is largest at the shipped configuration**, which is where it matters most.

## A useful side effect: this localises the cost

`gz-rendering` — which owns the GPU raycast — was **not** rebuilt. It comes from the
distribution's Gazebo install, not from these workspaces (the `gz_*_vendor` packages
compile nothing; their build trees hold no object files and no `compile_commands.json`).

So only DAVE plugin code changed, and the improvement is plugin-side by construction.
Marginal cost per ray fell 6.1x (2.111e-05 → 3.459e-06, fitted over 30,720 → 153,600),
which points at the per-point work in `FillPointCloudMsg` rather than the raycast. That is
a separate report; noting it here only because the rebuild happens to answer it.

## Suggested fix

**Preferred — set a default in CMake**, so it holds regardless of how the user invokes
colcon. Standard idiom, used widely across Gazebo and ROS packages:

```cmake
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()
```

Applied at minimum to `multibeam_sonar` and `multibeam_sonar_system`; sensible for the
other compiled packages too. `RelWithDebInfo` would be a reasonable choice instead if
keeping debug symbols is preferred — the point is that *something* gets set.

**Also — update both build guides**, so the documented path does not depend on the CMake
change landing:

```diff
 # gazebo/DEMO_GUIDE.md and gazebo/DEMO_GUIDE_AppleSilicon_MacOSX.md
-colcon build --packages-select dave_demos dave_worlds dave_interfaces multibeam_sonar multibeam_sonar_system dave_multibeam_sonar_demo dave_sensor_models
+colcon build --packages-select dave_demos dave_worlds dave_interfaces multibeam_sonar multibeam_sonar_system dave_multibeam_sonar_demo dave_sensor_models \
+  --cmake-args -DCMAKE_BUILD_TYPE=Release
```

## What this claim is and is not

- What is measured is **"Release is about 2x faster at the shipped configuration"**.
- **The old build was never directly confirmed to be `-O0`.** That is inferred from
  `CMAKE_BUILD_TYPE` and `CMAKE_CXX_FLAGS` both being empty; no `compile_commands.json`
  existed for that build, so its actual compile line was not read. The two claims are
  consistent but not identical.
- `n = 1` per condition. The 7,680-ray point shows no improvement while its neighbours show
  14% and 40% — non-monotonic, most likely noise, but unexplained.
- RTF only. This says nothing about whether sonar output is numerically identical under
  `-O3`; that has not been checked, and is worth checking before anyone treats the speed-up
  as free.
- Measured on macOS / Apple Silicon / Metal only. The build-configuration finding itself is
  platform-independent — it is visible in `CMakeCache.txt` on any platform — but the
  magnitude of the speed-up may not be.

## Environment

- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- ROS 2 Lyrical + Gazebo Jetty 10.4, Apple Silicon (M2), native, Metal
- World `dave_multibeam_sonar`, sensor `blueview_p900` at its shipped SDF settings
- RTF sampled as an endpoint delta over `/world/default/stats` after the simulation was
  confirmed to be stepping steadily

## Reproduce

```bash
colcon build --packages-select multibeam_sonar multibeam_sonar_system \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
```

Then launch the sonar world and compare RTF against the same world built as documented.

Full write-up, raw CSVs and measurement scripts:
[`notes/results/release_rebuild_2026-08-05/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/release_rebuild_2026-08-05/)
