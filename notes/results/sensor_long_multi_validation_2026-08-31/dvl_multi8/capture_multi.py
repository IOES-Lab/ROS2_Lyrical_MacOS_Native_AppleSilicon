#!/usr/bin/env python3
import json, statistics, time
from pathlib import Path
import rclpy
from rclpy.node import Node
from dave_interfaces.msg import DVL
names=['nortek_dvl500_300','nortek_dvl500_6000','nortek_dvl1000_300','nortek_dvl1000_4000','sonardyne_syrinx600','teledyne_explorer1000','teledyne_explorer4000','teledyne_whn']
target=20
configured_rates={n:8.0 for n in names}
configured_rates.update({'teledyne_explorer1000':12.0,
                         'teledyne_explorer4000':12.0,
                         'teledyne_whn':7.0})
class C(Node):
 def __init__(self):
  super().__init__('dvl_multi8_capture')
  self.rows={n:[] for n in names}
  for n in names: self.create_subscription(DVL,f'/dvl/{n}',lambda m,n=n:self.cb(n,m),10)
 def cb(self,n,m):
  if len(self.rows[n])<target:
   self.rows[n].append({'stamp':m.header.stamp.sec+m.header.stamp.nanosec/1e9,'frame_id':m.header.frame_id,'beams':len(m.beams),'target_type':str(m.target.type)})
rclpy.init(); n=C(); deadline=time.monotonic()+300
while time.monotonic()<deadline and not all(len(v)>=target for v in n.rows.values()): rclpy.spin_once(n,timeout_sec=0.1)
counts={k:len(v) for k,v in n.rows.items()}
if not all(v>=target for v in counts.values()): raise RuntimeError(counts)
stats={}
for k,v in n.rows.items():
 dt=[b['stamp']-a['stamp'] for a,b in zip(v,v[1:])]
 stats[k]={'count':len(v),'sim_duration_s':v[-1]['stamp']-v[0]['stamp'],'median_period_s':statistics.median(dt),'frame_ids':sorted(set(x['frame_id'] for x in v)),'beam_lengths':sorted(set(x['beams'] for x in v)),'target_types':sorted(set(x['target_type'] for x in v))}
frames=[x for s in stats.values() for x in s['frame_ids']]
checks={'all_eight_reached_target':all(v==target for v in counts.values()),'all_four_beams':all(s['beam_lengths']==[4] for s in stats.values()),'all_nonempty_frame_ids':all(s['frame_ids'] and all(s['frame_ids']) for s in stats.values()),'eight_distinct_frame_ids':len(set(frames))==8,'all_rates_match_descriptor':all(abs(s['median_period_s']-1.0/configured_rates[k])<0.005 for k,s in stats.items())}
out={'verdict':'PASS' if all(checks.values()) else 'FAIL','counts':counts,'configured_rates_hz':configured_rates,'checks':checks,'statistics':stats,'total_messages':sum(counts.values()),'scope':f'Eight distinct DAVE DVL descriptors ran simultaneously against one planar bottom for {target} messages each.','limitations':['Synthetic planar bottom only','single Docker run','not physical calibration or water-mass accuracy']}
Path('/tmp/dvl_multi8_result.json').write_text(json.dumps(out,indent=2)+'\n'); print(json.dumps(out,indent=2))
n.destroy_node(); rclpy.shutdown()
if out['verdict']!='PASS': raise SystemExit(1)
