#!/usr/bin/env python3
import json
import sys
import time
from pathlib import Path

import rclpy
from nav_msgs.msg import Odometry
from rclpy.node import Node

out_dir = Path(sys.argv[1])
duration = float(sys.argv[2])
out_dir.mkdir(parents=True, exist_ok=True)

def sim_time(msg):
    return msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9

def record(msg):
    return {
        "sim_time_s": sim_time(msg),
        "position_m": {
            "x": msg.pose.pose.position.x,
            "y": msg.pose.pose.position.y,
            "z": msg.pose.pose.position.z,
        },
        "linear_velocity_mps": {
            "x": msg.twist.twist.linear.x,
            "y": msg.twist.twist.linear.y,
            "z": msg.twist.twist.linear.z,
        },
    }

class Recorder(Node):
    def __init__(self):
        super().__init__("ocean_current_odom_recorder")
        self.first = None
        self.last = None
        self.create_subscription(
            Odometry,
            "/model/rexrov/odometry",
            self.callback,
            10,
        )

    def callback(self, msg):
        item = record(msg)
        if self.first is None:
            self.first = item
            print("START", json.dumps(item))
            return

        if item["sim_time_s"] - self.first["sim_time_s"] >= duration:
            self.last = item
            print("END", json.dumps(item))

rclpy.init()
node = Recorder()
wall_start = time.monotonic()

while rclpy.ok() and node.last is None:
    rclpy.spin_once(node, timeout_sec=1.0)
    if time.monotonic() - wall_start > 300:
        raise TimeoutError("No complete odometry window within 300 wall seconds")

start = node.first
end = node.last

displacement = {
    axis: end["position_m"][axis] - start["position_m"][axis]
    for axis in ("x", "y", "z")
}

result = {
    "requested_sim_duration_s": duration,
    "actual_sim_duration_s": end["sim_time_s"] - start["sim_time_s"],
    "start": start,
    "end": end,
    "displacement_m": displacement,
}

path = out_dir / "odom_window.json"
path.write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
print(f"Saved: {path}")

node.destroy_node()
rclpy.shutdown()
