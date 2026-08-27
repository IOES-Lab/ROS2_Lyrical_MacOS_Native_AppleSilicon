#!/usr/bin/env python3
"""Exercise the DAVE USBL ROS interface and retain machine-readable evidence."""

import argparse
import json
import math
import os
import time

import rclpy
from dave_interfaces.msg import Location
from rclpy.node import Node
from std_msgs.msg import String


NS = "/USBL"
TRANSCEIVER = f"{NS}/transceiver_manufacturer_168"
LOCATION_TOPIC = f"{TRANSCEIVER}/transponder_location"
CARTESIAN_TOPIC = f"{TRANSCEIVER}/transponder_location_cartesian"
MODE_TOPIC = f"{TRANSCEIVER}/interrogation_mode"
CHANNEL_TOPIC = f"{TRANSCEIVER}/channel_switch"
COMMON_PING_TOPIC = f"{NS}/common_interrogation_ping"
INDIVIDUAL_PING_TOPIC = {
    1: f"{NS}/transponder_manufacturer_1/individual_interrogation_ping",
    2: f"{NS}/transponder_manufacturer_2/individual_interrogation_ping",
}

EXPECTED_CARTESIAN = {
    1: (3.0, 3.0, 0.5),
    2: (6.0, 6.0, 0.5),
}


def msg_dict(msg):
    return {
        "transponder_id": int(msg.transponder_id),
        "x": float(msg.x),
        "y": float(msg.y),
        "z": float(msg.z),
    }


class MatrixNode(Node):
    def __init__(self):
        super().__init__("usbl_direct_validation")
        self.phase = "startup"
        self.spherical = []
        self.cartesian = []
        self.create_subscription(Location, LOCATION_TOPIC, self._on_spherical, 10)
        self.create_subscription(Location, CARTESIAN_TOPIC, self._on_cartesian, 10)
        self.mode_pub = self.create_publisher(String, MODE_TOPIC, 10)
        self.channel_pub = self.create_publisher(String, CHANNEL_TOPIC, 10)
        self.common_pub = self.create_publisher(String, COMMON_PING_TOPIC, 10)
        self.individual_pub = {
            key: self.create_publisher(String, topic, 10)
            for key, topic in INDIVIDUAL_PING_TOPIC.items()
        }

    def _on_spherical(self, msg):
        self.spherical.append({"phase": self.phase, "wall_time": time.time(), **msg_dict(msg)})

    def _on_cartesian(self, msg):
        self.cartesian.append({"phase": self.phase, "wall_time": time.time(), **msg_dict(msg)})

    def publish_text(self, pub, value):
        msg = String()
        msg.data = value
        pub.publish(msg)

    def spin_for(self, seconds, tick=None):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if tick is not None:
                tick()
            rclpy.spin_once(self, timeout_sec=0.05)


