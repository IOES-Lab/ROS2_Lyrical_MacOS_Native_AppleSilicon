# External-stack validation — 2026-08-29

This directory closes the locally executable part of the BlueROV2 external-stack gap. The tested
path is Ubuntu 26.04 `aarch64` in Docker Desktop on an Apple M2 host, ROS 2 Lyrical, Gazebo Jetty,
ArduSub `30257f01185471ab4c1ac544e47d1b4437e44c98`, and the official ArduPilot Gazebo plugin at
`082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5`.

The upstream DAVE checkout and installed workspace were kept read-only. The DAVE command change is
retained only as [`../../../patches/bluerov2_ardusub_speedup_fix.diff`](../../../patches/bluerov2_ardusub_speedup_fix.diff),
and the Docker dependency changes are in [`../../../docker/lyrical.arm64v8.dockerfile`](../../../docker/lyrical.arm64v8.dockerfile).

## Verdicts

| Check | Result | Direct observation |
|---|---|---|
| Official ArduPilot Gazebo plugin on Lyrical/Jetty arm64 | **PASS** | The isolated build and current Dockerfile build use the same pinned source commit. Their binaries differ by build configuration: SHA-256 `89f146…a75d` (isolated build) and `93c9e8…ca59` (current recipe); both have resolved Jetty dependencies |
| Original ArduSub launch after JSON input starts | **FAIL reproduced** | ArduSub received Gazebo JSON sensor frames and then raised `SIGFPE` in `AP_Logger_File::periodic_1Hz()` |
| Explicit `--speedup 1` candidate | **PASS in tested scope** | The patch applies on top of the previous nine-candidate snapshot; all three edited Python files compile; the baseline BlueROV2 runtime no longer raised the FPE |
| ArduSub ↔ MAVROS | **FUNCTIONAL PASS** | Four of four spaced state samples were connected; no heartbeat loss was recorded |
| BlueROV2 simulated control | **FUNCTIONAL PASS in one run** | MANUAL mode, forced arm, six seconds of non-neutral manual control, X odometry `−0.0000035 → 2.182961 m`, final `vx=0.792826 m/s`, then successful disarm |
| BlueROV2 Heavy simulated control | **FUNCTIONAL PASS in one run** | Four of four spaced MAVROS samples were connected; MANUAL force-arm reached `armed: true`, six seconds of non-neutral manual control moved X odometry `0.000158 → 2.375837 m`, and disarm succeeded |
| QGroundControl default AppRun | **FAIL** | The retained arm64 DailyBuild exited 139 under a clean X11 start |
| QGroundControl with its supported GLib opt-out | **PASS in bounded/integrated scope** | `QGC_NO_SYSTEM_GLIB=1` survived a clean 45-second control and connected to the live BlueROV2 stack; the GUI showed `Ready`, `100%`, `Manual`, and the ArduSub 4.5.7 firmware warning |
| Current Dockerfile recipe | **PASS, cache-assisted end to end** | The full current recipe completed in 44.86 minutes and produced image `af9586fa8045` (23.9 GB). ROS/Gazebo packages, source pins, three installed speedup edits, QGC environment and user tooling passed. This was not a fresh `--no-cache` build |
| Exact current image — all three BlueROV variants | **FUNCTIONAL PASS in one headless run each** | Baseline, Heavy and Heavy-multibeam each retained 4/4 connected MAVROS samples, armed, accepted six seconds of manual control, moved X by +1.697915 m, +1.125856 m and +0.818825 m respectively, then disarmed; no plugin-missing error or ArduSub FPE occurred |
| Exact current image — xrdp service | **SMOKE PASS** | The default container command stayed up, bound xrdp to an ephemeral localhost port and ran `xrdp`, `xrdp-sesman`, D-Bus and sshd. This is service liveness, not an RDP login or rendered-desktop check |
| Exact current image — QGroundControl opt-out offscreen | **20-second process-survival PASS** | With `QGC_NO_SYSTEM_GLIB=1`, clean XDG directories and Qt offscreen, the process survived until `timeout` returned 124. OpenGL/text-to-speech warnings remained. This is not visible GUI or vehicle-connection evidence |
| Derived image — fifth-sonar candidate + Heavy-multibeam control | **FAIL TO REACH FUNCTIONAL CHECK** | The candidate applied and `dave_worlds` rebuilt. WGPU selected `llvmpipe`; its first 1×1×4 probe took 60053 ms and the sonar reported 513×301×399, then Gazebo began a stack trace. ArduSub logged 105 no-JSON warnings; MAVROS state, PointCloud2 and control were not reached. Manual cleanup means no exit code or root cause is assigned |

