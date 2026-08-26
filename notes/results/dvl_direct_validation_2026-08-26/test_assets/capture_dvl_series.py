#!/usr/bin/env python3
import csv
import json
import math
import os
import sys
import time

import rclpy
from dave_interfaces.msg import DVL
from rclpy.node import Node

if len(sys.argv) != 3:
    raise SystemExit("usage: capture_dvl_series.py OUTPUT_DIR SAMPLE_COUNT")

output_dir = os.path.abspath(sys.argv[1])
sample_count = int(sys.argv[2])
os.makedirs(output_dir, exist_ok=True)

class Probe(Node):
    def __init__(self):
        super().__init__("dvl_series_probe")
        self.rows = []
        self.subscription = self.create_subscription(
            DVL, "/dvl/velocity", self.callback, 10)

    def callback(self, msg):
        if len(self.rows) >= sample_count:
            return
        row = {
            "index": len(self.rows) + 1,
            "stamp_sec": int(msg.header.stamp.sec),
            "stamp_nanosec": int(msg.header.stamp.nanosec),
            "stamp_s": float(msg.header.stamp.sec) + float(msg.header.stamp.nanosec) * 1e-9,
            "frame_id": msg.header.frame_id,
            "type": msg.type,
            "target_type": msg.target.type,
            "target_range_m": float(msg.target.range),
            "velocity_x_mps": float(msg.velocity.twist.linear.x),
            "velocity_y_mps": float(msg.velocity.twist.linear.y),
            "velocity_z_mps": float(msg.velocity.twist.linear.z),
            "beam_count": len(msg.beams),
            "beam_ranges_m": [float(b.range) for b in msg.beams],
            "beam_locked": [bool(b.locked) for b in msg.beams],
        }
        self.rows.append(row)
        print(json.dumps(row), flush=True)

rclpy.init()
node = Probe()
deadline = time.monotonic() + 300.0
while rclpy.ok() and len(node.rows) < sample_count and time.monotonic() < deadline:
    rclpy.spin_once(node, timeout_sec=1.0)

if len(node.rows) != sample_count:
    node.destroy_node()
    rclpy.shutdown()
    raise TimeoutError(f"received {len(node.rows)} of {sample_count} messages")

intervals = [
    node.rows[i]["stamp_s"] - node.rows[i - 1]["stamp_s"]
    for i in range(1, len(node.rows))
]
speeds = [
    math.sqrt(
        row["velocity_x_mps"] ** 2
        + row["velocity_y_mps"] ** 2
        + row["velocity_z_mps"] ** 2
    )
    for row in node.rows
]

def mean(values):
    return sum(values) / len(values)

summary = {
    "sample_count": len(node.rows),
    "all_frame_ids_empty": all(not row["frame_id"] for row in node.rows),
    "all_bottom_track": all(row["target_type"] == "DVL_TARGET_BOTTOM" for row in node.rows),
    "all_four_beams_locked": all(
        row["beam_count"] == 4 and all(row["beam_locked"]) for row in node.rows
    ),
    "mean_sim_interval_s": mean(intervals),
    "sim_message_rate_hz": 1.0 / mean(intervals),
    "target_range_mean_m": mean([r["target_range_m"] for r in node.rows]),
    "target_range_min_m": min(r["target_range_m"] for r in node.rows),
    "target_range_max_m": max(r["target_range_m"] for r in node.rows),
    "velocity_mean_mps": {
        "x": mean([r["velocity_x_mps"] for r in node.rows]),
        "y": mean([r["velocity_y_mps"] for r in node.rows]),
        "z": mean([r["velocity_z_mps"] for r in node.rows]),
    },
    "speed_mean_mps": mean(speeds),
}

with open(os.path.join(output_dir, "series.json"), "w") as f:
    json.dump({"summary": summary, "samples": node.rows}, f, indent=2)

with open(os.path.join(output_dir, "series.csv"), "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=[
            "index", "stamp_sec", "stamp_nanosec", "stamp_s", "frame_id",
            "type", "target_type", "target_range_m", "velocity_x_mps",
            "velocity_y_mps", "velocity_z_mps", "beam_count",
        ],
    )
    writer.writeheader()
    for row in node.rows:
        writer.writerow({k: row[k] for k in writer.fieldnames})

with open(os.path.join(output_dir, "series_summary.json"), "w") as f:
    json.dump(summary, f, indent=2)

print("SUMMARY")
print(json.dumps(summary, indent=2))

node.destroy_node()
rclpy.shutdown()
