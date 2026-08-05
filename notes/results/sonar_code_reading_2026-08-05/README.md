# Reading the sonar plugin source: what the measurements were actually seeing

Configuration sweeps had gone as far as they could — `<beams>`/`<rays>` couple the
raycast to the point count, so no SDF knob separates them. This is the code read
that was supposed to be needed instead.

It produced a structural explanation that accounts for **every** measurement made
today, and one finding that was not on the list at all.

Source: `dave/gazebo/dave_gz_multibeam_sonar/multibeam_sonar/MultibeamSonarSensor.cc`
(1494 lines), at pinned commit `6aef91c`.

---

## The finding that was not on the list

**The entire DAVE workspace is built with no optimisation.**

```
$ grep -E "^CMAKE_BUILD_TYPE|^CMAKE_CXX_FLAGS:" build/multibeam_sonar/CMakeCache.txt
CMAKE_BUILD_TYPE:STRING=
CMAKE_CXX_FLAGS:STRING=
```

Both empty. CMake only appends `CMAKE_CXX_FLAGS_<CONFIG>` when a build type is
set, so with both empty the compile line carries no `-O` flag at all and
GCC/Clang default to **`-O0`**.

This is not one package. All 14:

```
dave_demos  dave_gz_model_plugins  dave_gz_sensor_plugins  dave_gz_world_plugins
dave_interfaces  dave_multibeam_sonar_demo  dave_object_models  dave_robot_models
dave_ros_gz_plugins  dave_sensor_models  dave_worlds  multibeam_sonar
multibeam_sonar_system  wgpu_vendor          <- every one has BUILD_TYPE=[]
```

The package `CMakeLists.txt` files do not set it either (checked for `-O`,
`BUILD_TYPE`, `CXX_FLAGS`, `add_compile_options`, `target_compile_options` —
nothing).

**Every RTF figure recorded today describes an unoptimised sonar plugin.**

The relative comparisons all still hold — every measurement used the same build —
but the absolute numbers, and the size of the "sonar cost", are open to question.

**Caveat:** this rests on `CMakeCache.txt`. There is no `compile_commands.json`
in the build tree, so the actual compiler invocation was not inspected. A
`VERBOSE=1` rebuild would confirm it definitively. That check has not been done.

### Why this matters more than it first looks

Gazebo itself — including `gz-rendering`, which owns the GPU raycast — comes from
the vendored/apt packages and **is** built optimised. Only the DAVE plugin code is
at `-O0`.

That splits the two suspects cleanly:

| | where it lives | optimised? |
|---|---|---|
| `Render()` GPU raycast | `gz-rendering` (vendored) | yes |
| `FillPointCloudMsg` | DAVE plugin | **no** |
| `ComputeSonarImage` | DAVE plugin | **no** |

So a `Release` rebuild changes the plugin's speed and leaves the raycast
untouched. **That is the discriminator the SDF could not provide** — and it comes
free with a rebuild rather than needing a profiler.

- RTF improves substantially → the cost is in plugin code, i.e. `FillPointCloudMsg`
- RTF barely moves → the cost is in the raycast

---

## The structure, and why it explains every measurement

### `Update()` → `Render()`, synchronous

```cpp
bool MultibeamSonarSensor::Update(...)
{
  ...
  this->Render();      // line 877 — GPU raycast, on the sensor update path
  return true;
}
```

### `OnNewFrame()` → `FillPointCloudMsg()`, synchronous, in the render callback

```cpp
void ...::OnNewFrame(const float *_scan, ...)
{
  std::lock_guard<std::mutex> lock(this->rayMutex);
  ...
  memcpy(this->rayBuffer, _scan, rayBufferSize);
  this->FillPointCloudMsg(this->rayBuffer);   // line 805 — blocking
  ...
  this->computeCV_.notify_one();              // only *then* wake the compute thread
}
```

### `ComputeSonarImage()` — asynchronous, on its own thread

