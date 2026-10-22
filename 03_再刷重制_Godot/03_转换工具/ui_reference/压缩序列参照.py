#!/usr/bin/env python3
"""把 __seqRef.suite() 写出的 action_sequence_oracle.json（截图目录）压缩成 Godot 测试用的
01_Godot工程/tests/fixtures/action_sequence_oracle.json。用法：python3 -I 压缩序列参照.py [源文件]"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
src = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "04_验证/本地结果/原版参照/action_sequence_oracle.json"
# 第二个参数：输出文件名（另跑几招的读数，如 action_sequence_hp_oracle.json）
dst = ROOT / "01_Godot工程/tests/fixtures" / (sys.argv[2] if len(sys.argv) > 2 else "action_sequence_oracle.json")
d = json.loads(src.read_text())
out = {"note": "由 ui_reference __seqRef.suite() 压缩（压缩序列参照.py）：战斗夹具 4 人（1/8/9/10）、敌群 2，单体技能目标是敌群成员 1"
       "（敌人选择窗第一项），动画图先载好。cmds：[帧, 指令]；frames 行：[镜头层 x, y, 缩放, 镜头点 x, y, 窗口层隐藏, 日志行数]；"
       "sprites：{战斗者: 每帧 [不透明度, 浮空率, 跳跃率, 动作, 身体锚点 y]}（只收有变化的战斗者与行动者）；"
       "anims（新读数才有）：每帧 [[目标, 动画 x − 目标 x, 动画 y − 目标 y]…]。", "traces": {}}
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
    # 动画相对目标精灵的位置 [目标, dx, dy] 逐帧（只收有目标、已定位的；还在 _delay 里的停在 0,0 不收）；旧读数没有这一项
    if t["frames"] and "anims" in t["frames"][0]:
        pos = lambda f, kk: f["sprites"][keys.index(kk)]
        out["traces"][k]["anims"] = [[[a[0], round(a[1] - pos(f, a[0])[0], 3), round(a[2] - pos(f, a[0])[1], 3)]
                                      for a in f["anims"] if a[0] and (a[1] or a[2])] for f in t["frames"]]
    # 敌人 HP（实际值、血条显示值）逐帧；旧读数没有这一项
    if t["frames"] and "hp" in t["frames"][0]:
        out["traces"][k]["hp"] = {keys[j]: [f["hp"][j] for f in t["frames"]] for j in range(len(keys)) if keys[j].startswith("e")}
dst.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
print(dst, dst.stat().st_size)
