#!/usr/bin/env python3
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent
base = ET.parse(root / "camera_parameter_validation.world")
poses = {
    "uc_range_1m": "3 0 0 0 0 0",
    "uc_range_2m": "2 0 0 0 0 0",
    "uc_range_4m": "0 0 0 0 0 0",
    "uc_range_6m": "-2 0 0 0 0 0",
}
out_dir = root / "single_worlds"
out_dir.mkdir(exist_ok=True)

for model_dir in sorted((root / "models").iterdir()):
    if not model_dir.is_dir():
        continue
    tree = deepcopy(base)
    world = tree.getroot().find("world")
    assert world is not None
    world.attrib["name"] = f"camera_{model_dir.name}"
    model = ET.parse(model_dir / "model.sdf").getroot().find("model")
    assert model is not None
    model = deepcopy(model)
    pose = ET.Element("pose")
    pose.text = poses.get(model_dir.name, "0 0 0 0 0 0")
    model.insert(0, pose)
    world.append(model)
    ET.indent(tree, space="  ")
    tree.write(out_dir / f"{model_dir.name}.world", encoding="unicode", xml_declaration=True)

print(f"wrote {len(list(out_dir.glob('*.world')))} worlds")
