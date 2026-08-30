# Combined fifth-sonar candidate + Heavy-multibeam control — Docker

## Verdict

**FAIL TO REACH THE FUNCTIONAL CHECK in one bounded derived-image run.**

This test closed the earlier “not integrated” scope gap. It started from the exact current
cache-assisted image (`lyrical-sim:jetty-rdp-external-stack-check`), live-applied the retained
fifth-ROV sonar-world candidate, rebuilt `dave_worlds`, and launched
`bluerov2_heavy_multibeam_sonar` with the ArduSub/MAVROS control stack.

The candidate itself applied and rebuilt successfully. At runtime:

- WGPU selected the Docker `llvmpipe` software adapter.
- The first 1×1×4 WGPU probe took **60053.0 ms**.
- The sonar plugin then reported **513 beams × 301 rays × 399 time bins**.
- Gazebo immediately began a stack trace in its runtime thread.
- ArduSub printed `No JSON sensor message received, resending servos` **105 times**.
- The MAVROS state probe produced no message, no PointCloud2 sample was captured, and the
  arm/control/disarm phase was never reached.

The test was stopped manually after the failure condition was established and the container was
removed. Because cleanup interrupted the process before a final exit status and complete backtrace
were captured, this evidence does **not** assign a signal, exit code, or root cause. It establishes
only that this combined Docker configuration did not reach functional sonar or vehicle control.

The separate results remain valid and must not be merged with this failure:

- the exact current image, without the fifth-sonar world candidate, passed the Heavy-multibeam
  MAVROS arm/control/disarm loop;
- the isolated fifth-sonar candidate published 513×301 PointCloud2 on Mac/Metal.

## Evidence

- [`bluerov2_heavy_multibeam_sonar/candidate_build.txt`](bluerov2_heavy_multibeam_sonar/candidate_build.txt)
  — candidate marker and successful `dave_worlds` rebuild
- [`bluerov2_heavy_multibeam_sonar/key_lines.txt`](bluerov2_heavy_multibeam_sonar/key_lines.txt)
  — selected adapter, 60-second probe, sonar dimensions, stack-trace marker, and JSON starvation
- [`bluerov2_heavy_multibeam_sonar/launch.log`](bluerov2_heavy_multibeam_sonar/launch.log)
  — retained raw launch output
- [`bluerov2_heavy_multibeam_sonar/state_probe_latest.txt`](bluerov2_heavy_multibeam_sonar/state_probe_latest.txt)
  — empty raw MAVROS state probe
- [`bluerov2_heavy_multibeam_sonar/cleanup.txt`](bluerov2_heavy_multibeam_sonar/cleanup.txt)
  — post-test container cleanup check
- [`summary.json`](summary.json) — machine-readable scoped verdict
