#!/usr/bin/env python3
"""技能书容量专项的独立窗口截图，调用方通过占槽.py 启动。临时测试用户目录，不读玩家存档。"""
import argparse
import importlib.util
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
spec = importlib.util.spec_from_file_location("capacity_render_validation", Path(__file__).resolve().parents[2] / "07_开发环境/并行测试.py")
validation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validation)
with tempfile.TemporaryDirectory(prefix="xiyou_capacity_render_") as test_home:
    try:
        result = subprocess.run([a.godot, "--path", a.project, "--resolution", "1280x720", "res://tests/xiyou_book_capacity_ui.tscn", "--", "--out=" + str(a.out.resolve())], env=dict(os.environ, HOME=test_home), timeout=180, capture_output=True, text=True)
    except subprocess.TimeoutExpired as e:
        for output in [e.stdout, e.stderr]:
            if output:
                print(output.decode(errors="replace") if isinstance(output, bytes) else output, flush=True)
        raise SystemExit(142)
print(result.stdout + result.stderr, flush=True)
raise SystemExit(0 if validation.result_ok(result.returncode, result.stdout + result.stderr) else 1)
