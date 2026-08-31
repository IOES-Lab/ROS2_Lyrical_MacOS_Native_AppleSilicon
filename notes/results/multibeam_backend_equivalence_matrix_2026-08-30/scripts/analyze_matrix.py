#!/usr/bin/env python3
import csv
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
CASES = {
    "plane_2m_dark": 2.0,
    "plane_4m_dark": 4.0,
    "plane_4m_bright": 4.0,
    "plane_7m_dark": 7.0,
    "sphere_4m_bright": 4.0,
    "cylinder_4m_bright": 4.0,
}


def metric(diff):
    values = np.asarray(diff, dtype=np.float64)
    values = values[np.isfinite(values)]
    if not values.size:
        return {"count": 0, "mae": None, "rmse": None, "max_abs": None}
    return {
        "count": int(values.size),
        "mae": float(np.mean(np.abs(values))),
        "rmse": float(np.sqrt(np.mean(np.square(values)))),
        "max_abs": float(np.max(np.abs(values))),
    }


def median(values):
    return float(np.median(np.asarray(values, dtype=np.float64)))


rows = []
details = {}
for case, expected in CASES.items():
    backend_data = {}
    for backend in ("cpu", "wgpu"):
        path = RESULTS / case / backend
        summary = json.loads((path / "capture_summary.json").read_text())
        arrays = np.load(path / "first_frame_arrays.npz")
        backend_data[backend] = (summary, arrays)

    cpu_summary, cpu = backend_data["cpu"]
    wgpu_summary, wgpu = backend_data["wgpu"]
    if cpu["point_xyz"].shape != wgpu["point_xyz"].shape:
        raise RuntimeError(f"{case}: point shape mismatch")
    if cpu["raw_sonar"].shape != wgpu["raw_sonar"].shape:
        raise RuntimeError(f"{case}: raw shape mismatch")

    cpu_xyz = cpu["point_xyz"].astype(np.float64)
    wgpu_xyz = wgpu["point_xyz"].astype(np.float64)
    both = np.all(np.isfinite(cpu_xyz), axis=2) & np.all(np.isfinite(wgpu_xyz), axis=2)
    xyz_diff = (wgpu_xyz - cpu_xyz)[both]
    cpu_radial = np.linalg.norm(cpu_xyz[both], axis=1)
    wgpu_radial = np.linalg.norm(wgpu_xyz[both], axis=1)
    intensity_diff = (
        wgpu["point_intensity"].astype(np.float64)
        - cpu["point_intensity"].astype(np.float64)
    )[both]
    raw_diff = (
        wgpu["raw_sonar"].astype(np.float64)
        - cpu["raw_sonar"].astype(np.float64)
    )

    cpu_points = cpu_summary["point_frames"]
    wgpu_points = wgpu_summary["point_frames"]
    cpu_raw = cpu_summary["raw_frames"]
    wgpu_raw = wgpu_summary["raw_frames"]
    detail = {
        "expected_range_m": expected,
        "point_shape": list(cpu["point_xyz"].shape),
        "raw_shape": list(cpu["raw_sonar"].shape),
        "common_finite_points": int(both.sum()),
        "point_xyz_wgpu_minus_cpu": metric(xyz_diff),
        "point_radial_wgpu_minus_cpu_m": metric(wgpu_radial - cpu_radial),
        "point_intensity_wgpu_minus_cpu": metric(intensity_diff),
        "raw_first_observed_frame_wgpu_minus_cpu": metric(raw_diff),
        "raw_frame_alignment_limit": (
            "The first observed CPU and WGPU frames are not guaranteed to share "
            "the same internal frameIndex; raw-array errors are descriptive, not "
            "a same-random-state equivalence proof."
        ),
        "cpu": {
            "center_range_median": median([r["center_range_m"] for r in cpu_points]),
            "center_error_median": median([r["center_error_m"] for r in cpu_points]),
            "raw_peak_range_median": median([r["peak_range_m"] for r in cpu_raw]),
            "raw_peak_error_median": median([r["peak_error_m"] for r in cpu_raw]),
            "expected_bin_ranks": [r["expected_bin_rank"] for r in cpu_raw],
            "unique_point_hashes": len({r["data_sha256"] for r in cpu_points}),
            "unique_raw_hashes": len({r["data_sha256"] for r in cpu_raw}),
        },
        "wgpu": {
            "center_range_median": median([r["center_range_m"] for r in wgpu_points]),
            "center_error_median": median([r["center_error_m"] for r in wgpu_points]),
            "raw_peak_range_median": median([r["peak_range_m"] for r in wgpu_raw]),
            "raw_peak_error_median": median([r["peak_error_m"] for r in wgpu_raw]),
            "expected_bin_ranks": [r["expected_bin_rank"] for r in wgpu_raw],
            "unique_point_hashes": len({r["data_sha256"] for r in wgpu_points}),
            "unique_raw_hashes": len({r["data_sha256"] for r in wgpu_raw}),
        },
    }
    details[case] = detail
    rows.append(
        {
            "case": case,
            "expected_range_m": expected,
            "common_finite_points": detail["common_finite_points"],
            "point_xyz_rmse": detail["point_xyz_wgpu_minus_cpu"]["rmse"],
            "point_xyz_max_abs": detail["point_xyz_wgpu_minus_cpu"]["max_abs"],
            "intensity_rmse": detail["point_intensity_wgpu_minus_cpu"]["rmse"],
            "raw_first_frame_rmse": detail["raw_first_observed_frame_wgpu_minus_cpu"]["rmse"],
            "cpu_center_error_m": detail["cpu"]["center_error_median"],
            "wgpu_center_error_m": detail["wgpu"]["center_error_median"],
            "cpu_raw_peak_error_m": detail["cpu"]["raw_peak_error_median"],
            "wgpu_raw_peak_error_m": detail["wgpu"]["raw_peak_error_median"],
            "cpu_expected_rank_max": max(detail["cpu"]["expected_bin_ranks"]),
            "wgpu_expected_rank_max": max(detail["wgpu"]["expected_bin_ranks"]),
        }
    )

material = {}
for backend in ("cpu", "wgpu"):
    dark = np.load(RESULTS / "plane_4m_dark" / backend / "first_frame_arrays.npz")
    bright = np.load(RESULTS / "plane_4m_bright" / backend / "first_frame_arrays.npz")
    material[backend] = {
        "point_xyz": metric(bright["point_xyz"].astype(float) - dark["point_xyz"].astype(float)),
        "point_intensity": metric(
            bright["point_intensity"].astype(float) - dark["point_intensity"].astype(float)
        ),
        "raw_first_observed_frame": metric(
            bright["raw_sonar"].astype(float) - dark["raw_sonar"].astype(float)
        ),
        "interpretation_limit": (
            "Visual diffuse color is not a calibrated acoustic reflectivity "
            "coefficient, and observed frames are not frameIndex-aligned."
        ),
    }

verdict = {
    "case_count": len(CASES),
    "backends": ["cpu", "wgpu_llvmpipe"],
    "details": details,
    "visual_material_control": material,
    "scope": (
        "Controlled Gazebo geometry comparison. Point-cloud geometry and raw "
        "peak placement are evaluated separately. This is not real-material or "
        "general acoustic-accuracy validation."
    ),
}
(ROOT / "summary.json").write_text(json.dumps(verdict, indent=2) + "\n")
with (ROOT / "summary.csv").open("w", newline="") as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
print(json.dumps(verdict, indent=2))
