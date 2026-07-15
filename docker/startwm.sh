#!/bin/sh
# Custom xrdp startwm.sh — replaces the default Debian Xsession lookup chain
# (/etc/xrdp/startwm.sh -> ~/.xsession) with a single transparent script.
#
# Why this exists: on Ubuntu 26.04 GNOME 50 ships Wayland-only — it no longer
# provides a GNOME X11 session, so xorgxrdp (which is X11-only) cannot start
# a GNOME session. XFCE still ships a full X11 session, so this image uses
# XFCE as its RDP desktop. See ../README.md "Known limitation".

export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
export XDG_SESSION_DESKTOP=xfce

# Make ROS 2 / DAVE available to anything launched from the XFCE session
# (terminal, file manager actions, etc.), not just interactive bash logins.
. /opt/ros/lyrical/setup.sh 2>/dev/null || true
. "$DAVE_UNDERLAY/install/setup.sh" 2>/dev/null || true

exec startxfce4
