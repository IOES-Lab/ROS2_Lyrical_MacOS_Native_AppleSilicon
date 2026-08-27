#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text())


paths = {
    "mac_controlled": "01_controlled_mac/results.json",
    "mac_old_quickstart": "02_wiki_quickstart_mac/results.json",
    "mac_paused": "03_paused_mac/results.json",
    "mac_sigma_zero": "04_sigma_zero_mac/results.json",
    "mac_corrected_launcher": "05_corrected_world_launch_mac/results.json",
    "docker_controlled": "docker/01_controlled_docker/results.json",
    "docker_old_quickstart": "docker/02_wiki_quickstart_docker/results.json",
    "docker_paused": "docker/03_paused_docker/results.json",
    "docker_sigma_zero": "docker/04_sigma_zero_docker/results.json",
    "docker_corrected_launcher": "docker/05_corrected_world_launch_docker/results.json",
}
data = {name: load(path) for name, path in paths.items()}

controlled_names = ("mac_controlled", "docker_controlled")
for name in controlled_names:
    phases = data[name]["phases"]
    assert phases["common"]["spherical_count"] == 6
    assert phases["common"]["cartesian_count"] == 6
    assert phases["common"]["spherical_ids"] == [1, 2]
    assert phases["common"]["cartesian_ids"] == [1, 2]
    assert phases["individual_1"]["spherical_ids"] == [1]
    assert phases["individual_1"]["cartesian_ids"] == [1]
    assert phases["individual_2"]["spherical_ids"] == [2]
    assert phases["individual_2"]["cartesian_ids"] == [2]
    assert not phases["common"]["unexpected_ids"]
    assert not phases["individual_1"]["unexpected_ids"]
    assert not phases["individual_2"]["unexpected_ids"]

for name in ("mac_paused", "docker_paused"):
    common = data[name]["phases"]["common"]
    assert common["spherical_count"] == 0
    assert common["cartesian_count"] == 0
    graph = data[name]["graph"]
    assert graph["location_publishers"] == 1
    assert graph["common_ping_subscribers"] == 2

for name in ("mac_corrected_launcher", "docker_corrected_launcher"):
    common = data[name]["phases"]["common"]
    assert common["spherical_count"] == 6
    assert common["cartesian_count"] == 6
    assert common["spherical_ids"] == [1, 2]
    assert common["cartesian_ids"] == [1, 2]

for name in ("mac_old_quickstart", "docker_old_quickstart"):
    common = data[name]["phases"]["common"]
    assert common["spherical_count"] == 6
    assert common["cartesian_count"] == 6

mac_old_log = (ROOT / "02_wiki_quickstart_mac/launch.log").read_text()
docker_old_log = (ROOT / "docker/02_wiki_quickstart_docker/launch.log").read_text()
assert "description/usbl/model.sdf" in mac_old_log
assert "description/usbl/model.sdf" in docker_old_log

for relative in (
    "05_corrected_world_launch_mac/launch.log",
    "docker/05_corrected_world_launch_docker/launch.log",
):
    log = (ROOT / relative).read_text()
    assert "description/usbl/model.sdf" not in log

docker_sigma_log = (ROOT / "docker/04_sigma_zero_docker/server.log").read_text()
docker_sigma_exit = int((ROOT / "docker/04_sigma_zero_docker/gz_exit_code.txt").read_text())
assert "_M_stddev > _RealType(0)" in docker_sigma_log
assert docker_sigma_exit == 134
mac_zero = data["mac_sigma_zero"]["phases"]["common"]
assert mac_zero["spherical_ids"] == [1, 2]
assert mac_zero["cartesian_ids"] == [1, 2]

positive_sigma_errors = []
for name in (
    "mac_controlled",
    "mac_old_quickstart",
    "mac_corrected_launcher",
    "docker_controlled",
    "docker_old_quickstart",
    "docker_corrected_launcher",
):
    for phase in data[name]["phases"].values():
        value = phase.get("maximum_cartesian_axis_error_m")
        if value is not None:
            positive_sigma_errors.append(value)

summary = {
    "date": "2026-08-27",
    "verdict": "FUNCTIONAL PASS WITH REQUIRED WORKAROUNDS",
    "dave_commit": (ROOT / "source/dave_commit.txt").read_text().strip(),
    "tested_platforms": [
        "macOS arm64, ROS 2 Lyrical, Gazebo Jetty",
        "Docker Linux arm64, ROS 2 Lyrical, Gazebo Jetty",
    ],
    "positive_sigma_static_geometry": {
        "sigma": 0.0001,
        "controlled_platforms": list(controlled_names),
        "common_path": "6 spherical + 6 Cartesian samples per platform; IDs 1 and 2",
        "individual_path": "3 spherical + 3 Cartesian samples per selected ID per platform; no cross-channel IDs",
        "maximum_observed_cartesian_axis_error_m": max(positive_sigma_errors),
        "scope": "Tutorial static geometry and routing only; not general acoustic or travel-time accuracy.",
    },
    "old_wiki_quickstart": {
        "command_family": "dave_sensor.launch.py namespace:=usbl world_name:=usbl_tutorial",
        "mac_output": True,
        "docker_output": True,
        "defect": "The launcher also repeatedly tries to spawn nonexistent dave_sensor_models/description/usbl/model.sdf.",
    },
    "corrected_quickstart": {
        "command": "ros2 launch dave_demos dave_world.launch.py world_name:=usbl_tutorial",
        "mac_common_output": True,
        "docker_common_output": True,
        "nonexistent_model_spawn_error": False,
    },
    "paused_state": {
        "mac_graph_endpoints_present": True,
        "docker_graph_endpoints_present": True,
        "mac_output_samples": 0,
        "docker_output_samples": 0,
        "cause_from_source": "Both USBL PostUpdate methods call rclcpp::spin_some only while the simulation is unpaused.",
    },
    "sigma_zero": {
        "mac_libcpp": "accepted; both transponders produced finite output",
        "mac_maximum_cartesian_axis_error_m": mac_zero["maximum_cartesian_axis_error_m"],
        "docker_libstdcpp": "Gazebo server aborted on first ping",
        "docker_exit_code": docker_sigma_exit,
        "portability_conclusion": "sigma=0 behavior is platform-dependent; a plugin-level guard is required.",
    },
    "limitations": [
        "Three samples per transponder and trigger path in the controlled positive-sigma runs.",
        "Static tutorial geometry only; no moving transceiver or transponders.",
        "No independent acoustic propagation or travel-time ground truth.",
        "The DAVE workspaces were based on commit 6aef91c and were not pristine; controlled test worlds were kept outside the DAVE checkout.",
        "The sigma=0 Mac success does not make zero sigma portable because Docker/libstdc++ aborts.",
    ],
}
(ROOT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps(summary, indent=2))
