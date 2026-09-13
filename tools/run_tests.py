#!/usr/bin/env python3
"""Run isolated Godot regression scripts; a hung assert is a failed test."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

engine = os.environ.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot")
root = Path(__file__).resolve().parents[1]
failed = []
for test in sorted((root / "tests").glob("test_*.gd")):
    try:
        result = subprocess.run([engine, "--headless", "--path", str(root), "--log-file", str(Path(tempfile.gettempdir()) / (test.stem + ".log")), "--script", str(test), "--", "--qa-test"], capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        passed = result.returncode == 0 and "PASS " in output and "SCRIPT ERROR" not in output
        print(f'{"PASS" if passed else "FAIL"} {test.name}')
        if not passed:
            print(output[-4000:])
            failed.append(test.name)
    except subprocess.TimeoutExpired as error:
        print(f"FAIL {test.name}: timed out", error.stdout)
        failed.append(test.name)
sys.exit(bool(failed))
