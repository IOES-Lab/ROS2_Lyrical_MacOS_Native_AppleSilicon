# Docker — ROS 2 Lyrical + Gazebo Jetty + DAVE (arm64, RDP desktop)

```text
Status: BASELINE VALIDATED — 2026-07-18 clean (--no-cache) build including a from-source mavros
stage, build time/size recorded, ROS environment/package checks confirmed. Corrected 2026-07-23:
current HEAD's Dockerfile contains later changes not re-verified by a full clean build since —
the 2026-07-22 theme/Firefox/USBL/new_dvl late layers, the 2026-07-23 rosdep --skip-keys mavros
change, and the latest +177/-152 migration patch. World/performance/stability rows below were
re-checked 2026-07-22/23 against the lyrical-theme-test container (same Dockerfile lineage, a
separate running container, not a fresh clean build of current HEAD) — see the main README for
full detail, this file's table is kept in sync with it.
Validated (as of the 2026-07-18 baseline build specifically): Build, headless launch, XFCE/xrdp
login, ROS environment + dave_demos/multibeam_sonar_system/mavros package presence. Validated
separately: **aggregate Mac + Docker matrix, 18/18 worlds PASS-level (13 smoke, 5
functional), 0 PARTIAL as of 2026-08-07** — the 3 manipulation worlds were confirmed on Mac only,
since the headless launch fix has not been applied inside Docker (the last two PARTIAL rows were reclassified when their
stated grounds failed to reproduce; see notes/progress-log.md). USBL was directly revalidated on Mac and Docker on
2026-08-27 and is FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS (see table below). Quantitative RTF benchmark (ocean_waves/usbl_tutorial) re-run
clean 2026-07-27 using the fixed scripts (see table below). 1h clean stability run passed;
a 2026-07-23 4h re-run finished but used a pre-fix script and had a monitoring gap
(PRELIMINARY). A genuinely clean 4h re-run completed 2026-07-29 — current script,
gap-free 2-minute sampling for the full 4h, SURVIVED, RSS 932->1253MiB (12% growth,
heuristic OK) — see main README Next steps.
Known limitation: in the tested image, the installed GNOME 50 session requires Wayland while xorgxrdp produces an X11 session; XFCE is used as the validated RDP desktop. dave_multibeam_sonar still segfaults in Docker as shipped (`ogre2`). Under the documented `ogre` + authorised-X-display configuration it runs and publishes PointCloud2, but WGPU cannot obtain an adapter there and falls back to the CPU backend, so **no valid Docker RTF exists for this world** — the figures once quoted here were withdrawn, see [Superseded figures](#superseded-figures).
```

**Provenance (2026-07-18):** `lyrical.arm64v8.dockerfile` in this folder was clean-built
(`--no-cache`) end to end on 2026-07-18, including the commit SHA pinning, `.bashrc`
source-order fix, the CA-bootstrap fix described under Known limitations, and a from-source
mavros build (`ros-lyrical-mavros` isn't published via apt yet — see the main
[README.md Known issues](../notes/known-issues.md)) — image tag `lyrical-sim:jetty-rdp-pr1-ca-fix`.
Build took **51m 22s**, produced a **21.9GB** image, and an idle running container (no active
RDP session or Gazebo demo) used **62.66MiB** RAM (`docker stats`) — a floor, not a
representative figure under load. **Under an active demo workload** (2026-07-20, same image,
representative smoke test below running headless via `docker exec -d`), `docker stats` held
steady at **~1008MiB (8.44% of the 11.67GiB container memory limit)** and **~1.2–1.5% CPU**
across 5 samples over ~20s once the sonar plugin finished loading — roughly 16× the idle floor,
and consistent with a `ps aux` breakdown inside the container (`gz-sim-main` ~836MB RSS / ~15.7%
of one core, `parameter_bridge` ~90MB). Confirmed in that build/run: all 36 build steps completed,
`ROS_DISTRO=lyrical` and `ros2` resolved inside the container, `ros2 pkg prefix` resolved
`dave_demos` and `multibeam_sonar_system`, and `ros2 pkg list` listed `mavros`, `mavros_extras`,
`mavros_msgs`, `mavros_examples`. This particular build/run round (2026-07-18) is **clean build +
ROS environment/package presence validation** — it did not itself launch the representative demo.
**Corrected 2026-07-23 (was previously stated inconsistently):** the representative-demo /
RAM-CPU-under-load measurement above **was** run against this exact image tag
(`lyrical-sim:jetty-rdp-pr1-ca-fix`), two days later on 2026-07-20 — see the main README's
Progress Log entry for that date, which names the image tag explicitly. The
world/vehicle/performance/stability *rows in the table below*, separately, were validated on
2026-07-22/23 against the same Dockerfile lineage running as the `lyrical-theme-test`
container (a different, later container from the same Dockerfile, not this exact image tag) —
see the table for current status and the main README for full detail. Real
RDP login to an XFCE desktop was validated against the same Dockerfile lineage on 2026-07-17 and
again during the 2026-07-18 `--privileged` test below; it was not re-clicked-through on this
exact rebuild since nothing in the RDP/XFCE stack changed. This replaces an earlier draft (with
separate `entrypoint.sh`/`startwm.sh` files) that was never actually built.

