# Dave World Models audit — 2026-08-27

This audit checks the Wiki Quickstart, the 18 distributed `.world` files, their
internal `<world name>` values, and the current validation matrix. It uses the
existing Lyrical/Jetty migration workspaces at DAVE revision `6aef91c`; neither
workspace is a pristine upstream checkout.

## Current matrix

The repository contains 18 distributed world files and 18 matrix rows:

| Status | Count |
|---|---:|
| `FUNCTIONAL PASS` | 5 |
| `FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS` | 1 |
| `SMOKE PASS` | 11 |
| `PARTIAL` | 1 |

This is **17/18 PASS-level at the world-row level**, not 17 feature-complete
worlds. A `SMOKE PASS` proves launch/liveness or stepping only. Sensor, model,
service, manipulation and numerical verdicts remain scoped separately.

## Internal world-name audit

The 18 files expose only 14 distinct internal names. Seven files fall into
three duplicate-name groups:

| Internal name | World files |
|---|---|
| `oceans_waves` | `dave_ocean_waves.world`, `dave_ocean_waves_mossy_ground.world`, `dave_ocean_waves_sonar.world` |
| `default` | `dave_multibeam_sonar.world`, `usbl_tutorial.world` |
| `dvl_world` | `dvl_world.world`, `new_dvl.world` |

The previous documentation and upstream draft named only two files in the
first group and incorrectly called `default` unique. The full inventory is
identical by filename and internal name in Mac source, Docker source and the
Docker installed package.

Gazebo derives `/world/<name>/...` topics and services from the internal name,
not the filename. Concurrent runs in one Gazebo partition can therefore be
misattributed or rejected as another world of the same name.

## Quickstart rerun

The Wiki command was rerun on 2026-08-27:

- Docker RDP/X: the exact command
  `ros2 launch dave_demos dave_world.launch.py world_name:=dave_ocean_waves`
  started the world and yielded `/world/oceans_waves/stats` with advancing
  iterations.
- Mac: the same command with the locally verified headless extension
  `gui:=true headless:=true` yielded the same stats topic and advancing
  iterations.

The single retained stats sample on each platform is liveness evidence, not a
cross-platform performance benchmark.

## Remote assets

All 18 files contain at least one remote Fuel URI; the source inventory counts
128 remote include URIs in total. First launch therefore requires network
access unless every referenced model is already cached.

## Evidence map

- `mac_source_world_inventory.csv` — Mac source inventory
- `docker_source_world_inventory.csv` — Docker source inventory
- `docker_installed_world_inventory.csv` — Docker installed-package inventory
- `mac_collision_groups.txt`, `docker_source_collision_groups.txt`,
  `docker_installed_collision_groups.txt` — independently derived duplicate groups
- `quickstart_mac/` — Mac headless-extension run
- `quickstart_docker/` — exact Docker Wiki command under the authorised X session
- `summary.json` — machine-readable verdict

## Environment note

The long-lived Docker test container still contains an obsolete local USBL
patch whose XML comment includes forbidden `--` text. Its source and installed
`usbl_tutorial.world` therefore fail strict XML parsing. The current patch in
this review repository already fixes that comment. This is test-container
contamination, not a new upstream DAVE defect; the internal world name is read
from the opening tag and is unaffected.

## Limits

- Only `dave_ocean_waves` was rerun during this 2026-08-27 audit. The other 17
  matrix rows retain their existing dated runtime evidence.
- No `SMOKE PASS` was upgraded from source inspection alone.
- Remote URI presence was audited, but every model was not downloaded from an
  empty cache again.
