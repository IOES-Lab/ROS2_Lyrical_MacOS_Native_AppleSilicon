> **Historical / superseded context (added 2026-08-24):** this note
> records the 2026-08-03 startup-phase investigation. Its Docker `~0.0018`
> comparison and the `~4.5x` headline below are not current results. The Docker
> value was later withdrawn, and the canonical corrected 30 Hz result is
> RTF 0.5243 against control 0.9974 — a 1.90x cost. Retain the tables below as
> dated evidence about startup behaviour, not as the current performance summary.

# dave_multibeam_sonar — startup phase vs steady state (2026-08-03, Mac/Metal)

Resolves the long-open question of why this world measured at RTF ~0.012-0.015 with
apparent multi-minute stalls on 2026-07-23, but at ~0.19-0.22 with no stall on
2026-07-31 and 2026-08-03, on unchanged code.

## Method

Single launch, then `rtf_probe.sh` sampled `/world/default/stats` in back-to-back 25s
windows from t=0 to t=360s, recording whether the sonar had finished initialising
(`Persistent GPU buffers allocated for 513×301×399` present in the launch log).
Single confirmed instance, no other `gz-sim` alive. See `rtf_phase_curve.csv`.

## Result

| elapsed | RTF | `/stats` msgs in window | sonar up |
|---|---|---|---|
| 27s | **0.0014** | 2 | no |
| 54s | *n/a* | <2 | no |
| 80s | *n/a* | <2 | no |
| 106s | *n/a* | <2 | no |
| 133s | 0.1900 | 17 | no |
| 160s | 0.2182 | 84 | yes |
| 187s | 0.2138 | 81 | yes |
| 214s | 0.2171 | 85 | yes |
| 242s | 0.2080 | 80 | yes |
| 269s | 0.1887 | 69 | yes |
| 297s | 0.1939 | 83 | yes |
| 324s | 0.1866 | 72 | yes |
| 352s | 0.2219 | 76 | yes |

Each window is 25s. Once the sim is healthy `/stats` runs at roughly 3.3 Hz
(69-85 messages per window). The probe needs two messages to compute a delta,
so "n/a" means fewer than two arrived in 25 seconds.

Steady state (8 consecutive windows after the sonar is live): mean 0.2060,
min 0.1866, max 0.2219.

## What this explains

The startup phase reproduces **both** symptoms recorded on 2026-07-23:

- an ~80s window (t≈54-106s) in which `/stats` emits fewer than two messages per
  25s window — the "zero new /stats messages" / "stall" observation, reproduced
  directly. This is the strong part of the evidence.
- an RTF on the order of 1e-3 (0.0014 at t=27s) — same order as the 0.012-0.015
  figure. Treat this number as indicative only; see caveats.

It also lines up with that day's own account of the benchmark run: a 25s settle
produced *0 RTF samples* for this world, and raising it to 90s still produced very
low numbers. Both settles land inside the window above.

**Conclusion: the 2026-07-23 characterisation measured world loading and sensor
initialisation, not steady state.** The world is not livelocked and does not stall;
it takes ~145-175s before the multibeam sonar sensor is live, and only after that is
a steady-state RTF meaningful.

## Caveats

- Mac / Apple M2 / Metal only. Docker has not been re-measured with this method, so
  the 2026-07-29 Docker figure (~0.0018) is still unexplained and may be a genuinely
  different problem — `llvmpipe` remains the leading suspect for the Mac/Docker gap.
- **The 0.0014 figure rests on two messages 0.711s apart** (sim advanced 1 ms).
  A 0.7-second baseline is far too short to call an RTF with any confidence. What
  the startup window robustly shows is the *absence of stepping*, not a specific
  low RTF value. The order-of-magnitude agreement with 2026-07-23 is suggestive,
  not proof that the same number would be reproduced.
- Single run. The steady state has been repeated (4 runs on 2026-07-31 plus 8
  windows here), but this startup curve has been captured **once**. It should be
  repeated before the conclusion is treated as settled.
- The probe cannot distinguish "publisher silent" from "sim not stepping"; it only
  observes that no `/stats` traffic arrives.
- A third reading of the silent windows — "the world had not loaded yet, so the
  topic did not exist" — is **ruled out by the t=27s row**: two `/stats` messages
  were actually received there, so the topic existed before the silence began, and
  an existing Gazebo topic does not disappear. The silence is therefore a live
  publisher going quiet, not an absent one. This run used a hardcoded topic name
  and so could not have distinguished the two directly; `exp6_phase.sh` was changed
  afterwards to resolve the topic per window and record it in the CSV, which
  separates the two cases explicitly on any future run (including Docker).
- The RTF ~0.19-0.22 steady state is still a ~4.5x slowdown against the same world
  with no sonar attached (0.9996, measured 2026-07-31). That cost is real and
  unexplained; it is simply not a stall.

## Reproduce

```bash
bash notes/experiments/go.sh 6
```

On Docker, run the **same** script so the numbers are comparable — see
[`notes/experiments/RUN_DOCKER.md`](../../experiments/RUN_DOCKER.md):

```bash
TAG=docker TOTAL=1200 SLICE=30 bash exp6_phase.sh
```

Note the CSV produced by the current script has an extra `topic` column that this
2026-08-03 Mac file predates.
