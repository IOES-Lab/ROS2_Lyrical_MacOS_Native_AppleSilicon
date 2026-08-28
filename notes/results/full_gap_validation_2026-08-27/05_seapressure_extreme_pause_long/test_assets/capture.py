#!/usr/bin/env python3
import json
import math
from pathlib import Path
import statistics
import subprocess
import sys
import time

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import FluidPressure

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
conditions = {
    "surface": ("/model/sp_surface_long/sea_pressure", 0.0, 10000),
    "deep_1000": ("/model/sp_deep_1000/sea_pressure", -1000.0, 1000),
    "above_1000": ("/model/sp_above_1000/sea_pressure", 1000.0, 1000),
}

class Collector(Node):
    def __init__(self):
        super().__init__("seapressure_extreme_pause_capture")
        self.samples = {name: [] for name in conditions}
        self.keepalive = []
        for name, (topic, _z, _wanted) in conditions.items():
            self.keepalive.append(
                self.create_subscription(FluidPressure, topic, lambda msg, key=name: self.callback(key, msg), 50)
            )

    def callback(self, name, msg):
        if len(self.samples[name]) >= conditions[name][2]:
            return
        self.samples[name].append({
            "stamp_s": msg.header.stamp.sec + msg.header.stamp.nanosec / 1e9,
            "pressure": msg.fluid_pressure,
            "variance": msg.variance,
            "frame_id": msg.header.frame_id,
        })

rclpy.init()
node = Collector()

paused_deadline = time.monotonic() + 5.0
while time.monotonic() < paused_deadline:
    rclpy.spin_once(node, timeout_sec=0.1)
paused_counts = {name: len(rows) for name, rows in node.samples.items()}

control = subprocess.run(
    [
        "gz", "service", "-s", "/world/seapressure_extreme_pause/control",
        "--reqtype", "gz.msgs.WorldControl", "--reptype", "gz.msgs.Boolean",
        "--timeout", "5000", "--req", "pause: false",
    ],
    text=True, capture_output=True,
)
(out / "unpause_service.txt").write_text(control.stdout + control.stderr)
if control.returncode != 0:
    raise RuntimeError(f"unpause failed: {control.stdout}{control.stderr}")

deadline = time.monotonic() + 90
while time.monotonic() < deadline:
    if all(len(node.samples[name]) >= wanted for name, (_topic, _z, wanted) in conditions.items()):
        break
    rclpy.spin_once(node, timeout_sec=0.1)

result = {"paused_wall_window_s": 5.0, "paused_counts": paused_counts, "conditions": {}}
assert all(count == 0 for count in paused_counts.values()), paused_counts

for name, (_topic, z, wanted) in conditions.items():
    rows = node.samples[name]
    assert len(rows) >= wanted, (name, len(rows), wanted)
    pressure_values = [row["pressure"] for row in rows]
    variance_values = [row["variance"] for row in rows]
    stamps = [row["stamp_s"] for row in rows]
    intervals = [b - a for a, b in zip(stamps, stamps[1:])]
    expected = 101.325 + abs(z) * 9.80638
    assert all(math.isfinite(value) for value in pressure_values)
    assert max(pressure_values) == min(pressure_values)
    assert math.isclose(pressure_values[0], expected, abs_tol=1e-6)
    assert all(interval > 0 for interval in intervals)
    result["conditions"][name] = {
        "z_m": z,
        "sample_count": len(rows),
        "first_stamp_s": stamps[0],
        "last_stamp_s": stamps[-1],
        "simulated_span_s": stamps[-1] - stamps[0],
        "median_interval_s": statistics.median(intervals),
        "observed_pressure": pressure_values[0],
        "expected_implemented_formula": expected,
        "variance_values": sorted(set(variance_values)),
        "frame_id_values": sorted(set(row["frame_id"] for row in rows)),
        "all_finite": True,
        "pressure_constant": True,
        "stamps_strictly_increasing": True,
    }

result["assertions"] = {
    "no_messages_while_paused_for_5_wall_seconds": True,
    "surface_10000_frames_completed": True,
    "extreme_plus_minus_1000m_matches_implemented_abs_z_formula": True,
    "all_values_finite_and_timestamps_monotonic": True,
}
(out / "results.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result, indent=2))
node.destroy_node()
rclpy.shutdown()
