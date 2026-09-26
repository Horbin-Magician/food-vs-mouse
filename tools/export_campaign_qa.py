#!/usr/bin/env python3
"""Build non-distributed release QA entrypoints with byte-identical game sources.
Official release templates disallow external --script overrides. The QA app adds
only harness scripts; the distributable export remains tools/export_macos.py.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--template', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
engine = os.environ.get('GODOT_BIN', '/Applications/Godot.app/Contents/MacOS/Godot')
with tempfile.TemporaryDirectory(prefix='kitchen-release-qa-') as temporary:
    stage = Path(temporary)
    for folder in ['scripts','scenes','resources','assets']:
        shutil.copytree(root/folder,stage/folder)
    hashes = {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest()
              for folder in ['scripts','scenes','resources','assets']
              for p in (root/folder).rglob('*') if p.is_file()}
    assert all(hashlib.sha256((stage/name).read_bytes()).hexdigest()==digest for name,digest in hashes.items())
    Path('/tmp/kitchen-qa-source-hashes.json').write_text(json.dumps(hashes,indent=2))
    for name in ['project.godot','icon.svg','export_presets.cfg']:
        shutil.copy2(root/name,stage/name)
    project=stage/'project.godot'
    project.write_text(project.read_text().replace('res://scenes/front_end.tscn','res://scenes/qa_dispatch.tscn'))
    helper='\nfunc require(condition: bool, message: String = "validation failed") -> void:\n\tif not condition:\n\t\tFileAccess.open("/tmp/kitchen-qa-failure.txt",FileAccess.WRITE).store_string(message)\n\t\tpush_error(message)\n\t\tget_tree().quit(1)\n\nfunc quit(code: int = 0) -> void:\n\tget_tree().quit(code)\n'
    base=(root/'tests/autoplay.gd').read_text().replace('extends SceneTree','extends Node').replace('assert(','require(')+helper
    (stage/'scenes/qa_autoplay.gd').write_text(base)
    growth=(root/'tests/progression_autoplay.gd').read_text().replace('res://tests/autoplay.gd','res://scenes/qa_autoplay.gd').replace('assert(','require(')
    growth=growth.replace('\tprint("PROGRESSION ", JSON.stringify(report))','\tFileAccess.open("/tmp/kitchen-qa-growth.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))\n\tprint("PROGRESSION ", JSON.stringify(report))')
    (stage/'scenes/qa_growth.gd').write_text(growth)
    stress=(root/'tests/stress.gd').read_text().replace('run.saves.folder.path_join("stress.json")','"/tmp/kitchen-qa-stress%d.json" % run.state.units.size()')
    (stage/'scenes/qa_stress.gd').write_text(stress)
    status=(root/'tests/status_stress.gd').read_text().replace('res://tests/stress.gd','res://scenes/qa_stress.gd')
    (stage/'scenes/qa_status.gd').write_text(status)
    (stage/'scenes/qa_dispatch.gd').write_text('extends Node\nfunc _ready() -> void:\n\tif "--stress" in OS.get_cmdline_user_args(): add_child(load("res://scenes/qa_status.gd").new())\n\telse: add_child(load("res://scenes/qa_growth.gd").new())\n')
    (stage/'scenes/qa_dispatch.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scenes/qa_dispatch.gd" id="1"]\n[node name="QA" type="Node"]\nscript = ExtResource("1")\n')
    preset=stage/'export_presets.cfg'
    preset.write_text(preset.read_text().replace('custom_template/release=""','custom_template/release="'+str(args.template.resolve())+'"').replace('games.foodvsmouse.midnightkitchen','games.foodvsmouse.qa'))
    subprocess.run([engine,'--headless','--path',temporary,'--editor','--import','--quit'],check=True)
    subprocess.run([engine,'--headless','--path',temporary,'--export-release','macOS',str(args.output.resolve())],check=True)
