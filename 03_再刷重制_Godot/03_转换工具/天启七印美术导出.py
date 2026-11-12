#!/usr/bin/env python3
"""天启篇七印祭坛美术（TianqiQiyin_v1，2026-11-12 定稿 26 项）→ 游戏读的成品图 content/tianqi/qiyin/。

源：03_再刷重制_Godot/02_内容与素材/新美术/TianqiQiyin_v1/（Git 排除，原稿不进仓库；zip 先解到 _unzipped/，本脚本会自己解）。
只写 01_Godot工程/content/tianqi/qiyin/，不碰源目录以外的东西。重跑覆盖同名文件。

- 首领战斗图（E1～E3）：母版画布裁到脚底基线（anchor 0.5,1），lanczos 缩到逻辑尺寸（M 档 1024→256、L 档 2048→512，×0.25），
  引擎按 1 倍画；七首之龙躯干与七首分层（同画布原位），守默者平时／燃起两张。
- 七印徽记 S1、神器大图 P1～P5、龙隙 P6、头像框 P7、法阵 P8：原样拷贝，按七印键改名。
- 图标 I1～I10、O1～O3：32×32 原样拷贝，按键改名。

用法：python3 天启七印美术导出.py [--src 源目录]
"""
import argparse
import os
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # 03_再刷重制_Godot
DEFAULT_SRC = os.path.join(os.path.expanduser("~"), "Documents", "再刷项目资料库", "03_再刷重制_Godot",
                           "02_内容与素材", "新美术", "TianqiQiyin_v1")
OUT = os.path.join(ROOT, "01_Godot工程", "content", "tianqi", "qiyin")

# 美术文件编号 01～07 → 七印键（qiyin_show.json seals 顺序）
SEALS = ["bai", "hong", "hei", "hui", "xun", "zhen", "mo"]
SEAL_EN = ["white", "red", "black", "gray", "martyr", "quake", "silence"]
PARTS = ["head", "body", "hands", "waist", "legs", "feet"]  # 美术 01～06：helm／crown、cuirass、gauntlets、belt、greaves、boots
SET_DIRS = ["I1_白印胜而又胜_v3", "I2_红印太平已死", "I3_黑印斤斤计较", "I4_灰印阴府随行", "I5_殉印要到几时", "I6_震印天卷", "I7_默印二刻"]
WEAPONS_A = {"01_bow": "bow", "02_needle": "hidden", "03_sword": "sword", "04_axe": "axe", "05_gun": "gun", "06_fist": "fist"}
WEAPONS_B = {"01_katana": "katana", "02_dagger": "dagger", "03_mace": "blunt", "04_spear": "spear", "05_staff": "staff",
             "06_book": "book", "07_scroll_overlay": "overlay"}
ARTIFACTS = {"01_bow_and_crown": "bow_crown", "02_war_blade": "great_sword", "03_scales": "scales",
             "04_ashen_scythe": "grey_scythe", "05_seven_seals_scroll": "seven_seal_scroll"}
ARTIFACT_BIG = {"P1_弓与冠_v3": "bow_crown", "P2_夺和大刀": "great_sword", "P3_天平": "scales", "P4_灰镰": "grey_scythe",
                "P5_七印书卷": "seven_seal_scroll"}
ITEMS = {"01_seal_key": "seal_key", "02_wax_shards": "shards", "03_verdict_page": "page", "04_dragon_blood": "dragon_blood",
         "05_sealed_gear": "sealed"}
RULES = {"01_不愈": "no_cure", "02_杀声": "war_cry", "03_限时": "exam", "04_魔塔": "magic_tower", "05_献祭": "sacrifice",
         "06_星坠": "star_fall", "07_寂静": "silence"}
EFFECTS = {"01_疫": "plague", "02_砝码": "weight", "03_判决": "verdict", "04_陨月": "fallen_moon", "05_天书页": "book_page",
           "06_连斩": "chain_cut", "07_缓期": "reprieve", "08_龙血": "dragon_blood"}
RELICS = {"01_替身的钥匙串": "death", "02_最后一枚雷火弹": "war", "03_没写完的卷子": "famine", "04_混子之盾（碎）": "plague"}
BADGES = {"01_死亡骑士徽记": "death", "02_战争骑士徽记": "war", "03_饥荒骑士徽记": "famine", "04_瘟疫骑士徽记": "plague"}


def unzip_all(src):
    unz = os.path.join(src, "_unzipped")
    for dirpath, _, files in os.walk(src):
        if dirpath.startswith(unz):
            continue
        for f in files:
            if f.endswith(".zip"):
                dest = os.path.join(unz, f[:-4])
                if not os.path.isdir(dest):
                    with zipfile.ZipFile(os.path.join(dirpath, f)) as z:
                        z.extractall(dest)
    return unz


def find_dir(unz, prefix):
    for d in sorted(os.listdir(unz)):
        if d.startswith(prefix):
            return os.path.join(unz, d)
    sys.exit("缺素材包：" + prefix)


def copy(src, dst):
    if not os.path.isfile(src):
        sys.exit("缺文件：" + src)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copyfile(src, dst)


