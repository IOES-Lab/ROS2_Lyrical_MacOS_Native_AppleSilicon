#!/usr/bin/env python3
import json, math, statistics, time
from pathlib import Path
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import FluidPressure

OUT=Path('/tmp/seapressure_long_result')
topics={
 'sp_surface':'/model/sp_surface/sea_pressure',
 'sp_depth10':'/model/sp_depth10/sea_pressure',
 'sp_above10':'/model/sp_above10/sea_pressure',
 'sp_saturation':'/model/sp_saturation/sea_pressure',
 'sp_noise':'/model/sp_noise/sea_pressure',
 'sp_rate':'/model/sp_rate/sea_pressure',
 'sp_custom':'/model/sp_custom/custom_sp',
}
targets={k:(2000 if k=='sp_noise' else 200 if k=='sp_rate' else 1000) for k in topics}
class C(Node):
 def __init__(self):
  super().__init__('seapressure_long_multi_capture')
  self.rows={k:[] for k in topics}
  for k,t in topics.items():
   self.create_subscription(FluidPressure,t,lambda m,k=k:self.cb(k,m),10)
 def cb(self,k,m):
  if len(self.rows[k]) < targets[k]:
   self.rows[k].append((m.header.stamp.sec+m.header.stamp.nanosec/1e9,m.header.frame_id,m.fluid_pressure,m.variance))
rclpy.init(); n=C(); deadline=time.monotonic()+240
while time.monotonic()<deadline and not all(len(n.rows[k])>=targets[k] for k in topics):
 rclpy.spin_once(n,timeout_sec=0.1)
counts={k:len(v) for k,v in n.rows.items()}
if not all(counts[k]>=targets[k] for k in topics): raise RuntimeError(f'insufficient: {counts}')
def stats(rows):
 t=[r[0] for r in rows]; p=[r[2] for r in rows]; v=[r[3] for r in rows]
 d=[b-a for a,b in zip(t,t[1:])]
 return {'count':len(rows),'sim_duration_s':t[-1]-t[0],
         'median_period_s':statistics.median(d),'min_period_s':min(d),'max_period_s':max(d),
         'pressure_mean_pa':statistics.mean(p),'pressure_stdev_pa':statistics.stdev(p) if len(p)>1 else 0.0,
         'pressure_min_pa':min(p),'pressure_max_pa':max(p),'unique_pressures':len(set(p)),
         'variance_values':sorted(set(v)),'frame_ids':sorted(set(r[1] for r in rows))}
S={k:stats(v) for k,v in n.rows.items()}
checks={
 'all_targets_met':all(counts[k]>=targets[k] for k in topics),
 'seven_devices_simultaneous':len([k for k,v in counts.items() if v])==7,
 'noise_mean_within_15pa':abs(S['sp_noise']['pressure_mean_pa']-101325.0)<15.0,
 'noise_stdev_within_10pct':abs(S['sp_noise']['pressure_stdev_pa']-123.0)<12.3,
 'noise_variance_exact':S['sp_noise']['variance_values']==[15129.0],
 'noise_all_unique':S['sp_noise']['unique_pressures']==targets['sp_noise'],
 'rate_2hz':abs(S['sp_rate']['median_period_s']-0.5)<0.02,
 'surface_10hz':abs(S['sp_surface']['median_period_s']-0.1)<0.02,
 'surface_exact':S['sp_surface']['pressure_min_pa']==101325.0==S['sp_surface']['pressure_max_pa'],
 'depth_exact':math.isclose(S['sp_depth10']['pressure_mean_pa'],199388.8,abs_tol=1e-6),
 'saturation_exact':S['sp_saturation']['pressure_min_pa']==150000.0==S['sp_saturation']['pressure_max_pa'],
}
result={'verdict':'PASS' if all(checks.values()) else 'FAIL','targets':targets,'counts':counts,'checks':checks,'statistics':S,
 'scope':'Seven simultaneous candidate SeaPressure devices; 2000 noise frames (about 100 simulated seconds), 1000 frames for normal 10 Hz paths, and 200 frames for the 2 Hz path.',
 'limitations':['Single Docker run','synthetic plugin oracle, not physical pressure calibration','about 100 simulated seconds, not mission-duration endurance']}
OUT.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
n.destroy_node(); rclpy.shutdown()
if result['verdict']!='PASS': raise SystemExit(1)
