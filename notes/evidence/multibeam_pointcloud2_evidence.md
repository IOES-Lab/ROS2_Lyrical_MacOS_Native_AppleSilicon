# PointCloud2 evidence for the multibeam sonar plugin

Added 2026-07-23 in response to a review finding that the "real `PointCloud2` output confirmed,
513 beams × 301 rays" claims in `README.md` / `notes/validation_matrix.csv` (attributed to
2026-07-07 Mac Metal / Jazzy+Harmonic, and 2026-07-11 Docker / Lyrical+Jetty) had no small,
linkable evidence artifact in this repo — only the claim itself, not the underlying output. This
file documents exactly what is and isn't independently traceable from files actually committed
here, rather than asserting the original claim is correct or incorrect.

## What IS confirmed by files already in this repo

The `ros_gz` bridge log lines below (real, unedited excerpts from committed files) confirm that a
`PointCloud2`-typed bridge was created for the multibeam sonar topic, on the correct topic name,
in this Lyrical+Jetty checkout:

```
[parameter_bridge-3] [INFO] [1784698409.516437083] [ros_gz_bridge]: Creating GZ->ROS Bridge: [/sensor/multibeam_sonar/point_cloud (gz.msgs.PointCloudPacked) -> /sensor/multibeam_sonar/point_cloud (sensor_msgs/msg/PointCloud2)] (Lazy 0)
[parameter_bridge-3] [INFO] [1784698409.520582708] [ros_gz_bridge]: Creating ROS->GZ Bridge: [/sensor/multibeam_sonar/point_cloud (sensor_msgs/msg/PointCloud2) -> /sensor/multibeam_sonar/point_cloud (gz.msgs.PointCloudPacked)] (Lazy 0)
```

Source: [`notes/results/dave_multibeam_sonar.log`](../results/worlds/dave_multibeam_sonar.log) lines
18-19 (2026-07-22 `test_worlds.sh` smoke test run, Docker). The same two lines also appear in
[`notes/results/dave_ocean_waves_sonar.log`](../results/worlds/dave_ocean_waves_sonar.log) and
[`notes/results/dave_ocean_waves_sonar_integrated.log`](../results/worlds/dave_ocean_waves_sonar_integrated.log),
and (from the earlier, now-superseded benchmark run) in
[`notes/bench_results/SUPERSEDED_2026-07-22/dave_multibeam_sonar.log`](../benchmarks/bench_results/SUPERSEDED_2026-07-22/dave_multibeam_sonar.log),
which additionally shows:

```
[parameter_bridge-3] [INFO] [1784702574.527475468] [ros_gz_bridge]: Passing message from ROS sensor_msgs/msg/PointCloud2 to Gazebo gz.msgs.PointCloudPacked (showing msg only once per type)
```

**Corrected 2026-07-23 (caught in review):** this last line is the **ROS → Gazebo** direction of
the bidirectional bridge (line 18 above), not the Gazebo → ROS direction that would carry the
sonar plugin's actual sensor output (line 17's Bridge). It confirms the bridge is bidirectionally
alive and that *some* `PointCloud2`-typed message crossed it in that direction — it is not, by
itself, evidence that the sonar plugin's own output reached the ROS side. An earlier version of
this file cited this line without specifying direction, which read as if it supported the sonar
output claim; it doesn't. The Gazebo → ROS direction (line 17) is confirmed created here, but no
log in this repo shows a "Passing message" line for *that* direction specifically — see the "NOT
independently traceable" section below, which already correctly scoped the actual sonar-output
question to the session's contemporaneous notes rather than a committed log capture.

## What is NOT independently traceable from this repo

None of the log files currently in this repo contain a `ros2 topic echo` (or equivalent) capture
of an actual `PointCloud2` message's contents in the Gazebo → ROS direction (the direction that
would carry the sonar plugin's real output), and none contain the sonar plugin logging its own
beam/ray configuration (grepped for "beam", "ray", "width", "height" in the relevant logs — no
matches). The specific **"513 beams × 301 rays"** figure, and the 2026-07-07 (Mac Jazzy+Harmonic)
and 2026-07-11 (Docker Lyrical+Jetty) dates it's attributed to, are not backed by any small
evidence artifact in this repo as of 2026-07-23 — they rest on the session's own contemporaneous
notes rather than a committed, independently-checkable file. Nor is there a committed log line
confirming a message actually crossed the bridge in the Gazebo → ROS direction specifically (only
the reverse, ROS → Gazebo, direction has a "Passing message" line on record — see above).

**This does not mean the claim is false** — the bridge-creation evidence above is consistent with
it, and the figure was recorded in real time during those sessions, not invented after the fact.
But a reviewer working only from this GitHub repo cannot currently verify the exact dimensions, or
the Gazebo → ROS direction of message flow, themselves. If/when the environment is available
again, the most useful addition would be a short `ros2 topic echo --once
/sensor/multibeam_sonar/point_cloud` capture (or just its `width`/`height` fields, not the full
point data) saved as a small text file here.
