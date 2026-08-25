#!/usr/bin/env python3
import csv
import json
import math
import os
import statistics
import struct
import sys
import time

import rclpy
from rclpy.node import Node
from rclpy.qos import (
    QoSProfile,
    ReliabilityPolicy,
    DurabilityPolicy,
    HistoryPolicy,
)
from marine_acoustic_msgs.msg import ProjectedSonarImage

OUT = sys.argv[1]
BACKEND = sys.argv[2]
TOPIC = "/sensor/codex_multibeam/sonar_image_raw"
EXPECTED = 3.99
SAMPLE_COUNT = 5

os.makedirs(OUT, exist_ok=True)

class Capture(Node):
    def __init__(self):
        super().__init__(f"{BACKEND}_peak_series_capture")
        self.rows = []
        self.seen = set()

        qos = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
        )
        self.create_subscription(
            ProjectedSonarImage,
            TOPIC,
            self.callback,
            qos,
        )

    def callback(self, msg):
        stamp = (msg.header.stamp.sec, msg.header.stamp.nanosec)
        if stamp in self.seen or len(self.rows) >= SAMPLE_COUNT:
            return
        self.seen.add(stamp)

        beams = int(msg.image.beam_count)
        ranges = list(msg.ranges)
        values = [
            item[0]
            for item in struct.iter_unpack("<f", bytes(msg.image.data))
        ]

        if len(values) != beams * len(ranges):
            raise RuntimeError(
                f"layout mismatch: {len(values)} != "
                f"{beams} × {len(ranges)}"
            )

        center_beam = beams // 2
        profile = [
            values[index * beams + center_beam]
            for index in range(len(ranges))
        ]

        candidates = [
            (value, ranges[index], index)
            for index, value in enumerate(profile)
            if math.isfinite(value)
        ]
        candidates.sort(reverse=True)

        peak_value, peak_range, peak_index = candidates[0]

        expected_index = min(
            range(len(ranges)),
            key=lambda index: abs(ranges[index] - EXPECTED),
        )
        expected_value = profile[expected_index]
        expected_rank = 1 + sum(
            1 for value, _, _ in candidates
            if value > expected_value
        )

        row = {
            "sample": len(self.rows) + 1,
            "stamp_sec": stamp[0],
            "stamp_nanosec": stamp[1],
            "peak_range_m": float(peak_range),
            "peak_error_m": float(peak_range - EXPECTED),
            "peak_value_db": float(peak_value),
            "peak_index": int(peak_index),
            "expected_bin_range_m": float(ranges[expected_index]),
            "expected_bin_value_db": float(expected_value),
            "expected_bin_rank": int(expected_rank),
        }
        self.rows.append(row)
        print(json.dumps(row))

rclpy.init()
node = Capture()
deadline = time.time() + 300

while time.time() < deadline and len(node.rows) < SAMPLE_COUNT:
    rclpy.spin_once(node, timeout_sec=1.0)

if len(node.rows) != SAMPLE_COUNT:
    raise RuntimeError(
        f"received {len(node.rows)}/{SAMPLE_COUNT} samples"
    )

csv_path = os.path.join(OUT, "peak_series_5frames.csv")
with open(csv_path, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=node.rows[0].keys())
    writer.writeheader()
    writer.writerows(node.rows)

peak_ranges = [row["peak_range_m"] for row in node.rows]
summary = {
    "backend": BACKEND,
    "sample_count": len(node.rows),
    "expected_range_m": EXPECTED,
    "peak_ranges_m": peak_ranges,
    "median_peak_range_m": statistics.median(peak_ranges),
    "min_peak_range_m": min(peak_ranges),
    "max_peak_range_m": max(peak_ranges),
    "all_expected_bin_rank_1": all(
        row["expected_bin_rank"] == 1 for row in node.rows
    ),
}

json_path = os.path.join(OUT, "peak_series_summary.json")
with open(json_path, "w") as f:
    json.dump(summary, f, indent=2)

print("\nSUMMARY")
print(json.dumps(summary, indent=2))
print(f"\nSaved: {csv_path}")
print(f"Saved: {json_path}")

node.destroy_node()
rclpy.shutdown()
