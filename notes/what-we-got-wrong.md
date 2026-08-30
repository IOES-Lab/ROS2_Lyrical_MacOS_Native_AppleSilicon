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

The "123x Mac/Docker gap" was built on this one number and went with it. We first documented
only two files sharing `oceans_waves`. A complete 18-file audit on 2026-08-27 found that the
correction itself was too narrow: seven files occupy three duplicate-name groups
(`oceans_waves`, `default`, `dvl_world`). The upstream draft now reports the full inventory.
The lesson is the same as the original failure: checking only the names already suspected is
not evidence that the rest are unique.

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
axis error, so the positive transform path and the bad example can be stated separately. At that
stage a round-trip checked only internal consistency and did not establish independent geodesic
accuracy. The later 2026-08-28 WGS-84/ECEF/ENU oracle closed that specific gap with 13 points
across four geographic cases; invalid-input handling and packaging remain separate problems.

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

## 2026-08-27 — `6/6`의 분모가 actuator를 포함한다고 잘못 읽었다

**Believed:** Glider의 `6/6 FUNCTIONAL`이 battery·thruster·NavSat·odometry·pose·IMU를
직접 확인했다는 뜻이었다.

**Actually:** 그 결과를 만든 `exp12_vehicles.sh`의 topic extractor 마지막 줄은
`grep -v '^joint'`였다. `cmd_thrust`, `ang_vel`, `enable_deadband` 세 경로는 검사 대상에서
의도적으로 빠졌고, 여섯은 battery·NavSat·odometry·odometry-with-covariance·pose·IMU였다.
브리지 생성 로그에 joint topic이 보였다는 사실을 메시지·명령 검증과 합쳐 읽었다.

**Caught by** 2026-08-27에 `robot_config.py`의 9개 항목을 먼저 분모로 고정하고, state/sensor
6개와 joint 3개를 별도 시험한 것이다. `cmd_thrust`는 실제 ROS→Gazebo 전달과 `ang_vel`
변화를 확인했지만 `enable_deadband`는 integrated ROS→Gazebo가 아직 미확정이다. 앞으로
`N/N`은 포함된 항목 목록 또는 추출식을 함께 인용하며, config에 있는 항목 수와 test가 만든
분모를 먼저 대조한다.

## 2026-08-27 — `Object Model Uploaded`를 entity 존재 증거로 쓸 수 없다

**Believed:** `ros_gz_sim create`의 `Entity creation successful`, exit 0, 이어지는
`Object Model Uploaded`면 object가 world에 추가된 것이다.

**Actually:** 존재하지 않는 `description/definitely_missing_object/model.sdf`를 요청한
통제에서 Gazebo server는 `Error finding file`과 `Unable to read file`을 기록했고 model
list에도 entity가 없었다. 그런데 create client는 성공 문구와 exit 0을 냈고,
`upload_object.launch.py`의 `OnProcessExit`는 exit 결과를 검사하지 않은 채 성공 로그를
출력했다.

**Caught by** 성공 로그가 아니라 server error와 실행 후 `gz model --list`를 함께 읽은
것이다. process 종료·exit 0·성공 문자열은 각각 entity 존재와 다른 속성이다. spawn 검증은
요청 전후 model/entity 목록 또는 실제 topic/pose를 확인해야 하며, 실패 통제 하나를 넣어
성공 판정기가 실패도 성공으로 분류하지 않는지 먼저 확인한다.

## 2026-08-28 — one-shot timeout을 양방향 결함으로 올렸다

Glider integrated `enable_deadband`에서 ROS publisher가 성공하고 Gazebo echo가 한 번 timeout된
것을 비대칭 bridge 결함으로 기록했다. 동일 경로를 반복 송신하자 ROS `true` 50개가 Gazebo
`true` 50개로 관측되고 false는 0개였다. 한 번의 subscriber timing 결과는 메시지 경로의
부재와 구별되지 않는다. 앞으로 양방향 bridge 부재를 주장하려면 subscriber discovery 뒤
반복 송신·반복 관측과 양성 대조를 함께 둔다.

## 2026-08-28 — hook attribution을 좁은 검색으로 잘못 철회했다

Ocean/Spherical의 nested `GZ_SIM_SYSTEM_PLUGIN_PATH`를 package hook 탓이라고 했다가 install
tree 검색에서 문자열을 못 찾아 “지원되지 않는 추정”으로 철회했다. 그러나 source package의
`.dsv.in`을 포함해 검색하자 두 package가 정확히 `lib/@PROJECT_NAME@/`을 prepend했고, clean
layered environment도 DAVE setup 뒤 그 nested 경로를 만들었다. 실제 dylib는 plain `lib/`에
있다. “설치 트리 한 위치에 문자열이 없다”는 검사는 환경 항목의 출처 전체를 부정하지 못한다.
환경 변수 provenance는 clean shell에서 setup layer별 값을 읽고 source hook·generated hook·
실제 install destination을 함께 대조해야 한다.


## 2026-08-29 — 결함 목록을 현재 판정처럼 읽었다

`known-issues.md`는 실패 발견 시점의 근거를 보존하는 감사 이력인데, 후보 패치를 검증한 뒤에도
루트 README·matrix·next-steps가 그 문장을 현재형으로 반복했다. 코드를 고친 것과 판정 전파는
별개이며, 후자를 하지 않으면 사용자는 이미 닫힌 재현 가능 결함과 외부 blocker를 구분할 수 없다.

