#!/usr/bin/env python3
import json
import sys
import time

import rclpy
from geometry_msgs.msg import PoseArray
from nav_msgs.msg import Odometry
from rclpy.node import Node
from sensor_msgs.msg import CameraInfo, Image, Imu, MagneticField


out_path = sys.argv[1]
timeout_s = int(sys.argv[2]) if len(sys.argv) > 2 else 120
rclpy.init()
node = Node("capture_rexrov_exact_example")
rows = {}


def once(name, payload):
    rows.setdefault(name, payload)


node.create_subscription(
    Odometry,
    "/model/rexrov/odometry",
    lambda m: once(
        "odometry",
        {
            "frame_id": m.header.frame_id,
            "position": [
                m.pose.pose.position.x,
                m.pose.pose.position.y,
                m.pose.pose.position.z,
            ],
        },
    ),
    10,
)
node.create_subscription(
    Odometry,
    "/model/rexrov/odometry_with_covariance",
    lambda m: once("odometry_with_covariance", {"frame_id": m.header.frame_id}),
    10,
)
node.create_subscription(
    PoseArray,
    "/model/rexrov/pose",
    lambda m: once("pose", {"frame_id": m.header.frame_id, "pose_count": len(m.poses)}),
    10,
)
node.create_subscription(
    Imu,
    "/model/rexrov/imu",
    lambda m: once(
        "imu",
        {
            "frame_id": m.header.frame_id,
            "linear_acceleration": [
                m.linear_acceleration.x,
                m.linear_acceleration.y,
                m.linear_acceleration.z,
            ],
        },
    ),
    10,
)
node.create_subscription(
    MagneticField,
    "/model/rexrov/magnetometer",
    lambda m: once(
        "magnetometer",
        {
            "frame_id": m.header.frame_id,
            "magnetic_field": [
                m.magnetic_field.x,
                m.magnetic_field.y,
                m.magnetic_field.z,
            ],
        },
    ),
    10,
)
node.create_subscription(
    Image,
    "/model/rexrov/camera/image",
    lambda m: once(
        "camera_image",
        {
            "frame_id": m.header.frame_id,
            "width": m.width,
            "height": m.height,
            "encoding": m.encoding,
            "data_length": len(m.data),
        },
    ),
    10,
)
node.create_subscription(
    CameraInfo,
    "/model/rexrov/camera/camera_info",
    lambda m: once(
        "camera_info",
        {"frame_id": m.header.frame_id, "width": m.width, "height": m.height},
    ),
    10,
)

expected = {
    "odometry",
    "odometry_with_covariance",
    "pose",
    "imu",
    "magnetometer",
    "camera_image",
    "camera_info",
}
deadline = time.monotonic() + timeout_s
while time.monotonic() < deadline and not expected.issubset(rows):
    rclpy.spin_once(node, timeout_sec=0.5)

result = {
    "example": "rexrov + empty.sdf",
    "received": rows,
    "missing": sorted(expected - set(rows)),
    "timeout_s": timeout_s,
}
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(result, f, indent=2)
    f.write("\n")
print(json.dumps(result, indent=2))
node.destroy_node()
rclpy.shutdown()