## Naming notice

The lab's advisor has indicated this project will eventually move off the `DAVE` name to
something new — **not yet decided**. Until that's settled:

- External/display names (Docker image tag, container name, hostname, shell prompt) use a
  neutral placeholder, `lyrical-sim`, instead of `DAVE`. This is what was actually used in
  the validated build (`lyrical-sim:jetty-rdp`, container `lyrical-sim`, hostname
  `lyrical-docker`, prompt `docker@lyrical_docker:~$`).
- `DAVE` is still used to refer to the underlying codebase and its existing ROS packages
  (`dave_demos`, `dave_interfaces`, `dave_worlds`, the `dave_ws` workspace path, etc.) —
  those are not renamed here; that's a separate migration once the new project name is final.
- Treat `lyrical-sim` as a placeholder, not a committed project name.

## Files

```text
docker/
├── lyrical.arm64v8.dockerfile   image definition — single self-contained file
└── README.md                    this file
```

No separate `entrypoint.sh`/`startwm.sh`: `startwm.sh` is generated inline (`RUN printf ...`)
directly into `/etc/xrdp/startwm.sh` inside the image, bypassing the default Debian Xsession
lookup chain, and the multi-service startup (dbus, sshd, xrdp-sesman, xrdp) is a single
shell-form `CMD` at the end of the Dockerfile — no separate entrypoint script needed.

## Build

Run from the **repository root**:

```bash
docker build --no-cache -f docker/lyrical.arm64v8.dockerfile -t lyrical-sim:jetty-rdp .
```

`--platform linux/arm64` is implied by the `arm64v8/ubuntu:26.04` base image; this Dockerfile
targets **Apple Silicon / arm64 only** — it has not been adapted or tested for `amd64`.

## Verify the build

The image's final `USER` is `root` (needed for the RDP/xrdp `CMD`), so `bash -lc` does **not**
auto-source `/home/docker/.bashrc` — the ROS/DAVE/mavros environment lines live there, not in
root's shell rc. Source the underlays explicitly instead of relying on login-shell sourcing.
`ros2 --version` is also not a real `ros2` CLI flag; check `$ROS_DISTRO` and `which ros2` instead.

```bash
docker run --rm lyrical-sim:jetty-rdp uname -m               # expect: aarch64
docker run --rm lyrical-sim:jetty-rdp lsb_release -a          # expect: 26.04 Resolute

docker run --rm lyrical-sim:jetty-rdp bash -lc \
  'source /opt/ros/lyrical/setup.bash && echo "$ROS_DISTRO" && which ros2'

docker run --rm lyrical-sim:jetty-rdp bash -lc \
  'source /opt/ros/lyrical/setup.bash && gz sim --versions'

docker run --rm lyrical-sim:jetty-rdp bash -lc \
  'source /opt/ros/lyrical/setup.bash && \
   source /home/docker/dave_ws/install/setup.bash && \
   ros2 pkg list | grep "^dave_"'

docker run --rm lyrical-sim:jetty-rdp bash -lc \
  'source /opt/ros/lyrical/setup.bash && \
   source /home/docker/mavros_ws/install/setup.bash && \
   ros2 pkg list | grep "^mavros"'
```

## Run (RDP desktop)

```bash
docker run -d \
  --name lyrical-sim \
  --hostname lyrical-docker \
  -p 127.0.0.1:3393:3389 \
  lyrical-sim:jetty-rdp
```

(Port left-hand side is arbitrary — pick one that doesn't collide with any container already
using 3389 locally.) `127.0.0.1:` binds the published port to localhost only, matching the
warning below — omitting it would expose RDP on every network interface. Connect with any RDP
client (Microsoft Remote Desktop, etc.) to `localhost:3393`, user `docker`, password `docker` —
**local development default only**; change the password before running this anywhere
network-reachable. A successful login reaches an XFCE desktop with shell prompt
`docker@lyrical_docker:~$`.

