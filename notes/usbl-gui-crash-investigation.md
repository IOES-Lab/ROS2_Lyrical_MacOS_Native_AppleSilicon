# USBL GUI Crash — Root Cause Investigation (2026-07-22)

## Status: CONFIRMED (2026-07-22, `notes/results/usbl_tutorial.log`)

**This is not a GUI crash.** It is the Gazebo **server** process (`gz sim ... -s -r`, `-s`
= server-only) aborting with `SIGABRT` (exit code 134). Real captured log:

```
[gazebo-1] /usr/include/c++/15/bits/random.h:2138: std::normal_distribution<_RealType>::param_type::param_type(_RealType, _RealType) [with _RealType = double]: Assertion '_M_stddev > _RealType(0)' failed.
[gazebo-1] Aborted
[ERROR] [gazebo-1]: process has died [pid 3148, exit code 134, cmd 'ruby /opt/ros/lyrical/opt/gz_tools_vendor/bin/gz sim /home/docker/dave_ws/install/share/dave_worlds/worlds/usbl_tutorial.world -s -r --force-version 10'].
```

**Root cause, confirmed at the source line:** `UsblTransponder.cc:263`
(`dave_ws_lyrical/src/dave/gazebo/dave_gz_sensor_plugins/src/UsblTransponder.cc`):

```cpp
std::normal_distribution<> d(this->dataPtr->m_noiseMu, this->dataPtr->m_noiseSigma);
```

`m_noiseSigma` is read unvalidated straight from the world file's `<sigma>` SDF
param (line 197: `this->dataPtr->m_noiseSigma = _sdf->Get<double>("sigma");`).
`usbl_tutorial.world` sets `<sigma>0.0</sigma>` on **both** `UsblTransponder`
plugin instances (`sphere` model, `sphere2` model). libstdc++'s
`std::normal_distribution` constructor requires `stddev > 0` (strictly), so
`sigma=0.0` trips a `_GLIBCXX_ASSERTIONS`-style abort on this Ubuntu
26.04/gcc-15 build. The plugin's own default (`m_noiseSigma = 1.0`, line 82)
is safe — the world file explicitly overrides it to the unsafe value.

**Why this only surfaces here:** the code default is safe (1.0); only this
specific world file's explicit `sigma=0.0` triggers it, and whether the
assertion is even compiled in depends on the libstdc++ build flags — plausibly
why this wasn't caught on the original Jazzy+Harmonic target platform.

**Fix applied and verified (2026-07-22):** patched `<sigma>0.0</sigma>` →
`<sigma>0.0001</sigma>` on both `UsblTransponder` instances in
`usbl_tutorial.world` (world-file fix, no C++ rebuild needed — saved as
[`patches/usbl_sigma_fix.diff`](../patches/usbl_sigma_fix.diff)). Verified
live: copied the patched world file into the running `lyrical-theme-test`
container (`docker cp` over the built-in copy at
`/home/docker/dave_ws/install/share/dave_worlds/worlds/usbl_tutorial.world`)
and re-ran the exact launch command with a 15s `timeout` — the process
survived the full window with no assertion/abort, versus dying within ~3s
before the fix.

**Update (2026-07-22, later same day):** the Docker *image* fix landed —
`docker/lyrical.arm64v8.dockerfile` now includes a cache-preserving late-layer
`sed` step that patches the already-installed `usbl_tutorial.world` (with a
build-time `grep -q` assertion so the build fails loudly if the pattern ever
stops matching), re-verified end-to-end on a fresh image build (16.1s,
all prior layers cache-hit). This fix is no longer container-local/lost-on-recreation
— it's baked into the image build itself.

**Still not done:**
- Not reported upstream to `naitikpahwa18/dave` or `IOES-Lab/dave` yet.
- The more defensive **plugin-level fix** (guard `sigma <= 0` in
  `UsblTransponder.cc` around line 263 and skip noise/return `mu` instead of
  asserting) was not applied — the world-file epsilon is a valid workaround
  but the plugin itself would still crash on a *literal* zero from any other
  world file or user config. Worth flagging in an upstream report regardless
  of which fix ships here. **This is the only functional gap remaining** —
  the crash itself is fully worked around and persisted; what's left is the
  plugin-level hardening and the upstream report.

## Superseded: earlier same-day hypothesis (WRONG, kept below for the record)

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
