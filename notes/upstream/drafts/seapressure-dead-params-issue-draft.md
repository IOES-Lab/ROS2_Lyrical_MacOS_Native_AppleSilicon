# Upstream issue draft — three SeaPressure parameters are accepted but do nothing

**Status:** Draft, not yet filed. Ready to paste into a GitHub Issue.

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) —
`gazebo/dave_gz_sensor_plugins/src/sea_pressure_sensor.cc`. Same file as the unit issue filed
alongside this one, but a separate concern: that one produces a value in the wrong unit, this one
is about configuration that does not reach the output and a `variance` whose meaning is
undocumented. Present on the `ros2` default branch (`cc98a539`, checked 2026-08-21) as well as on
the fork this was measured in.

**Suggested labels:** `bug`, `documentation`

**Before filing:** the `noise_sigma` finding below is from reading `Configure()`, not from a
runtime comparison. Setting `<noise_sigma>` to a non-default value (say `0.123`) and confirming
`variance` stays at `9.0` would turn it into a measurement and takes one launch. Either do that
first, or file with the limitation stated as written below — but do not let it be read as
runtime-confirmed.

---

## Title

`SubseaPressureSensorPlugin`: `noise_sigma` appears unparsed, `saturation` is never applied, and
the documented Gaussian noise is commented out

## Summary

Three things the plugin's documentation describes as configurable appear to have no effect on its
output. None of them warns; each silently does nothing.

| Parameter | Documented behaviour | Actual | Basis |
|---|---|---|---|
| `<noise_sigma>` | standard deviation of the added noise | **Never read.** `Configure()` has no branch for this element | Source only — see the caveat in §1 |
| `<saturation>` | upper limit on output pressure | **Parsed, then unused.** Stored and never referenced again | Source; verifiable by grep |
| Gaussian noise | added to the pressure reading | **Commented out** with a `TODO` | Source; the line is visibly disabled |

## 1. `noise_sigma` is not parsed

`Configure()` reads `saturation`, `estimate_depth_on`, `standard_pressure` and `kPa_per_meter`.
There is no branch for `noise_sigma`, so `noiseSigma` keeps its compiled-in default of `3.0`
regardless of what the SDF says.

`rexrov/model.sdf` does supply the tag:

```xml
<noise_sigma>3.0</noise_sigma>
```

and a run publishes `variance: 9.0`, which is `3.0²`.

**That output is not evidence of anything**, and is included here only to forestall the
inference. The SDF value and the compiled-in default are both `3.0`, so the observation is
equally consistent with the tag being honoured and with it being ignored. The claim rests
entirely on the absence of a parsing branch in `Configure()`.

The experiment that would settle it — set `<noise_sigma>0.123</noise_sigma>` and check whether
`variance` moves off `9.0` — has not been run.

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
`variance` field. This is the one of the three that needs no inference — the addition is a
commented-out line sitting directly above a `+= 0.0`.

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

Alongside that, two configuration elements do not reach the output. The `saturation` case is
plain. The `noise_sigma` case is the weaker claim of the three and is marked as such in §1.

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

- **All three findings are from reading the source. None is runtime-confirmed.** A live run
  showed the effective `noiseSigma` is 3.0, but the model SDF also specifies 3.0, so that
  observation cannot distinguish "parsed" from "ignored".
- **No parameter was set to a non-default value and observed to have no effect.** That is the
  experiment that would convert these from code reading to measurement, and it was not done.
- The `saturation` and commented-out-noise findings are absences in the code — direct to verify
  by reading the file, but still not the same as an experiment.
- **Cross-checked against the `ros2` default branch.** The source was read at
  `naitikpahwa18/dave` commit `6aef91c` and again at `IOES-Lab/dave` `ros2` (`cc98a539`) on
  2026-08-21; all three findings are present in both, so this is not fork-specific.

## Environment

- Local `lyrical-jetty-migration` workspace built on `naitikpahwa18/dave` commit `6aef91c`
  (the same commit as that fork's `wgpu_integration` head at the time of checkout)
- ROS 2 Lyrical + Gazebo Jetty 10.4.0, macOS, Apple M2, headless

## Reproduce

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov \
  world_name:=dave_ocean_waves \
  paused:=false headless:=true \
  debug:=true verbose:=4 \
  use_teleop:=false use_web_joystick:=false

ros2 topic echo /model/rexrov/sea_pressure --once
# variance: 9.0 -- but rexrov/model.sdf also says 3.0, so this run does not
# discriminate. Change the tag to 0.123 and re-run to make it discriminate.
```

`headless:=true` matters: the default GUI launch exits `-6` on this machine.
