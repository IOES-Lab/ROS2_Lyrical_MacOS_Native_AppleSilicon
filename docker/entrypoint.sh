#!/bin/bash
# Container entrypoint — starts dbus, sshd (optional), and xrdp/xrdp-sesman
# in the foreground so the container stays alive as long as xrdp does.
set -e

sudo rm -f /var/run/xrdp/xrdp*.pid >/dev/null 2>&1 || true
sudo service dbus restart >/dev/null 2>&1 || true
sudo /usr/lib/systemd/systemd-logind >/dev/null 2>&1 &

if [ -x /usr/sbin/sshd ]; then
  sudo /usr/sbin/sshd
fi

sudo xrdp-sesman --config /etc/xrdp/sesman.ini
exec sudo xrdp --nodaemon --config /etc/xrdp/xrdp.ini
