# USBL direct validation — 2026-08-27

## Verdict

**FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS.**

The two-transponder tutorial's common and individual interrogation paths were
directly exercised on both macOS and Docker under ROS 2 Lyrical + Gazebo Jetty.
Both the spherical `dave_interfaces/msg/Location` stream and the transceiver's
Cartesian companion stream were checked.

This verdict is scoped. It establishes ROS/Gazebo routing and static tutorial
geometry, not general USBL acoustic or travel-time accuracy.

The DAVE workspaces were based on commit
`6aef91c823af5da073329b84ba617b572965e79e` and were not pristine. Controlled
worlds and the test client were kept in this evidence directory; the DAVE
checkout was not modified by this validation.

## Direct results

| Test | macOS | Docker |
|---|---|---|
| Controlled common mode, `sigma=0.0001` | 6 spherical + 6 Cartesian samples, IDs 1 and 2 | 6 spherical + 6 Cartesian samples, IDs 1 and 2 |
| Controlled individual channel 1 | 3 + 3 samples, ID 1 only | 3 + 3 samples, ID 1 only |
| Controlled individual channel 2 | 3 + 3 samples, ID 2 only | 3 + 3 samples, ID 2 only |
| Unexpected IDs | none | none |
| Paused simulation | graph endpoints exist, 0 output samples | graph endpoints exist, 0 output samples |
| Literal `sigma=0` | both IDs return finite data | Gazebo server aborts, exit 134 |
| Corrected world launcher | common output verified, no missing-model error | common output verified, no missing-model error |

Across all retained positive-sigma runs, the largest observed Cartesian axis
difference from the static tutorial coordinates was
`0.00025795250425891814 m` (about `0.258 mm`). This is a small-sample
observation under `sigma=0.0001`, not an accuracy specification.

## Wiki Quickstart defect

The previous Wiki command used the generic sensor launcher:

```bash
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=usbl world_name:=usbl_tutorial paused:=false
```

The USBL systems are already embedded in `usbl_tutorial.world`; there is no
`dave_sensor_models/description/usbl/model.sdf`. On both platforms the old
command still produced USBL data from the embedded world plugins, but it also
logged an error while repeatedly trying to spawn that nonexistent sensor
model. Output alone therefore did not prove that the Quickstart was correct.

The directly verified replacement is:

```bash
ros2 launch dave_demos dave_world.launch.py \
  world_name:=usbl_tutorial
```

The world launcher includes `-r`, so the simulation runs without the
`paused:=false` sensor-launch workaround. It produced common-mode output on
both platforms and did not attempt the nonexistent model spawn.

For a portable server-only run without relying on the local headless launch
patch:

```bash
gz sim -s -r \
  "$(ros2 pkg prefix dave_worlds)/share/dave_worlds/worlds/usbl_tutorial.world"
```

## Paused-state behavior

With the same USBL graph endpoints discovered but the simulation left paused,
common-mode triggers produced zero spherical and zero Cartesian samples on
both platforms. Source inspection explains the observation: both USBL
`PostUpdate` methods call `rclcpp::spin_some()` only when
`UpdateInfo::paused` is false.

This is not a DDS discovery failure. The endpoints can be matched while no ROS
subscription callback is being pumped.

## `sigma=0` is platform-dependent

A literal zero standard deviation is not portable in the current plugin:

- macOS/libc++ accepted it and both transponders returned finite, effectively
  exact coordinates in this run;
- Docker/libstdc++ aborted the Gazebo server on the first ping with
  `_M_stddev > _RealType(0)` and exit code 134.

The macOS success does not close the defect. A plugin-level guard should return
the mean directly when `sigma == 0` and reject negative values instead of
constructing `std::normal_distribution` unconditionally.

## Evidence map

- [`01_controlled_mac/`](01_controlled_mac/) — common and both individual paths
- [`02_wiki_quickstart_mac/`](02_wiki_quickstart_mac/) — old Quickstart output plus missing-model errors
- [`03_paused_mac/`](03_paused_mac/) — matched graph, zero output while paused
- [`04_sigma_zero_mac/`](04_sigma_zero_mac/) — libc++ zero-sigma behavior
- [`05_corrected_world_launch_mac/`](05_corrected_world_launch_mac/) — corrected launcher
- [`docker/01_controlled_docker/`](docker/01_controlled_docker/) — common and both individual paths
- [`docker/02_wiki_quickstart_docker/`](docker/02_wiki_quickstart_docker/) — old Quickstart output plus missing-model error
- [`docker/03_paused_docker/`](docker/03_paused_docker/) — matched graph, zero output while paused
- [`docker/04_sigma_zero_docker/`](docker/04_sigma_zero_docker/) — libstdc++ abort and exit 134
- [`docker/05_corrected_world_launch_docker/`](docker/05_corrected_world_launch_docker/) — corrected launcher
- [`test_assets/`](test_assets/) — controlled worlds, client and summary generator
- [`source/`](source/) — source snapshots, commit and working-tree status
- [`summary.json`](summary.json) — machine-readable verdict

## Limits

- Three samples per transponder and trigger path in each controlled
  positive-sigma platform run.
- Static transceiver and transponders only.
- No independent acoustic propagation, travel-time, multipath or moving-target
  ground truth.
- No long-duration, multi-transceiver or namespace-isolation test.
- No upstream code or documentation fix was submitted.
