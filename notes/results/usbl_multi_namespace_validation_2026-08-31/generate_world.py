from pathlib import Path
root=Path(__file__).resolve().parent
models=[]
def transceiver(ns,name,x):
 return f'''  <model name="{name}"><static>true</static><pose>{x} 0 0 0 0 0</pose><link name="link"/>
    <plugin filename="UsblTransceiver" name="dave_gz_sensor_plugins::UsblTransceiver">
      <namespace>{ns}</namespace><transceiver_device>transceiver</transceiver_device><transponder_device>transponder</transponder_device>
      <transponder_ID>1,2</transponder_ID><transceiver_ID>168</transceiver_ID><enable_ping_scheduler>false</enable_ping_scheduler>
      <interrogation_mode>common</interrogation_mode><ping_frequency>0.5</ping_frequency>
      <transponder_attached_object>{name}_tp1,{name}_tp2</transponder_attached_object><sound_speed>1540</sound_speed>
    </plugin></model>'''
def transponder(ns,txname,tid,x,y):
 name=f'{txname}_tp{tid}'
 return f'''  <model name="{name}"><static>true</static><pose>{x} {y} 0.5 0 0 0</pose><link name="link"/>
    <plugin filename="UsblTransponder" name="dave_gz_sensor_plugins::UsblTransponder">
      <namespace>{ns}</namespace><transponder_device>transponder</transponder_device><transponder_ID>{tid}</transponder_ID>
      <transceiver_device>transceiver</transceiver_device><transceiver_ID>168</transceiver_ID><transceiver_model>{txname}</transceiver_model>
      <sound_speed>1540</sound_speed><mu>0</mu><sigma>0</sigma>
    </plugin></model>'''
for ns,tx,base in [('USBL_A','tx_a',0),('USBL_B','tx_b',100)]:
 models += [transceiver(ns,tx,base),transponder(ns,tx,1,base+3,4),transponder(ns,tx,2,base+6,8)]
world='''<?xml version="1.0"?>
<sdf version="1.10"><world name="usbl_multi_namespace">
  <physics name="1ms" type="ignored"><max_step_size>0.001</max_step_size><real_time_factor>1.0</real_time_factor></physics>
  <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
  <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
  <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
'''+"\n".join(models)+'''\n</world></sdf>\n'''
(root/'test_assets'/'usbl_multi_namespace.world').write_text(world)
print('world generated')
