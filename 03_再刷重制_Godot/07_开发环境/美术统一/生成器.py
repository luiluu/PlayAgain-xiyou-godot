#!/usr/bin/env python3
"""行走图角色生成器（原型）：部件库＋配方 → 一键导出 `$` 行走图。

思路照 RPG Maker 的角色生成器，但部件全是自己的：

  拆件  把一张已定稿的行走图拆成三类部件存进部件库
          头    光头＋脸，下、左、右、上四个方向各一张
          发    发型，四个方向各一张
          身体  脖子以下 12 帧，带每帧「头该放在哪」的位置
  导出  按配方选头、发、身体，换色，拼成 144×192 的行走图
  总览  把部件库里的部件排成一张图，方便挑

同一个方向的三帧共用同一张头和发，只跟着身体上下左右平移，所以走路时头不会一帧一个样。
同样的部件和配方，导出结果逐字节相同。

部件库是本地文件夹（图片不进仓库），路径由 --库 给。依赖：Pillow、numpy。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from 行走图 import 亮度, 十六进制, 色带取色, 外缘, 方向名  # noqa: E402

格 = 48
列数, 行数 = 3, 4
站立列 = 1


# ---------- 颜色规则 ----------

def 色相饱和(色: np.ndarray):
    """返回 (色相 0～360, 饱和 0～1)，按 HSV。"""
    c = 色[..., :3].astype(float) / 255.0
    大, 小 = c.max(-1), c.min(-1)
    差 = 大 - 小
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    h = np.zeros(大.shape)
    有 = 差 > 1e-9
    是r = 有 & (大 == r)
    是g = 有 & (大 == g) & ~是r
    是b = 有 & ~是r & ~是g
    h[是r] = ((g - b)[是r] / 差[是r]) % 6
    h[是g] = (b - r)[是g] / 差[是g] + 2
    h[是b] = (r - g)[是b] / 差[是b] + 4
    s = np.where(大 > 1e-9, 差 / np.maximum(大, 1e-9), 0.0)
    return h * 60.0, s


def 合规则(图: np.ndarray, 规: dict, 位置=None) -> np.ndarray:
    """规则字段都可省：色相 [a,b]（a 为负表示跨过 0 度）、最低饱和、最高饱和、最低亮度、最高亮度、位置 [起,止]。"""
    h, s = 色相饱和(图)
    L = 亮度(图[..., :3])
    罩 = np.ones(L.shape, bool)
    if "色相" in 规:
        a, b = 规["色相"]
        罩 &= ((h >= a % 360) | (h <= b)) if a < 0 else ((h >= a) & (h <= b))
    if "最低饱和" in 规:
        罩 &= s >= 规["最低饱和"]
    if "最高饱和" in 规:
        罩 &= s <= 规["最高饱和"]
    if "最低亮度" in 规:
        罩 &= L >= 规["最低亮度"]
    if "最高亮度" in 规:
        罩 &= L <= 规["最高亮度"]
    if "位置" in 规 and 位置 is not None:
        罩 &= (位置 >= 规["位置"][0]) & (位置 < 规["位置"][1])
    return 罩


def 八邻(罩: np.ndarray) -> np.ndarray:
    垫 = np.pad(罩, 1)
    出 = np.zeros_like(罩)
    for dy in (0, 1, 2):
        for dx in (0, 1, 2):
            if dy == 1 and dx == 1:
                continue
            出 |= 垫[dy:dy + 罩.shape[0], dx:dx + 罩.shape[1]]
    return 出


def 填洞(罩: np.ndarray) -> np.ndarray:
    """把被罩完全围住的空洞也算进罩里（脸中间的眼睛、嘴、纹）。"""
    高, 宽 = 罩.shape
    外 = np.zeros_like(罩)
    栈 = [(y, x) for y in range(高) for x in (0, 宽 - 1)] + [(y, x) for x in range(宽) for y in (0, 高 - 1)]
    while 栈:
        y, x = 栈.pop()
        if y < 0 or x < 0 or y >= 高 or x >= 宽 or 外[y, x] or 罩[y, x]:
            continue
        外[y, x] = True
        栈 += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return ~外


def 去碎点(罩: np.ndarray, 最小: int) -> np.ndarray:
    高, 宽 = 罩.shape
    号 = np.zeros((高, 宽), int)
    出 = np.zeros_like(罩)
    n = 0
    for y0 in range(高):
        for x0 in range(宽):
            if not 罩[y0, x0] or 号[y0, x0]:
                continue
            n += 1
            栈, 块 = [(y0, x0)], []
            号[y0, x0] = n
            while 栈:
                y, x = 栈.pop()
                块.append((y, x))
                for yy, xx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= yy < 高 and 0 <= xx < 宽 and 罩[yy, xx] and not 号[yy, xx]:
                        号[yy, xx] = n
                        栈.append((yy, xx))
            if len(块) >= 最小:
                for y, x in 块:
                    出[y, x] = True
    return 出


def 平移(图: np.ndarray, dx: int, dy: int) -> np.ndarray:
    出 = np.zeros_like(图)
    高, 宽 = 图.shape[:2]
    ys0, ys1 = max(0, dy), min(高, 高 + dy)
    xs0, xs1 = max(0, dx), min(宽, 宽 + dx)
    if ys0 < ys1 and xs0 < xs1:
        出[ys0:ys1, xs0:xs1] = 图[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return 出


def 盖(底: np.ndarray, 上: np.ndarray) -> np.ndarray:
    出 = 底.copy()
    罩 = 上[..., 3] > 0
    出[罩] = 上[罩]
    return 出


def 读格(图: np.ndarray, 行: int, 列: int) -> np.ndarray:
    块 = 图[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格].copy()
    实 = 块[..., 3] >= 128
    块[..., 3] = np.where(实, 255, 0)      # alpha 二值化
    块[~实] = 0
    return 块


def 存图(数组: np.ndarray, 路径: Path):
    路径.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(数组.astype(np.uint8), "RGBA").save(路径)


def 读图(路径) -> np.ndarray:
    return np.array(Image.open(路径).convert("RGBA")).astype(np.int32)


# ---------- 拆件 ----------

def 拆头(块: np.ndarray, 脖: int, 档: dict, 行: int, 正面: dict | None):
    """返回 (光头＋脸, 发, 锚点 [x, y], 正面信息)。正面信息＝正面那张量到的脸宽和肤色，四个方向共用。"""
    实 = 块[..., 3] > 0
    头罩 = 实.copy()
    头罩[脖:] = False
    规 = 档["头"]
    肤 = 合规则(块, 规["肤"]) & 头罩
    肤 = 去碎点(肤, 规.get("最小脸块", 2))
    眼 = 合规则(块, 规["眼"]) & 头罩 if "眼" in 规 else np.zeros_like(头罩)
    if 肤.any():
        # 眼睛只认落在皮肤范围里的；头发边缘偶尔有同色相的点，不算
        肤ys, 肤xs = np.where(肤)
        框 = np.zeros_like(眼)
        框[肤ys.min():肤ys.max() + 1, 肤xs.min():肤xs.max() + 1] = True
        眼 = 去碎点(眼 & 框, 3)
    脸 = 肤 | 眼
    脸 = 填洞(脸) & 头罩
    眼 = 眼 & 脸
    L = 亮度(块[..., :3])
    _, 饱 = 色相饱和(块)
    ys, xs = np.where(脸)
    if len(ys) == 0:
        raise SystemExit(f"方向「{方向名[行]}」的头上找不到皮肤，检查素材档的肤色规则")
    腰 = ys.mean()
    行号 = np.arange(块.shape[0])[:, None] * np.ones((1, 块.shape[1]))
    # 眼白：左右紧挨眼睛的亮点
    if 眼.any():
        旁 = np.zeros_like(眼)
        旁[:, 1:] |= 眼[:, :-1]
        旁[:, :-1] |= 眼[:, 1:]
        脸 |= 头罩 & ~脸 & 旁 & (L >= 180)
    # 被脸三面以上围住的点算脸（脸上的阴影、纹）
    for _ in range(2):
        垫 = np.pad(脸, 1).astype(int)
        邻数 = 垫[:-2, 1:-1] + 垫[2:, 1:-1] + 垫[1:-1, :-2] + 垫[1:-1, 2:]
        脸 |= 头罩 & (邻数 >= 3)
    暗 = 头罩 & ~脸 & (L < 规.get("脸线最高亮度", 90))
    # 下巴、脸颊的轮廓线：贴着脸、在脸的下半边的暗点
    脸线 = 暗 & 八邻(脸) & (行号 >= 腰)
    # 睫毛、眉：眼睛正上方两行内的暗点
    if 眼.any():
        上方 = np.zeros_like(眼)
        上方[:-1] |= 眼[1:]
        上方[:-2] |= 眼[2:]
        脸线 |= 暗 & 上方
    面 = 脸 | 脸线
    # 头发里和主体不相连的碎点（多半是脸边的阴影）留在脸上，不跟着发型走
    发罩 = 去碎点(头罩 & ~面, 规.get("最小发块", 6))
    面 = 头罩 & ~发罩
    if 正面 is None:
        肤色 = 块[肤][:, :3]
        肤亮 = 亮度(肤色)
        取 = lambda 分位: 肤色[np.argsort(肤亮)[int((len(肤亮) - 1) * 分位)]].astype(float)
        正面 = {"脸宽": int(xs.max() - xs.min() + 1), "亮": 取(0.85), "中": 取(0.55), "暗": 取(0.2)}
    W = 规.get("头骨宽", 正面["脸宽"])
    x0, x1 = int(xs.min()), int(xs.max())
    if 行 == 1:      # 朝左：脸的前缘在左
        锚x, 颅心 = x0, x0 + W / 2 - 0.5
    elif 行 == 2:    # 朝右
        锚x, 颅心 = x1, x1 - W / 2 + 0.5
    elif 行 == 3:    # 背面看不到脸，用整个头的中线
        头xs = np.where(头罩.any(0))[0]
        颅心 = (int(头xs.min()) + int(头xs.max())) / 2
        锚x = int(颅心)
    else:
        颅心 = (x0 + x1) / 2
        锚x = int(颅心)
    # 头骨：头发底下补一块头皮，换上别的发型时不会露洞
    rw = W / 2 - 0.5
    rh = rw * 规.get("头骨高宽比", 0.9)
    颅腰 = (脖 - 1) - rh + 0.5
    yy, xx = np.mgrid[0:块.shape[0], 0:块.shape[1]]
    u, v = (xx - 颅心) / rw, (yy - 颅腰) / rh
    椭 = (u * u + v * v <= 1.0) & (yy < 脖)
    补 = 椭 & ~面
    光头 = np.zeros_like(块)
    光头[面] = 块[面]
    向光 = -0.6 * u - 0.8 * v
    光头[补, :3] = np.round(正面["中"])
    光头[补 & (向光 > 0.5), :3] = np.round(正面["亮"])
    光头[补 & (向光 < -0.45), :3] = np.round(正面["暗"])
    垫 = np.pad(椭 | 面, 1)
    内 = 垫[:-2, 1:-1] & 垫[2:, 1:-1] & 垫[1:-1, :-2] & 垫[1:-1, 2:]
    圈 = 补 & ~内
    圈[脖 - 1] = False      # 贴脖子的那一行不描，免得和身体之间多一道线
    光头[圈, :3] = np.round(正面["暗"] * 0.45)
    光头[补, 3] = 255
    发 = np.zeros_like(块)
    发[发罩] = 块[发罩]
    return 光头, 发, [int(锚x), int(脖)], 正面


def 对头(块: np.ndarray, 站头: np.ndarray, 站脖: int):
    """这一帧的头相对站立帧挪了多少：在 ±3 里找和站立帧的头最对得上的平移。"""
    最好 = None
    站实 = 站头[..., 3] > 0
    for dy in range(-3, 4):
        头 = 块.copy()
        头[站脖 + dy:] = 0
        实 = 头[..., 3] > 0
        for dx in range(-3, 4):
            移 = 平移(站头, dx, dy)
            移实 = 移[..., 3] > 0
            两 = 实 & 移实
            差 = (实 ^ 移实).sum() * 1.0 + np.abs(头[两][:, :3] - 移[两][:, :3]).sum() / 255.0
            键 = (差, abs(dx) + abs(dy))
            if 最好 is None or 键 < 最好[0]:
                最好 = (键, dx, dy)
    return 最好[1], 最好[2]


def 命令_拆件(参):
    档 = json.loads(Path(参.素材档).read_text("utf-8"))
    图 = 读图(参.源图)
    if 图.shape[:2] != (行数 * 格, 列数 * 格):
        raise SystemExit(f"源图要 {列数 * 格}×{行数 * 格}，实际 {图.shape[1]}×{图.shape[0]}")
    库 = Path(参.库)
    名 = 参.名
    头图 = np.zeros((行数 * 格, 格, 4), np.int32)
    发图 = np.zeros_like(头图)
    身图 = np.zeros_like(图)
    头锚, 身锚 = [], []
    正面 = None
    for 行 in range(行数):
        站 = 读格(图, 行, 站立列)
        ys = np.where((站[..., 3] > 0).any(1))[0]
        脖 = int(ys.max()) - 档["脖子距底"][行]
        光头, 发, 锚, 正面 = 拆头(站, 脖, 档, 行, 正面)
        头图[行 * 格:(行 + 1) * 格] = 光头
        发图[行 * 格:(行 + 1) * 格] = 发
        头锚.append(锚)
        站头 = 站.copy()
        站头[脖:] = 0
        for 列 in range(列数):
            块 = 读格(图, 行, 列)
            dx, dy = (0, 0) if 列 == 站立列 else 对头(块, 站头, 脖)
            身 = 块.copy()
            身[:脖 + dy] = 0
            身图[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格] = 身
            身锚.append([锚[0] + dx, 锚[1] + dy])
    存图(头图, 库 / "头" / f"{名}.png")
    存图(发图, 库 / "发" / f"{名}.png")
    存图(身图, 库 / "身体" / f"{名}.png")
    (库 / "头" / f"{名}.json").write_text(json.dumps(
        {"锚": 头锚, "分区": 档["头"], "来源": Path(参.源图).name}, ensure_ascii=False, indent=1), "utf-8")
    (库 / "发" / f"{名}.json").write_text(json.dumps(
        {"锚": 头锚, "来源": Path(参.源图).name}, ensure_ascii=False, indent=1), "utf-8")
    (库 / "身体" / f"{名}.json").write_text(json.dumps(
        {"头锚": 身锚, "分区": 档["身体"], "来源": Path(参.源图).name}, ensure_ascii=False, indent=1), "utf-8")
    print(f"已入库「{名}」：头、发、身体各一份 → {库}")
    return 0


# ---------- 导出 ----------

def 按色带换(图: np.ndarray, 罩: np.ndarray, 项: dict, 轮廓: np.ndarray):
    """把罩里的像素按原来的明暗换到色带上；描边色用在轮廓和最暗的点。"""
    if not 罩.any():
        return
    L = 亮度(图[..., :3])
    全 = np.sort(L[罩])
    暗, 明 = float(np.percentile(全, 2)), float(np.percentile(全, 98))
    t = np.clip((L[罩] - 暗) / max(明 - 暗, 1.0), 0, 1)
    均衡 = 项.get("均衡", 0.0)
    if 均衡:
        名次 = np.searchsorted(全, L[罩]) / max(len(全) - 1, 1)
        t = t * (1 - 均衡) + 名次 * 均衡
    原暗线 = 罩 & (L <= 暗 + (明 - 暗) * 项.get("暗线比例", 0.06))
    图[罩, :3] = np.round(色带取色(项["色带"], t)).astype(np.int32)
    if 项.get("描边"):
        线 = (罩 & 轮廓) | 原暗线
        图[线, :3] = np.round(十六进制(项["描边"])).astype(np.int32)


def 头的分区(头: np.ndarray, 规: dict):
    实 = 头[..., 3] > 0
    肤 = 合规则(头, 规["肤"]) & 实
    眼 = 合规则(头, 规["眼"]) & 实 if "眼" in 规 else np.zeros_like(实)
    return 肤 & ~眼, 眼


def 身体分区(身: np.ndarray, 规们: list, 头锚们: list):
    """返回 {名: 罩}（整张 144×192）。规则按顺序，先中先得。"""
    高, 宽 = 身.shape[:2]
    实 = 身[..., 3] > 0
    位置 = np.zeros((高, 宽))
    for 行 in range(行数):
        for 列 in range(列数):
            块实 = 实[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格]
            ys = np.where(块实.any(1))[0]
            if len(ys) == 0:
                continue
            顶, 底 = 头锚们[行 * 列数 + 列][1], int(ys.max())
            比 = (np.arange(格) - 顶) / max(底 - 顶 + 1, 1)
            位置[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格] = 比[:, None]
    剩 = 实.copy()
    出 = {}
    for 规 in 规们:
        罩 = 合规则(身, 规, 位置) & 剩
        出[规["名"]] = 出.get(规["名"], np.zeros_like(实)) | 罩
        剩 &= ~罩
    return 出


def 拼(配方: dict, 库: Path) -> np.ndarray:
    def 取(类, 名):
        return 读图(库 / 类 / f"{名}.png"), json.loads((库 / 类 / f"{名}.json").read_text("utf-8"))
    头图, 头档 = 取("头", 配方["头"])
    发图, 发档 = 取("发", 配方["发"]) if 配方.get("发") else (None, None)
    身图, 身档 = 取("身体", 配方["身体"])
    换 = 配方.get("换色", {})
    # 先换色（在部件上换，12 帧自然一致），再拼
    for 行 in range(行数):
        头 = 头图[行 * 格:(行 + 1) * 格]
        肤, 眼 = 头的分区(头, 头档["分区"])
        边 = 外缘(头[..., 3] > 0)
        if "肤" in 换:
            按色带换(头, 肤, 换["肤"], 边)
        if "眼" in 换:
            按色带换(头, 眼, 换["眼"], np.zeros_like(边))
        if 发图 is not None and "发" in 换:
            发 = 发图[行 * 格:(行 + 1) * 格]
            按色带换(发, 发[..., 3] > 0, 换["发"], 外缘(发[..., 3] > 0))
    区们 = 身体分区(身图, 身档["分区"], 身档["头锚"])
    身边 = 外缘(身图[..., 3] > 0)
    for 名, 罩 in 区们.items():
        键 = 名 if 名 == "肤" else f"身体.{名}"
        if 键 in 换:
            按色带换(身图, 罩, 换[键], 身边)
    出 = np.zeros((行数 * 格, 列数 * 格, 4), np.int32)
    偏 = 配方.get("发偏移", {})
    for 行 in range(行数):
        头 = 头图[行 * 格:(行 + 1) * 格]
        for 列 in range(列数):
            块 = 身图[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格].copy()
            ax, ay = 身档["头锚"][行 * 列数 + 列]
            块 = 盖(块, 平移(头, ax - 头档["锚"][行][0], ay - 头档["锚"][行][1]))
            if 发图 is not None:
                ox, oy = 偏.get(方向名[行], [0, 0])
                发 = 发图[行 * 格:(行 + 1) * 格]
                块 = 盖(块, 平移(发, ax - 发档["锚"][行][0] + ox, ay - 发档["锚"][行][1] + oy))
            出[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格] = 块
    return 出


def 命令_导出(参):
    配方 = json.loads(Path(参.配方).read_text("utf-8"))
    出 = 拼(配方, Path(参.库))
    存图(出, Path(参.输出))
    print(f"已导出 {参.输出}（头 {配方['头']}，发 {配方.get('发') or '无'}，身体 {配方['身体']}）")
    return 0


def 命令_总览(参):
    库 = Path(参.库)
    倍 = 参.倍数
    行们 = []
    for 类 in ("头", "发", "身体"):
        for 文 in sorted((库 / 类).glob("*.png")):
            图 = Image.open(文).convert("RGBA")
            if 类 != "身体":      # 四个方向横着排
                横 = Image.new("RGBA", (格 * 4, 格))
                for i in range(4):
                    横.alpha_composite(图.crop((0, i * 格, 格, (i + 1) * 格)), (i * 格, 0))
                图 = 横
            else:                 # 只放站立帧
                横 = Image.new("RGBA", (格 * 4, 格))
                for i in range(4):
                    横.alpha_composite(图.crop((格, i * 格, 格 * 2, (i + 1) * 格)), (i * 格, 0))
                图 = 横
            行们.append(图.resize((图.width * 倍, 图.height * 倍), Image.NEAREST))
    板 = Image.new("RGBA", (格 * 4 * 倍, 格 * 倍 * len(行们)), (29, 39, 51, 255))
    for i, 图 in enumerate(行们):
        板.alpha_composite(图, (0, i * 格 * 倍))
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    板.save(参.输出)
    print(f"已生成 {参.输出}（{len(行们)} 个部件）")
    return 0


def main(argv=None):
    解 = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    子 = 解.add_subparsers(dest="命令", required=True)
    a = 子.add_parser("拆件", help="把定稿行走图拆成头、发、身体入库")
    a.add_argument("源图")
    a.add_argument("素材档")
    a.add_argument("--名", required=True)
    a.add_argument("--库", required=True)
    a.set_defaults(函=命令_拆件)
    b = 子.add_parser("导出", help="配方 → 行走图")
    b.add_argument("配方")
    b.add_argument("输出")
    b.add_argument("--库", required=True)
    b.set_defaults(函=命令_导出)
    c = 子.add_parser("总览", help="部件库一览图")
    c.add_argument("--库", required=True)
    c.add_argument("--输出", required=True)
    c.add_argument("--倍数", type=int, default=4)
    c.set_defaults(函=命令_总览)
    参 = 解.parse_args(argv)
    return 参.函(参)


if __name__ == "__main__":
    sys.exit(main())
