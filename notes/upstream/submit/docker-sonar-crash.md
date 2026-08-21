<!-- 제출 대상: [`IOES-Lab/dave`](https://github.com/IOES-Lab/dave). The crash occurs inside `libgz-rendering-ogre2`, but a stock `gpu_lidar` at the same ray count does
     라벨:     `bug`, `crash`
     원본:     notes/upstream/drafts/docker-sonar-crash-issue-draft.md
     자동 생성: notes/upstream/make_submittable.py — 직접 고치지 말 것 -->

## 이슈 제목 (아래 한 줄을 제목 칸에 붙여넣기)

`dave_multibeam_sonar` segfaults in `Ogre2GpuRays::CreateSampleTexture()` on Ubuntu 26.04 aarch64, where a stock `gpu_lidar` at the same 513 × 301 ray count runs fine

---

## 이슈 본문 (이 줄 아래 전체를 본문 칸에 붙여넣기)

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

A minimal world with **no DAVE code** — base systems, a ground plane, a target box, and one
`<sensor type="gpu_lidar">` — was run in the same container on `ogre2`, first at the sonar's
ray count and then with **every ray-geometry parameter matched to the sonar's**:

| probe configuration | result |
|---|---|
| 513 × 301, arbitrary angles (±1.047 H, ±0.262 V) | initialises and publishes, 3/3 |
| 128 × 64 and 16 × 1 | initialises and publishes, 3/3 |
| **513 × 301, sonar's exact angles (±1.13447 H, ±0.10472 V), range 0.1–10.0** | **initialises and publishes** |
| macOS Metal, same sweep (control) | initialises and publishes, 3/3 |

So with ray count, horizontal FOV, vertical FOV and range all identical to the sonar's, a
stock GpuRays sensor runs in the same container where the sonar segfaults. The crash is not
explained by ray count, by the 130° horizontal FOV, or by the narrow 12° vertical FOV.

**What remains different, and untested.** The comparison is now tight on ray geometry but
not on everything:

- **Construction path.** The stock sensor is built by `gz-sensors` from
  `<sensor type="gpu_lidar">`; the sonar is `<sensor type="custom" gz:type="multibeam_sonar">`
  and calls `Scene()->CreateGpuRays()` itself, then `SetClamp(false)`,
  `SetNearClipPlane`/`SetFarClipPlane`, and forces both ray counts odd (512 → 513,
  300 → 301). Both end in `Ogre2GpuRays`, but not by the same route or necessarily at the
  same point in the render lifecycle.
- **Other rendering sensors in the same model.** `blueview_p900` also carries a camera and a
  depth camera; the probe has only the lidar. We did not test a probe with several rendering
  sensors present.
- **Scene content.** The sonar world contains a tank model and target cylinders; the probe
  has a ground plane and one box.

**So this narrows the suspect to the sonar's construction path or to multi-sensor
interaction — it does not identify the call.** The next step toward a `gz-rendering` filing
would be a hand-written `GpuRays` client mimicking the sonar's setup, which we have not
written.

Probe world and script: [`notes/experiments/gpu_lidar_probe.world`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/blob/main/notes/experiments/gpu_lidar_probe.world),
[`notes/experiments/exp13_gpu_lidar.sh`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/blob/main/notes/experiments/exp13_gpu_lidar.sh).
Data: [`notes/results/gpu_lidar_probe_2026-08-07/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/gpu_lidar_probe_2026-08-07/).

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
[`ogre-x-display-doc-correction.md`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/blob/main/notes/wiki/ogre-x-display-doc-correction.md).

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
[`notes/results/docker_multibeam_crash_2026-08-03/`](https://github.com/IOES-Lab/ROS2_Lyrical_MacOS_Native_AppleSilicon/tree/main/notes/results/docker_multibeam_crash_2026-08-03/)
