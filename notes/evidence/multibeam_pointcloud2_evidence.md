# PointCloud2 evidence for the multibeam sonar plugin

## Current verdict — 2026-08-25

The current ROS 2 Lyrical + Gazebo Jetty output claim is backed by direct,
committed artifacts:

- Mac Apple M2 WGPU/Metal: PointCloud2 **513×301**, image/raw sonar **513×399**
- Custom overlay sensor/world: PointCloud2 **65×61**, image/raw sonar **65×319**
- Docker RDP, explicitly forced CPU backend: raw sonar **513×399**

Evidence:
[`results/multibeam_direct_validation_2026-08-25/`](../results/multibeam_direct_validation_2026-08-25/).

The direct PointCloud2 artifact records `frame_id`
`blueview_p900/blueview_p900_base_link/multibeam_sonar`, height 301, width 513,
fields `x`, `y`, `z`, `intensity`, `ring`, `point_step` 32, `row_step` 16416,
and data length 4941216.

The raw-sonar artifact records 513 beam directions, 399 range bins, 900 kHz
frequency and 1500 m/s sound speed.

## Historical traceability gap

On 2026-07-23 the repository had bridge-creation logs and session notes but no
small committed Gazebo→ROS PointCloud2 echo artifact. A reviewer could not
independently verify the exact 513×301 dimensions from the repository alone.

The 2026-08-25 artifacts close that gap for the **current Lyrical+Jetty
workspace**. They do not retroactively create artifacts for the separate
2026-07-07 Jazzy+Harmonic or 2026-07-11 Docker sessions.

## Numerical scope

Publication and structure are not accuracy proofs. A controlled 3.99 m planar
test found:

- CPU raw-sonar peak: **3.988294 m**, expected bin ranked first in 5/5 frames
- WGPU raw-sonar peak: **6.396–6.446 m**, expected bin never ranked first in 5/5 frames
- PointCloud centre range on both backends: **3.990244 m**

Therefore structured output is verified, while WGPU numerical equivalence and
general acoustic correctness are not.
