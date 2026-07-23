# Docker — ROS 2 Lyrical + Gazebo Jetty + DAVE (arm64, RDP desktop)

```text
Status: VALIDATED (2026-07-18 build) — clean (--no-cache) build including a from-source mavros stage,
build time/size recorded, ROS environment/package checks confirmed. World/performance/stability rows
below were re-checked 2026-07-22/23 against the lyrical-theme-test container (same Dockerfile
lineage) — see the main README for full detail, this file's table is kept in sync with it.
Validated: Build, headless launch, XFCE/xrdp login, ROS environment + dave_demos/multibeam_sonar_system/mavros
package presence, 12/18 worlds PASS-level (9 smoke, 3 functional), 3 PARTIAL (see table below), USBL
world-file workaround (downgraded to PARTIAL 2026-07-23, see table below), quantitative RTF benchmark
(ocean_waves/usbl_tutorial), 1h clean stability run
Known limitation: in the tested image, the installed GNOME 50 session requires Wayland while xorgxrdp produces an X11 session; XFCE is used as the validated RDP desktop. dave_multibeam_sonar has a known simulation-progress instability — see table below and main README Known issues.
```

**Provenance (2026-07-18):** `lyrical.arm64v8.dockerfile` in this folder was clean-built
(`--no-cache`) end to end on 2026-07-18, including the commit SHA pinning, `.bashrc`
source-order fix, the CA-bootstrap fix described under Known limitations, and a from-source
mavros build (`ros-lyrical-mavros` isn't published via apt yet — see the main
[README.md Known issues](../README.md#known-issues)) — image tag `lyrical-sim:jetty-rdp-pr1-ca-fix`.
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
| Clean (`--no-cache`) Docker build | PASS |
| Container startup | PASS |
| xrdp connection, XFCE session (real RDP login, prompt confirmed) | PASS |
| ROS 2 Lyrical / Gazebo Jetty environment | PASS |
| Representative REXROV launch + `ros_gz` bridges | PASS |
| WGPU/Rust sonar packages (`wgpu_vendor`, `multibeam_sonar`, `multibeam_sonar_system`) build | PASS |
| ArduSub SITL build | PASS |
| mavros build (from source; `ros-lyrical-mavros` not yet on apt) | PASS — `mavros`/`mavros_extras`/`mavros_msgs`/`mavros_examples` confirmed via `ros2 pkg list`, MAVLink bridging itself not yet exercised |
| RAM/CPU under an active demo workload | MEASURED — short observation window: ~1008MiB (8.44%) / ~1.2–1.5% CPU, steady over 5 samples across ~20s (2026-07-20); idle floor is 62.66MiB. Not a long-duration measurement — see the separate long-duration stability test row |
| USBL | PARTIAL (combined evidence, world-file workaround, downgraded from FUNCTIONAL PASS 2026-07-23) — root cause was the Gazebo **server** aborting on an unvalidated `sigma=0.0`, not a GUI crash as first thought; fixed via a world-file patch (`sigma` → `0.0001`), baked into this Dockerfile. This is a workaround, not a plugin-level fix. "Combined evidence" means the pre-fix run confirmed real topic data while the post-fix run separately confirmed no abort — **no single run has confirmed both at once**, which is why this is reported as PARTIAL rather than FUNCTIONAL PASS — see main [README.md Known issues](../README.md#known-issues) and [Verified demos](../README.md#verified-demos) |
| 18-world validation matrix | 12/18 PASS-level (9 SMOKE PASS, 3 FUNCTIONAL PASS), 3/18 PARTIAL (`dave_multibeam_sonar` and `dave_ocean_waves_sonar_integrated` — both show confirmed simulation-progress problems of different severity; `usbl_tutorial` — downgraded 2026-07-23, see row above), 3/18 NOT AUTOMATED (manipulation worlds — `dave_world.launch.py` has no headless mode) (2026-07-22/23) — see main [README.md](../README.md#progress-log) and `notes/validation_matrix.csv` |
| Worlds previously documented as `sonar-demo`-branch-only | The separate-branch requirement was investigated and found incorrect for this checkout (2026-07-22) — both worlds only need `multibeam_sonar_system`, already present. Status differs between the two: `dave_ocean_waves_sonar` is SMOKE PASS; `dave_ocean_waves_sonar_integrated` is PARTIAL (confirmed simulation slowdown, RTF ~0.03) — see main [README.md Verified demos](../README.md#verified-demos) |
| All vehicle/sensor/GUI-headless combinations | PARTIAL — REXROV + DVL/camera/ocean-current/pressure confirmed with real topic data; USBL confirmed real topic data and the post-fix no-crash state, but not in the same run (see USBL row above); BlueROV2/BlueROV2 Heavy/Slocum Glider have not yet been used as the smoke-test vehicle for any world (ArduSub SITL build/launch success is a separate, already-confirmed thing — see main README [Verified demos](../README.md#verified-demos)) |
| Quantitative performance benchmark | PASS for `dave_ocean_waves`/`usbl_tutorial`, PARTIAL for `dave_multibeam_sonar` (2026-07-23, same RTF sampling methodology and parameters on Mac and Docker, run via two platform-specific scripts — `benchmark_worlds.sh` on Docker, `benchmark_worlds_mac.sh` on Mac): `dave_ocean_waves` RTF 0.277 (Docker) / 0.423 (Mac); `usbl_tutorial` RTF 1.000 (Docker) / 0.998 (Mac). `dave_multibeam_sonar` **excluded from the comparison** — confirmed unreliable on both platforms (crawls at RTF ~0.012-0.015, or shows a simulation-progress stall with platform-specific symptoms: Mac high-CPU/livelock-like, Docker near-idle/possible deadlock — mechanism not confirmed, no thread dump/lock analysis done), not a valid benchmark number. See main [README.md](../README.md#progress-log) and `notes/bench_results/`. Reported as separate environments per-world, not a single "N× faster" claim |
| Long-duration stability | PARTIAL (2026-07-23) — the original 4h run crashed at ~4.4h; traced to leftover test-script processes starving the container (not a DAVE/Gazebo-Jetty bug), fixed in all 4 test scripts, and a clean 1h re-run **survived the full duration**. A full clean 4h re-run started 2026-07-23 (in progress) — see main [README.md](../README.md#progress-log) for live status and raw result files |

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
  [README.md Known issues](../README.md#known-issues) — the shim applied during the image build
  isn't present/effective in this interactive `docker`-user shell. Net effect: don't rebuild as
  `docker` unless you're intentionally testing uncommitted source changes; for running the
  existing demos, skip `colcon build` entirely.
