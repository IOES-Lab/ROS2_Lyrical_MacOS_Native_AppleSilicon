# USBL GUI Crash — Root Cause Investigation (2026-07-22)


> **Current status — revalidated 2026-08-27 on Mac and Docker.** The historical
> `dave_sensor.launch.py namespace:=usbl ... paused:=false` command below is no
> longer the recommended Quickstart: it produces data from the world-embedded
> plugins but also tries to spawn nonexistent `description/usbl/model.sdf`.
> Use `ros2 launch dave_demos dave_world.launch.py world_name:=usbl_tutorial`.
> Common and individual paths passed on both platforms. Literal `sigma=0` is
> platform-dependent: macOS/libc++ returned finite data, Docker/libstdc++
> aborted with exit 134. Current evidence:
> [`results/usbl_direct_validation_2026-08-27/`](results/usbl_direct_validation_2026-08-27/).


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
  of which fix ships here. **These are the remaining implementation/upstream
  gaps** — the crash itself is fully worked around and persisted; what's left
  here is the plugin-level hardening and the upstream report. (Reworded
  2026-07-23, twice: an earlier version said "the only functional gap
  remaining," which read too broadly; a subsequent pass changed it to "the
  only USBL-specific gap remaining," which still read confusingly right next
  to the separate evidence-scope gap described below — reworded again to
  avoid the word "only" entirely. That separate gap, for the same world,
  downgraded its overall status from FUNCTIONAL PASS to PARTIAL: no single
  test run has confirmed both real topic data *and* the post-fix no-abort
  state at once — see [Verified demos](verified-demos.md) in the
  main README. That gap is about test coverage, not about the crash fix
  itself, so it's tracked there rather than as a third bullet here.)

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
patch.** The then-documented "OGRE2 unavailable... GUI launches fail unless
world files are patched ogre2 → ogre" Known Issue must refer to a manual/live
edit that was never captured in the committed diff, or to a `--render-engine`
command-line override — not tracked here either way. **That Known Issue was
itself withdrawn on 2026-08-21** — OGRE2 is present and a stock `gpu_lidar`
runs on it in the same container; the crash is sonar-specific. This paragraph
is left as written because its point about the patch not being tracked stands
regardless.

## Hypothesis

`usbl_tutorial.world` has no `<gui>` element, so when launched with `gui:=true`,
Gazebo falls through to its own **stock default GUI config** (not this
project's per-world custom config) — a different code path than every other
world that was actually confirmed working over RDP. At the time, that stock default was suspected to be where the project's
then-current OGRE2-availability hypothesis resurfaced. **That hypothesis was
withdrawn on 2026-08-21**: OGRE2 is present and the retained evidence points to
a DAVE-sonar-specific crash instead. This paragraph records the historical
hypothesis; it is not a current diagnosis. See `notes/known-issues.md`.

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

## Update (2026-07-29): live debugging session — new precondition bug found, deeper issue still open

Goal: close the evidence-scope gap noted above (no single run has confirmed
both real `transponder_location` data and the post-sigma-fix no-abort state
at once). Live session against `lyrical-theme-test`, launch command
`ros2 launch dave_demos dave_sensor.launch.py namespace:=usbl
world_name:=usbl_tutorial gui:=true headless:=true` (started 01:38 UTC,
stayed alive with no abort throughout — the sigma fix continues to hold).

### Tooling detour: `ros2 topic echo` is broken in this environment (not a project bug)

`ros2 topic echo <any topic>` — including `/rosout`, ruling out a
`dave_interfaces` type-loading cause — fails immediately with either
`RuntimeError: !rclpy.ok()` or `RCLError: failed to initialize wait set: the
given context is not valid...`, while `ros2 topic pub`, `ros2 topic list`,
and `ros2 topic info -v` all work normally on the same daemon/session. Stack:
`ROS 2 Lyrical` + Python 3.14 + `rclpy` 10.0.10 + `ros2cli` 0.40.7 (all built
2026-06-06, `arm64`). Checked
[ros2/rclpy#1221](https://github.com/ros2/rclpy/issues/1221) (same
`!rclpy.ok()` string, but for `topic list`, fixed by a daemon restart — tried
here too, didn't fully resolve it) and
[ros2/ros2cli#519](https://github.com/ros2/ros2cli/issues/519) (`echo`
crashing on a *nonexistent* topic, different error, different cause) —
neither matches. No confirmed upstream report for this exact combination was
found. **Workaround used for the rest of this session:** a standalone
`rclpy` Python subscriber (`rclpy.init()` / `create_subscription` /
`rclpy.spin()`) in place of the CLI `echo` verb — this ran cleanly with no
`!rclpy.ok()`/wait-set errors while receiving (or failing to receive)
messages. Separately confirmed: *any* spinning `rclpy` process in this
container reliably raises `RCLError: failed to initialize wait set` when it
receives SIGTERM, whether from `timeout` or a plain `kill` — this is a
shutdown-path artifact of this environment/version combination, not evidence
that a message was or wasn't delivered, and should be disregarded as noise
when it appears at the tail of an otherwise-successful run.

### Real finding: `UsblTransponder`'s own `m_interrogationMode` has no default

`UsblTransceiver::Configure()` (lines ~263-283) explicitly defaults
`m_interrogationMode` to `"common"` whenever the SDF's `<interrogation_mode>`
is missing or invalid. `UsblTransponder` has its own, separate
`m_interrogationMode` member (`UsblTransponder.cc`) — grep-confirmed
(`grep -n 'interrogation_mode\|m_interrogationMode ='`) it is **never**
assigned inside `Configure()` at all; the only assignment in the whole file
is inside `interrogationModeCallback` (line 349), bound to a subscription on
`{transceiver_device}_{transceiver_id}/interrogation_mode`. `usbl_tutorial.world`
never publishes to that topic (it's a bare two-sphere/one-box tutorial world
with no vehicle, no teleop, no keyboard publisher), so the transponder's
`m_interrogationMode` starts, and stays, as a default-constructed empty
string. `cisRosCallback`'s gate (`UsblTransponder.cc:315`,
`m_interrogationMode.compare("common") == 0`) therefore always evaluates
false, so pinging `common_interrogation_ping` does nothing — silently, no
error printed anywhere. **This is a real, previously-undocumented usability
gap**, independent of the already-fixed sigma/SIGABRT bug: this world cannot
produce any USBL sensor output unless something external first publishes
`"common"` (or `"individual"`, matching a channel) to the transceiver's
`interrogation_mode` topic — nothing in the world file, launch file, or
plugin defaults does this automatically.

### Still unresolved: the ping chain doesn't work even once the precondition is met

Manually published `"common"` to
`/USBL/transceiver_manufacturer_168/interrogation_mode` — confirmed
delivered (`ros2 topic info -v` showed 2 matched subscriber nodes,
`usbl_transponder_1_node`/`usbl_transponder_2_node`, before and after) — then
repeatedly published to `/USBL/common_interrogation_ping`, using both
`--once` and rate-repeated `-r 2` publishing over several seconds, with a
standalone `rclpy` subscriber left running continuously (30s+ windows,
correct start-before-ping ordering confirmed via a single self-contained
`nohup ... & sleep ... ; pub ; sleep ... ; kill` script to eliminate
terminal-timing mistakes). **Zero `transponder_location` messages were ever
received.** Critically, the live launch terminal's own scrollback (found via
`ps aux` — the `ros2 launch`/`gz sim` processes were confirmed still alive
throughout — then located and read directly) still showed only its original
01:38 startup output, with **nothing appended** since, across the entire
session. None of `cisRosCallback`'s own `gzmsg` lines ever printed —
`"In common mode, publishing position..."`, `"Transceiver acquires
transponder_..."`, nor even the failure-path `"Interrogation mode is not set
to common and wrong channel is being pinged"`. This means `cisRosCallback`
itself was never invoked, despite ROS2/DDS reporting the topic as fully
matched (`Publisher count: 1` / `Subscription count: 2`, correct QoS on both
sides). That's a genuine, unexplained gap between confirmed DDS-level topic
matching and the plugin's C++ subscription callback actually firing —
possible causes not yet ruled out include a stale/non-functional endpoint
match (a known `rmw` failure mode in some FastDDS/CycloneDDS versions), an
issue specific to this very new Python 3.14 + `rclpy` 10.0.10 + Gazebo Jetty
combination, or something entirely inside the Gazebo-transport leg between
`UsblTransponder::sendLocation()` and `UsblTransceiver::receiveGazeboCallback`
that was never reached.

### Resolved (same session): the world was loading paused, blocking every ROS2 callback

The "matched but never invoked" mystery above turned out to have a concrete,
checkable cause rather than needing code instrumentation. Both
`UsblTransponder::PostUpdate` and `UsblTransceiver::PostUpdate` read:

```cpp
void UsblTransponder::PostUpdate(
  const gz::sim::UpdateInfo & _info, const gz::sim::EntityComponentManager & _ecm)
{
  if (!_info.paused)
  {
    rclcpp::spin_some(this->ros_node_);
  }
}
```

`rclcpp::spin_some()` — the call that actually invokes any pending ROS2
subscription callback — only runs when the simulation is **not paused**.
Checking the actual `gzserver` process command line (`ps aux` inside the
container) showed:

```
/bin/sh -c ruby ... gz sim .../usbl_tutorial.world -s --force-version 10
```

No `-r` (run-on-start) flag. `gz sim` loads **paused** by default unless
`-r` is passed. Reading `dave_ws/install/share/dave_demos/launch/dave_sensor.launch.py`
directly confirmed why: it only appends `-r` to `gz_args` when the launch is
given `paused:=false` explicitly —

```python
if paused.perform(context) == "false":
    gz_args.append(" -r")
```

— and every launch command used in this investigation (today's and all
prior sessions') omitted `paused:=false`. So the world sat paused the entire
time, `spin_some()` never ran, and **no ROS2 subscription callback in either
USBL plugin could ever fire** — independent of, and invisible to, DDS-level
topic matching (`ros2 topic info -v` reports a matched subscription based on
discovery/QoS, not on whether an executor is actually pumping it). This also
explains why a live unpause attempt failed: `usbl_tutorial.world` has no
`gz-sim-user-commands-system` plugin (confirmed in the original 2026-07-22
investigation above), so there's no `/world/.../control` service to call on
an already-running instance — `gz service -s /world/usbl_tutorial/control
--reqtype gz.msgs.WorldControl --reptype gz.msgs.Boolean --timeout 3000
--req 'pause: false'` timed out for exactly this reason.

It does **not** explain why other sensors (DVL, camera, ocean current, sea
pressure) worked fine under the same paused-by-default launch — those are
pure Gazebo→ROS2 publishers with no incoming ROS2 subscription of their own,
so they never depended on `spin_some()` running at all. USBL is the only
plugin in this codebase whose function depends on a ROS2→Gazebo trigger
(the interrogation ping), which is why it's the only one this affects.

**Fix (launch-arg-only, no code/world-file change needed):** killed the
paused instance and relaunched with `paused:=false` added:

```bash
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=usbl world_name:=usbl_tutorial gui:=true headless:=true paused:=false
```

In that one continuous run: launch stayed alive with no abort (sigma fix
from the section above still holding), then publishing `"common"` to
`/USBL/transceiver_manufacturer_168/interrogation_mode` followed by a ping to
`/USBL/common_interrogation_ping` produced real, continuous
`dave_interfaces/msg/Location` data from both transponders on a standalone
`rclpy` subscriber, e.g.:

```
GOT MESSAGE: dave_interfaces.msg.Location(transponder_id=2, x=45.00038091462625, y=8.49991150276506, z=3.372572927772231)
GOT MESSAGE: dave_interfaces.msg.Location(transponder_id=1, x=44.999848218814634, y=4.271884882357488, z=6.723046481272813)
```

This closes the combined-evidence gap that kept `usbl_tutorial` at `PARTIAL`
since 2026-07-23: real topic data and the post-sigma-fix no-abort state are
now confirmed in a single run. **Upgraded to `FUNCTIONAL PASS`** in
[`validation_matrix.csv`](validation_matrix.csv) and the main README's
Verified demos table.

**Still not done:** neither bug has a plugin/world-level fix that removes
the need for the workaround — `paused:=false` must still be passed
explicitly every time (nothing defaults it), and the sigma fix is still a
world-file epsilon rather than a plugin-level guard. Not yet reported
upstream; a single report covering both the sigma/SIGABRT bug and the
paused-state/`spin_some()` gap (both live in the same two plugin files)
would be the natural way to file it.

## Direct cross-platform revalidation (2026-08-27)

The July root-cause findings were rerun rather than accepted from the old log.
Controlled worlds outside the DAVE checkout exercised common mode and each
individual channel on Mac and Docker. Both transponders produced spherical and
Cartesian data in common mode; individual channels returned only the selected
ID. Across retained positive-sigma runs, the maximum static-coordinate axis
error was `0.000258 m`.

The paused control retained all expected graph endpoints but produced zero
output samples on both platforms. The literal-zero control split by standard
library: libc++ accepted `sigma=0`, while libstdc++ aborted on the first ping
with `_M_stddev > 0` and exit 134. The epsilon world patch therefore remains a
portability workaround, not a plugin fix.

The old Wiki command was also found to be structurally wrong. Because the USBL
plugins are embedded in `usbl_tutorial.world`, the generic sensor launcher can
still produce data while simultaneously failing to spawn nonexistent
`dave_sensor_models/description/usbl/model.sdf`. The world-only launcher was
then run on both platforms, produced both IDs, and emitted no missing-model
error:

```bash
ros2 launch dave_demos dave_world.launch.py world_name:=usbl_tutorial
```

Evidence: [`results/usbl_direct_validation_2026-08-27/`](results/usbl_direct_validation_2026-08-27/).
