# Deferred multibeam backend extended validation — 2026-08-30

This directory extends the first isolated deferred-backend result with repeated cold starts,
repeated Heavy+ArduSub/MAVROS control, a valid process-group shutdown control and a bounded
30-minute software-WGPU soak.  All runtime tests used copied source or a derived image; the
upstream DAVE checkout and installed user workspace were not changed.

## Verdict

- **Startup/output: FUNCTIONAL PASS in this isolated Docker `llvmpipe` scope.** Twenty fresh WGPU
  cold starts all selected `llvmpipe` and produced PointCloud2 513×301 plus raw sonar 513×399.
- **Heavy integration: FUNCTIONAL PASS in the tested control scope.** Three of three runs connected
  MAVROS, armed, accepted 100 bounded controls, moved and disarmed. X displacement was
  0.624–0.687 m, median 0.667 m.
- **Bounded 30-minute runtime: FUNCTIONAL PASS in this software-adapter scope.** Payloads were
  present both before and after the 1,861 s sampled interval, WGPU frame count advanced 3,850,
  world iterations advanced in four retained windows and no runtime stack trace or exit 139 was
  observed.
- **Shutdown: PARTIAL.** A process-group SIGINT made the launch exit cleanly without escalation in
  10/10 runs, but `parameter_bridge` reported shutdown-only exit -11 in 7/10. All required sonar
  payloads had already passed and no runtime sonar stack occurred.
- **Distribution and hardware remain PARTIAL.** The candidate is not upstream or installed, and
  Docker hardware WGPU/NVIDIA CUDA were not available.

## 30-minute resource and progress scope

After excluding the first 300 s startup window, 26 resource samples gave:

- container memory 706,425,651–714,604,544 bytes, median 708,837,375.5 bytes;
- fitted container-memory slope +3,256,554.5 bytes/hour;
- Gazebo RSS 664,988–667,444 KiB, median 666,060 KiB;
- fitted Gazebo-RSS slope +6,396.8 KiB/hour.

Those small positive slopes describe one bounded run and are **not** labelled a memory leak.
Endpoint-delta RTF across the four retained world-stat windows was 0.1764–0.1917. Reported
per-message RTF medians were lower (0.0172–0.0237) because those streams include highly variable
instantaneous samples; the two measures are kept separate.

The launch was stopped by the bounded harness and records rc 143. The container was removed and
no matching host process remained. That rc is teardown provenance, not a runtime sensor failure.

## Harness corrections retained

- [`clean_shutdown_10/`](clean_shutdown_10/) sent SIGINT to a background shell PID and then required
  TERM in 10/10. It is retained as an invalid Ctrl-C model and excluded from the shutdown verdict.
- [`clean_shutdown_process_group_10/`](clean_shutdown_process_group_10/) uses a process group and is
  the valid shutdown control.
- [`invalid_wgpu_soak_dry_run_missing_end_env/`](invalid_wgpu_soak_dry_run_missing_end_env/) preserves
  the first rejected soak harness. The corrected script supplies the end-capture environment and
  bounds all optional diagnostics.

## Evidence map

- [`summary.json`](summary.json): aggregate machine-readable verdict.
- [`wgpu_cold_start_20/aggregate_summary.json`](wgpu_cold_start_20/aggregate_summary.json): 20 starts.
- [`heavy_repeated_3/aggregate_summary.json`](heavy_repeated_3/aggregate_summary.json): 3 Heavy runs.
- [`clean_shutdown_process_group_10/summary.tsv`](clean_shutdown_process_group_10/summary.tsv): valid
  shutdown series.
- [`wgpu_soak_30m/summary.json`](wgpu_soak_30m/summary.json): bounded soak analysis.
- [`scripts/`](scripts/): execution and analysis scripts.

This evidence does not establish upstream acceptance, installed behavior, hardware-GPU performance
or general acoustic correctness.
