# The Docker sonar world does run — it needed an X display (2026-08-07)

**This supersedes the conclusion of
[`../docker_multibeam_crash_2026-08-03/`](../docker_multibeam_crash_2026-08-03/), which
recorded that `dave_multibeam_sonar` "does not start on either render engine" in Docker.**

That was true of the environment it was tested in, not of the world. With the documented
`ogre2` → `ogre` patch **and a real X display**, the world starts, the sonar sensor
initialises, the simulation steps, and `/sensor/multibeam_sonar/point_cloud` publishes.

## Result

`lyrical-theme-test`, the same container as 2026-08-03. Run as user `docker` with
`DISPLAY=:10` and `XAUTHORITY=/home/docker/.Xauthority` against the container's live xrdp
Xorg server.

```
SONAR PLUGIN LOADED
# of Beams = 513
# of Rays / Beam (Elevation, Azimuth) = (301, 1)
# of Time data / Beam = 399
```

| check | result |
|---|---|
| process survived 300 s | **yes**, exit 124 (killed by timeout) |
| crash signature | **none** — no segfault, no abort, no `terminate called` |
| sonar sensor created | **yes** (513 × 301, as configured) |
| `/sensor/multibeam_sonar/point_cloud` | **publishes** |
| `/world/default/stats` | `iterations: 72107` — stepping |
| `/sensor/depth_camera/points` | publishes |

Against 2026-08-03, where `ogre` aborted in `RenderSystem_GL`'s `dllStartPlugin` (exit 134)
**without ever reaching the sensor**.

## Why the earlier attempt failed

The 2026-08-03 run set `DISPLAY=:10` but not `XAUTHORITY`, and ran as **root** via
`docker exec`. The Xorg server belongs to user `docker`, and `/home/docker/.Xauthority` is
mode 600. So the connection was refused and OGRE1 reported:

```
[error] [OgreRenderEngine.cc:396] Unable to open display:
OGRE EXCEPTION(3:RenderingAPIException): Couldn't open X display
  in GLXGLSupport::getGLDisplay at ./RenderSystems/GL/src/GLX/OgreGLXGLSupport.cpp (line 807)
```

That draft flagged its own `DISPLAY=:10` attempt as "weak evidence, not a clean refutation"
because `XAUTHORITY` was untested. **That caveat was correct, and it was the whole answer.**

The requirement was isolated first with a stock `gpu_lidar` carrying no DAVE code
([`../gpu_lidar_probe_2026-08-07/`](../gpu_lidar_probe_2026-08-07/)): headless it produced
no data on `ogre`, and with the X display set correctly it produced data 3/3.

## What still fails, and what it means

**`ogre2` still segfaults.** That half is unchanged and remains DAVE-specific — a stock
`gpu_lidar` at the same 513 × 301 ray count works on `ogre2` in this container.

**WGPU cannot get a GPU adapter under this configuration.** The Rust backend tries `vulkan`
then `all`, panics, and falls back to CPU:

```
[sonar_wgpu] [all] GPU init panicked; trying next backend set
[sonar_wgpu] GPU init failed for all backend sets; falling back to CPU path
[sonar_wgpu] GPU unavailable on first compute -> creating CPU fallback backend
[sonar_compute_factory] Creating CPU backend
```

Note this differs from earlier Docker runs, which reported
`[sonar_wgpu] [all] selected adapter: llvmpipe`. With `DISPLAY` set the adapter search takes
a different path and fails. Also present: `libEGL warning: Ensure your X server supports
DRI3 to get accelerated rendering`. **So the sonar output above is from the CPU compute
backend, not WGPU** — which is a working configuration, but not the one the PR is about.

## What this changes

- **`dave_multibeam_sonar` is not unrunnable in Docker.** It needs `ogre` plus a properly
  authorised X display. The matrix's remaining PARTIAL was justified by "the world does not
  start in Docker"; that reason no longer holds.
- **The `ogre2` → `ogre` workaround is valid but conditional.** It requires an X display —
  which the repo's documentation does not say, and which is easy to miss in a container
  where an Xorg server exists but belongs to another user.
- **The Docker crash draft shrinks.** Only the `ogre2` segfault remains reportable to DAVE.

## Caveats

- **n = 1.** One run reached PointCloud2; earlier runs the same day reached sensor
  initialisation without crashing, so the no-crash result has three observations behind it,
  but the published-data result has one.
- **Message content was not inspected** — only that a message arrives.
- **No performance figure.** RTF was not measured under this configuration, and with a CPU
  compute backend it should not be compared to any Mac number.
- `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` was set, which the 2026-08-03 run did not have. It was
  included to rule out the separate spawn hang; it is not believed to affect the render
  engine, but the two runs differ in that respect.
- **The container's world file is left patched to `ogre`** (`.bak` alongside it). That is a
  container-local change, not in the repo.
- One container, aarch64, software rendering.

## Reproduce

```bash
docker exec lyrical-theme-test bash -lc '
  W=/home/docker/dave_ws/install/share/dave_worlds/worlds/dave_multibeam_sonar.world
  cp -n "$W" "$W.bak"
  sed -i "s|<render_engine>ogre2</render_engine>|<render_engine>ogre</render_engine>|;
          s|<engine>ogre2</engine>|<engine>ogre</engine>|" "$W"'

docker exec -u docker \
  -e DISPLAY=:10 -e XAUTHORITY=/home/docker/.Xauthority \
  -e FASTDDS_BUILTIN_TRANSPORTS=UDPv4 lyrical-theme-test bash -lc '
    source /opt/ros/lyrical/setup.bash
    source /home/docker/dave_ws/install/setup.bash
    ros2 launch dave_demos dave_sensor.launch.py \
      namespace:=blueview_p900 world_name:=dave_multibeam_sonar paused:=false \
      x:=5.8 z:=2 yaw:=3.14 compute_backend:=wgpu gui:=true headless:=true &
    sleep 240
    gz topic -e -t /sensor/multibeam_sonar/point_cloud -n 1'
```

`-u docker` and both X variables are all required. As root it fails; with `DISPLAY` alone it
fails.
