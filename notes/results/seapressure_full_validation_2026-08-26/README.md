# SeaPressure direct validation — Mac and Docker, 2026-08-26

## Verdict

**PARTIAL.** The plugin loads and publishes ROS and Gazebo messages on both tested
platforms. Its implemented pressure/depth formula, working SDF overrides and topic
routing are reproducible. It is not numerically correct as a
`sensor_msgs/msg/FluidPressure` producer, and three documented configuration
elements do not affect output.

This run extends the 2026-08-21 surface-only Mac check with ten controlled static
probes on both:

- macOS Apple Silicon, ROS 2 Lyrical, Gazebo Jetty
- Docker ARM64, ROS 2 Lyrical, Gazebo Jetty

All ten conditions produced the same pressure and variance on both platforms.

## Direct results

| Condition | Controlled change | Mac | Docker | What it establishes |
|---|---|---:|---:|---|
| baseline | omit all optional tags, `z=0` | `101.325` | `101.325` | compiled defaults; kPa-sized value in a Pascal field |
| depth | `z=-10 m` | `199.3888` | `199.3888` | default depth slope is applied |
| above origin | `z=+10 m` | `199.3888` | `199.3888` | the implementation uses `abs(z)` |
| saturation | `z=-10`, `<saturation>50</saturation>` | `199.3888` | `199.3888` | saturation is ignored; a clamp would have produced `50` |
| standard pressure | `<standard_pressure>200</standard_pressure>` | `200.0` | `200.0` | this override works |
| pressure slope | `z=-10`, `<kPa_per_meter>1.0</kPa_per_meter>` | `111.325` | `111.325` | this override works |
| noise sigma | `<noise_sigma>0.123</noise_sigma>` | variance `9.0` | variance `9.0` | tag ignored; if applied, variance would be `0.015129` |
| topic | `<topic>custom_sp</topic>` | custom topic | custom topic | topic override works |
| depth switch | `<estimate_depth_on>false</estimate_depth_on>` | no depth topic | no depth topic | switch works |
| update rate | `<update_rate>2</update_rate>` | median `0.001 s` | median `0.001 s` | tag ignored; output follows the 1000 Hz physics step, not 2 Hz |

Every retained condition captured five post-warmup pressure frames. All five were
identical in each condition on both platforms. This is runtime evidence that no
sample-varying noise was present in these runs; it is not a long-duration
statistical guarantee.

## Unit and depth behavior

The ROS interface recorded in
[`06_docker_validation/fluid_pressure_interface.txt`](06_docker_validation/fluid_pressure_interface.txt)
defines:

```text
float64 fluid_pressure  # Absolute pressure reading in Pascals.
```

The plugin publishes `101.325` at the controlled surface and `199.3888` at
`|z|=10 m`. Those are kPa-sized values. A consumer following the ROS contract
would expect `101325` and `199388.8` Pa respectively.

The depth topic was numerically checked, not merely discovered:

- `z=0` -> inferred depth `0`
- `z=-10` -> inferred depth `10`
- `z=+10` -> inferred depth `10`
- `kPa_per_meter=1.0`, `z=-10` -> inferred depth still `10`

The inverse is self-consistent because the same slope is used in both directions.
It also exposes the `abs(z)` behavior: in a controlled world whose origin represents
the surface, a probe 10 m above the origin is treated exactly like one 10 m below it.

## Metadata and transports

All retained ROS pressure samples on both platforms had an empty `header.frame_id`,
although the message definition says this field locates the pressure sensor.

Gazebo Transport output was read directly:

```text
pressure: 101.325
variance: 9
```

Docker captured all ten Gazebo topics. A separate Mac retest captured the baseline:

- [`06_docker_validation/`](06_docker_validation/)
- [`07_mac_gz_transport_retest/`](07_mac_gz_transport_retest/)

## Discriminating controls

The controls separate working parameters from ignored ones in the same build and
session:

- `standard_pressure=200` and `kPa_per_meter=1.0` changed output exactly as predicted.
- `estimate_depth_on=false` removed the depth topic.
- `topic=custom_sp` changed both ROS and Gazebo topic names.
- `saturation=50`, `noise_sigma=0.123` and `update_rate=2` did not affect the
  corresponding output properties.

## Invalid first matrix

[`invalid_duplicate_tag_and_cleanup_attempt/`](invalid_duplicate_tag_and_cleanup_attempt/)
is retained but excluded. Its script duplicated `kPa_per_meter` and
`estimate_depth_on` tags and relied on process-name cleanup that did not stop prior
worlds. Models accumulated in one old world, so that attempt cannot support a
condition-isolation claim. The corrected runner uses one deliberately shared server,
unique namespaces, a unique world name and exactly one copy of every tested tag.

## Reproduction

The test kit is under
[`../../experiments/seapressure/`](../../experiments/seapressure/):

```bash
bash notes/experiments/seapressure/run.sh mac /absolute/output/path
bash notes/experiments/seapressure/run.sh docker /absolute/output/path
python3 notes/experiments/seapressure/summarize_results.py /absolute/result/root
```

The DAVE checkout was read and loaded but not edited. Exact generated models and
the controlled world are preserved in each platform's `test_assets/`. The exact
source file used for the audit, its repository commit and matching SHA-256 are under
[`source/`](source/).

## Repository whitespace check

After staging, `git diff --cached --check` reports 57 evidence-format warnings:
51 command-output files end with the blank line emitted by the captured command,
and six copies of the SDF inputs retain whitespace on an otherwise blank generated
line. They are preserved as executed or captured rather than rewritten to make the
checker pass. The documentation and reusable experiment scripts add no such
warning. This is a record of the check's actual result, not a claim that the staged
tree is whitespace-warning-free.

## Limits

- Static controlled probes only; maximum absolute Z was 10 m.
- No comparison with a physical pressure sensor or real ocean data.
- The intended meaning of `variance=9.0` while no Gaussian noise is applied is not
  established by runtime data.
- Above-origin behavior is scoped to a world whose origin represents the surface.
- Paused behavior, long-duration stability and extreme-depth behavior were not tested.

Machine-readable canonical result:
[`summary.json`](summary.json).
