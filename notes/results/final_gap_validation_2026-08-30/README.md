# Final gap validation — 2026-08-30

This directory records the remaining locally executable checks after the DAVE Wiki and
repository audit. Verdicts are intentionally scoped to what each test measured.

| Area | Current result |
|---|---|
| Combined Heavy + multibeam | **Backend-dependent:** software-WGPU/llvmpipe exits 139; forced CPU publishes sonar and completes vehicle control |
| Native macOS DVL | Stock world crash root-caused in Gazebo sensor initialization; hidden standard-camera initializer is an actionable PASS workaround, not an upstream fix |
| Native macOS RViz | Still **open**; main Cocoa window remains offscreen despite Qt controls and tested candidate fixes |
| Fast DDS create path | **18/18 current successes**; stale SHM was cleaned, but the historical hang's cause was not reproduced |
| Underwater Camera exact startup | **6/6 PASS** with 120-second windows; old short-window failure is superseded by measured latency |
| Exact cache image RDP/QGC | Windows App login, XFCE framebuffer, Gazebo and connected QGC **PASS** |
| Current recipe fresh build | `--no-cache` build, package/pin verification, real FreeRDP/xrdp login, XFCE framebuffer, Gazebo and connected QGC **PASS** |

Subdirectories contain raw logs, machine-readable summaries, source excerpts and retained
framebuffer captures. `remaining_external_validation_plan.md` gives official procedures
for the checks that cannot be honestly completed on this Apple-M2 host: NVIDIA/CUDA or
hardware WGPU, Windows/WSL, physical HIL, authenticated Fuel upload/version flow and
physical/scientific validation.

No result here turns software functionality into a claim of general physical accuracy.
