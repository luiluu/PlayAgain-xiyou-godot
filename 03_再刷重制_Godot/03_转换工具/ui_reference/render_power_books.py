#!/usr/bin/env python3
"""权能遗忘专项的独立窗口截图，调用方通过占槽.py 启动。临时测试用户目录，不读玩家存档。"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("godot")
p.add_argument("project")
p.add_argument("out", type=Path)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="xiyou_power_render_") as test_home:
    compiled = subprocess.run([a.godot, "--headless", "--path", a.project, "--check-only", "--script", "res://tests/xiyou_power_books_menu.gd"], env=dict(os.environ, HOME=test_home), timeout=60)
    if compiled.returncode:
        raise SystemExit(compiled.returncode)
    result = subprocess.run([a.godot, "--path", a.project, "--resolution", "1280x720", "res://tests/xiyou_power_books_menu.tscn", "--", "--out=" + str(a.out.resolve())], env=dict(os.environ, HOME=test_home), timeout=180)
raise SystemExit(result.returncode)
