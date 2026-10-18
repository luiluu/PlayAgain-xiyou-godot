#!/usr/bin/env python3
"""把 __seqRef.suite() 写出的 action_sequence_oracle.json（截图目录）压缩成 Godot 测试用的
01_Godot工程/tests/fixtures/action_sequence_oracle.json。用法：python3 -I 压缩序列参照.py [源文件]"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
src = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "04_验证/本地结果/原版参照/action_sequence_oracle.json"
dst = ROOT / "01_Godot工程/tests/fixtures/action_sequence_oracle.json"
d = json.loads(src.read_text())
out = {"note": "由 ui_reference __seqRef.suite() 压缩（压缩序列参照.py）：战斗夹具 4 人（1/8/9/10）、敌群 2，单体技能目标是敌群成员 1"
       "（敌人选择窗第一项），动画图先载好。cmds：[帧, 指令]；frames 行：[镜头层 x, y, 缩放, 镜头点 x, y, 窗口层隐藏, 日志行数]；"
       "sprites：{战斗者: 每帧 [不透明度, 浮空率, 跳跃率, 动作, 身体锚点 y]}（只收有变化的战斗者与行动者）。", "traces": {}}
for k, t in d["traces"].items():
    keys = [b["key"] for b in t["battlers"]]
    keep = {"a%d" % t["actor"]}
    for f in t["frames"]:
        for j, s in enumerate(f["sprites"]):
            if s[5] != 255 or s[6] or s[7] or s[10] != 1:
                keep.add(keys[j])
    sp = {kk: [] for kk in sorted(keep)}
    for f in t["frames"]:
        for j, s in enumerate(f["sprites"]):
            if keys[j] in keep:
                sp[keys[j]].append([s[5], s[6], s[7], s[8], s[10]])
    out["traces"][k] = {"actor": t["actor"], "skill": t["skill"], "camera": t["camera"], "animation": t["animation"],
                        "speed": t["speed"], "battlers": t["battlers"], "cmds": [[c[0], c[1]] for c in t["cmds"]],
                        "frames": [[f["field"][0], f["field"][1], f["field"][2], f["zoom"][0], f["zoom"][1], 1 if f["hud"] else 0,
                                    f["lines"]] for f in t["frames"]], "sprites": sp}
dst.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
print(dst, dst.stat().st_size)
