# USBL GUI Crash — Root Cause Investigation (2026-07-22)

## Status: strong hypothesis, not yet confirmed (no real crash log ever captured)

## What was already known (2026-07-14)

`usbl_tutorial.world` (world-only test, no vehicle spawn): the server-side
`UsblTransceiver`/`UsblTransponder` plugins load and publish correctly, but the
Gazebo GUI client crashes. No stack trace, error message, or exit code was ever
recorded — the bug has only ever been documented as an outcome, not diagnosed.

## Investigation this session

**1. Is there a USBL-specific GUI plugin that could be crashing?**

No. Searched the full checked-out source
(`dave_ws_lyrical/src/dave/gazebo/dave_gz_sensor_plugins/`): `UsblTransceiver.cc`/`.hh`
and `UsblTransponder.cc`/`.hh` both derive only from `gz::sim::System` +
`ISystemConfigure`/`ISystemPostUpdate` — pure server-side systems. No
`gz::gui::Plugin`, `QQuickItem`, `.qml` file, or rendering call anywhere in
either file. There is no USBL-specific GUI code in this codebase at all, so a
USBL-specific rendering bug isn't a plausible cause.

**2. What's actually different about `usbl_tutorial.world`?**

Read the full file
(`dave_ws_lyrical/src/dave/models/dave_worlds/worlds/usbl_tutorial.world`,
134 lines). It is a bare-bones tutorial world: two Fuel `<include>`s (Ground
Plane, Sun), three simple `<model>` blocks (a box + two spheres) carrying the
USBL plugins, and nothing else. Specifically it is **missing every one of the
standard system plugins present in every other tested world**:

- No `gz-sim-physics-system` / `Physics`
- No `gz-sim-scene-broadcaster-system` / `SceneBroadcaster`
- No `gz-sim-user-commands-system` / `UserCommands`
- No `gz-sim-sensors-system` / `Sensors` (which is where `dave_ocean_waves.world`
  explicitly sets `<render_engine>ogre2</render_engine>`, line 49)
- **No `<gui>` block at all**

Compare to `dave_ocean_waves.world` (PASS, REXROV test, 2026-07-13) and
`dave_multibeam_sonar.world` (PASS, sonar test) — both explicitly declare
`<render_engine>ogre2</render_engine>` inside their `Sensors` system plugin,
and both carry an explicit `<gui fullscreen='0'>...</gui>` block with camera
pose/view-controller settings (`dave_ocean_waves.world:116-122`).

**3. Does the ogre2→ogre patch already applied elsewhere cover this world?**

No. Grepped `patches/dave_lyrical_jetty_migration_mac.diff` for `usbl`,
`ogre`, and `render_engine` — the diff touches 8 CMake/C++ files only (linking
fixes for the Jetty `gz-rendering` rename), never a `.world` file. **No world
file in this repo has ever had an ogre2→ogre swap applied via the tracked
patch.** The already-documented "OGRE2 unavailable... GUI launches fail unless
world files are patched ogre2 → ogre" Known Issue must refer to a manual/live
edit that was never captured in the committed diff, or to a `--render-engine`
command-line override — not tracked here either way.

## Hypothesis

`usbl_tutorial.world` has no `<gui>` element, so when launched with `gui:=true`,
Gazebo falls through to its own **stock default GUI config** (not this
project's per-world custom config) — a different code path than every other
world that was actually confirmed working over RDP. That stock default is the
most likely place the already-known, already-confirmed-separately OGRE2
unavailability on this Ubuntu 26.04 aarch64 setup (see README Known issues)
resurfaces, this time with nothing to catch it.

This is circumstantial, not proven: no crash log has ever been captured to
confirm the failure signature is actually `Failed to load plugin [ogre2]`
rather than something else entirely.

## Recommended next step (needs to be run in the container/Mac — this sandbox has no Gazebo)

Two independent tests, either would help confirm or rule this out:

```bash
# Test A: force the OGRE1 fallback renderer on the unmodified world
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=usbl world_name:=usbl_tutorial gui:=true headless:=true \
  --ros-args -p render_engine_gui:=ogre
# (if that launch arg isn't wired through, try the raw gz-sim flag instead:)
gz sim -v 4 --render-engine-gui ogre <path-to>/usbl_tutorial.world
```

```bash
# Test B: add the same <gui> block dave_ocean_waves.world uses (known-working)
# to a local copy of usbl_tutorial.world, then relaunch normally:
#   <gui fullscreen='0'>
#     <camera name='user_camera'>
#       <pose frame=''>10 -1 5 0 0.3 2.2</pose>
#       <view_controller>orbit</view_controller>
#       <projection_type>perspective</projection_type>
#     </camera>
#   </gui>
```

If either test produces a real crash log this time (stack trace, signal
number, exact error line), that turns this from a hypothesis into a confirmed
root cause — please paste the output back and I'll finish the diagnosis and
draft the actual world-file fix.
