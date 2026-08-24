> **Historical measurement context (added 2026-08-24):** the relative
> range/ray-count observations below are retained as dated experiment results,
> but their `~4.5x` performance framing is superseded. The repository's
> canonical corrected 30 Hz comparison is RTF 0.5243 against 0.9974, or 1.90x.
> Do not use the raw RTF values below as the current headline benchmark.

# Re-measurement of exp1 and exp4 under the stepping criterion (2026-08-05)

Both were originally measured on 2026-08-03 using a *log line* as the signal that
the simulator was ready. That criterion was later shown to fire during a phase in
which the simulator is doing essentially nothing (see
`../raycount_2026-08-05/`). Re-run here with `wait_until_stepping`, which
requires observed `iterations` growth.

**One conclusion needs correcting. Two are confirmed.**

---

## Correction — sonar max range has a small real effect, not none

| max range | RTF (2026-08-05) | overhead* | RTF (2026-08-03, void) |
|---|---|---|---|
| 10.0 m | 0.2100 | 3.761 | 0.2186 |
| 3.0 m | 0.2156 | 3.639 | 0.2507 |
| 1.0 m | 0.2344 | 3.266 | 0.1933 |

\* `overhead = 1/RTF − 1/0.9996`, i.e. added cost over the no-sonar control.

The 2026-08-03 run gave a **non-monotonic** result and was recorded as
"range has no measurable effect — the spread is noise". That was wrong, or at
least overstated.

Under the corrected criterion the ordering is **monotonic and in the expected
direction**: shorter range is faster, every step. The magnitude is small —
a 10x range reduction removes **13%** of the overhead.

For scale, from the same day's ray-count sweep, a **5x** ray reduction removes
**72%** of the overhead.

**Revised statement:** range does affect the cost, but roughly an order of
magnitude more weakly than ray count. It is not the explanation for the ~4.5x
slowdown; ray count is. Calling it "irrelevant" was too strong.

Note the earlier caveat still stands: only `<range><max>` was changed.
`<maxDistance>` (also 10) and `<raySkips>` were not.

---

## Confirmed — the integrated world measures the same as the empty one

**RTF 0.2197** (317 msgs, sim +10.264s / real +46.710s, iterations
173,615 → 183,879 monotonic), against 0.2241 on 2026-08-03 and 0.19–0.22 for
`dave_multibeam_sonar`.

`dave_ocean_waves_sonar_integrated` has 14 includes plus a Sand Heightmap;
`dave_multibeam_sonar` has 5 and no ground. They cost the same. **Scene content
does not explain the sonar cost** — that conclusion survives the better method.

---

## Confirmed — no CPU climb, and RSS actually falls

Sampling from the point the simulator genuinely starts stepping (t ≥ 150s,
n = 26 over 12.5 minutes):

| | value |
|---|---|
| CPU mean | 170.7% |
| CPU range | 155.3 – 192.9% |
| first half / second half | 172.6 / **168.9** |
| RSS start → end | 405 MB → **281 MB** |
| RSS range | 263 – 405 MB |

No upward trend in CPU; the second half is slightly *lower*. RSS **decreases**
by ~30% over the window rather than growing. The "CPU climbs 32% → 47% → 69%"
finding is not reproduced, and there is no memory accumulation.

---

## Bonus — independent evidence for the log/stepping gap

This run captured the same mismatch from a different signal. `sonar_up` flipped
to 1 at **t = 60s**, but CPU stayed at ~107% through t = 120s and only jumped to
192.9% at **t = 150s**:

```
t= 30s   40.1%   sonar 아직
t= 60s  110.2%   sonar 켜짐     <- log says ready
t= 90s  108.6%   sonar 켜짐
t=120s  106.8%   sonar 켜짐
t=150s  192.9%   sonar 켜짐     <- actual work starts here
```

So the ~90s gap between "the sonar logged that it is up" and "the simulator is
actually working" is visible in CPU usage too, not only in `iterations`. Two
independent signals, same conclusion.

## Caveats

- n = 1 per condition, as before. The range effect (13% across a 10x change) is
  small enough that repeats would be worthwhile to separate it cleanly from the
  noise floor, even though the ordering is now correct.
- Mac / Apple M2 / Metal only.
- `%CPU` is `ps` whole-process across threads; >100% is expected on multicore.
- RTF only, not an accuracy benchmark.

## Reproduce

```bash
bash notes/experiments/go.sh 1
MIN=15 bash notes/experiments/exp4_integrated_isolated.sh
```
