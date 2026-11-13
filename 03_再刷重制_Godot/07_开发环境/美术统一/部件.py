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


def 命令_体检(参):
    坏 = 0
    for 文件 in 参.文件:
        print(f"== {文件}（{参.类型}图头部件）")
        for 名, 合, 说 in 体检(Path(文件), 参.类型):
            标 = "提醒" if 合 is None else ("合格" if 合 else "不合格")
            坏 += 合 is False
            print(f"  [{标}] {名}：{说}")
    print("全部合格" if not 坏 else f"有 {坏} 项不合格")
    sys.exit(1 if 坏 else 0)


def main(argv=None):
    p = argparse.ArgumentParser(description="头部件：拆头、体检")
    子 = p.add_subparsers(dest="命令", required=True)
    a = 子.add_parser("拆头", help="把原版角色的头拆成头部件")
    a.add_argument("类型", choices=("行走", "战斗"))
    a.add_argument("角色", help="行走：文件名#序号；战斗：文件名")
    a.add_argument("输出")
    a.add_argument("--素材", required=True)
    a.add_argument("--留领口", action="store_true", help="不擦掉脖子上方带着的旧领口（默认擦掉）")
    a.set_defaults(函数=命令_拆头)
    b = 子.add_parser("体检", help="检查头部件合不合规格")
    b.add_argument("类型", choices=("行走", "战斗"))
    b.add_argument("文件", nargs="+")
    b.set_defaults(函数=命令_体检)
    参 = p.parse_args(argv)
    参.函数(参)


if __name__ == "__main__":
    main()
