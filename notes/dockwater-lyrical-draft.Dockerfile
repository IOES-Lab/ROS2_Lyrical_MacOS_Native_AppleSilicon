# UNTESTED DRAFT — dockwater-style base image for ROS 2 Lyrical + Gazebo Jetty
#
# Purpose: a starting point for adding a `lyrical/` folder to a fork of
# https://github.com/IOES-Lab/dockwater (which currently only goes up to
# `jazzy/` — confirmed 2026-07-20, no `lyrical/` folder exists upstream).
# This is modeled on dockwater's own jazzy/Dockerfile
# (https://github.com/IOES-Lab/dockwater/blob/main/jazzy/Dockerfile), NOT a
# copy of our full docker/lyrical.arm64v8.dockerfile — dockwater's Dockerfiles
# are meant to be a thin, generic ROS+Gazebo dev base; things like RDP/xrdp,
# the DAVE workspace, the mavros-from-source build, and ArduSub SITL are
# app-specific and stay in our own docker/lyrical.arm64v8.dockerfile, or would
# need to be added via rocker's runtime extensions instead of baked into the
# image (dockwater's pattern uses rocker's `-r`/`--x11`/`--home` etc. at
# `docker run` time, not a baked-in xrdp CMD like ours).
#
# Key differences from dockwater/jazzy/Dockerfile, and why (all already
# solved once in docker/lyrical.arm64v8.dockerfile — see that file for the
# verified detail on each):
#
#   1. Base image: jazzy's Dockerfile starts `FROM osrf/ros:jazzy-desktop-full`
#      (an OSRF-published image with ROS+desktop preinstalled). As of
#      2026-07-20 there is no `osrf/ros:lyrical-desktop-full` published yet
#      (Lyrical is brand new) — confirm this before relying on the fallback
#      below. Falls back to `arm64v8/ubuntu:26.04` + manual ROS apt install,
#      same as our validated Dockerfile.
#   2. `arm64v8/ubuntu:26.04` ships without `ca-certificates`, breaking HTTPS
#      apt before anything installs. Needs the same CA-bootstrap fix as
#      docker/lyrical.arm64v8.dockerfile (copy a CA bundle from a
#      digest-pinned curlimages/curl image before the first apt-get update).
#      NOT NEEDED if a `lyrical-desktop-full` base image turns up later.
#   3. Gazebo: jazzy's Dockerfile adds OSRF's own Gazebo apt repo and installs
#      `gz-harmonic` as a standalone package. For Lyrical, `ros-lyrical-ros-gz`
#      already vendors Gazebo Jetty (confirmed working, see docker/README.md)
#      — UNCONFIRMED whether a standalone `gz-jetty` apt package exists
#      separately; if it does, prefer it to match jazzy's pattern more
#      closely, otherwise keep relying on ros-lyrical-ros-gz.
#   4. `ros-${ROSDIST}-mavros-msgs` — CONFIRMED available on apt for lyrical
#      (2026-07-20 build), even though the full `ros-lyrical-mavros` (with
#      compiled nodes) is NOT (verified gap, see main README.md Known issues).
#      Kept in the package list below.
#
# STATUS: VALIDATED 2026-07-20 — `docker build -f notes/dockwater-lyrical-draft.Dockerfile
# -t dockwater-lyrical-test .` completed 18/18 steps successfully (arm64, Mac
# Apple Silicon, Docker Desktop). Fixed 3 real issues to get there, in order:
# (a) Acquire::https::CaInfo needed on EVERY apt call, not just `update` —
# setting it once wasn't enough; (b) the dev-tools block (has `curl`) has to
# run BEFORE the ROS apt-source block that shells out to `curl` — the first
# ordering hit `curl: not found`; (c) `ros-lyrical-navigation2`,
# `ros-lyrical-nav2-bringup`, `ros-lyrical-plotjuggler-ros` don't exist on
# apt yet for lyrical (confirmed via real `Unable to locate package` errors),
# removed from the package list. Confirmed `ros-lyrical-mavros-msgs` IS on
# apt (unlike the full `ros-lyrical-mavros`).
#
# NOT yet done: this only proves the raw `docker build` succeeds standalone —
# it is not wired into an actual dockwater fork as a `lyrical/` folder, and
# hasn't been run through dockwater's build.bash/run.bash + rocker extensions
# (RDP, X11, GPU passthrough). That's the remaining step before this could be
# a real dockwater contribution.

