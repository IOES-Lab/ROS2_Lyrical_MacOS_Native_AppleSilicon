# Documentation correction draft — the `ogre2` → `ogre` workaround needs an X display

**Status:** Draft, ready to send. Not a bug report — nothing here is broken. The workaround
works; the instructions for it are incomplete in a way that makes it look broken.

**Suggested target:** DAVE's Wiki / installation docs, alongside the existing "OGRE2 is
unavailable on Ubuntu 26.04 aarch64, patch world files `ogre2` → `ogre`" guidance. Also
worth folding into [`wiki-error-report-final-EN.md`](wiki-error-report-final-EN.md) if that
is sent as one document.

**Split from** [`docker-sonar-crash-issue-draft.md`](../upstream/drafts/docker-sonar-crash-issue-draft.md) on
2026-08-07, which had been treating this as a second crash.

---

## What the docs say

When OGRE2 is unavailable — as on Ubuntu 26.04 aarch64 — world files should be patched:

```diff
- <render_engine>ogre2</render_engine>
+ <render_engine>ogre</render_engine>
```

## What is missing

**OGRE1's GL render system requires an X display.** With none, the render engine fails to
load and **no rendering sensor produces data at all** — camera, depth camera, lidar or
sonar. In a plain `docker exec` session there is no display, so the workaround appears not
to work:

```
[error] [OgreRenderEngine.cc:396] Unable to open display:
OGRE EXCEPTION(3:RenderingAPIException): Couldn't open X display
  in GLXGLSupport::getGLDisplay at ./RenderSystems/GL/src/GLX/OgreGLXGLSupport.cpp (line 807)
```

Depending on how it is launched this surfaces either as an `abort` during plugin install
(exit 134) or as a server that stays up while every sensor stays silent — the second being
the more misleading, since the world looks healthy.

## It is not enough to set `DISPLAY`

This is the part that cost us four days. In the dockwater-style images, the X server started
by xrdp belongs to user `docker`, and `/home/docker/.Xauthority` is mode 600. A `docker exec`
session attaches as **root**. So:

| supplied | result |
|---|---|
| nothing | `Couldn't open X display` |
| `DISPLAY=:10` only, as root | `Couldn't open X display` — authorisation refused |
| `-u docker` + `DISPLAY=:10` + `XAUTHORITY=/home/docker/.Xauthority` | **works** |

All three are needed. Our own earlier record concluded the workaround "does not help — it
swaps one crash for another" after supplying only `DISPLAY`, as root.

## Verified

A minimal world with **no DAVE code** — base systems, a ground plane, a box, one
`<sensor type="gpu_lidar">` — in the same container:

| engine | X display | sensor data |
|---|---|---|
| `ogre2` | — | yes, 3/3 |
| `ogre` | none | **no, 3/3** |
| `ogre` | supplied correctly | **yes, 3/3** |

And with the real sonar world, patched to `ogre`, X supplied correctly: no crash across
300 s, sensor initialised (513 beams / 301 rays / 399 time data), `iterations` reached
72,107, `/sensor/multibeam_sonar/point_cloud` publishing.

Data: [`notes/results/gpu_lidar_probe_2026-08-07/`](../results/gpu_lidar_probe_2026-08-07/),
[`notes/results/docker_sonar_x_display_2026-08-07/`](../results/docker_sonar_x_display_2026-08-07/).

## Suggested wording

> **Note:** the `ogre` render engine requires an X display. Running headless — for example
> in a plain `docker exec` session — the render engine will fail to load and no camera,
> depth camera, lidar or sonar will produce data, even though the simulation itself may
> appear to run.
>
> In the RDP-enabled images an X server is already running, but it belongs to the `docker`
> user. All three of the following are required:
>
> ```bash
> docker exec -u docker \
>   -e DISPLAY=:10 \
>   -e XAUTHORITY=/home/docker/.Xauthority \
>   <container> <command>
> ```
>
> Setting `DISPLAY` alone, or running as root, is not sufficient — the connection is refused
> and the error is the same as having no display at all.

Adjust the display number to match the running `Xorg` (`ps -eo user,cmd | grep Xorg`).

## Caveats

- One container image (`lyrical-sim:jetty-rdp-theme`), aarch64, software rendering.
- Not tested with `Xvfb` or a headless-GL setup, either of which would presumably also
  satisfy OGRE1 and might be the better recommendation for CI. Untested.
- **A separate issue remains:** with `DISPLAY` set, the sonar's WGPU backend fails to obtain
  a GPU adapter (tries `vulkan`, then `all`, panics) and falls back to the CPU compute
  backend, where without `DISPLAY` it had reported `selected adapter: llvmpipe`. So the
  sonar output confirmed above came from the CPU path, not WGPU. That is not a
  documentation matter and is not covered by this correction.
