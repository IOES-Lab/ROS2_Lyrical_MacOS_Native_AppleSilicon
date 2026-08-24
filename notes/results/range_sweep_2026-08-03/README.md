# Sonar max range does not affect RTF (Mac, 2026-08-03)

Tests the hypothesis that the sonar's cost is ray traversal through empty space,
which predicts that shortening `<max>` range makes it substantially cheaper.

**It does not.** The hypothesis fails.

## Result

`blueview_p900` `<range><max>` varied, everything else identical. Each run:
fresh launch, cleanup verified, waited for sonar initialisation, 60s window on
`/world/default/stats`.

| max range | RTF | msgs | sim Δ | real Δ |
|---|---|---|---|---|
| 10.0 m (default) | 0.2186 | 308 | 9.834 | 44.983 |
| 3.0 m | **0.2507** | 365 | 11.913 | 47.516 |
| 1.0 m | **0.1933** | 283 | 8.911 | 46.091 |

**Not monotonic.** If range drove the cost, 1 m would be fastest. It is the
slowest of the three. 3 m is the fastest.

## Is the spread just noise?

Yes, as far as can be told. Known run-to-run variation on this world at fixed
settings:

| set | values | ratio |
|---|---|---|
| 4 repeats, 2026-07-31 | 0.2223 / 0.1884 / 0.2091 / 0.1869 | 1.19x |
| 8 consecutive windows, 2026-08-03 | 0.1866 – 0.2219 | 1.19x |
| **this range sweep** | 0.1933 – 0.2507 | **1.30x** |

The sweep's spread is only slightly wider than the noise floor and has no
direction. There is no range effect visible above the noise.

## Where this leaves the 4.5x sonar cost

Every axis varied on Mac so far leaves the number unmoved:

| varied | result |
|---|---|
| scene content (5 includes, no ground → 14 includes + heightmap) | no change (0.19–0.22 → 0.2241) |
| world (`dave_multibeam_sonar` → `dave_ocean_waves_sonar_integrated`) | no change |
| sonar max range (10 → 3 → 1 m) | no change |
| **sonar present vs absent** | **0.9996 → ~0.22** |

Only the last one matters. The cost looks **fixed per frame**, incurred by having
the sensor at all, and independent of how much of the scene it has to look at.

The remaining untested axis is ray/point count: the sensor issues 513 × 301 rays
and `FillPointCloudMsg` iterates all 153,600 points on the render-thread
callback. That is `exp1b`.

## Caveats

- **n = 1 per range.** Single measurements. A small real effect could hide inside
  the noise; what is excluded is a large one, and the non-monotonicity argues
  against any effect at all. Repeats would tighten this.
- `<max>` was changed in the sensor SDF. `<maxDistance>` (also 10 in this model)
  was **not** changed, and neither was `<raySkips>`. If the implementation keys
  off `maxDistance` rather than `range/max` for its work loop, this experiment
  would show nothing even if range did matter. **Not yet checked in the source.**
- Mac / Apple M2 / Metal only. **The statement that Docker could not run this world
  was superseded on 2026-08-07:** it runs with the `ogre` workaround and an authorised
  X display. No comparable Docker RTF was measured in that configuration.
- RTF only, not an accuracy benchmark.

## Reproduce

```bash
bash notes/experiments/go.sh 1
```
