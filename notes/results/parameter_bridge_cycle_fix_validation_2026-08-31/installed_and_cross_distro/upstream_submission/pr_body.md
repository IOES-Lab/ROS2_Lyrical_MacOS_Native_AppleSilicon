## Summary

Fixes #951.

`RosGzBridge` owns each `BridgeHandle` through `shared_ptr`, while each handle
currently retains a `shared_ptr` back to the owning node. This patch changes
only that back-reference to `rclcpp::Node::WeakPtr` and locks it at the call
sites that need node access.

The node continues to own its handles strongly, but handles no longer keep the
node and its middleware endpoints alive after `rclcpp::spin()` returns.

## Changes

- store the owner node as `rclcpp::Node::WeakPtr` in publisher, subscription and
  service bridge handles;
- lock the weak reference before using node APIs;
- handle an expired owner without dereferencing it;
- keep the existing public factory inputs and node-to-handle ownership.

## Validation

The original failure was reproduced against exact `ros_gz` 3.0.9. The same
four-file ownership change was then validated on this current `ros2` branch:

- DAVE sonar bridge-first shutdown: payloads 20/20, bridge clean 20/20;
- DAVE sonar process-group shutdown: payloads 10/10, launch rc 0 in 10/10;
- direct ROS→GZ String: payload and clean exit 20/20;
- active stock camera and PointCloud GZ→ROS: 5/5 each;
- official ARM64 Humble, Jazzy and Kilted source builds: 8/8 topic directions
  plus 1/1 service each, clean bridge exit;
- Jazzy `linux/amd64` under Docker Desktop emulation: 8/8 topic directions plus
  1/1 service, clean bridge exit;
- ordinary-layout isolated clone: 24/24 topic directions across 13 unique type
  pairs and 4/4 service factories;
- the candidate applied cleanly to the ordinary user workspace while preserving
  two pre-existing unrelated CMake edits, and `ros_gz_bridge` built successfully;
- all 73 generated topic mapping pairs were instantiated in both directions:
  73/73 GZ→ROS generated payload assertions and, after waiting for all generated
  endpoints before starting assertions, 73/73 ROS→GZ payload assertions;
- the ordered 73-pair ROS→GZ run shut `parameter_bridge` down with exit 0 and no
  escalation; five repeated payload runs and eleven lifecycle-only runs also
  exited cleanly.

The package's non-launch unit and lint targets passed after satisfying local
test dependencies. The stock macOS launch-test harness still exposes separate
startup-order and test-client teardown failures (`mutex lock failed` and a
component shutdown context error). An ordered component run passed its three
payload assertions and one service assertion, but `bridge_node` still exited
139 on SIGINT. These component/test-helper failures remain separate open scope;
the ordered `parameter_bridge` conversion oracle itself exits cleanly and this
patch does not claim to fix every macOS component shutdown path.

## Scope

The matrix covers every generated mapping registered by this checkout, but it
is still bounded. Native x86_64 hardware, Windows, hardware GPU paths and the
full upstream CI matrix remain appropriate maintainer / CI scope.
