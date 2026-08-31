# Multibeam seed determinism and llvmpipe cache validation — 2026-08-31

## Scope

This result closes two narrow questions about the validation-only exact-DFT
WGPU candidate on Docker / Mesa `llvmpipe`:

1. Is its output repeatable when both the configured seed and frame index are
   held fixed?
2. Is the long first exact-N dispatch sensitive to the Mesa / XDG cache?

It does **not** establish hardware-GPU behavior, general acoustic accuracy, or
CPU/WGPU raw-array equivalence.

## Determinism result

The validation image fixes `frameIndex` to `0`; the existing default
`sonarSeed` remains `12345`. Three independent fresh containers each captured
three frames from the same controlled planar scene.

| Measurement | Result |
|---|---:|
| Fresh containers | 3 |
| Frames per container | 3 |
| Unique raw-sonar hashes across all 9 frames | 1 |
| Unique PointCloud2 hashes across all 9 frames | 1 |
| Cross-container first raw arrays bitwise equal | yes |
| Raw peak range | 4.013377666 m |
| Error from the 4.0 m target plane | +0.013377666 m |

Raw-sonar SHA-256:
`d76402e9366b4eff50d0c1b1683ea931a0ea4edf6bfe76150afe39d3e7c161fc`.

Point-cloud SHA-256:
`25db2f6c8904408c0cb97975b4bef8204e1b5295b968aab4ef2ea4f8560cfed9`.

Therefore the tested WGPU path is bitwise repeatable for this one scene when
the seed and frame index are fixed.

## CPU comparison is not an equivalence test

The CPU reference and fixed-frame WGPU result have the same `399 x 513` raw
array shape, but are not numerically equal (`MAE 132.80`, `RMSE 133.71`). This
does not by itself identify a WGPU implementation defect: the current CPU path
uses a deterministic beam/ray-index phase construction, while WGPU uses a
Philox sequence keyed by seed and frame index. They are different algorithms,
so full raw-array equality is not an applicable oracle until both backends
implement the same phase/noise model.

## Exact-N initialization and cache result

### Same container

| Run | Cache state | Wall time to full buffers | Pipeline compile | First probe |
|---:|---|---:|---:|---:|
| 1 | cold | 92 s | 1542 ms | 84826.8 ms |
| 2 | warm | 5 s | 11 ms | 8.0 ms |
| 3 | warm | 5 s | 8 ms | 7.5 ms |

### Fresh containers sharing one cache directory

| Run | Cache state | Wall time to full buffers | Pipeline compile | First probe |
|---:|---|---:|---:|---:|
| 1 | empty | 101 s | 1420 ms | 94192.4 ms |
| 2 | reused | 5 s | 11 ms | 9.3 ms |

The reused cache occupied about 3 MiB. The exact-N software-renderer cold
delay is therefore cache-sensitive: most of the cold latency is in the first
dispatch/JIT/cache population rather than pipeline creation alone. Reusing the
Mesa/XDG cache is a practical local startup mitigation; it does not change the
algorithm or turn `llvmpipe` into hardware GPU execution.

## Invalid attempt retained but excluded

The first cross-container harness used ROS domain IDs `236` and `237`, outside
the usable Fast DDS UDP port range in this environment. That attempt is marked
invalid and is not included in the conclusions.

## Evidence

- [`summary.json`](summary.json) — machine-readable verdict and timing tables
- [`repeats/summary.tsv`](repeats/summary.tsv) — all fresh-container hashes
- [`cpu_wgpu_comparison.json`](cpu_wgpu_comparison.json) — scoped CPU/WGPU comparison
- [`init_same_container/summary.tsv`](init_same_container/summary.tsv) — cold/warm repeats
- [`init_cross_container_cache/summary.tsv`](init_cross_container_cache/summary.tsv) — fresh-container cache reuse
- [`init_cross_container_cache_invalid_high_domain/INVALID_ATTEMPT.txt`](init_cross_container_cache_invalid_high_domain/INVALID_ATTEMPT.txt) — excluded harness error
- [`scripts/`](scripts/) — reproducible build and run harnesses

## Limits

- One controlled planar scene on Docker / `llvmpipe` only.
- The fixed-frame image is a validation instrument, not a production change.
- No real sonar reference, hardware GPU, or real-ocean acoustic validation.
- General repeatability across scenes, seeds, drivers, and devices remains open.
