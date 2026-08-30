#!/usr/bin/env python3
from pathlib import Path
import json
import os
import signal
import subprocess
import time
import re

root = Path(__file__).resolve().parent
rviz = Path('/Users/gwon-yeseol/ros2_lyrical/install/rviz2/lib/rviz2/rviz2')
variants = [
    ('qt_opengl_software', {'QT_OPENGL': 'software'}),
    ('libgl_software', {'LIBGL_ALWAYS_SOFTWARE': '1'}),
    ('both_software', {'QT_OPENGL': 'software', 'LIBGL_ALWAYS_SOFTWARE': '1'}),
]
only = os.environ.get('ONLY_VARIANT')
if only:
    variants = [item for item in variants if item[0] == only]
wait_seconds = int(os.environ.get('RVIZ_WAIT_SECONDS', '15'))
summary = []


def main_window_is_onscreen(coregraphics_text):
    # Evaluate each CoreGraphics entry independently.  The splash window can be
    # onscreen while RViz's 640x508 main window remains offscreen, so looking
    # for both strings anywhere in the full output produces a false positive.
    entries = re.split(r'(?=^id=)', coregraphics_text, flags=re.MULTILINE)
    return any(
        'onscreen=true' in entry
        and 'Width = 640;' in entry
        and 'Height = 508;' in entry
        for entry in entries
    )


for name, additions in variants:
    case = root / name
    case.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(additions)
    with (case / 'rviz.log').open('w') as log:
        proc = subprocess.Popen(
            [str(rviz)], cwd=case, env=env, stdout=log,
            stderr=subprocess.STDOUT, start_new_session=True)
        (case / 'pid.txt').write_text(f'{proc.pid}\n')
        time.sleep(wait_seconds)
        alive = proc.poll() is None
        cg = subprocess.run(
            ['/tmp/list_windows', str(proc.pid)], text=True, capture_output=True)
        cg_text = cg.stdout + cg.stderr
        (case / 'coregraphics_windows.txt').write_text(cg_text)
        summary.append({
            'variant': name,
            'env': additions,
            'alive_after_wait': alive,
            'wait_seconds': wait_seconds,
            'coregraphics_has_main_onscreen': main_window_is_onscreen(cg_text),
            'coregraphics_windows': cg_text,
        })
        if alive:
            os.killpg(proc.pid, signal.SIGKILL)
        proc.wait(timeout=5)

(root / ('software_variant_summary.json' if not only else f'{only}_summary.json')).write_text(
    json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
