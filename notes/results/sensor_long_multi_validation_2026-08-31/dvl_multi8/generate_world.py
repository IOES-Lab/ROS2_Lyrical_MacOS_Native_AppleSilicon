#!/usr/bin/env python3
from pathlib import Path
import re, sys
src=Path(sys.argv[1]); out=Path(sys.argv[2])
models=['nortek_dvl500_300','nortek_dvl500_6000','nortek_dvl1000_300','nortek_dvl1000_4000','sonardyne_syrinx600','teledyne_explorer1000','teledyne_explorer4000','teledyne_whn']
blocks=[]
for i,name in enumerate(models):
 text=(src/name/'model.sdf').read_text()
 m=re.search(r'(<model\b.*?</model>)',text,re.S)
 if not m: raise RuntimeError(name)
 block=m.group(1)
 block=re.sub(r'<model\s+name="[^"]+">',f'<model name="{name}">\n      <pose>{(i%4)*8-12} {(i//4)*8-4} 0 0 0 0</pose>',block,count=1)
 block=block.replace('/dvl/velocity',f'/dvl/{name}')
 blocks.append(block)
world='''<?xml version="1.0"?>
<sdf version="1.10">
  <world name="dvl_multi8">
    <physics name="1ms" type="ignored"><max_step_size>0.001</max_step_size><real_time_factor>1.0</real_time_factor></physics>
    <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
    <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
    <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
    <plugin filename="gz-sim-sensors-system" name="gz::sim::systems::Sensors"><render_engine>ogre</render_engine></plugin>
    <plugin filename="gz-sim-dvl-system" name="gz::sim::systems::DopplerVelocityLogSystem"/>
    <light type="directional" name="sun"><direction>0 0 -1</direction><cast_shadows>false</cast_shadows></light>
    <model name="bottom"><static>true</static><pose>0 0 -20.5 0 0 0</pose><link name="link"><collision name="collision"><geometry><box><size>100 100 1</size></box></geometry></collision><visual name="visual"><geometry><box><size>100 100 1</size></box></geometry></visual></link></model>
'''+''.join('\n    '+b.replace('\n','\n    ') for b in blocks)+'''\n  </world>\n</sdf>\n'''
out.write_text(world)
print(out)
