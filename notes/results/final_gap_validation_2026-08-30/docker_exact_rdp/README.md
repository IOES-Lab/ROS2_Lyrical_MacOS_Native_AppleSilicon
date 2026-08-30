# Earlier exact cache image rendered RDP and QGroundControl replay

Image `lyrical-sim:jetty-rdp-external-stack-check` (`af9586…`) was started as a dedicated
container on `127.0.0.1:3396`. Windows App was invoked with Microsoft's legacy encoded
RDP URI, using the saved Docker-user credentials.

## Result

- xrdp accepted the login and started Xorg `:10` plus XFCE;
- the actual X framebuffer was captured (`exact_rdp_root.png`);
- the baseline BlueROV stack reached MAVROS `connected: true`, MANUAL mode;
- QGroundControl was launched with its supported `QGC_NO_SYSTEM_GLIB=1` opt-out;
- the rendered framebuffer (`integrated_qgc/qgc_connected.png`) visibly shows Gazebo and
  QGroundControl, with QGC reporting Ready/Manual and the vehicle connection active.

This closes the exact-image rendered-login and QGC-vehicle-connection gap. It does not
validate physical HIL, network exposure outside localhost, or QGC without the GLib
opt-out.

Official references:

- <https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/remote-desktop-uri>
- <https://github.com/neutrinolabs/xrdp>
