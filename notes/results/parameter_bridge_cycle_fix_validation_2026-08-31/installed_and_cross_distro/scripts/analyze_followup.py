#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def text(path):
    return (ROOT / path).read_text().strip()

assert text("lyrical_normal_install/build_rc.txt") == "0"
assert "PREFIX=/home/docker/bridge_normal_ws/install/ros_gz_bridge" in text(
    "lyrical_normal_install/install_prefix.txt"
)
assert text("lyrical_normal_install/runtime_matrix/summary.txt").splitlines()[:2] == [
    "topic=8/8", "service=1/1"
]
repeat_rows = text("lyrical_normal_install/repeat_teardown_valid/summary.tsv").splitlines()
assert len(repeat_rows) == 10
assert all(row.endswith("\tPASS\t0") for row in repeat_rows)

for distro, token in (("jazzy", "jazzy"), ("kilted", "kilted")):
    base = f"cross_distro/{distro}"
    assert text(f"{base}/build_rc.txt") == "0"
    topic = f"{base}/topic_matrix" if distro == "jazzy" else base
    assert text(f"{topic}/topic_bridge_rc.txt") == "0"
    assert text(f"{topic}/topic_bridge_escalation.txt") == "NONE"
    assert token + "-g2r" in text(f"{topic}/g2r_string.txt")
    assert "42.25" in text(f"{topic}/g2r_double.txt")
    assert "x: 4.0" in text(f"{topic}/g2r_pose.txt")
    assert token + "-r2g" in text(f"{topic}/r2g_string.txt")
    assert "84.5" in text(f"{topic}/r2g_double.txt")
    assert "linear" in text(f"{topic}/r2g_twist.txt")

assert text("cross_distro/jazzy/service_matrix/summary.txt").splitlines() == [
    "service_matrix=1/1", "service_bridge_exit=0", "gz_server_exit=0"
]
assert "success=True" in text("cross_distro/jazzy/service_matrix/pause_response.txt")
assert "success=True" in text("cross_distro/jazzy/service_matrix/unpause_response.txt")
assert text("cross_distro/kilted/summary.txt").splitlines() == [
    "build=PASS", "topic_matrix=8/8", "service_matrix=1/1",
    "topic_exit=0", "service_exit=0"
]
assert "success=True" in text("cross_distro/kilted/pause_response.txt")
assert "success=True" in text("cross_distro/kilted/unpause_response.txt")

humble = text("humble_arm64/summary.txt").splitlines()
assert humble == [
    "build=PASS", "topic_matrix=8/8", "service_matrix=1/1",
    "topic_exit=0", "service_exit=0"
]
amd64 = text("jazzy_amd64_emulated/summary.txt").splitlines()
assert amd64 == [
    "runtime=PASS", "topic_matrix=8/8", "service_matrix=1/1",
    "topic_exit=0", "service_exit=0"
]
expanded = text("expanded_matrix/summary.txt").splitlines()
assert expanded == [
    "ordinary_layout_runtime=PASS", "topic_conversions=24/24",
    "unique_topic_type_pairs=13", "service_factories=4/4",
    "topic_exit=0", "service_exit=0"
]

workspace = json.loads(text("user_workspace_install/summary.json"))
assert workspace["candidate_source_files_match_pr"] == "4/4"
assert workspace["build"]["result"] == "PASS"
assert workspace["parameter_bridge"]["generated_factory_pairs_instantiated"] == "73/73"
assert workspace["parameter_bridge"]["generated_gz_to_ros_payload_assertions"] == "73/73"
assert workspace["parameter_bridge"]["ordered_generated_ros_to_gz_payload_assertions"] == "73/73"
assert workspace["parameter_bridge"]["ordered_ros_to_gz_bridge_rc"] == 0
assert workspace["parameter_bridge"]["repeated_payload_runs"] == "5/5"
assert workspace["parameter_bridge"]["lifecycle_runs"] == "11/11"
assert workspace["component_bridge"]["ordered_payload_assertions"] == "3/3"
assert workspace["component_bridge"]["ordered_service_assertions"] == "1/1"
assert workspace["component_bridge"]["test_helper_rc"] == 134
assert workspace["component_bridge"]["bridge_node_rc"] == 139

pr = json.loads(text("upstream_submission/pr_status_after_dco_fix.json"))
assert pr["mergeable"] == "MERGEABLE"
assert pr["commits"][0]["oid"] == "86910a32efe28624ec489ae5ce5cdcfb5a2ec500"
assert any(
    check.get("name") == "DCO" and check.get("conclusion") == "SUCCESS"
    for check in pr["statusCheckRollup"]
)

data = json.loads(text("summary.json"))
assert data["cross_distribution"]["humble"]["source_overlay_build"] == "PASS"
assert data["cross_distribution"]["jazzy"]["topic_matrix"] == "8/8"
assert data["cross_distribution"]["kilted"]["service_matrix"] == "1/1"
assert data["cross_distribution"]["jazzy_amd64_emulated"]["topic_matrix"] == "8/8"
assert data["ordinary_layout"]["topic_conversions"] == "24/24"
assert data["actual_user_workspace"]["generated_topic_payloads_each_direction"] == "73/73"
assert data["actual_user_workspace"]["ordered_bridge_rc"] == 0
assert data["separate_component_teardown"]["bridge_node_rc"] == 139
review = json.loads(text("upstream_review/summary.json"))
assert review["total_matches"] == 0
assert review["issue_template_count"] == 0
assert review["pull_request_template_present"] is False
assert data["upstream_submission"]["focused_issue_pr_searches"] == 8
assert data["upstream_submission"]["duplicate_matches"] == 0
assert data["upstream_submission"]["issue"] == "https://github.com/gazebosim/ros_gz/issues/951"
assert data["upstream_submission"]["pull_request"] == "https://github.com/gazebosim/ros_gz/pull/952"
print(json.dumps(data, indent=2))