**`--privileged` is not required for container startup and XFCE/xrdp login** — tested 2026-07-18
by running the image with no `--privileged` flag and no extra `--cap-add` (`docker run -d --name
priv-test --hostname lyrical-docker -p 127.0.0.1:3396:3389 lyrical-sim:jetty-rdp-pr1-ca-fix`):
RDP login reached a usable XFCE desktop with no capability errors. `xorgxrdp` doesn't need host
GPU device access here (this image uses `llvmpipe` software rendering, no `/dev/dri` passthrough).
Dropped from the example above accordingly. **Scope caveat:** this only re-validates container
startup and RDP/XFCE login without `--privileged` — it has not been re-checked across every
Gazebo world, device-access path, or vehicle/sensor combination, so treat "not required" as
scoped to what was actually re-tested, not as a blanket clearance for every workload in this image.

A representative smoke test (headless, no RDP needed):

```bash
docker exec -it lyrical-sim bash -lc \
  "source /opt/ros/lyrical/setup.bash && source \$DAVE_UNDERLAY/install/setup.bash && \
   ros2 launch dave_demos dave_sensor.launch.py namespace:=blueview_p900 \
   world_name:=dave_multibeam_sonar paused:=false x:=5.8 z:=2 yaw:=3.14 \
   compute_backend:=wgpu gui:=true headless:=true"
```

## Verified / partial / not verified

