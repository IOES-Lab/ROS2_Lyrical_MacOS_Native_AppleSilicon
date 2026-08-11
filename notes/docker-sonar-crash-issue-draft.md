# Upstream issue draft — `dave_multibeam_sonar` segfaults in `Ogre2GpuRays` where a stock `gpu_lidar` does not

**Status:** Draft, ready to file. Scoping resolved 2026-08-07.

**Scope note (2026-08-07):** this draft used to cover two failures. The second one — an
`abort` when the world was patched to `ogre` — turned out **not to be a bug at all**: OGRE1
needs an X display, and once one was supplied correctly the world ran and published sonar
data. That half has been moved to
[`ogre-x-display-doc-correction.md`](ogre-x-display-doc-correction.md) as a documentation
correction. **Only the `ogre2` segfault is reported here.**

**Suggested target repo:** [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave). The crash
occurs inside `libgz-rendering-ogre2`, but a stock `gpu_lidar` at the same ray count does
**not** crash there, so this is not a plain `gz-rendering` defect — see below. If DAVE
maintainers conclude the sonar's `GpuRays` usage is correct, this should be forwarded to
[`gazebosim/gz-rendering`](https://github.com/gazebosim/gz-rendering) with that assessment
attached.

**Suggested labels:** `bug`, `crash`

---

## Title

`dave_multibeam_sonar` segfaults in `Ogre2GpuRays::CreateSampleTexture()` on Ubuntu 26.04
aarch64, where a stock `gpu_lidar` at the same 513 × 301 ray count runs fine

## Summary

On an Ubuntu 26.04 aarch64 container with `llvmpipe` software rendering, the
`dave_multibeam_sonar` world crashes at sensor initialisation with the shipped
`<render_engine>ogre2</render_engine>`.

The sonar plugin initialises correctly first — `SONAR PLUGIN LOADED`, `# of Beams = 513`,
`# of Rays / Beam = (301, 1)`, `# of Time data / Beam = 399` — and the WGPU compute backend
selects an adapter without complaint
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

## Why this is not simply a `gz-rendering` limit

The obvious first question is whether `ogre2` can drive 154,413 rays at all under
`llvmpipe`. It can.

A minimal world with **no DAVE code** — base systems, a ground plane, a target box, and one
`<sensor type="gpu_lidar">` at the sonar's own 513 × 301 — was run in the same container, on
`ogre2`:

| platform | rays | result |
|---|---|---|
| this container, `ogre2` | 154,413 / 8,192 / 16 | **initialises and publishes, 3/3** |
| macOS Metal (control), `ogre2` | 154,413 / 8,192 / 16 | initialises and publishes, 3/3 |

So the crash is not "`ogre2` GpuRays cannot do this ray count here". Something about how the
sonar creates or configures `GpuRays` triggers it.

**What that does not establish.** The two paths are not identical: the stock sensor is built
by `gz-sensors` from `<sensor type="gpu_lidar">`, while the sonar is
`<sensor type="custom" gz:type="multibeam_sonar">` and constructs `gz::rendering::GpuRays`
in its own code. Both end in `Ogre2GpuRays`, but they do not get there the same way. **This
narrows the suspect to the sonar's usage; it does not identify which call**, and we have not
diffed the two configuration sequences.

Probe world and script: [`notes/experiments/gpu_lidar_probe.world`](experiments/gpu_lidar_probe.world),
[`notes/experiments/exp13_gpu_lidar.sh`](experiments/exp13_gpu_lidar.sh).
Data: [`notes/results/gpu_lidar_probe_2026-08-07/`](results/gpu_lidar_probe_2026-08-07/).

## Steps to reproduce

```bash
ros2 launch dave_demos dave_sensor.launch.py \
  namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
  x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true
```

The world file ships with `<render_engine>ogre2</render_engine>` (line 16) and
`<engine>ogre2</engine>` (line 40); no patching is needed to hit this.

## The same world does run — two ways

**On macOS / Apple Silicon / Metal**, as shipped. Its cost there is characterised: 1.90x
against a no-sonar control (0.5243 vs 0.9974, n=3 each), most of which is recoverable by
lowering the sensor's unreachable 30 Hz `<update_rate>` (a separate report).

**In this same container**, if the world is patched to `<render_engine>ogre</render_engine>`
**and** an X display is supplied correctly — sensor initialises, simulation steps, and
`/sensor/multibeam_sonar/point_cloud` publishes. See
[`ogre-x-display-doc-correction.md`](ogre-x-display-doc-correction.md).

So this is not a defect in the sonar world or the WGPU backend generally. It is specific to
the `ogre2` path in this environment.

## What we can and cannot claim

- **One container, one architecture, one GPU stack.** Not tested on any other aarch64
  machine, any x86_64 machine, or with a hardware GPU.
- **The trigger is not isolated.** It could be `llvmpipe`, the aarch64 build, Ubuntu 26.04's
  OGRE2 packaging, or the sonar's specific `GpuRays` configuration. The stock-`gpu_lidar`
  comparison rules out "any GpuRays at this ray count", nothing narrower.
- **Not minimised further.** We did not attempt to reproduce with a hand-written `GpuRays`
  client mimicking the sonar's setup, which would be the next step toward a filing at
  `gz-rendering`.
- The DAVE README describes the OGRE2 problem on this platform as a *load failure*
  (`Failed to load plugin [ogre2]`). What we see is different — `ogre2` loads and executes
  as far as `PreRender` before crashing. These may share a root cause; that is an inference,
  not something we confirmed.

## Environment

- Container image `lyrical-sim:jetty-rdp-theme`
- Ubuntu 26.04 aarch64, ROS 2 Lyrical, Gazebo Jetty 10.4 (`--force-version 10`)
- Rendering: `llvmpipe` software rasteriser, no `/dev/dri` passthrough
- Headless server (`gz sim <world> -s -r`)
- `naitikpahwa18/dave`, branch `wgpu_integration`, pinned commit `6aef91c`

Full write-up and raw logs:
[`notes/results/docker_multibeam_crash_2026-08-03/`](results/docker_multibeam_crash_2026-08-03/)
