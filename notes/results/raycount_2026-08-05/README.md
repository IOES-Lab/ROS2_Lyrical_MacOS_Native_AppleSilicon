# The sonar cost is ~90% proportional to ray count (Mac, 2026-08-05)

This answers the question left open since 2026-07-31: **why does enabling the
multibeam sonar drop RTF from 0.9996 to ~0.22?**

Answer: at the default `blueview_p900` configuration, **about 90% of the added
cost is proportional to the number of rays**. The remaining ~10% is a fixed cost
of having the sensor at all.

Every other axis tested was flat — scene content, world, and sonar max range all
left the number unmoved. Ray count is the one that moves it.

## Result

`<beams>` / `<rays>` varied in the sensor SDF, everything else identical.

| beams × rays | rays/frame | RTF | msgs | real Δ |
|---|---|---|---|---|
| 512 × 300 (default) | 153,600 | 0.2180 | 315 | 47.2s |
| 512 × 60 | 30,720 | 0.5017 | 430 | 48.2s |
| 128 × 60 | 7,680 | 0.6632 | 492 | 50.0s |
| 64 × 15 | 960 | 0.6835 | 485 | 49.6s |

Control (no sonar attached, 2026-07-31): **0.9996**.

## The relationship is linear in ray count

Working in cost rather than rate — `cost = 1/RTF`, and `overhead = cost − 1/0.9996`:

| rays/frame | 1/RTF | overhead |
|---|---|---|
| 153,600 | 4.5872 | 3.5868 |
| 30,720 | 1.9934 | 0.9930 |
| 7,680 | 1.5079 | 0.5075 |
| 960 | 1.4631 | 0.4627 |

Fitting a straight line through **only** the two largest points gives

```
overhead = 0.345 + 2.111e-5 × N
```

and that line then predicts the 7,680-ray point at 0.5066 against a measured
0.5075 — **0.2% error, on a point not used in the fit.**

At the default 153,600 rays this decomposes as:

- **fixed cost 0.345 → 10%**
- **ray-proportional cost 3.242 → 90%**

## Two things this does *not* settle

**A floor remains.** Extrapolating to zero rays leaves overhead 0.345, i.e. an
RTF ceiling of **0.744**, not 0.9996. Roughly a quarter of the slowdown is
present regardless of sensor size and is still unexplained.

**It does not identify which loop.** Linear in ray count is equally consistent
with the `Render()` GPU ray-cast and with `FillPointCloudMsg` iterating every
point — both scale with N. A discriminator is available and untested: `raySkips`
(currently 10) reduces the rays actually *computed* without necessarily changing
the emitted point count. The log line
`GPU #50 | 21.5 ms | 65 beams × 2 rays × 399 freq` for a `rays=15` config shows
15/10 ≈ 2 rays reaching compute, so the two are separable. **Vary `raySkips`
alone: if RTF moves, the cost is compute-side; if not, it is in the point fill.**

## Caveats

- **n = 1 per condition.** The linear fit is excellent but rests on single
  measurements. It should be repeated before being treated as settled.
- The 960-ray point sits 0.098 above the fitted line — the only real deviation.
  Plausibly noise at the small end, where the fixed term dominates and relative
  error is largest, but a second regime cannot be excluded.
- Mac / Apple M2 / Metal only. Docker cannot currently run this world at all.
- RTF only. Nothing here says whether the sonar output is *correct* at reduced
  ray counts — the reduced configurations are diagnostic, not a proposed setting.

## Method note — this is the third attempt, and the first valid one

The first two runs of this experiment produced numbers in the same direction that
had to be thrown away. Both failures came from using **log lines** as the signal
that the simulator was ready:

1. `Persistent GPU buffers allocated for 513` was hardcoded, so reduced-beam
   conditions timed out and were silently skipped.
2. Generalising it to `Persistent GPU buffers allocated for` then matched a dummy
   `1×1×4` allocation the plugin emits first, passing after ~20s.
3. Switching to `[sonar_wgpu] GPU #` still passed too early.

A direct check settled it. Sampling `iterations` every 30s from launch:

```
t= 30s   8          t= 90s   6,536
t= 60s   11         t=120s   15,116   (+8,580)
                    t=150s   24,389   (+9,273)
                    t=180s   33,365   (+8,976)
```

**The simulator does essentially nothing for the first ~60-75s, then steps
steadily.** No log line marks that transition — the sonar messages all appear
during the frozen phase. Over the course of 2026-08-03 their timing drifted from
~163s down to ~20s while the frozen phase stayed the same length, which is what
made them look like a valid settle signal and then stop working.

The scripts now wait on `iterations` growth directly (`wait_until_stepping` in
`common.sh`: ≥1000 per 15s, twice consecutively). That is the only criterion that
observes the thing being measured. Applied here it gave 47-50s of usable data
inside a 60s window, against 1-12s before.

**Consequence for earlier results:** `exp1` (range sweep) and `exp4` (integrated
world) were measured with the old log-line criterion and should be re-run under
the new one before being relied on.

## Reproduce

```bash
bash notes/experiments/go.sh 1b
```
