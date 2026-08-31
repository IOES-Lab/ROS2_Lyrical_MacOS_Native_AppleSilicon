from pathlib import Path
root=Path(__file__).resolve().parent/'test_assets'; root.mkdir(parents=True,exist_ok=True)
def world(name, noise=False, tide=False):
 nvel='0.15' if noise else '0.0'; nang='0.08' if noise else '0.0'; mu='0.2' if noise else '0.0'
 tidal='''
      <tidal_oscillation>
        <harmonic_constituents>
          <M2><amp>100</amp><phase>0</phase><speed>3600</speed></M2>
          <S2><amp>50</amp><phase>45</phase><speed>1800</speed></S2>
          <N2><amp>25</amp><phase>90</phase><speed>900</speed></N2>
        </harmonic_constituents>
        <mean_direction><ebb>0</ebb><flood>180</flood></mean_direction>
        <world_start_time_GMT><day>1</day><month>1</month><year>2026</year><hour>0</hour><minute>0</minute></world_start_time_GMT>
      </tidal_oscillation>''' if tide else ''
 return f'''<?xml version="1.0"?>
<sdf version="1.10"><world name="{name}">
  <physics name="fast" type="ignored"><max_step_size>0.01</max_step_size><real_time_factor>100</real_time_factor></physics>
  <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
  <plugin filename="OceanCurrentWorldPlugin" name="dave_gz_world_plugins::OceanCurrentWorldPlugin">
    <namespace>hydrodynamics</namespace>
    <constant_current><use_constant_current>true</use_constant_current><topic>ocean_current</topic>
      <velocity><mean>1</mean><min>0</min><max>2</max><mu>{mu}</mu><noiseAmp>{nvel}</noiseAmp></velocity>
      <horizontal_angle><mean>0</mean><min>-3.141592653589793</min><max>3.141592653589793</max><mu>{mu}</mu><noiseAmp>{nang}</noiseAmp></horizontal_angle>
      <vertical_angle><mean>0</mean><min>-1.5</min><max>1.5</max><mu>{mu}</mu><noiseAmp>{nang}</noiseAmp></vertical_angle>
    </constant_current>
    <transient_current><topic_stratified>stratified_current_velocity</topic_stratified><databasefileName>transientOceanCurrentDatabase.csv</databasefileName></transient_current>{tidal}
  </plugin>
  <plugin filename="OceanCurrentPlugin" name="dave_ros_gz_plugins::OceanCurrentPlugin"><namespace>hydrodynamics</namespace></plugin>
</world></sdf>\n'''
for n,noise,tide in [('baseline',False,False),('gauss_markov_noise',True,False),('extreme_harmonic_tide',False,True)]:
 (root/f'{n}.world').write_text(world(n,noise,tide))
print('generated 3 worlds')
