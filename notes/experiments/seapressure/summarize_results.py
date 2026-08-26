#!/usr/bin/env python3
"""Verify the Mac/Docker SeaPressure matrix and write its canonical summary.

The script trusts neither platform's precomputed interpretation. It re-reads
each per-condition JSON, checks the discriminating observations, and compares
the two platforms field by field before emitting summary.json.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


CONDITIONS = [
    "sp_baseline",
    "sp_depth10",
    "sp_above10",
    "sp_saturation",
    "sp_stdpress",
    "sp_kpa",
    "sp_noise",
    "sp_topic",
    "sp_nodepth",
    "sp_rate",
]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def close(a: float, b: float, tol: float = 1e-9) -> bool:
    return math.isclose(a, b, rel_tol=0.0, abs_tol=tol)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    platforms = {
        "mac": root / "05_parameter_matrix",
        "docker": root / "06_docker_validation",
    }

    rows: dict[str, dict] = {}
    for condition in CONDITIONS:
        rows[condition] = {}
        for platform, base in platforms.items():
            summary_path = base / condition / "summary.json"
            data = load(summary_path)
            assert data["condition"] == condition
            assert data["captured"] >= 15
            assert data["deterministic"] is True
            assert (base / condition / "spawn.exit_code").read_text().strip() == "0"
            assert (base / condition / "capture.exit_code").read_text().strip() == "0"
            rows[condition][platform] = data

        mac = rows[condition]["mac"]
        docker = rows[condition]["docker"]
        assert close(mac["pressure"]["observed"], docker["pressure"]["observed"])
        assert close(mac["variance"]["observed"], docker["variance"]["observed"])
        assert (
            mac["inferred_depth"]["topic_present_in_graph"]
            == docker["inferred_depth"]["topic_present_in_graph"]
        )

    expected_pressure = {
        "sp_baseline": 101.325,
        "sp_depth10": 199.3888,
        "sp_above10": 199.3888,
        "sp_saturation": 199.3888,
        "sp_stdpress": 200.0,
        "sp_kpa": 111.325,
        "sp_noise": 101.325,
        "sp_topic": 101.325,
        "sp_nodepth": 199.3888,
        "sp_rate": 101.325,
    }
    for condition, expected in expected_pressure.items():
        for platform in platforms:
            assert close(rows[condition][platform]["pressure"]["observed"], expected, 1e-6)

    for platform in platforms:
        assert rows["sp_saturation"][platform]["pressure"]["predicted_if_saturation_applied"] == 50
        assert rows["sp_saturation"][platform]["pressure"]["observed"] == 199.3888
        assert rows["sp_noise"][platform]["variance"]["observed"] == 9.0
        assert rows["sp_noise"][platform]["variance"]["predicted_if_noise_sigma_applied"] == 0.015129
        assert rows["sp_nodepth"][platform]["inferred_depth"]["topic_present_in_graph"] is False
        assert rows["sp_rate"][platform]["timing"]["matches_configured_period"] is False
        assert close(
            rows["sp_rate"][platform]["timing"]["observed_median_stamp_interval_s"],
            0.001,
            1e-9,
        )

    docker_gz = {}
    for condition in CONDITIONS:
        condition_dir = platforms["docker"] / condition
        assert (condition_dir / "gz_capture.exit_code").read_text().strip() == "0"
        sample = (condition_dir / "gz_sample.txt").read_text()
        assert "pressure:" in sample and "variance:" in sample
        docker_gz[condition] = sample.strip()

    mac_gz = (root / "07_mac_gz_transport_retest" / "gz_sample.txt").read_text().strip()
    assert "pressure: 101.325" in mac_gz and "variance: 9" in mac_gz

    compact = {}
    for condition in CONDITIONS:
        compact[condition] = {}
        for platform in platforms:
            data = rows[condition][platform]
            compact[condition][platform] = {
                "fluid_pressure": data["pressure"]["observed"],
                "variance": data["variance"]["observed"],
                "deterministic_five_kept_frames": data["deterministic"],
                "depth_topic_present": data["inferred_depth"]["topic_present_in_graph"],
                "depth_sample": data["inferred_depth"].get("observed"),
                "median_stamp_interval_s": data["timing"]["observed_median_stamp_interval_s"],
                "frame_id_values": sorted({frame["frame_id"] for frame in data["frames"]}),
            }

    result = {
        "date": "2026-08-26",
        "verdict": "PARTIAL",
        "platforms": ["macOS Apple Silicon / ROS 2 Lyrical / Gazebo Jetty", "Docker ARM64 / ROS 2 Lyrical / Gazebo Jetty"],
        "conditions": compact,
        "cross_platform": {
            "all_ten_pressure_values_equal": True,
            "all_ten_variance_values_equal": True,
            "depth_topic_presence_equal": True,
            "gazebo_transport_sampled": {"mac": ["sp_baseline"], "docker": CONDITIONS},
        },
        "runtime_confirmed": {
            "ros_pascal_field_receives_kpa_sized_values": True,
            "surface_value": 101.325,
            "depth_minus_10m_value": 199.3888,
            "depth_plus_10m_value": 199.3888,
            "absolute_z_is_used_above_and_below_origin": True,
            "inferred_depth_matches_absolute_z_at_0_and_plus_minus_10m": True,
            "saturation_50_is_ignored_observed": 199.3888,
            "noise_sigma_0p123_is_ignored_observed_variance": 9.0,
            "noise_sigma_if_applied_variance": 0.015129,
            "update_rate_2hz_is_ignored_observed_median_period_s": {"mac": 0.001, "docker": 0.001},
            "standard_pressure_override_200_observed": 200.0,
            "kpa_per_meter_override_1_observed_at_10m": 111.325,
            "custom_topic_override_works": True,
            "estimate_depth_false_suppresses_depth_topic": True,
            "all_kept_pressure_frames_deterministic": True,
            "ros_frame_id_empty_on_both_platforms": True,
            "gazebo_transport_baseline": {"mac": mac_gz, "docker": docker_gz["sp_baseline"]},
        },
        "limitations": [
            "Controlled static probes only; maximum absolute Z was 10 m.",
            "No comparison with a physical pressure sensor or real ocean data.",
            "Five kept frames per condition demonstrate deterministic output in these runs, not a long-duration statistical guarantee.",
            "The meaning intended for variance=9.0 while no noise is applied cannot be inferred from runtime output.",
            "Above-origin behavior is measured relative to a controlled world whose origin represents the surface; other world conventions were not tested.",
        ],
        "invalid_attempt": {
            "path": "invalid_duplicate_tag_and_cleanup_attempt",
            "reason": "The first full-matrix script duplicated parameter tags and failed to stop prior worlds, so its results are excluded.",
        },
    }
    (root / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