def wait_for_graph(node, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        graph = {
            "location_publishers": node.count_publishers(LOCATION_TOPIC),
            "cartesian_publishers": node.count_publishers(CARTESIAN_TOPIC),
            "mode_subscribers": node.count_subscribers(MODE_TOPIC),
            "common_ping_subscribers": node.count_subscribers(COMMON_PING_TOPIC),
            "individual_1_subscribers": node.count_subscribers(INDIVIDUAL_PING_TOPIC[1]),
            "individual_2_subscribers": node.count_subscribers(INDIVIDUAL_PING_TOPIC[2]),
            "channel_subscribers": node.count_subscribers(CHANNEL_TOPIC),
        }
        if (
            graph["location_publishers"] >= 1
            and graph["cartesian_publishers"] >= 1
            and graph["mode_subscribers"] >= 3
            and graph["common_ping_subscribers"] >= 2
            and graph["individual_1_subscribers"] >= 1
            and graph["individual_2_subscribers"] >= 1
            and graph["channel_subscribers"] >= 1
        ):
            return graph
        node.spin_for(0.2)
    return graph


def messages_for_phase(messages, phase):
    return [row for row in messages if row["phase"] == phase]


def run_common(node, duration, samples_per_id):
    phase = "common"
    node.phase = phase
    for _ in range(10):
        node.publish_text(node.mode_pub, "common")
        node.spin_for(0.1)
    start_s = len(node.spherical)
    start_c = len(node.cartesian)
    deadline = time.monotonic() + duration
    next_ping = 0.0
    while time.monotonic() < deadline:
        now = time.monotonic()
        if now >= next_ping:
            node.publish_text(node.common_pub, "ping")
            next_ping = now + 0.25
        rclpy.spin_once(node, timeout_sec=0.05)
        new_s = node.spherical[start_s:]
        new_c = node.cartesian[start_c:]
        if all(sum(row["transponder_id"] == i for row in new_s) >= samples_per_id for i in (1, 2)) and all(
            sum(row["transponder_id"] == i for row in new_c) >= samples_per_id for i in (1, 2)
        ):
            break
    return {
        "spherical": node.spherical[start_s:],
        "cartesian": node.cartesian[start_c:],
    }


def run_individual(node, transponder_id, duration, samples_per_id):
    phase = f"individual_{transponder_id}"
    node.phase = phase
    for _ in range(10):
        node.publish_text(node.channel_pub, str(transponder_id))
        node.spin_for(0.1)
    # Drain mode-change traffic before attributing location messages to this phase.
    node.spin_for(0.5)
    start_s = len(node.spherical)
    start_c = len(node.cartesian)
    deadline = time.monotonic() + duration
    next_ping = 0.0
    while time.monotonic() < deadline:
        now = time.monotonic()
        if now >= next_ping:
            node.publish_text(node.individual_pub[transponder_id], "ping")
            next_ping = now + 0.25
        rclpy.spin_once(node, timeout_sec=0.05)
        new_s = node.spherical[start_s:]
        new_c = node.cartesian[start_c:]
        if (
            sum(row["transponder_id"] == transponder_id for row in new_s) >= samples_per_id
            and sum(row["transponder_id"] == transponder_id for row in new_c) >= samples_per_id
        ):
            break
    return {
        "spherical": node.spherical[start_s:],
        "cartesian": node.cartesian[start_c:],
    }


def summarize_phase(phase_data, allowed_ids):
    result = {
        "spherical_count": len(phase_data["spherical"]),
        "cartesian_count": len(phase_data["cartesian"]),
        "spherical_ids": sorted({row["transponder_id"] for row in phase_data["spherical"]}),
        "cartesian_ids": sorted({row["transponder_id"] for row in phase_data["cartesian"]}),
        "unexpected_ids": sorted(
            ({row["transponder_id"] for row in phase_data["spherical"]}
             | {row["transponder_id"] for row in phase_data["cartesian"]})
            - set(allowed_ids)
        ),
        "maximum_cartesian_axis_error_m": None,
        "maximum_spherical_cartesian_reconstruction_error_m": None,
    }
    cart_errors = []
    for row in phase_data["cartesian"]:
        expected = EXPECTED_CARTESIAN.get(row["transponder_id"])
        if expected:
            cart_errors.extend(abs(row[key] - expected[i]) for i, key in enumerate(("x", "y", "z")))
    if cart_errors:
        result["maximum_cartesian_axis_error_m"] = max(cart_errors)

    reconstruction_errors = []
    for row in phase_data["spherical"]:
        bearing = math.radians(row["x"])
        distance = row["y"]
        elevation = math.radians(row["z"])
        reconstructed = (
            distance * math.cos(elevation) * math.cos(bearing),
            distance * math.cos(elevation) * math.sin(bearing),
            distance * math.sin(elevation),
        )
        expected = EXPECTED_CARTESIAN.get(row["transponder_id"])
        if expected:
            reconstruction_errors.extend(abs(reconstructed[i] - expected[i]) for i in range(3))
    if reconstruction_errors:
        result["maximum_spherical_cartesian_reconstruction_error_m"] = max(reconstruction_errors)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--samples-per-id", type=int, default=3)
    parser.add_argument("--skip-individual", action="store_true")
    args = parser.parse_args()

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    rclpy.init()
    node = MatrixNode()
    graph = wait_for_graph(node, args.timeout)
    phases = {}
    phases["common"] = run_common(node, args.timeout, args.samples_per_id)
    if not args.skip_individual:
        phases["individual_1"] = run_individual(node, 1, args.timeout, args.samples_per_id)
        phases["individual_2"] = run_individual(node, 2, args.timeout, args.samples_per_id)

    summary = {
        "graph": graph,
        "phases": {
            name: summarize_phase(data, (1, 2) if name == "common" else (int(name[-1]),))
            for name, data in phases.items()
        },
        "raw": phases,
        "expected_cartesian_m": {str(k): list(v) for k, v in EXPECTED_CARTESIAN.items()},
        "scope": (
            "Common and individual ROS trigger paths in the two-transponder tutorial geometry. "
            "This checks message routing and geometric self-consistency, not general acoustic accuracy."
        ),
    }
    with open(args.output, "w", encoding="utf-8") as stream:
        json.dump(summary, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print(json.dumps(summary, indent=2, sort_keys=True))
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
