#!/usr/bin/env python3
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
import rclpy
from marine_acoustic_msgs.msg import ProjectedSonarImage
from rclpy.node import Node
from rclpy.qos import (
    DurabilityPolicy,
    HistoryPolicy,
    QoSProfile,
    ReliabilityPolicy,
)
from sensor_msgs.msg import PointCloud2


OUT = Path(sys.argv[1])
CASE = sys.argv[2]
BACKEND = sys.argv[3]
EXPECTED_RANGE = float(sys.argv[4])
SAMPLE_COUNT = int(sys.argv[5]) if len(sys.argv) > 5 else 3

POINT_TOPIC = "/sensor/multibeam_sonar/point_cloud"
RAW_TOPIC = "/sensor/multibeam_sonar/sonar_image_raw"


def stamp_tuple(msg):
    return int(msg.header.stamp.sec), int(msg.header.stamp.nanosec)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def point_array(msg: PointCloud2):
    fields = {field.name: field for field in msg.fields}
    required = ["x", "y", "z", "intensity", "ring"]
    if any(name not in fields for name in required):
        raise RuntimeError(f"missing PointCloud2 fields: {sorted(fields)}")
    dtype = np.dtype(
        {
            "names": required,
            "formats": ["<f4", "<f4", "<f4", "<f4", "<u2"],
            "offsets": [fields[name].offset for name in required],
            "itemsize": int(msg.point_step),
        }
    )
    raw = bytes(msg.data)
    records = np.ndarray(
        shape=(int(msg.height), int(msg.width)),
        dtype=dtype,
        buffer=raw,
        strides=(int(msg.row_step), int(msg.point_step)),
    )
    xyz = np.stack([records["x"], records["y"], records["z"]], axis=-1).copy()
    intensity = records["intensity"].copy()
    ring = records["ring"].copy()
    return raw, xyz, intensity, ring


