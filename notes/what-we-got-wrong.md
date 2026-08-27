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

**A third mistake was hidden by a successful output check.** The Wiki used the generic sensor
launcher with `namespace:=usbl`. The world-embedded USBL plugins still published, so the command
looked valid, while the same launch log repeatedly said that `description/usbl/model.sdf` does not
exist. Directly checking output proved only the embedded world path, not that every action in the
launcher succeeded. Re-running the world-only launcher on both platforms removed the error.

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

### "Fixed" documentation that was still wrong, three reviews running

The DAVE documentation corrections were reported complete three times, and were incomplete all
three times. An outside reviewer caught it each time.

**First pass.** A warning callout was added to the top of each affected page — and the command
underneath it, the one a reader would actually copy, was left unchanged. A page that says "this
will fail" above a command that fails is not corrected.

**Second pass.** The commands were fixed. The tables were not: eight "Service name" rows still
listed the un-namespaced path, the camera page's Default Value column still carried the values
the prose above it had just retracted, and eighteen `(float)` annotations remained on fields the
`.srv` declares as `float64`. The parts that look like prose got attention; the parts that look
like reference data did not.

**Third pass.** Two of those eight rows were still unprefixed — the replacement string carried a
trailing newline that did not match. The tool reported success on all eight. Separately, a
before/after example had been "corrected" on both sides, so it now showed the same command twice,
and two build callouts contradicted the commands directly beneath them, which had already been
fixed in the pass before.

**How completion was claimed.** By grepping the source for `ros2 service call` and finding no old
paths. That search could not see table rows, because table rows do not contain `ros2 service
call`. The verification matched the shape of the fix rather than the scope of the problem — the
same failure this page documents under *measuring something that looks like the target*, arrived
at from a different direction.

What settled it was fetching the rendered page back and grepping *that*, which found the two
unprefixed rows immediately and distinguished them from the one example that is unprefixed on
purpose.

None of these announced themselves either. Each edit returned success.

### A link checker that could not see the thing it was checking

**Believed:** all relative links in the repository resolve. A commit message said so — "All 221
relative links resolve" — on the strength of a script run just before.

**Actually:** 38 were broken. When the README was split into separate files, links of the form
`../README.md#known-issues` were left pointing at headings that had moved out of that file. The
checker computed `target.split('#')[0]` and asked whether *that* existed. `../README.md` exists.
Every one of them passed.

**Caught by** an outside review that ran a checker which resolves the heading slug as well as the
path.

The script was not wrong about what it measured. It was measuring file existence and being
reported as link validity, and the gap between those two is exactly where the 38 lived. This is
the sixth entry on this page with that shape, and the second in two days.

### A "second confirmation" that confirmed nothing

The pressure sensor's unit error was measured properly: `fluid_pressure: 101.325` where the
Pascal-typed field implies `101325`. That part holds.

The same echo also carried `variance: 9.0`, and it was written up as a bonus finding — variance is
`noiseSigma²`, 9.0 is 3.0², therefore `noiseSigma` is at its compiled-in default of 3.0,
therefore the `<noise_sigma>` tag is being ignored. It was described in the results note as "a
second confirmation from the same run".

`rexrov/model.sdf:896` sets `<noise_sigma>3.0</noise_sigma>`. **The SDF value and the compiled-in
default are the same number.** An output of 9.0 is precisely what appears if the tag is read
correctly, and precisely what appears if it is ignored. The observation cannot separate the two,
and the reasoning had quietly assumed the conclusion it was offered as evidence for.

The underlying claim may well be true — `Configure()` has no branch for the element, which is
direct source evidence. But that is a different and weaker kind of evidence than a measurement,
and the draft had been written as though a live run backed it.

**This one was caught in review before anything was filed**, which is the first time in this list.

**And then the experiment was run.** The tag was set to `0.123`, the model relaunched, and
`variance` came back `9.0` — where `0.123²` is `0.015129`, about 595× away. The
claim was correct all along; what was wrong was the evidence offered for it. That distinction is
the whole point. A true conclusion supported by an observation that cannot discriminate is still
a reasoning error, and it fails the moment someone checks the reasoning rather than the
conclusion.

The fix cost one launch. Recognising it was needed cost a review round.

### A mechanism invented to explain a real symptom

**Believed:** the Ocean Current plugins failed to load because both packages' generated `.dsv`
hooks prepend `lib/<package>/` to `GZ_SIM_SYSTEM_PLUGIN_PATH` while CMake installs the dylibs
to `lib/`.

