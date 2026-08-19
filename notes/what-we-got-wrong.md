# What we got wrong, and how it was caught

Most of this repository states what is true. This page states what was believed and later
turned out not to be, because that is the part that says how much the rest can be trusted.

Every figure below was in the README or a results note at some point. None was a typo. Each
one looked right, was written down, and stood for days or weeks before something contradicted
it. The pattern in how they broke is more useful than any individual correction.

---

## The corrections

### A performance number measured from the wrong world

**Believed:** Docker ran `dave_multibeam_sonar` at RTF ~0.0018, roughly 123x worse than Mac.

**Actually:** the figure was sampled from `/world/oceans_waves/stats`. That is not this world —
`dave_multibeam_sonar.world` declares `<world name="default">`. Worse, a `dave_ocean_waves`
stability run was executing in the same container at the time, so the topic was real, was
publishing, and belonged to something else entirely.

**Caught by** trying to re-measure it and noticing the world name did not match.

The "123x Mac/Docker gap" was built on this one number and went with it. Two world files also
turned out to share the internal name `oceans_waves`, which is what made the mistake possible;
that is now an upstream issue report of its own.

### A 4.5x cost that was 1.90x

**Believed:** the sonar slows the simulation by about 4.5x.

**Actually:** 1.90x. Three separate things were wrong at once — the workspace was building with
no `-O` flag, the settle criterion was measuring the startup phase rather than the running
sensor, and single runs were being compared across conditions with 8% run-to-run spread.

**Caught by** re-running with `n≥2` per condition after fixing the other two, which is the only
reason the spread became visible at all.

### A four-minute livelock that was a startup window

**Believed:** `dave_multibeam_sonar` livelocks for 4+ minutes on launch.

**Actually:** for about 80 s after launch `/stats` publishes almost nothing, and the sonar
sensor is not live until roughly 145–175 s. Nothing is stuck. Any measurement taken inside that
window describes a world that is either not stepping or has no sonar in it.

**Caught by** mapping the startup phase continuously instead of sampling it.

### A readiness check that matched the plugin's own placeholder

**Believed:** the sonar was up, because the log line said so.

**Actually:** the plugin emits a dummy frame with `1 beams` before the real sensor initialises.
The check keyed on a substring that this dummy frame also satisfies. Measurements labelled
"sonar running" were of the startup window.

**This one bit twice.** It was found on 2026-08-03, fixed by keying on a different string — and
the replacement string was also present in the dummy frame. The second fix parses the beam count
and requires it to exceed 1.

### A crash that was our own test script

**Believed:** the long-duration stability test crashed, which looked like a real DAVE defect.

**Actually:** leftover processes from previous test runs. The cleanup function sent `TERM` and
returned without checking whether anything died.

**Caught by** a clean re-run after fixing cleanup in all four scripts.

The same defect invalidated a benchmark: the 2026-07-23 Mac/Docker comparison was found to have
run *before* the cleanup fix, and was downgraded to preliminary until re-measured.

### A GUI crash that never involved the GUI

**Believed:** the USBL demo crashed the Gazebo GUI client.

**Actually:** the **server** aborts with `SIGABRT`, and reproduces identically with `gui:=false`.
`UsblTransponder.cc` constructs a `std::normal_distribution` directly from the world file's
`<sigma>`, and the shipped `usbl_tutorial.world` sets `0.0`, which the C++ standard forbids.

**Caught by** running it headless, which should have been the first thing tried.

USBL then moved PASS → PARTIAL → PASS across three weeks as a *second*, unrelated bug surfaced:
the world loads paused unless `paused:=false` is passed, which silently blocks the plugin's
`rclcpp::spin_some()` and every ROS 2 subscription callback.

### Five hypotheses about the CPU cost, four of them wrong

**Believed, in order:** `FillPointCloudMsg` dominates; the spawn hang is double-sourcing; the
sensor is not loading; the SDF is corrupt; `UserCommands` is missing.

**Actually:** `FillPointCloudMsg` is 1.0% of CPU. The spawn hang is Fast DDS shared-memory
transport — with it on, spawning succeeded once in nine attempts; with `UDPv4`, five times in
five.

**Caught by** profiling the running process with `sample(1)` instead of inferring from RTF
deltas. Every hypothesis before that was reasoning about the code rather than watching it.

### A citation that pointed at the wrong paper

**Believed:** the sonar implements Choi et al. 2021 (Frontiers).

**Actually:** that paper describes the **raster-based** method. The entire subject of this
repository is the **ray-based** backend of PR #44, which is Choi 2025 (*Sensors*). Both papers
are real and distinct; the README listed only the older one.

**Caught by** checking whether both citations referred to the same work.

### Measurement tools that produced wrong numbers silently

Six defects were found in the measurement scripts, two of which had already corrupted results:

- `grep -c` counted call paths, not samples, in the first profile summary
- inclusive time included blocked time, so one process read 124% of busy CPU
- an RTF probe accepted `real +947 s` inside a 60-second window — which would have moved a mean
  from 0.814 to 0.556 and reversed the conclusion
- `timeout` without `-k` against a process that catches `SIGTERM`, hanging for 30+ minutes
- a topic list hard-coded for one vehicle, then a replacement regex that truncated at `/`,
  turning `camera/image` into `camera` — together inventing a missing topic and reporting it
- `assert_model_spawned` read "could not ask" as "not there"

None of these announced themselves. Each returned a number.

---

## What actually went wrong, four times over

**Measuring something that looks like the target.** The wrong world's topic, the dummy frame, the
startup window. In each case data arrived, on the right-looking topic, at the right-looking rate.
Liveness is not identity — a signal being present says nothing about what produced it.

**Tools that fail quietly.** Cleanup that never verified, a probe that accepted impossible values,
a timeout that could not kill its target. A tool that reports failure costs an hour. A tool that
reports a plausible wrong number costs a week, and takes the conclusions built on it.

**Reasoning about code instead of observing it.** Five hypotheses about where the CPU went, formed
by reading source and watching RTF. The first measurement retired four of them in one run.

**Configuration that does not appear in results.** The workspace built without optimisation for
a month. Nothing failed; every number was just quietly half what it should have been. This is
now the one thing the build scripts refuse to proceed without.

---

## What this changed about how the work is done

Conditions are repeated — `n≥2`, and the spread is reported next to the mean. A single run is
not a measurement.

Measurement scripts assert their preconditions and exit non-zero. `extras/build-*.sh` refuses
to finish if the sonar was compiled without `-O`.

Superseded results stay in the repository under their original names, marked `SUPERSEDED`,
`CONTAMINATED` or `PRE_LEAKFIX`. Deleting them would remove the only evidence of when a number
changed and why.

Claims carry the conditions they were measured under. Where something was not tested, the
documents say so rather than leaving it implied — the sonar's acoustic accuracy has never been
verified, and that sentence is in the README.
