#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORLD_DIR = ROOT / "test_assets" / "worlds"
SENSOR_X = 4.0

CASES = {
    "plane_2m_dark": ("box", 2.0, "0.1 0.1 0.1 1"),
    "plane_4m_dark": ("box", 4.0, "0.1 0.1 0.1 1"),
    "plane_4m_bright": ("box", 4.0, "0.9 0.9 0.9 1"),
    "plane_7m_dark": ("box", 7.0, "0.1 0.1 0.1 1"),
    "sphere_4m_bright": ("sphere", 4.0, "0.9 0.9 0.9 1"),
    "cylinder_4m_bright": ("cylinder", 4.0, "0.9 0.9 0.9 1"),
}


def geometry(kind: str, expected_range: float) -> tuple[float, str]:
    if kind == "box":
        center_x = SENSOR_X - expected_range - 0.01
        return center_x, "<box><size>0.02 12 12</size></box>"
    if kind == "sphere":
        center_x = SENSOR_X - expected_range - 0.5
        return center_x, "<sphere><radius>0.5</radius></sphere>"
    if kind == "cylinder":
        center_x = SENSOR_X - expected_range - 0.5
        return center_x, "<cylinder><radius>0.5</radius><length>12</length></cylinder>"
    raise ValueError(kind)


def world_text(name: str, kind: str, expected_range: float, color: str) -> str:
    center_x, geom = geometry(kind, expected_range)
    return f'''<?xml version="1.0"?>
<sdf version="1.7">
  <world name="{name}">
    <physics name="1ms" type="ignored">
      <max_step_size>0.001</max_step_size>
      <real_time_factor>1.0</real_time_factor>
    </physics>
    <plugin filename="gz-sim-physics-system" name="gz::sim::systems::Physics"/>
    <plugin filename="gz-sim-sensors-system" name="gz::sim::systems::Sensors">
      <render_engine>ogre2</render_engine>
    </plugin>
    <plugin filename="gz-sim-user-commands-system" name="gz::sim::systems::UserCommands"/>
    <plugin filename="gz-sim-scene-broadcaster-system" name="gz::sim::systems::SceneBroadcaster"/>
    <plugin filename="multibeam_sonar_system" name="custom::MultibeamSonarSystem"/>
    <scene>
      <ambient>0.5 0.5 0.5 1</ambient>
      <background>0.05 0.05 0.05 1</background>
    </scene>
    <model name="target">
      <static>true</static>
      <pose>{center_x:.6f} 0 2 0 0 0</pose>
      <link name="target_link">
        <collision name="target_collision">
          <geometry>{geom}</geometry>
        </collision>
        <visual name="target_visual">
          <geometry>{geom}</geometry>
          <material>
            <ambient>{color}</ambient>
            <diffuse>{color}</diffuse>
          </material>
        </visual>
      </link>
    </model>
  </world>
</sdf>
'''


WORLD_DIR.mkdir(parents=True, exist_ok=True)
for case, (kind, expected_range, color) in CASES.items():
    path = WORLD_DIR / f"{case}.world"
    path.write_text(world_text(case, kind, expected_range, color))
    print(f"{path}: kind={kind} expected_range={expected_range}")
