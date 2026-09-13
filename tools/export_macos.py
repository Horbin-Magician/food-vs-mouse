#!/usr/bin/env python3
"""Export using official macos.zip without installing templates globally."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--template", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
engine = os.environ.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot")
root = Path(__file__).resolve().parents[1]
assert args.template.is_file()
args.output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="food-vs-mouse-export-") as temporary:
    stage = Path(temporary)
    for folder in ["scripts", "scenes", "resources", "assets"]:
        if (root / folder).exists():
            shutil.copytree(root / folder, stage / folder)
    for filename in ["project.godot", "icon.svg", "export_presets.cfg"]:
        shutil.copy2(root / filename, stage / filename)
    preset = stage / "export_presets.cfg"
    preset.write_text(preset.read_text().replace('custom_template/release=""', 'custom_template/release="' + str(args.template.resolve()) + '"'))
    subprocess.run([engine, "--headless", "--path", temporary, "--log-file", str(stage / "import.log"), "--editor", "--import", "--quit"], check=True)
    subprocess.run([engine, "--headless", "--path", temporary, "--log-file", str(stage / "export.log"), "--export-release", "macOS", str(args.output.resolve())], check=True)
print(args.output.resolve())
