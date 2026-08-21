# Upstream reports — prepared, awaiting submission

Eight GitHub issues and two documentation corrections. **None has been sent.** Each is ready to
review before submission, and the limits of what was confirmed at runtime are stated inside the
report itself — issue 8 combines runtime evidence for `noise_sigma` with source-only evidence
for `saturation` and the un-applied Gaussian noise, and distinguishes them explicitly.

**File one or two at a time rather than all eight at once.** Eight simultaneous issues from an
unfamiliar account reads as a dump; start with issue 7 and let its reception say how much
appetite there is for the rest.

Whoever files these needs only a GitHub account — [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave)
is public with Issues enabled. The `package.xml` fix would go as a fork-and-PR.

**Target repository:** `IOES-Lab/dave`, default branch **`ros2`** (not `main`).

## The eight issues

Ordered by suggested filing sequence — the first three are one-line fixes with measured
before/after, so they are the easiest for a maintainer to act on. The last two were added on
2026-08-21 after the pressure sensor was checked against a running simulation.

| # | File | What it reports | Fix size |
|---|---|---|---|
| 1 | [`vehicle-imu-topic.md`](vehicle-imu-topic.md) | No vehicle's IMU data reaches ROS. All four models omit `<topic>` on `imu_sensor`, so the bridged topic exists and stays silent. | One line per model |
| 2 | [`build-type.md`](build-type.md) | The documented build sets no `CMAKE_BUILD_TYPE`, so nothing is compiled with `-O`. `Release` doubles RTF. | One flag |
| 3 | [`updaterate.md`](updaterate.md) | `blueview_p900` asks for 30 Hz, which the sensor cannot reach and the hardware does not do. 2 Hz removes 75% of the sonar's cost. | One number |
| 4 | [`usbl.md`](usbl.md) | `UsblTransponder` aborts the Gazebo **server** on `<sigma>0.0</sigma>`, which the shipped demo world sets. | Input validation |
| 5 | [`world-name-collision.md`](world-name-collision.md) | Two world files declare the same `<world name>`, making their topics indistinguishable. Caused a real misattributed measurement here. | One attribute |
| 6 | [`docker-sonar-crash.md`](docker-sonar-crash.md) | `dave_multibeam_sonar` segfaults in `Ogre2GpuRays::CreateSampleTexture()` on Ubuntu 26.04 aarch64, where a stock `gpu_lidar` at the same ray count and angles does not. | Not identified |
| 7 | [`seapressure-unit.md`](seapressure-unit.md) | `SubseaPressureSensorPlugin` puts kPa into `sensor_msgs/FluidPressure`, which is defined in Pascals. Measured `101.325` at the surface where the message contract implies `101325`. | One multiplication |
| 8 | [`seapressure-dead-params.md`](seapressure-dead-params.md) | Same plugin: `<noise_sigma>` is ignored (**confirmed by changing it and seeing no change**), `saturation` is parsed and never used, and the Gaussian noise it documents is commented out — yet a non-zero `variance` is still published. | Docs, or three small additions |

**Order for these two:** both are ready, but file 7 first and wait for a response before
sending 8. They touch the same file, and two simultaneous issues from an unfamiliar account
against one plugin is more likely to be read as noise than as two findings.

Issue 8's `noise_sigma` claim was runtime-confirmed on 2026-08-21 by setting the tag to `0.123`
and observing `variance: 9.0` unchanged — `0.123²` would be `0.015129`. Its other two claims
(`saturation`, un-applied noise) remain source-only and say so. Data:
[`../../results/seapressure_unit_2026-08-21/`](../../results/seapressure_unit_2026-08-21/).

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

All linked paths were verified to exist and to be committed, so none will 404.
