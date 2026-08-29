> **Superseded current-boundary note (2026-08-29):** this folder is the first eight-candidate
> snapshot. A ninth world-system patch and current OGRE2/camera/Fast-DDS/BlueROV2 rechecks are in
> [`../open_gap_revalidation_2026-08-29/`](../open_gap_revalidation_2026-08-29/). Historical raw
> measurements here are unchanged.

# Remaining defect patch validation — 2026-08-29

This folder records validation of **candidate patches** assembled from the tested DAVE source
snapshot. The upstream DAVE checkout was kept read-only; these results do not claim that upstream
or the installed user workspace already contains the fixes.

## Closed in the tested patch set

- WGPU's gross planar raw-sonar range shift: old 6.396–6.446 m for a 3.99 m target became
  3.988294–4.063545 m on Mac/Metal. A post-commit boundary audit also added an explicit
  `n_freq <= 4096` GPU limit: 4097 bins return before GPU initialisation for the existing C++ CPU
  fallback instead of exceeding the shader's fixed workgroup arrays.
- Explicit unavailable CUDA now falls back to CPU, keeps Gazebo alive and publishes raw sonar in a
  small discriminating test.
- Underwater Camera semantic R/G/B tags now produce expected BGR `[50, 103, 85]` on both Mac and Docker.
- SeaPressure unit, depth sign, saturation, noise, rate, variance, frame and topic controls pass on both platforms.
- Spherical services reject invalid input, return explicit status, remain responsive while paused,
  and fail safely without world spherical configuration on both platforms.
- Eight shipped DVL descriptors publish four-beam Docker messages with populated frame IDs and no
  initialization error; an actual descriptor also reports water-mass target and non-zero environmental velocity.
- USBL `sigma=0`, paused callbacks, moving target and fractional propagation delay pass on Mac and Docker.
- Plugin discovery hooks, missing-object preflight, server-only launch semantics, debug arguments,
  non-TTY keyboard handling and 18/18 unique internal world names pass their scoped checks.

## Still open

The remaining items in `summary.json` require an external stack/environment, a design decision, or
broad scientific validation. They are intentionally not relabelled PASS.

## Evidence map

- `summary.json` — machine-readable verdict and remaining boundaries.
- `mac/` — selected Mac results.
- `docker/` — selected Docker results.
- `build_and_static_checks.txt` — build, syntax, XML and patch-application checks.
- `post_commit_audit.txt` — 4096-bin boundary test and stale-current-document propagation audit.
- `patch_sha256.txt` — hashes of the eight candidate patches kept in `patches/`.
