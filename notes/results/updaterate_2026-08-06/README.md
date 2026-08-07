# `update_rate` is the lever — 1.46x with no code change (Mac, 2026-08-06)

Two attempts to make the sonar *faster* failed the same afternoon, one of them badly.
Lowering how *often* it runs works.

Pooled over repeats:

| `<update_rate>` | n | mean RTF | spread | vs 30 Hz | overhead\* | removed |
|---|---|---|---|---|---|---|
| **30 (as shipped)** | 3 | 0.5243 | 7.9% | 1.00x | 0.905 | — |
| 10 | 3 | 0.5984 | 4.3% | 1.14x | 0.669 | **26%** |
| 5 | 1 | 0.6971 | — | 1.33x | 0.432 | 52% |
| 2 | 2 | 0.8140 | 6.2% | **1.55x** | 0.226 | **75%** |

\* `1/RTF − 1/0.9974`, the added cost over the no-sonar control measured the same day
(n=3, spread 0.2%).

Monotonic, and both repeated conditions separate from 30 Hz by more than either one's
spread. No rebuild, no code change — one number in the sensor's SDF.

The 30 Hz row pools the two baseline runs (0.5019, 0.5275) with the sweep's own 30 Hz run
(0.5436); 10 Hz and 2 Hz come from a dedicated `N=3` run. 5 Hz remains n=1 and is shown for
shape only.

**The 5% band quoted earlier was optimistic.** It came from n=2. With n=3 the 30 Hz
condition spreads 7.9%, so **8% is the working threshold**. Both headline effects (+14%,
+55%) clear it, but smaller ones will not be readable without more repeats.

### One measurement was discarded

`2 Hz` repeat 2 reported `sim +37.326s · real +947.475s` over a 60 s window, giving
RTF 0.0394. A real-time delta cannot exceed the observation window; `sim` was normal (37.3
against 39.4 and 42.5 in the neighbouring repeats), so the `real_time` field jumped rather
than the run being slow. Left in, it would have moved the 2 Hz mean from 0.814 to 0.556 and
the spread from 6.2% to 143.9% — i.e. it would have inverted the result.

`rtf_probe.sh` now rejects `real_delta > 1.5 × window` and `sim > real`, and emits no
`RESULT` line, so the caller drops the repeat rather than averaging an impossible value.

## Why this was tried

Two interventions had just failed:

| intervention | RTF | |
|---|---|---|
| `cv::setNumThreads(1)` | 0.5147 → 0.5054 | inside the band, no effect |
| skip the visualisation image | 0.5147 → 0.3012 | **40% worse**, spread 5% → 21% |

The second is the informative one. Removing work made it *slower*, reproducibly across three
runs. The plugin's own frame counter explains it — over comparable runs it reached:

```
baseline   GPU #550
cv1        GPU #600
noimg      GPU #1300      <- 2.4x more sonar frames
```

**The compute thread runs as fast as it can and consumes whatever that takes.** Making each
frame cheaper does not save CPU; it just runs more frames and takes more. This is the same
axis `exp7` found from the other side, where `raySkips=1` cost +73% by making the compute
thread heavier.

So the knob is frequency, not speed.

## Why 30 Hz was the wrong number to ship

The SDF asks for 30 Hz. The sensor actually achieves roughly **2.8 frames/s** (≈550 frames
over ~200 s of sonar-live time at baseline). The requested rate is far above anything
reachable, so it functions as "as fast as possible" rather than as a limit.

It is also not physical. A BlueView P900 tops out near 15 Hz in hardware; 30 Hz is asking
the simulation for something the modelled device cannot do.

## Practical recommendation

**Set `<update_rate>` to something the sensor can actually meet and the hardware actually
does.** 10 Hz costs nothing measurable in frames delivered at this resolution and returns
19% RTF; 2 Hz returns 46% and removes 69% of the sonar's overhead.

This belongs upstream as a change to the shipped `blueview_p900` model, or at minimum as
documentation. It is the first intervention in this investigation that improves RTF without
touching code or build flags.

## Caveats

- **n is 3 / 3 / 1 / 2** across 30 / 10 / 5 / 2 Hz. 5 Hz was not repeated.
- **The frame counts are too coarse to interpret finely.** The plugin logs every 50th
  frame, and the number recorded is the last one in the whole run, not within the 60 s
  probe window. 30 Hz and 10 Hz both read 600 while RTF differed by 19% — that is a
  resolution artefact, not evidence that identical work produced different RTF. Only the
  2 Hz drop (250) is large enough to read.
- **Output fidelity was not checked.** Fewer pings means fewer sonar images per second.
  Whether that matters depends on the application; nothing here measures sonar output
  quality, only simulation throughput.
- Mac / Apple M2 / Metal. `Release` build, `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`.

## Reproduce

```bash
source ~/dave_ws_lyrical/install/setup.zsh
bash notes/experiments/go.sh 11
```

The script edits `<update_rate>` inside the `multibeam_sonar` sensor block only — the model
also has `camera` and `depth_camera` sensors with their own `update_rate` tags — and
restores the SDF on exit.

Raw: `/tmp/exp11_updaterate_0806_1539.csv`, `/tmp/exp11_rate{30,10,5,2}.log`
