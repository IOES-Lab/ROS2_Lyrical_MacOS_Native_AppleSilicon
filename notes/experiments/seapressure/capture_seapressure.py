#!/usr/bin/env python3
"""Capture SeaPressure output for one condition and compare it against both hypotheses.

Writes summary.json holding, for every claim: what the implementation predicts,
what the competing explanation predicts, and what was observed. A condition whose
two predictions coincide is marked non-discriminating rather than counted as
evidence -- the `variance: 9.0` mistake of 2026-08-21 is the reason that flag exists.
"""

import argparse
import json
import math
import statistics
import sys
import time

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import FluidPressure
from geometry_msgs.msg import PointStamped

WARMUP = 10          # frames discarded before capture, as in the camera run
CAPTURE = 5          # frames kept; all must agree
TIMEOUT_S = 60.0
TOL = 1e-9


class Capture(Node):
    def __init__(self, pressure_topic, depth_topic):
        super().__init__("seapressure_capture")
        self.pressure = []
        self.depth = []
        self.create_subscription(FluidPressure, pressure_topic, self._on_pressure, 10)
        if depth_topic:
            self.create_subscription(PointStamped, depth_topic, self._on_depth, 10)

    def _on_pressure(self, msg):
        self.pressure.append({
            "stamp_s": msg.header.stamp.sec + msg.header.stamp.nanosec / 1e9,
            "frame_id": msg.header.frame_id,
            "fluid_pressure": msg.fluid_pressure,
            "variance": msg.variance,
        })

    def _on_depth(self, msg):
        self.depth.append({"x": msg.point.x, "y": msg.point.y, "z": msg.point.z})


def collect(node, want, want_depth):
    deadline = time.time() + TIMEOUT_S
    while time.time() < deadline:
        if len(node.pressure) >= want and (not want_depth or len(node.depth) >= 1):
            break
        rclpy.spin_once(node, timeout_sec=0.1)
    return len(node.pressure) >= want and (not want_depth or len(node.depth) >= 1)


def identical(samples, keys):
    """Return the list of keys that varied across samples."""
    return [k for k in keys if len({round(s[k], 12) for s in samples}) > 1]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--condition", required=True)
    p.add_argument("--namespace", required=True)
    p.add_argument("--topic", default="sea_pressure")
    p.add_argument("--z", type=float, required=True)
    p.add_argument("--standard-pressure", type=float, default=101.325)
    p.add_argument("--kpa-per-meter", type=float, default=9.80638)
    p.add_argument("--saturation", type=float, default=None,
                   help="value set in SDF; omit if the tag is absent")
    p.add_argument("--noise-sigma", type=float, default=None,
                   help="value set in SDF; omit if the tag is absent")
    p.add_argument("--update-rate", type=float, default=None,
                   help="configured update_rate; used to test whether the tag is applied")
    p.add_argument("--expect-depth-topic", action="store_true", default=False)
    p.add_argument("--expect-no-depth-topic", action="store_true", default=False)
    p.add_argument("--out", required=True)
    a = p.parse_args()

    if a.expect_depth_topic and a.expect_no_depth_topic:
        p.error("depth topic cannot be expected present and absent at the same time")

    base = f"model/{a.namespace}/{a.topic}"
    expected_depth_name = f"/{base}_depth"
    depth_topic = f"{base}_depth" if a.expect_depth_topic else None

    rclpy.init()
    node = Capture(base, depth_topic)
    ok = collect(node, WARMUP + CAPTURE, a.expect_depth_topic)
    got = list(node.pressure)
    got_depth = list(node.depth)
    graph_topics = {name for name, _types in node.get_topic_names_and_types()}
    node.destroy_node()
    rclpy.shutdown()

    result = {
        "condition": a.condition,
        "pressure_topic": base,
        "depth_topic": depth_topic,
        "z_m": a.z,
        "captured": len(got),
        "warmup_discarded": WARMUP,
    }

    if not ok:
        result["verdict"] = "NO DATA"
        result["note"] = f"fewer than {WARMUP + CAPTURE} messages within {TIMEOUT_S}s"
        json.dump(result, open(a.out, "w"), indent=2)
        print(f"[{a.condition}] NO DATA", file=sys.stderr)
        return 1

    kept = got[WARMUP:WARMUP + CAPTURE]
    varied = identical(kept, ["fluid_pressure", "variance"])
    result["frames"] = kept
    result["deterministic"] = not varied
    result["fields_that_varied"] = varied

    obs_p = kept[0]["fluid_pressure"]
    obs_v = kept[0]["variance"]

    # --- pressure -------------------------------------------------------
    depth = abs(a.z)
    impl = a.standard_pressure + depth * a.kpa_per_meter
    saturation_applied = min(impl, a.saturation) if a.saturation is not None else impl
    saturation_ignored = impl
    claim = "saturation" if a.saturation is not None else "formula"

    # a correct sensor would not add pressure above the surface
    signed = a.standard_pressure + (depth * a.kpa_per_meter if a.z < 0 else 0.0)

    result["pressure"] = {
        "claim": claim,
        "observed": obs_p,
        "predicted_from_source_as_implemented": impl,
        "predicted_if_saturation_applied": saturation_applied,
        "predicted_if_saturation_ignored": saturation_ignored,
        "predicted_if_abs_were_signed": signed,
        "matches_source_as_implemented": math.isclose(obs_p, impl, abs_tol=1e-6),
        "discriminating": not math.isclose(
            saturation_applied, saturation_ignored, abs_tol=1e-6),
        "pascal_expectation_if_units_were_correct": impl * 1000.0,
    }

    # --- variance -------------------------------------------------------
    default_sigma = 3.0
    v_ignored = default_sigma ** 2
    v_applied = (a.noise_sigma ** 2) if a.noise_sigma is not None else v_ignored
    result["variance"] = {
        "observed": obs_v,
        "predicted_if_noise_sigma_applied": v_applied,
        "predicted_if_noise_sigma_ignored": v_ignored,
        "discriminating": not math.isclose(v_applied, v_ignored, abs_tol=1e-12),
    }

    # --- inferred depth -------------------------------------------------
    if depth_topic:
        result["inferred_depth"] = {
            "observed": got_depth[-1] if got_depth else None,
            "predicted_abs_z": depth,
            "samples": len(got_depth),
            "topic_present_in_graph": expected_depth_name in graph_topics,
            "data_received": bool(got_depth),
        }
    else:
        result["inferred_depth"] = {
            "topic_present_in_graph": expected_depth_name in graph_topics,
            "expected_absent": a.expect_no_depth_topic,
            "note": "estimate_depth_on false; presence in the ROS graph would be a defect",
        }

    # --- update rate ----------------------------------------------------
    stamps = [sample["stamp_s"] for sample in kept]
    intervals = [b - a_ for a_, b in zip(stamps, stamps[1:])]
    configured_period = 1.0 / a.update_rate if a.update_rate else None
    median_interval = statistics.median(intervals) if intervals else None
    result["timing"] = {
        "configured_update_rate_hz": a.update_rate,
        "configured_period_s": configured_period,
        "observed_stamp_intervals_s": intervals,
        "observed_median_stamp_interval_s": median_interval,
        "matches_configured_period": (
            None if configured_period is None or median_interval is None
            else math.isclose(median_interval, configured_period, rel_tol=0.2, abs_tol=0.02)
        ),
    }

    json.dump(result, open(a.out, "w"), indent=2)
    print(f"[{a.condition}] pressure={obs_p} variance={obs_v} "
          f"deterministic={result['deterministic']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
