#!/usr/bin/env python3
import hashlib,json,sys,time
from pathlib import Path
import numpy as np
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import Image

root=Path(sys.argv[1]); variants=json.loads((root/'test_assets/variants.json').read_text())
class C(Node):
  def __init__(self):
    super().__init__('underwater_full_matrix_capture'); self.count={k:0 for k in variants}; self.rows={}
    self.subs=[self.create_subscription(Image,f'/{k}/simulated_image',lambda m,k=k:self.cb(k,m),10) for k in variants]
  def cb(self,k,m):
    self.count[k]+=1
    if self.count[k] <= 10 or k in self.rows: return
    a=np.frombuffer(bytes(m.data),dtype=np.uint8).reshape(m.height,m.step)[:,:m.width*3].reshape(m.height,m.width,3).copy()
    center=[int(x) for x in a[m.height//2,m.width//2]]
    mean=[float(x) for x in a.reshape(-1,3).mean(axis=0)]
    np.save(root/'run'/f'{k}.npy',a)
    self.rows[k]={'width':m.width,'height':m.height,'encoding':m.encoding,'step':m.step,'data_length':len(m.data),'center_bgr':center,'mean_bgr':mean,'sha256':hashlib.sha256(a.tobytes()).hexdigest()}

rclpy.init(); n=C(); deadline=time.monotonic()+240
while rclpy.ok() and len(n.rows)<len(variants) and time.monotonic()<deadline:
  rclpy.spin_once(n,timeout_sec=1)
if len(n.rows)!=len(variants):
  missing=sorted(set(variants)-set(n.rows)); raise TimeoutError(f'missing {missing}')
# Direct discriminating assertions.
base=n.rows['uc_no_effect']['center_bgr']
assert n.rows['uc_att_r']['center_bgr'][0] < base[0] and n.rows['uc_att_r']['center_bgr'][1:] == base[1:]
assert n.rows['uc_att_g']['center_bgr'][1] < base[1] and n.rows['uc_att_g']['center_bgr'][0] == base[0] and n.rows['uc_att_g']['center_bgr'][2] == base[2]
assert n.rows['uc_att_b']['center_bgr'][2] < base[2] and n.rows['uc_att_b']['center_bgr'][:2] == base[:2]
b0=n.rows['uc_bg_base']['center_bgr']
assert n.rows['uc_bg_r']['center_bgr'][0] > b0[0] and n.rows['uc_bg_r']['center_bgr'][1:] == b0[1:]
assert n.rows['uc_bg_g']['center_bgr'][1] > b0[1] and n.rows['uc_bg_g']['center_bgr'][0] == b0[0] and n.rows['uc_bg_g']['center_bgr'][2] == b0[2]
assert n.rows['uc_bg_b']['center_bgr'][2] > b0[2] and n.rows['uc_bg_b']['center_bgr'][:2] == b0[:2]
ranges=[n.rows[f'uc_range_{d}m']['center_bgr'] for d in (1,2,4,6)]
for c in range(3):
  assert all(ranges[i][c] > ranges[i+1][c] for i in range(3)), (c,ranges)
out={'variant_tags':variants,'rows':n.rows,'assertions':{'each_attenuation_tag_changes_only_same_array_index':True,'each_background_tag_changes_only_same_array_index':True,'range_curve_strictly_decreases_all_bgr_channels':True},'range_center_bgr':dict(zip(('1m','2m','4m','6m'),ranges))}
(root/'run/results.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out['assertions'],indent=2)); print(json.dumps(out['range_center_bgr'],indent=2))
n.destroy_node(); rclpy.shutdown()