FROM curlimages/curl@sha256:7c12af72ceb38b7432ab85e1a265cff6ae58e06f95539d539b654f2cfa64bb13 AS ca-source

FROM arm64v8/ubuntu:26.04
# ^ Swap for osrf/ros:lyrical-desktop-full if/when OSRF publishes one —
#   check https://hub.docker.com/r/osrf/ros/tags first, that would let you
#   drop the CA-bootstrap step and the manual ROS apt install below entirely,
#   matching jazzy's Dockerfile shape exactly.

ARG ROSDIST=lyrical

ENV TZ=Etc/UTC
RUN echo $TZ > /etc/timezone && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime

# --- CA-certificate bootstrap ---------------------------------------------
# arm64v8/ubuntu:26.04 ships without ca-certificates, so the first HTTPS apt
# source fails before anything else can install. Verbatim from
# docker/lyrical.arm64v8.dockerfile (validated 2026-07-17/18) — needs a
# `FROM curlimages/curl@sha256:7c12af72ceb38b7432ab85e1a265cff6ae58e06f95539d539b654f2cfa64bb13 AS ca-source`
# stage added above the `FROM arm64v8/ubuntu:26.04` line at the top of this file.
RUN mkdir -p /etc/ssl/certs
COPY --from=ca-source /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN test -s /etc/ssl/certs/ca-certificates.crt || \
    (echo "FATAL: /etc/ssl/certs/ca-certificates.crt missing or empty after COPY from ca-source \
- the assumed Alpine CA bundle path was wrong for this curlimages/curl digest. Inspect the \
image manually and fix the COPY --from path above." >&2; exit 1)
RUN grep -rl 'http://ports.ubuntu.com' /etc/apt/ 2>/dev/null | xargs -r sed -i 's|http://ports.ubuntu.com|https://ports.ubuntu.com|g'

# Every apt-get/apt call below (update AND install/full-upgrade/autoremove)
# carries -o Acquire::https::CaInfo=... explicitly. Setting it on `update`
# alone was the exact mistake that broke the real Dockerfile the first time
# (see docker/README.md Known limitations: index download succeeds, the
# following install still fails with an SSL error) — do not drop it from
# any single apt invocation below, including ones that look download-free.
ENV ROS_DISTRO=${ROSDIST}
ENV CA_OPT="-o Acquire::https::CaInfo=/etc/ssl/certs/ca-certificates.crt"
RUN apt update -o APT::Update::Error-Mode=any $CA_OPT && \
    apt full-upgrade -y $CA_OPT && apt autoremove -y $CA_OPT

# Tools necessary and useful during development (same list as dockwater/jazzy).
# Ordered BEFORE the ROS apt-source setup below on purpose: that step needs
# `curl`, which isn't present in this minimal base image until this block
# installs it (found the hard way — the first draft had these reversed and
# hit `curl: not found`).
RUN apt update $CA_OPT && \
    DEBIAN_FRONTEND=noninteractive \
    apt install --no-install-recommends -y $CA_OPT \
    build-essential \
    atop \
    ca-certificates \
    cmake \
    cppcheck \
    curl \
    expect \
    gdb \
    git \
    gnupg2 \
    gnutls-bin \
    iputils-ping \
    libbluetooth-dev \
    libccd-dev \
    libcwiid-dev \
    libeigen3-dev \
    libfcl-dev \
    libgflags-dev \
    libgles2-mesa-dev \
    libgoogle-glog-dev \
    libspnav-dev \
    libusb-dev \
    lsb-release \
    net-tools \
    pkg-config \
    protobuf-compiler \
    python3-dbg \
    python3-empy \
    python3-numpy \
    python3-setuptools \
    python3-pip \
    python3-venv \
    ruby \
    software-properties-common \
    sudo \
    vim \
    wget \
    xvfb \
    && apt clean -qq

