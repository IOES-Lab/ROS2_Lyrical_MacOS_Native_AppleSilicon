# `parameter_bridge` active-endpoint shutdown validation (2026-08-31)

## Verdict

The bridge publishes valid data during runtime, but its teardown defect is reproducible when
active Gazebo/ROS endpoints have existed. The same bridge commands with no active Gazebo
publishers exited cleanly **40/40**. With the sonar active, none of the tested mitigations
eliminated the crash.

| Control | Result |
|---|---:|
| Standalone, no active publishers, four argument/direction cases | 0/40 SIGSEGV |
| One-way GZ→ROS, process-group shutdown | 9/10 SIGSEGV |
| Bridge first, SIGINT | 4/10 SIGSEGV |
| Bridge first, SIGTERM | 4/10 SIGSEGV |
| Process-group shutdown with `TRACETOOLS_RUNTIME_DISABLE=1` | 7/20 SIGSEGV |
| Simulator first, 5 s wait, then bridge | 2/10 SIGSEGV |
| Simulator first, 20 s wait, then bridge | 3/10 SIGSEGV |
| GDB, ordinary active one-way bridge | 9/10 SIGSEGV |
| GDB, explicit tracing disable in the inferior | 8/10 SIGSEGV |
| Stock camera publisher, bridge first | 0/10 SIGSEGV |
| Stock GPU lidar (640×16), bridge first | 0/10 SIGSEGV |
| Stock GPU lidar reshaped to 513×301, bridge first | 0/10 SIGSEGV |
| DAVE sonar, PointCloud2 bridge only, bridge first | 2/10 SIGSEGV |
| Explicit node-reset/shutdown candidate, bridge first | 6/20 SIGSEGV |
| Explicit node-reset/shutdown candidate, process-group shutdown | 6/10 SIGSEGV |

Every DAVE-sonar active-launch series reached backend-ready and captured populated **513×301
PointCloud2** plus **513×399 raw sonar** before teardown. This is therefore a teardown defect,
not a sonar-runtime failure.

## What the controls rule out

- Bidirectional bridge syntax is not required: the crash remains with GZ→ROS-only arguments.
- SIGTERM instead of SIGINT is not a fix.
- `TRACETOOLS_RUNTIME_DISABLE=1` is not a fix. GDB logs explicitly print `ROS 2 tracing
  disabled`, yet the crash remains.
- Stopping Gazebo first reduces the observed rate in these bounded samples but does not make
  teardown reliable, even after 20 seconds.
- A generic active camera or GPU-lidar publisher is not sufficient. The official stock
  point-cloud control is 10/10 clean both at 640×16 and after reshaping it to 513×301, while
  a DAVE-sonar PointCloud2-only bridge still crashes 2/10. The sonar dimensions alone are
  therefore not the discriminator.
- Explicitly destroying the bridge node and calling `rclcpp::shutdown()` after `spin()` is
  **not a fix**. A focused rebuild from official `ros_gz_bridge` tag 3.0.9 still crashes 6/20
  when the bridge is stopped first and 6/10 under process-group shutdown.
- The installed image has only `rmw_fastrtps_cpp`; an alternate-RMW comparison was not
  executable without changing the environment.

## GDB bound

The crashing thread is often named `dds.ev.0` or `dds.udp.*`; the main thread is concurrently
inside process finalization (`_dl_fini`) and a `libtracetools.so` destructor/`dlclose` path. Some
crash-thread stacks are already corrupt. Because explicit tracing disable still crashes 8/10,
this locates a dynamic-unload / DDS-thread teardown window but **does not prove that
`tracetools` owns the root cause**.

## Evidence map

- `standalone/summary.tsv`: 40 no-publisher controls.
- `active_oneway_10/summary.tsv`: one-way active process-group shutdown.
- `active_oneway_bridge_first_10/summary.tsv`: bridge-first SIGINT.
- `active_oneway_bridge_first_sigterm_10/summary.tsv`: bridge-first SIGTERM.
- `active_oneway_tracing_disabled_20/summary.tsv`: runtime tracing-disable control.
- `active_oneway_simulator_first_delay5_10/summary.tsv` and
  `active_oneway_simulator_first_delay20_10/summary.tsv`: ordered teardown controls.
- `gdb_active_oneway_10/` and `gdb_active_oneway_tracing_disabled_explicit_10/`:
  repeated debugger backtraces.
- `stock_camera_bridge_first_10/`, `stock_pointcloud_bridge_first_10/`, and
  `stock_pointcloud_513x301_bridge_first_10/`: active stock-sensor controls.
- `active_sonar_point_only_bridge_first_10/`: DAVE sonar with only the point-cloud bridge.
- `explicit_cleanup_candidate/`: official-3.0.9 focused rebuild, patch, binary hashes, and
  the two repeated rejection series.
- `summary.json`: machine-readable totals and package versions.

No upstream or installed fix is claimed. SIGKILL can avoid destructor execution but is not a
graceful fix and was not promoted as one.
