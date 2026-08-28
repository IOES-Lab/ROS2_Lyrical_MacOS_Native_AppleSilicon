#!/usr/bin/env python3
import json
import os
import time

import rclpy
from geometry_msgs.msg import TwistStamped
from nav_msgs.msg import Odometry
from rclpy.node import Node

NAMES = ("rexrov5", "rexrov15")


def stamp_s(msg):
    return msg.header.stamp.sec + msg.header.stamp.nanosec * 1e-9


class Capture(Node):
    def __init__(self):
        super().__init__("ocean_depth_force_capture")
        self.odom = {name: [] for name in NAMES}
        self.current = {name: [] for name in NAMES}
        for name in NAMES:
            self.create_subscription(
                Odometry, f"/model/{name}/odometry",
                lambda msg, n=name: self.odom[n].append(msg), 10)
            self.create_subscription(
                TwistStamped, f"/model/{name}/ocean_current",
                lambda msg, n=name: self.current[n].append(msg), 10)

    def spin_until(self, predicate, timeout):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=0.05)
            if predicate(): return
        raise TimeoutError("capture condition not reached")


def odom_row(msg):
    return {
        "sim_time_s": stamp_s(msg),
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


def current_row(msg):
    return {
        "sim_time_s": stamp_s(msg),
        "linear_mps": [msg.twist.linear.x, msg.twist.linear.y, msg.twist.linear.z],
    }


def main():
    out = os.environ["OUT"]
    os.makedirs(out, exist_ok=True)
    rclpy.init(); node = Capture()
    node.spin_until(lambda: all(node.odom[n] and node.current[n] for n in NAMES), 120)
    start = {n: node.odom[n][-1] for n in NAMES}
    current_start = {n: node.current[n][-1] for n in NAMES}
    current_index = {n: len(node.current[n]) - 1 for n in NAMES}
    target = max(stamp_s(m) for m in start.values()) + 6.0
    node.spin_until(lambda: all(stamp_s(node.odom[n][-1]) >= target for n in NAMES), 180)
    end = {n: node.odom[n][-1] for n in NAMES}

    result = {"models": {}, "scope": "Simultaneous two-depth functional response; not coefficient or real-ocean accuracy."}
    for n in NAMES:
        a, b = odom_row(start[n]), odom_row(end[n])
        currents = node.current[n][current_index[n]:]
        dt = b["sim_time_s"] - a["sim_time_s"]
        result["models"][n] = {
            "current_start": current_row(current_start[n]),
            "current_end": current_row(currents[-1]),
            "current_x_min_mps": min(m.twist.linear.x for m in currents),
            "current_x_max_mps": max(m.twist.linear.x for m in currents),
            "start": a, "end": b,
            "duration_s": dt,
            "displacement_m": {
                axis: b["position_m"][axis] - a["position_m"][axis]
                for axis in ("x", "y", "z")
            },
            "average_x_velocity_mps": (b["position_m"]["x"] - a["position_m"]["x"]) / dt,
        }
    with open(os.path.join(out, "results.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2); f.write("\n")
    print(json.dumps(result, indent=2))
    node.destroy_node(); rclpy.shutdown()


if __name__ == "__main__": main()
