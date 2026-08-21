# Upstream issue draft — three SeaPressure parameters are accepted but do nothing

**Status:** Draft, not yet filed. Ready to paste into a GitHub Issue.

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) —
`gazebo/dave_gz_sensor_plugins/src/sea_pressure_sensor.cc`. Same file as the unit issue filed
alongside this one, but a separate concern: that one produces wrong numbers, this one produces
numbers that ignore your configuration.

**Suggested labels:** `bug`, `documentation`

---

## Title

`SubseaPressureSensorPlugin`: `noise_sigma` is never parsed, `saturation` is never applied, and
the Gaussian noise it documents is commented out

## Summary

Three things the plugin's documentation describes as configurable have no effect on its output.
None of them warns; each silently does nothing.

| Parameter | Documented behaviour | Actual |
|---|---|---|
| `<noise_sigma>` | standard deviation of the added noise | **Never read.** `Configure()` does not parse this element |
| `<saturation>` | upper limit on output pressure | **Parsed, then unused.** Stored and never referenced again |
| Gaussian noise | added to the pressure reading | **Commented out** with a `TODO` |

## 1. `noise_sigma` is not parsed

`Configure()` reads `saturation`, `estimate_depth_on`, `standard_pressure` and `kPa_per_meter`.
There is no branch for `noise_sigma`, so `noiseSigma` keeps its compiled-in default of `3.0`
regardless of the SDF.

This is observable without reading the source. The published `variance` is `noiseSigma²`, so a
default run shows:

```
variance: 9.0        # 3.0², i.e. the compiled-in default
```

Setting `<noise_sigma>` to anything else leaves that value unchanged.

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

The reading is therefore deterministic. `noiseSigma` still populates the message's `variance`
field, so consumers are told the data is noisy when it is not — a filter weighting this sensor by
its reported variance will down-weight a perfectly clean measurement.

## Why this matters together

Individually these are small. Together they mean **the sensor advertises uncertainty it does not
have and accepts configuration it ignores.** A user tuning `noise_sigma` to study estimator
robustness would see the variance field stay at 9.0 and the readings stay identical, with no
indication that neither knob is connected.

## Suggested fix

The smallest honest change is to make the code and the documentation agree. Options, in
increasing order of work:

1. **Document the current state** — mark `saturation` and `noise_sigma` as not implemented, and
   stop publishing a non-zero `variance` for a noiseless reading.
2. **Parse `noise_sigma`** and apply `saturation` as a clamp, leaving noise generation as future
   work.
3. **Implement the Gaussian noise** the `TODO` refers to, at which point all three become
   meaningful.

Option 1 alone would prevent the misleading part.

## What this claim is and is not

- **Read from the source, and partially confirmed at runtime.** The `variance: 9.0` output
  confirms `noiseSigma` is at its compiled-in default; the other two are from reading the file.
- **Not tested by setting the parameters and observing no change.** The conclusion that they are
  ignored comes from their absence in the code paths, which is direct but is not the same as an
  experiment.
- Observed on macOS / Apple Silicon under ROS 2 Lyrical + Gazebo Jetty 10.4.

## Environment

- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- ROS 2 Lyrical + Gazebo Jetty 10.4.0, macOS, Apple M2, headless

## Reproduce

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov world_name:=dave_ocean_waves paused:=false

ros2 topic echo /model/rexrov/sea_pressure --once
# variance: 9.0  regardless of any <noise_sigma> set in the model SDF
```
