# `dave_ocean_waves_sonar_integrated` isolated on Mac (2026-08-03)

First measurement of this world on Mac/Metal with the corrected method (wait for
the sonar to actually initialise; single confirmed instance; resolve the stats
topic rather than assume it). 15 minutes, 30s sampling, then a 60s RTF window.

Two long-standing claims were tested. **Both fail.**

## Result

**RTF = 0.2241** (`/world/oceans_waves_sonar_integrated/stats`, 334 messages,
sim +10.989s over real +49.029s, iterations 183,449 → 194,438 monotonic).

| | RTF | source |
|---|---|---|
| `dave_ocean_waves_sonar_integrated` | **0.2241** | this run |
| `dave_multibeam_sonar`, sonar on, 10 m | 0.19–0.22 | 2026-07-31 ×4, 2026-08-03 ×8 |
| `dave_multibeam_sonar`, **no sonar** | 0.9996 | 2026-07-31 |

CPU and RSS, 30s samples (`rss_cpu.csv`):

| phase | CPU % | RSS |
|---|---|---|
| sonar not yet up (t=30–120s) | 69.4 → 107.1 → 108.5 → 107.2 | ramping |
| sonar live (t=150–900s), n=26 | mean **178.3**, min 150.6, max 201.1 | 279–336 MB |
| — first 13 samples | 181.0 | |
| — last 13 samples | **175.6** | |

## Claim 1 — "the empty scene is slower than the heightmap scene". Refuted.

The two worlds measure **the same**: 0.2241 vs 0.19–0.22. Scene content does not
explain the cost.

`dave_multibeam_sonar` has 5 includes and no ground. `dave_ocean_waves_sonar_integrated`
has 14 (Vase ×3, Lionfish, Coral, Kelp ×2, Sand Heightmap). If ray traversal
through empty space were the dominant cost, these should differ substantially.
They do not differ at all.

Where the claim came from: it compared two **Docker** figures, 0.0018 and 0.03.
The 0.0018 was withdrawn on 2026-08-03 (it was sampled from a different world —
see `../docker_multibeam_crash_2026-08-03/`). The asymmetry it described has never
been observed on Mac and now looks like an artefact of that misattribution.

**This kills the premise of `exp3_heightmap.sh`** (add a heightmap to the empty
world and see if it speeds up) and removes the original motivation for
`exp1_range.sh` / `exp1c_range_sweep.sh`.

## Claim 2 — "CPU climbs 32% → 47% → 69%". Not reproduced.

Once the sonar is live, CPU is flat: 26 consecutive samples over 12.5 minutes
oscillating 150.6–201.1 with **no upward trend** — the second half averages
*lower* than the first (175.6 vs 181.0). RSS is likewise flat at 279–336 MB after
the initial allocation settles, with no growth across 12.5 minutes.

There *is* a sharp step at sonar initialisation (≈107% → ≈178%), and a ramp
before it. The earlier observation was taken with other `gz-sim` instances
running concurrently and without distinguishing the startup window, so it plausibly
captured either that contention or that ramp.

**This removes the stated basis for this world's PARTIAL classification.** Whether
to reclassify is a separate decision — see below.

## What this leaves

The one thing that is real, reproducible and unexplained: **the sonar costs ~4.5x**
(0.9996 with no sonar vs ~0.22 with it). That cost now looks like a **fixed
per-frame sensor cost**, not scene-dependent, since two very different scenes pay
it identically.

That reframes the remaining experiments into a sharp prediction:

- `exp1` / `exp1c` (max range 10 → 3 → 1 m): if the cost is fixed per frame and
  not traversal-dependent, **range should barely matter**.
- `exp1b` (beam/ray count): the sensor issues 513 × 301 rays and
  `FillPointCloudMsg` loops over all 153,600 points on the render-thread callback.
  **Ray count should matter a lot.**

If range moves the number substantially, the fixed-cost reading is wrong. Either
outcome is informative, which is why both are still worth running — but with this
purpose, not the old one.

## Caveats

- Single run of this world. The multibeam figure it is compared against has 12
  windows across 5 runs; this has 1.
- Mac / Apple M2 / Metal only. **The statement that Docker could not run either sonar
  world was superseded on 2026-08-07:** the world runs with the `ogre` workaround and
  an authorised X display. No comparable Docker RTF was measured in that configuration.
- `%CPU` is `ps` whole-process across all threads, so >100% is expected on a
  multicore machine; it is not normalised and should not be read as a core count.
- RTF only. This is not an accuracy benchmark, and says nothing about whether the
  sonar output is correct.

## Reproduce

```bash
MIN=15 bash notes/experiments/exp4_integrated_isolated.sh
```
