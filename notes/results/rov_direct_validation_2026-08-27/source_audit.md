# ROV source audit (2026-08-27)

DAVE source revision: `6aef91c823af5da073329b84ba617b572965e79e`

The local checkout is not pristine. The ordinary `rexrov`, `bluerov2`,
`bluerov2_heavy`, and `glider_slocum` models contain the local IMU-topic patch.
The fifth model below is unchanged and therefore provides the as-shipped comparison.

## `bluerov2_heavy_multibeam_sonar/model.sdf`

- lines 42-48: IMU sensor has no `<topic>` element.
- lines 65-81: camera declares a topic.
- lines 141-145: custom multibeam sonar declares a topic.
- no `type="magnetometer"` sensor exists in this model.

## `bluerov2_heavy_multibeam_sonar/robot_config.py`

- lines 39-45 bridge pose, IMU, magnetometer, and multibeam PointCloud2.
- Thus the magnetometer bridge has no backing sensor in this model.

Runtime establishes the remaining observation: on both tested platforms the
vehicle spawned, odometry published, but IMU, magnetometer, and sonar
PointCloud2 did not publish within the 120-second capture window. The source
audit explains the IMU and magnetometer results; it does not establish the
root cause of the silent sonar output.
