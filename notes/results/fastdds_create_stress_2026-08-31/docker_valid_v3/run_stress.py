#!/usr/bin/env python3
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import csv, json, os, signal, subprocess, time

root = Path(__file__).resolve().parent
source = root
world = source / 'empty_world.sdf'
model = source / 'probe_model.sdf'
domain = 47
partition = 'fastdds_create_stress_20260831'

def env_for(transport):
    env = os.environ.copy()
    env['ROS_DOMAIN_ID'] = str(domain)
    env['GZ_PARTITION'] = partition
    if transport:
        env['FASTDDS_BUILTIN_TRANSPORTS'] = transport
    else:
        env.pop('FASTDDS_BUILTIN_TRANSPORTS', None)
    return env

def command(name):
    return ['ros2','run','ros_gz_sim','create','-world','fastdds_probe',
            '-file',str(model),'-name',name]

def one(phase, round_no, slot, transport):
    name=f'{phase}_{round_no}_{slot}'
    start=time.monotonic()
    try:
        cp=subprocess.run(command(name),env=env_for(transport),text=True,
                          capture_output=True,timeout=40)
        output=cp.stdout+cp.stderr
        cls='SUCCESS' if cp.returncode==0 and 'Entity creation successful' in output else 'NONZERO'
        rc=cp.returncode
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or b''
        stderr = exc.stderr or b''
        if isinstance(stdout, bytes):
            stdout = stdout.decode(errors='replace')
        if isinstance(stderr, bytes):
            stderr = stderr.decode(errors='replace')
        output = stdout + stderr
        cls='TIMEOUT'; rc=124
    elapsed=time.monotonic()-start
    (root/f'{name}.log').write_text(output)
    return {'phase':phase,'round':round_no,'slot':slot,
            'transport':transport or 'DEFAULT_SHM_UDP','classification':cls,
            'return_code':rc,'elapsed_s':round(elapsed,3)}

def rounds(rows, phase, transport, count=5, width=8):
    for round_no in range(1,count+1):
        with ThreadPoolExecutor(max_workers=width) as pool:
            futures=[pool.submit(one,phase,round_no,slot,transport)
                     for slot in range(1,width+1)]
            batch=[f.result() for f in as_completed(futures)]
        rows.extend(sorted(batch,key=lambda x:x['slot']))
        print(phase,round_no,{k:sum(r['classification']==k for r in batch)
                              for k in ('SUCCESS','NONZERO','TIMEOUT')},flush=True)

def inject_kills(count=20):
    rcs=[]
    for i in range(1,count+1):
        with (root/f'kill_{i}.log').open('w') as log:
            p=subprocess.Popen(command(f'killed_{i}'),env=env_for(None),text=True,
                               stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            time.sleep(0.25)
            try: os.killpg(p.pid,signal.SIGKILL)
            except ProcessLookupError: pass
            rcs.append(p.wait(timeout=5))
    return rcs

def wait_world():
    for _ in range(160):
        cp=subprocess.run(['gz','service','-l'],text=True,capture_output=True,
                          env=env_for(None))
        if '/world/fastdds_probe/create' in cp.stdout: return True
        time.sleep(0.25)
    return False

rows=[]
gzlog=(root/'gz_server.log').open('w')
gz=subprocess.Popen(['gz','sim','-s','-r',str(world)],stdout=gzlog,
                    stderr=subprocess.STDOUT,start_new_session=True,
                    env=env_for(None))
metadata={'ros_domain_id':domain,'concurrency':8,'rounds_per_phase':5,
          'per_process_timeout_s':40,
          'execution_environment':'fresh Docker container',
          'world':str(world),'model':str(model),'gz_partition':partition}
try:
    if not wait_world(): raise RuntimeError('create service did not appear')
    rounds(rows,'concurrent_dirty_default',None)
    metadata['sigkill_return_codes']=inject_kills()
    rounds(rows,'concurrent_after_20_sigkills',None)
    clean=subprocess.run(['fastdds','shm','clean'],text=True,capture_output=True)
    (root/'fastdds_shm_clean.txt').write_text(clean.stdout+clean.stderr)
    metadata['fastdds_clean_return_code']=clean.returncode
    rounds(rows,'concurrent_after_clean',None)
    rounds(rows,'concurrent_udp','UDPv4')
finally:
    try: os.killpg(gz.pid,signal.SIGINT)
    except ProcessLookupError: pass
    try: gz.wait(timeout=15)
    except subprocess.TimeoutExpired:
        os.killpg(gz.pid,signal.SIGKILL); gz.wait(timeout=5)
    gzlog.close()

with (root/'results.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
counts={phase:{cls:sum(r['phase']==phase and r['classification']==cls for r in rows)
               for cls in ('SUCCESS','NONZERO','TIMEOUT')}
        for phase in sorted({r['phase'] for r in rows})}
summary={'metadata':metadata,'total_runs':len(rows),'counts':counts,
         'all_success':all(r['classification']=='SUCCESS' for r in rows),
         'maximum_elapsed_s':max(r['elapsed_s'] for r in rows)}
(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
