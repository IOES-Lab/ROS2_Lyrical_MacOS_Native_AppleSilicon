#!/usr/bin/env python3
import csv, json, math, re, statistics, sys
from pathlib import Path

out=Path(sys.argv[1])
rows=[]
with (out/'resource_samples.tsv').open(newline='') as f:
    for row in csv.DictReader(f,delimiter='\t'):
        def num(k, typ=float):
            v=row.get(k,'')
            return typ(v) if v not in ('',None) else None
        rows.append({k:row[k] for k in ('sample','wall_utc') if k in row} | {
            'elapsed_s':num('elapsed_s',int),
            'container_cpu_pct':num('container_cpu_pct'),
            'container_mem_bytes':num('container_mem_bytes',int),
            'container_pids':num('container_pids',int),
            'gz_rss_kib':num('gz_rss_kib',int),
            'gz_cpu_pct':num('gz_cpu_pct'),
            'gpu_frame':num('gpu_frame',int),
            'gpu_ms':num('gpu_ms'),
        })

def slope(points):
    pts=[(float(x),float(y)) for x,y in points if x is not None and y is not None]
    if len(pts)<2:return None
    xb=sum(x for x,_ in pts)/len(pts); yb=sum(y for _,y in pts)/len(pts)
    den=sum((x-xb)**2 for x,_ in pts)
    return sum((x-xb)*(y-yb) for x,y in pts)/den if den else 0.0

stable=[r for r in rows if r['elapsed_s'] is not None and r['elapsed_s']>=300]
mem=[r['container_mem_bytes'] for r in stable if r['container_mem_bytes'] is not None]
rss=[r['gz_rss_kib'] for r in stable if r['gz_rss_kib'] is not None]
frames=[r['gpu_frame'] for r in rows if r['gpu_frame'] is not None]

def parse_stats(path):
    text=path.read_text(errors='replace')
    block_re=re.compile(r'sim_time \{\s*sec: (\d+)\s*nsec: (\d+)\s*\}\s*real_time \{\s*sec: (\d+)\s*nsec: (\d+)\s*\}\s*iterations: (\d+)\s*real_time_factor: ([0-9.eE+-]+)',re.M)
    vals=[]
    for m in block_re.finditer(text):
        vals.append({
            'sim_s':int(m[1])+int(m[2])*1e-9,
            'real_s':int(m[3])+int(m[4])*1e-9,
            'iterations':int(m[5]),
            'reported_rtf':float(m[6]),
        })
    if not vals:return {'file':path.name,'messages':0}
    endpoint=(vals[-1]['sim_s']-vals[0]['sim_s'])/(vals[-1]['real_s']-vals[0]['real_s']) if vals[-1]['real_s']>vals[0]['real_s'] else None
    return {
        'file':path.name,'messages':len(vals),
        'first_iteration':vals[0]['iterations'],'last_iteration':vals[-1]['iterations'],
        'iteration_delta':vals[-1]['iterations']-vals[0]['iterations'],
        'endpoint_delta_rtf':endpoint,
        'reported_rtf_median':statistics.median(v['reported_rtf'] for v in vals),
        'reported_rtf_min':min(v['reported_rtf'] for v in vals),
        'reported_rtf_max':max(v['reported_rtf'] for v in vals),
    }

stats=[]
for p in sorted(out.glob('world_stats*.txt')):
    if p.name.endswith('.utc.txt') or p.name=='world_stats_topics.txt':continue
    stats.append(parse_stats(p))

def text_has(path,*patterns):
    if not path.exists():return False
    s=path.read_text(errors='replace')
    return all(re.search(p,s,re.M) for p in patterns)

launch=(out/'launch.log').read_text(errors='replace') if (out/'launch.log').exists() else ''
result={
    'duration_target_minutes':30,
    'resource_sample_count':len(rows),
    'elapsed_s_first':rows[0]['elapsed_s'] if rows else None,
    'elapsed_s_last':rows[-1]['elapsed_s'] if rows else None,
    'backend_ready':(out/'backend_ready.txt').read_text().strip()=='1' if (out/'backend_ready.txt').exists() else False,
    'payload':{
        'point_start_513x301':text_has(out/'point_start.txt',r'height: 301',r'width: 513',r'data: .+4941216'),
        'point_end_513x301':text_has(out/'point_end.txt',r'height: 301',r'width: 513',r'data: .+4941216'),
        'raw_start_513x399':text_has(out/'raw_start.txt',r'beam_count: 513',r'length: 399',r'data: .+818748'),
        'raw_end_513x399':text_has(out/'raw_end.txt',r'beam_count: 513',r'length: 399',r'data: .+818748'),
    },
    'gpu_frames':{'first':frames[0] if frames else None,'last':frames[-1] if frames else None,'delta':frames[-1]-frames[0] if len(frames)>=2 else None},
    'stable_window':{
        'definition':'elapsed_s >= 300; sample 0/startup excluded',
        'sample_count':len(stable),
        'container_mem_bytes_min':min(mem) if mem else None,
        'container_mem_bytes_median':statistics.median(mem) if mem else None,
        'container_mem_bytes_max':max(mem) if mem else None,
        'container_mem_slope_bytes_per_hour':slope((r['elapsed_s'],r['container_mem_bytes']) for r in stable)*3600 if len(stable)>=2 else None,
        'gz_rss_kib_min':min(rss) if rss else None,
        'gz_rss_kib_median':statistics.median(rss) if rss else None,
        'gz_rss_kib_max':max(rss) if rss else None,
        'gz_rss_slope_kib_per_hour':slope((r['elapsed_s'],r['gz_rss_kib']) for r in stable)*3600 if len(stable)>=2 else None,
    },
    'world_stats_samples':stats,
    'runtime_segfault_or_stack_trace':bool(re.search(r'Segmentation fault|Stack trace|exit code 139',launch)),
    'bridge_shutdown_exit_minus_11':bool(re.search(r'parameter_bridge.*exit code -11',launch)),
    'launch_rc':int((out/'launch_rc.txt').read_text().strip()) if (out/'launch_rc.txt').exists() and (out/'launch_rc.txt').read_text().strip().lstrip('-').isdigit() else None,
    'interpretation':'Memory slopes describe this bounded software-llvmpipe run only; a positive slope is not by itself called a leak.',
}
(out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
