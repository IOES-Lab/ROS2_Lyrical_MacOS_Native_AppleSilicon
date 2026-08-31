# Multibeam CPU / software-WGPU controlled-scene matrix — 2026-08-30

> **Current update — 2026-08-31.** The statement below that frames were not seed/frame-index aligned describes this 2026-08-30 matrix, not the current evidence limit. A later exact-N control fixed seed `12345` and `frameIndex=0` and produced byte-identical raw and point arrays across three fresh containers and nine frames. CPU/WGPU full raw equality is still not used as an oracle because the two backends intentionally implement different phase/noise algorithms. See [`../multibeam_seed_determinism_validation_2026-08-31/`](../multibeam_seed_determinism_validation_2026-08-31/).

This matrix separates the renderer-derived PointCloud2 geometry from the computed raw-sonar
image.  Every run used Docker software Vulkan `llvmpipe`, the same full 513×301 ray image and a
399-bin raw image.  Six controlled scenes were captured three times per backend.

## Verdict

- **PointCloud geometry: PASS in this matrix.**  CPU and the distributed WGPU implementation
  produced exactly equal finite XYZ and intensity arrays in all six scenes.  Centre ranges were
  within 0.0012 m of the intended nearest surface.
- **Distributed WGPU raw range localisation: FAIL.**  Its median peak error was +0.584 m at 2 m,
  about +1.14 to +1.17 m at 4 m and +1.980 m at 7 m.
- **Exact-N candidate raw range localisation: scoped PASS.**  After rebuilding the Rust archive
  *and* relinking `multibeam_sonar`, all 18 raw frames peaked within 0.0736 m of the expected
  surface; median absolute error was 0.0134 m.  The expected bin ranked 1–10, not always first.
- **Full raw-array backend equivalence: not established.**  CPU and WGPU frames were not aligned
  to the same stochastic `frameIndex` / seed, and large descriptive array differences remain.
- **General acoustic correctness: not established.**  These are synthetic geometric controls,
  not calibrated materials or real acoustic measurements.

## Range-localisation results

| Scene | Expected (m) | CPU median peak (m) | Distributed WGPU median (m) | Exact-N WGPU median (m) |
|---|---:|---:|---:|---:|
| plane, dark | 2.0 | 1.981605 | 2.583612 | 2.006689 |
| plane, dark | 4.0 | 3.988294 | 5.142140 | 4.038461 |
| plane, bright | 4.0 | 3.988294 | 5.142140 | 4.013378 |
| plane, dark | 7.0 | 6.998328 | 8.979933 | 6.998328 |
| sphere, bright | 4.0 | 3.988294 | 5.167224 | 4.013378 |
| cylinder, bright | 4.0 | 3.988294 | 5.142140 | 4.038461 |

The three plane distances fit a distributed-WGPU peak slope of 1.279264.  That is close to
`512 / 399 = 1.283208`, consistent with the source-level defect: the old shader zero-pads the
399 samples to 512, writes only the first 399 padded-FFT bins and the publisher labels them with
the original 399-bin range vector.  The exact-N candidate removes that grid mismatch.  This is a
source-informed explanation supported by the candidate discriminator, not a claim about every
possible range configuration.

## Build provenance and rejected attempt

The existing [`multibeam_wgpu_and_backend_fix.diff`](../../../patches/multibeam_wgpu_and_backend_fix.diff)
contains an exact DFT path for non-power-of-two spectra.  The first Docker image applied the patch
and rebuilt `multibeam_sonar`, but did **not** rebuild the vendor archive; its output remained
bit-for-bit equivalent to the defective implementation and is retained under
[`exact_dft_candidate/`](exact_dft_candidate/) as a rejected build-provenance attempt.

The corrected image rebuilt `wgpu_vendor`, sourced that install and then clean-rebuilt the sonar:

```text
libsonar_wgpu.a       9d2835b6824085e15d0375d0d7faf98bea440a10ac6da0cfb5558579ba9d127e
libmultibeam_sonar.so 1f63f0d7752698a2e86ce52aa498e7f8a953a2bcc379baac0aa74cd3f96742c3
image                 sha256:981004fb7c9102484a1435b1a526e2f221a55f567118099a891912fa224369e2
```

The retained 4097-bin boundary unit test passed.  On fresh software-`llvmpipe` containers, however,
the exact DFT's initial 1×1×4 probe took **88.2–115.3 s** across the six runs.  This O(N²) path is a
correctness discriminator and a validated local candidate, not yet an acceptable software-renderer
performance solution.  A production change should preserve the exact N-bin grid with a more
efficient arbitrary-length transform or explicitly fall back to CPU.

## Material-control limit

Changing only the Gazebo visual diffuse colour from dark to bright changed neither backend's
captured arrays.  That proves this particular visual field is not being used as an acoustic
reflectivity control in the tested path; it does **not** mean real target material is irrelevant.

## Evidence map

- [`summary.json`](summary.json) and [`summary.csv`](summary.csv): CPU versus distributed WGPU.
- [`range_scale_analysis.json`](range_scale_analysis.json): measured scale relationship.
- [`exact_dft_candidate_v2/summary.json`](exact_dft_candidate_v2/summary.json): corrected linked candidate.
- [`exact_dft_candidate_v2/run_summary.tsv`](exact_dft_candidate_v2/run_summary.tsv): six cold runs.
- [`test_assets/`](test_assets/): image lineage, build logs and binary hashes.
- [`test_assets/worlds/`](test_assets/worlds/): controlled SDF worlds.
- [`scripts/`](scripts/): generation, capture, build and analysis scripts.
- [`COMPACTION.md`](COMPACTION.md): retention rule for large NumPy bundles.
- [`array_sha256_manifest.txt`](array_sha256_manifest.txt): hashes of all original bundles and
  retained/removed status.  The 4 m dark-plane CPU, distributed-WGPU and exact-N bundles remain as
  representative binary controls; aggregate JSON/CSV and build provenance were not rewritten.
- [`provenance_sha256.json`](provenance_sha256.json): clean source revision, both candidate-patch
  digests, and the retained deferred/exact-N runtime image IDs used by the final audit.
