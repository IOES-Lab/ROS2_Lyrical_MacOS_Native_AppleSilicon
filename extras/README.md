# extras/

Build scripts. The same procedure as
[`../notes/setup/reproduction.md`](../notes/setup/reproduction.md), made executable — prose lets
you skip a step and discover it twenty minutes later.

| Script | Platform | Coverage |
|---|---|---|
| [`build-dave-lyrical-linux.sh`](build-dave-lyrical-linux.sh) | Ubuntu 26.04 | **Complete.** `apt` through to a running sonar |
| [`build-dave-lyrical-macos.sh`](build-dave-lyrical-macos.sh) | macOS, Apple Silicon | Two of three stages — see below |

```bash
extras/build-dave-lyrical-linux.sh                     # workspace defaults to ../dave_ws
extras/build-dave-lyrical-linux.sh ~/somewhere/else
```

## What the macOS script does not do

It does not build ROS 2 Lyrical itself.

ROS 2 Lyrical has no macOS binary release, so it was built from source on 2026-07-06 with
GUI-related packages excluded. **The commands were never recorded** — the progress log has the
outcome, not the invocation.

Writing them from memory would put commands in this repository that nobody has run. The script
checks for `$ROS2_LYRICAL_WS/install/setup.zsh` instead and stops with an explanation if it is
missing, rather than failing partway through a later stage for an unrelated-looking reason.

If you have ROS 2 Lyrical elsewhere:

```bash
ROS2_LYRICAL_WS=/path/to/ws extras/build-dave-lyrical-macos.sh
```

If you do not, the Docker path is complete and verified end to end — [`../docker/`](../docker/).

## Both scripts refuse to finish on an unoptimised build

The last thing each one does is check `compile_commands.json` for an `-O` flag and exit non-zero
if it is absent.

This is the defect that cost the most here. `colcon` leaves `CMAKE_BUILD_TYPE` empty unless told
otherwise, and no package sets a default, so following the documented build produces a workspace
with no optimisation anywhere. Nothing fails. The sonar world simply runs at RTF 0.2180 instead
of 0.4380, and every performance figure taken before 2026-08-05 was measured that way.

A build that quietly halves your numbers is worse than one that breaks, so these scripts break.
