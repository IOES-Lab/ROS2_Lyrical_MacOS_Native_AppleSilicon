# Upstream issue draft — three SeaPressure SDF elements do not affect output

**Status:** Draft, not yet filed. Ready to paste into a GitHub Issue.

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) —
`gazebo/dave_gz_sensor_plugins/src/sea_pressure_sensor.cc`. Same file as the separate unit draft,
but a different concern: that one produces a value in the wrong unit, this one
is about configuration that does not reach the output and a `variance` whose meaning is
undocumented. Present on the `ros2` default branch (`cc98a539`, checked 2026-08-21) as well as on
the fork this was measured in.

**Suggested labels:** `bug`, `documentation`

---

## Title

`SubseaPressureSensorPlugin`: `noise_sigma`, `saturation`, and `update_rate` do not affect output

## Summary

Three SDF elements shown by the plugin documentation have no effect on their corresponding output
properties. None warns. Separately, the documented Gaussian noise is commented out while a
non-zero variance is still published.

| Parameter | Documented behaviour | Actual | Basis |
|---|---|---|---|
| `<noise_sigma>` | standard deviation of the added noise | **Never read.** `Configure()` has no branch for this element | **Source + runtime confirmed** (§1) |
| `<saturation>` | upper limit on output pressure | **Parsed, then unused.** Stored and never referenced again | **Source + runtime confirmed** (§2) |
| `<update_rate>` | requested output rate | **Never read.** Output follows the physics update | **Source + runtime confirmed** (§3) |
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

## 2. `saturation` is parsed but never applied — confirmed at runtime

```cpp
double saturation;                                    // member
...
if (_sdf->HasElement("saturation"))
  this->dataPtr->saturation = _sdf->Get<double>("saturation");
else
  this->dataPtr->saturation = 3000;
```

Those are the only three occurrences in the file. The value never appears in a comparison, a
clamp, or any arithmetic. In the 2026-08-26 controlled matrix, a probe at `z=-10 m` with
`<saturation>50</saturation>` published `199.3888` on both macOS and Docker. A working clamp would
have produced `50`, so the run discriminates between applied and ignored behavior.

## 3. `update_rate` is not parsed — confirmed at runtime

`Configure()` has no branch for `update_rate` and `PostUpdate()` has no rate gate. A controlled
probe configured with `<update_rate>2</update_rate>` produced a median message timestamp interval
of approximately `0.001 s` on both platforms, not the requested `0.5 s`. The output followed the
1000 Hz physics step used by the test world.

## 4. No Gaussian noise is added

```cpp
// not adding gaussian noise for now, Future Work (TODO)
// pressure += this->dataPtr->GetGaussianNoise(this->dataPtr->noiseAmp);
this->dataPtr->pressure += this->dataPtr->noiseAmp;   // noiseAmp is 0.0
```

The reading is therefore deterministic, while `noiseSigma²` still populates the message's
`variance` field. Five post-warmup frames per condition were identical in every one of ten
conditions on both platforms. That short run is consistent with the source, but the disabled line
is the evidence for the implementation and the five-frame observation is not a long-duration
statistical guarantee.

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

Alongside that, three configuration elements do not reach the corresponding output behavior:
`noise_sigma`, `saturation`, and `update_rate`, each confirmed with a discriminating runtime
control on both platforms.

## Suggested fix

The smallest honest change is to make the code and the documentation agree. Options, in
increasing order of work:

1. **Document the current state** — record that `saturation`, `noise_sigma`, and `update_rate` are not applied,
   and state what the published `variance` is meant to represent given that no noise is added.
   That last point is a decision for whoever knows the intent, not a bug fix.
2. **Parse `noise_sigma` and `update_rate`**, and apply `saturation` as a clamp, leaving noise
   generation as future work.
3. **Implement the Gaussian noise** the `TODO` refers to, at which point all three become
   consistent with each other.

Option 1 alone would remove the ambiguity, which is the part a user actually trips over.

## What this claim is and is not

- **`noise_sigma`, `saturation`, and `update_rate` are runtime-confirmed on Mac and Docker.** Each
  used a value whose applied and ignored outcomes differ clearly.
- **The un-applied Gaussian noise is source-confirmed.** Five deterministic frames per condition
  are consistent with it but are not a long-duration noise study.
- **The `variance` semantics question is not a measurement at all.** What the field is *meant* to
  represent cannot be determined from outside; it needs someone who knows the intent.
- Ten static conditions per platform, five retained frames per condition; maximum `|z|=10 m`.
- **Cross-checked against the `ros2` default branch.** The source was read at
  `naitikpahwa18/dave` commit `6aef91c` and again at `IOES-Lab/dave` `ros2` (`cc98a539`) on
  2026-08-21; all three findings are present in both, so this is not fork-specific.

## Environment

- Local `lyrical-jetty-migration` workspace built on `naitikpahwa18/dave` commit `6aef91c`
  (the same commit as that fork's `wgpu_integration` head at the time of checkout)
- ROS 2 Lyrical + Gazebo Jetty 10.4.0 on macOS / Apple M2 and Docker ARM64

## Reproduce

The preserved test kit generates a copied world and models with exactly one occurrence of every
tested tag; the DAVE checkout is not edited:

```bash
bash notes/experiments/seapressure/run.sh mac /absolute/result/root/05_parameter_matrix
bash notes/experiments/seapressure/run.sh docker /absolute/result/root/06_docker_validation
python3 notes/experiments/seapressure/summarize_results.py /absolute/result/root
```

Results and generated test assets:
[`../../results/seapressure_full_validation_2026-08-26/`](../../results/seapressure_full_validation_2026-08-26/).
