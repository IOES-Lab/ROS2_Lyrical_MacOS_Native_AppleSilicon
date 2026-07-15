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
# - Desktop is XFCE, not GNOME. Ubuntu 26.04 ships GNOME 50, which is Wayland-only (no GNOME
#   X11 session) — xorgxrdp is X11-only, so it cannot start a GNOME session on this OS release.
#   XFCE still ships a full X11 session, so that's what this image's RDP desktop uses.
#   See README.md "Known limitation" and docker/startwm.sh.
#
# Status: Experimental / validation environment.
# Validated: image build, headless launch, XFCE/xrdp login, representative smoke tests.
# Not yet validated: all 18 worlds, quantitative performance.
#
# Naming note: the advisor plans to eventually move this project off the "DAVE" name (not yet
# decided). External/display names (image tag, container name, hostname, shell prompt) should
# use a neutral placeholder ("lyrical-sim") rather than "DAVE" — see docker/README.md. This does
# NOT apply to the existing DAVE codebase or its ROS package names (dave_demos, dave_worlds,
# dave_ws, etc.) below, which are left untouched.
#
# Security note: the $USER account password defaults to "docker" (see ARG PASS below) —
# fine for a local, non-exposed validation container; change it before exposing this image
# on any shared or internet-facing host.

FROM arm64v8/ubuntu:26.04

ARG USER=docker
ARG PASS=docker
ARG X11Forwarding=true

# --- RDP / desktop setup (XFCE + xorgxrdp — see note above on why not GNOME) ---
# hadolint ignore=DL3008,DL3015,DL3009
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
        apt-get install -y xfce4 xfce4-terminal xorgxrdp dbus-x11 xrdp sudo; \
    [ $X11Forwarding = 'true' ] && apt-get install -y openssh-server; \
    apt-get autoremove --purge; \
    apt-get clean; \
    rm -f /run/reboot-required*

RUN useradd -s /bin/bash -m $USER -p "$(openssl passwd "$PASS")"; \
    usermod -aG sudo $USER; echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers; \
    adduser xrdp ssl-cert; \
    # xrdp daemon needs root-group access to session sockets under /run/xrdp/sockdir/ —
    # without this, RDP connections time out after ~30s ("connection problem, giving up")
    usermod -aG root xrdp; \
    echo 'LANG=en_US.UTF-8' >> /etc/default/locale; \
    sed -i "s/#EnableConsole=false/EnableConsole=true/g" /etc/xrdp/xrdp.ini; \
    sed -i 's/max_bpp=32/max_bpp=16/g' /etc/xrdp/xrdp.ini; \
    [ $X11Forwarding = 'true' ] && \
        sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config || \
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config || \
        :;

# Custom startwm.sh replaces the default Debian Xsession -> ~/.xsession lookup chain with a
# single transparent script that also sources ROS 2 / DAVE before launching XFCE.
COPY docker/startwm.sh /etc/xrdp/startwm.sh
RUN chmod +x /etc/xrdp/startwm.sh

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo xterm init systemd snapd vim net-tools \
    curl wget git build-essential cmake cppcheck \
    gnupg libeigen3-dev libgles2-mesa-dev \
    lsb-release pkg-config protobuf-compiler \
    python3-dbg python3-pip python3-venv \
    qtbase5-dev ruby dirmngr gnupg2 nano xauth \
    software-properties-common htop libtool \
    x11-apps mesa-utils bison flex automake && \
    rm -rf /var/lib/apt/lists/

RUN truncate -s0 /tmp/preseed.cfg && \
    (echo "tzdata tzdata/Areas select Etc" >> /tmp/preseed.cfg) && \
    (echo "tzdata tzdata/Zones/Etc select UTC" >> /tmp/preseed.cfg) && \
    debconf-set-selections /tmp/preseed.cfg && \
    rm -f /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata
RUN apt-get update && \
    apt-get -y install --no-install-recommends locales tzdata && \
    rm -rf /tmp/*
RUN locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

EXPOSE 3389/tcp
EXPOSE 22/tcp

# --- ROS 2 Lyrical + Gazebo Jetty ---
ARG BRANCH="wgpu_integration"
ARG ROS_DISTRO="lyrical"

RUN apt update && apt full-upgrade -y && apt autoremove -y

# Gazebo Jetty is vendored by ros-lyrical-ros-gz on apt already — no separate Gazebo source build
RUN export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') && \
    curl -L -o /tmp/ros2-apt-source.deb \
      "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" && \
    dpkg -i /tmp/ros2-apt-source.deb && \
    apt update && \
    apt install -y --no-install-recommends \
      ros-${ROS_DISTRO}-desktop ros-${ROS_DISTRO}-ros-gz \
      python3-rosdep python3-vcstool python3-colcon-common-extensions

# --- DAVE workspace (naitikpahwa18/dave, wgpu_integration branch + our migration patch) ---
ENV DAVE_UNDERLAY=/home/$USER/dave_ws
WORKDIR $DAVE_UNDERLAY/src
RUN git clone https://github.com/naitikpahwa18/dave.git dave && \
    cd dave && git checkout $BRANCH

COPY patches/dave_lyrical_jetty_migration_mac.diff /tmp/dave_lyrical_jetty_migration_mac.diff
RUN cd dave && git apply /tmp/dave_lyrical_jetty_migration_mac.diff

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

# --- ArduSub SITL (BlueROV2) — Python 3.14 compatibility shims required, see notes/ardusub-sitl-setup.md ---
WORKDIR /home/$USER
RUN git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git && \
    cd ardupilot && git fetch --tags && git checkout ArduSub-stable -b ardusub-stable && \
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
RUN apt-get update && \
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
RUN echo "source $DAVE_UNDERLAY/install/setup.bash" >> /home/$USER/.bashrc && \
    echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/$USER/.bashrc && \
    echo "export PATH=/usr/local/bin:\$PATH" >> /home/$USER/.bashrc && \
    echo "export GEOGRAPHICLIB_GEOID_PATH=/usr/share/GeographicLib/geoids" >> /home/$USER/.bashrc && \
    echo "export PS1='\[\e[1;36m\]\u@lyrical_docker\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '" >> /home/$USER/.bashrc

# --- Run ---
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