The normal arm service was acknowledged but did not change the armed state. The retained run used
the explicit force-arm command (`MAV_CMD_COMPONENT_ARM_DISARM`, magic value `21196`) before publishing
manual control. This is why the result is a functional simulation check, not a safe real-vehicle
arming procedure.

## ArduSub failure boundary

GDB placed the pre-fix exception in `AP_Logger_File::periodic_1Hz()`. The tested ArduSub source sets
SITL `SIM_SPEEDUP` to `-1` by default, while `io_thread_alive()` multiplies an unsigned millisecond
timeout by `sitl->speedup`. Passing `--speedup 1` removes that invalid boundary in this arm64 run.
The retained evidence supports this source/runtime boundary; it does not claim that every possible
`SIGFPE` in ArduSub has the same cause.

## Environment boundaries measured, not inferred

- Docker had no `/dev/dri`, no NVIDIA device request and no `nvidia-smi`; `glxinfo` reported
  `llvmpipe` and `Accelerated: no`.
- The host is macOS on Apple M2 / Metal 3. No Windows, WSL or Wine executable was present.
- No local Gazebo Fuel authentication file or token was found, so no account upload was attempted.
- The sanitized USB/HID inventory contained no external gamepad, Pixhawk/Cube or common USB-serial
  HIL adapter. Serial numbers were deliberately omitted from the committed evidence.

These are **BLOCKED prerequisites**, not product failures.

## Scope limits

- The earlier lineage-container controls cover baseline BlueROV2 and BlueROV2 Heavy. The exact
  newly built current image then completed one additional arm/control/disarm run for all three
  variants, including Heavy multibeam. A later derived-image run did combine the ninth sonar-world
  candidate, but failed after slow `llvmpipe` WGPU startup and a Gazebo stack trace, before JSON/MAVROS,
  PointCloud2 or control. The separate control and Mac-sonar PASS results remain valid only in their
  original scopes.
- The current Dockerfile completed a cache-assisted end-to-end build. A fresh `--no-cache` rebuild
  was not run: only about 57 GiB remained at the decision point while Docker images and cache occupied about 186 GiB, and
  deleting unrelated user assets solely to force a clean build would have been destructive. The
  2026-07-18 clean build remains the clean-build provenance baseline.
- The exact current image passed non-visual xrdp-service startup and a 20-second QGroundControl
  offscreen survival check. Its RDP login, rendered desktop, QGroundControl GUI and vehicle
  connection were not re-clicked-through; the retained visual/connection result comes from the
  separate integrated control.
- Odometry response establishes a working simulated control chain. It does not validate controller
  tuning, thruster calibration, safety, real-vehicle behavior or long-duration stability.
- No NVIDIA CUDA/hardware-GPU, Windows/WSL, physical HIL/gamepad, Fuel upload or broad scientific
  accuracy claim is made here.
- The QGroundControl workaround is required for the retained DailyBuild artifact; default AppRun
  behavior remains a reproduced crash.

## Evidence map

- [`ardupilot_gazebo/`](ardupilot_gazebo/) — pin, configure/build output, artifact metadata and hash
- [`ardusub_fpe/`](ardusub_fpe/) — GDB excerpt, relevant source, patch/apply/compile checks
- [`bluerov2_control/`](bluerov2_control/) — connection samples, mode/arm/control/disarm and odometry
- [`bluerov2_heavy_control/`](bluerov2_heavy_control/) — the same bounded sequence on BlueROV2 Heavy
- [`qgroundcontrol/`](qgroundcontrol/) — default-crash and workaround controls plus screenshots
- [`environment/`](environment/) — Docker GPU, host/Windows, Fuel and sanitized hardware boundaries
- [`dockerfile/`](dockerfile/) — current recipe build/image checks, exact-image three-variant full-control runs, xrdp/QGC smokes and the combined sonar/control failure
- [`dockerfile/combined_sonar_control/`](dockerfile/combined_sonar_control/) — direct derived-image integration attempt and scoped failure evidence
- [`summary.json`](summary.json) — machine-readable scoped summary
