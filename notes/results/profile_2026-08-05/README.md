# Profiling the running sonar: the leading hypothesis was wrong (Mac, 2026-08-05)

All day the question "where does the sonar cost live" was answered by *inference* —
configuration sweeps, then a `Release` rebuild that isolated plugin code from the raycast.
The code read then nominated `FillPointCloudMsg` and its ~460,800 redundant trig
evaluations per frame as the most plausible site, and the next planned step was to hoist
that trig and measure before/after.

A profiler was run first instead. `sample(1)` on the live `gz-sim-server`, 10 s at 1 ms,
no rebuild and no code change.

**`FillPointCloudMsg` accounts for 1.0% of CPU. The trig patch would have been wasted
work.**

## Result

49 threads, 5,946 samples each. After excluding samples whose stack top is a blocking call
(`__psynch_cvwait`, `mach_msg2_trap`, `kevent`, …), 23,975 samples represent actual CPU.

Inclusive CPU under each function of interest — blocked time excluded:

| | samples | % of busy | thread |
|---|---|---|---|
| `FillPointCloudMsg` | 234 | **1.0%** | render |
| `OnNewFrame` | 250 | 1.0% | render |
| `ComputeSonarImage` | 5,939 | 24.8% | `computeThread_` (async, off critical path) |
| `gz-rendering` | 5,473 | 22.8%\* | render |
| `GpuRays` | 881 | 3.7%\* | render |

\* These two are from the first analysis pass, whose inclusive figures included blocked
time (the same bug that made `gz-sim` read 124%). They are upper bounds, not CPU. The
`FillPointCloudMsg` and `ComputeSonarImage` rows are unaffected in ordering — 1.0% is 1.0%
either way.

Where the spinning comes from, once each yield is attributed to its nearest non-system
caller — **49.3% of busy CPU is spin-waiting**:

| samples | % of busy | caller | threads |
|---|---|---|---|
| ~5,225 | **21.8%** | `tbb::detail::r1::stealing_loop_backoff::pause()` | 7 workers, ~747 each |
| 3,871 | **16.1%** | `boost::interprocess::spin_wait::yield()` (Fast DDS shm) | `dds.shm.*` × 2 |
| 1,028+ | 4.3%+ | `Ogre::pthread_barrier_wait` | render + 2 |

Seven TBB worker threads spinning on an 8-core M2 is a textbook oversubscription signature.
Which subsystem owns the TBB pool was not determined.

Top self time — where CPU was actually burned:

| samples | % | symbol |
|---|---|---|
| 9,669 | **40.3%** | `swtch_pri` (thread yield) |
| 2,224 | 9.3% | `__sendmsg` |
| 1,168 | 4.9% | `__psynch_cvbroad` |
| 871 | 3.6% | `__psynch_mutexdrop` |
| 804 | 3.4% | `__open` |
| ~1,090 | ~4.5% | OpenCV drawing (`cv::EllipseEx`, `Line2`, `Circle`, `FillConvexPoly`) |

Several `eprosima::fastdds::*` symbols also appear in the top 20.

## What this retires

**The trig hoist is not worth doing for performance.** The redundant work is real — it was
read directly from the source — but it sits inside a function that costs 1% of CPU.
Removing all of it cannot move RTF meaningfully. It may still be worth submitting as a
readability/correctness cleanup; it is no longer a performance patch.

This also means the `Release` rebuild's 6.1x drop in per-ray marginal cost, which was read
as "consistent with `FillPointCloudMsg`", was consistent with something else. That
attribution in
[`../release_rebuild_2026-08-05/`](../release_rebuild_2026-08-05/) is now unsupported —
the note already said it was not proof, and this is the measurement that decides against it.

## What it suggests instead

**40% of CPU is spent yielding.** `swtch_pri` is not computation; it is a thread giving up
its timeslice. Together with `__psynch_cvbroad`, `__psynch_mutexdrop` and the main thread
being only 5.4% busy, the shape is **contention/serialisation, not compute**. The simulation
loop is not CPU-bound — it is waiting.

