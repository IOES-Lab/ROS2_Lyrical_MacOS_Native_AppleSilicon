# Dave Glider Models direct validation — 2026-08-27

## Verdict

**FUNCTIONAL PASS in the directly tested Wiki-launch and state/sensor scope; actuator coverage is PARTIAL.**

Both Wiki examples were launched in the Docker RDP environment:

```bash
ros2 launch dave_demos dave_robot.launch.py \
  z:=0.2 namespace:=glider_slocum world_name:=empty.sdf paused:=false

ros2 launch dave_demos dave_robot.launch.py \
  x:=4 z:=-1.5 namespace:=glider_slocum \
  world_name:=dave_ocean_waves paused:=false
```

The model spawned and all **nine** topics configured by
`glider_slocum/robot_config.py` were listed in each Docker case. Those nine
are six state/sensor paths plus three propeller-joint paths.

## Corrected scope of the earlier `6/6`

The 2026-08-07 test helper ended its extracted topic list with
`grep -v '^joint'`. Therefore its `6/6` covered only:

- battery state
- NavSat
- odometry
- odometry with covariance
- pose
- IMU

It did **not** test `cmd_thrust`, `ang_vel`, or `enable_deadband`. Earlier
wording that described the six as including a thruster is withdrawn.

## As-shipped versus local IMU patch

| Docker case | Six state/sensor outputs | IMU |
|---|---:|---|
| `empty.sdf`, as shipped | 5/6 | listed, no message before timeout |
| `dave_ocean_waves`, local `<topic>` patch | 6/6 | message received |

The as-shipped ocean run also kept the IMU silent. Its first battery probe
ran before the message type became discoverable, so that one run is not used
as a six-topic denominator. The exact `empty.sdf` run provides the clean
as-shipped 5/6 comparison.

## Propeller command

In the patched Docker ocean run, publishing ROS `cmd_thrust = 25.0` was
observed on Gazebo as `data: 25`. The Gazebo propeller angular-velocity stream
changed from `-0` to `55776.343531645027`.

This is direct evidence that the command crosses the bridge and reaches the
actuator path. The magnitude is **not** treated as proof of physical accuracy.

## `enable_deadband` boundary

A focused integrated test produced an asymmetric result:

- Gazebo `true` -> ROS `true`: **PASS**
- ROS `true` -> Gazebo echo: **not observed**, timeout exit 124

The same `std_msgs/msg/Bool` <-> `gz.msgs.Boolean` bridge passed both
directions on an isolated topic. Thus the generic Bool converter works, but
the integrated glider ROS-command path remains unresolved.

The earlier one-byte Gazebo capture after publishing `false` is not promoted
to a pass: protobuf text output can omit a default-valued field, and that run
did not retain the command exit status needed to discriminate receipt from a
timeout.

## Mac retest

Fresh Mac attempts for both Wiki examples created the world/model or bridge
processes but did not produce advancing `/stats` or model data, including
after an explicit unpause of `empty.sdf`. They are recorded as transient
`NOT_STEPPING` / inconclusive attempts and are not used as the current
functional proof. This does not erase the earlier successful patched Mac run;
the current direct functional evidence comes from Docker.

## Evidence map

- [`docker/01_docker_ocean_as_shipped/`](docker/01_docker_ocean_as_shipped/) — as-shipped ocean case
- [`docker/02_docker_ocean_patched/`](docker/02_docker_ocean_patched/) — ocean case with local IMU-topic overlay
- [`docker/03_docker_empty_as_shipped/`](docker/03_docker_empty_as_shipped/) — exact as-shipped empty-world example
- [`docker/07_docker_patched_deadband_retest/`](docker/07_docker_patched_deadband_retest/) — repeated thrust response
- [`docker/08_docker_deadband_bidirectional/`](docker/08_docker_deadband_bidirectional/) — integrated deadband directions
- [`docker/09_docker_bool_bridge_isolation/`](docker/09_docker_bool_bridge_isolation/) — isolated Bool bridge control
- `01_mac_*` and `02_mac_*` — inconclusive Mac attempts
- [`source/previous_exp12_method_excerpt.sh`](source/previous_exp12_method_excerpt.sh) — the joint-excluding 6/6 method
- [`summary.json`](summary.json) — machine-readable verdict

## Limits

This establishes launch, publication, bridge and one actuator-response path.
It does not establish actuator calibration, hydrodynamic accuracy, navigation
performance, battery depletion, long-duration stability, or real-glider
behaviour.
