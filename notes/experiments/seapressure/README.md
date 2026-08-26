# SeaPressure full validation kit — Mac + Docker

Built to the same standard as the Underwater Camera run of 2026-08-26: every documented SDF
element exercised, every claim given a **discriminating** prediction, both
platforms, deterministic capture, and failed routes kept.

The 2026-08-21 run established two things at runtime — the 1000x unit error and
that `<noise_sigma>` is ignored — on **macOS only**, at **one depth**, with
`saturation` and the disabled Gaussian noise left as source-only. This kit
closes the rest.

## What the source says the output must be

`sea_pressure_sensor.cc`, `PreUpdate()`:

```cpp
double depth = std::abs(sea_pressure_sensor_pos.Z());
this->dataPtr->pressure = this->dataPtr->standardPressure;
if (depth >= 0) { this->dataPtr->pressure += depth * this->dataPtr->kPaPerM; }
this->dataPtr->pressure += this->dataPtr->noiseAmp;          // noiseAmp is 0.0
if (this->dataPtr->estimateDepth) {
  this->dataPtr->inferredDepth =
    (this->dataPtr->pressure - this->dataPtr->standardPressure) / this->dataPtr->kPaPerM;
}
```

So:

```
pressure       = standard_pressure + |z| * kPa_per_meter
inferred_depth = |z|                       (exact inverse, by construction)
variance       = noiseSigma^2              (compiled default 3.0 -> 9.0)
```

`Configure()` reads exactly six elements: `namespace`, `topic`, `saturation`,
`estimate_depth_on`, `standard_pressure`, `kPa_per_meter`. **`noise_sigma` and
the documented `update_rate` are not among them.** `saturation` is read into a member at line 98 and never
referenced again — lines 34, 96, 98 and 102 are its only four occurrences.

Two ROS topics are published:

```
model/<namespace>/<topic>            sensor_msgs/msg/FluidPressure
model/<namespace>/<topic>_depth      geometry_msgs/msg/PointStamped   (if estimate_depth_on)
```

## Two things to look at that the 08-21 run did not

**`depth` uses `std::abs`.** A sensor *above* the origin reads the same pressure
as one the same distance below it. Condition C tests this: at `z = +10` the
implementation predicts 199.3888 kPa — the pressure of being 10 m underwater —
where a correct sensor at or above the surface should read 101.325.

**`if (depth >= 0)` is dead.** `std::abs` never returns a negative, so the guard
is always true. Source-only observation; nothing to measure.

## Conditions

Ten probe models, each isolating one claim. `sp_*` models are static, so
nothing moves and every run is deterministic.

| # | model | z | SDF change | if the tag reaches output | if it does not | what it separates |
|---|---|---:|---|---:|---:|---|
| A | `sp_baseline` | 0 | none | `101.325` | — | baseline; unit error (not `101325`) |
| B | `sp_depth10` | -10 | none | `199.3888` | `101.325` | depth scaling |
| C | `sp_above10` | **+10** | none | `199.3888` | `101.325` | **`abs(z)` defect** |
| D | `sp_saturation` | -10 | `<saturation>50</saturation>` | `50` | `199.3888` | `saturation` applied? |
| E | `sp_stdpress` | 0 | `<standard_pressure>200</standard_pressure>` | `200` | `101.325` | this tag *does* reach output |
| F | `sp_kpa` | -10 | `<kPa_per_meter>1.0</kPa_per_meter>` | `111.325` | `199.3888` | this tag *does* reach output |
| G | `sp_noise` | 0 | `<noise_sigma>0.123</noise_sigma>` | `variance 0.015129` | `variance 9.0` | `noise_sigma` ignored — Docker repeat |
| H | `sp_topic` | 0 | `<topic>custom_sp</topic>` | `.../custom_sp` | `.../sea_pressure` | `topic` reaches output |
| I | `sp_nodepth` | -10 | `<estimate_depth_on>false</estimate_depth_on>` | no `_depth` topic | `_depth` present | `estimate_depth_on` reaches output |
| J | `sp_rate` | 0 | `<update_rate>2</update_rate>` | about `0.5 s` stamp spacing | physics-step spacing | `update_rate` reaches output? |

E and F matter as much as D. If `standard_pressure` and `kPa_per_meter` demonstrably
work while `saturation` and `noise_sigma` demonstrably do not, the claim stops being
"some tags are ignored" and becomes "these two are, these two are not, measured in
the same session on the same build". That is what makes it reportable upstream.

Every condition also reads `<topic>_depth` and checks `inferred_depth == |z|`.

## Running it

Mac and Docker, same ten conditions, same script.

```bash
# Mac
bash notes/experiments/seapressure/run.sh mac  /path/to/output/05_parameter_matrix

# Docker (inside the container, after sourcing the workspace)
bash notes/experiments/seapressure/run.sh docker /path/to/output/06_docker_validation
```

`run.sh` creates throwaway SDF assets under `$TMPDIR`, starts one server, spawns
the ten uniquely namespaced probes, captures each with `capture_seapressure.py`, and writes one
`summary.json` per condition. **The DAVE checkout is never modified** — the
08-21 run edited `rexrov/model.sdf` in place and restored it afterwards; this
one does not touch it at all.

## Recording the result

Put the output under
`notes/results/seapressure_full_validation_2026-08-<dd>/` with:

```
01_mac_baseline/          02_..._through_10_...   per-condition captures
05_parameter_matrix/      Mac, ten conditions
06_docker_validation/     Docker, ten conditions
test_assets/              the ten .sdf files and the world
summary.json              machine-readable verdict
README.md                 verdict, scope, and what stays unestablished
```

Failed or abandoned routes go in `invalid_*` / `incomplete_*` directories and
are named as such in the README, not deleted.

## What this kit still will not establish

- Real-world pressure-sensor accuracy against a physical instrument.
- Behaviour at large depth — the deepest condition here is 10 m.
- `gz::msgs::FluidPressure`'s declared unit. No `fluid_pressure.proto` was
  located on the 08-21 system; if it is found, note where.
- The intended meaning of a non-zero `variance` on a deterministic reading.
  That needs whoever wrote it, not a measurement.