**Actually:** the symptom is real. The environment did carry `lib/<package>/`, the dylibs are in
`lib/`, the load failed with `Could not find shared library`, and adding the real directories
fixed it. The *mechanism* was not. No file under either package's install tree references
`GZ_SIM_SYSTEM_PLUGIN_PATH` at all, and the hooks those packages generate are
`cmake_prefix_path.dsv` and `dyld_library_path.dsv` — a different variable, pointing at `lib`.
Where the `lib/<package>/` entries come from is still unknown.

**Caught by** opening the two `.dsv` files instead of reasoning about what a hook of that name
would do.

**This is the first entry here that was flagged in review before the commit and went in anyway.**
The review note and the commit crossed; the sentence reached `origin/main` unchanged and was
corrected in a later commit. That the claim was wrong is half of it. The other half is that a
correction which is not applied before the commit is not a correction — it is a note.

The shape is familiar: a real observation, an explanation that fits it, and no check that the
explanation is the one operating. Several entries above have it. What is new is that the
explanation named a specific artefact — two files, by name — which could have been opened in one
command and never was.

### A whitespace check that could not see the files it was said to cover

**Believed:** `cae3a96` was committed with a message ending "UTF-8 clean, git diff --check clean".

**Actually:** `git diff --check` compares the working tree against the index. It was run before
anything was staged, when the 72 new evidence files were still untracked and therefore outside
its view. Once staged, `git diff --cached --check` reported two `new blank line at EOF` warnings,
and `git show --check cae3a96` reports them still. The check that was run was real and its result
was real; it simply did not cover what the sentence next to it claimed.

**Caught by** an outside review reading the commit message against the repository.

Two things are worth separating. The **warnings themselves are not a defect** — the two files are
raw `ros2 node info` and `ros2 topic info` output, and the trailing blank line is what the command
prints for an empty `Action Clients:` section. Deleting it to make the sentence true afterwards
would be editing evidence to fit a claim, which is the wrong direction, and it would not even
work: `git show --check cae3a96` would still flag the lines that commit added. So the correction
is to the sentence.

The review that caught it named `git diff --check` as the failing command; on a clean tree that
command passes and `git show --check` is what reports the warnings. **The same substitution
happened on both sides** — a checker named, and its scope quietly taken to be the scope of the
claim.

This is the seventh entry on this page with that shape and the second in three days, and it is the
first one where the rule being broken was already written down on this page. Knowing the failure
mode is not the same as running the check that would catch it. What would have caught this is one
sentence before committing: *this command compares the working tree to the index, and the files in
question are not in the index yet.*

### A publishing DVL topic that was promoted to a whole-plugin pass

**Believed:** DVL was a functional pass because an early run launched and published a real topic.

**Actually:** the evidence did not preserve the exact `world_name` or inspect range, velocity,
frame metadata, water-mass mode, bridge choice or the current Mac execution path. Direct testing
on 2026-08-26 found a narrower split verdict: the exact Wiki command and controlled bottom,
velocity and corrected water-mass paths pass in Docker, while four Mac controls crash, DAVE's
custom bridge loses `frame_id`, and the shipped water-mass tags do not name environmental
variables. The old observation was real; **the scope assigned to it was not**.

**Caught by** replaying the documentation rather than searching for an existing success line, then
asking separately what each message field and operating mode established. A topic is evidence of
publication, not of every mode exposed by the same sensor.

### A ten-condition matrix whose conditions were not isolated

**Believed:** the first SeaPressure full-matrix runner had tested each SDF parameter independently.

**Actually:** it relied on process-name cleanup that did not stop the previous Gazebo world, so
models accumulated in an old server. It also copied a base plugin block and appended overrides,
creating duplicate `kPa_per_meter` and `estimate_depth_on` elements. The script produced plausible
JSON for every named condition, but neither the running world nor the generated SDF matched the
isolation claim.

**Caught by** reading the generated test assets and enumerating live worlds rather than accepting
the runner's exit codes. The excluded attempt remains under
[`results/seapressure_full_validation_2026-08-26/invalid_duplicate_tag_and_cleanup_attempt/`](results/seapressure_full_validation_2026-08-26/invalid_duplicate_tag_and_cleanup_attempt/).
The corrected runner starts one tracked server with a unique world name, gives every probe a unique
namespace, emits each tested tag at most once, and validates all ten result JSON files independently.

