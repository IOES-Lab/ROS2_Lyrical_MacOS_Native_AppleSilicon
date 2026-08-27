#!/usr/bin/env python3
import asyncio
import json
import sys
import threading
import time

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Joy
import websockets


out_path = sys.argv[1]
received = threading.Event()
record = {}


class Probe(Node):
    def __init__(self):
        super().__init__("codex_ws_joy_probe")
        self.create_subscription(Joy, "/joy", self.callback, 10)

    def callback(self, msg):
        record.update(
            {
                "frame_id": msg.header.frame_id,
                "axes": list(msg.axes),
                "buttons": list(msg.buttons),
            }
        )
        received.set()


async def send_payload():
    payload = {
        "id": "codex_runtime_probe",
        "axes": [0.25, -0.8, 0.5, 0.0],
        "buttons": [1, 0, 1, 0],
    }
    deadline = time.monotonic() + 20
    last_error = None
    while time.monotonic() < deadline:
        try:
            async with websockets.connect("ws://127.0.0.1:8765") as ws:
                # Give DDS endpoint discovery time after the subscriber starts,
                # then send repeatedly so the test does not depend on one
                # best-effort discovery race.
                await asyncio.sleep(2.0)
                for _ in range(20):
                    await ws.send(json.dumps(payload))
                    await asyncio.sleep(0.1)
                return
        except Exception as exc:
            last_error = repr(exc)
            await asyncio.sleep(0.25)
    raise RuntimeError(f"websocket server unavailable: {last_error}")


rclpy.init()
node = Probe()

thread = threading.Thread(target=lambda: asyncio.run(send_payload()), daemon=True)
thread.start()

deadline = time.monotonic() + 30
while time.monotonic() < deadline and not received.is_set():
    rclpy.spin_once(node, timeout_sec=0.1)

thread.join(timeout=1)
node.destroy_node()
rclpy.shutdown()

if not received.is_set():
    raise TimeoutError("No /joy message received from websocket bridge")

expected = {
    "frame_id": "browser_gamepad:codex_runtime_probe",
    "axes": [0.25, -0.8, 0.5, 0.0],
    "buttons": [1, 0, 1, 0],
}
record["semantic_match"] = (
    record.get("frame_id") == expected["frame_id"]
    and record.get("buttons") == expected["buttons"]
    and len(record.get("axes", [])) == len(expected["axes"])
    and all(abs(a - b) < 1e-6 for a, b in zip(record["axes"], expected["axes"]))
)
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(record, f, indent=2)
    f.write("\n")

print(json.dumps(record, indent=2))
if not record["semantic_match"]:
    raise AssertionError("Joy message did not semantically match websocket payload")
