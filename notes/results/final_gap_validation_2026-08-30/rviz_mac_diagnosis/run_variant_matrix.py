#!/usr/bin/env python3
from pathlib import Path
import json, os, signal, subprocess, time

root = Path(__file__).resolve().parent
rviz = Path('/Users/gwon-yeseol/ros2_lyrical/install/rviz2/lib/rviz2/rviz2')
variants = [
    ('layer_0', {'QT_QPA_PLATFORM': 'cocoa', 'QT_MAC_WANTS_LAYER': '0'}, []),
    ('layer_1', {'QT_QPA_PLATFORM': 'cocoa', 'QT_MAC_WANTS_LAYER': '1'}, []),
    ('scale_1', {'QT_QPA_PLATFORM': 'cocoa', 'QT_SCALE_FACTOR': '1', 'QT_SCREEN_SCALE_FACTORS': '1'}, []),
    ('fullscreen', {'QT_QPA_PLATFORM': 'cocoa'}, ['--fullscreen']),
]
applescript = r'''
on run argv
 set targetPid to item 1 of argv as integer
 tell application "System Events"
  set matches to every process whose unix id is targetPid
  if (count matches) is 0 then return "process_missing"
  set p to item 1 of matches
  return "name=" & name of p & ", visible=" & visible of p & ", frontmost=" & frontmost of p & ", windows=" & (count windows of p)
 end tell
end run
'''
summary = []
for name, additions, args in variants:
    case = root / name
    case.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(additions)
    with (case / 'rviz.log').open('w') as log:
        proc = subprocess.Popen([str(rviz), *args], cwd=case, env=env,
                                stdout=log, stderr=subprocess.STDOUT,
                                start_new_session=True)
        (case / 'pid.txt').write_text(f'{proc.pid}\n')
        time.sleep(15)
        alive = proc.poll() is None
        if alive:
            ps = subprocess.run(['ps', '-p', str(proc.pid), '-o', 'pid,state,etime,command'],
                                text=True, capture_output=True)
            (case / 'process.txt').write_text(ps.stdout + ps.stderr)
            osa = subprocess.run(['osascript', '-', str(proc.pid)], input=applescript,
                                 text=True, capture_output=True)
            accessibility = (osa.stdout + osa.stderr).strip()
            (case / 'window_state.txt').write_text(accessibility + '\n')
            cg = subprocess.run(['/tmp/list_windows', str(proc.pid)], text=True,
                                capture_output=True)
            cg_text = cg.stdout + cg.stderr
            (case / 'coregraphics_windows.txt').write_text(cg_text)
        else:
            accessibility = f'exited={proc.returncode}'
            cg_text = ''
        summary.append({
            'variant': name,
            'pid': proc.pid,
            'alive_after_15s': alive,
            'accessibility': accessibility,
            'coregraphics_has_large_onscreen_layer0': any(
                'layer=0' in line and 'onscreen=true' in line and
                ('Width = 640' in line or 'Width = 1710' in line)
                for line in cg_text.splitlines()
            ),
            'env': additions,
            'args': args,
        })
        if alive:
            os.killpg(proc.pid, signal.SIGKILL)
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
(root / 'variant_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
