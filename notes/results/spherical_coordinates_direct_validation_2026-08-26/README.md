# Spherical Coordinates direct validation — 2026-08-26

## Verdict

**PARTIAL.** With the installed plugin library discoverable, all four DAVE ROS
services worked on Mac and Docker. Get/set/restore passed, and three finite
Cartesian→spherical→Cartesian round trips per platform had a maximum axis error
of `9.708536197194917e-10 m`. Mac and Docker were numerically equivalent within
`2e-9` (maximum observed cross-platform numeric difference
`1.0136034234164981e-9`).

The overall verdict is not a full pass because the current Wiki example and
runtime input handling have confirmed problems:

1. the current `dave_bimanual_example` origin is
   `(35.074823, 129.084798, 0)`, not the older North Sea value shown by the Wiki;
2. after setting the Wiki origin, local `(100, 200, 3)` converts to
   `(-24.71717115826974, -46.51463667787355, 103.00393470935524)`, while the
   documented spherical result converts back to approximately
   `(-100, -200, 3)` — the documented X/Y direction is reversed;
3. non-finite transform inputs return non-finite payloads, and
   `latitude=100`, `longitude=200` is accepted with `success=true`;
4. on this Mac migration workspace the generated
   `GZ_SIM_SYSTEM_PLUGIN_PATH` names `lib/dave_ros_gz_plugins/`, but
   `libSphericalCoords.dylib` is in `lib/`; the four custom services were absent
   until the actual `lib/` directory was added.

The Mac path problem did **not** reproduce in the merged Docker install. Docker
also generated a `lib/dave_ros_gz_plugins/` Gazebo path, but `install/lib` was on
`LD_LIBRARY_PATH`, and all four services appeared without a manual Gazebo-path
override.

## Directly exercised services

```text
/gz/get_origin_spherical_coordinates
/gz/set_origin_spherical_coordinates
/gz/transform_to_spherical_coordinates
/gz/transform_from_spherical_coordinates
```

The controlled matrix used the Wiki origin and local points `(0,0,0)`,
`(100,200,3)` and `(-250,50,-20)`. It then exercised the exact Wiki output,
NaN in both transform directions, an out-of-range origin, and restoration of
the original origin.

## Evidence map

- [`01_wiki_quickstart_mac/`](01_wiki_quickstart_mac/) — **excluded from the
  verdict**: the first GUI attempt ran inside a restricted harness that denied
  local sockets and screens.
- [`02_wiki_headless_default_path_mac/`](02_wiki_headless_default_path_mac/) —
  the Wiki world ran headless under the sourced Mac environment, but the four
  custom services were absent.
- [`03_fixed_path_mac/`](03_fixed_path_mac/) — the Wiki world and individual
  calls after adding the actual installed library directory.
- [`04_controlled_matrix/`](04_controlled_matrix/) — reproducible Mac and Docker
  matrices plus the cross-platform summary.
- [`05_default_path_docker/`](05_default_path_docker/) — all four services
  present with the default Docker environment; records both Gazebo and dynamic
  linker paths.
- [`source/`](source/) — the tested `SphericalCoords.cc`, four `.srv` files,
  DAVE commit/status, hashes and installed-library-path evidence.
- [`../../experiments/spherical_coordinates/`](../../experiments/spherical_coordinates/) —
  the reusable minimal world, client, runner and cross-platform summarizer.
- [`summary.json`](summary.json) — machine-readable final result.

## Limits

- Three finite points and one configured origin are not general geodesic
  validation.
- No independent geodesy implementation or survey reference was used.
- The optional-empty fallback identified by source review was not triggered at
  runtime. NaN propagated as NaN rather than becoming zero.
- The DAVE checkout was not pristine; the exact tested source and its hash are
  retained under [`source/`](source/). No DAVE source file was modified by this
  validation.
