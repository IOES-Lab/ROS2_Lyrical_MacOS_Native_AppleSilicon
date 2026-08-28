#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image

variant = sys.argv[1]
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

class Capture(Node):
    def __init__(self):
        super().__init__(f"capture_{variant}")
        self.seen = 0
        self.row = None
        self.sub = self.create_subscription(
            Image, f"/{variant}/simulated_image", self.callback, 10
        )

    def callback(self, msg):
        self.seen += 1
        if self.seen <= 5 or self.row is not None:
            return
        array = np.frombuffer(bytes(msg.data), dtype=np.uint8)
        array = array.reshape(msg.height, msg.step)[:, : msg.width * 3]
        array = array.reshape(msg.height, msg.width, 3).copy()
        np.save(out / "frame.npy", array)
        self.row = {
            "variant": variant,
            "width": msg.width,
            "height": msg.height,
            "encoding": msg.encoding,
            "step": msg.step,
            "data_length": len(msg.data),
            "center_bgr": [int(v) for v in array[msg.height // 2, msg.width // 2]],
            "mean_bgr": [float(v) for v in array.reshape(-1, 3).mean(axis=0)],
            "sha256": hashlib.sha256(array.tobytes()).hexdigest(),
        }

rclpy.init()
node = Capture()
deadline = time.monotonic() + 50
while rclpy.ok() and node.row is None and time.monotonic() < deadline:
    rclpy.spin_once(node, timeout_sec=1)
if node.row is None:
    raise TimeoutError(f"no image for {variant}; callbacks={node.seen}")
(out / "result.json").write_text(json.dumps(node.row, indent=2) + "\n")
print(json.dumps(node.row))
node.destroy_node()
rclpy.shutdown()
