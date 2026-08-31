#!/usr/bin/env python3
from pathlib import Path
import ast, hashlib, json, re, sys
root=Path(sys.argv[1] if len(sys.argv)>1 else '/Users/gwon-yeseol/dave_ws_lyrical/src/dave')
out=Path(sys.argv[2] if len(sys.argv)>2 else '.')
scope=(sys.argv[3] if len(sys.argv)>3 else 'source inventory only; do not infer runtime image contents')
variants=['bluerov2','bluerov2_heavy','bluerov2_heavy_multibeam_sonar']
rows=[]
for v in variants:
    sdf=root/'models/dave_robot_models/description'/v/'model.sdf'
    cfg=root/'models/dave_robot_models/config'/v/'robot_config.py'
    text=sdf.read_text()
    sensors=[]
    for m in re.finditer(r'<sensor\s+name="([^"]+)"\s+type="([^"]+)"(?:\s+gz:type="([^"]+)")?>(.*?)</sensor>',text,re.S):
        body=m.group(4)
        topic=re.search(r'<topic>(.*?)</topic>',body,re.S)
        sensors.append({'name':m.group(1),'type':m.group(3) or m.group(2),'explicit_topic':topic.group(1).strip() if topic else None})
    cfg_text=cfg.read_text()
    tree=ast.parse(cfg_text)
    bridges=[]
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id.endswith('_arguments') for t in node.targets) and isinstance(node.value, ast.List):
            for elt in node.value.elts:
                rendered=ast.unparse(elt)
                if '/model/' in rendered or 'namespace' in rendered:
                    bridges.append(rendered)
    rows.append({'variant':v,'model_sdf':str(sdf),'model_sha256':hashlib.sha256(sdf.read_bytes()).hexdigest(),'declared_sensors':sensors,'configured_bridge_source_lines':bridges,'declares_magnetometer_sensor':any(s['type']=='magnetometer' for s in sensors),'declares_pressure_sensor':any('pressure' in s['type'] for s in sensors)})
out.mkdir(parents=True,exist_ok=True)
(out/'source_inventory.json').write_text(json.dumps({'source_root':str(root),'scope':scope,'variants':rows},indent=2)+'\n')
for r in rows:
    print(r['variant'])
    for s in r['declared_sensors']: print(' ',s)
    print(' magnetometer declared:',r['declares_magnetometer_sensor'],'pressure declared:',r['declares_pressure_sensor'])
