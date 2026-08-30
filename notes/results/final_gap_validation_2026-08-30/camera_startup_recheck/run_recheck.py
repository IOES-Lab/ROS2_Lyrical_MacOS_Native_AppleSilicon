#!/usr/bin/env python3
from pathlib import Path
import csv
import json
import os
import signal
import subprocess
import time

root = Path(__file__).resolve().parent
root.mkdir(parents=True, exist_ok=True)
topic = '/underwater_camera/simulated_image'
domain_id = '50'


def command_env(transport):
    env = os.environ.copy()
    env['ROS_DOMAIN_ID'] = domain_id
    if transport is None:
        env.pop('FASTDDS_BUILTIN_TRANSPORTS', None)
    else:
        env['FASTDDS_BUILTIN_TRANSPORTS'] = transport
    return env


def stop_group(proc):
    if proc.poll() is not None:
        return proc.returncode
    for sig, timeout in ((signal.SIGINT, 15), (signal.SIGTERM, 5), (signal.SIGKILL, 5)):
        try:
            os.killpg(proc.pid, sig)
        except ProcessLookupError:
            break
        try:
            return proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            pass
    return proc.poll()


def run_case(transport_label, transport, attempt):
    case = root / f'{transport_label}_{attempt}'
    case.mkdir(exist_ok=True)
    env = command_env(transport)
    subprocess.run(['ros2', 'daemon', 'stop'], env=env, text=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['ros2', 'daemon', 'start'], env=env, text=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    launch_command = [
        'ros2', 'launch', 'dave_demos', 'dave_sensor.launch.py',
        'namespace:=underwater_camera',
        'world_name:=camera_tutorial',
        'paused:=false', 'x:=10', 'z:=-93.5',
        'pitch:=0.3', 'yaw:=3.14',
        'gui:=true', 'headless:=false', 'debug:=false',
    ]
    (case / 'command.txt').write_text(' '.join(launch_command) + '\n')
    started = time.monotonic()
    with (case / 'launch.log').open('w') as log:
        proc = subprocess.Popen(launch_command, env=env, text=True,
                                stdout=log, stderr=subprocess.STDOUT,
                                start_new_session=True)
        classification = 'TIMEOUT'
        detail = ''
        topic_first_seen_s = None
        image_s = None
        image_output = ''
        deadline = started + 120
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                classification = 'LAUNCH_EXITED'
                detail = f'launch exited with {proc.returncode}'
                break
            try:
                listed = subprocess.run(
                    ['ros2', 'topic', 'list'], env=env, text=True,
                    capture_output=True, timeout=15)
            except subprocess.TimeoutExpired:
                time.sleep(1)
                continue
            if topic in listed.stdout.splitlines():
                if topic_first_seen_s is None:
                    topic_first_seen_s = time.monotonic() - started
                try:
                    echo = subprocess.run(
                        ['ros2', 'topic', 'echo', topic, '--filter',
                         'm.width > 1', '--once', '--timeout', '30', '--no-arr'],
                        env=env, text=True, capture_output=True, timeout=40)
                    image_output = echo.stdout + echo.stderr
                    if (echo.returncode == 0 and 'height: 240' in image_output
                            and 'width: 320' in image_output
                            and 'length: 230400' in image_output):
                        image_s = time.monotonic() - started
                        classification = 'SUCCESS'
                        break
                    detail = f'echo returned {echo.returncode} without expected image'
                except subprocess.TimeoutExpired as exc:
                    def decoded(value):
                        if value is None:
                            return ''
                        return value.decode(errors='replace') if isinstance(value, bytes) else value
                    image_output = decoded(exc.stdout) + decoded(exc.stderr)
                    detail = 'image echo timed out'
            time.sleep(2)
        (case / 'image_structure.txt').write_text(image_output)
        launch_rc = stop_group(proc)
    subprocess.run(['ros2', 'daemon', 'stop'], env=env, text=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elapsed = time.monotonic() - started
    row = {
        'transport': transport_label,
        'attempt': attempt,
        'classification': classification,
        'topic_first_seen_s': None if topic_first_seen_s is None else round(topic_first_seen_s, 3),
        'image_received_s': None if image_s is None else round(image_s, 3),
        'total_elapsed_s': round(elapsed, 3),
        'launch_return_code_after_shutdown': launch_rc,
        'detail': detail,
    }
    (case / 'result.json').write_text(json.dumps(row, indent=2) + '\n')
    print(json.dumps(row), flush=True)
    time.sleep(3)
    return row


rows = []
for label, transport in (('default', None), ('udp', 'UDPv4')):
    for attempt in range(1, 4):
        rows.append(run_case(label, transport, attempt))

with (root / 'results.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

summary = {
    'ros_domain_id': int(domain_id),
    'timeout_per_attempt_s': 120,
    'expected_image': {'width': 320, 'height': 240, 'encoding': 'bgr8', 'data_length': 230400},
    'rows': rows,
    'counts': {
        label: {
            status: sum(1 for row in rows if row['transport'] == label and row['classification'] == status)
            for status in ('SUCCESS', 'TIMEOUT', 'LAUNCH_EXITED')
        }
        for label in ('default', 'udp')
    },
}
(root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
