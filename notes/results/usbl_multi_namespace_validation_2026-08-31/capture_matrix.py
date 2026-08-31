import json, math, sys, time
from pathlib import Path
import rclpy
from rclpy.node import Node
from std_msgs.msg import String
from dave_interfaces.msg import Location
OUT=Path(sys.argv[1]); OUT.mkdir(parents=True,exist_ok=True)
NSS=['USBL_A','USBL_B']
def t(ns,suffix): return f'/{ns}/{suffix}'
class C(Node):
 def __init__(self):
  super().__init__('usbl_multi_namespace_capture')
  self.phase='startup'; self.rows={ns:[] for ns in NSS}; self.pubs={}
  self.subs=[]
  for ns in NSS:
   self.subs.append(self.create_subscription(Location,t(ns,'transceiver_168/transponder_location_cartesian'),lambda m,ns=ns:self.cb(ns,m),10))
   self.pubs[ns]=self.create_publisher(String,t(ns,'common_interrogation_ping'),10)
 def cb(self,ns,m):
  self.rows[ns].append({'phase':self.phase,'wall_time':time.time(),'id':int(m.transponder_id),'x':float(m.x),'y':float(m.y),'z':float(m.z)})
 def spin(self,sec):
  end=time.monotonic()+sec
  while time.monotonic()<end:rclpy.spin_once(self,timeout_sec=.05)
 def ping(self,ns,n=1):
  m=String(); m.data='ping'
  for _ in range(n):self.pubs[ns].publish(m)
def count(rows,phase): return [r for r in rows if r['phase']==phase]
rclpy.init(); n=C(); deadline=time.monotonic()+60
graph={}
while time.monotonic()<deadline:
 graph={ns:{'location_publishers':n.count_publishers(t(ns,'transceiver_168/transponder_location_cartesian')),'ping_subscribers':n.count_subscribers(t(ns,'common_interrogation_ping'))} for ns in NSS}
 if all(v['location_publishers']>=1 and v['ping_subscribers']>=2 for v in graph.values()):break
 n.spin(.2)
phases={}
for active,quiet in [('USBL_A','USBL_B'),('USBL_B','USBL_A')]:
 phase=f'{active}_only'; n.phase=phase; before={k:len(v) for k,v in n.rows.items()}
 end=time.monotonic()+20; nxt=0
 while time.monotonic()<end:
  now=time.monotonic()
  if now>=nxt:n.ping(active); nxt=now+.1
  rclpy.spin_once(n,timeout_sec=.05)
  if len(count(n.rows[active],phase))>=20:break
 n.spin(1)
 phases[phase]={k:count(n.rows[k],phase) for k in NSS}
n.phase='both_concurrent'; end=time.monotonic()+30; nxt=0
while time.monotonic()<end:
 now=time.monotonic()
 if now>=nxt:
  for ns in NSS:n.ping(ns)
  nxt=now+.1
 rclpy.spin_once(n,timeout_sec=.05)
 if all(len(count(n.rows[ns],'both_concurrent'))>=20 for ns in NSS):break
n.spin(1); phases['both_concurrent']={k:count(n.rows[k],'both_concurrent') for k in NSS}
expected={1:(3,4,.5),2:(6,8,.5)}
def summarize(rows):
 errs=[]
 for r in rows:
  e=expected.get(r['id'])
  if e:errs.extend(abs(r[k]-e[i]) for i,k in enumerate(('x','y','z')))
 return {'count':len(rows),'ids':sorted({r['id'] for r in rows}),'max_axis_error_m':max(errs) if errs else None}
summary_ph={p:{ns:summarize(rows) for ns,rows in d.items()} for p,d in phases.items()}
checks={
 'graph_complete':all(v['location_publishers']>=1 and v['ping_subscribers']>=2 for v in graph.values()),
 'a_only_has_a':summary_ph['USBL_A_only']['USBL_A']['count']>=20 and summary_ph['USBL_A_only']['USBL_B']['count']==0,
 'b_only_has_b':summary_ph['USBL_B_only']['USBL_B']['count']>=20 and summary_ph['USBL_B_only']['USBL_A']['count']==0,
 'both_have_data':all(summary_ph['both_concurrent'][ns]['count']>=20 for ns in NSS),
 'all_ids_1_2':all(v['ids']==[1,2] for p in summary_ph.values() for v in p.values() if v['count']),
 'geometry_exact':all((v['max_axis_error_m'] or 0)<1e-9 for p in summary_ph.values() for v in p.values()),
}
summary={'verdict':'PASS' if all(checks.values()) else 'FAIL','graph':graph,'phases':summary_ph,'checks':checks,'raw':n.rows,'scope':'Two transceivers and four transponders in two namespaces with reused device IDs; isolated and concurrent common interrogation.','limitations':['One Docker run.','Static synthetic geometry.','Bounded message counts, not long-duration or physical acoustic accuracy.']}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n'); print(json.dumps({k:v for k,v in summary.items() if k!='raw'},indent=2))
n.destroy_node(); rclpy.shutdown()
