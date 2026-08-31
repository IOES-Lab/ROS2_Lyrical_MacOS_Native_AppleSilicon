# Upstream issue draft — break the bridge-handle owner cycle

**Status:** Filed as [`gazebosim/ros_gz#951`](https://github.com/gazebosim/ros_gz/issues/951) on 2026-08-31 by explicit user request; the signed fix is open as [`gazebosim/ros_gz#952`](https://github.com/gazebosim/ros_gz/pull/952). DCO passes and GitHub reports the PR mergeable; maintainer review and merge are pending. The candidate is validated in normal Lyrical, official-image ARM64 Humble/Jazzy/Kilted, Jazzy `linux/amd64` emulation, an ordinary isolated clone and the actual user workspace. The requested `bug` and `ROS 2` labels could not be applied by the external contributor account. Native x86_64 hardware, Windows and the separate macOS component/test-helper teardown remain open.

**Suggested target repo:** [`gazebosim/ros_gz`](https://github.com/gazebosim/ros_gz), default
branch `ros2`, under `ros_gz_bridge/`.

**Suggested labels:** `bug`, `ROS 2` (both confirmed to exist on 2026-08-31)

---

## Title

Break the RosGzBridge–BridgeHandle ownership cycle before middleware teardown

## Summary

`RosGzBridge` owns bridge handles in a vector of `shared_ptr`, while each `BridgeHandle` stores a
`shared_ptr` back to the owning `rclcpp::Node`. This forms a strong-reference cycle:

```text
RosGzBridge node -> handles_ -> BridgeHandle -> ros_node_ -> RosGzBridge node
```

After `rclcpp::spin()` returns, resetting the local node pointer does not destroy the node, its
handles or their middleware endpoints. In the active DAVE-sonar reproduction, process finalization
then intermittently reaches Fast DDS / shared-library teardown with those objects still alive and
`parameter_bridge` exits with SIGSEGV.

The candidate changes only the handle-to-owner back-reference to `rclcpp::Node::WeakPtr` and locks
it at the small number of sites that need node access. Node-to-handle ownership remains strong.

## Reproduction boundary

On ROS 2 Lyrical / Gazebo Jetty in fresh ARM64 Docker containers:

- standalone no-publisher bridge controls exited cleanly 40/40;
- active stock camera / PointCloud controls exited cleanly 30/30;
- active one-way DAVE-sonar process-group shutdown produced `parameter_bridge` exit `-11` in 9/10;
- a PointCloud-only bridge-first variant produced exit `-11` in 2/10.

Every failing DAVE run had already delivered its PointCloud / raw-sonar payload before shutdown.
Signal recipient, shutdown ordering, tracing disable and an explicit local-node reset did not give
a reliable fix.

## Candidate validation

Built from exact release tag `3.0.9`, commit
`2d17974dd4aec749e22824f74baa22149aaf5b4d`:

- DAVE sonar, stop bridge first: PointCloud2 20/20, raw sonar 20/20, bridge clean 20/20,
  exit `-11` 0/20;
- DAVE sonar, process-group shutdown: both payloads 10/10, launch rc0 10/10,
  bridge exit `-11` 0/10;
- direct ROS→GZ String payload and clean shutdown: 20/20;
- active stock camera GZ→ROS: payload and clean shutdown 5/5;
- active stock PointCloud GZ→ROS: payload and clean shutdown 5/5;
- normal Lyrical source/install overlay: 8/8 topic conversions, 1/1 ControlWorld service, active bidirectional teardown 10/10;
- equivalent official-image ARM64 Humble, Jazzy and Kilted branch-local builds: 8/8 topics and 1/1 service each, bridge exit 0 without escalation;
- Jazzy `linux/amd64` under Docker Desktop emulation: fresh build, 8/8 topics and 1/1 service, bridge exit 0;
- ordinary-layout isolated exact-3.0.9 clone: 24/24 conversion directions across 13 unique topic type pairs and all four service factories, with the user's workspace unchanged;
- actual user `ros_gz` workspace: candidate files match the signed PR 4/4 while two unrelated CMake edits remain preserved; build PASS, 24/24 bounded directions, all 73 generated mapping payload assertions 73/73 each way, ordered bridge rc0, repeat payload 5/5 and lifecycle 11/11.

The candidate executable was verified to load `libros_gz_bridge.so` from the isolated overlay.
The patch reconstructs the four modified files exactly. Current upstream `ros2` commit `2ee8a5c`
still has both strong references, and the same patch passes `git apply --check` there.

## Invalid attempts excluded from the result

One exploratory harness signalled a `ros2 run` process group, delivering SIGINT to both the wrapper
and its child. Failing logs contain two signal-handler records, so those rows are excluded. Another
combined-direction CLI harness was interrupted after a discovery miss left a timeout wrapper
waiting on a defunct child. Valid tests launch the candidate executable directly and separate the
direction-specific oracles.

## Scope and requested review

This is a minimal ownership change, but the retained evidence is not a substitute for upstream CI.
The constrained Lyrical package build completed and 17/18 CTest targets passed. The only failed
target was `xmllint`, which timed out while downloading the remote ROS package schema; the exact
unmodified `package.xml` passed against the canonical schema supplied locally, and all compiled,
launch and source-lint targets passed. Please review whether a weak node back-reference is the preferred ownership model. ARM64 Humble runtime and Jazzy `linux/amd64` emulation were run successfully; the isolated service matrix covered 4/4 factories; and the actual user workspace passed all 73 generated topic mappings in both directions. Native x86_64 hardware, Windows and the full upstream CI matrix remain appropriate follow-up scope. Separately, an ordered macOS `bridge_node` test passes 3/3 topic and 1/1 service assertions before the test helper aborts and the component exits 139 on SIGINT; PR #952 does not claim that separate component/test-helper path is fixed.

## Evidence and patch

- Root cause, build provenance and repeated validation:
  [`../../results/parameter_bridge_cycle_fix_validation_2026-08-31/`](../../results/parameter_bridge_cycle_fix_validation_2026-08-31/)
- Focused baseline matrix and rejected shutdown candidates:
  [`../../results/parameter_bridge_shutdown_validation_2026-08-31/`](../../results/parameter_bridge_shutdown_validation_2026-08-31/)
- Candidate diff:
  [`../../../patches/ros_gz_bridge_handle_cycle_fix.diff`](../../../patches/ros_gz_bridge_handle_cycle_fix.diff)
- Signed upstream PR (DCO PASS; maintainer review pending):
  [`gazebosim/ros_gz#952`](https://github.com/gazebosim/ros_gz/pull/952)
- Fork branch:
  [`yeseorizi:fix/bridge-handle-owner-cycle`](https://github.com/yeseorizi/ros_gz/tree/fix/bridge-handle-owner-cycle)
- Upstream compare / PR form:
  [`ros2...yeseorizi:fix/bridge-handle-owner-cycle`](https://github.com/gazebosim/ros_gz/compare/ros2...yeseorizi:ros_gz:fix/bridge-handle-owner-cycle?expand=1)

## Environment

- ROS 2 Lyrical, Gazebo Jetty 10.4, ARM64 Docker Desktop on Apple M2
- Fast DDS over UDPv4 for the retained repetitions
- isolated normal-install, ordinary-layout clone and release-branch overlays; the actual user workspace now contains the exact four-file candidate while preserving two unrelated CMake edits
- official ARM64 ROS images for Humble, Jazzy and Kilted
- official Jazzy `linux/amd64` image under Docker Desktop emulation on Apple M2
