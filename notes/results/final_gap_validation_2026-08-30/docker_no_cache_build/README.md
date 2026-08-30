# Current Docker recipe fresh no-cache build and rendered replay

The current `docker/lyrical.arm64v8.dockerfile` at Git
`e05070a28dba5231e1fad03ed3484fa254b2711f` was rebuilt after an official BuildKit
builder-cache prune with Docker `--no-cache`.

## Build result

- **PASS**, return code 0;
- 4015.02 seconds (**66.917 minutes**), 2026-08-30 11:13:38–12:20:34 KST;
- image `lyrical-sim:jetty-rdp-no-cache-20260830`;
- image ID `sha256:53744d17f09dd2489d6be3eedbfae19377b9013211f1cfa3c109c70cfc67d955`;
- 6,260,137,751 bytes, arm64/Linux, Ubuntu 26.04.1 LTS, ROS 2 Lyrical and Gazebo
  Jetty 10.5.0;
- DAVE, multibeam, MAVROS and MAVROS message package prefixes exist;
- all four pinned source revisions and the required ArduSub, Gazebo-plugin and QGC
  artifacts match the recipe.

The only Docker build warning recommends JSON-array form for `CMD`; it did not fail a
layer or the image verification.

## Rendered runtime result

A real RDP protocol login was made with FreeRDP SDL 3.31.0 against the fresh image's xrdp
server. It started Xorg `:10` and XFCE, and the actual 1280×900 framebuffer was captured.
The integrated baseline BlueROV replay then rendered Gazebo and QGroundControl in that
session. MAVROS reported `connected: true`, `mode: MANUAL`; the retained screenshot shows
QGC **Ready / Manual**. QGC used the already documented `QGC_NO_SYSTEM_GLIB=1` opt-out.

This fresh replay uses FreeRDP because the host's Windows App could not be automated
without macOS Accessibility permission. The prior exact cache image has a separate real
Windows App login capture under `../docker_exact_rdp/`; the fresh result must not be
misdescribed as a Windows App run.

## Evidence

- `build.log`, `build_return_code.txt`, `metadata_before.txt`, `metadata_after.txt`;
- `image_metadata.txt`, `image_verification.txt`, `summary.json`;
- `rendered_rdp/no_cache_rdp_root.png` and xrdp/session logs;
- `integrated_qgc/mavros_state_latest.txt`, `integrated_summary.json`,
  `no_cache_qgc_connected.png`, launch and QGC logs.

## Limits

This closes the current-recipe fresh-build and rendered xrdp/Gazebo/QGC replay gaps. It
does not validate physical HIL, NVIDIA/CUDA, hardware Vulkan/WGPU, Windows/WSL, Fuel
upload credentials, or general physical/scientific accuracy.
