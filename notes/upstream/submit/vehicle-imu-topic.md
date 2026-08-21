<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) — `models/dave_robot_models/`. Model and config content, unrelated to the WGPU sonar work. Verified on `naitikpahwa18/dave`, branch `wgpu_integration`, pinned `6aef91c`; the vehicle models are unlikely to differ from `ros2` (the repository's default branch), but worth checking before filing.
     라벨:     `bug`
     원본:     notes/upstream/drafts/vehicle-imu-topic-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

`imu_sensor` omits `<topic>` on every vehicle, so the bridged `/model/<ns>/imu` topic exists but never publishes

---

## 이슈 본문 (이 줄 아래 전체를 본문 칸에 붙여넣기)

## Summary

Four base vehicle models — `rexrov`, `bluerov2`, `bluerov2_heavy`, `glider_slocum` — were
runtime-tested, and a fifth, `bluerov2_heavy_multibeam_sonar`, shows the same omission by source
inspection only. All five declare
an `imu_sensor` with no `<topic>` element. Gazebo therefore publishes on its default sensor
path, while each vehicle's `robot_config.py` bridges the short name:

```
gz publishes to    /world/<world>/model/<ns>/link/<link>/sensor/imu_sensor/imu
bridge listens on  /model/<ns>/imu                      <- nothing publishes here
```

The ROS topic is created by the bridge, appears in `ros2 topic list`, and stays silent.

Adding one line per model fixes it:

```xml
<topic>/model/<vehicle>/imu</topic>
```

Measured before and after on a running simulation, in `dave_ocean_waves`:

| vehicle | IMU messages before | after |
|---|---|---|
| `rexrov` | none | received |
| `bluerov2` | none | received |
| `bluerov2_heavy` | none | received |
| `glider_slocum` | none | received |

## The same files contain the counter-example

This is not inferred from topic names. In `rexrov/model.sdf`:

| sensor | `<topic>` declared | publishes to ROS |
|---|---|---|
| `magnetometer_sensor` | yes | yes |
| `imu_sensor` | **no** | **no** |

`bluerov2/model.sdf` shows the same pairing with its `underwater_camera`, which declares a
topic and works. Within a single file, the sensors that declare a topic reach ROS and the
ones that do not are silent.

## Why this has not been noticed

Everything a liveness check looks at is healthy. The vehicle spawns, physics steps,
`odometry` and `pose` publish normally, and the process stays up indefinitely. Only
subscribing to `/model/<ns>/imu` shows that no message ever arrives.

## Suggested fix

```diff
       <sensor name="imu_sensor" type="imu">
         <always_on>true</always_on>
         <update_rate>50.0</update_rate>
+        <topic>/model/rexrov/imu</topic>
       </sensor>
```

Applied to the four base models. `bluerov2_heavy_multibeam_sonar` needs the same line — see the
scope note below. Alternatively the bridge could be pointed at Gazebo's default
path, but that path embeds the world and link names, so declaring the topic in the sensor is
the smaller and more stable change.

## Second, related problem: BlueROV2 bridges a magnetometer it does not have

`config/bluerov2/robot_config.py` and `config/bluerov2_heavy/robot_config.py` both bridge
`/model/<ns>/magnetometer`, but neither model declares a magnetometer sensor — only
`imu_sensor` and `underwater_camera`. REXROV has one, and appears to be where the config was
copied from.

Two possible fixes, and the choice is yours rather than ours:

- **Remove the bridge entry**, matching the model as it stands.
- **Add a magnetometer sensor to the models** — a real BlueROV2 carries one, so this may be
  what was intended, but it changes vehicle behaviour.

## What this claim is and is not

- **Message content was not inspected**, only that messages arrive. This does not say the
  IMU data is correct, only that before the fix there was none.
- **Four vehicles measured, a fifth read only.** The four base vehicles were measured before and after on a running simulation. A fifth model, `bluerov2_heavy_multibeam_sonar`, has the same omission in the current `ros2` source — its `imu_sensor` declares no `<topic>` while the camera and sonar in the same file do — but it was **not** launched, so that one is source-only.
- **n = 1 per vehicle.** The before/after is the exception: all four measured silent before
  and publishing after.
- Tested only in `dave_ocean_waves`. Whether behaviour differs by world is untested.
- Measured on macOS / Apple Silicon / Metal under ROS 2 Lyrical + Gazebo Jetty 10.4, with
  `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` set to work around an unrelated spawn hang. Nothing
  about the defect looks platform-specific — it is a topic-name mismatch visible in the
  files — but it has not been reproduced elsewhere.

## Environment

- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- ROS 2 Lyrical + Gazebo Jetty 10.4, macOS, Apple M2, Metal
- `ros2 launch dave_demos dave_robot.launch.py namespace:=<vehicle>
  world_name:=dave_ocean_waves paused:=false gui:=true headless:=true
  use_teleop:=false use_web_joystick:=false`

## Reproduce

```bash
# before the fix
ros2 topic list | grep /model/rexrov/imu     # topic exists
ros2 topic echo /model/rexrov/imu --once     # never returns
gz topic -l | grep imu                       # shows the long default path instead
```

Full write-up and the patch:
[`notes/results/vehicles_2026-08-07/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/vehicles_2026-08-07/),
[`patches/vehicle_imu_topic_fix.diff`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/blob/main/patches/vehicle_imu_topic_fix.diff)
