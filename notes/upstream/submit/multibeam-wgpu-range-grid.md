<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave), default branch `ros2`, under `gazebo/dave_gz_multibeam_sonar/wgpu_vendor/sonar_wgpu_rust/`.
     라벨:     `bug`, `sonar`, `wgpu`
     원본:     notes/upstream/drafts/multibeam-wgpu-range-grid-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

WGPU zero-padding changes the 399-bin sonar range grid and shifts a 3.99 m return to about 5.14 m

---

## 이슈 본문 (이 줄 아래 전체를 본문 칸에 붙여넣기)

## Summary

The WGPU spectrum shader pads the sonar's 399 input samples to 512, performs a 512-point FFT,
writes only the first 399 output bins, and the publisher labels those values with the original
399-bin range vector.  The padded transform therefore samples a different frequency grid from
the one represented by the message.

In six copied, controlled scenes on Docker ARM64 software Vulkan `llvmpipe`, the renderer-derived
PointCloud2 geometry was exactly equal between CPU and the distributed WGPU backend, but raw-sonar
range localisation was not:

| Target | Expected | CPU median peak | Distributed WGPU median peak |
|---|---:|---:|---:|
| planar surface | 2.0 m | 1.981605 m | 2.583612 m |
| planar surface | 4.0 m | 3.988294 m | 5.142140 m |
| planar surface | 7.0 m | 6.998328 m | 8.979933 m |
| sphere surface | 4.0 m | 3.988294 m | 5.167224 m |
| cylinder surface | 4.0 m | 3.988294 m | 5.142140 m |

Each backend/scene cell contains three retained raw frames.  The three plane distances fit a
WGPU peak slope of `1.279264`, close to `512 / 399 = 1.283208`.

## Source path

The distributed shader uses a padded size for non-power-of-two inputs:

```text
n_freq = 399
padded_n = next_power_of_two(n_freq) = 512
```

It then transforms the zero-padded working set but only copies the first `n_freq` bins back.  The
range vector remains 399 bins long and is not rescaled for the 512-point grid.

## Correctness discriminator

A copied candidate retained the radix-2 FFT when `n_freq` is already a power of two and used an
exact N-point DFT otherwise.  After rebuilding the Rust vendor archive and clean-relinking the
sonar library, all 18 retained raw frames in the same six scenes peaked within `0.0736 m` of the
expected surface; median absolute peak error was `0.0134 m`.

The first candidate build is deliberately retained as a rejected attempt: it applied the source
patch but did not rebuild/relink the vendor archive, and its output remained equivalent to the
defective implementation.  This prevents a source-diff-only success claim.

## Why the candidate is not the proposed production fix

The exact DFT is O(N squared).  On fresh software-`llvmpipe` containers its initial 1×1×4 WGPU
probe took `88.2–115.3 s` across six launches.  It is useful as a correctness discriminator, not
as an acceptable software-renderer implementation.  A production fix should preserve the exact
N-bin grid with an efficient arbitrary-length transform (for example Bluestein or mixed-radix),
or explicitly use the CPU path when the GPU implementation cannot preserve the grid.

## What this establishes and what it does not

- It establishes a repeatable raw range-localisation error for the tested 399-bin configuration.
- It establishes that an exact-N transform removes that localisation error in six synthetic
  geometric scenes.
- A later validation-only exact-N control fixed seed `12345` and `frameIndex=0`; three fresh
  containers produced byte-identical WGPU raw and point arrays across all nine captured frames.
- This closes deterministic repeatability for that controlled WGPU scene.  It does **not**
  establish CPU/WGPU full raw-array equality, and that equality is not an applicable oracle
  while the CPU and WGPU paths intentionally use different phase/noise algorithms.
- It does **not** establish general acoustic correctness or target reflectivity.  Changing only
  Gazebo visual diffuse colour did not affect the retained arrays, so that field is not an
  acoustic-material control in this path.
- No hardware WGPU or CUDA result is inferred from software `llvmpipe`.

## Environment

- ROS 2 Lyrical, Gazebo Jetty 10.4, Docker Desktop ARM64 on Apple M2
- rendering and WGPU adapter: Mesa `llvmpipe`, no `/dev/dri` passthrough
- full PointCloud2: 513×301; raw sonar: 513×399
- copied worlds and derived images only; the DAVE checkout was not edited

## Evidence and candidate

- Controlled matrix and build provenance:
  [`../../results/multibeam_backend_equivalence_matrix_2026-08-30/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/multibeam_backend_equivalence_matrix_2026-08-30/)
- Fixed-seed/frame determinism and cache evidence:
  [`../../results/multibeam_seed_determinism_validation_2026-08-31/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/multibeam_seed_determinism_validation_2026-08-31/)
- Candidate diff:
  [`../../../patches/multibeam_wgpu_and_backend_fix.diff`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/blob/main/patches/multibeam_wgpu_and_backend_fix.diff)
