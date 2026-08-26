import hashlib
import json
import sys
import time
from pathlib import Path

import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image

variant = sys.argv[1]
output_dir = Path(sys.argv[2])
output_dir.mkdir(parents=True, exist_ok=True)
topic = f"/{variant}/simulated_image"

class CaptureNode(Node):
    def __init__(self):
        super().__init__(f"capture_{variant}")
        self.received = 0
        self.frames = []
        self.subscription = self.create_subscription(
            Image, topic, self.callback, 10
        )

    def callback(self, msg):
        self.received += 1
        if self.received <= 10 or len(self.frames) >= 5:
            return

        data = np.frombuffer(bytes(msg.data), dtype=np.uint8)
        rows = data.reshape(msg.height, msg.step)
        frame = rows[:, : msg.width * 3].reshape(msg.height, msg.width, 3).copy()

        index = len(self.frames) + 1
        np.save(output_dir / f"frame_{index:02d}.npy", frame)
        rgb = frame[:, :, ::-1]
        ppm_path = output_dir / f"frame_{index:02d}.ppm"
        with ppm_path.open("wb") as stream:
            stream.write(f"P6\n{msg.width} {msg.height}\n255\n".encode())
            stream.write(rgb.tobytes())

        center = frame[msg.height // 2, msg.width // 2]
        means = frame.reshape(-1, 3).mean(axis=0)
        digest = hashlib.sha256(frame.tobytes()).hexdigest()

        self.frames.append({
            "index": index,
            "stamp_sec": int(msg.header.stamp.sec),
            "stamp_nanosec": int(msg.header.stamp.nanosec),
            "width": int(msg.width),
            "height": int(msg.height),
            "encoding": msg.encoding,
            "step": int(msg.step),
            "data_length": len(msg.data),
            "center_bgr": [int(x) for x in center],
            "mean_bgr": [float(x) for x in means],
            "sha256": digest,
        })

        print(json.dumps(self.frames[-1]))

rclpy.init()
node = CaptureNode()
deadline = time.monotonic() + 180

while rclpy.ok() and len(node.frames) < 5 and time.monotonic() < deadline:
    rclpy.spin_once(node, timeout_sec=1.0)

if len(node.frames) != 5:
    node.destroy_node()
    rclpy.shutdown()
    raise TimeoutError(f"Captured {len(node.frames)}/5 frames from {topic}")

summary = {
    "variant": variant,
    "topic": topic,
    "channel_order": "BGR",
    "ignored_initial_frames": 10,
    "captured_frames": len(node.frames),
    "frames": node.frames,
}

(output_dir / "summary.json").write_text(
    json.dumps(summary, indent=2) + "\n"
)

print(json.dumps(summary, indent=2))
print(f"Saved: {output_dir}")

node.destroy_node()
rclpy.shutdown()