```cpp
this->computeThread_ = std::thread([this]() {
  while (true) {
    std::unique_lock<std::mutex> lk(this->computeMutex_);
    this->computeCV_.wait(lk, [this]{ return this->newFrameReady_ || this->stopThread_; });
    ...
    this->ComputeSonarImage();
  }
});
```

It takes `lock_` only long enough to `clone()` the depth image, then releases it —
the code says so explicitly:

```cpp
{
  std::lock_guard<std::mutex> snapshot_lk(this->lock_);
  ...
  depthSnapshot = this->pointCloudImage.clone();
  ...
}
// lock_ released -> render thread can proceed immediately.
```

### `raySkips` never reaches the point cloud

Every use is in the compute backends (`sonar_compute_wgpu.cc`,
`sonar_compute_cpu.cc`, `sonar_compute_cuda.cc`) plus the SDF parse. It does not
appear in `FillPointCloudMsg` or on the `Render()` path.

### Every measurement follows

| observation | explanation |
|---|---|
| `exp7`: cutting `raySkips` 15x gained nothing | the compute stage is async and off the critical path |
| `exp7`: `raySkips=1` (~10x compute) cost **+73%** | the compute thread saturates cores the sim/render threads need. **Not** lock contention — `lock_` is released after the clone |
| `exp1b`: cutting beams×rays 5x gained **−72%** | shrinks both `Render()` and `FillPointCloudMsg`, the two synchronous stages |
| `exp1`: range 10→1 m barely moved it | changes neither loop's iteration count |
| `exp4`: scene content irrelevant | likewise |

Five independent measurements, one structure, no contradictions. That convergence
is the main reason to trust the reading.

---

## Inside `FillPointCloudMsg`: two full passes, and redundant trig

The function traverses `width × height` **twice** per frame — 2 × 153,600 =
**307,200 iterations** at default settings.

Pass 1 (lines 953–998) computes, per point:

```cpp
... = depth * std::cos(inclination) * std::cos(azimuth);
... = depth * std::cos(inclination) * std::sin(azimuth);
... = depth * std::sin(inclination);
```

That is **five trig calls per point**, and `inclination` does not change in the
inner loop — it is a function of `j` only. So `cos(inclination)` (twice) and
`sin(inclination)` are **loop-invariant**: 3 × 153,600 ≈ **460,800 redundant trig
evaluations per frame**, where 301 × 2 would do. `azimuth` likewise takes only 513
distinct values and could be tabulated once.

Pass 2 (lines 1022–1054) traverses the whole grid again to build
`pointCloudImage`, holding `lock_` throughout.

**Whether the compiler eliminates any of this depends on flags.** With
`-fmath-errno` (on by default), `std::cos`/`std::sin` may set `errno`, so they are
not pure and cannot be hoisted out of the loop. At `-O0` nothing is hoisted
regardless. Given the build type above, **none of it is being optimised away.**

This is a plausible mechanism, not a measured one. Nothing here has been profiled;
the loop has not been timed in isolation.

---

## What to do next

**1. Rebuild `Release` and re-measure.** Cheap, and it is the discriminator:

```bash
colcon build --packages-select multibeam_sonar multibeam_sonar_system \
  --cmake-args -DCMAKE_BUILD_TYPE=Release
# then re-run, same method:
bash notes/experiments/go.sh 2    # no-sonar control
bash notes/experiments/go.sh 1b   # ray-count sweep
```

Compare against `notes/results/raycount_2026-08-05/`. A large improvement points
at plugin code; little change points at the raycast.

**2. Confirm the `-O0` claim properly** with `VERBOSE=1` or a generated
`compile_commands.json`, rather than inferring from `CMakeCache.txt`.

**3. If Release does move it,** hoisting the invariant trig and merging the two
passes becomes a concrete upstream patch with a measurable before/after.

## Caveats

- Code reading, not profiling. No function has been timed.
- The `-O0` conclusion is inferred from `CMakeCache.txt`; the compile command was
  not inspected.
- The claim that `gz-rendering` is optimised is an assumption about the vendored
  packages, not something verified.
- Whether the compiler hoists the invariant trig at higher optimisation levels was
  not checked against generated assembly.