def boss(src, dst, canvas, baseline, factor=4):
    """裁到基线、缩到逻辑尺寸（lanczos，透明照留）"""
    if not os.path.isfile(src):
        sys.exit("缺文件：" + src)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    w, h = canvas // factor, baseline // factor
    vf = "crop=%d:%d:0:0,scale=%d:%d:flags=lanczos,format=rgba" % (canvas, baseline, w, h)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-vf", vf, "-frames:v", "1", dst], check=True)


def icons(pack, mapping, out_dir, prefix):
    for stem, key in mapping.items():
        copy(os.path.join(pack, "icons_32", stem + ".png"), os.path.join(out_dir, prefix + key + ".png"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    a = ap.parse_args()
    src = a.src
    unz = unzip_all(src)
    ic = os.path.join(OUT, "icons")
    bt = os.path.join(OUT, "battlers")

    # E1 七首之龙：躯干＋七首，L 档 2048 画布、基线 1856
    dragon = os.path.join(find_dir(unz, "七首之龙"), "SevenSealDragon_v1", "parts")
    boss(os.path.join(dragon, "body.png"), os.path.join(bt, "Tianqi_Qiyin_Dragon.png"), 2048, 1856)
    for k, en in zip(SEALS, SEAL_EN):
        boss(os.path.join(dragon, "head_%s.png" % en), os.path.join(bt, "Tianqi_Qiyin_Dragon_%s.png" % k), 2048, 1856)
    # E2 白衣的魂、E3 守默者：M 档 1024、基线 928
    boss(os.path.join(src, "白衣的魂", "E2_白衣的魂_透明战斗站姿_1024.png"), os.path.join(bt, "Tianqi_Qiyin_WhiteSoul.png"), 1024, 928)
    silent = find_dir(unz, "E3_守默者")
    boss(os.path.join(silent, "pose_normal.png"), os.path.join(bt, "Tianqi_Qiyin_Silent.png"), 1024, 928)
    boss(os.path.join(silent, "pose_ignited.png"), os.path.join(bt, "Tianqi_Qiyin_Silent_lit.png"), 1024, 928)

    # S1 徽记、P7 头像框、P8 法阵：按七印键
    for i, k in enumerate(SEALS):
        n = "%02d_%s.png" % (i + 1, SEAL_EN[i])
        copy(os.path.join(find_dir(unz, "S1_"), "badges_256", n), os.path.join(OUT, "seals", k + ".png"))
        copy(os.path.join(find_dir(unz, "P7_"), "frames_128", n), os.path.join(OUT, "frames", k + ".png"))
        copy(os.path.join(find_dir(unz, "P8_"), "circles_512", n), os.path.join(OUT, "circles", k + ".png"))
    # P1～P5 神器大图、P6 龙隙
    for stem, key in ARTIFACT_BIG.items():
        copy(os.path.join(src, "七印神器掉落大图", stem + "_像素版_掉落大图_512.png"), os.path.join(OUT, "artifacts", key + ".png"))
    copy(os.path.join(src, "龙隙裂缝", "P6_龙隙裂缝_透明叠层_1280x720.png"), os.path.join(OUT, "rift.png"))

    # I1～I7 套装件：每印六件，文件按 01～06 排（白印头部叫 crown）
    for i, k in enumerate(SEALS):
        pack = os.path.join(find_dir(unz, SET_DIRS[i]), "icons_32")
        files = sorted(f for f in os.listdir(pack) if f.endswith(".png"))
        if len(files) != 6:
            sys.exit("套装图标不是六张：" + pack)
        for j, f in enumerate(files):
            copy(os.path.join(pack, f), os.path.join(ic, "set_%s_%s.png" % (k, PARTS[j])))
    icons(find_dir(unz, "I8A_"), WEAPONS_A, ic, "weapon_")
    icons(find_dir(unz, "I8B_"), WEAPONS_B, ic, "weapon_")
    # 「不立文字」卷轴叠在握柄上：从 128 母版按面积缩到 16（直接拿 32 图最近邻缩会糊成几卷），引擎贴左下角
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i",
                    os.path.join(find_dir(unz, "I8B_"), "masters_128", "07_scroll_overlay.png"),
                    "-vf", "scale=w=16:h=16:flags=area,format=rgba", os.path.join(ic, "weapon_overlay_16.png")], check=True)
    icons(find_dir(unz, "I9_"), ARTIFACTS, ic, "artifact_")
    icons(find_dir(unz, "I10_"), ITEMS, ic, "item_")
    icons(find_dir(unz, "O1_"), RULES, ic, "rule_")
    icons(find_dir(unz, "O2_"), EFFECTS, ic, "effect_")
    o3 = find_dir(unz, "O3_")
    for stem, key in RELICS.items():
        copy(os.path.join(o3, "icons_32", "遗物", stem + ".png"), os.path.join(ic, "relic_%s.png" % key))
        copy(os.path.join(o3, "icons_32", "遗物", stem + "_残.png"), os.path.join(ic, "relic_%s_broken.png" % key))
    for stem, key in BADGES.items():
        copy(os.path.join(o3, "icons_32", "徽记", stem + ".png"), os.path.join(ic, "badge_%s.png" % key))
    n = sum(1 for _, _, fs in os.walk(OUT) for f in fs if f.endswith(".png"))
    print("写好 %d 张图 → %s" % (n, OUT))


if __name__ == "__main__":
    main()
