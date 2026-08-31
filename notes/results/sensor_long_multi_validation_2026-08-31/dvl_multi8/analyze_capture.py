#!/usr/bin/env python3
from pathlib import Path
import json, re
root=Path(__file__).resolve().parent
raw=json.loads((root/'raw_capture_v3.json').read_text())
world=(root/'dvl_multi8.world').read_text()
rates={}
for name in raw['statistics']:
 m=re.search(rf'<model name=["\']{re.escape(name)}["\']>(.*?)</model>',world,re.S)
 if not m: raise RuntimeError(f'model not found: {name}')
 u=re.search(r'<update_rate>([^<]+)</update_rate>',m.group(1))
 if not u: raise RuntimeError(f'update rate not found: {name}')
 rates[name]=float(u.group(1))
frames=[x for s in raw['statistics'].values() for x in s['frame_ids']]
checks={
 'all_eight_reached_target':all(v==20 for v in raw['counts'].values()),
 'all_four_beams':all(s['beam_lengths']==[4] for s in raw['statistics'].values()),
 'all_bottom_lock':all(s['target_types']==['DVL_TARGET_BOTTOM'] for s in raw['statistics'].values()),
 'all_nonempty_frame_ids':all(s['frame_ids'] and all(s['frame_ids']) for s in raw['statistics'].values()),
 'eight_distinct_frame_ids':len(set(frames))==8,
 'all_rates_match_descriptor':all(abs(s['median_period_s']-1.0/rates[k])<0.005 for k,s in raw['statistics'].items()),
}
out={**raw,'verdict':'PASS' if all(checks.values()) else 'FAIL','configured_rates_hz':rates,'checks':checks,
 'scope':'Eight distinct DAVE DVL descriptors ran simultaneously against one planar bottom for 20 messages each.',
 'analysis_note':'The runtime capture completed. Its first verdict incorrectly assumed every descriptor was 8 Hz; this reanalysis reads 8/12/7 Hz directly from the embedded model descriptors.',
 'limitations':['Synthetic planar bottom only','single Docker run','20 messages per device (160 total)','not physical calibration or water-mass accuracy','simulator teardown emitted the separately tracked DAVE DVL bridge shutdown stack trace after capture']}
(root/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
if out['verdict']!='PASS': raise SystemExit(1)
