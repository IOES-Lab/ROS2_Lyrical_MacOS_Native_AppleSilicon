# `dave_ocean_waves_sonar` clean Docker validation — 2026-08-31

## Verdict

`dave_ocean_waves_sonar.world` is a **FUNCTIONAL PASS in the isolated Docker
exact-N candidate/output scope**. The retained five-stat run directly captured:

- WGPU on the Vulkan `llvmpipe` software adapter;
- full `513×301×399` backend allocation;
- PointCloud2 `513×301`: **3/3** frames;
- raw sonar `513×399`: **3/3** frames;
- five `/world/oceans_waves/stats` messages with iterations increasing by 99;
- no runtime stack trace.

This closes the old clean-isolation replay gap for this non-integrated world.
The similarly named integrated world was validated separately on 2026-08-30.

## Progress and performance scope

The four adjacent stat-message deltas give a median RTF of **0.1949**. The
individual `real_time_factor` fields are bursty (median `0.01130`) and are not
used as the primary estimate. The delta method is retained in
[`docker_exact_dft_v2_stats5/stats_analysis.json`](docker_exact_dft_v2_stats5/stats_analysis.json).

The fresh software-renderer run spent **99.743 s** in the first 1×1×4 exact-N
probe; GPU frame 100 was **527.9 ms**. The separate cache experiment shows that
the cold probe is cache-sensitive. These numbers are not hardware-GPU
performance.

## Evidence

- [`summary.json`](summary.json) — machine-readable verdict
- [`docker_exact_dft_v2_stats5/summary.json`](docker_exact_dft_v2_stats5/summary.json) — payload counts
- [`docker_exact_dft_v2_stats5/stats_analysis.json`](docker_exact_dft_v2_stats5/stats_analysis.json) — five-message delta analysis
- [`docker_exact_dft_v2_stats5/point_1.txt`](docker_exact_dft_v2_stats5/point_1.txt) through `point_3.txt`
- [`docker_exact_dft_v2_stats5/raw_1.txt`](docker_exact_dft_v2_stats5/raw_1.txt) through `raw_3.txt`
- [`docker_exact_dft_v2_stats5/launch.log`](docker_exact_dft_v2_stats5/launch.log)
- [`docker_exact_dft_v2/`](docker_exact_dft_v2/) — independent preliminary one-stat repeat

## Limits

- Candidate image only; no distributed/upstream installation claim.
- Docker `llvmpipe`, not hardware WGPU or CUDA.
- Two bounded runs, with detailed stats from one.
- Payload, progress, and bounded stability only; no general acoustic accuracy.
