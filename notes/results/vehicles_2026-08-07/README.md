# No vehicle's IMU ever reached ROS — and a one-line SDF fix (Mac, 2026-08-07)

The world axis of the validation matrix has been complete for weeks; the vehicle axis never
was. REXROV was the only vehicle used as a smoke-test subject, BlueROV2 had its ArduSub and
mavros build confirmed but no in-world behaviour checked, and BlueROV2 Heavy had never been
used at all.

Checking sensor **output** rather than process liveness found a defect that had been present
the whole time and is invisible to a smoke test.

## The finding

**Every vehicle's `imu_sensor` omits `<topic>`, so Gazebo publishes on its default sensor
path while every `robot_config.py` bridges the short name.** The ROS topic is created by the
bridge and stays silent forever.

```
gz publishes to   /world/oceans_waves/model/bluerov2/link/base_link/sensor/imu_sensor/imu
bridge listens on /model/bluerov2/imu                       <- nothing ever publishes here
```

Verified before and after, on the running simulation:

| vehicle | IMU before | IMU after |
|---|---|---|
| `bluerov2` | 0 | **1** |
| `bluerov2_heavy` | 0 | **1** |
| `rexrov` | 0 | **1** |
| `glider_slocum` | 0 | **1** |

The fix is one line per model:

```xml
<topic>/model/<vehicle>/imu</topic>
```

Saved as [`../../patches/vehicle_imu_topic_fix.diff`](../../patches/vehicle_imu_topic_fix.diff)
— 4 files, 19 lines including comments.

### The same file contains the control

This is not an inference from the topic names. Within `rexrov/model.sdf`:

| sensor | `<topic>` declared | publishes |
|---|---|---|
| `magnetometer_sensor` | yes | yes |
| `imu_sensor` | **no** | **no** |

`bluerov2/model.sdf` shows the same pairing with its camera. The sensors that declare a
topic work; the ones that do not are silent.

## Result after the fix

| vehicle | topics ok | verdict | missing |
|---|---|---|---|
| `rexrov` | **7 / 7** | **FUNCTIONAL** | — |
| `glider_slocum` | **6 / 6** | **FUNCTIONAL** | — |
| `bluerov2` | 4 / 5 | PARTIAL | `magnetometer` |
| `bluerov2_heavy` | 4 / 5 | PARTIAL | `magnetometer` |

Two vehicles fully functional, two short by exactly the magnetometer their models do not
have. **The vehicle axis is closed** — every documented vehicle has now been run in a world
and checked against the topics its own config bridges.

World `dave_ocean_waves`, launched via `dave_robot.launch.py` with `use_teleop:=false
use_web_joystick:=false`, checked after `wait_until_stepping` confirmed ≥60 steps/s twice.

## Second defect: BlueROV2 bridges a magnetometer it does not have

`config/bluerov2/robot_config.py` and `config/bluerov2_heavy/robot_config.py` both bridge
`/model/<ns>/magnetometer`, but neither model SDF declares a magnetometer sensor — only
`imu_sensor` and `underwater_camera`. REXROV, which *does* have one, appears to be where the
config was copied from.

**Not fixed here, because the right fix is a judgement call:**

- **Remove the bridge entry** — accurate to the model as it stands, smallest change.
- **Add a magnetometer sensor to the model** — a real BlueROV2 has one, so this is arguably
  what was intended, but it changes vehicle behaviour and belongs to whoever owns the model.

Left for upstream to decide.

## Why a smoke test could never see this

The vehicle spawns, physics runs, `odometry` and `pose` publish, and the process stays
alive for as long as you watch it. Everything a liveness check looks at is healthy. Only
subscribing to the sensor topics shows that two of them never produce a message.

That is the difference between `SMOKE PASS` and `FUNCTIONAL PASS` in this matrix, and it is
why the vehicle axis was worth closing rather than assuming REXROV generalised.

## Method notes — two errors in this script, both the same shape

**Hard-coded topic list.** The first version checked `imu / magnetometer / odometry / pose`
for every vehicle. `glider_slocum` bridges `navsat` instead of a magnetometer, so the script
looked for a sensor that does not exist and reported the vehicle as PARTIAL. Replaced by
reading each vehicle's own `robot_config.py`.

**Regex truncation.** The replacement matched `/model/{namespace}/[a-z_]*`, which stops at a
slash. The real entries are `/model/{ns}/camera/image` and
`/model/{ns}/battery/battery/state`, so it produced `camera` and `battery` — again topics
that do not exist — and marked `rexrov` and `glider_slocum` missing. Fixed by allowing `/`
in the match.

Both errors invented a missing topic and then reported it. Removing a hard-coded assumption
introduced a new one; the second was only caught by checking what the config actually
contains.

**Also fixed:** `timeout` needs `-k`. `ros2 topic echo` catches `SIGTERM` and ignores it, so
the first version hung for over 30 minutes on the second vehicle — the same signal-handling
behaviour that made the hung `ros_gz_sim create` process unkillable on 2026-08-06.

## Caveats

- n = 1 per vehicle. The IMU before/after is the exception: two vehicles measured at 0
  before the fix and all four at 1 after.
- `glider_slocum` needed two attempts. The first ended in `NOT_STEPPING` with `/stats` never
  responding; the re-run reached 6/6 with the same command and no change. Transient, cause
  not established — and a reminder that a single failed run here means "try again", not
  "the vehicle is broken".
- Only `dave_ocean_waves` was used. Whether sensor output differs by world is untested.
- Message *content* was not inspected — only that messages arrive. A topic publishing
  garbage would pass this check.
- Mac / Apple Silicon / Metal, with `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`.

## Reproduce

```bash
source ~/dave_ws_lyrical/install/setup.zsh
VEHICLES="bluerov2 bluerov2_heavy rexrov glider_slocum" bash notes/experiments/go.sh 12
```

To see the defect before the fix, revert
[`../../patches/vehicle_imu_topic_fix.diff`](../../patches/vehicle_imu_topic_fix.diff).