이번에는 각 항목을 (1) 후보 패치로 재현 실패가 사라진 것, (2) stock Gazebo·외부 패키지·하드웨어
때문에 남은 것, (3) 일반 과학 정확도로 나눴다. 단, 로컬 후보 패치의 PASS를 upstream 반영으로
쓰지 않았다. 앞으로 결함 수정의 완료 조건에는 원인 통제, 양 플랫폼 가능 범위, patch-apply 검사,
현재 문서 전파와 "아직 주장하지 않는 것" 목록을 함께 둔다.

## 2026-08-29 — 패치가 통과한 입력 범위를 구현 경계 전체로 늘려 쓴 다음, 예전 판정을 다른 문서에 남겼다

**Believed:** 평면 타겟의 319-bin WGPU 장면과 패치 적용 검사가 통과했으므로
non-power-of-two 처리와 후속 문서 전파도 끝났다.

**Actually:** shader의 workgroup array는 4096개인데 host는 `next_power_of_two().min(4096)`만
사용했다. `n_freq > 4096`에서는 exact-DFT branch가 고정 array 밖을 index할 수 있었다.
동시에 source guide는 아직 zero-padded `fft_len` buffer를 설명했고,
`cmake-migration-patterns.md`·`verified-demos.md`·matrix는 2026-08-29 launch 후보 패치 전의
`gui:=false` 판정을 현재형으로 남겼다.

**Caught by** 실행한 319-bin 통제가 아니라 shader storage 한계에서 입력 도메인을 역으로
계산하고, 후보 패치가 건드린 원본 guide와 현재 판정 문서를 따로 검색한 것이다. host·shader
양쪽에 4096-bin guard를 두고, GPU 초기화 전에 4097-bin이 null을 반환하는 unit test를
추가했다. 앞으로 특정 크기의 PASS를 크기 전체의 PASS로 올리지 않고, 패치 완료 시 코드
주석·원본 guide·현재 verdict를 별도 전파 목록으로 검사한다.

## 2026-08-29 — “not in the sourced environment” was reported as “not in the image”

The 2026-08-27 BlueROV2 run correctly showed that `mavros` and `mavros_msgs` were absent from
that shell's package index, but the current write-up expanded that observation to the container.
The container actually had `/home/docker/mavros_ws/install`; sourcing it started ArduSub and MAVROS
and opened their TCP endpoint. At that intermediate audit point the remaining failure appeared
different: the ArduPilot Gazebo system plugin was absent, MAVROS stayed disconnected, and
QGroundControl SIGSEGVed. The later same-day section below supersedes that as the final boundary.

The same sweep found a second scope error: the fifth ROV's declared sonar was called “unexplained”
after reading only its model and bridge. The selected **world** did not load
`MultibeamSonarSystem`; adding that system made a 513×301 PointCloud appear. For plugin-driven
sensors, the audit boundary is model + bridge + world systems + sourced overlays, not any one file.

## 2026-08-29 — an observed missing prerequisite was treated as a final external boundary

**Believed:** after sourcing MAVROS, the remaining BlueROV2 stack was blocked externally because
`libArduPilotPlugin.so` was absent and QGroundControl crashed.

**Actually:** both observations were real, but neither established that the prerequisite could not
be supplied locally. The official ArduPilot Gazebo repository builds on the tested arm64/Jetty
image. QGroundControl's own AppRun has a supported `QGC_NO_SYSTEM_GLIB=1` opt-out that avoids the
observed default crash. Once the plugin delivered JSON, a new, deeper ArduSub `SIGFPE` appeared;
GDB and source inspection then exposed the invalid default speedup boundary, and an explicit
`--speedup 1` candidate allowed the integrated control loop to run.

**Lesson:** “component absent in this image” and “component unavailable to this project” are
separate claims. Before marking an executable gap external, identify the authoritative provider,
try the supported build or wrapper controls in isolation, then rerun the full chain. Each newly
unblocked layer can expose the next failure; a successful process start is still not an end-to-end
PASS.

## 2026-08-30 — 수동 종료한 결합 시험을 최종 실패 상태처럼 요약했다

**Believed:** Heavy-multibeam 결합 실행에서 stack trace와 JSON starvation을 봤으므로 결합
경로의 실패 판정과 원인 범위가 충분히 닫혔다.

**Actually:** 그 실행은 수동 cleanup으로 끝나 final signal·exit code가 없었고, auto backend와
CPU backend도 분리하지 않았다. 현재 재실행은 auto WGPU가 software `llvmpipe`를 선택한 뒤
OGRE2 sample-texture/null-`memcpy` stack과 Gazebo exit 139를 보존했다. 같은 derived candidate를
forced CPU로 실행하면 513×301 PointCloud2, MAVROS MANUAL arm, 100 control messages, X
+1.348464 m 이동과 disarm이 한 session에서 통과한다. 따라서 결합 결과는 전체 FAIL이 아니라
**backend-dependent**다.

**Lesson:** crash를 기록할 때는 마지막 exit status까지 보존하고, 자동 선택된 backend를
명시적 양성 대조와 분리한다. 중간 증상만으로 종료 결과나 다른 backend까지 확대하지 않는다.

## 2026-08-30 — 창 진단기가 splash와 main window를 한 판정으로 합쳤다

RViz 창 검사의 첫 버전은 `onscreen=true`인 splash와 `onscreen=false`인 main window를 합쳐
"창이 있다"고 읽을 수 있었다. CoreGraphics layer별 window number·size·onscreen 상태와
Accessibility window count를 분리하자 main 640×508 layer는 계속 offscreen이고 AX window는
0개였다. plain Qt controls는 같은 환경에서 onscreen이므로 일반 Qt 또는 macOS 창 생성 실패로
확대할 수 없다. 앞으로 GUI 판정은 process·native window·onscreen framebuffer·실제 내용
렌더링을 별도 속성으로 기록한다.
