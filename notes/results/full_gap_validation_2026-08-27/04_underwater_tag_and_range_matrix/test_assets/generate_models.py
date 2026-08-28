from pathlib import Path
import json
root=Path(__file__).parent/'models'
root.mkdir(parents=True,exist_ok=True)
variants={
 'uc_no_effect':{},
 'uc_att_r':{'attenuationR':0.8},
 'uc_att_g':{'attenuationG':0.8},
 'uc_att_b':{'attenuationB':0.8},
 'uc_bg_base':{'attenuationR':0.8,'attenuationG':0.8,'attenuationB':0.8},
 'uc_bg_r':{'attenuationR':0.8,'attenuationG':0.8,'attenuationB':0.8,'backgroundR':85},
 'uc_bg_g':{'attenuationR':0.8,'attenuationG':0.8,'attenuationB':0.8,'backgroundG':107},
 'uc_bg_b':{'attenuationR':0.8,'attenuationG':0.8,'attenuationB':0.8,'backgroundB':47},
 'uc_range_1m':{'attenuationR':0.2,'attenuationG':0.2,'attenuationB':0.2},
 'uc_range_2m':{'attenuationR':0.2,'attenuationG':0.2,'attenuationB':0.2},
 'uc_range_4m':{'attenuationR':0.2,'attenuationG':0.2,'attenuationB':0.2},
 'uc_range_6m':{'attenuationR':0.2,'attenuationG':0.2,'attenuationB':0.2},
}
for name,tags in variants.items():
    tagtext='\n'.join(f'          <{k}>{v}</{k}>' for k,v in tags.items())
    sdf=f'''<?xml version="1.0"?>
<sdf version="1.10">
  <model name="{name}">
    <static>true</static>
    <link name="camera_link">
      <sensor name="{name}" type="rgbd_camera">
        <update_rate>10</update_rate>
        <visualize>false</visualize>
        <always_on>true</always_on>
        <topic>{name}</topic>
        <camera>
          <horizontal_fov>1.05</horizontal_fov>
          <image><width>320</width><height>240</height></image>
          <clip><near>0.1</near><far>10.0</far></clip>
        </camera>
        <plugin filename="UnderwaterCamera" name="dave_gz_sensor_plugins::UnderwaterCamera">
{tagtext}
        </plugin>
      </sensor>
    </link>
  </model>
</sdf>
'''
    d=root/name; d.mkdir(exist_ok=True); (d/'model.sdf').write_text(sdf)
(root.parent/'variants.json').write_text(json.dumps(variants,indent=2)+'\n')