RUN apt update $CA_OPT && apt install -y $CA_OPT locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# --- ROS 2 Lyrical apt setup + install --------------------------------------
# Verbatim from docker/lyrical.arm64v8.dockerfile (validated 2026-07-18):
# resolves the latest ros-apt-source release, installs the signing
# key + sources.list.d entry via that .deb, then installs the desktop +
# ros-gz metapackages (which already vendor Gazebo Jetty — no separate
# Gazebo apt repo or source build needed, unlike jazzy's Dockerfile above).
RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" && \
    dpkg -i /tmp/ros2-apt-source.deb && \
    apt update -o APT::Update::Error-Mode=any $CA_OPT && \
    apt install -y --no-install-recommends $CA_OPT \
      ros-${ROS_DISTRO}-desktop ros-${ROS_DISTRO}-ros-gz \
      python3-rosdep python3-vcstool python3-colcon-common-extensions

# --- ROS packages (mirrors jazzy's list) ------------------------------------
# VALIDATED 2026-07-20 by a real `docker build` of this exact file (arm64,
# lyrical apt index as of that date). Confirmed available:
# ackermann-msgs, actuator-msgs, ament-cmake-pycodestyle, image-transport(-plugins),
# joy-teleop, joy-linux, marine-acoustic-msgs, marine-sensor-msgs, mavros-msgs,
# nav2-minimal-tb3-sim, nav2-minimal-tb4-description, nav2-minimal-tb4-sim,
# radar-msgs, vision-msgs, xacro. Notably `ros-lyrical-mavros-msgs` IS on apt
# even though the full `ros-lyrical-mavros` (compiled nodes) is NOT (see main
# README.md Known issues) — msgs-only packages ported ahead of the C++ nodes.
#
# Confirmed NOT YET available for lyrical (removed below, apt error was
# `Unable to locate package`, not a typo — re-check periodically as the
# distro matures):
#   - ros-lyrical-navigation2
#   - ros-lyrical-nav2-bringup
#   - ros-lyrical-plotjuggler-ros
# (the nav2-minimal-tb*-sim demo packages installed fine even without the
# nav2 core packages above — worth double-checking they're not silently
# broken at runtime without navigation2/nav2-bringup present.)
RUN apt update $CA_OPT \
    && apt install -y --no-install-recommends $CA_OPT \
    python3-colcon-common-extensions \
    python3-vcstool \
    ros-${ROSDIST}-ackermann-msgs \
    ros-${ROSDIST}-actuator-msgs \
    ros-${ROSDIST}-ament-cmake-pycodestyle \
    ros-${ROSDIST}-image-transport \
    ros-${ROSDIST}-image-transport-plugins \
    ros-${ROSDIST}-joy-teleop \
    ros-${ROSDIST}-joy-linux \
    ros-${ROSDIST}-marine-acoustic-msgs \
    ros-${ROSDIST}-marine-sensor-msgs \
    ros-${ROSDIST}-mavros-msgs \
    ros-${ROSDIST}-nav2-minimal-tb3-sim \
    ros-${ROSDIST}-nav2-minimal-tb4-description \
    ros-${ROSDIST}-nav2-minimal-tb4-sim \
    ros-${ROSDIST}-radar-msgs \
    ros-${ROSDIST}-vision-msgs \
    ros-${ROSDIST}-xacro \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean -qq

# NOTE: `ros-${ROSDIST}-ros-gz-sim` deliberately omitted above — for Lyrical,
# `ros-lyrical-ros-gz` (the whole meta-package, already validated in
# docker/lyrical.arm64v8.dockerfile) is what actually vendors Gazebo Jetty.
# Confirm during the real build whether a narrower `ros-lyrical-ros-gz-sim`
# package exists on its own before deciding which to use here.
