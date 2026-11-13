#!/usr/bin/env python3
"""头部件：单独画好的头，给生成器当「头」用（配方里写「头部件」）。

原版的头在行走图 12 帧、战斗图 54 帧里都是同一张图整体平移，所以一个新角色只要画几格头：
行走图 3 格（正面、左侧面、背面），战斗图 1～3 格（常态、闭眼、吃痛），身体和动作全用原版的。

  拆头  把原版角色的头拆成一张头部件（当起稿的底子，也是规格的样板）
  体检  检查一张头部件合不合规格；有一项不合格就退出码 1

规格（体检照这个查）：
  行走图头部件  一格 48×48，按站立帧的位置画，身体的第一行是第 30 行。
                宽 144＝正面、左侧面、背面；宽 192＝正面、左侧面、右侧面、背面。
  战斗图头部件  一格 64×64，按第 1 帧的位置画（朝左），身体的第一行是第 37 行。
                宽 64／128／192＝常态、闭眼、吃痛。
  两种都可以加第二排（高 96／128）：垫在身体后面的一层，画披在背后的长发、翅膀。
  图里不透明的点全部算头，会原样盖到身体上；透明度只有 0 和 255。

依赖：Pillow、numpy。素材目录由 --素材 给。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from 行走图 import 亮度  # noqa: E402
import 生成器 as 走  # noqa: E402
import 战斗图 as 战  # noqa: E402

标准肤色 = ("#FBDCC8", "#F9C19D", "#EA9777", "#B36739", "#964B1F", "#613518")   # 原版多数角色的脸：高光、底色、阴影、深阴影、描边、最深的描边
类型表 = {
    "行走": {"格": 48, "切": 30, "宽": (144, 192), "格名": {144: ("正面", "左侧面", "背面"), 192: ("正面", "左侧面", "右侧面", "背面")},
           "最多色": 36, "脸": (14, 30, 12, 36), "头顶最低": 8, "接": 5, "肤点": {"正面": 40, "左侧面": 25, "右侧面": 25}},
    "战斗": {"格": 64, "切": 37, "宽": (64, 128, 192), "格名": {64: ("常态",), 128: ("常态", "闭眼"), 192: ("常态", "闭眼", "吃痛")},
           "最多色": 40, "脸": (16, 37, 6, 46), "头顶最低": 6, "接": 8, "肤点": {"常态": 80, "闭眼": 80, "吃痛": 80}},
}


def 色键(块):
    return (块[..., 0] << 16) | (块[..., 1] << 8) | 块[..., 2]


def 外缘(实):
    垫 = np.pad(实, 1)
    return 实 & (~垫[:-2, 1:-1] | ~垫[2:, 1:-1] | ~垫[1:-1, :-2] | ~垫[1:-1, 2:])


def 小块(实, 上限=2):
    """不超过「上限」个点、八个方向都不挨着别的点的碎块。返回点的列表。"""
    高, 宽 = 实.shape
    见 = np.zeros_like(实)
    出 = []
    for y0, x0 in zip(*np.where(实)):
        if 见[y0, x0]:
            continue
        堆, 栈 = [], [(y0, x0)]
        见[y0, x0] = True
        while 栈:
            y, x = 栈.pop()
            堆.append((int(x), int(y)))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < 高 and 0 <= xx < 宽 and 实[yy, xx] and not 见[yy, xx]:
                        见[yy, xx] = True
                        栈.append((yy, xx))
        if len(堆) <= 上限:
            出 += 堆
    return 出


# ---------- 拆头 ----------

def 拆行走头(素材: Path, 号: str, 去领口=True) -> np.ndarray:
    图 = 走.读部件(素材, 号)
    脖 = 走.找脖子行(图)
    if 去领口:
        走.去领口(图, 脖)
    摆 = 走.头的下摆(图, 脖)
    出 = np.zeros((走.格, 4 * 走.格, 4), np.int32)
    for 行 in range(走.行数):
        块 = 走.取格(图, 行, 走.站立列)
        罩 = 块[..., 3] > 0
        罩[脖:] = False
        罩 |= 走.取格(摆, 行, 走.站立列)
        移 = 走.默认脖子行 - 脖
        for y, x in zip(*np.where(罩)):
            if 0 <= y + 移 < 走.格:
                出[y + 移, 行 * 走.格 + x] = 块[y, x]
    return 出


def 拆战斗头(素材: Path, 名: str, 去领口=True) -> np.ndarray:
    图 = 战.读战斗图(素材, 名)
    分 = 战.分头(图, None, 去领口)
    出 = np.zeros((战.格, 3 * 战.格, 4), np.int32)
    帧0 = 战.取帧(图, 0)
    移y = 战.默认下巴行 - 分["下巴行"]
    y0, y1, x0, x1 = 类型表["战斗"]["脸"]
    for 序, i in enumerate((0, 6, 12)):                     # 常态＝第 1 帧，闭眼＝咏唱，吃痛＝受伤
        帧 = 战.取帧(图, i)
        dx, dy = 分["位移"][i]
        for y, x in zip(*np.where(分["头罩"][0])):            # 三格都先铺第 1 帧的头：头发、轮廓三格逐像素一样
            if 0 <= y + 移y < 战.格:
                出[y + 移y, 序 * 战.格 + x] = 帧0[y, x]
        for y, x in zip(*np.where(分["头罩"][i] if i else np.zeros((战.格, 战.格), bool))):
            yy, xx = y - dy + 移y, x - dx                   # 表情只换脸那一块，头发盖着的点不动
            if (y0 <= yy < y1 and x0 <= xx < x1 and 出[yy, 序 * 战.格 + xx, 3] > 0
                    and tuple(出[yy, 序 * 战.格 + xx, :3]) not in 分["发色"] and tuple(帧[y, x, :3]) not in 分["发色"]):
                出[yy, 序 * 战.格 + xx] = 帧[y, x]
    return 出


# ---------- 拆身 ----------

def 拆身(类型: str, 素材: Path, 名: str) -> np.ndarray:
    """把原版角色的头去掉，剩下的整张身体（行走 144×192／战斗 576×384）就是身体部件的底子。

    做法是让生成器拿一个全透明的头部件去拼：旧头、旧下巴、垂下来的旧头发擦掉，盖住的身体照正下方补，
    挡在脸前的手留着。所以拆出来的身体再配上头，和直接拿原版角色当身体供体拼出来的一样。
    """
    import tempfile
    with tempfile.TemporaryDirectory() as 目录:
        目录 = Path(目录)
        if 类型 == "行走":
            Image.fromarray(np.zeros((走.格, 3 * 走.格, 4), np.uint8), "RGBA").save(目录 / "空.png")
            出, _ = 走.拼({"头部件": "空.png", "身体": 名}, 素材, 目录)
        else:
            Image.fromarray(np.zeros((战.格, 战.格, 4), np.uint8), "RGBA").save(目录 / "空.png")
            出, _ = 战.拼({"头部件": "空.png", "身体": 名}, 素材, 目录)
    return 出


def 命令_拆身(参):
    出 = 拆身(参.类型, Path(参.素材), 参.角色)
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(出.astype(np.uint8), "RGBA").save(参.输出, optimize=False)
    print(f"已拆出 {参.输出}（{出.shape[1]}×{出.shape[0]}，{参.类型}图身体部件，来自 {参.角色}）")


def 命令_拆头(参):
    出 = (拆行走头 if 参.类型 == "行走" else 拆战斗头)(Path(参.素材), 参.角色, not 参.留领口)
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(出.astype(np.uint8), "RGBA").save(参.输出, optimize=False)
    print(f"已拆出 {参.输出}（{出.shape[1]}×{出.shape[0]}，{参.类型}图头部件，来自 {参.角色}）")


# ---------- 体检 ----------

def 体检(路: Path, 类型: str):
    """返回 [(项, 合格, 说明)]。合格是 None 的只是提醒，不算不合格。"""
    规 = 类型表[类型]
    格, 切 = 规["格"], 规["切"]
    原 = np.array(Image.open(路).convert("RGBA")).astype(np.int32)
    高, 宽 = 原.shape[:2]
    项 = []
    尺寸对 = 宽 in 规["宽"] and 高 in (格, 2 * 格)
    项.append(("尺寸", 尺寸对, f"{宽}×{高}" + ("" if 尺寸对 else f"；要宽 {'／'.join(map(str, 规['宽']))}、高 {格} 或 {2 * 格}")))
    if not 尺寸对:
        return 项
    半 = int(((原[..., 3] > 0) & (原[..., 3] < 255)).sum())
    项.append(("透明度只有 0 和 255", 半 == 0, f"半透明的点 {半} 个" + ("" if 半 == 0 else "；边缘不能有虚边，要么全透明要么不透明")))
    实全 = 原[..., 3] >= 128
    键全 = 色键(原)
    格名 = 规["格名"][宽]
    肤键 = {int(色[1:], 16) for 色 in 标准肤色}
    y0, y1, x0, x1 = 规["脸"]
    前 = []
    for 序, 名 in enumerate(格名):
        块 = 原[:格, 序 * 格:(序 + 1) * 格]
        实 = 实全[:格, 序 * 格:(序 + 1) * 格]
        键 = 键全[:格, 序 * 格:(序 + 1) * 格]
        前.append((实, 键))
        if 实.sum() < 150:
            项.append((f"{名}：有内容", False, f"只有 {int(实.sum())} 个点，这一格是空的或者太小"))
            continue
        后实 = 实全[格:, 序 * 格:(序 + 1) * 格] if 高 == 2 * 格 else np.zeros_like(实)
        后键 = 键全[格:, 序 * 格:(序 + 1) * 格] if 高 == 2 * 格 else 键
        色数 = len(set(np.unique(键[实]).tolist()) | set(np.unique(后键[后实]).tolist()))
        项.append((f"{名}：颜色数", 色数 <= 规["最多色"], f"{色数} 种（原版的头一般 15～30 种，上限 {规['最多色']}）"))
        ys, xs = np.where(实)
        顶 = int(ys.min())
        项.append((f"{名}：头顶位置", 顶 <= 规["头顶最低"], f"头顶在第 {顶} 行（原版在 0～5 行；超过 {规['头顶最低']} 说明头画小了或者画低了）"))
        接 = int(实[切 - 1].sum())
        if 名 != "背面":
            项.append((f"{名}：接到脖子", 接 >= 规["接"], f"第 {切 - 1} 行（身体上面那一行）有 {接} 个点" + ("" if 接 >= 规["接"] else "；头的下沿要落在这一行，不然头和身体之间会露缝")))
        边 = 外缘(实 | 后实) & 实
        L = 亮度(块[..., :3])
        里 = 实 & ~边
        比 = float(L[边].mean() / max(float(L[里].mean()), 1.0)) if 边.any() and 里.any() else 1.0
        黑比 = float((L[边] < 25).mean()) if 边.any() else 0.0
        项.append((f"{名}：外缘描边", 比 <= 0.78, f"外缘一圈的平均亮度是里面的 {比:.0%}（原版中位数 44%，最多 78%）" + ("" if 比 <= 0.78 else "；外缘要有一圈比里面深的描边")))
        项.append((f"{名}：描边不是死黑", None if 黑比 > 0.75 else True, f"外缘近乎纯黑的占 {黑比:.0%}" + ("；原版的描边是各部位自己颜色的深色，不是一圈黑线" if 黑比 > 0.75 else "")))
        碎 = 小块(实)
        项.append((f"{名}：没有碎点", len(碎) == 0, f"落单的碎点 {len(碎)} 个" + (f"，例如（列, 行）{碎[:6]}" if 碎 else "")))
        if 名 in 规["肤点"]:
            脸 = np.zeros_like(实)
            脸[y0:y1, x0:x1] = True
            标 = int((np.isin(键, list(肤键)) & 实 & 脸).sum())
            项.append((f"{名}：脸用标准肤色", 标 >= 规["肤点"][名], f"脸上用了标准肤色的点 {标} 个（至少 {规['肤点'][名]}）；标准肤色是 {' '.join(标准肤色)}"))
    if 类型 == "战斗" and len(前) > 1:                        # 几格表情必须是同一个头，只有眼睛、嘴不一样
        实0, 键0 = 前[0]
        for 序 in range(1, len(前)):
            实, 键 = 前[序]
            异 = (实 != 实0) | (实 & 实0 & (键 != 键0))
            脸外 = 异.copy()
            脸外[y0:y1, x0:x1] = False
            形变 = int((实 != 实0).sum())
            合 = int(脸外.sum()) == 0 and 形变 <= 12 and int(异.sum()) <= 200
            项.append((f"{格名[序]}：和常态是同一个头", 合, f"和常态不一样的点 {int(异.sum())} 个，其中脸以外 {int(脸外.sum())} 个，轮廓变了 {形变} 个"
                      + ("" if 合 else "；只许改眼睛、眉毛、嘴，头发和轮廓要逐像素一样（先复制常态那一格再改）")))
    return 项


身体规 = {   # 门槛照原版量：标准肤色的原版角色拆出来的身体，行走图全图颜色中位数 30、p75 39，每帧 24／31；战斗图全图 67／77，每帧最多 52／65
    "行走身体": {"宽高": (144, 192), "帧": [(行, 列) for 行 in range(4) for 列 in range(3)], "每帧色": 40, "全图色": 48},
    "战斗身体": {"宽高": (576, 384), "帧": list(range(54)), "每帧色": 64, "全图色": 96},
}


def 身体帧(图, 类型, f):
    if 类型 == "行走身体":
        return 图[f[0] * 走.格:(f[0] + 1) * 走.格, f[1] * 走.格:(f[1] + 1) * 走.格]
    return 战.取帧(图, f)


动作名 = ("前进", "待机", "咏唱", "防御", "受伤", "闪避", "突刺", "挥舞", "飞行道具", "技能", "魔法", "道具",
          "逃跑", "胜利", "濒死", "异常", "睡眠", "倒地")


def 帧名(类型, f):
    return f"朝{走.方向名[f[0]]}第 {f[1] + 1} 帧" if 类型 == "行走身体" else f"第 {f + 1} 帧（{动作名[f // 3]}）"


def 肤色量(图):
    肤 = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in 标准肤色])
    rgb = 图[..., :3][图[..., 3] >= 128]
    if not len(rgb):
        return 0, 0
    d = np.abs(rgb[:, None, :] - 肤[None]).sum(-1).min(1)
    return int((d == 0).sum()), int(((d > 0) & (d < 30)).sum())


def 体检身体(路: Path, 类型: str, 底子路: Path):
    """身体部件体检：和拆出来的底子比，姿势不能改，颜色、描边、碎点不能比原版差。"""
    规 = 身体规[类型]
    原 = np.array(Image.open(路).convert("RGBA")).astype(np.int32)
    底 = np.array(Image.open(底子路).convert("RGBA")).astype(np.int32)
    高, 宽 = 原.shape[:2]
    项 = []
    对 = (宽, 高) == 规["宽高"]
    项.append(("尺寸", 对, f"{宽}×{高}" + ("" if 对 else f"；要 {规['宽高'][0]}×{规['宽高'][1]}，和整张{'行走' if 类型 == '行走身体' else '战斗'}图一样")))
    if not 对 or 底.shape != 原.shape:
        if 对:
            项.append(("底子", False, f"底子 {底子路.name} 的尺寸不对，要用 拆身 拆出来的那张"))
        return 项
    半 = int(((原[..., 3] > 0) & (原[..., 3] < 255)).sum())
    项.append(("透明度只有 0 和 255", 半 == 0, f"半透明的点 {半} 个"))
    实全 = 原[..., 3] >= 128
    全色 = len(np.unique(色键(原)[实全]))
    项.append(("全图颜色数", 全色 <= 规["全图色"], f"{全色} 种（上限 {规['全图色']}）；所有帧共用一套颜色，同一种布料每帧用同几个色"))
    最多, 最多帧, 最偏, 最偏帧, 空帧, 比们 = 0, None, 0.0, None, [], []
    碎, 底碎 = 0, 0
    for f in 规["帧"]:
        块, 底块 = 身体帧(原, 类型, f), 身体帧(底, 类型, f)
        实, 底实 = 块[..., 3] >= 128, 底块[..., 3] >= 128
        if 底实.sum() >= 50 and 实.sum() < 0.5 * 底实.sum():
            空帧.append(帧名(类型, f))
        if not 实.any():
            continue
        色 = len(np.unique(色键(块)[实]))
        if 色 > 最多:
            最多, 最多帧 = 色, f
        偏 = float((实 ^ 底实).sum() / max(int(底实.sum()), 1))
        if 偏 > 最偏:
            最偏, 最偏帧 = 偏, f
        碎 += len(小块(实))
        底碎 += len(小块(底实))
        边 = 外缘(实)
        里 = 实 & ~边
        if 边.any() and 里.any():
            L = 亮度(块[..., :3])
            比们.append(float(L[边].mean() / max(float(L[里].mean()), 1.0)))
    项.append(("每帧有内容", not 空帧, "全部有" if not 空帧 else f"这几帧比底子少了一半以上：{'、'.join(空帧[:6])}"))
    项.append(("每帧颜色数", 最多 <= 规["每帧色"], f"最多的是{帧名(类型, 最多帧) if 最多帧 is not None else ''} {最多} 种（上限 {规['每帧色']}）"))
    姿 = 最偏 <= 0.35
    项.append(("姿势没改", (None if 最偏 > 0.15 else True) if 姿 else False,
              (f"和底子轮廓差得最多的是{帧名(类型, 最偏帧)}，差了底子点数的 {最偏:.0%}" if 最偏帧 is not None else "轮廓和底子一样") + "（超过 15% 提醒，超过 35% 不合格）"
              + ("" if 姿 else "；动作要照底子，只改衣服和配色，不要重画姿势")))
    项.append(("没有碎点", 碎 <= 底碎, f"落单的碎点 {碎} 个（底子 {底碎} 个）"))
    中 = float(np.median(比们)) if 比们 else 1.0
    项.append(("外缘描边", 中 <= 0.78, f"各帧外缘平均亮度是里面的 {中:.0%}（中位数；原版行走 62%、战斗 56%，上限 78%）"))
    标, 近 = 肤色量(原)
    底标, 底近 = 肤色量(底)
    肤对 = 近 <= 底近 + 20 and (标 > 0 or 底标 == 0)
    项.append(("皮肤用标准肤色", 肤对, f"标准肤色的点 {标} 个，像皮肤又不是标准肤色的点 {近} 个（底子 {底标}／{底近}）"
              + ("" if 肤对 else "；脖子、手要用 " + " ".join(标准肤色) + "，和头对得上")))
    return 项


def 命令_体检(参):
    坏 = 0
    if 参.类型 in 身体规 and not 参.底子:
        raise SystemExit("身体部件体检要给 --底子（拆身 拆出来的那张），用来比姿势")
    for 文件 in 参.文件:
        身体 = 参.类型 in 身体规
        print(f"== {文件}（{参.类型.replace('身体', '')}图{'身体' if 身体 else '头'}部件）")
        for 名, 合, 说 in (体检身体(Path(文件), 参.类型, Path(参.底子)) if 身体 else 体检(Path(文件), 参.类型)):
            标 = "提醒" if 合 is None else ("合格" if 合 else "不合格")
            坏 += 合 is False
            print(f"  [{标}] {名}：{说}")
    print("全部合格" if not 坏 else f"有 {坏} 项不合格")
    sys.exit(1 if 坏 else 0)


def main(argv=None):
    p = argparse.ArgumentParser(description="部件：拆头、拆身、体检")
    子 = p.add_subparsers(dest="命令", required=True)
    a = 子.add_parser("拆头", help="把原版角色的头拆成头部件")
    a.add_argument("类型", choices=("行走", "战斗"))
    a.add_argument("角色", help="行走：文件名#序号；战斗：文件名")
    a.add_argument("输出")
    a.add_argument("--素材", required=True)
    a.add_argument("--留领口", action="store_true", help="不擦掉脖子上方带着的旧领口（默认擦掉）")
    a.set_defaults(函数=命令_拆头)
    c = 子.add_parser("拆身", help="把原版角色的头去掉，剩下的身体当身体部件的底子")
    c.add_argument("类型", choices=("行走", "战斗"))
    c.add_argument("角色", help="行走：文件名#序号；战斗：文件名")
    c.add_argument("输出")
    c.add_argument("--素材", required=True)
    c.set_defaults(函数=命令_拆身)
    b = 子.add_parser("体检", help="检查头部件、身体部件合不合规格")
    b.add_argument("类型", choices=("行走", "战斗", "行走身体", "战斗身体"))
    b.add_argument("文件", nargs="+")
    b.add_argument("--底子", help="身体部件体检用：拆身 拆出来的那张")
    b.set_defaults(函数=命令_体检)
    参 = p.parse_args(argv)
    参.函数(参)


if __name__ == "__main__":
    main()
