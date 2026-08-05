# Two thirds of the "sonar cost" was build configuration (Mac, 2026-08-05)

The DAVE workspace was built with `CMAKE_BUILD_TYPE` unset — no optimisation
flags. Rebuilding `multibeam_sonar` and `multibeam_sonar_system` with
`-DCMAKE_BUILD_TYPE=Release` (`-O3`) **doubles RTF at the default sensor
configuration** and removes ~64% of the sonar's cost over the no-sonar control.

It also settles what the configuration sweeps could not: **the ray-proportional
cost lives in plugin code, not in the GPU raycast.**

## Result

Same world, same method (`wait_until_stepping`), same machine. Only the build
changed.

| rays/frame | RTF before | RTF after | speed-up | overhead* before | after | removed |
|---|---|---|---|---|---|---|
| **153,600 (default)** | 0.2180 | **0.4380** | **2.01x** | 3.587 | **1.283** | **64%** |
| 30,720 | 0.5017 | 0.5382 | 1.07x | 0.993 | 0.858 | 14% |
| 7,680 | 0.6632 | 0.6611 | 1.00x | 0.508 | 0.512 | −1% |
| 960 | 0.6835 | 0.7829 | 1.15x | 0.463 | 0.277 | 40% |

\* `overhead = 1/RTF − 1/0.9996`, the added cost over the no-sonar control.

Release was confirmed to have taken effect before measuring:

```
$ grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
   4 -O3
```

## This is the discriminator the SDF could not provide

`gz-rendering` — which owns the GPU raycast — was **not** rebuilt. Only the DAVE
plugin changed. So any improvement is plugin-side by construction.

**Where Gazebo actually comes from (verified 2026-08-05, after an earlier version
of this note asserted it without checking).** The `gz_*_vendor` packages in
`~/ros_gz_ws_lyrical` also have `CMAKE_BUILD_TYPE` empty, which at first looked
like the whole stack was unoptimised. It is not:

```
$ find ~/ros_gz_ws_lyrical/build/gz_rendering_vendor -name "*.o"                 # (nothing)
$ find ~/ros_gz_ws_lyrical/build/gz_rendering_vendor -name compile_commands.json # (nothing)
$ ls ~/ros_gz_ws_lyrical/install/gz_rendering_vendor/lib/                        # (does not exist)
$ ls /opt/homebrew/lib/libgz-rendering*
/opt/homebrew/lib/libgz-rendering-ogre.10.0.1.dylib   ...
```

The vendor package compiles nothing — its build tree holds only `ament_cmake`
symlink-install artefacts. It wraps the **Homebrew** Gazebo install, which ships
optimised release binaries. So the vendor packages' empty `BUILD_TYPE` is
harmless; the only build type that mattered was DAVE's own.

**Per-ray cost fell 6.1x:**

| build | marginal cost per ray (fitted over 30,720 → 153,600) |
|---|---|
| as-shipped | 2.111e-05 |
| Release | 3.459e-06 |

The cost that scales with ray count is therefore **in the plugin**, consistent
with `FillPointCloudMsg` — which traverses `width × height` twice per frame with
five trig calls per point, three of them loop-invariant (see
`../sonar_code_reading_2026-08-05/`).

It is not proof that `FillPointCloudMsg` specifically is the site — `ComputeSonarImage`
is also plugin code and also got faster. But `exp7` showed the compute stage is
asynchronous and off the critical path, which leaves `FillPointCloudMsg` as the
plausible one.

## The relationship changed shape, not just scale

As shipped, overhead was strikingly **linear** in ray count — a line fitted
through two points predicted a held-out third to within 0.2%:

```
overhead = 0.345 + 2.111e-05 × N        (as shipped)
```

Under `-O3` that no longer holds. Fitting the same way over-predicts the small
end badly:

```
N=153,600   predicted 1.283   measured 1.283
N= 30,720   predicted 0.858   measured 0.858
N=  7,680   predicted 0.778   measured 0.512   (−0.266)
N=    960   predicted 0.755   measured 0.277   (−0.478)
```

The Release curve is **sub-linear**. Marginal cost per ray falls roughly 10x from
the small end to the large end:

| interval | marginal cost/ray |
|---|---|
| 960 → 7,680 | 3.50e-05 |
| 7,680 → 30,720 | 1.50e-05 |
| 30,720 → 153,600 | 3.46e-06 |

A plausible reading: without optimisation every point costs the same, giving
clean linearity; with `-O3` vectorisation and per-frame amortisation make large
batches relatively cheaper. **This is an interpretation of four single
measurements, not something established.** No assembly was inspected.

## What this changes

**The practical recommendation is now different.** Before touching the code, the
build should be configured. The README's reproduction section produces an
unoptimised build, so anyone following it measures what we measured all day.

**Prior absolute figures are superseded for Release builds.** The
0.19–0.22 recorded for this world across 2026-07-31 and 2026-08-05 describes the
unoptimised build. The Release figure at default settings is **0.438**.

Relative conclusions from earlier experiments are unaffected — each compared
within a single build:

- scene content irrelevant
- world irrelevant
- range has a small effect, an order of magnitude weaker than ray count
- compute stage (`raySkips`) is not the bottleneck

**A real cost remains.** At default settings Release still gives 0.438 against a
0.9996 control — about **2.3x**. Build configuration explained roughly two thirds
of the gap, not all of it.

## Caveats

- Gazebo being optimised rests on it being a Homebrew binary distribution.
  Homebrew's own build flags for `gz-rendering` were not inspected.
- **The as-shipped build was never directly confirmed to be `-O0`.** It was
  inferred from `CMAKE_BUILD_TYPE:STRING=` and `CMAKE_CXX_FLAGS:STRING=` being
  empty in `CMakeCache.txt`; no `compile_commands.json` existed for it, so the
  actual compile line was not read. What is measured is "Release is 2x faster at
  default settings", not "the old build was `-O0`". The two are consistent but
  not the same claim.
- n = 1 per condition, as throughout.
- Only `multibeam_sonar` and `multibeam_sonar_system` were rebuilt. The other 12
  DAVE packages remain unoptimised.
- The 7,680-ray point shows no improvement (−1%) while its neighbours show 14%
  and 40%. Non-monotonic. Most likely noise at n=1, but unexplained.
- Mac / Apple M2 / Metal only. RTF only — this says nothing about output
  correctness under `-O3`.

## Reproduce

```bash
cd ~/dave_ws_lyrical
source ~/ros2_lyrical/.venv/bin/activate      # colcon lives here
source ~/ros2_lyrical/install/setup.zsh
colcon build --packages-select multibeam_sonar multibeam_sonar_system \
  --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
grep -o '\-O[0-3s]*' build/multibeam_sonar/compile_commands.json | sort | uniq -c
source install/setup.zsh
bash notes/experiments/go.sh 1b
```
