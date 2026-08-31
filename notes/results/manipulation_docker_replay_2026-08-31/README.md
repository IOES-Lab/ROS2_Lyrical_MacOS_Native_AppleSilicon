# Manipulation-world Docker replay — 2026-08-31

## Verdict

All three manipulation-labelled worlds are **SMOKE PASS** in the isolated
Docker launch-candidate scope:

| World | Stats captured | Iteration increase | Alive before bounded shutdown | Runtime stack trace |
|---|---:|---:|---:|---:|
| `dave_bimanual_example` | 5 | 356 | yes | no |
| `dave_electrical_mating` | 5 | 389 | yes | no |
| `dave_plug_and_socket` | 5 | 302 | yes | no |

The candidate makes `dave_world.launch.py` always start Gazebo and interprets
`gui:=false` as server-only mode. Each world was run with
`gui:=false headless:=false`, so this exercises that exact semantic change
rather than the older `gui:=true headless:=true` workaround.

## Why the result remains SMOKE

These files are static prop/environment worlds. They do not include a robot
arm, manipulation task controller, or functional sensor output to assert.
World startup and simulation progress are therefore the strongest applicable
runtime verdict; this is not a manipulation-task success claim.

## Evidence

- [`summary.json`](summary.json) — machine-readable verdict
- [`summary.tsv`](summary.tsv) — per-world outcomes
- [`dave_bimanual_example/stats_analysis.json`](dave_bimanual_example/stats_analysis.json)
- [`dave_electrical_mating/stats_analysis.json`](dave_electrical_mating/stats_analysis.json)
- [`dave_plug_and_socket/stats_analysis.json`](dave_plug_and_socket/stats_analysis.json)
- [`build.log`](build.log) — candidate overlay build
- [`scripts/run_all.sh`](scripts/run_all.sh) — complete reproducer

## Limits

- One isolated Docker replay per world.
- Candidate overlay only; not installed into the user workspace or upstream.
- Fuel assets were resolved in the existing Docker environment; immutable
  account pin/upload remains separate.
