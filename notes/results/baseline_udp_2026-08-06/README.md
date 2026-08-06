# New baseline after the DDS fix (Mac, 2026-08-06)

Every RTF figure recorded before today is out of scope for comparison. Two things changed:

1. **`FASTDDS_BUILTIN_TRANSPORTS=UDPv4` is now set** to avoid the spawn hang
   ([`../spawn_hang_2026-08-05/ROOT_CAUSE.md`](../spawn_hang_2026-08-05/ROOT_CAUSE.md)).
   The shared-memory transport it disables was 16% of busy CPU in profiling.
2. **The sonar-ready check was fixed.** The old one matched the plugin's dummy
   `1 beams × 1 rays × 4 freq` warm-up frame and passed at 0-20 s; measurements taken with
   it could straddle the sonar coming online. The corrected check waits for the real sensor
   — observed at 110-115 s in these runs.

## Result

`dave_multibeam_sonar`, shipped sensor configuration, `Release` build of `multibeam_sonar`
and `multibeam_sonar_system`, 60 s endpoint-delta window after `wait_until_stepping`
confirms ≥60 steps/s twice.

| run | RTF | sim Δ | real Δ | msgs |
|---|---|---|---|---|
| 1 | 0.5019 | 22.573 | 44.976 | 413 |
| 2 | — | — | — | *probe returned no samples; not recorded* |
| 3 | 0.5275 | 23.430 | 44.419 | 412 |

**Mean 0.5147, range 5.0% of mean, max/min 1.05x.**

Stepping rate at the settle check was 478-542 steps/s across all three runs, including the
one whose probe failed — so the world was healthy in all three; only the measurement was
lost.

## How to use this number

**5.0% is the floor for reading a difference.** Any before/after result closer than that
cannot be attributed to the intervention at n=2-3.

**It is n=2, which is a range and not a variance estimate.** Two points cannot establish
spread. Treat 5% as provisional and widen it if a later run falls outside. Topping this up
to n=5 is worth doing before any close call is decided on it.

## The control, re-measured the same day under the same conditions

`dave_multibeam_sonar` launched via `dave_world.launch.py` — same world, no sonar sensor.
Same protocol, same `wait_until_stepping` criterion, `N=3`.

| run | RTF |
|---|---|
| 1 | 0.99806 |
| 2 | 0.99812 |
| 3 | 0.99607 |

**Mean 0.9974, range 0.2% of mean.** 3/3 completed.

**So the sonar costs 1.94x** — `overhead = 1/0.5147 − 1/0.9974 = 0.940`.

The no-sonar world steps at ~980/s against ~500/s with the sonar, consistent with the RTF
ratio.

### The control is far more reproducible than the sonar

Control spread **0.2%** against the sonar baseline's **5.0%**. Whatever produces the
run-to-run variation is in the sonar path, not in the measurement method — the method
returns nearly the same number three times running when the sonar is absent.

That also raises confidence in the 5% figure as a real property of the sonar rather than
measurement noise, and means tightening the protocol further will not shrink it.

### Effect on the headline number

The "4.5x sonar cost" recorded on 2026-07-31 (0.2180 against 0.9996) is now **1.94x**
(0.5147 against 0.9974). The denominator barely moved — 0.9996 → 0.9974, within the
control's own spread — so essentially all of the change is in the numerator.

**How that change splits between the `Release` rebuild, the DDS transport switch and the
corrected settle check is not separable from these runs.** The `Release` rebuild alone was
measured at 2.01x on 2026-08-05, which accounts for most of it, but that measurement used
the settle check that could pass on the dummy frame.

## What is not claimed

- **This is not comparable to the 0.438 recorded on 2026-08-05.** That figure was taken
  with the shared-memory transport active and with the settle check that could pass on the
  dummy frame. Both differences push in unknown directions. The gap between 0.438 and 0.515
  should not be read as "disabling shared memory gained 17%" — it may be that, or the
  settle fix, or both, or neither.
- ~~The no-sonar control has not been re-measured under these conditions.~~ **Done the same
  day — see above.** 0.9974, and the sonar cost is 1.94x.

## Known wart

The `sonar_wait_s` column reads 314/316 s. That is the whole `measure_once` duration, not
the sonar initialisation time — the timer starts before launch and stops after the 60 s
probe. Actual sonar-ready was 110-115 s per the settle output. The column is mislabelled;
it was not corrected because nothing depends on it.

## Reproduce

```bash
source ~/dave_ws_lyrical/install/setup.zsh
N=3 bash notes/experiments/go.sh 5
```

Raw: `/tmp/exp5_repeat_0806_1339.csv`, `/tmp/exp5_baseline_run{1,2,3}.log`
