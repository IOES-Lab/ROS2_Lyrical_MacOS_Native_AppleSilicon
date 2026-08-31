# Upstream issue draft — break the bridge-handle owner cycle

**Status:** Draft, not yet filed. The candidate is repeatedly validated in a normal Lyrical source/install overlay and equivalent ARM64 Jazzy/Kilted branch-local overlays. A read-only 2026-08-31 review found 0 duplicates across eight focused issue/PR searches and no project issue or PR template; submission, maintainer review, merge, ordinary-workspace adoption and exhaustive CI remain open.

**Suggested target repo:** [`gazebosim/ros_gz`](https://github.com/gazebosim/ros_gz), default
branch `ros2`, under `ros_gz_bridge/`.

**Suggested labels:** `bug`, `ros_gz_bridge`, `lifecycle`, `shutdown`

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
- equivalent ARM64 Jazzy and Kilted branch-local builds: 8/8 topics and 1/1 service each, bridge exit 0 without escalation.

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
launch and source-lint targets passed. Please review whether a weak node back-reference is the preferred ownership model. Humble runtime, x86_64 and exhaustive message/service configurations were not run here and remain appropriate for upstream CI.

## Evidence and patch

- Root cause, build provenance and repeated validation:
  [`../../results/parameter_bridge_cycle_fix_validation_2026-08-31/`](../../results/parameter_bridge_cycle_fix_validation_2026-08-31/)
- Focused baseline matrix and rejected shutdown candidates:
  [`../../results/parameter_bridge_shutdown_validation_2026-08-31/`](../../results/parameter_bridge_shutdown_validation_2026-08-31/)
- Candidate diff:
  [`../../../patches/ros_gz_bridge_handle_cycle_fix.diff`](../../../patches/ros_gz_bridge_handle_cycle_fix.diff)

## Environment

- ROS 2 Lyrical, Gazebo Jetty 10.4, ARM64 Docker Desktop on Apple M2
- Fast DDS over UDPv4 for the retained repetitions
- isolated normal-install and release-branch overlays; original source and ordinary installed workspace unchanged
- official ARM64 ROS images for Jazzy and Kilted; Humble adaptation static-only
