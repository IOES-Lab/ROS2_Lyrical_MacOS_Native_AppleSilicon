# SeaPressure: a Pascal-field unit error and an ignored `noise_sigma`, both confirmed at runtime

**2026-08-21** · macOS / Apple M2 / Metal · ROS 2 Lyrical + Gazebo Jetty 10.4.0 · headless

The unit mismatch was found by reading `sea_pressure_sensor.cc`. This run confirms it against a
live system, which is what the upstream report needed.

## What was run

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov \
  world_name:=dave_ocean_waves \
  paused:=false headless:=true \
  debug:=true verbose:=4 \
  use_teleop:=false use_web_joystick:=false
```

`headless:=true` is load-bearing. A default GUI launch of the same world exits `-6` on this
machine, so the headless flag is not a convenience — it is the difference between a run and no
run, and any reproduction that omits it is not the procedure that produced this measurement.

Gazebo started, REXROV uploaded, the SeaPressure plugin loaded, `PostUpdate` ran for about two
minutes, and the process exited cleanly.

```
[INFO] [gazebo-1]: process started with pid [22511]
[INFO] [launch.user]: Robot Model Uploaded
[INFO] [gazebo-1]: process has finished cleanly [pid 22511]
```

## Output

```
$ ros2 topic echo /model/rexrov/sea_pressure --once
fluid_pressure: 101.32505915145917
variance: 9.0
```

The message type was **not** captured in this first session — an earlier version of this note
showed a `ros2 topic type` invocation here as though it had been, which it had not. It was
captured in the discriminating run below, whose output begins with the line
`sensor_msgs/msg/FluidPressure`. The type is now confirmed from the CLI rather than only from
`create_publisher<sensor_msgs::msg::FluidPressure>` in the source.

## What it establishes

**The 1000x factor is real, not inferred.** At `z:=0` the field reads `101.325`.
`sensor_msgs/msg/FluidPressure` specifies Pascals — the definition reads
`float64 fluid_pressure       # Absolute pressure reading in Pascals.` — so a consumer following
it expects `101325`. The plugin's internals are kPa-based throughout (`standardPressure = 101.325`,
`kPaPerM = 9.80638`) and the value is assigned without conversion.

That is the whole of what this run establishes.

**Cross-checked upstream on 2026-08-21.** `IOES-Lab/dave`'s `ros2` default branch (`cc98a539`)
carries the same unconverted assignment, the same absent `noise_sigma` branch in `Configure()`,
the same unused `saturation`, and the same commented-out noise. None of this is fork-specific, so
the reports do not need a "may differ on the default branch" hedge.

**What the message says about `variance` matters here too:** the same definition reads
`float64 variance             # 0 is interpreted as variance unknown`. So "publish 0 because
there is no noise" is not the obvious fix it looked like — `0` asserts *unknown*, not *noiseless*.
That is why the variance question was split out of the unit report entirely.

## What `variance: 9.0` does NOT establish — a correction

**This note originally claimed that `variance: 9.0` independently confirmed `noiseSigma` sits at
its compiled-in default of 3.0, and therefore that `<noise_sigma>` is never parsed. That was
wrong, and it was caught in review before the report was filed.**

`rexrov/model.sdf:896` contains:

```xml
<noise_sigma>3.0</noise_sigma>
```

The SDF value and the compiled-in default are **the same number**. So `variance: 9.0` is exactly
what you would see if the tag were being read correctly, and exactly what you would see if it
were being ignored. The observation cannot tell the two apart, and calling it a "second
confirmation from the same run" was reading a conclusion into data that does not carry it.

What the run does show is that the **effective** `noiseSigma` is 3.0. Whether that came from the
SDF or from the default is not determined here. The claim that `Configure()` never parses the
element stands on reading `Configure()` and finding no branch for it — source evidence, which is
direct, but not runtime evidence.

**The discriminating experiment has since been run, and it settles the question — see the next
section.** What follows above stands as the record of why the first attempt did not.

This is the same failure this project has now recorded five times — a signal that resembles the
target being accepted as the target. It is written up in
[`../../what-we-got-wrong.md`](../../what-we-got-wrong.md). It is also the first one caught before
publication, and the first to be closed by running the experiment rather than by weakening the
claim.

## The discriminating run — `<noise_sigma>0.123</noise_sigma>`

```
Test input:            <noise_sigma>0.123</noise_sigma>   (rexrov/model.sdf:896)
Expected if applied:   variance = 0.015129                (0.123²)
Expected if ignored:   variance = 9.0                     (3.0², the compiled-in default)
Observed:              variance = 9.0
Conclusion:            the SDF value is ignored; the compiled-in default 3.0 remains active
Restored after test:   <noise_sigma>3.0</noise_sigma>     (verified by grep; backup removed)
```

Full output, saved as [`noise_sigma_0p123.txt`](noise_sigma_0p123.txt):

```
$ ros2 topic type /model/rexrov/sea_pressure
sensor_msgs/msg/FluidPressure

$ ros2 topic echo /model/rexrov/sea_pressure --once
header:
  stamp:
    sec: 0
    nanosec: 2000000
  frame_id: ''
fluid_pressure: 101.32505915145917
variance: 9.0
---
```

