# Lyrical/Jetty equivalent of IOES-Lab/dave's .docker/jazzy.arm64v8.dockerfile
# (https://github.com/IOES-Lab/dave/blob/ros2/.docker/jazzy.arm64v8.dockerfile)
#
# Differences from the original:
# - FROM arm64v8/ubuntu:26.04 directly instead of a prebuilt personal base image — the RDP/xrdp
#   setup below is the un-commented, adapted version of what that base image actually contained,
#   plus the group-permission fix we found necessary (see notes/cmake-migration-patterns.md #8).
# - ROS_DISTRO=lyrical, Gazebo Jetty installed straight from apt (ros-lyrical-ros-gz already
#   vendors Jetty — no separate Gazebo source build needed, unlike the Jazzy/Harmonic install script).
# - ArduSub SITL build includes the Python 3.14 compatibility shims from
#   notes/ardusub-sitl-setup.md (imp/pipes modules, python-argparse, PEP 668).
# - CA bootstrap stage added 2026-07-16: `arm64v8/ubuntu:26.04` is a minimal rootfs with no
#   ca-certificates, so any HTTPS apt source failed before the first package installed.
#   Diagnosed with `docker run --rm curlimages/curl:latest -I
#   https://ports.ubuntu.com/ubuntu-ports/dists/resolute/InRelease` -> 200 OK, which confirmed
#   Docker's network/HTTPS path itself was fine and isolated the failure to the missing CA
#   bundle in the Ubuntu base image. See docker/README.md Known limitations for details.

FROM curlimages/curl@sha256:7c12af72ceb38b7432ab85e1a265cff6ae58e06f95539d539b654f2cfa64bb13 AS ca-source

FROM arm64v8/ubuntu:26.04

ARG USER=docker
ARG PASS=docker
ARG X11Forwarding=true

# CA bundle path verified directly for the pinned curlimages/curl digest:
# /etc/ssl/certs/ca-certificates.crt exists, is non-empty, and passed test -s (CA_BUNDLE_OK).
RUN mkdir -p /etc/ssl/certs
COPY --from=ca-source /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
RUN test -s /etc/ssl/certs/ca-certificates.crt || \
    (echo "FATAL: /etc/ssl/certs/ca-certificates.crt missing or empty after COPY from ca-source \
- the assumed Alpine CA bundle path was wrong for this curlimages/curl digest. Inspect the \
image manually (docker run --rm curlimages/curl@sha256:7c12af72ceb38b7432ab85e1a265cff6ae58e06f95539d539b654f2cfa64bb13 \
sh -c 'ls -la /etc/ssl/certs/ /etc/ssl/*.pem 2>/dev/null') and fix the COPY --from path above." >&2; \
     exit 1)

# The base image's default arm64 mirror can be http://ports.ubuntu.com; force https wherever it
# actually appears rather than guessing which apt source file the base image uses (classic
# sources.list vs. the newer deb822 *.sources format).
RUN grep -rl 'http://ports.ubuntu.com' /etc/apt/ 2>/dev/null | xargs -r sed -i 's|http://ports.ubuntu.com|https://ports.ubuntu.com|g'

# --- RDP / XFCE desktop setup ---
# hadolint ignore=DL3008,DL3015,DL3009
RUN DEBIAN_FRONTEND=noninteractive apt-get update -o APT::Update::Error-Mode=any -o Acquire::https::CaInfo=/etc/ssl/certs/ca-certificates.crt && \
    apt-get -o Acquire::https::CaInfo=/etc/ssl/certs/ca-certificates.crt install -y --no-install-recommends \
      dbus dbus-x11 xrdp xorgxrdp \
      xfce4 xfce4-goodies xfce4-terminal xterm \
      sudo openssl ca-certificates && \
    if [ "$X11Forwarding" = 'true' ]; then apt-get install -y openssh-server; fi && \
    apt-get autoremove --purge && \
    apt-get clean && \
    rm -f /run/reboot-required*

