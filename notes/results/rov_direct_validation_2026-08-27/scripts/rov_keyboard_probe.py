#!/usr/bin/env python3
import json
import sys
import time

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Joy


out_path = sys.argv[1]
record = None


class Probe(Node):
    def __init__(self):
        super().__init__("codex_keyboard_joy_probe")
        self.create_subscription(Joy, "/keyboard/joy", self.callback, 10)

    def callback(self, msg):
        global record
        axes = list(msg.axes)
        buttons = list(msg.buttons)
        # Ignore the periodic neutral heartbeat and capture the first
        # key-induced non-zero command.
        if any(abs(v) > 1e-6 for v in axes) or any(buttons):
            record = {
                "frame_id": msg.header.frame_id,
                "axes": axes,
                "buttons": buttons,
            }


rclpy.init()
node = Probe()
deadline = time.monotonic() + 30
while time.monotonic() < deadline and record is None:
    rclpy.spin_once(node, timeout_sec=0.1)
node.destroy_node()
rclpy.shutdown()

if record is None:
    raise TimeoutError("No non-neutral /keyboard/joy message received")

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(record, f, indent=2)
    f.write("\n")
print(json.dumps(record, indent=2))