**`<noise_sigma>` is now confirmed ignored at runtime.** The two hypotheses predicted values three
orders of magnitude apart — 0.015129 against 9.0 — so unlike the first run, this one discriminates.
The finding no longer rests on the absence of a parsing branch in `Configure()`; that reading now
has a measurement behind it.

**Two things came free with it.** `ros2 topic type` was captured this time, closing the gap noted
above. And `fluid_pressure` reads `101.32505915145917` — **bit-identical to the first run**, which
is consistent with the reading being deterministic, as it must be if the Gaussian noise is never
applied. That is corroboration, not proof: two identical readings at the same depth would also
appear if noise were applied with a fixed seed. The commented-out line remains the actual
evidence.

**Still source-only:** `saturation` and the un-applied Gaussian noise. Neither was tested by
setting a value and observing no effect, and this run says nothing about either.

### Procedure

Kept for reproduction. This is what was run.

Terminal 1 — back up the model, change the tag, launch:

```bash
source ~/ros2_lyrical/.venv/bin/activate
source ~/ros2_lyrical/install/setup.zsh
source ~/ros_gz_ws_lyrical/install/local_setup.zsh
source ~/dave_ws_lyrical/install/local_setup.zsh

MODEL=~/dave_ws_lyrical/src/dave/models/dave_robot_models/description/rexrov/model.sdf
cp "$MODEL" "$MODEL.noise-test.bak"

python3 -c 'from pathlib import Path; p=Path.home()/"dave_ws_lyrical/src/dave/models/dave_robot_models/description/rexrov/model.sdf"; s=p.read_text(); assert s.count("<noise_sigma>3.0</noise_sigma>")==1; p.write_text(s.replace("<noise_sigma>3.0</noise_sigma>", "<noise_sigma>0.123</noise_sigma>"))'

grep -n noise_sigma "$MODEL"

ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov \
  world_name:=dave_ocean_waves \
  paused:=false headless:=true \
  debug:=true verbose:=4 \
  use_teleop:=false use_web_joystick:=false
```

The `assert` on the count is the point of using Python rather than `sed` — if the file ever gains
a second `noise_sigma` tag, a blind replace would silently change both and the test would still
appear to work.

Terminal 2:

```bash
source ~/ros2_lyrical/.venv/bin/activate
source ~/ros2_lyrical/install/setup.zsh
source ~/ros_gz_ws_lyrical/install/local_setup.zsh
source ~/dave_ws_lyrical/install/local_setup.zsh

ros2 topic type /model/rexrov/sea_pressure
ros2 topic echo /model/rexrov/sea_pressure --once
```

| Reading | Would mean | Actual |
|---|---|---|
| `variance: 9.0` | the tag is ignored | **← observed** |
| `variance: 0.015129` | the tag *is* applied (`0.123²`), source-based claim wrong | not observed |

Restore afterwards — `Ctrl+C` in terminal 1, then:

```bash
MODEL=~/dave_ws_lyrical/src/dave/models/dave_robot_models/description/rexrov/model.sdf
mv "$MODEL.noise-test.bak" "$MODEL"
grep -n noise_sigma "$MODEL"
```

## Other limits

- **Only the surface value was measured**, at `z:=0`, in one run. Scaling at depth follows from
  the same code path but was not measured at several depths.
- **`sea_pressure_depth` was not checked numerically.** It divides by the same `kPaPerM`, so on
  dimensional grounds the units should cancel — but that is reasoning about the code, not a
  comparison against a known depth.
- **Only the ROS message was examined.** The Pascal convention cited is
  `sensor_msgs/msg/FluidPressure`'s. No `fluid_pressure.proto` could be located on this system at
  all, so nothing is known here about what `gz::msgs::FluidPressure` declares — an earlier
  version of this note said the definition "carries no unit comment", which overstated a failed
  search as an inspection.
- **Single platform.** Two runs on the same machine: the baseline and the `0.123` discriminator.
- **`saturation` and the un-applied noise remain source-only.** The `0.123` test covers
  `noise_sigma` and nothing else.

## Separate observation, not part of this finding

The GUI launch's `-6` exit is a rendering-side failure. It is recorded here because it explains
why `headless:=true` is in the command, not because it bears on the units. Kept apart
deliberately so the unit report does not carry an unexplained crash with it.

## Environment

Local `lyrical-jetty-migration` workspace built on `naitikpahwa18/dave` commit `6aef91c` — the
same commit as that fork's `wgpu_integration` head at the time of checkout, which is why earlier
notes named the branch instead. The branch name in this workspace is `lyrical-jetty-migration`.

## Reports written from this

- [`../../upstream/drafts/seapressure-unit-issue-draft.md`](../../upstream/drafts/seapressure-unit-issue-draft.md) — the unit mismatch. Runtime-confirmed; file this one first
- [`../../upstream/drafts/seapressure-dead-params-issue-draft.md`](../../upstream/drafts/seapressure-dead-params-issue-draft.md) — `noise_sigma` unparsed (**now runtime-confirmed**), `saturation` unused and Gaussian noise commented out (**source-only**)
