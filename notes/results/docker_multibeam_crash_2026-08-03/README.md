# Docker: `dave_multibeam_sonar` crashes at sensor initialisation (2026-08-03)

Attempting to re-measure the Docker RTF figure with the corrected settle produced
something else entirely: **the world does not start.** It crashes during sonar
sensor initialisation, in two different places depending on the render engine.

This has to be resolved before any Docker RTF number means anything, and it puts
the existing ~0.0018 figure in question.

## Environment

- Container `lyrical-theme-test`, image `lyrical-sim:jetty-rdp-theme`, up 13 days
- Ubuntu 26.04 aarch64, ROS 2 Lyrical, Gazebo Jetty 10.4 (`--force-version 10`)
- Workspace `/home/docker/dave_ws` (note: `docker exec` attaches as **root**, so
  `$HOME` is `/root` and `~/dave_ws` does not exist — see RUN_DOCKER.md)
- Headless server: `gz sim <world> -s -r`
- WGPU compute backend selected successfully:
  `[sonar_wgpu] [all] selected adapter: llvmpipe (LLVM 21.1.8, 128 bits)`

Exact command (via `dave_sensor.launch.py`):

```
namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false
x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

## Failure 1 — `ogre2`: segfault in GPU rays texture creation

The world file ships with `<render_engine>ogre2</render_engine>` (line 16) and
`<engine>ogre2</engine>` (line 40), in both `src/` and `install/`. **The
`ogre2` → `ogre` patch described in the main README is not applied here.**

The sonar plugin loads correctly first — `SONAR PLUGIN LOADED`, `# of Beams = 513`,
`# of Rays / Beam = (301, 1)`, `# of Time data / Beam = 399` — and then:

```
Ogre2Scene::PreRender()
  -> Ogre2GpuRays::PreRender()
    -> Ogre2GpuRays::CreateGpuRaysTextures()
      -> Ogre2GpuRays::CreateSampleTexture()
        -> __memcpy_generic
Segmentation fault (Address not mapped to object [(nil)])
exit code 139
```

`libgz-rendering-ogre2.so.10.0.1`. A null-pointer `memcpy`.

**Reproduced twice**, same stack both times, on fresh launches.

Note this is *not* the "OGRE2 unavailable / `Failed to load plugin [ogre2]`"
failure recorded in the main README. Here ogre2 loads and executes as far as
`PreRender` before crashing. It may be the same underlying gap presenting
differently in the server, but that is an inference, not something confirmed.

## Failure 2 — `ogre`: abort while loading the GL render system

Patching the installed world to `ogre` removes the segfault but does not make it
run. It aborts earlier, during render-engine load:

```
BaseRenderEngine::Load()
  -> OgreRenderEngine::LoadImpl()
    -> OgreRenderEngine::LoadAttempt()
      -> OgreRenderEngine::LoadPlugins()
        -> RenderSystem_GL.so.1.9.0  dllStartPlugin
          -> Ogre::Root::installPlugin
            -> _Unwind_Resume -> __cxa_call_terminate -> abort
Aborted, exit code 134
```

OGRE 1.9's GL render system throws during plugin install and the exception
crosses a `noexcept` boundary, so it terminates. No `SONAR PLUGIN LOADED` line at
all in this run — it dies before the sensor is reached.

**Method note:** the first check for this used `grep -c 'Segmentation fault'`,
which returned 0 and was briefly read as success. It was not — the failure mode
had simply changed from segfault to abort. Liveness (`pgrep`) or exit code is the
correct test, not one signature.

## Summary

| render engine | result | exit | reproduced |
|---|---|---|---|
| `ogre2` (as shipped) | segfault in `Ogre2GpuRays::CreateSampleTexture()` | 139 | 2/2 |
| `ogre` | abort in `RenderSystem_GL` plugin install | 134 | 1/1 |

## `DISPLAY` was tested and did not help

The container runs xrdp and an X socket exists (`/tmp/.X11-unix/X10`), but the
launches above ran from a bare `docker exec` shell with `DISPLAY` unset. Re-running
with `DISPLAY=:10` (world still on `ogre`) changed nothing:

