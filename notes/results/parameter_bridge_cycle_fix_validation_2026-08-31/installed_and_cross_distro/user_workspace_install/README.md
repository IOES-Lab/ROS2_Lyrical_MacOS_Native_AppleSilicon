# Actual user-workspace validation — 2026-08-31

## Verdict

The exact four source files from upstream PR
[`gazebosim/ros_gz#952`](https://github.com/gazebosim/ros_gz/pull/952)
were applied to the ordinary user workspace and built successfully. Two
pre-existing unrelated edits to `ros_gz_bridge/CMakeLists.txt` and
`ros_gz_sim/CMakeLists.txt` were preserved. SHA-256 comparison confirms that
the four candidate files in the workspace match the signed PR branch exactly.

For the `parameter_bridge` executable, the expanded actual-workspace checks
pass:

| Check | Result |
|---|---:|
| RelWithDebInfo build | PASS |
| Bounded payload matrix | 24/24 directions, 13 unique pairs |
| All generated factory mappings instantiated | 73/73 pairs, 146/146 direction handles |
| Generated GZ→ROS payload assertions | 73/73 |
| Ordered generated ROS→GZ payload assertions | 73/73 |
| Ordered 73-pair ROS→GZ bridge shutdown | exit 0, no escalation |
| Repeated payload runs | 5/5 payload and clean exit |
| Lifecycle-only repetitions | 11/11 clean exit |

The first stock ROS→GZ launch test started its subscriber assertions while the
bridge and publisher were still serially creating 73 endpoints. It therefore
passed only 20/73 before timing out later assertions. The retained ordered rerun
waits for all bridge endpoints before starting the generated subscriber and
passes 73/73 with subscriber rc 0 and bridge rc 0. This is a harness/startup
ordering distinction, not a conversion change.

## Full package tests and separate macOS failures

After satisfying the local Homebrew GoogleTest and Python `flake8`
dependencies, all non-launch unit and lint targets pass. The stock macOS launch
tests still expose failures outside the bounded `parameter_bridge` oracle:

- the generated GZ→ROS test completes all 73/73 payload assertions, then its
  helper process aborts during teardown with `mutex lock failed`;
- the stock generated ROS→GZ launch has the endpoint-creation race described
  above and tears the bridge down through the failing launch harness;
- an ordered component (`bridge_node`) run passes 3/3 payload assertions and
  1/1 service assertion, but the helper process aborts and `bridge_node` exits
  139 on SIGINT;
- the service assertion itself passes, but its test client also hits the same
  helper-process mutex failure after the assertion.

These results do **not** support saying that every macOS component/test-helper
shutdown path is fixed. PR #952 is scoped to the reproduced active
`parameter_bridge` owner-cycle failure; the component and helper teardown
failures remain separate follow-up scope.

## Service rerun boundary

The actual Mac workspace topic tests do not start Gazebo Sim. A local
Homebrew ABI mismatch (`gz-sim` expects FFmpeg `libswscale.9`, while the current
FFmpeg install provides `.10`) blocked a fresh actual-workspace service-world
rerun. No compatibility symlink was fabricated. The four service factories
remain directly validated in the isolated ordinary-layout run under
[`../expanded_matrix/`](../expanded_matrix/).

## Key evidence

- [`source_match_pr_candidate.txt`](source_match_pr_candidate.txt)
- [`build.log`](build.log) and [`build_rc.txt`](build_rc.txt)
- [`expanded_runtime/`](expanded_runtime/)
- [`factory_inventory/`](factory_inventory/)
- [`ordered_full_r2g/`](ordered_full_r2g/)
- [`repeat_payload_5/`](repeat_payload_5/)
- [`lifecycle_stress_11/`](lifecycle_stress_11/)
- [`ordered_component/`](ordered_component/)
- [`colcon_test_full.log`](colcon_test_full.log)
- [`flake8_rerun.log`](flake8_rerun.log)

Directories prefixed with `invalid_` are retained rejected attempts and are not
used in the verdict.
