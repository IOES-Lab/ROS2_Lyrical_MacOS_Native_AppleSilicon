#!/usr/bin/env python3
import json
import math
import sys
import time
from pathlib import Path

import rclpy
from dave_interfaces.msg import StratifiedCurrentDatabase
from geometry_msgs.msg import TwistStamped
from rclpy.node import Node


class Capture(Node):
    def __init__(self, out: Path):
        super().__init__("capture_tidal_model_path")
        self.out = out
        self.samples = {"no_tide": [], "tide": []}
        self.database = None
        self.create_subscription(
            TwistStamped,
            "/model/probe_no_tide/ocean_current",
            lambda msg: self.record("no_tide", msg),
            100,
        )
        self.create_subscription(
            TwistStamped,
            "/model/probe_tide/ocean_current",
            lambda msg: self.record("tide", msg),
            100,
        )
        self.create_subscription(
            StratifiedCurrentDatabase,
            "/hydrodynamics/stratified_current_velocity_topic_database",
            self.record_database,
            10,
        )

    def record(self, key, msg):
        if len(self.samples[key]) >= 200:
            return
        self.samples[key].append(
            {
                "stamp_s": msg.header.stamp.sec + msg.header.stamp.nanosec / 1e9,
                "x": msg.twist.linear.x,
                "y": msg.twist.linear.y,
                "z": msg.twist.linear.z,
            }
        )

    def record_database(self, msg):
        if self.database is not None:
            return
        self.database = {
            "tideconstituents": bool(msg.tideconstituents),
            "m2": [msg.m2_amp, msg.m2_phase, msg.m2_speed],
            "s2": [msg.s2_amp, msg.s2_phase, msg.s2_speed],
            "n2": [msg.n2_amp, msg.n2_phase, msg.n2_speed],
            "ebb_direction_deg": msg.ebb_direction,
            "flood_direction_deg": msg.flood_direction,
            "world_start_time": [
                msg.world_start_time_year,
                msg.world_start_time_month,
                msg.world_start_time_day,
                msg.world_start_time_hour,
                msg.world_start_time_minute,
            ],
            "depth_count": len(msg.depths),
        }


def stats(rows):
    result = {"count": len(rows)}
    for axis in ("x", "y", "z"):
        values = [r[axis] for r in rows]
        result[axis] = {
            "min": min(values),
            "max": max(values),
            "range": max(values) - min(values),
            "unique_12dp": len({round(v, 12) for v in values}),
        }
    result["all_finite"] = all(
        math.isfinite(r[a]) for r in rows for a in ("x", "y", "z")
    )
    return result


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    rclpy.init()
    node = Capture(out)
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        rclpy.spin_once(node, timeout_sec=0.2)
        if (
            node.database is not None
            and len(node.samples["no_tide"]) >= 200
            and len(node.samples["tide"]) >= 200
        ):
            break
    summary = {
        "database": node.database,
        "no_tide": stats(node.samples["no_tide"]),
        "tide": stats(node.samples["tide"]),
        "paired_equal_12dp": all(
            all(round(a[k], 12) == round(b[k], 12) for k in ("x", "y", "z"))
            for a, b in zip(node.samples["no_tide"], node.samples["tide"])
        ),
    }
    (out / "samples.json").write_text(json.dumps(node.samples, indent=2) + "\n")
    (out / "database.json").write_text(json.dumps(node.database, indent=2) + "\n")
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))
    node.destroy_node()
    rclpy.shutdown()
    if node.database is None or min(map(len, node.samples.values())) < 200:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
