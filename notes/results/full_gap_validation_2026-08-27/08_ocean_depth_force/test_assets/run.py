#!/usr/bin/env python3
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "run3_fixed_depth"
WORLD = ROOT / "test_assets/ocean_depth_force_fixed_depth.world"


def run(cmd, *, timeout=60, check=True, log=None):
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
    if log:
        Path(log).write_text(proc.stdout + proc.stderr)
    if check and proc.returncode:
        raise RuntimeError({"cmd": cmd, "returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr})
    return proc


def service_list():
    return run(["ros2", "service", "list"], timeout=15, check=False).stdout.splitlines()


def main():
    if OUT.exists(): raise FileExistsError(OUT)
    OUT.mkdir(parents=True)
    server_log = open(OUT / "server.log", "w")
    bridge = None
    bridge_log = None
    server = subprocess.Popen(
        ["gz", "sim", "-s", "-r", str(WORLD)],
        stdout=server_log, stderr=subprocess.STDOUT, text=True,
        start_new_session=True,
    )
    (OUT / "server_pid.txt").write_text(f"pid={server.pid}\npgid={os.getpgid(server.pid)}\n")
    try:
        required = "/hydrodynamics/set_stratified_current_velocity"
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            if required in service_list(): break
            if server.poll() is not None: raise RuntimeError(f"server exited {server.returncode}")
            time.sleep(1)
        else: raise TimeoutError(required)
        (OUT / "service_list.txt").write_text("\n".join(service_list()) + "\n")

        calls = []
        for layer in range(12):
            velocity = 0.0 if layer <= 1 else 1.5
            req = f"{{layer: {layer}, velocity: {velocity}, horizontal_angle: 0.0, vertical_angle: 0.0}}"
            proc = run([
                "ros2", "service", "call", required,
                "dave_interfaces/srv/SetStratifiedCurrentVelocity", req,
            ], timeout=30)
            calls.append({"layer": layer, "velocity": velocity, "output": proc.stdout})
        (OUT / "layer_service_calls.json").write_text(json.dumps(calls, indent=2) + "\n")

        spawn = []
        specs = (("rexrov5", -5.0, -5.0), ("rexrov15", 5.0, -15.0))
        for name, y, z in specs:
            proc = run([
                "ros2", "run", "ros_gz_sim", "create",
                "-world", "ocp_depth_force_fixed_depth", "-file", str(ROOT / f"test_assets/{name}.sdf"),
                "-name", name, "-x", "0", "-y", str(y), "-z", str(z),
            ], timeout=90)
            spawn.append({"name": name, "output": proc.stdout + proc.stderr})
        (OUT / "spawn_results.json").write_text(json.dumps(spawn, indent=2) + "\n")

        bridge_log = open(OUT / "bridge.log", "w")
        bridge = subprocess.Popen([
            "ros2", "run", "ros_gz_bridge", "parameter_bridge",
            "/model/rexrov5/odometry@nav_msgs/msg/Odometry@gz.msgs.Odometry",
            "/model/rexrov15/odometry@nav_msgs/msg/Odometry@gz.msgs.Odometry",
        ], stdout=bridge_log, stderr=subprocess.STDOUT, text=True, start_new_session=True)
        (OUT / "bridge_pid.txt").write_text(f"pid={bridge.pid}\npgid={os.getpgid(bridge.pid)}\n")

        env = os.environ.copy(); env["OUT"] = str(OUT)
        proc = subprocess.run(
            [sys.executable, str(ROOT / "test_assets/capture_two.py")],
            text=True, capture_output=True, timeout=300, env=env)
        (OUT / "capture.log").write_text(proc.stdout + proc.stderr)
        if proc.returncode: raise RuntimeError((proc.returncode, proc.stdout, proc.stderr))
        print(proc.stdout)
    finally:
        if bridge is not None:
            try: os.killpg(os.getpgid(bridge.pid), signal.SIGINT)
            except ProcessLookupError: pass
            try: bridge.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try: os.killpg(os.getpgid(bridge.pid), signal.SIGTERM)
                except ProcessLookupError: pass
                try: bridge.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    try: os.killpg(os.getpgid(bridge.pid), signal.SIGKILL)
                    except ProcessLookupError: pass
                    bridge.wait(timeout=3)
            if bridge_log is not None: bridge_log.close()
        try: os.killpg(os.getpgid(server.pid), signal.SIGINT)
        except ProcessLookupError: pass
        try: server.wait(timeout=8)
        except subprocess.TimeoutExpired:
            try: os.killpg(os.getpgid(server.pid), signal.SIGTERM)
            except ProcessLookupError: pass
            try: server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try: os.killpg(os.getpgid(server.pid), signal.SIGKILL)
                except ProcessLookupError: pass
                server.wait(timeout=5)
        server_log.close()


if __name__ == "__main__": main()
