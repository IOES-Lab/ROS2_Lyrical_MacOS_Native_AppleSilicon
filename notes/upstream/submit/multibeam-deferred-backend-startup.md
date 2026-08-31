<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave), default branch `ros2`, under `gazebo/dave_gz_multibeam_sonar/multibeam_sonar_system/`.
     라벨:     `bug`, `crash`, `sonar`, `wgpu`
     원본:     notes/upstream/drafts/multibeam-deferred-backend-startup-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

Defer multibeam WGPU device creation from the render callback to the existing compute thread

---

## 이슈 본문 (이 줄 아래 전체를 본문 칸에 붙여넣기)

## Summary

In the tested Docker ARM64 software-WGPU environment, creating the sonar compute backend during
the render-side startup path produced an intermittent/ordering-sensitive Gazebo failure before a
usable sonar payload.  Moving backend creation to the first populated `GpuRays` frame handled by
the plugin's existing compute thread converted that path into repeated usable output.

The retained candidate does not change the ray renderer.  It stores the requested backend during
configuration and creates it once in the compute thread after a populated frame is available.  It
also disables unused ROS parameter services/event publication on the internal plugin node, which
reduces unrelated entities in the same startup path.

## Retained validation

On Docker Desktop ARM64 with Mesa `llvmpipe`:

- 20/20 cold launches selected the WGPU `llvmpipe` adapter and published both a 513×301
  PointCloud2 and a 513×399 raw-sonar message.
- 3/3 Heavy-multibeam + ArduSub/MAVROS runs connected, armed, accepted 100 bounded control
  commands, moved, and disarmed.  X displacement was 0.624–0.687 m (median 0.667 m).
- An integrated ocean-waves sonar world published 3/3 PointCloud2 and 3/3 raw-sonar payloads while
  world statistics progressed.
- A bounded 30-minute software-WGPU soak retained valid PointCloud2 and raw sonar at both ends,
  advanced the WGPU frame count by 3,850 and showed progressing world iterations in four sampled
  windows.  No runtime stack trace or exit 139 occurred.  After excluding startup, container
  memory stayed within 706.4–714.6 MB and Gazebo RSS within 664,988–667,444 KiB; fitted positive
  slopes from this single run are reported but are not labelled a leak.
- No runtime OGRE2 stack trace or exit 139 occurred in those retained runs.

The candidate also selected Apple M2 Metal and computed frames in a bounded Mac run.  That does
not substitute for an independent hardware-WGPU or CUDA validation of the Docker path.

## Shutdown finding is separate

A process-group SIGINT harness exited the launch process cleanly without escalation in 10/10
runs, but the baseline `ros_gz_bridge/parameter_bridge` reported exit `-11` during shutdown in
7/10. Sonar payloads had already passed in all ten cases, and no runtime sonar stack trace was
present. A later focused baseline measured 9/10 in the active DAVE-sonar path and separated it from
40/40 no-publisher plus 30/30 stock-active clean controls.

That bridge lifecycle issue is no longer an unresolved part of this DAVE candidate. An independent
exact-`ros_gz` 3.0.9 ownership-cycle candidate gives bridge-first 20/20 clean and process-group
10/10 rc0 while preserving point/raw payloads. It should be reviewed separately in `gazebosim/ros_gz`.

A prior harness that sent SIGINT to a background shell PID required TERM in 10/10 and is retained
as invalid for Ctrl-C semantics.  It is excluded from the process-group verdict.

## Why this should be reviewed separately from the range-grid bug

This change addresses backend initialisation timing.  It does not correct the distributed WGPU
shader's 399-to-512 range-grid mismatch.  The range/localisation issue and candidate transform are
documented in a separate draft so maintainers can review and bisect the two changes independently.

## What remains unproven

- Upstream acceptance and independent reproduction.
- Hardware WGPU and CUDA startup behavior.
- Whether disabling the plugin node's unused parameter services is necessary, merely helpful, or
  should be a separate change.
- Upstream review, full tests and installed distribution of the separate bridge ownership-cycle candidate.
- Hardware-backed long-duration and performance behavior; the retained soak used software
  `llvmpipe` only.
- General acoustic correctness; this candidate establishes startup and payload availability only.

## Environment

- ROS 2 Lyrical, Gazebo Jetty 10.4, Docker Desktop ARM64 on Apple M2
- software Vulkan / WGPU adapter: Mesa `llvmpipe`; no `/dev/dri` passthrough
- derived image and copied DAVE source; original checkout remained read-only

## Evidence and candidate

- Repeated cold starts, Heavy integration, shutdown series and soak artifacts:
  [`../../results/multibeam_deferred_backend_extended_validation_2026-08-30/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/multibeam_deferred_backend_extended_validation_2026-08-30/)
- Earlier isolated candidate evidence:
  [`../../results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/multibeam_llvmpipe_deferred_backend_candidate_2026-08-30/)
- Candidate diff:
  [`../../../patches/multibeam_defer_backend_until_compute_fix.diff`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/blob/main/patches/multibeam_defer_backend_until_compute_fix.diff)
- Separate bridge lifecycle candidate:
  [`../../results/parameter_bridge_cycle_fix_validation_2026-08-31/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/parameter_bridge_cycle_fix_validation_2026-08-31/)
