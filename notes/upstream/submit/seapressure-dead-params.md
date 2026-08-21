<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) — `gazebo/dave_gz_sensor_plugins/src/sea_pressure_sensor.cc`. Same file as the unit issue filed alongside this one, but a separate concern: that one produces a value in the wrong unit, this one is about configuration that does not reach the output and a `variance` whose meaning is undocumented. Present on the `ros2` default branch (`cc98a539`, checked 2026-08-21) as well as on the fork this was measured in.
     라벨:     `bug`, `documentation`
     원본:     notes/upstream/drafts/seapressure-dead-params-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

`SubseaPressureSensorPlugin`: `<noise_sigma>` is ignored, `saturation` is never applied, and the documented Gaussian noise is commented out

---

## 이슈 본문 (이 줄 아래 전체를 본문 칸에 붙여넣기)

## Summary

Three things the plugin's documentation describes as configurable have no effect on its output.
None of them warns; each silently does nothing.

| Parameter | Documented behaviour | Actual | Basis |
|---|---|---|---|
| `<noise_sigma>` | standard deviation of the added noise | **Never read.** `Configure()` has no branch for this element | **Source + runtime confirmed** (§1) |
| `<saturation>` | upper limit on output pressure | **Parsed, then unused.** Stored and never referenced again | Source; verifiable by grep |
| Gaussian noise | added to the pressure reading | **Commented out** with a `TODO` | Source; the line is visibly disabled |

## 1. `noise_sigma` is not parsed — confirmed at runtime

`Configure()` reads `namespace`, `topic`, `saturation`, `estimate_depth_on`, `standard_pressure`
and `kPa_per_meter`. There is no branch for `noise_sigma`, so `noiseSigma` keeps its compiled-in
default of `3.0` no matter what the SDF says.

Confirmed by changing the value and observing no change in the output. `rexrov/model.sdf` ships
`<noise_sigma>3.0</noise_sigma>`; it was set to `0.123` and the model relaunched:

```
Test input:            <noise_sigma>0.123</noise_sigma>
Expected if applied:   variance = 0.015129   (0.123²)
Expected if ignored:   variance = 9.0        (3.0², the compiled-in default)
Observed:              variance = 9.0
```

```
$ ros2 topic echo /model/rexrov/sea_pressure --once
fluid_pressure: 101.32505915145917
variance: 9.0
```

The two hypotheses predict values about 595× apart — nearly three orders of magnitude — so this
run discriminates between them. **The SDF element does not reach the sensor.**

Note that a run at the shipped `3.0` proves nothing here, since the SDF value and the compiled
default are the same number and `variance: 9.0` appears either way. Changing the value is what
makes the observation informative.

## 2. `saturation` is parsed but never applied

```cpp
double saturation;                                    // member
...
if (_sdf->HasElement("saturation"))
  this->dataPtr->saturation = _sdf->Get<double>("saturation");
else
  this->dataPtr->saturation = 3000;
```

Those are the only three occurrences in the file. The value never appears in a comparison, a
clamp, or any arithmetic, so output pressure is not limited by it.

## 3. No Gaussian noise is added

```cpp
// not adding gaussian noise for now, Future Work (TODO)
// pressure += this->dataPtr->GetGaussianNoise(this->dataPtr->noiseAmp);
this->dataPtr->pressure += this->dataPtr->noiseAmp;   // noiseAmp is 0.0
```

The reading is therefore deterministic, while `noiseSigma²` still populates the message's
`variance` field. This one needs no inference — the addition is a commented-out line sitting
directly above a `+= 0.0`. Consistently, `fluid_pressure` came back bit-identical across two
separate launches at the same depth (`101.32505915145917` both times), though that alone would
also be explained by a fixed seed; the commented-out line is the evidence.

## Why this matters together

The plugin publishes a non-zero `variance` while its output remains deterministic, because the
documented Gaussian noise is not applied. **This may well be intentional** — a nominal sensor
uncertainty is a reasonable thing to advertise even when the simulated signal is clean, and
`sensor_msgs/msg/FluidPressure` reserves `0` for *variance unknown*, so publishing `0` instead
would assert something different rather than something more accurate.

The problem is that the intended semantics are not documented anywhere, so a consumer cannot tell
which of the two it is being handed: a modelled uncertainty that happens not to be sampled, or a
leftover from noise that was planned and never implemented. The commented-out `TODO` suggests the
second, but that is an inference about intent.

Alongside that, two configuration elements do not reach the output — `noise_sigma`, confirmed by
changing it and seeing nothing move, and `saturation`, which the code simply never reads after
storing.

## Suggested fix

The smallest honest change is to make the code and the documentation agree. Options, in
increasing order of work:

1. **Document the current state** — record that `saturation` and `noise_sigma` are not applied,
   and state what the published `variance` is meant to represent given that no noise is added.
   That last point is a decision for whoever knows the intent, not a bug fix.
2. **Parse `noise_sigma`** and apply `saturation` as a clamp, leaving noise generation as future
   work.
3. **Implement the Gaussian noise** the `TODO` refers to, at which point all three become
   consistent with each other.

Option 1 alone would remove the ambiguity, which is the part a user actually trips over.

## What this claim is and is not

- **`noise_sigma` is runtime-confirmed.** Set to a non-default value, relaunched, output
  unchanged. This is a measurement, not an inference.
- **`saturation` and the un-applied Gaussian noise are source-only.** Neither was tested by
  setting a value and observing no effect. They are absences in the code — direct to verify by
  reading the file, but not the same kind of evidence as §1.
- **The `variance` semantics question is not a measurement at all.** What the field is *meant* to
  represent cannot be determined from outside; it needs someone who knows the intent.
- Two runs, one machine, `z:=0`.
- **Cross-checked against the `ros2` default branch.** The source was read at
  `naitikpahwa18/dave` commit `6aef91c` and again at `IOES-Lab/dave` `ros2` (`cc98a539`) on
  2026-08-21; all three findings are present in both, so this is not fork-specific.

## Environment

- Local `lyrical-jetty-migration` workspace built on `naitikpahwa18/dave` commit `6aef91c`
  (the same commit as that fork's `wgpu_integration` head at the time of checkout)
- ROS 2 Lyrical + Gazebo Jetty 10.4.0, macOS, Apple M2, headless

## Reproduce

Edit `rexrov/model.sdf` — the tag is a single occurrence:

```diff
-      <noise_sigma>3.0</noise_sigma>
+      <noise_sigma>0.123</noise_sigma>
```

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov \
  world_name:=dave_ocean_waves \
  paused:=false headless:=true \
  debug:=true verbose:=4 \
  use_teleop:=false use_web_joystick:=false

# in another terminal
ros2 topic echo /model/rexrov/sea_pressure --once
# variance: 9.0   -- 0.123² would be 0.015129
```

`headless:=true` matters: the default GUI launch exits `-6` on this machine.

Remember to restore the model afterwards.
