#!/usr/bin/env python3
"""Cross-check Mac and Docker SphericalCoords results."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


COMPARISON_TOLERANCE_M = 2e-9


def close(a: float, b: float, tolerance: float = COMPARISON_TOLERANCE_M) -> bool:
    return math.isclose(a, b, rel_tol=0.0, abs_tol=tolerance)


def compare(left, right) -> None:
    if isinstance(left, dict):
        assert left.keys() == right.keys()
        for key in left:
            if key != "platform":
                compare(left[key], right[key])
    elif isinstance(left, list):
        assert len(left) == len(right)
        for a, b in zip(left, right):
            compare(a, b)
    elif isinstance(left, float):
        if math.isnan(left):
            assert math.isnan(right)
        else:
            assert close(left, right)
    else:
        assert left == right


def numeric_differences(left, right):
    """Yield finite absolute numeric differences, ignoring platform labels."""
    if isinstance(left, dict):
        for key in left:
            if key != "platform":
                yield from numeric_differences(left[key], right[key])
    elif isinstance(left, list):
        for a, b in zip(left, right):
            yield from numeric_differences(a, b)
    elif isinstance(left, float) and math.isfinite(left) and math.isfinite(right):
        yield abs(left - right)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    mac = json.loads((root / "mac/results.json").read_text())
    docker = json.loads((root / "docker/results.json").read_text())
    compare(mac, docker)
    maximum_cross_platform_difference = max(numeric_differences(mac, docker))

    for platform in (mac, docker):
        assert platform["set_wiki_origin_success"] is True
        assert platform["restore_success"] is True
        for key in ("latitude_deg", "longitude_deg", "altitude"):
            assert close(
                platform["origin_after_set"][key],
                {
                    "latitude_deg": -24.71897669633431,
                    "longitude_deg": -46.515625,
                    "altitude": 100.0,
                }[key],
            )
            assert close(
                platform["restored_origin"][key],
                platform["initial_origin"][key],
            )
        assert platform["out_of_range_origin"]["service_success"] is True
        assert platform["non_finite_input"]["to_spherical_all_finite"] is False
        assert platform["non_finite_input"]["from_spherical_all_finite"] is False
        for row in platform["round_trips"]:
            assert max(abs(value) for value in row["error_m"].values()) < 2e-9

    actual = mac["round_trips"][1]["spherical"]
    wiki_back = mac["wiki_documented_spherical_converts_to_local"]
    summary = {
        "date": "2026-08-26",
        "verdict": "PARTIAL",
        "positive_path": {
            "all_four_services_available_with_installed_lib_path": True,
            "get_set_restore_pass": True,
            "round_trip_points_per_platform": 3,
            "maximum_round_trip_axis_error_m": max(
                abs(value)
                for result in (mac, docker)
                for row in result["round_trips"]
                for value in row["error_m"].values()
            ),
            "mac_docker_numerically_equivalent_within_2e-9": True,
            "maximum_mac_docker_numeric_difference": (
                maximum_cross_platform_difference
            ),
        },
        "wiki_discrepancies": {
            "world_origin_in_current_dave": mac["initial_origin"],
            "documented_transform_to_result": mac[
                "wiki_documented_spherical_for_local_100_200_3"
            ],
            "observed_transform_to_result": actual,
            "documented_result_converts_back_to_local": wiki_back,
        },
        "runtime_defects": {
            "mac_default_generated_plugin_path_misses_installed_library": True,
            "docker_default_services_present_via_install_lib_on_ld_library_path": True,
            "non_finite_inputs_return_non_finite_success_payloads": True,
            "out_of_range_origin_is_accepted": mac["out_of_range_origin"],
        },
        "limitations": [
            "Three finite local points and one configured origin were used.",
            "The optional-empty fallback identified in source was not triggered; NaN propagated instead of becoming zero.",
            "Geodesic accuracy was not compared with an independent geodesy implementation or survey data.",
        ],
        "scope": (
            "Four ROS services, three finite round trips per platform, exact "
            "Wiki example, NaN and out-of-range-origin behavior, and default "
            "plugin discovery."
        ),
        "default_loading": {
            "mac": {
                "custom_services_present": False,
                "generated_gz_path_suffix": "lib/dave_ros_gz_plugins/",
                "actual_library_suffix": "lib/libSphericalCoords.dylib",
                "manual_actual_lib_path_required": True,
            },
            "docker": {
                "custom_services_present": True,
                "generated_gz_path_suffix": "lib/dave_ros_gz_plugins/",
                "actual_library_suffix": "lib/libSphericalCoords.so",
                "install_lib_on_ld_library_path": True,
                "manual_gz_path_override_required": False,
            },
        },
        "excluded_attempts": [
            {
                "path": "01_wiki_quickstart_mac",
                "reason": (
                    "Restricted harness denied local sockets and GUI screens; "
                    "not used for the plugin verdict."
                ),
            }
        ],
        "evidence": [
            "02_wiki_headless_default_path_mac",
            "03_fixed_path_mac",
            "04_controlled_matrix",
            "05_default_path_docker",
            "source",
        ],
    }
    (root / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
