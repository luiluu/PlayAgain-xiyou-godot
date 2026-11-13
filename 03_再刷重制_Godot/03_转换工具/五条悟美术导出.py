#!/usr/bin/env python3
"""五条悟正式美术导出（2026-11-12 Kyo 定稿，源在主工作区 02_内容与素材/新美术/五条悟/，Git 排除）。

成品写到 01_Godot工程/content/gojo/（XGojo 读）：
- Codex_Gojo_Face.png：头像母图 1024 绿底 → 抠绿、缩 144，放进 576×288 头像表的第 1 格。
- icons/NN.png：技能、被动、进阶、眼罩图标母图 1024 绿底 → 抠绿、缩 128（XGojo.ICONS 的顺序号）。
- domain_bg.png：无量空处领域背景 1280×720，原样拷贝。
- $Codex_Gojo_Walk.png、Codex_Gojo_SV.png：定稿行走图、战斗图，原样拷贝。
没有 PIL，用 ffmpeg。用法：python3 五条悟美术导出.py [源目录]
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "01_Godot工程", "content", "gojo")
DEFAULT_SRC = os.path.expanduser("~/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/新美术/五条悟")
KEY = "colorkey=0x00ff00:0.32:0.08,despill=type=green"

# 图标：成品号（XGojo.ICONS 里的序号）→ 源文件（相对源目录）
ICONS = {
    2: "技能图标/02_五条悟_咒力打击_绿底_1024.png",
    3: "技能图标/03_五条悟_术式顺转_苍_绿底_1024.png",
    4: "技能图标/04_五条悟_术式反转_赫_绿底_1024.png",
    5: "技能图标/05_五条悟_反转术式_绿底_1024.png",
    6: "技能图标/06_五条悟_苍_最大出力_绿底_1024.png",
    7: "技能图标/07_五条悟_赫_最大出力_绿底_1024.png",
    8: "技能图标/08_五条悟_虚式_茈_收_绿底_1024.png",
    9: "技能图标/09_五条悟_虚式_茈_放_绿底_1024.png",
    10: "技能图标/10_五条悟_领域展开_无量空处_绿底_1024.png",
    11: "被动图标/11_五条悟_六眼_绿底_1024.png",
    12: "被动图标/12_五条悟_无下限_绿底_1024.png",
    13: "被动图标/13_五条悟_最强_绿底_1024.png",
    14: "被动图标/14_五条悟_黑闪觉醒_定稿_绿底_1024.png",
    15: "进阶图标/15_五条悟_茈收束_绿底_1024.png",
    16: "进阶图标/16_五条悟_茈贯穿_绿底_1024.png",
    17: "进阶图标/17_五条悟_自动反转_绿底_1024.png",
    18: "法宝图标/18_五条悟_眼罩法宝_绿底_1024.png",
}


def ff(src, dst, vf):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-vf", vf, "-frames:v", "1", dst], check=True)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    for n, rel in ICONS.items():
        ff(os.path.join(src, rel), os.path.join(OUT, "icons", "%02d.png" % n), "format=rgba,%s,scale=128:128:flags=lanczos,format=rgba" % KEY)
    ff(os.path.join(src, "头像/01_五条悟_常态头像_绿底_1024.png"), os.path.join(OUT, "Codex_Gojo_Face.png"),
       "format=rgba,%s,scale=144:144:flags=lanczos,pad=576:288:0:0:color=black@0,format=rgba" % KEY)
    shutil.copyfile(os.path.join(src, "领域背景/gojo_unlimited_void_background.png"), os.path.join(OUT, "domain_bg.png"))
    shutil.copyfile(os.path.join(src, "行走图/$Codex_Gojo_Walk.png"), os.path.join(OUT, "$Codex_Gojo_Walk.png"))
    shutil.copyfile(os.path.join(src, "战斗精灵/Codex_Gojo_SV.png"), os.path.join(OUT, "Codex_Gojo_SV.png"))
    print("五条悟美术导出：图标 %d 张、头像、领域背景、行走图、战斗图 → %s" % (len(ICONS), os.path.normpath(OUT)))


if __name__ == "__main__":
    main()
