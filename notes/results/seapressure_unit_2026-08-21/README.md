# SeaPressure publishes kPa into a Pascal field — runtime confirmation

**2026-08-21** · macOS / Apple M2 / Metal · ROS 2 Lyrical + Gazebo Jetty 10.4.0 · headless

The unit mismatch was found by reading `sea_pressure_sensor.cc`. This run confirms it against a
live system, which is what the upstream report needed.

## What was run

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov world_name:=dave_ocean_waves paused:=false
```

Gazebo started, REXROV uploaded, the SeaPressure plugin loaded, `PostUpdate` ran for about two
minutes, and the process exited cleanly. No aborts.

```
[INFO] [gazebo-1]: process started with pid [22511]
[INFO] [launch.user]: Robot Model Uploaded
[INFO] [gazebo-1]: process has finished cleanly [pid 22511]
```

## Output

```
$ ros2 topic type /model/rexrov/sea_pressure
sensor_msgs/msg/FluidPressure

$ ros2 topic echo /model/rexrov/sea_pressure --once
fluid_pressure: 101.32505915145917
variance: 9.0
```

## What it establishes

**The 1000x factor is real, not inferred.** At `z:=0` the field reads `101.325`.
`sensor_msgs/msg/FluidPressure` specifies Pascals, so a consumer following the message definition
expects `101325`. The plugin's internals are kPa-based throughout (`standardPressure = 101.325`,
`kPaPerM = 9.80638`) and the value is assigned without conversion.

**`variance: 9.0` confirms a second defect from the same run.** Variance is published as
`noiseSigma²`, and 9.0 = 3.0². That is the compiled-in default, not the `0.01` the wiki listed —
and it holds regardless of `<noise_sigma>`, because `Configure()` never parses that element.

## What this does not establish

- **Only the surface value was measured.** Scaling at depth follows from the same code path but
  was not measured at several depths.
- **`sea_pressure_depth` was not checked numerically.** The argument that its units cancel comes
  from reading the code.
- **Single platform.** Nothing about the defect looks platform-specific, but it was seen on one.

## Separate observation, not part of this finding

A GUI launch of the same world exited with `-6`. That is a rendering-side failure and is
unrelated to the pressure units — the headless run above completed cleanly and produced the
measurement. Kept apart deliberately so the unit report does not carry an unexplained crash with
it.

## Reports written from this

- [`../../upstream/drafts/seapressure-unit-issue-draft.md`](../../upstream/drafts/seapressure-unit-issue-draft.md) — the unit mismatch
- [`../../upstream/drafts/seapressure-dead-params-issue-draft.md`](../../upstream/drafts/seapressure-dead-params-issue-draft.md) — `noise_sigma` unparsed, `saturation` unused, Gaussian noise commented out
