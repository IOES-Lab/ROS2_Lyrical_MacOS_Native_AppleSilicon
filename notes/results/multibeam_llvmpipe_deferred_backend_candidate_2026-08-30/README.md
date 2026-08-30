# Multibeam llvmpipe / OGRE2 deferred-backend candidate — 2026-08-30

## Verdict

**VALIDATED ISOLATED CANDIDATE.** The current distributed/installed path still reproduces the
Docker software-WGPU crash. The retained candidate changes startup ordering; it is not installed
into the user's DAVE workspace, submitted, reviewed, or merged upstream.

The minimal baseline needs neither BlueROV2, ArduSub nor MAVROS: WGPU selects Vulkan
`llvmpipe`, then Gazebo exits 139 with the OGRE2 sample-texture/null-`memcpy` stack. This scopes
the trigger to the sonar/render/backend startup interaction rather than the vehicle stack.

## Candidate

[`candidate.patch`](candidate.patch) makes two startup changes:

1. remove compute-backend construction and probe execution from sonar beam/render initialization;
2. create and initialize that backend on the existing sonar compute thread only after a `GpuRays`
   frame has populated the depth image.

The sonar declares no runtime ROS parameters, so the candidate also disables its unused ROS
parameter services and parameter-event publisher during startup. This second change was needed
to keep the isolated macOS plugin startup from loading optional dynamic typesupport endpoints
while Gazebo's sensor graph was still initializing.

Patch SHA-256:

```text
5a8fed3ef1af590c3fd6e5b22a8fa39ba13c7849714aa174a887c57c81bc2a6e
```

A fresh reconstruction from the retained baseline matched the candidate tree exactly.
`multibeam_sonar_system` built in Release on Mac and Docker. The package currently declares no
tests; `colcon test-result` therefore reports 0 tests, 0 errors and 0 failures rather than a
runtime PASS.

## Rejected candidate

A third prototype created the backend on the **render callback thread** after an initialized ray
frame. That sounded closer to the original thread affinity, but Docker still reached the
llvmpipe/OGRE2 SIGSEGV and emitted no retained payload. It is preserved under
[`v3_rejected/`](v3_rejected/) so a failed prototype is not silently promoted into the final
explanation.

## Docker regression matrix

The accepted candidate was frozen as image
`sha256:9a419bd753cfb85d5a0d04542aee66d77687a7da5e2a2b6cea601c6a563e23f5`.

| Run | Selected path | PointCloud2 | Raw sonar | Runtime crash before bounded shutdown |
|---|---|---:|---:|---:|
| WGPU 1 | `llvmpipe` | 513×301 | 513 beams × 399 ranges | no |
| WGPU 2 | `llvmpipe` | 513×301 | 513 beams × 399 ranges | no |
| `auto` | WGPU / `llvmpipe` | 513×301 | 513 beams × 399 ranges | no |
| CPU | CPU | 513×301 | 513 beams × 399 ranges | no |

The runners terminate by an intentional bounded SIGINT after collecting both payloads. Child
exit `-2` at that point is shutdown evidence, not the earlier exit-139 crash. One CPU shutdown
also produced a `parameter_bridge` exit `-11` after both payloads had already been retained; this
candidate does not claim to repair that separate shutdown-only observation.

Evidence:

- [`v5_wgpu_run1/`](v5_wgpu_run1/)
- [`v5_wgpu_run2/`](v5_wgpu_run2/)
- [`v5_auto/`](v5_auto/)
- [`v5_cpu/`](v5_cpu/)

## Combined Heavy-multibeam control

The same candidate and `auto` software-WGPU path were then used in one combined
BlueROV2-Heavy-multibeam session. It retained:

- PointCloud2 513×301;
- raw sonar 513×399;
- MAVROS connected;
- MANUAL armed;
- 100 manual-control publications;
- X odometry `0.000123` m → `0.191414` m, delta `+0.191291` m;
- disarmed;
- no OGRE2 SIGSEGV before bounded shutdown.

See [`v5_heavy_integration/functional_summary.json`](v5_heavy_integration/functional_summary.json).
The shutdown-only bridge signal noted above is not turned into a control-loop failure because all
functional checks were captured first.

## Mac Metal control

The exact candidate libraries were built in an isolated overlay. The run selected Apple M2 Metal,
created the backend after the plugin-load line, allocated 513×301×399 buffers, reached GPU frame
100 and showed no OGRE2 crash.

The host had been upgraded after earlier direct sonar validation, leaving `gz-sim10` dependent on
older FFmpeg/x265 ABIs. This run used local compatibility libraries rather than changing Homebrew.
Its ROS CLI observer then stalled while loading/discovering types, so this candidate run does
**not** add a fresh Mac PointCloud2/raw-sonar artifact. Earlier committed direct Mac payload
evidence remains separate; only the candidate's Metal compute/no-crash scope is claimed here.

See [`v5_mac_metal/`](v5_mac_metal/).

## What this closes and what it does not

This closes the **reproducible local startup crash** in the tested isolated candidate:

- minimal Docker WGPU;
- repeated explicit Docker WGPU;
- Docker `auto`;
- Docker CPU regression;
- one combined Heavy + ArduSub + MAVROS control session;
- one Mac Metal compute control.

It does not establish:

- upstream acceptance or installed-distribution behavior;
- Docker hardware WGPU or NVIDIA CUDA;
- general acoustic correctness or full CPU/WGPU numerical equivalence;
- long-duration stability;
- physical vehicle/HIL behavior;
- a fix for the shutdown-only `parameter_bridge` signal.

Machine-readable scope and raw-derived dimensions are in [`summary.json`](summary.json).
Reproduction scripts are retained in [`scripts/`](scripts/).
