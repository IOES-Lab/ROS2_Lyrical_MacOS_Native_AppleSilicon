# The sonar compute stage is not the bottleneck (Mac, 2026-08-05)

`exp1b` established that ~90% of the sonar's cost scales with ray count. But it
varied `<beams>`/`<rays>`, which changes three things at once — the GPU raycast
resolution, the sonar compute workload, and the emitted PointCloud2 size.

`raySkips` separates them. It subsamples rays **at the compute stage only**; the
raycast stays at 513×301.

**Result: reducing compute does not help. The compute stage accounts for roughly
8% of the overhead at default settings.**

## Result

`<beams>512` / `<rays>300` fixed throughout. Only `<spec><raySkips>` varied.
The plugin reports its effective ray count in the log
(`513 beams × N rays × 399 freq`), which is recorded to confirm the parameter
actually took effect.

| raySkips | effective rays | RTF | overhead* |
|---|---|---|---|
| 1 (no skipping) | **301** | 0.1323 | 6.559 |
| 10 (default) | 31 | 0.2090 | 3.785 |
| 30 | 11 | 0.2157 | 3.635 |
| 100 | 4 | 0.1770 | 4.649 |
| 300 | 2 | 0.1790 | 4.585 |

\* `overhead = 1/RTF − 1/0.9996`, i.e. added cost over the no-sonar control.

The effective-ray column tracks `raySkips` correctly (301 → 31 → 11 → 4 → 2), so
the parameter is doing what it says.

## The response is strongly asymmetric

**Increasing compute costs.** `raySkips=1` computes 301 rays instead of 31 — a
~10x increase — and overhead rises 3.785 → 6.559, **+73%**. The positive control
passes: this parameter has a real effect on runtime.

**Decreasing compute gains nothing.** From 31 down to 2 effective rays — a
**15.5x reduction** — overhead ranges 3.635 to 4.649, a 1.28x spread against a
known fixed-setting noise floor of 1.19x. There is no trend, and if anything the
two smallest configurations measured slightly *worse*.

Fitting a line through the two endpoints (31 and 301 rays):

```
overhead = 3.466 + 0.01028 × (compute rays)
```

At the default 31 rays that is **0.319 from compute (8%)** and **3.466
independent of compute (92%)**.

## What this means, combined with exp1b

| experiment | what was reduced | effect on overhead |
|---|---|---|
| `exp1b` | beams×rays 5x — raycast **and** compute **and** point count | 3.587 → 0.993 (**−72%**) |
| `exp7` | compute only, 15x | 3.785 → 4.585 (**+21%**, i.e. nothing) |

Cutting compute alone buys nothing. So the large gain in `exp1b` came from the
other two things it changed: **the GPU raycast and/or the PointCloud2 fill.**

This eliminates the sonar signal-processing path (backscatter / matmul / FFT) as
the dominant term, which had been the leading suspect. It is real work — the log
reports ~93.7 ms per GPU frame at default settings — but it is not what governs
RTF here.

## What is still open

**Raycast vs point fill has not been separated.** Both scale with beams×rays and
the SDF couples them: `<beams>`/`<rays>` sets the GpuRays resolution *and*
determines the emitted point count. No configuration knob appears to split them,
so **the next step is not another sweep** — it needs profiling (e.g. Instruments
on macOS) or reading `MultibeamSonarSensor.cc` to time `Render()` against
`FillPointCloudMsg` directly.

**The two lowest points do not fit.** At 4 and 2 effective rays the measured
overhead sits ~1.1 above the fitted line, higher than the default configuration.
The linear model does not explain that. With n=1 per condition it is most likely
noise, but it is not accounted for and should not be waved away — a repeat would
settle it.

**The 0.744 ceiling from `exp1b` is untouched by this experiment.**

## Caveats

- n = 1 per condition.
- Mac / Apple M2 / Metal only.
- RTF only. Reduced `raySkips` presumably degrades sonar output quality; nothing
  here measures that. These settings are diagnostic, not a recommendation.
- The claim "raySkips does not change the emitted point count" is inferred from
  the persistent buffer staying at 513×301×399 across all conditions, not from
  reading the publisher code.

## Reproduce

```bash
bash notes/experiments/go.sh 7
```
