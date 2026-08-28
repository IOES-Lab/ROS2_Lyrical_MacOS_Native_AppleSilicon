#!/usr/bin/env python3
import json
import math
import os
import subprocess
import time

import rclpy
from dave_interfaces.msg import Location
from rclpy.node import Node
from std_msgs.msg import String

NS = "/USBLGAP"
LOCATION = f"{NS}/transceiver_168/transponder_location_cartesian"
MODE = f"{NS}/transceiver_168/interrogation_mode"
CHANNEL = f"{NS}/transceiver_168/channel_switch"
PING = {
    1: f"{NS}/transponder_1/individual_interrogation_ping",
    2: f"{NS}/transponder_2/individual_interrogation_ping",
}


class Probe(Node):
    def __init__(self):
        super().__init__("usbl_gap_probe")
        self.received = []
        self.create_subscription(Location, LOCATION, self._on_location, 10)
        self.mode_pub = self.create_publisher(String, MODE, 10)
        self.channel_pub = self.create_publisher(String, CHANNEL, 10)
        self.ping_pub = {i: self.create_publisher(String, topic, 10) for i, topic in PING.items()}

    def _on_location(self, msg):
        self.received.append({
            "wall_monotonic_s": time.monotonic(),
            "transponder_id": int(msg.transponder_id),
            "x": float(msg.x), "y": float(msg.y), "z": float(msg.z),
        })

    @staticmethod
    def _text(value):
        msg = String(); msg.data = value; return msg

    def spin_for(self, duration):
        deadline = time.monotonic() + duration
        while time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=0.05)

    def select(self, transponder_id):
        for _ in range(12):
            self.mode_pub.publish(self._text("individual"))
            self.channel_pub.publish(self._text(str(transponder_id)))
            self.spin_for(0.05)
        self.spin_for(0.3)

    def query(self, transponder_id, timeout=4.0):
        self.select(transponder_id)
        start_index = len(self.received)
        start = time.monotonic()
        self.ping_pub[transponder_id].publish(self._text("ping"))
        deadline = start + timeout
        while time.monotonic() < deadline:
            rclpy.spin_once(self, timeout_sec=0.01)
            for row in self.received[start_index:]:
                if row["transponder_id"] == transponder_id:
                    return {**row, "latency_s": row["wall_monotonic_s"] - start}
        raise TimeoutError(f"no location for transponder {transponder_id}")


def set_pose(name, x, y=0.0, z=0.0):
    request = f'name: "{name}" position: {{x: {x}, y: {y}, z: {z}}} orientation: {{w: 1}}'
    cmd = [
        "gz", "service", "-s", "/world/usbl_gap/set_pose",
        "--reqtype", "gz.msgs.Pose", "--reptype", "gz.msgs.Boolean",
        "--timeout", "5000", "--req", request,
    ]
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=10)
    return {"command": cmd, "returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr}


def wait_graph(node, timeout=30.0):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        graph = {
            "location_publishers": node.count_publishers(LOCATION),
            "mode_subscribers": node.count_subscribers(MODE),
            "channel_subscribers": node.count_subscribers(CHANNEL),
            "ping1_subscribers": node.count_subscribers(PING[1]),
            "ping2_subscribers": node.count_subscribers(PING[2]),
        }
        if min(graph.values()) >= 1:
            return graph
        node.spin_for(0.1)
    raise TimeoutError(graph)


def main():
    out = os.environ["OUT"]
    os.makedirs(out, exist_ok=True)
    if os.path.exists(os.path.join(out, "results.json")):
        raise FileExistsError(os.path.join(out, "results.json"))
    rclpy.init()
    node = Probe()
    graph = wait_graph(node)

    near_before = [node.query(1) for _ in range(3)]
    move = set_pose("sphere_near", 9.0)
    node.spin_for(0.5)
    near_after = [node.query(1) for _ in range(3)]

    below = [node.query(2) for _ in range(3)]
    move_latency = set_pose("sphere_latency", 1541.0)
    node.spin_for(0.5)
    above = [node.query(2) for _ in range(3)]

    result = {
        "graph": graph,
        "moving_target": {
            "before": near_before,
            "set_pose": move,
            "after": near_after,
            "median_x_before_m": sorted(r["x"] for r in near_before)[1],
            "median_x_after_m": sorted(r["x"] for r in near_after)[1],
        },
        "travel_time_quantization": {
            "sound_speed_mps": 1540.0,
            "below_one_second_distance_m": 1539.0,
            "above_one_second_distance_m": 1541.0,
            "below": below,
            "set_pose": move_latency,
            "above": above,
            "median_latency_below_s": sorted(r["latency_s"] for r in below)[1],
            "median_latency_above_s": sorted(r["latency_s"] for r in above)[1],
        },
        "scope": "Moving-target geometry and the implemented wall-clock delay around the one-second sound-travel boundary; not general acoustic accuracy.",
    }
    with open(os.path.join(out, "results.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2); f.write("\n")
    print(json.dumps(result, indent=2))
    node.destroy_node(); rclpy.shutdown()


if __name__ == "__main__":
    main()
