# A stock `gpu_lidar` separates the two Docker failures (2026-08-07)

> **Follow-up later on 2026-08-07:** the authorised-X path was subsequently tested.
> Running as user `docker` with `DISPLAY=:10` and
> `XAUTHORITY=/home/docker/.Xauthority` made the `ogre` path work, and the real
> DAVE sonar world published PointCloud2. See
> [`../docker_sonar_x_display_2026-08-07/`](../docker_sonar_x_display_2026-08-07/).
> Statements below saying this path was untested describe the earlier probe stage only.

`notes/docker-sonar-crash-issue-draft.md` has carried a "Before filing" block since
2026-08-03 saying a maintainer's first question would be *"does this happen with a stock
GpuRays sensor?"* — and that the report should not be filed until that was answered.

It is answered. The two failure modes have different causes and only one of them is DAVE's.

| render engine | stock `gpu_lidar` | `dave_multibeam_sonar` |
|---|---|---|
| `ogre2` (as shipped) | **works, 3/3 with data** | segfault in `Ogre2GpuRays::CreateSampleTexture()`, exit 139, 2/2 |
| `ogre` (documented workaround) | **no sensor data, `Couldn't open X display`** | abort in `RenderSystem_GL` `dllStartPlugin`, exit 134 |

## The probe

`gpu_lidar_probe.world` contains no DAVE code at all — `gz-sim-physics-system`,
`user-commands`, `scene-broadcaster`, `sensors` with a selectable `<render_engine>`, a
ground plane, a target box, and one `gpu_lidar`. Ray counts are substituted by
`exp13_gpu_lidar.sh`; 513 × 301 matches what the sonar requests.

Run in `lyrical-theme-test` — the same container where the sonar crash was reproduced —
and on the Mac as a control.

| platform | engine | rays | outcome |
|---|---|---|---|
| Mac / Metal | `ogre2` | 154,413 / 8,192 / 16 | `ALIVE_WITH_DATA` (3/3) |
| Docker / llvmpipe | `ogre2` | 154,413 / 8,192 / 16 | `ALIVE_WITH_DATA` (3/3) |
| Docker / llvmpipe | `ogre` | 154,413 / 8,192 / 16 | `ALIVE_NO_DATA` (3/3) |

**Liveness alone would have proved nothing here.** A world whose sensor was never created
also stays alive — that is exactly what happened with the sonar world on 2026-08-06 (model
never spawned, RTF ~1.0, everything looking healthy) and with the vehicle IMUs the same
week (topic present, permanently silent). So the probe checks that `/gpu_lidar` actually
publishes, and the `ogre` rows are recorded as `ALIVE_NO_DATA` rather than as passes.

## Finding 1 — the `ogre2` segfault is sonar-specific, and ray geometry is not the trigger

A stock `gpu_lidar` at **the same 513 × 301 ray count, same container, same render engine,
same software rasteriser** initialises and publishes.

**The first version of this probe was not actually a matched comparison**, which is worth
recording. It matched the sonar's ray *count* but used arbitrary angles — ±1.047 horizontal
and ±0.262 vertical — where the sonar's SDF specifies **±1.13447 (130°) horizontal and
±0.10472 (12°) vertical**, a vertical field of view 2.5× narrower. Since `Ogre2GpuRays`
switches to a cubemap path for wide fields of view, and 130° crosses 120°, the angles were a
plausible trigger and the "same conditions" claim was not yet earned.

Re-run with every ray-geometry parameter matched — 513 × 301, ±1.13447 H, ±0.10472 V,
range 0.1–10.0 — **the stock sensor still initialises and publishes.** So the crash is not
explained by ray count, horizontal FOV, vertical FOV, or range.

**What remains different, and untested:**

- **Construction path.** `gz-sensors` builds the stock sensor from
  `<sensor type="gpu_lidar">`; the sonar is `type="custom"` and calls
  `Scene()->CreateGpuRays()` itself, then `SetClamp(false)`, `SetNearClipPlane`/
  `SetFarClipPlane`, and forces both ray counts odd (512 → 513, 300 → 301). Same destination,
  different route, and possibly a different point in the render lifecycle.
- **Other rendering sensors in the same model.** `blueview_p900` also carries a camera and a
  depth camera; the probe has only the lidar.
- **Scene content.** The sonar world has a tank and target cylinders; the probe has a ground
  plane and a box.

This narrows the suspect to the construction path or to multi-sensor interaction. It does
not identify the call.

## Finding 2 — the `ogre` failure is not DAVE's, and the documented workaround is void

```
[error] [OgreRenderEngine.cc:396] Unable to open display:
OGRE EXCEPTION(3:RenderingAPIException): Couldn't open X display
  in GLXGLSupport::getGLDisplay at ./RenderSystems/GL/src/GLX/OgreGLXGLSupport.cpp (line 807)
```

OGRE1's GL render system requires an X display, and a `docker exec` session has none. This
reproduces with no DAVE code involved, so the sonar's exit-134 abort in `dllStartPlugin` is
the same thing surfacing through a `noexcept` boundary.

**Consequence beyond the sonar.** At the time of this probe, this repository and DAVE's
docs recommended patching world files `ogre2` → `ogre` under the now-withdrawn claim
that OGRE2 was unavailable on Ubuntu 26.04 aarch64. **In a
headless container that workaround cannot work for any world containing a rendering
sensor** — camera, depth camera, lidar or sonar — because the render engine never loads.
It is not specific to the sonar, and it was previously recorded as if it were.

The 2026-08-03 attempt to set `DISPLAY=:10` against the container's xrdp socket was flagged
in the draft as weak evidence because `XAUTHORITY` was not set. That caveat now has an
explanation: the requirement is real. It was untested at this point in the probe, then
confirmed later the same day using a reachable X display with valid authorisation.

## What this unblocks

The Docker crash draft can now be filed. It should be split:

1. **To DAVE** — the `ogre2` segfault, with the stock-`gpu_lidar` control as evidence that
   it is not a generic gz-rendering limit.
2. **Not a bug report at all** — the `ogre` failure is a documentation correction. The
   `ogre2` → `ogre` workaround needs a caveat that it requires an X display and therefore
   does not apply to headless runs with rendering sensors.

## Caveats

- One container (`lyrical-theme-test`), one architecture (aarch64), software rendering only.
- The probe survived a 40 s window; it was not run long enough to rule out a later crash.
- **Superseded later on 2026-08-07:** the `ogre` path was tested with the container's
  authorised xrdp X display and worked.
- The sonar was not re-run during this initial probe, but was re-run later the same day;
  it initialised and published PointCloud2 under the authorised-X configuration.

## Reproduce

```bash
# Mac
bash notes/experiments/exp13_gpu_lidar.sh

# Docker
docker cp notes/experiments/exp13_gpu_lidar.sh   lyrical-theme-test:/tmp/
docker cp notes/experiments/gpu_lidar_probe.world lyrical-theme-test:/tmp/
docker exec lyrical-theme-test bash -lc '
  source /opt/ros/lyrical/setup.bash
  cd /tmp && bash exp13_gpu_lidar.sh'
docker exec lyrical-theme-test bash -lc '
  source /opt/ros/lyrical/setup.bash
  cd /tmp && ENGINE=ogre bash exp13_gpu_lidar.sh'
```

`gz` is not on `PATH` for `docker exec` (which attaches as root with `HOME=/root`);
`/opt/ros/lyrical/setup.bash` must be sourced first.
