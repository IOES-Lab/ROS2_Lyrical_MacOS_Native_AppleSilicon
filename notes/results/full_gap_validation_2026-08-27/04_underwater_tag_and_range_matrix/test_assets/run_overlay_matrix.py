#!/usr/bin/env python3
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root = Path(sys.argv[1]).resolve()
variants = json.loads((root / "test_assets/variants.json").read_text())
positions = {
    "uc_range_1m": "3",
    "uc_range_2m": "2",
    "uc_range_4m": "0",
    "uc_range_6m": "-2",
}
run_root = root / "overlay_run2"
if run_root.exists():
    raise FileExistsError(f"refusing existing {run_root}")
run_root.mkdir()

for variant in variants:
    out = run_root / variant
    out.mkdir()
    env = os.environ.copy()
    env["ROS_LOG_DIR"] = str(out / "ros_logs")
    Path(env["ROS_LOG_DIR"]).mkdir()
    command = [
        "ros2", "launch", "dave_demos", "dave_sensor.launch.py",
        f"namespace:={variant}",
        "world_name:=camera_parameter_validation",
        "paused:=false",
        f"x:={positions.get(variant, '0')}",
        "y:=0", "z:=0", "roll:=0", "pitch:=0", "yaw:=0",
        "gui:=true", "headless:=true", "debug:=false",
    ]
    print(f"=== {variant} ===", flush=True)
    with (out / "launch.log").open("wb") as log:
        launch = subprocess.Popen(
            command,
            stdout=log,
            stderr=subprocess.STDOUT,
            env=env,
            start_new_session=True,
        )
        try:
            time.sleep(5)
            capture = subprocess.run(
                [sys.executable, str(root / "test_assets/capture_one.py"), variant, str(out)],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
                timeout=70,
            )
            (out / "capture.log").write_text(capture.stdout)
            if capture.returncode != 0:
                raise RuntimeError(f"capture failed for {variant}: {capture.stdout}")
            print(capture.stdout.strip(), flush=True)
        finally:
            for sig, delay in ((signal.SIGINT, 3), (signal.SIGTERM, 2), (signal.SIGKILL, 0)):
                try:
                    os.killpg(launch.pid, sig)
                except (ProcessLookupError, PermissionError):
                    break
                time.sleep(delay)
            try:
                launch.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
    subprocess.run(["ros2", "daemon", "stop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["ros2", "daemon", "start"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)

rows = {
    path.parent.name: json.loads(path.read_text())
    for path in sorted(run_root.glob("*/result.json"))
}
assert len(rows) == len(variants), (len(rows), len(variants))

base = rows["uc_no_effect"]["center_bgr"]
assert rows["uc_att_r"]["center_bgr"][0] < base[0] and rows["uc_att_r"]["center_bgr"][1:] == base[1:]
assert rows["uc_att_g"]["center_bgr"][1] < base[1] and rows["uc_att_g"]["center_bgr"][0] == base[0] and rows["uc_att_g"]["center_bgr"][2] == base[2]
assert rows["uc_att_b"]["center_bgr"][2] < base[2] and rows["uc_att_b"]["center_bgr"][:2] == base[:2]

background = rows["uc_bg_base"]["center_bgr"]
assert rows["uc_bg_r"]["center_bgr"][0] > background[0] and rows["uc_bg_r"]["center_bgr"][1:] == background[1:]
assert rows["uc_bg_g"]["center_bgr"][1] > background[1] and rows["uc_bg_g"]["center_bgr"][0] == background[0] and rows["uc_bg_g"]["center_bgr"][2] == background[2]
assert rows["uc_bg_b"]["center_bgr"][2] > background[2] and rows["uc_bg_b"]["center_bgr"][:2] == background[:2]

ranges = [rows[f"uc_range_{distance}m"]["center_bgr"] for distance in (1, 2, 4, 6)]
range_checks = [
    all(ranges[index][channel] > ranges[index + 1][channel] for index in range(3))
    for channel in range(3)
]
result = {
    "rows": rows,
    "assertions": {
        "attenuation_tags_change_same_bgr_array_index_only": True,
        "background_tags_change_same_bgr_array_index_only": True,
        "range_strictly_decreases_by_bgr_channel": range_checks,
    },
    "range_center_bgr": dict(zip(("1m", "2m", "4m", "6m"), ranges)),
}
(run_root / "results.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result["assertions"], indent=2))
print(json.dumps(result["range_center_bgr"], indent=2))
