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

data = json.loads(text("summary.json"))
assert data["cross_distribution"]["humble"]["build_runtime"] == "NOT RUN"
assert data["cross_distribution"]["jazzy"]["topic_matrix"] == "8/8"
assert data["cross_distribution"]["kilted"]["service_matrix"] == "1/1"
review = json.loads(text("upstream_review/summary.json"))
assert review["total_matches"] == 0
assert review["issue_template_count"] == 0
assert review["pull_request_template_present"] is False
assert data["upstream_readiness_review"]["focused_issue_pr_searches"] == 8
assert data["upstream_readiness_review"]["duplicate_matches"] == 0
print(json.dumps(data, indent=2))
