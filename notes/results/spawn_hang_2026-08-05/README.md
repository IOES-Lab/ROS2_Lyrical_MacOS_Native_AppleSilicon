# `ros_gz_sim create` hangs; the underlying gz service works (Mac, 2026-08-05)

Three consecutive attempts to launch `dave_multibeam_sonar` produced a world with **no
sonar sensor in it**. The world ran normally — physics stepped, the main thread spent 65%
of its time in `sleep_for` throttling to real time — but the vehicle model carrying the
sonar was never spawned.

Isolated to `ros2 run ros_gz_sim create`, which blocks indefinitely. The Gazebo service it
is supposed to call is present and works when called directly.

## Evidence

The world itself is fine. Started standalone, it comes up and lists its models:

```
$ gz sim -s -r .../dave_multibeam_sonar.world &
$ gz model --list
    - ground_plane
    - basement_tank_model
    - cylinder_target1
    - cylinder_target2          <- no blueview_p900
```

The `UserCommands` system is declared in the world (line 19-20), and the services it
provides exist:

```
$ gz service -l | grep -i 'create\|remove'
/world/default/create
/world/default/create/blocking
/world/default/create_multiple
/world/default/create_multiple/blocking
/world/default/remove
/world/default/remove/blocking
```

`ros2 run ros_gz_sim create -world default -file <sdf> -name blueview_p900 -x 5.8 -z 2
-Y 3.14` never returns. It does not error and writes nothing; `Ctrl-C` is caught by
`rclcpp`'s signal handler and the process has to be killed.

The same spawn via the service directly succeeds immediately:

```
$ gz service -s /world/default/create \
    --reqtype gz.msgs.EntityFactory --reptype gz.msgs.Boolean --timeout 10000 \
    --req "sdf_filename: \"$P\", name: \"blueview_p900\", pose: {position: {x: 5.8, z: 2}}"
data: true

$ gz model --list
    ...
    - blueview_p900             <- spawned
$ gz topic -l | grep -i 'sonar\|point'
/sensor/depth_camera/points
```

## Why this matters beyond the inconvenience

**The failure is silent and it looks like success.** `ros2 launch` reports all four
processes started and then prints nothing further. Gazebo prints nothing either at default
verbosity — every log line we had been reading from these runs came from the sonar plugin,
so when the sonar is absent the log is simply empty. The world then runs at RTF ≈ 1.0
because there is no sonar to slow it down.

**Anything that measures RTF without checking that the sensor exists would record ~1.0 and
read it as a dramatic improvement.** `settle_for_sonar` caught this three times in a row —
it aborted rather than measuring. That check, added on 2026-08-03 for a different reason,
is the only thing that stopped a fabricated result from entering the record.

## What this does not explain

**It worked once.** The 15:51 profiling run had a fully live sonar —
`ComputeSonarImage` occupied an entire thread and OpenCV drawing was active. Three
subsequent runs failed. Nothing in the environment was knowingly changed between them.

So this is intermittent, and its trigger is unknown. Hypotheses tried and eliminated:

| hypothesis | how it died |
|---|---|
| `setup.zsh` sourced twice in one shell | failed identically in a fresh shell, sourced once |
| sonar plugin not loading | `MultibeamSonarSystem` is present in the stack (4 frames) |
| the sensor SDF was corrupted by `exp1b`/`exp7`'s edit-and-restore | `git status` shows `model.sdf` unmodified; values are the shipped 512/300/10 |
| the SDF is malformed XML | Python's `ElementTree` reports `unbound prefix` at line 59, but `sdformat` accepts the file and the direct spawn succeeds — the strict parser is wrong here, not the file |
| the world lacks `gz-sim-user-commands-system` | it is declared at line 19-20 and its services are live |

A stale `model.sdf.bak` from 13:21 was found and removed — left by an interrupted
`exp1b`/`exp7` run. It was not the cause (the restore had worked; `model.sdf` matches git),
but the scripts should clean it up.

## Workaround (implemented 2026-08-06)

Bypass the ROS node. Start the world with `gz sim` directly and spawn via `gz service`.

`common.sh` now provides this as a second path. Set `DIRECT=1` and every existing
experiment uses it unchanged:

```bash
DIRECT=1 bash notes/experiments/go.sh 9
```

New functions: `launch_world_direct`, `wait_for_create_service`, `spawn_sonar_direct`,
`assert_model_spawned`, `measure_once_direct`. The default path is untouched.

`wait_for_create_service` exists because spawning before the world is ready fails — the
original `create-2` node starts simultaneously with Gazebo, which is one candidate
explanation for the intermittency, though not a confirmed one.

`assert_model_spawned` checks `gz model --list` after the spawn returns. Between that and
`settle_for_sonar`, a sonar-free world can no longer be measured silently.

**This is not a drop-in substitute for the existing measurement path.** `ros2 launch` also
starts `parameter_bridge` and `static_transform_publisher`; `gz sim` alone does not. The
2026-08-05 profile showed DDS threads spinning at ~16% of busy CPU, so removing the bridge
plausibly changes RTF. **Any figure taken this way needs its own baseline and must not be
compared against the numbers recorded before today.** The warning is repeated in the
`common.sh` block itself.

## Update 2026-08-06: it got worse, and the direct path does not work either

**Failure rate rose.** 3/4 on 2026-08-05, then 3/3 on 2026-08-06 with retries enabled —
nine consecutive launches producing no model in the last attempt series. Confirmed by the
log being empty of *any* `sonar_wgpu` output: when the model does spawn, the plugin prints
its dummy warm-up frame immediately, so an empty log means no model, not a stalled sensor.

Two runs earlier the same morning did work and had the real sensor
(`513 beams × 31 rays × 399 freq`). So it remains intermittent, not permanent.

**The `DIRECT=1` path spawns successfully but cannot be measured.** `gz service` returns
`data: true` and the model appears, but `/world/default/stats` then stops publishing and did
not resume within 315 s — far beyond the 145-175 s the sonar normally takes. Before the
spawn, the same world publishes `/stats` normally (`iterations: 19176` at t=20 s).

So the direct path currently trades one blocker for another. It is left in place, unused,
because the observation that **stats publishes before the spawn and stops after it** is a
concrete lead that did not exist before.

Note `gz model --list` times out on `/world/<name>/state` **even before any spawn, on an
empty world**. That is a property of this setup, not a sonar symptom, and it is why
`assert_model_spawned` no longer treats a failed query as a missing model.

**Retrying does not currently rescue a run** — `measure_once` now retries on the spawn-hang
exit codes, and all three attempts failed the same way.

## Open

- Why it works sometimes. Not understood.
- Whether `ros_gz_sim create` hangs before or after issuing the service request — not
  traced. `sample`-ing the hung `create` process would answer this and has not been done.
- Whether this is specific to ROS 2 Lyrical, to macOS, or to this workspace. Untested
  elsewhere; not yet worth reporting upstream in this state.

## Environment

- macOS, Apple Silicon (M2), ROS 2 Lyrical + Gazebo Jetty 10.4
- `naitikpahwa18/dave`, `wgpu_integration`, pinned `6aef91c`
- `multibeam_sonar` / `multibeam_sonar_system` built `Release`; other 12 packages unoptimised
