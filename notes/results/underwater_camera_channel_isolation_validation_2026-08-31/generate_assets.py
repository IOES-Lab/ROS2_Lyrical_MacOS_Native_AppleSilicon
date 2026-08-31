from pathlib import Path
root = Path(__file__).resolve().parent
models = root/'test_assets'/'models'
variants = {
 'ucam_control':       dict(a=(0.0,0.0,0.0), b=(0,0,0)),
 'ucam_atten_base':    dict(a=(0.5,0.5,0.5), b=(0,0,0)),
 'ucam_atten_r_only':  dict(a=(0.5,0.0,0.0), b=(0,0,0)),
 'ucam_atten_g_only':  dict(a=(0.0,0.5,0.0), b=(0,0,0)),
 'ucam_atten_b_only':  dict(a=(0.0,0.0,0.5), b=(0,0,0)),
 'ucam_bg_r_only':     dict(a=(0.5,0.5,0.5), b=(200,0,0)),
 'ucam_bg_g_only':     dict(a=(0.5,0.5,0.5), b=(0,200,0)),
 'ucam_bg_b_only':     dict(a=(0.5,0.5,0.5), b=(0,0,200)),
}
for name,v in variants.items():
    d=models/name; d.mkdir(parents=True,exist_ok=True)
    ar,ag,ab=v['a']; br,bg,bb=v['b']
    (d/'model.config').write_text(f'''<?xml version="1.0"?>\n<model><name>{name}</name><version>1.0</version><sdf version="1.10">model.sdf</sdf></model>\n''')
    (d/'model.sdf').write_text(f'''<?xml version="1.0"?>
<sdf version="1.10">
  <model name="{name}">
    <static>true</static>
    <link name="camera_link">
      <sensor name="{name}" type="rgbd_camera">
        <update_rate>10</update_rate><visualize>false</visualize><always_on>true</always_on>
        <topic>{name}</topic>
        <camera><horizontal_fov>1.05</horizontal_fov><image><width>320</width><height>240</height></image><clip><near>0.1</near><far>10.0</far></clip></camera>
        <plugin filename="UnderwaterCamera" name="dave_gz_sensor_plugins::UnderwaterCamera">
          <attenuationR>{ar}</attenuationR><attenuationG>{ag}</attenuationG><attenuationB>{ab}</attenuationB>
          <backgroundR>{br}</backgroundR><backgroundG>{bg}</backgroundG><backgroundB>{bb}</backgroundB>
        </plugin>
      </sensor>
    </link>
  </model>
</sdf>\n''')
includes='\n'.join(f'''    <include><uri>model://{n}</uri><name>{n}</name><pose>0 0 0 0 0 0</pose></include>''' for n in variants)
world=f'''<?xml version="1.0"?>
<sdf version="1.10"><world name="camera_channel_isolation">
  <physics name="1ms" type="ignored"><max_step_size>0.001</max_step_size><real_time_factor>1.0</real_time_factor></physics>
  <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
  <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
  <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
  <plugin filename="gz-sim-sensors-system" name="gz::sim::systems::Sensors"><render_engine>ogre</render_engine></plugin>
  <scene><ambient>0.6 0.6 0.6 1</ambient><background>0.05 0.05 0.05 1</background><shadows>false</shadows></scene>
  <light type="directional" name="validation_light"><pose>0 0 5 0 0 0</pose><diffuse>1 1 1 1</diffuse><specular>0 0 0 1</specular><direction>-1 0 -0.2</direction><cast_shadows>false</cast_shadows></light>
  <model name="planar_target"><static>true</static><pose>4 0 0 0 0 0</pose><link name="target_link">
    <collision name="target_collision"><geometry><box><size>0.05 8 8</size></box></geometry></collision>
    <visual name="target_visual"><geometry><box><size>0.05 8 8</size></box></geometry><material><ambient>0.8 0.4 0.2 1</ambient><diffuse>0.8 0.4 0.2 1</diffuse><specular>0 0 0 1</specular></material></visual>
  </link></model>
{includes}
</world></sdf>\n'''
(root/'test_assets'/'camera_channel_isolation.world').write_text(world)
(root/'test_assets'/'variants.json').write_text(__import__('json').dumps(variants,indent=2))
print(f'generated {len(variants)} variants')
