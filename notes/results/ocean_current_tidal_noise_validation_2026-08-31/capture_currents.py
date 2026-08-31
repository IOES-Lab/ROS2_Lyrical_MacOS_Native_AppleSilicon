import json, math, statistics, sys, time
from pathlib import Path
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import TwistStamped
from dave_interfaces.msg import StratifiedCurrentVelocity
out=Path(sys.argv[1]); variant=sys.argv[2]; out.mkdir(parents=True,exist_ok=True)
class C(Node):
 def __init__(self):
  super().__init__('ocean_current_tidal_noise_capture')
  self.global_rows=[]; self.strat_rows=[]
  self.create_subscription(TwistStamped,'/hydrodynamics/currentVelocityTopic',self.g,10)
  self.create_subscription(StratifiedCurrentVelocity,'/hydrodynamics/stratifiedCurrentVelocityTopic',self.s,10)
 def g(self,m):
  self.global_rows.append({'t':m.header.stamp.sec+m.header.stamp.nanosec*1e-9,'x':m.twist.linear.x,'y':m.twist.linear.y,'z':m.twist.linear.z})
 def s(self,m):
  self.strat_rows.append({'t':m.header.stamp.sec+m.header.stamp.nanosec*1e-9,'depths':list(m.depths),'velocities':[[v.x,v.y,v.z] for v in m.velocities]})
rclpy.init(); n=C(); deadline=time.time()+180
while rclpy.ok() and time.time()<deadline and (len(n.global_rows)<400 or len(n.strat_rows)<100):rclpy.spin_once(n,timeout_sec=1)
if len(n.global_rows)<400 or len(n.strat_rows)<100:raise TimeoutError(f'global={len(n.global_rows)} strat={len(n.strat_rows)}')
g=n.global_rows[:400]; st=n.strat_rows[:100]
def uniq(vals):return len(set(round(x,12) for x in vals))
xs=[r['x'] for r in g]; ys=[r['y'] for r in g]; zs=[r['z'] for r in g]
summary={'variant':variant,'verdict':'CAPTURED','counts':{'global':len(g),'stratified':len(st)},'sim_time':{'first':g[0]['t'],'last':g[-1]['t'],'span_s':g[-1]['t']-g[0]['t']},'global':{'mean_xyz':[statistics.fmean(xs),statistics.fmean(ys),statistics.fmean(zs)],'stdev_xyz':[statistics.pstdev(xs),statistics.pstdev(ys),statistics.pstdev(zs)],'min_xyz':[min(xs),min(ys),min(zs)],'max_xyz':[max(xs),max(ys),max(zs)],'unique_xyz':[uniq(xs),uniq(ys),uniq(zs)]},'stratified_first':st[0],'stratified_last':st[-1]}
(out/'raw.json').write_text(json.dumps({'global':g,'stratified':st},indent=2)+'\n'); (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print(json.dumps(summary,indent=2))
n.destroy_node(); rclpy.shutdown()