DDS messaging (`__sendmsg` plus the `fastdds` symbols) is a visible second cost, plausibly
the point cloud being published every frame.

If the bottleneck is oversubscription rather than any single hot function, that accounts for
more of the existing measurements than the `FillPointCloudMsg` hypothesis did:

| measurement | under this reading |
|---|---|
| `exp1b` fewer rays → better RTF | less compute → less contention |
| `exp7` `raySkips=1` → **+73%** | more compute → more contention (the note already said "saturates cores the sim/render threads need") |
| `Release` rebuild → 2x | compute finishes sooner → less contention |
| range, scene content → no effect | neither changes the amount of parallel work |

**It also makes a cheap prediction:** capping thread counts should improve RTF without
touching sonar code or rebuilding anything. That test has not been run.

**None of this is established.** It is one 10-second window, never reproduced, with an
unresolved RTF discrepancy attached — see below.

## The problem that has to be resolved first

**RTF was not recorded during the profile window.** The settle output showed +14,164
iterations per 15 s ≈ 944 steps/s. At a 1 ms step that implies RTF ≈ 0.94. The same build
measured **0.438** on this world.

That is a 2x discrepancy, and until it is explained this profile cannot be described as a
profile of the slow regime. Candidate explanations, none checked:

- the step size is not 1 ms for this world
- this run happened to be fast
- the sonar was live (it clearly was — `ComputeSonarImage` occupied a whole thread and
  OpenCV drawing was active) but in a cheaper phase

`exp8_profile.sh` now runs `rtf_probe.sh` concurrently over the same window, so the next run
answers this directly.

**The `FillPointCloudMsg` = 1% result survives the discrepancy** — that function is not the
bottleneck in either regime. What needs re-checking before being trusted is the
`swtch_pri`/contention picture, which is a claim about *why* the world is slow and therefore
depends on having profiled a slow window.

## Method notes and corrections

**The first summary was wrong and was thrown out.** `exp8_profile.sh` initially reported
`grep -c` counts. In `sample` output one line is one distinct call path and the weight is
the leading integer, so "`FillPointCloudMsg` 6" meant six paths, not six samples — the
weight was unknown. It also reported "heaviest stacks" with a regex that matched thread
header lines (all read 5,946, the per-thread sample total, which is what gave it away).
Both were replaced by `analyze_profile.py`.

**Idle threads must be excluded.** All 49 threads show 5,946 samples because `sample`
samples every thread whether or not it is running; 17 were entirely idle. Summing without
filtering measures sleep.

**Inclusive time initially included blocked time**, which is why `gz-sim` read 124% of busy.
`analyze_profile.py` now attributes only non-idle leaf samples to their ancestor chain.

**The pass/fail criteria were fixed in the script header before measuring**, precisely so
this could not be decided after seeing the numbers. The recorded third branch — "neither" —
is the one that came up.

## Caveats

- **One 10 s window, one run, and three attempts to repeat it failed** — not because the
  profile was hard to take, but because the sonar model stopped spawning at all. See
  [`../spawn_hang_2026-08-05/`](../spawn_hang_2026-08-05/). Until a second capture exists,
  the contention picture below (`swtch_pri` 49.3%, TBB 21.8%, DDS 16.1%) is **recorded, not
  concluded**. The `FillPointCloudMsg` = 1.0% result is the exception: it is a statement
  about which function is not the bottleneck, and does not depend on this being a
  representative window.
- Statistical profiler: 1 ms sampling, so short-lived work can be missed or over-weighted.
- `swtch_pri` being 40% is an observation, not a diagnosis. Which lock, and who contends
  for it, has not been determined.
- The RTF discrepancy above is unresolved.
- Mac / Apple M2 / Metal, `Release` build of `multibeam_sonar` and
  `multibeam_sonar_system` only (the other 12 DAVE packages are still unoptimised).

## Reproduce

```bash
source ~/dave_ws_lyrical/install/setup.zsh
bash notes/experiments/go.sh 8
# or re-analyse an existing capture:
python3 notes/experiments/analyze_profile.py /tmp/exp8_profile_*.txt
```
