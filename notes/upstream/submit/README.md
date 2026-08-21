# Upstream reports — prepared, awaiting submission

Eight GitHub issues and two documentation corrections, all written and verified. **None has
been sent.** Everything here is ready to paste; nothing needs further testing.

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
| 8 | [`seapressure-dead-params.md`](seapressure-dead-params.md) | Same plugin: `noise_sigma` is never parsed, `saturation` is parsed and never used, and the Gaussian noise it documents is commented out — yet a non-zero `variance` is still published. | Docs, or three small additions |

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