```
살아있나: 0                                    # no gz sim process
grep -c 'SONAR PLUGIN LOADED'  ->  0           # never reached the sensor
Aborted, exit code 134                         # same failure as without DISPLAY
```

**Caveat:** only `DISPLAY` was set. `XAUTHORITY` was not, and the X server belongs
to an xrdp session owned by another user, so the connection may have been refused
for authorisation reasons rather than the display being irrelevant. The log shows
no distinct "cannot open display" message, and the abort is byte-for-byte the same
place, but this is weak evidence against the hypothesis rather than a clean
refutation. A proper test would run from inside an actual RDP/XFCE session.

## Conclusion

**`dave_multibeam_sonar` does not run in this container today, on either render
engine.** It is not slow — it does not start.

## Open — what changed since 2026-07-29?

On 2026-07-29 this same world ran in this same container for a ~34 minute
gdb-attached session, making slow but continuous progress. It did not crash.
Today it does not start on either engine. Something differs and it is not the
code.

The `DISPLAY` hypothesis was the obvious candidate and it did not pan out (above),
though the `XAUTHORITY` gap leaves it not fully closed.

Other differences not yet checked:

- Container state drift over 13 days of uptime (`lyrical-theme-test` has been up
  since ~2026-07-21): loaded modules, `/tmp` contents, prior crashed runs.
- Whether the 2026-07-29 run used the same `compute_backend:=wgpu` and the same
  headless `-s` server path.

But see the next section first — the 2026-07-29 RTF numbers appear not to be
about this world at all.

## The 2026-07-29 figure was read from the wrong topic

The 2026-07-29 Progress Log entry states:

> `/world/oceans_waves/stats` (the world's actual internal name — it differs from
> the `dave_multibeam_sonar.world` filename)

**That is incorrect.** Checked directly in the world files, on both the Mac
workspace and inside this container:

| world file | `<world name>` |
|---|---|
| `dave_multibeam_sonar.world` | **`default`** |
| `dave_ocean_waves.world` | `oceans_waves` |
| `dave_ocean_waves_sonar.world` | `oceans_waves` |
| `dave_ocean_waves_sonar_integrated.world` | `oceans_waves_sonar_integrated` |

`dave_multibeam_sonar`'s internal name is `default`, not `oceans_waves`. Today's
`/world/default/stats` samples on Mac are consistent with this.

So `/world/oceans_waves/stats` belongs to `dave_ocean_waves` or
`dave_ocean_waves_sonar` — and the 2026-07-29 entry records that **a 4-hour
`dave_ocean_waves` stability run was executing in the same container at the same
time.** That entry corrected for having initially attached `gdb` to the wrong PID,
but the topic name was apparently not revisited.

**Consequence: the ~0.0018 RTF and the "continuous but extremely slow progress"
characterisation most likely describe `dave_ocean_waves` under the concurrent
stability test, not `dave_multibeam_sonar`.** The `gdb` evidence (program counter
moved between snapshots) does concern the correct process and stands on its own;
the RTF numbers do not.

This is inference from the world-name mismatch plus the recorded concurrency, not
a re-run of that day. It has not been directly disproven by re-measurement,
because the world no longer starts at all.

### Related hazard

`dave_ocean_waves.world` and `dave_ocean_waves_sonar.world` **both** declare
`<world name="oceans_waves">`. Running them together produces colliding topic
namespaces, and a `/world/oceans_waves/stats` sample cannot be attributed to
either one. Worth reporting upstream, and worth avoiding in any future concurrent
test.

## Consequence for the record

The Docker `dave_multibeam_sonar` RTF figure (~0.0018, 2026-07-29) should be
**withdrawn**, not merely marked unreproduced: it was read from `/world/oceans_waves/stats`,
which is not this world. Every downstream claim built on it goes with it —
including "Docker is ~123x worse than Mac", which compared that number against
the Mac figures. There is currently **no valid Docker RTF measurement** for this
world, and none can be taken until the crash is resolved. The `llvmpipe` hypothesis for the gap
remains untested — note that WGPU adapter selection succeeded on llvmpipe here,
and the crash is in the OGRE rendering path, which is a separate concern from
the WGPU compute backend.
