<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) — `gazebo/dave_gz_sensor_plugins/src/sea_pressure_sensor.cc`. Core sensor code, unrelated to the WGPU sonar work. Measured in a local `lyrical-jetty-migration` workspace built on `naitikpahwa18/dave` commit `6aef91c`, and **cross-checked against `IOES-Lab/dave`'s `ros2` default branch (`cc98a539`) on 2026-08-21 — the unconverted assignment is present there unchanged.**
     라벨:     `bug`
     원본:     notes/upstream/drafts/seapressure-unit-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

`SubseaPressureSensorPlugin` publishes kPa into `sensor_msgs/FluidPressure`, which is defined in Pascals — readings are 1000x too small

---

## 이슈 본문 (이 줄 아래 전체를 본문 칸에 붙여넣기)

## Summary

The plugin computes pressure in **kilopascals** and assigns that number directly to the
`fluid_pressure` field of [`sensor_msgs/msg/FluidPressure`](https://docs.ros.org/en/rolling/p/sensor_msgs/msg/FluidPressure.html),
which the message definition specifies in **Pascals**.

At the controlled surface the topic carries `101.325` where a consumer reading the message
according to its own definition expects `101325`. At `|z|=10 m` it carries `199.3888` rather
than `199388.8`. Both values were reproduced on macOS and Docker.

The message definition reads:

```
float64 fluid_pressure       # Absolute pressure reading in Pascals.
float64 variance             # 0 is interpreted as variance unknown
```

Measured first on REXROV at `z:=0` in `dave_ocean_waves`:

```
$ ros2 topic type /model/rexrov/sea_pressure
sensor_msgs/msg/FluidPressure

$ ros2 topic echo /model/rexrov/sea_pressure --once
fluid_pressure: 101.32505915145917
```

`101.32505915145917` against an expected `101325` Pa — a factor of 1000.

The finding was then re-run on 2026-08-26 in a copied controlled world with ten uniquely
namespaced static probes on both macOS and Docker. The unit-discriminating conditions were:

| Controlled pose/configuration | macOS | Docker | Pascal-contract value |
|---|---:|---:|---:|
| `z=0`, compiled defaults | `101.325` | `101.325` | `101325` |
| `z=-10 m`, compiled defaults | `199.3888` | `199.3888` | `199388.8` |
| `z=+10 m`, compiled defaults | `199.3888` | `199.3888` | `199388.8` |

The same baseline number was also read directly from Gazebo Transport on both platforms. This
report cites the ROS Pascal contract only; the Gazebo message's unit convention is not assumed.

## Where it comes from

The internal constants are kPa-based, which is self-consistent:

```cpp
double standardPressure = 101.325;   // kPa at the surface
double kPaPerM = 9.80638;            // kPa per metre of depth
```

```cpp
this->dataPtr->pressure = this->dataPtr->standardPressure;
if (depth >= 0) {
  this->dataPtr->pressure += depth * this->dataPtr->kPaPerM;
}
```

The value is then published without conversion:

```cpp
rosPressureMsg.fluid_pressure = this->dataPtr->pressure;   // kPa into a Pa field
```

The depth estimate published on `sea_pressure_depth` divides by the same `kPaPerM`. It was checked
numerically in the controlled run: `z=0` produced depth `0`, and both `z=-10` and `z=+10` produced
depth `10`. A `kPa_per_meter=1.0` control at `z=-10` still produced depth `10`. This establishes
self-consistency of the implemented inverse; it also exposes the separate `abs(z)` behavior and
does not establish real-sensor accuracy.

## Why this is easy to miss

Nothing fails. The topic exists, publishes at the expected rate, and carries a plausible-looking
number. Anyone who reads it as kPa gets a correct answer; anyone who reads it as the message
definition says gets one that is wrong by three orders of magnitude, with no indication which
happened.

## Suggested fix

Convert at the publication boundary and leave the internal model in kPa:

```diff
-  rosPressureMsg.fluid_pressure = this->dataPtr->pressure;
+  // FluidPressure.msg specifies Pascals; the model works in kPa
+  rosPressureMsg.fluid_pressure = this->dataPtr->pressure * 1000.0;
```

**The `variance` field is deliberately left out of this proposal.** Variance scales with the
square of the unit, so a mechanical fix would be `noiseSigma × 1000` squared — but the noise this
variance is meant to describe is not currently applied to the reading (the addition is commented
out in the same file), and the message defines `0` as *unknown* rather than *noiseless*, so what
the field should hold is a semantics question rather than an arithmetic one. **This issue is
about the pressure value's unit**; the variance and noise semantics are raised separately.

The Gazebo-side publication (`gzPressureMsg.set_pressure(...)`) carries the same number from the
same variable, so whatever is decided here applies to it. **No claim is made about what
`gz::msgs::FluidPressure` declares** — its definition was not located, so its unit convention is
simply unknown to this report.

**This is a behaviour change for existing users.** Anyone who has been treating the topic as kPa
will see their numbers jump by 1000x. That is a maintainer's call — an alternative is to leave
the value and document the unit, though that leaves the ROS message contract violated.

## What this claim is and is not

- **The 1000x factor is confirmed at runtime**, not inferred from reading the source. The echo
  output above is from a live simulation.
- **Surface and ±10 m values are runtime-confirmed on Mac and Docker.** The controlled matrix
  contains five retained post-warmup frames per condition and the platform values agree.
- **`sea_pressure_depth` was checked numerically** at 0 and ±10 m, plus one slope override.
- **The Pascal claim is ROS-specific.** Gazebo Transport was sampled, but no equivalent unit
  convention is claimed for `gz::msgs::FluidPressure`.
- The controlled range is small and static. No physical pressure sensor, real ocean, extreme depth
  or long-duration stability comparison was performed.

## Environment

- Local `lyrical-jetty-migration` workspace built on `naitikpahwa18/dave` commit `6aef91c`
  (the same commit as that fork's `wgpu_integration` head at the time of checkout)
- ROS 2 Lyrical + Gazebo Jetty 10.4.0 on macOS / Apple M2 and Docker ARM64
- Controlled copied world and models; the DAVE checkout was loaded but not edited

## Reproduce

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0 namespace:=rexrov \
  world_name:=dave_ocean_waves \
  paused:=false headless:=true \
  debug:=true verbose:=4 \
  use_teleop:=false use_web_joystick:=false

# in another terminal
ros2 topic type /model/rexrov/sea_pressure
ros2 topic echo /model/rexrov/sea_pressure --once
```

At `z:=0` the surface value should read `101325` if the field is Pascals. It reads `101.325`.

The cross-platform matrix, generated SDF and machine-readable results are preserved at
[`../../results/seapressure_full_validation_2026-08-26/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/seapressure_full_validation_2026-08-26/).
