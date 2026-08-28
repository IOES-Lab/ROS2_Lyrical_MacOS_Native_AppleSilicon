#!/usr/bin/env python3
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent
world_path = root / "camera_parameter_validation.world"
tree = ET.parse(world_path)
world = tree.getroot().find("world")
assert world is not None

poses = {
    "uc_range_1m": "3 0 0 0 0 0",
    "uc_range_2m": "2 0 0 0 0 0",
    "uc_range_4m": "0 0 0 0 0 0",
    "uc_range_6m": "-2 0 0 0 0 0",
}

for model_dir in sorted((root / "models").iterdir()):
    if not model_dir.is_dir():
        continue
    model = ET.parse(model_dir / "model.sdf").getroot().find("model")
    assert model is not None, model_dir
    model = deepcopy(model)
    pose = ET.Element("pose")
    pose.text = poses.get(model.attrib["name"], "0 0 0 0 0 0")
    model.insert(0, pose)
    world.append(model)

ET.indent(tree, space="  ")
out = root / "camera_parameter_validation_combined.world"
tree.write(out, encoding="unicode", xml_declaration=True)
print(out)