RUN useradd -s /bin/bash -m $USER && echo "$USER:$PASS" | chpasswd; \
    usermod -aG sudo $USER; echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers; \
    adduser xrdp ssl-cert; \
    # xrdp daemon needs root-group access to session sockets under /run/xrdp/sockdir/ —
    # without this, RDP connections time out after ~30s ("connection problem, giving up")
    usermod -aG root xrdp; \
    echo 'LANG=en_US.UTF-8' >> /etc/default/locale; \
    echo 'export XDG_CURRENT_DESKTOP=XFCE' > /home/$USER/.xsessionrc; \
    echo 'export XDG_SESSION_DESKTOP=xfce' >> /home/$USER/.xsessionrc; \
    echo 'export DESKTOP_SESSION=xfce' >> /home/$USER/.xsessionrc; \
    echo 'export XDG_SESSION_TYPE=x11' >> /home/$USER/.xsessionrc; \
    sed -i "s/#EnableConsole=false/EnableConsole=true/g" /etc/xrdp/xrdp.ini; \
    sed -i 's/max_bpp=32/max_bpp=16/g' /etc/xrdp/xrdp.ini; \
    [ $X11Forwarding = 'true' ] && \
        sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config || \
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config || \
        :; \
    chown $USER:$USER /home/$USER/.xsessionrc

# Bypass the Debian Xsession wrapper. In a systemd-less container it can exit
# before reaching ~/.xsession. Each RDP login gets its own DBus session.
RUN test -d /etc/xrdp && \
    printf '%s\n' \
      '#!/bin/bash' \
      'exec >>/home/docker/xrdp-startwm.log 2>&1' \
      'export HOME=/home/docker' \
      'export USER=docker' \
      'export LOGNAME=docker' \
      'export XDG_SESSION_TYPE=x11' \
      'export XDG_CURRENT_DESKTOP=XFCE' \
      'export XDG_SESSION_DESKTOP=xfce' \
      'export DESKTOP_SESSION=xfce' \
      'export XDG_RUNTIME_DIR="/run/user/$(id -u)"' \
      'unset GNOME_SHELL_SESSION_MODE SESSION_MANAGER DBUS_SESSION_BUS_ADDRESS' \
      'exec /usr/bin/dbus-run-session -- /usr/bin/startxfce4' \
      > /etc/xrdp/startwm.sh && \
    chmod 0755 /etc/xrdp/startwm.sh

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
# hadolint ignore=DL3008
RUN apt-get update -o APT::Update::Error-Mode=any -o Acquire::https::CaInfo=/etc/ssl/certs/ca-certificates.crt && \
    apt-get install -y --no-install-recommends \
    xterm vim net-tools \
    curl wget git build-essential cmake cppcheck \
    gnupg libeigen3-dev libgles2-mesa-dev \
    lsb-release pkg-config protobuf-compiler \
    python3-pip python3-venv \
    nano xauth htop libtool \
    x11-apps mesa-utils bison flex automake && \
    rm -rf /var/lib/apt/lists/

RUN truncate -s0 /tmp/preseed.cfg && \
    (echo "tzdata tzdata/Areas select Etc" >> /tmp/preseed.cfg) && \
    (echo "tzdata tzdata/Zones/Etc select UTC" >> /tmp/preseed.cfg) && \
    debconf-set-selections /tmp/preseed.cfg && \
    rm -f /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata
RUN apt-get update -o APT::Update::Error-Mode=any && \
    apt-get -y install --no-install-recommends locales tzdata && \
    rm -rf /tmp/*
RUN locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

EXPOSE 3389/tcp
EXPOSE 22/tcp

# --- ROS 2 Lyrical + Gazebo Jetty ---
# Pinned to the exact commit verified in README.md's "Pinned commits" table (not the
# "wgpu_integration" branch tip) so this image is reproducible against the tested code.
ARG DAVE_COMMIT="6aef91c823af5da073329b84ba617b572965e79e"
ARG ROS_DISTRO="lyrical"

RUN apt update -o APT::Update::Error-Mode=any && apt full-upgrade -y && apt autoremove -y

# Gazebo Jetty is vendored by ros-lyrical-ros-gz on apt already — no separate Gazebo source build
RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" && \
    dpkg -i /tmp/ros2-apt-source.deb && \
    apt update -o APT::Update::Error-Mode=any && \
    apt install -y --no-install-recommends \
      ros-${ROS_DISTRO}-desktop ros-${ROS_DISTRO}-ros-gz \
      python3-rosdep python3-vcstool python3-colcon-common-extensions

# --- DAVE workspace (naitikpahwa18/dave, wgpu_integration branch + our migration patch) ---
ENV DAVE_UNDERLAY=/home/$USER/dave_ws
WORKDIR $DAVE_UNDERLAY/src
RUN git clone https://github.com/naitikpahwa18/dave.git dave && \
    cd dave && git checkout --detach "$DAVE_COMMIT"

COPY patches/dave_lyrical_jetty_migration_mac.diff /tmp/dave_lyrical_jetty_migration_mac.diff
RUN cd dave && git apply /tmp/dave_lyrical_jetty_migration_mac.diff

# Tested 2026-07-18 with `|| true` removed from the install step: confirmed it WAS masking a
# real dependency-resolution failure, not just a harmless warning. Failure: `ros-lyrical-mavros`
# is not available via apt for the `lyrical` distro yet (`E: Unable to locate package
# ros-lyrical-mavros` — the package/distro sync for this very new ROS distro hasn't caught up).
# `|| true` is restored below so this DAVE-workspace rosdep pass doesn't hard-fail on that one
# missing key. This does NOT mean mavros is missing from the final image: a separate from-source
# mavros build stage further down this file (search "mavros, built from source") installs it
# independently of this rosdep call, and that stage's success is what actually determines
# whether mavros ends up in the image — see that section for the validated result.
RUN rosdep init || true && rosdep update --rosdistro $ROS_DISTRO && \
    rosdep install --rosdistro $ROS_DISTRO -iy --from-paths . || true

# wgpu_vendor (multibeam sonar's CUDA-free compute backend) is a Rust crate — needs cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR $DAVE_UNDERLAY
RUN . "/opt/ros/${ROS_DISTRO}/setup.sh" && \
    colcon build --merge-install --executor sequential --symlink-install \
      --packages-select dave_interfaces dave_object_models dave_sensor_models dave_robot_models \
      dave_worlds dave_gz_world_plugins dave_gz_model_plugins dave_gz_sensor_plugins \
      dave_ros_gz_plugins dave_demos && \
    colcon build --merge-install --executor sequential --packages-select wgpu_vendor && \
    colcon build --merge-install --executor sequential --packages-select multibeam_sonar multibeam_sonar_system

# --- mavros, built from source (NOT yet available via apt for $ROS_DISTRO — see the comment
# above the rosdep install step earlier in this file: `E: Unable to locate package
# ros-lyrical-mavros`, confirmed 2026-07-18). Follows the official mavros ros2-branch
# source-install procedure:
# https://github.com/mavlink/mavros/blob/ros2/mavros/README.md#source-installation
# VALIDATED 2026-07-18 by a full clean (`--no-cache`) rebuild that completed all 36 build steps
# end to end — see README.md's Progress Log and docker/README.md's Provenance note for the full
# result (build time, image size, and `ros2 pkg list` confirming `mavros`/`mavros_extras`/
# `mavros_msgs`/`mavros_examples` are present in the built image).
#
# Two real build issues were hit and fixed along the way during that same 2026-07-18 rebuild,
# kept here for context on why this block looks the way it does:
# 1) `rosinstall_generator` DID resolve both "mavlink" (release/lyrical/mavlink/2026.6.19-1 —
#    mavlink itself is already released for lyrical) and "mavros" (upstream tag 2.14.0)
#    successfully — that part was never the problem.
# 2) The build then failed on `apt-get install -y libasio-dev` with `E: Unable to locate
#    package`. Traced to a **self-inflicted bug, not an archive gap**: `apt-cache policy
#    libasio-dev` run directly against this same base image confirms the package genuinely
#    exists (`resolute/universe arm64`, candidate `1:1.30.2-1build1`) — the real cause was that
#    the `rm -rf /var/lib/apt/lists/*` at the end of the block below (added purely for
#    image-size hygiene) wiped the apt index *before* rosdep's own `apt-get install` call, and
#    rosdep does not re-run `apt-get update` itself. Fixed by moving that cleanup to run only
#    after this whole mavros block finishes, not before rosdep needs the index — which is the
#    ordering already reflected below.
ENV MAVROS_WS=/home/$USER/mavros_ws
RUN apt-get update -o APT::Update::Error-Mode=any && \
    apt-get install -y --no-install-recommends \
      python3-rosinstall-generator python3-osrf-pycommon geographiclib-tools

RUN mkdir -p $MAVROS_WS/src
WORKDIR $MAVROS_WS
RUN . "/opt/ros/${ROS_DISTRO}/setup.sh" && \
    rosinstall_generator --format repos mavlink | tee /tmp/mavlink.repos && \
    rosinstall_generator --format repos --upstream mavros | tee /tmp/mavros.repos && \
    vcs import src < /tmp/mavlink.repos && \
    vcs import src < /tmp/mavros.repos && \
    rosdep update --rosdistro $ROS_DISTRO && \
    rosdep install --rosdistro $ROS_DISTRO --from-paths src --ignore-src -y
RUN $MAVROS_WS/src/mavros/mavros/scripts/install_geographiclib_datasets.sh

# `MAKEFLAGS=-j1` here only (not globally): the first attempt at this colcon build (2026-07-18)
# OOM-killed `cc1plus` while compiling `mavros`'s plugins (`Killed signal terminated program
# cc1plus`, Docker itself then failed the whole build step with `ResourceExhausted: cannot
# allocate memory`) — make's default `-j$(nproc)` was compiling too many of mavros's plugin
# translation units in parallel for the memory available. Every other colcon build in this
# Dockerfile (DAVE packages, wgpu_vendor, multibeam_sonar, ArduSub) completed fine at default
# parallelism, so this is scoped to just the mavros package rather than slowing down the whole
# image build. If this still OOMs, the fix is host-level (raise Docker Desktop's memory limit
# under Settings > Resources), not something fixable from inside the Dockerfile alone.
RUN . "/opt/ros/${ROS_DISTRO}/setup.sh" && \
    MAKEFLAGS="-j1" colcon build --merge-install --executor sequential --parallel-workers 1 && \
    rm -rf /var/lib/apt/lists/*

# --- ArduSub SITL (BlueROV2) — Python 3.14 compatibility shims required, see notes/ardusub-sitl-setup.md ---
# Pinned to the exact commit verified in README.md's "Pinned commits" table (not the
# "ArduSub-stable" branch/ref tip, which can move) so this image is reproducible against the tested code.
ARG ARDUSUB_COMMIT="30257f01185471ab4c1ac544e47d1b4437e44c98"
WORKDIR /home/$USER
RUN git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git && \
    cd ardupilot && git fetch --tags && git checkout --detach "$ARDUSUB_COMMIT" && \
    git submodule update --init --recursive

RUN mkdir -p /home/$USER/imp_shim && \
    printf 'import types\ndef new_module(name):\n    return types.ModuleType(name)\n' > /home/$USER/imp_shim/imp.py && \
    printf 'import shlex\ndef quote(s):\n    return shlex.quote(s)\n' > /home/$USER/imp_shim/pipes.py

ENV PYTHONPATH=/home/$USER/imp_shim:/home/$USER/ardupilot/modules/waf/waflib/extras
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# chown first — the repo was cloned as root but must be built as $USER, and git refuses to
# operate across ownership boundaries ("detected dubious ownership") since CVE-2022-24765
RUN chown -R $USER:$USER /home/$USER/ardupilot /home/$USER/imp_shim && \
    cd /home/$USER/ardupilot && \
    sed -i "s/ python-argparse//g" Tools/environment_install/install-prereqs-ubuntu.sh && \
    su $USER -c "git config --global --add safe.directory /home/$USER/ardupilot" && \
    su $USER -c "cd /home/$USER/ardupilot && Tools/environment_install/install-prereqs-ubuntu.sh -y" && \
    su $USER -c "cd /home/$USER/ardupilot && ./waf configure --board sitl && ./waf sub" && \
    cp /home/$USER/ardupilot/build/sitl/bin/ardusub /usr/local/bin/ardusub

# --- QGroundControl, Firefox, environment ---
RUN usermod -aG dialout $USER && apt -y remove modemmanager || true
RUN apt-get update -o APT::Update::Error-Mode=any && \
    apt-get install -y --no-install-recommends \
    ffmpeg python3-venv python3-websockets \
    ros-${ROS_DISTRO}-joy-linux gstreamer1.0-tools gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly python3-gi python3-gst-1.0 \
    libfuse2 libxcb-xinerama0 libxkbcommon-x11-0 libxcb-cursor-dev gstreamer1.0-qt6 \
    gstreamer1.0-gl libqt6qml6 qml6-module-qtquick qml6-module-qtquick-window && \
    rm -rf /var/lib/apt/lists/*

USER $USER
RUN mkdir -p ~/QGC && wget -O ~/QGC/QGroundControl-aarch64-DailyBuild.AppImage \
    "https://d176tv9ibo4jno.cloudfront.net/builds/master/QGroundControl-aarch64.AppImage" && \
    cd ~/QGC && chmod +x QGroundControl-aarch64-DailyBuild.AppImage && \
    ./QGroundControl-aarch64-DailyBuild.AppImage --appimage-extract && \
    mv ~/QGC/squashfs-root/* ~/QGC/. && rm ~/QGC/QGroundControl-aarch64-DailyBuild.AppImage && \
    mkdir -p /home/$USER/.local/bin && \
    ln -sf /home/$USER/QGC/AppRun /home/$USER/.local/bin/qgroundcontrol

USER root
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/$USER/.bashrc && \
    echo "source $DAVE_UNDERLAY/install/setup.bash" >> /home/$USER/.bashrc && \
    echo "source $MAVROS_WS/install/setup.bash" >> /home/$USER/.bashrc && \
    echo "export PATH=/usr/local/bin:\$PATH" >> /home/$USER/.bashrc && \
    echo "export GEOGRAPHICLIB_GEOID_PATH=/usr/share/GeographicLib/geoids" >> /home/$USER/.bashrc && \
    echo "export PS1='\[\e[1;36m\]\u@lyrical_docker\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '" >> /home/$USER/.bashrc

# --- Run (no systemd inside this container) ---
# hadolint ignore=DL3025
CMD uid="$(id -u docker)"; \
    sudo install -d -m 0755 /run/xrdp /run/xrdp/sockdir; \
    sudo install -d -m 0700 -o docker -g docker "/run/user/$uid"; \
    sudo rm -f /run/xrdp/*.pid /var/run/xrdp/*.pid; \
    sudo mkdir -p /run/dbus; sudo rm -f /run/dbus/pid; \
    sudo dbus-daemon --system --fork; \
    [ -f /usr/sbin/sshd ] && sudo /usr/sbin/sshd; \
    sudo xrdp-sesman --nodaemon --config /etc/xrdp/sesman.ini & \
    exec sudo xrdp --nodaemon --config /etc/xrdp/xrdp.ini