class Capture(Node):
    def __init__(self):
        super().__init__(f"sonar_equivalence_{CASE}_{BACKEND}")
        self.point_rows = []
        self.raw_rows = []
        self.point_seen = set()
        self.raw_seen = set()
        self.first = {}

        reliable = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
        )
        transient = QoSProfile(
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
        )
        self.create_subscription(PointCloud2, POINT_TOPIC, self.on_point, reliable)
        self.create_subscription(ProjectedSonarImage, RAW_TOPIC, self.on_raw, transient)

    def on_point(self, msg):
        stamp = stamp_tuple(msg)
        if stamp in self.point_seen or len(self.point_rows) >= SAMPLE_COUNT:
            return
        self.point_seen.add(stamp)
        raw, xyz, intensity, ring = point_array(msg)
        radial = np.linalg.norm(xyz, axis=2)
        finite = np.isfinite(radial)
        center = (int(msg.height) // 2, int(msg.width) // 2)
        row = {
            "sample": len(self.point_rows) + 1,
            "stamp_sec": stamp[0],
            "stamp_nanosec": stamp[1],
            "width": int(msg.width),
            "height": int(msg.height),
            "frame_id": msg.header.frame_id,
            "data_sha256": digest(raw),
            "finite_point_count": int(finite.sum()),
            "center_xyz_m": [float(v) for v in xyz[center]],
            "center_range_m": float(radial[center]),
            "center_error_m": float(radial[center] - EXPECTED_RANGE),
            "radial_mean_m": float(np.nanmean(radial)),
            "radial_median_m": float(np.nanmedian(radial)),
            "radial_min_m": float(np.nanmin(radial)),
            "radial_max_m": float(np.nanmax(radial)),
            "intensity_mean": float(np.nanmean(intensity)),
            "intensity_std": float(np.nanstd(intensity)),
            "intensity_min": float(np.nanmin(intensity)),
            "intensity_max": float(np.nanmax(intensity)),
        }
        self.point_rows.append(row)
        if "point_xyz" not in self.first:
            self.first["point_xyz"] = xyz
            self.first["point_intensity"] = intensity
            self.first["point_ring"] = ring
        print(json.dumps({"point": row}))

    def on_raw(self, msg):
        stamp = stamp_tuple(msg)
        if stamp in self.raw_seen or len(self.raw_rows) >= SAMPLE_COUNT:
            return
        self.raw_seen.add(stamp)
        beams = int(msg.image.beam_count)
        ranges = np.asarray(msg.ranges, dtype=np.float32)
        raw = bytes(msg.image.data)
        values = np.frombuffer(raw, dtype="<f4")
        expected_size = beams * len(ranges)
        if values.size != expected_size:
            raise RuntimeError(f"raw layout mismatch: {values.size} != {expected_size}")
        matrix = values.reshape(len(ranges), beams).copy()
        center_beam = beams // 2
        profile = matrix[:, center_beam]
        finite_indices = np.flatnonzero(np.isfinite(profile))
        if finite_indices.size == 0:
            raise RuntimeError("raw center profile has no finite values")
        finite_values = profile[finite_indices]
        peak_local = int(np.argmax(finite_values))
        peak_index = int(finite_indices[peak_local])
        expected_index = int(np.argmin(np.abs(ranges - EXPECTED_RANGE)))
        expected_value = float(profile[expected_index])
        expected_rank = 1 + int(np.sum(finite_values > expected_value))
        row = {
            "sample": len(self.raw_rows) + 1,
            "stamp_sec": stamp[0],
            "stamp_nanosec": stamp[1],
            "beam_count": beams,
            "range_bin_count": int(len(ranges)),
            "frame_id": msg.header.frame_id,
            "data_sha256": digest(raw),
            "peak_range_m": float(ranges[peak_index]),
            "peak_error_m": float(ranges[peak_index] - EXPECTED_RANGE),
            "peak_value_db": float(profile[peak_index]),
            "peak_index": peak_index,
            "expected_bin_range_m": float(ranges[expected_index]),
            "expected_bin_value_db": expected_value,
            "expected_bin_rank": expected_rank,
            "matrix_mean": float(np.nanmean(matrix)),
            "matrix_std": float(np.nanstd(matrix)),
            "matrix_min": float(np.nanmin(matrix)),
            "matrix_max": float(np.nanmax(matrix)),
        }
        self.raw_rows.append(row)
        if "raw_sonar" not in self.first:
            self.first["raw_sonar"] = matrix
            self.first["ranges"] = ranges.copy()
        print(json.dumps({"raw": row}))


OUT.mkdir(parents=True, exist_ok=True)
rclpy.init()
node = Capture()
deadline = time.time() + 600
while time.time() < deadline:
    if len(node.point_rows) >= SAMPLE_COUNT and len(node.raw_rows) >= SAMPLE_COUNT:
        break
    rclpy.spin_once(node, timeout_sec=1.0)

if len(node.point_rows) != SAMPLE_COUNT or len(node.raw_rows) != SAMPLE_COUNT:
    raise TimeoutError(
        f"captured point={len(node.point_rows)}/{SAMPLE_COUNT}, "
        f"raw={len(node.raw_rows)}/{SAMPLE_COUNT}"
    )

np.savez_compressed(OUT / "first_frame_arrays.npz", **node.first)
summary = {
    "case": CASE,
    "backend": BACKEND,
    "expected_range_m": EXPECTED_RANGE,
    "sample_count": SAMPLE_COUNT,
    "point_topic": POINT_TOPIC,
    "raw_topic": RAW_TOPIC,
    "point_frames": node.point_rows,
    "raw_frames": node.raw_rows,
    "scope": (
        "Controlled simulated geometry/backend comparison only; not a general "
        "acoustic-accuracy or real-material validation."
    ),
}
(OUT / "capture_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
node.destroy_node()
rclpy.shutdown()
