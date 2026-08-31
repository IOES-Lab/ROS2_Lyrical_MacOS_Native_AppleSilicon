#!/usr/bin/env python3
"""Recompute BlueROV runtime verdicts from captured message signatures."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VARIANTS = (
    "bluerov2",
    "bluerov2_heavy",
    "bluerov2_heavy_multibeam_sonar",
)
SIGNATURES = {
    "imu": r"^orientation:",
    "magnetometer": r"^magnetic_field:",
    "camera": r"^height: [1-9][0-9]*\nwidth: [1-9][0-9]*$",
    "odometry": r"^child_frame_id:",
}


def read(path: Path) -> str:
    return path.read_text(errors="replace") if path.exists() else ""


summaries = []
for variant in VARIANTS:
    directory = ROOT / "runtime" / variant
    summary = {
        "variant": variant,
        "ros_message_received": {
            label: bool(re.search(pattern, read(directory / f"{label}.txt"), re.M))
            for label, pattern in SIGNATURES.items()
        },
        "default_path_gz_imu_received": bool(
            re.search(
                r"^entity_name:.*imu_sensor",
                read(directory / "default_imu_gz.txt"),
                re.M,
            )
        ),
        "sonar_point_513x301": bool(
            re.search(
                r"^height: 301\nwidth: 513$",
                read(directory / "sonar_point.txt"),
                re.M,
            )
        ),
        "sonar_raw_513x399": bool(
            re.search(
                r"^  beam_count: 513$",
                read(directory / "sonar_raw.txt"),
                re.M,
            )
            and "length: 399" in read(directory / "sonar_raw.txt")
        ),
        "runtime_segfault": bool(
            re.search(
                r"Stack trace|exit code 139|Segmentation fault",
                read(directory / "launch.log"),
            )
        ),
    }
    (directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    summaries.append(summary)

(ROOT / "runtime_summary.json").write_text(json.dumps(summaries, indent=2) + "\n")
print(json.dumps(summaries, indent=2))
