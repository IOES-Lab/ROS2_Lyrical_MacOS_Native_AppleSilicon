import hashlib, json, math, sys, time
from pathlib import Path
import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image
NAMES=['ucam_control','ucam_atten_base','ucam_atten_r_only','ucam_atten_g_only','ucam_atten_b_only','ucam_bg_r_only','ucam_bg_g_only','ucam_bg_b_only']
out=Path(sys.argv[1]); out.mkdir(parents=True,exist_ok=True)
class C(Node):
  def __init__(self):
    super().__init__('camera_channel_matrix_capture')
    self.count={n:0 for n in NAMES}; self.frames={}
    self.subs=[]
    for n in NAMES:
      self.subs.append(self.create_subscription(Image,f'/{n}/simulated_image',lambda m,n=n:self.cb(n,m),10))
  def cb(self,n,m):
    self.count[n]+=1
    if self.count[n] < 10 or n in self.frames:return
    a=np.frombuffer(bytes(m.data),dtype=np.uint8).reshape(m.height,m.width,3).copy()
    self.frames[n]=a
    np.save(out/f'{n}.npy',a)
rclpy.init(); node=C(); deadline=time.time()+240
while rclpy.ok() and len(node.frames)<len(NAMES) and time.time()<deadline:rclpy.spin_once(node,timeout_sec=1)
if len(node.frames)!=len(NAMES):
  missing=sorted(set(NAMES)-set(node.frames)); raise TimeoutError(f'missing={missing} counts={node.count}')
center={n:a[a.shape[0]//2,a.shape[1]//2].astype(int).tolist() for n,a in node.frames.items()}
mean={n:a.mean(axis=(0,1)).tolist() for n,a in node.frames.items()}
sha={n:hashlib.sha256(a.tobytes()).hexdigest() for n,a in node.frames.items()}
# BGR indices 0,1,2. Candidate source maps semantic B/G/R tags to those indices.
ctrl=np.array(center['ucam_control'])
base=np.array(center['ucam_atten_base'])
checks={
 'atten_r_changes_only_red': center['ucam_atten_r_only'][0:2]==center['ucam_control'][0:2] and center['ucam_atten_r_only'][2]<center['ucam_control'][2],
 'atten_g_changes_only_green': center['ucam_atten_g_only'][0]==center['ucam_control'][0] and center['ucam_atten_g_only'][2]==center['ucam_control'][2] and center['ucam_atten_g_only'][1]<center['ucam_control'][1],
 'atten_b_changes_only_blue': center['ucam_atten_b_only'][1:3]==center['ucam_control'][1:3] and center['ucam_atten_b_only'][0]<center['ucam_control'][0],
 'background_r_changes_only_red_vs_base': center['ucam_bg_r_only'][0:2]==center['ucam_atten_base'][0:2] and center['ucam_bg_r_only'][2]>center['ucam_atten_base'][2],
 'background_g_changes_only_green_vs_base': center['ucam_bg_g_only'][0]==center['ucam_atten_base'][0] and center['ucam_bg_g_only'][2]==center['ucam_atten_base'][2] and center['ucam_bg_g_only'][1]>center['ucam_atten_base'][1],
 'background_b_changes_only_blue_vs_base': center['ucam_bg_b_only'][1:3]==center['ucam_atten_base'][1:3] and center['ucam_bg_b_only'][0]>center['ucam_atten_base'][0],
 'all_frames_distinct': len(set(sha.values()))==len(NAMES),
}
# Center surface is 3.975 m from sensor; C++ assignment truncates to uint8.
r=3.975; e=math.exp(-r*0.5)
def tr(v): return int(v)
pred={
 'ucam_atten_base':[tr(e*x) for x in ctrl],
 'ucam_atten_r_only':[int(ctrl[0]),int(ctrl[1]),tr(e*ctrl[2])],
 'ucam_atten_g_only':[int(ctrl[0]),tr(e*ctrl[1]),int(ctrl[2])],
 'ucam_atten_b_only':[tr(e*ctrl[0]),int(ctrl[1]),int(ctrl[2])],
 'ucam_bg_r_only':[tr(e*ctrl[0]),tr(e*ctrl[1]),tr(e*ctrl[2]+(1-e)*200)],
 'ucam_bg_g_only':[tr(e*ctrl[0]),tr(e*ctrl[1]+(1-e)*200),tr(e*ctrl[2])],
 'ucam_bg_b_only':[tr(e*ctrl[0]+(1-e)*200),tr(e*ctrl[1]),tr(e*ctrl[2])],
}
errors={n:[center[n][i]-pred[n][i] for i in range(3)] for n in pred}
checks['analytic_center_within_one_lsb']=all(abs(x)<=1 for row in errors.values() for x in row)
summary={'verdict':'PASS' if all(checks.values()) else 'FAIL','channel_order':'BGR','frame_counts_at_capture':node.count,'center_bgr':center,'mean_bgr':mean,'sha256_raw_bytes':sha,'expected_center_bgr':pred,'center_error_lsb':errors,'checks':checks,'limitations':['One synthetic planar scene.','One Docker llvmpipe run.','Validates implemented per-channel transform and tag mapping, not general underwater optical accuracy.']}
(out/'summary.json').write_text(json.dumps(summary,indent=2)); print(json.dumps(summary,indent=2))
node.destroy_node(); rclpy.shutdown()