| | Status |
|---|---|
| Clean (`--no-cache`) Docker build | PASS — as of the 2026-07-18 baseline build; current HEAD has later Dockerfile changes not yet re-verified by a fresh clean build, see Status block above |
| Container startup | PASS |
| xrdp connection, XFCE session (real RDP login, prompt confirmed) | PASS |
| ROS 2 Lyrical / Gazebo Jetty environment | PASS |
| Representative REXROV launch + `ros_gz` bridges | PASS |
| WGPU/Rust sonar packages (`wgpu_vendor`, `multibeam_sonar`, `multibeam_sonar_system`) build | PASS |
| ArduSub SITL build | PASS |
| mavros build (from source; `ros-lyrical-mavros` not yet on apt) | PASS — `mavros`/`mavros_extras`/`mavros_msgs`/`mavros_examples` confirmed via `ros2 pkg list`, MAVLink bridging itself not yet exercised |
| RAM/CPU under an active demo workload | MEASURED — short observation window: ~1008MiB (8.44%) / ~1.2–1.5% CPU, steady over 5 samples across ~20s (2026-07-20); idle floor is 62.66MiB. Not a long-duration measurement — see the separate long-duration stability test row |
| USBL | **FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS (direct Mac+Docker revalidation 2026-08-27).** Common mode returned both tutorial transponder IDs and individual channels returned only the selected ID in both spherical and Cartesian streams. Largest retained positive-sigma static-coordinate axis error: `0.000258 m`. Three independent limitations remain: (1) literal `sigma=0` returns finite data on macOS/libc++ but aborts Docker/libstdc++ on the first ping (exit 134), so the `0.0001` world patch remains required for portability; (2) paused simulations expose endpoints but produce no payload because `spin_some()` is gated on `!paused`; (3) the old Wiki generic sensor launcher also tries to spawn nonexistent `description/usbl/model.sdf`. The verified command is `ros2 launch dave_demos dave_world.launch.py world_name:=usbl_tutorial`. Static routing/geometry only, not general acoustic/travel-time accuracy — see [Known issues](../notes/known-issues.md), [Verified demos](../notes/verified-demos.md), and [direct evidence](../notes/results/usbl_direct_validation_2026-08-27/) |
| 18-world validation matrix | **18/18 PASS-level, 0 PARTIAL** (2026-08-07) — 13 SMOKE PASS (process-level liveness), 5 FUNCTIONAL PASS (real topic/service/sensor data read back). The last two PARTIAL rows were reclassified when their stated grounds stopped reproducing: `dave_multibeam_sonar` → FUNCTIONAL PASS once it ran under the authorised-X-display configuration and published PointCloud2, and `dave_ocean_waves_sonar_integrated` → SMOKE PASS once its RTF and CPU-climb grounds were both refuted. The `dave_world.launch.py` headless gap that blocked all 3 manipulation worlds is fixed ([`patches/dave_world_launch_headless_fix.diff`](../patches/dave_world_launch_headless_fix.diff)) — **still Mac-only, not applied inside Docker.** See [`notes/verified-demos.md`](../notes/verified-demos.md) and `notes/validation_matrix.csv`. Earlier 16/18 wording in [Superseded figures](#superseded-figures) |
| Worlds previously documented as `sonar-demo`-branch-only | The separate-branch requirement was investigated and found incorrect for this checkout (2026-07-22) — both worlds only need `multibeam_sonar_system`, already present. **Both are now PASS-level:** `dave_ocean_waves_sonar` SMOKE PASS, `dave_ocean_waves_sonar_integrated` SMOKE PASS (reclassified 2026-08-07). Neither has had its sonar output topics echoed — only `/world/.../stats` — which is why both are SMOKE rather than FUNCTIONAL. See [`notes/verified-demos.md`](../notes/verified-demos.md) |
| Vehicle/sensor coverage (not every Cartesian combination) | REXROV and Slocum Glider are **FUNCTIONAL**; BlueROV2 and BlueROV2 Heavy are **PARTIAL (4/5)** because their configs bridge a magnetometer the models do not declare. DVL/camera/ocean-current are FUNCTIONAL; SeaPressure publishes but remains numerical PARTIAL; USBL is **FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS** in static tutorial routing/geometry. ArduSub SITL build/launch is a separate result — see main README [Verified demos](../notes/verified-demos.md). |
| Quantitative performance benchmark | **PASS** for `dave_ocean_waves`/`usbl_tutorial`, clean rerun 2026-07-27: `dave_ocean_waves` RTF 0.170 (Docker) / 0.376 (Mac); `usbl_tutorial` RTF 0.687 (Docker) / 0.646 (Mac). Reported as separate environments per world, not a single "N× faster" claim. **No valid Docker RTF exists for `dave_multibeam_sonar`** — the figures previously quoted here were withdrawn (see [Superseded figures](#superseded-figures)), and the world has not been re-measured under the X-display configuration that makes it run. Mac figures for that world are in [`notes/sonar-performance.md`](../notes/sonar-performance.md). See [`notes/next-steps.md`](../notes/next-steps.md) and `notes/bench_results/` |
| Long-duration stability | **PASS** (2026-07-29) — a genuinely clean 4-hour run completed: 120 samples at an unbroken 2-minute cadence from elapsed=2min to elapsed=240min with no gaps, `Outcome: SURVIVED full planned duration`, RSS 932 → 1253 MiB (+12%, memory-growth heuristic OK). This is the first 4h run that is simultaneously current-script, uncontaminated and gap-free — it closes the item that had been open since 2026-07-27. Raw data committed at [`notes/stability/4h_clean_2026-07-29/`](../notes/stability/4h_clean_2026-07-29/) and re-verified on the committed copy. Earlier attempts in [Superseded figures](#superseded-figures) |

## Known limitations

- **`arm64v8/ubuntu:26.04` (this tested minimal image) ships without `ca-certificates`**, so
  any HTTPS apt source failed before the first package installed, and the default `http://`
  mirror also failed (connection timeout). Confirmed Docker's own network/HTTPS path was fine
  (`docker run --rm curlimages/curl:latest -I
  https://ports.ubuntu.com/ubuntu-ports/dists/resolute/InRelease` → `200 OK`), which isolated
  the cause to the missing CA bundle in the base image rather than a network/proxy problem.
  Fixed by copying the CA bundle from a digest-pinned `curlimages/curl` image into
  `/etc/ssl/certs/` before any HTTPS apt operation (the exact path was confirmed against that
  digest, not assumed — the Dockerfile also asserts the copied file is non-empty and fails the
  build immediately if that ever stops being true), forcing any `http://ports.ubuntu.com` apt
  source to `https://`, and adding `ca-certificates` plus an explicit
  `Acquire::https::CaInfo=/etc/ssl/certs/ca-certificates.crt` to **both** the first
  `apt-get update` and the first `apt-get install` — setting it on `update` alone let the index
  download succeed but the following `install` still failed with an SSL error. A clean
  (`--no-cache`) build with this fix in place completed successfully on 2026-07-17, followed by
  a real RDP login. This is scoped to this tested minimal image, not a claim that every Ubuntu
  26.04 base image lacks CA certificates.
- **Ubuntu 26.04 GNOME 50 is Wayland-only** in the tested image; `xorgxrdp` is X11-only, so
  it can't start a GNOME session here. XFCE still ships a full X11 session, so that's what
  this image's RDP desktop uses. This is an observation about *this tested image*, not a
  universal claim that GNOME remote desktop is impossible on every Ubuntu 26.04 configuration.
- **Docker's `llvmpipe` is CPU software rendering, not hardware GPU acceleration.** The Mac
  Metal comparison elsewhere in this repo is a real Apple M2 hardware GPU backend — the two
  numbers are environment-specific observations, not a controlled benchmark (OS, native vs.
  container, and GPU vs. CPU renderer all differ at once).
- **`CMD` is currently shell-form**, which produces a `JSONArgsRecommended` warning during
  build (not a failure). Switching to an `entrypoint.sh` + JSON/exec-form `CMD` is possible
  but wasn't done since it risks changing how the multi-service startup (dbus, sshd,
  xrdp-sesman, xrdp) currently works — tracked as a follow-up, not fixed blindly.
- **`ShaderParam` SDF warning** (`ShaderParam plugin element not defined in SDF` /
  `Copying plugin as children of sdf`) seen during REXROV spawn; robot spawn and `ros_gz`
  bridge creation completed successfully afterward, so this is a non-fatal known warning,
  not an error.
- **A "Stack trace (most recent call last) in thread N:" line appears in `gazebo-1`'s log**
  right after the multibeam sonar plugin finishes loading (seen 2026-07-20, during the
  RAM/CPU-under-load measurement above). This did **not** crash the process: `ps aux` inside
  the container showed `gz-sim-main` still alive and actively consuming CPU (~15.7% of one
  core) more than 7 minutes after the trace appeared, and the `docker stats` RAM reading was
  stable across all 5 samples. Also present in the same log: `error: XDG_RUNTIME_DIR is
  invalid or not set in the environment` — non-fatal, the WGPU sonar backend still selected
  `llvmpipe` and compiled its pipelines successfully afterward. Root cause of the stack trace
  itself not yet investigated; flagged here as a known non-fatal log artifact, not confirmed
  benign for every world/workload.
- **Rebuilding any workspace (`dave_ws`, `mavros_ws`, the ArduSub SITL build) as the runtime
  `docker` user fails** (found 2026-07-20, while launching demos over RDP). All workspaces are
  compiled once, as `root`, during the image build itself — the `docker` user never needs to run
  `colcon build` at all; sourcing the already-built `install/setup.bash` and launching directly
  is sufficient (and is what every command in this file does). If a rebuild is attempted anyway
  as `docker`, three separate issues surface in sequence: (1) `cargo` (needed by `wgpu_vendor`)
  only exists under `/root/.rustup/...`, which the `docker` user can't read — fix by installing
  rustup separately for `docker` (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
  sh -s -- -y`); (2) the existing workspace directories under `/home/docker` are `root`-owned
  from the image build, so `colcon build` fails with `Permission denied` — fix with `sudo chown
  -R docker:docker /home/docker`; (3) `ardupilot_sitl`'s `waf` still fails with
  `ModuleNotFoundError: No module named 'imp'` even after both of the above, the same Python
  3.14/`imp` incompatibility already tracked in the main
  [README.md Known issues](../notes/known-issues.md) — the shim applied during the image build
  isn't present/effective in this interactive `docker`-user shell. Net effect: don't rebuild as
  `docker` unless you're intentionally testing uncommitted source changes; for running the
  existing demos, skip `colcon build` entirely.


---

## Superseded figures

**Nothing in this section describes the current state.** It is kept so that the record shows when
a number changed and why. Do not quote from it.

**Withdrawn:** the Docker RTF `~0.0018` / `~0.0008-0.0077` figures for `dave_multibeam_sonar`.
They were sampled from `/world/oceans_waves/stats`, which is **not that world** —
`dave_multibeam_sonar.world` declares `<world name="default">` — while a `dave_ocean_waves`
stability run was executing in the same container. Withdrawn 2026-08-03, together with the
"Docker is ~123x worse than Mac" comparison built on them.

**Superseded:** `RTF ~0.03` for `dave_ocean_waves_sonar_integrated` (a 20 s spot sample; Mac
measurements under the corrected method give 0.2241 / 0.2197). The Mac `4.5x` sonar cost
(now 1.90x — the earlier figure came from an unoptimised build with a settle criterion that was
timing the startup window). The `32%→47%→69%` CPU climb (not reproduced in two isolated runs).

**Superseded wording:** this page's table previously read `16/18 PASS-level, 2/18 PARTIAL`, and
its stability row read `PARTIAL ... a proper rerun is still needed`. Both were true when written
and are not now — see the rows above.

Full accounting: [`notes/what-we-got-wrong.md`](../notes/what-we-got-wrong.md).
