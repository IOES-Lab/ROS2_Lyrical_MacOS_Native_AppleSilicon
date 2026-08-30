# Exact Underwater Camera Quickstart startup recheck

The exact Wiki/DAVE launch was repeated six times on macOS with a 120-second evidence
window: three default Fast DDS runs and three explicit UDPv4 runs.

All **6/6** produced `/underwater_camera/simulated_image` as 320×240 `bgr8` with 230400
bytes and shut down cleanly. The topic first appeared after 89.520–105.333 seconds and the
image arrived after 93.029–110.431 seconds.

The earlier short-wait “topic missing” observation is therefore explained by startup
latency in this environment, not by a current camera or Fast DDS transport failure. This
recheck covers startup/output only; the separate parameter matrix covers the optical
transform and R/B semantics.

Machine-readable results are in `summary.json`.
