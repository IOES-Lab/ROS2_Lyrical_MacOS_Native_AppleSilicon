#!/usr/bin/env python3
from pathlib import Path
import csv
import json
import os
import signal
import subprocess
import time

root = Path(__file__).resolve().parent
world = root / 'empty_world.sdf'
model = root / 'probe_model.sdf'
shm_dir = Path('/private/tmp/boost_interprocess')


def snapshot(label):
    files = sorted(p.name for p in shm_dir.iterdir()) if shm_dir.exists() else []
    (root / f'shm_{label}.txt').write_text('\n'.join(files) + ('\n' if files else ''))
    return len(files)


def wait_for_world():
    for _ in range(120):
        result = subprocess.run(['gz', 'service', '-l'], text=True, capture_output=True)
        if '/world/fastdds_probe/create' in result.stdout:
            return True
        time.sleep(0.25)
    return False


def create_command(name):
    return [
        'ros2', 'run', 'ros_gz_sim', 'create',
        '-world', 'fastdds_probe', '-file', str(model), '-name', name,
    ]


def run_probe(phase, attempt, transport=None, timeout=30):
    env = os.environ.copy()
    env['ROS_DOMAIN_ID'] = '49'
    if transport is None:
        env.pop('FASTDDS_BUILTIN_TRANSPORTS', None)
    else:
        env['FASTDDS_BUILTIN_TRANSPORTS'] = transport
    name = f'{phase}_{attempt}'
    start = time.monotonic()
    try:
        result = subprocess.run(
            create_command(name), env=env, text=True, capture_output=True,
            timeout=timeout)
        elapsed = time.monotonic() - start
        output = result.stdout + result.stderr
        classification = 'SUCCESS' if result.returncode == 0 and 'Entity creation successful' in output else 'NONZERO'
        rc = result.returncode
    except subprocess.TimeoutExpired as exc:
        elapsed = time.monotonic() - start
        def decoded(value):
            if value is None:
                return ''
            return value.decode(errors='replace') if isinstance(value, bytes) else value
        output = decoded(exc.stdout) + decoded(exc.stderr)
        classification = 'TIMEOUT'
        rc = 124
    (root / f'{phase}_{attempt}.log').write_text(output)
    return {
        'phase': phase,
        'attempt': attempt,
        'transport': transport or 'DEFAULT_SHM_UDP',
        'return_code': rc,
        'classification': classification,
        'elapsed_s': round(elapsed, 3),
    }


def inject_unclean_exit(index):
    env = os.environ.copy()
    env['ROS_DOMAIN_ID'] = '49'
    env.pop('FASTDDS_BUILTIN_TRANSPORTS', None)
    log_path = root / f'sigkill_injection_{index}.log'
    with log_path.open('w') as log:
        proc = subprocess.Popen(
            create_command(f'sigkill_{index}'), env=env, text=True,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        time.sleep(1.5)
        os.killpg(proc.pid, signal.SIGKILL)
        proc.wait(timeout=5)
    return proc.returncode


rows = []
metadata = {
    'ros_domain_id': 49,
    'probe_timeout_s': 30,
    'world': str(world),
    'model': str(model),
}

snapshot('initial')
gz_log = (root / 'gz_server.log').open('w')
gz = subprocess.Popen(
    ['gz', 'sim', '-s', '-r', str(world)], stdout=gz_log,
    stderr=subprocess.STDOUT, start_new_session=True)
try:
    if not wait_for_world():
        raise RuntimeError('Gazebo create service did not appear')

    for attempt in range(1, 6):
        rows.append(run_probe('dirty_preclean', attempt))

    clean = subprocess.run(['fastdds', 'shm', 'clean'], text=True, capture_output=True)
    (root / 'fastdds_clean.txt').write_text(clean.stdout + clean.stderr)
    metadata['fastdds_clean_return_code'] = clean.returncode
    snapshot('after_clean')

    for attempt in range(1, 6):
        rows.append(run_probe('clean_postclean', attempt))

    metadata['sigkill_return_codes'] = [inject_unclean_exit(i) for i in range(1, 6)]
    snapshot('after_sigkill_injection')

    for attempt in range(1, 6):
        rows.append(run_probe('after_sigkill', attempt))

    for attempt in range(1, 4):
        rows.append(run_probe('udp_control', attempt, 'UDPv4'))
finally:
    try:
        os.killpg(gz.pid, signal.SIGINT)
    except ProcessLookupError:
        pass
    try:
        gz.wait(timeout=10)
    except subprocess.TimeoutExpired:
        os.killpg(gz.pid, signal.SIGKILL)
        gz.wait(timeout=5)
    gz_log.close()

with (root / 'results.csv').open('w', newline='') as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

summary = {
    'metadata': metadata,
    'rows': rows,
    'counts': {
        phase: {
            cls: sum(1 for row in rows if row['phase'] == phase and row['classification'] == cls)
            for cls in ('SUCCESS', 'NONZERO', 'TIMEOUT')
        }
        for phase in sorted(set(row['phase'] for row in rows))
    },
}
(root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