This is the same scope error in test-fixture form: ten result files do not prove ten independent
conditions unless the fixture proves what was loaded and what was varied.

### A coordinate example that was trusted without reversing it

**Believed:** the Spherical Coordinates Wiki's response for local `(100,200,3)` was a usable
numeric example because its fields and general transform flow matched the source.

**Actually:** after setting the exact Wiki origin, the runtime result has the opposite latitude
and longitude direction from the documented value. Feeding the documented spherical triple into
the inverse service returns approximately `(-100,-200,3)`, not `(100,200,3)`. The current example
world's initial origin has also changed since the page's older North Sea value.

**Caught by** treating a documented numeric response as a test vector and running it in both
directions on Mac and Docker. Three independent finite round-trip points passed at sub-nanometre
axis error, so the positive transform path and the bad example can be stated separately. A
round-trip checks internal consistency; it still does not establish independent geodesic accuracy.

---

## What actually went wrong, five times over

**Measuring something that looks like the target.** The wrong world's topic, the dummy frame, the
startup window, the `variance: 9.0` that matched under either hypothesis. In each case data
arrived, on the right-looking topic, at the right-looking rate, carrying the expected value.
Liveness is not identity — a signal being present says nothing about what produced it, and a
number matching a prediction says nothing when the competing explanation predicts it too.

**Tools that fail quietly.** Cleanup that never verified, a probe that accepted impossible values,
a timeout that could not kill its target. A tool that reports failure costs an hour. A tool that
reports a plausible wrong number costs a week, and takes the conclusions built on it.

**Reasoning about code instead of observing it.** Five hypotheses about where the CPU went, formed
by reading source and watching RTF. The first measurement retired four of them in one run.

**Configuration that does not appear in results.** The workspace built without optimisation for
a month. Nothing failed; the sonar numbers were just quietly about half what they should have
been — measured on one world at one configuration, n=1, so the scope of the 2.01x is that result
and not every package. This is now the one thing the build scripts refuse to proceed without.

**A tool reporting success, taken as evidence the change happened.** An edit API returns success
when the call was well-formed, not when the document ended up the way it was meant to. Three
rounds of documentation fixes were declared complete on that basis. The only thing that settles
it is reading the artefact back — the rendered page, the built binary, the published topic — and
checking it against the whole of what was claimed, not against the part that was easy to search
for.

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
documents say so rather than leaving it implied. General sonar acoustic accuracy remains
unverified; one controlled planar test now establishes a narrower result — CPU range localisation
passed while WGPU raw-sonar localisation failed in that scene.

Edits are verified by reading the result back, not by the editing tool's return value, and the
check has to cover everything the claim covers. A checker that passes is evidence only for the
property it actually tests — before quoting one, say out loud what it measures and compare that
sentence to the claim being made. "All eight rows fixed" is verified by counting
eight rows in the fetched page, not by searching for the phrase that appeared in the two rows
that were easy to find.

Before a measurement is called evidence for a claim, the competing explanation is asked what it
predicts. If it predicts the same number, the measurement is not evidence — it is a coincidence
that happens to be consistent. `variance: 9.0` at the shipped setting failed this test and nearly
went upstream; `variance: 9.0` with the tag set to `0.123` passes it, because the alternative
predicts `0.015129`. Same number, same topic, same command — one discriminates and one does not,
and the difference is entirely in what else was varied.

Reports state which of their claims are measured and which are read from source, per claim rather
than per document. The two are not interchangeable, and a reader deciding whether to act on a
report needs to know which one they are being handed.

## 2026-08-27 — `source-only`는 영구 판정이 아니다

`bluerov2_heavy_multibeam_sonar`를 2026-08-21에 소스로만 읽고 "네 대 runtime + 한 대
source-only"라고 정확히 범위를 적었지만, 그 상태를 최종 판정처럼 오래 두면 별도의 runtime
결함을 볼 수 없다. 2026-08-27에 처음 양쪽 플랫폼에서 띄워 보니 IMU omission은 재현됐고,
동시에 선언된 sonar PointCloud2도 120초 동안 발행되지 않았다. 소스 감사는 이미 아는 실패를
설명했지만, 실행은 **다른 실패가 함께 있는지**를 보여줬다. 따라서 source-only 항목에는
"읽음" 표시뿐 아니라 후속 runtime test가 명시돼야 하고, 실행 뒤에는 모든 현재 문서에서
그 표시를 제거하거나 날짜 붙은 역사로 바꿔야 한다.
