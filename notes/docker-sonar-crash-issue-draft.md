# Upstream issue draft — `dave_multibeam_sonar` does not start on Ubuntu 26.04 aarch64

**Status:** Draft, not yet filed. **Read the "Before filing" section first — this one has a
genuine scoping problem that the other drafts do not.**

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave) for the
world-file/documentation part. The segfault itself is inside `gz-rendering`, so it may
belong at [`gazebosim/gz-rendering`](https://github.com/gazebosim/gz-rendering) instead —
see below.

**Suggested labels:** `bug`, `crash`

---

## Before filing — what we can and cannot claim

We observed this on **one container, one architecture, one GPU stack**. That is enough to
report an observation; it is not enough to claim a general defect. Specifically:

- We have **not** tested any other aarch64 machine, any x86_64 machine, or hardware GPU.
- We have **not** determined whether the trigger is `llvmpipe` (software rendering), the
  aarch64 build, Ubuntu 26.04's OGRE packaging, or something about the sonar's GpuRays
  configuration in particular.
- We have **not** minimised the reproducer to a plain GpuRays sensor without DAVE.

**A maintainer's first question will be "does this happen with a stock GpuRays sensor?"**
That test is cheap and would sharpen the report considerably — a small SDF with a
`gpu_lidar` at 513×301 on the same container, no DAVE plugin. If it crashes too, this is a
`gz-rendering` issue and should be filed there with DAVE dropped from the report entirely.
If it does not, the report stays with DAVE and the sonar's usage becomes the suspect.

Consider doing that before filing.

## Title

`dave_multibeam_sonar` crashes at sensor initialisation on Ubuntu 26.04 aarch64 —
segfault in `Ogre2GpuRays::CreateSampleTexture()` with `ogre2`, abort in `RenderSystem_GL`
with `ogre`

## Summary

On an Ubuntu 26.04 aarch64 container with `llvmpipe` software rendering, the
`dave_multibeam_sonar` world does not start. It fails in two different places depending on
the render engine, so neither the shipped configuration nor the documented workaround
produces a running world.

## Steps to reproduce

```bash
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
  x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

## Failure 1 — as shipped (`ogre2`): segfault

The world file declares `<render_engine>ogre2</render_engine>` (line 16) and
`<engine>ogre2</engine>` (line 40).

The sonar plugin initialises correctly first — `SONAR PLUGIN LOADED`,
`# of Beams = 513`, `# of Rays / Beam = (301, 1)`, `# of Time data / Beam = 399` — and the
WGPU compute backend selects an adapter without complaint
(`[sonar_wgpu] [all] selected adapter: llvmpipe (LLVM 21.1.8, 128 bits)`).

Then:

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
**Reproduced 2/2 on fresh launches, identical stack.**

## Failure 2 — patched to `ogre`: abort

Switching the world to `<render_engine>ogre</render_engine>` removes the segfault but does
not produce a running world. It dies earlier, during render-engine load:

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

OGRE 1.9's GL render system throws during plugin install and the exception crosses a
`noexcept` boundary, so the process terminates. `SONAR PLUGIN LOADED` never appears — it
dies before reaching the sensor. This looks like a missing GL context rather than a DAVE
problem.

Setting `DISPLAY=:10` against the container's live xrdp X socket did not change it. Caveat:
only `DISPLAY` was set, not `XAUTHORITY`, and the X server belongs to another user's
session, so the connection may have been refused for authorisation reasons. That is weak
evidence, not a clean refutation.

## Note for DAVE specifically

Independent of where the crash belongs, one thing is squarely a DAVE-side observation:

The project README documents that OGRE2 is unavailable on Ubuntu 26.04 aarch64 and that
world files need patching `ogre2` → `ogre`. **The world files as shipped are not patched**,
and in this environment the patch does not help either — it swaps one crash for another.
So the documented workaround does not currently produce a working world here.

Also worth distinguishing: the README describes the OGRE2 problem as a *load failure*
(`Failed to load plugin [ogre2]`). What we see is different — ogre2 loads and executes as
far as `PreRender` before crashing. These may share a root cause, but that is an inference,
not something we confirmed.

## Environment

- Container image `lyrical-sim:jetty-rdp-theme`, up 13 days at time of testing
- Ubuntu 26.04 aarch64, ROS 2 Lyrical, Gazebo Jetty 10.4 (`--force-version 10`)
- Rendering: `llvmpipe` software rasteriser, no `/dev/dri` passthrough
- Headless server (`gz sim <world> -s -r`)
- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`
- **Not reproduced anywhere else — see "Before filing" above**

## For contrast: the same world runs on macOS

On Apple Silicon with Metal, this world runs and simulates steadily (RTF ~0.19–0.22 against
a no-sonar control of 0.9996). So this is not a general defect in the sonar world or the
WGPU backend — it is specific to this rendering environment.

Full write-up and raw logs:
[`notes/results/docker_multibeam_crash_2026-08-03/`](results/docker_multibeam_crash_2026-08-03/)
