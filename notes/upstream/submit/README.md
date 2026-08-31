# Upstream reports — one issue and one signed PR filed; the rest awaiting decisions

Eleven GitHub issue records and two documentation corrections. **The bridge-lifecycle report is [gazebosim/ros_gz#951](https://github.com/gazebosim/ros_gz/issues/951), and its signed fix is open as [PR #952](https://github.com/gazebosim/ros_gz/pull/952); DCO passes and maintainer review/merge is pending. The other ten reports have not been sent.** Draft 6 is a
historical do-not-file record; drafts 9 and 10 are new sonar reports that deliberately separate a
range-grid defect from a backend-startup-order candidate. Draft 11 is a separate `gazebosim/ros_gz`
bridge-lifecycle report. The limits of what was confirmed at
runtime are stated inside each report — issue 8 has cross-platform runtime evidence for
`noise_sigma`, `saturation` and `update_rate`, plus source evidence for the un-applied Gaussian
noise, and distinguishes them.

**File one or two at a time rather than all ten at once.** Multiple simultaneous issues from an
unfamiliar account reads as a dump; start with issue 7 and let its reception say how much
appetite there is for the rest.

Whoever files these needs only a GitHub account — [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave)
is public with Issues enabled. The `package.xml` fix would go as a fork-and-PR.

**Filing is a person's decision, not an automatic next step.** `IOES-Lab/dave` is not ours to
write to; these drafts exist so that whoever does file them has the evidence ready. The ordering
suggestions below are notes for that person. See [`CLAUDE.md`](../../../CLAUDE.md).

**Target repository:** `IOES-Lab/dave`, default branch **`ros2`** (not `main`).

## The eleven drafts

**Issue numbers reflect draft creation order, not filing order.** Draft 11 has been filed independently against `gazebosim/ros_gz`. For the remaining DAVE reports, the recommended first submission
is issue 7, then issue 8 after maintainer feedback.  Review drafts 9 and 10 as independent change
units; neither should be combined with the other.  Within the older six, the first three are
one-line fixes with measured
before/after, so they are the easiest for a maintainer to act on. The last two were added on
2026-08-21 after the pressure sensor was checked against a running simulation.

| # | File | What it reports | Fix size |
|---|---|---|---|
| 1 | [`vehicle-imu-topic.md`](vehicle-imu-topic.md) | Four base models omit `<topic>` on `imu_sensor`, so the bridged topic exists and stays silent — measured before/after. A later exact-image audit also kept all three BlueROV short ROS IMU/magnetometer paths silent while camera, odometry and each default long Gazebo IMU path published. The fifth fixed form was not rerun. | One line per model |
| 2 | [`build-type.md`](build-type.md) | The documented build sets no `CMAKE_BUILD_TYPE`, so nothing is compiled with `-O`. `Release` doubles RTF. | One flag |
| 3 | [`updaterate.md`](updaterate.md) | `blueview_p900` asks for 30 Hz, which the sensor cannot reach and the hardware does not do. 2 Hz removes 75% of the sonar's cost. | One number |
| 4 | [`usbl.md`](usbl.md) | `UsblTransponder` aborts the Gazebo **server** on `<sigma>0.0</sigma>`, which the shipped demo world sets. | Input validation |
| 5 | [`world-name-collision.md`](world-name-collision.md) | Seven of 18 world files occupy three duplicate `<world name>` groups, making their topic namespaces ambiguous. One collision contributed to a real misattributed measurement here. | Seven attributes, with namespace migration |
| 6 | [`docker-sonar-crash.md`](docker-sonar-crash.md) | **HISTORICAL DRAFT — do not file as-is.** The 2026-08-03 crash was real, but a 2026-08-29 isolated OGRE2 DAVE-sonar run published PointCloud; a new reproducer/version delta is required. | Reproducer first |
| 7 | [`seapressure-unit.md`](seapressure-unit.md) | `SubseaPressureSensorPlugin` puts kPa into `sensor_msgs/FluidPressure`, which is defined in Pascals. Cross-platform controlled values were `101.325` at the surface and `199.3888` at `|z|=10 m`. | One multiplication |
| 8 | [`seapressure-dead-params.md`](seapressure-dead-params.md) | Same plugin: `<noise_sigma>`, `saturation` and `<update_rate>` do not affect their documented output properties in Mac and Docker controls; Gaussian noise is commented out while non-zero `variance` is published. | Docs, or three small additions |
| 9 | [`multibeam-wgpu-range-grid.md`](multibeam-wgpu-range-grid.md) | The 399-bin WGPU input is zero-padded to 512 but published on the original range vector, shifting synthetic target peaks.  An exact-N discriminator restores localisation in six scenes but is too slow on software `llvmpipe` as a production fix. | Efficient arbitrary-N transform or explicit CPU fallback |
| 10 | [`multibeam-deferred-backend-startup.md`](multibeam-deferred-backend-startup.md) | Deferring WGPU creation to the existing compute thread gives 20/20 `llvmpipe` cold starts, 3/3 Heavy controls and a bounded 30-minute payload soak. Its historical bridge shutdown `-11` is now separated into draft 11; hardware-GPU validation remains external. | Backend lifecycle; review node-parameter suppression separately |
| 11 | [`parameter-bridge-handle-cycle.md`](parameter-bridge-handle-cycle.md) · [filed #951](https://github.com/gazebosim/ros_gz/issues/951) · [PR #952](https://github.com/gazebosim/ros_gz/pull/952) | `RosGzBridge` and `BridgeHandle` form a strong owner cycle. The signed weak-back-reference PR is installed and exhaustively generated-mapping-tested in the actual user workspace: 73/73 payloads each direction and ordered bridge rc0. Separate `bridge_node`/test-helper teardown remains outside the PR scope. | Four small source files; maintainer ownership/lifecycle review |

**Order for these two:** both are ready, but file 7 first and wait for a response before
sending 8. They touch the same file, and two simultaneous issues from an unfamiliar account
against one plugin is more likely to be read as noise than as two findings.

Issue 8 was expanded on 2026-08-26 with a ten-condition Mac/Docker matrix. `noise_sigma=0.123`
left variance at `9.0`; `saturation=50` did not clamp `199.3888`; and `update_rate=2` still
published at about `0.001 s` intervals. The un-applied Gaussian-noise line remains a source-level
claim. Data:
[`../../results/seapressure_full_validation_2026-08-26/`](../../results/seapressure_full_validation_2026-08-26/).

**Both were cross-checked against the `ros2` default branch (`cc98a539`) on 2026-08-21** — every
finding is present there, so neither is an artefact of the fork they were measured in.

Each file has the issue **title** on its own line and the **body** below it. The comment
block at the top holds the suggested target and labels; it is invisible when pasted.

## Two documents that are not issues

- [`../ogre-x-display-doc-correction.md`](../../wiki/ogre-x-display-doc-correction.md) — the
  `ogre2` → `ogre` workaround needs an X display, and needs the right user plus
  `XAUTHORITY`, not just `DISPLAY`. **Not a bug** — the workaround works; the instructions
  are incomplete in a way that makes a working setup look broken.
- [`../wiki-error-report-final-EN.md`](../../wiki/wiki-error-report-final-EN.md) — corrections found
  while reading all 20 pages of the DAVE ROS 2 documentation. **The X-display correction
  above should be added to this before sending.**

The documentation lives at [dave-ros2.notion.site](http://dave-ros2.notion.site) — a Notion
site, not a GitHub wiki — so delivery is a Notion comment or a message to whoever maintains
it, not a pull request.

## One more, already prepared

[`../../patches/`](../../../patches/) holds the verified patches. The `package.xml` dependency
fix (7 `<depend>` tags, resolving a parallel-build race) is ready to go as a PR and is
independent of ROS distro.

## Regenerating

These files are generated. **Edit the drafts in `notes/`, not these.**

```bash
python3 notes/upstream/make_submittable.py
```

The script strips our status/target/label notes into an HTML comment, separates the title,
and rewrites every relative link to an absolute URL — without that last step the links break
when pasted into another repository's tracker. It re-checks that no relative links survive.

Link checking covers anchors as well as paths — an earlier checker compared only the part
before `#`, so 38 links pointing at headings that no longer exist passed it. The check that
matters resolves the target file *and* the heading slug inside it.
