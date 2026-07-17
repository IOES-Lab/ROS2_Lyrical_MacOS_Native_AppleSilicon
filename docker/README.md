# Docker — ROS 2 Lyrical + Gazebo Jetty + DAVE (arm64, RDP desktop)

```text
Status: VALIDATED (2026-07-17) — clean (--no-cache) build with CA-bootstrap fix, RDP login, and
ROS environment/package checks confirmed
Validated: Build, headless launch, XFCE/xrdp login, ROS environment + dave_demos/multibeam_sonar_system package presence
Not yet validated: all 18 worlds, quantitative performance, long-duration stability
Known limitation: in the tested image, the installed GNOME 50 session requires Wayland while xorgxrdp produces an X11 session; XFCE is used as the validated RDP desktop
```

**Provenance (2026-07-17):** `lyrical.arm64v8.dockerfile` in this folder was clean-built
(`--no-cache`) end to end on 2026-07-17, including the commit SHA pinning, `.bashrc`
source-order fix, and the CA-bootstrap fix described under Known limitations — image tag
`lyrical-sim:jetty-rdp-pr1-ca-fix`. Confirmed in that build/run: the build completed
(`#37 DONE`, image exported and unpacked), a real RDP login reached an XFCE desktop and stayed
up (no immediate exit), `ROS_DISTRO=lyrical` and `ros2` resolved inside the container, and
`ros2 pkg prefix` resolved both `dave_demos` and `multibeam_sonar_system`. This is **clean
build + XFCE/xrdp login + ROS environment/package presence validation** — it does not re-run
the representative demo launch, and it does not touch the world/vehicle/performance/stability
rows still marked NOT TESTED below. This replaces an earlier draft (with separate
`entrypoint.sh`/`startwm.sh` files) that was never actually built.

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

```bash
docker run --rm lyrical-sim:jetty-rdp uname -m               # expect: aarch64
docker run --rm lyrical-sim:jetty-rdp lsb_release -a          # expect: 26.04 Resolute
docker run --rm lyrical-sim:jetty-rdp bash -lc 'ros2 --version'
docker run --rm lyrical-sim:jetty-rdp bash -lc 'gz sim --versions'
docker run --rm lyrical-sim:jetty-rdp bash -lc 'ros2 pkg list | grep "^dave_"'
```

## Run (RDP desktop)

```bash
docker run -d \
  --name lyrical-sim \
  --hostname lyrical-docker \
  --privileged \
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

`--privileged` is used here for simplicity during validation; it has not yet been narrowed
to the minimal capability set xrdp/Xorg actually need (a follow-up item, not required for
this round's smoke tests).

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
| USBL | PARTIAL — server/plugin loads and publishes; GUI client crashes |
| All 18 worlds executed | NOT TESTED — inventory complete, not all run |
| `sonar-demo`-branch-only worlds | NOT TESTED |
| All vehicle/sensor/GUI-headless combinations | NOT TESTED |
| Quantitative performance benchmark | NOT DONE |
| Long-duration stability | NOT DONE |

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
