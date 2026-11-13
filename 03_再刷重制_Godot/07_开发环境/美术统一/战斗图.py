#!/usr/bin/env python3
"""战斗图角色生成器（原型）：和行走图同一个办法，拿原版战斗图当部件库，换头、换身体、换色，导出 576×384 的战斗图。

原版的战斗图（9×6 格、每格 64×64、18 个动作各 3 帧）里，头在 54 帧里是同一张图整体平移出来的
（倒地那一帧也只是平移）。所以只要在第 1 帧把头认出来，再逐帧找到它移到了哪儿，
每一帧的头和身体就都分得开，任意两个角色可以互换。

  目录  把素材目录里的战斗图排成带名字的一览图
  取色  列出一张战斗图头上、身上的颜色
  导出  按配方里的「战斗图」一节拼头和身体、换色、加点缀

素材目录是原版的 img/sv_actors（不在仓库里，路径由 --素材 给）。依赖：Pillow、numpy。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from 行走图 import 亮度, 十六进制  # noqa: E402
from 生成器 import 色相饱和, 头发色, 下摆一格, 换色, 去孤点, 列颜色  # noqa: E402

格 = 64
帧数 = 54
整宽, 整高 = 576, 384
默认下巴行 = 37      # 第 1 帧里身体的第一行；原版生成器捏的角色都是这一行


def 帧位(i):
    动作, 帧 = divmod(i, 3)
    组, 行 = divmod(动作, 6)
    return 行 * 格, (组 * 3 + 帧) * 格


def 取帧(图, i):
    y, x = 帧位(i)
    return 图[y:y + 格, x:x + 格]


def 读战斗图(素材: Path, 名: str) -> np.ndarray:
    路 = 素材 / 名
    if not 路.exists():
        raise SystemExit(f"素材目录里没有 {名}")
    图 = np.array(Image.open(路).convert("RGBA")).astype(np.int32)
    if 图.shape[:2] != (整高, 整宽):
        raise SystemExit(f"{名} 的尺寸是 {图.shape[1]}×{图.shape[0]}，不是 {整宽}×{整高}，不能当部件")
    实 = 图[..., 3] >= 128
    图[..., 3] = np.where(实, 255, 0)
    图[~实] = 0
    return 图


def 肤色罩(块):
    h, s = 色相饱和(块)
    L = 亮度(块[..., :3])
    return (块[..., 3] > 0) & (h >= 5) & (h <= 45) & (s >= 0.12) & (s <= 0.8) & (L >= 90)


def 找下巴(帧0):
    """第 1 帧里脸在哪一列、下巴到哪一行。找肤色最宽的一行当脸，从那儿往下走到肤色断掉为止。量不出来返回默认。"""
    肤 = 肤色罩(帧0)
    ys = np.where((帧0[..., 3] > 0).any(1))[0]
    if len(ys) == 0:
        return 默认下巴行, 格 // 2
    顶 = int(ys.min())
    脸 = None
    for y in range(顶 + 14, min(顶 + 32, 格 - 1)):
        xs = np.where(肤[y])[0]
        if len(xs) >= 6 and (脸 is None or len(xs) > 脸[1]):
            脸 = (y, len(xs), int(np.median(xs)))
    if 脸 is None:
        return 默认下巴行, 格 // 2
    y0, _, 中 = 脸
    for y in range(y0 + 1, 格 - 2):
        if 肤[y, max(中 - 4, 0):中 + 5].sum() < 3:
            return y, 中
    return 默认下巴行, 中


def 色键(块):
    键 = (块[..., 0] << 16) | (块[..., 1] << 8) | 块[..., 2]
    return np.where(块[..., 3] > 0, 键, -1)


def 对位(键0, 头形0, 键f):
    """头在这一帧相对第 1 帧移了多少：试遍位移，挑颜色对上最多的。返回 (dx, dy, 对上的比例)。"""
    ys, xs = np.where(头形0)
    if len(ys) == 0:
        return 0, 0, 0.0
    值 = 键0[ys, xs]
    垫 = 32
    大 = np.full((格 + 2 * 垫, 格 + 2 * 垫), -2, np.int64)
    大[垫:垫 + 格, 垫:垫 + 格] = 键f
    最 = (-1, 0, 0)
    for dy in range(-10, 28):
        行 = 大[ys + 垫 + dy]
        for dx in range(-16, 17):
            数 = int((行[np.arange(len(ys)), xs + 垫 + dx] == 值).sum())
            if 数 > 最[0]:
                最 = (数, dx, dy)
    return 最[1], 最[2], 最[0] / len(ys)


def 平移(罩, dx, dy):
    出 = np.zeros_like(罩)
    高, 宽 = 罩.shape
    y0, y1 = max(dy, 0), min(高 + dy, 高)
    x0, x1 = max(dx, 0), min(宽 + dx, 宽)
    if y0 < y1 and x0 < x1:
        出[y0:y1, x0:x1] = 罩[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return 出


def 移键(键, dx, dy, 空=-3):
    出 = np.full_like(键, 空)
    高, 宽 = 键.shape
    y0, y1 = max(dy, 0), min(高 + dy, 高)
    x0, x1 = max(dx, 0), min(宽 + dx, 宽)
    if y0 < y1 and x0 < x1:
        出[y0:y1, x0:x1] = 键[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return 出


def 分头(图, 下巴行=None, 去领口=True, 调试=None):
    """把一张战斗图 54 帧的头都认出来。返回 {下巴行, 位移[54], 匹配[54], 头罩[54], 遮挡[54]}。"""
    帧0 = 取帧(图, 0)
    量的, 中 = 找下巴(帧0)
    切0 = 下巴行 or 量的
    实0 = 帧0[..., 3] > 0
    头形0 = 实0.copy()
    头形0[切0:] = False
    if 去领口:                                              # 下巴上方 4 行里，头的上半截从没出现过的颜色是旧领口
        上 = 帧0[:max(切0 - 4, 0)]
        上色 = {tuple(p) for p in 上[上[..., 3] > 0][:, :3]}
        for y in range(max(切0 - 4, 0), 切0):
            for x in range(格):
                if 头形0[y, x] and 亮度(帧0[y, x, :3]) >= 40 and tuple(帧0[y, x, :3]) not in 上色:
                    头形0[y, x] = False
        for _ in range(2):                                  # 领口擦掉后落单的描边
            for y in range(max(切0 - 4, 0), 切0):
                for x in range(格):
                    if 头形0[y, x] and 亮度(帧0[y, x, :3]) < 40:
                        邻 = [(y + dy, x + dx) for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)) if 0 <= y + dy < 切0 and 0 <= x + dx < 格]
                        if not any(头形0[p] and 亮度(帧0[p][:3]) >= 40 for p in 邻):
                            头形0[y, x] = False
    颈肤 = {tuple(帧0[y, x, :3]) for y in range(max(切0 - 8, 0), 切0) for x in range(max(中 - 4, 0), min(中 + 5, 格)) if 实0[y, x]}
    发色 = 头发色(帧0, 颈肤)
    键0 = 色键(帧0)
    键头0 = np.where(头形0, 键0, -3)
    # 头自己的颜色：第 1 帧头上有、而且不是「身上一大片、头上只有几点」的（耳环和手甲同色时，算身体的）
    头数 = {int(色): int(数) for 色, 数 in zip(*np.unique(键头0[头形0], return_counts=True))}
    身数 = {int(色): int(数) for 色, 数 in zip(*np.unique(键0[切0:][实0[切0:]], return_counts=True))}
    头色0 = {int(色) for 色, 数 in 头数.items() if 身数.get(色, 0) < 3 * 数}
    身色0 = {int(色) for 色 in 身数} - 头色0
    摆0 = 下摆一格(帧0, 切0, 发色, 头上=头形0)                        # 第 1 帧里头伸到下巴行以下的部分
    垂发 = 摆0.sum() <= 0.3 * max(int(实0[切0:].sum()), 1)
    if not 垂发:                                            # 衣服和头发同色，一路漫下去把身体吃掉了：不认垂发，只认下巴
        发色 = set()
        摆0 = 下摆一格(帧0, 切0, 发色, 头上=头形0)
    键摆0 = np.where(摆0, 键0, -3)
    位移, 匹配, 头罩, 遮挡 = [], [], [], []
    # 先逐帧找头移到了哪儿，把每一帧的头搬回第 1 帧的位置叠起来比
    归位 = np.full((帧数, 格, 格), -3, np.int64)
    for i in range(帧数):
        键 = 色键(取帧(图, i))
        dx, dy, 比 = (0, 0, 1.0) if i == 0 else 对位(键0, 头形0, 键)
        位移.append((dx, dy))
        匹配.append(比)
        归位[i] = np.where(头形0, 移键(键, -dx, -dy), -3)
    归位[归位 == -1] = -3
    # 表情（闭眼、张嘴）在好几个动作里是同一张脸，手甲只在自己那个动作里挡在那儿：
    # 一个点的颜色和第 1 帧一样，或者在另外 3 个动作里同一位置出现过（2 个动作、6 帧以上也算），就是头自己的
    同 = (归位[:, None] == 归位[None, :]) & (归位[:, None] != -3)      # [帧, 帧, 行, 列]
    动作同 = 同.reshape(帧数, 帧数 // 3, 3, 格, 格).any(2)             # [帧, 动作, 行, 列]
    for i in range(帧数):
        动作同[i, i // 3] = False
    帧同 = 同.copy()
    for i in range(帧数):
        帧同[i, i // 3 * 3:i // 3 * 3 + 3] = False
    动作数, 帧同数 = 动作同.sum(1), 帧同.sum(1)
    自己的 = (归位 == 键头0[None]) | (动作数 >= 3) | ((动作数 >= 2) & (帧同数 >= 6))
    # 被挡住的地方拿哪一帧来补：别的动作里和这一帧的头最像的那一帧
    参照 = []
    for i in range(帧数):
        像 = 同[i].reshape(帧数, -1).sum(1)
        像[i // 3 * 3:i // 3 * 3 + 3] = -1
        参照.append(int(像.argmax()))
    for i in range(帧数):
        帧 = 取帧(图, i)
        实 = 帧[..., 3] > 0
        键 = 色键(帧)
        dx, dy = 位移[i]
        切 = 切0 + dy
        上 = np.zeros((格, 格), bool)
        上[:max(min(切, 格), 0)] = True
        移形 = 平移(头形0, dx, dy)

        def 下摆(头上):
            # 第 1 帧照行走图的办法量；别的帧把第 1 帧量到的整体平移过来（颜色还对得上的才算），垂下来的头发另外再漫一遍。
            # 不在每一帧重新量下巴，是因为手会举到下巴旁边，肤色一样，会被当成下巴吃掉半只。
            if i == 0:
                return 下摆一格(帧, 切, 发色, 头上=头上)
            同位 = 键 == 移键(键摆0, dx, dy)
            return 同位 | 下摆一格(帧, 切, 发色, 头上=头上, 只发=True) if 垂发 else 同位

        形 = 移形 & 实 & 上
        # 有的角色别的帧头发会多出几撮（受伤时炸起来）：挨着头形、颜色是头发的都算头，贴着它们的描边也算
        候 = 实 & 上 & ~形
        发点 = np.zeros((格, 格), bool)
        暗点 = np.zeros((格, 格), bool)
        for y, x in zip(*np.where(实 & 上)):
            if tuple(帧[y, x, :3]) in 发色:
                发点[y, x] = True
            elif 亮度(帧[y, x, :3]) < 40 and int(键[y, x]) in 头数:   # 头上本来就有的描边色才算（衣领的深色描边不算）
                暗点[y, x] = True
        for 轮 in range(16):
            邻 = np.zeros((格, 格), bool)
            邻发 = np.zeros((格, 格), bool)
            for ddy in (-1, 0, 1):
                for ddx in (-1, 0, 1):
                    邻 |= 平移(形, ddx, ddy)
                    邻发 |= 平移(形 & 发点, ddx, ddy)
            加 = 候 & ~形 & ((发点 & 邻) | (暗点 & (邻发 | (邻 if 轮 < 2 else False))))
            if not 加.any():
                break
            形 |= 加
        # 挡在头前面的身体（举到脸前的拳头、手甲、飘起来的兜帽）：头形里「不是头自己的」点连成的块，
        # 还得和头外面的身体连着，并且块里有身体才有的颜色（手甲），或者够大（10 点以上，光手的拳头）。
        # 下巴行以下也一样看：第 1 帧的下巴、垂发该在的地方换了别的颜色。
        摆初 = 下摆(形)
        异 = 形 & 移形 & ~平移(自己的[i], dx, dy)
        if i:
            异 |= 实 & 平移(摆0, dx, dy) & (键 != 移键(键摆0, dx, dy)) & ~摆初
        外 = 实 & ~形 & ~摆初 & ~异
        if 调试 is not None:
            调试.append(异.copy())
        身色 = np.array(sorted((身色0 | set(int(v) for v in np.unique(键[外]))) - 头色0), np.int64)
        核 = 异 & np.isin(键, 身色)
        挡 = np.zeros((格, 格), bool)
        见 = np.zeros((格, 格), bool)
        for y0, x0 in zip(*np.where(异)):
            if 见[y0, x0]:
                continue
            堆, 栈, 连外 = [], [(y0, x0)], False
            见[y0, x0] = True
            while 栈:
                y, x = 栈.pop()
                堆.append((y, x))
                for ddy in (-1, 0, 1):
                    for ddx in (-1, 0, 1):
                        yy, xx = y + ddy, x + ddx
                        if not (0 <= yy < 格 and 0 <= xx < 格):
                            continue
                        if 外[yy, xx]:
                            连外 = True
                        elif 异[yy, xx] and not 见[yy, xx]:
                            见[yy, xx] = True
                            栈.append((yy, xx))
            if 连外 and (len(堆) >= 10 or any(核[点] for 点 in 堆)):
                for 点 in 堆:
                    挡[点] = True
        变 = (形 | 摆初) & (键 != 移键(键头0, dx, dy)) & (键 != 移键(键摆0, dx, dy))
        for _ in range(2 if 挡.any() else 0):               # 贴着挡块、和第 1 帧不一样的两圈也带上（别的动作里碰巧同色的描边）
            挡 |= 变 & (平移(挡, 1, 0) | 平移(挡, -1, 0) | 平移(挡, 0, 1) | 平移(挡, 0, -1))
        if 挡.any():                                        # 拳头中间和脸同色的几点：四面都被挡块围住的也算
            左 = np.logical_or.accumulate(挡, 1)
            右 = np.logical_or.accumulate(挡[:, ::-1], 1)[:, ::-1]
            上围 = np.logical_or.accumulate(挡, 0)
            下围 = np.logical_or.accumulate(挡[::-1], 0)[::-1]
            挡 |= (形 | 摆初) & 左 & 右 & 上围 & 下围
        形 &= ~挡
        罩 = (形 | 下摆(形)) & ~挡
        # 头拿走以后会落单的小碎点（炸起来的发梢描边）：贴着头、整块在下巴以上、不超过 6 个点的，也跟头走
        余 = 实 & ~罩 & ~挡
        见 = np.zeros((格, 格), bool)
        for y0, x0 in zip(*np.where(余 & 上)):
            if 见[y0, x0]:
                continue
            堆, 栈, 贴头 = [], [(y0, x0)], False
            见[y0, x0] = True
            while 栈 and len(堆) <= 6:
                y, x = 栈.pop()
                堆.append((y, x))
                for ddy in (-1, 0, 1):
                    for ddx in (-1, 0, 1):
                        yy, xx = y + ddy, x + ddx
                        if not (0 <= yy < 格 and 0 <= xx < 格):
                            continue
                        if 罩[yy, xx]:
                            贴头 = True
                        elif 余[yy, xx] and not 见[yy, xx]:
                            见[yy, xx] = True
                            栈.append((yy, xx))
            if not 栈 and len(堆) <= 6 and 贴头 and all(y < 切 and int(键[y, x]) in 头数 for y, x in 堆):
                for 点 in 堆:
                    罩[点] = True
        头罩.append(罩)
        遮挡.append(挡)
    return {"下巴行": 切0, "位移": 位移, "匹配": 匹配, "头罩": 头罩, "遮挡": 遮挡, "整头": 头形0 | 摆0, "参照": 参照, "垂发": bool(垂发)}


def 拼(节, 素材: Path):
    头图 = 读战斗图(素材, 节["头"])
    身图 = 读战斗图(素材, 节["身体"])
    头分 = 分头(头图, 节.get("头下巴行"), 节.get("去领口", True))
    身分 = 分头(身图, 节.get("身体下巴行"), False)
    提示 = [f"下巴行：头 {头分['下巴行']}，身体 {身分['下巴行']}"]
    for 名, 分 in (("头", 头分), ("身体", 身分)):
        差 = [i + 1 for i, 比 in enumerate(分["匹配"]) if 比 < 0.5]
        if 差:
            提示.append(f"{名}供体有 {len(差)} 帧的头和第 1 帧对不上（第 {差[0]} 帧起），这张图可能不是同一个头平移出来的，放大看一眼")
        if not 分["垂发"]:
            提示.append(f"{名}供体的头发和衣服是一个颜色，分不出垂到肩膀以下的头发，只按下巴切；长发的话肩上会留下一截")
    for 项 in 节.get("换色", []):
        部位 = 项.get("部位", "全部")
        数 = 0
        if 部位 in ("头", "全部"):
            数 += 换色(头图, 项, 格)
        if 部位 in ("身体", "全部"):
            数 += 换色(身图, 项, 格)
        if 数 == 0:
            提示.append(f"换色「{项.get('名', 项.get('选色'))}」在{部位}上一个点都没选中")
    偏x, 偏y = 节.get("头偏移", [0, 0])
    出 = np.zeros((整高, 整宽, 4), np.int32)
    出界 = 0
    头0 = 取帧(头图, 0)
    for i in range(帧数):
        头, 身 = 取帧(头图, i), 取帧(身图, i)
        头罩, 身头 = 头分["头罩"][i], 身分["头罩"][i]
        (hx, hy), (bx, by) = 头分["位移"][i], 身分["位移"][i]
        身切 = 身分["下巴行"] + by
        块 = np.zeros((格, 格, 4), np.int32)
        身罩 = (身[..., 3] > 0) & ~身头
        块[身罩] = 身[身罩]
        去 = 身头 & (身[..., 3] > 0)
        去[:max(身切, 0)] = False
        for y, x in sorted(zip(*np.where(去)), reverse=True):   # 旧下巴、旧头发盖住的身体：左右都有身体才补，照正下方最近的非描边点
            if not (身罩[y, :x].any() and 身罩[y, x + 1:].any()):
                continue
            for 下 in range(y + 1, min(y + 5, 格)):
                if 块[下, x, 3] == 0:
                    break
                if 亮度(块[下, x, :3]) >= 40:
                    块[y, x] = 块[下, x]
                    break
        移x = bx - hx + 偏x
        移y = (身分["下巴行"] + by) - (头分["下巴行"] + hy) + 偏y
        补 = 头分["遮挡"][i] & 平移(头分["整头"], hx, hy) & ~头罩   # 头供体自己的手挡住的那几块脸，拿第 1 帧的补上
        参 = 头分["参照"][i]                                # 先看最像的那一帧同一位置露没露出来，没露就用第 1 帧
        (rx, ry), 参头, 参罩 = 头分["位移"][参], 取帧(头图, 参), 头分["头罩"][参]
        for y, x in zip(*np.where(补)):
            yy, xx = y + 移y, x + 移x
            if 0 <= yy < 格 and 0 <= xx < 格:
                ty, tx = y - hy + ry, x - hx + rx
                块[yy, xx] = 参头[ty, tx] if 0 <= ty < 格 and 0 <= tx < 格 and 参罩[ty, tx] else 头0[y - hy, x - hx]
        for y, x in zip(*np.where(头罩)):
            yy, xx = y + 移y, x + 移x
            if 0 <= yy < 格 and 0 <= xx < 格:
                块[yy, xx] = 头[y, x]
            else:
                出界 += 1
        挡 = 身分["遮挡"][i]                               # 身体供体挡在头前面的手，盖回头上面
        块[挡] = 身[挡]
        去孤点(块, 身切)
        for x, y, 色 in 节.get("点缀", []):                  # 点缀按第 1 帧的位置写，跟着头走
            yy, xx = y + by, x + bx
            if 0 <= yy < 格 and 0 <= xx < 格:
                块[yy, xx] = [int(v) for v in np.round(十六进制(色))] + [255]
        y0, x0 = 帧位(i)
        出[y0:y0 + 格, x0:x0 + 格] = 块
    if 出界:
        提示.append(f"头有 {出界} 个点超出格子被裁掉了")
    return 出, 提示


def 命令_导出(参):
    配方 = json.loads(Path(参.配方).read_text(encoding="utf-8"))
    if "战斗图" not in 配方:
        raise SystemExit("配方里没有「战斗图」一节")
    出, 提示 = 拼(配方["战斗图"], Path(参.素材))
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(出.astype(np.uint8), "RGBA").save(参.输出, optimize=False)
    print(f"已导出 {参.输出}（头 {配方['战斗图']['头']}，身体 {配方['战斗图']['身体']}）")
    for 句 in 提示:
        print("注意：" + 句)


def 全部战斗图(素材: Path, 排除=("Codex",)):
    """素材目录里尺寸标准的战斗图。文件名带「Codex」的是后来补画的，不是原版，默认不收。"""
    for 路 in sorted(素材.glob("*.png")):
        if any(词 in 路.name for 词 in 排除):
            continue
        try:
            with Image.open(路) as 图:
                if 图.size != (整宽, 整高):
                    continue
        except OSError:
            continue
        yield 路.name


def 命令_目录(参):
    字 = ImageFont.truetype(参.字体, 11) if 参.字体 else ImageFont.load_default()
    倍 = 参.倍数
    素材 = Path(参.素材)
    名们 = [名 for 名 in 全部战斗图(素材) if not 参.筛 or 参.筛 in 名]
    if not 名们:
        raise SystemExit("没有符合条件的战斗图")
    宽格, 高格 = 格 * 倍 + 8, 格 * 倍 + 16
    每页 = 参.每行 * 参.每页行
    出 = Path(参.输出)
    出.mkdir(parents=True, exist_ok=True)
    for 页 in range(0, len(名们), 每页):
        批 = 名们[页:页 + 每页]
        行 = (len(批) + 参.每行 - 1) // 参.每行
        布 = Image.new("RGBA", (参.每行 * 宽格, 行 * 高格), (58, 62, 70, 255))
        画 = ImageDraw.Draw(布)
        for i, 名 in enumerate(批):
            x0, y0 = (i % 参.每行) * 宽格, (i // 参.每行) * 高格
            小 = Image.fromarray(取帧(读战斗图(素材, 名), 0).astype(np.uint8), "RGBA").resize((格 * 倍, 格 * 倍), Image.NEAREST)
            布.alpha_composite(小, (x0, y0))
            画.text((x0 + 2, y0 + 格 * 倍 + 1), 名[:-4][:18], fill=(235, 235, 235, 255), font=字)
        路 = 出 / f"战斗图目录_{页 // 每页 + 1:02d}.png"
        布.save(路)
        print(f"{路}：{len(批)} 张")
    print(f"共 {len(名们)} 张标准尺寸的战斗图")


def 命令_取色(参):
    图 = 读战斗图(Path(参.素材), 参.名)
    分 = 分头(图, 参.下巴行, False)
    低 = sum(1 for 比 in 分["匹配"] if 比 < 0.5)
    print(f"下巴行 {分['下巴行']}；54 帧里头对得上的有 {帧数 - 低} 帧")
    头点, 身点 = [], []
    for i in range(帧数):
        帧 = 取帧(图, i)
        实 = 帧[..., 3] > 0
        头点.append(帧[实 & 分["头罩"][i]])
        身点.append(帧[实 & ~分["头罩"][i]])
    列颜色("头", np.concatenate(头点))
    列颜色("身体", np.concatenate(身点))


def main(argv=None):
    p = argparse.ArgumentParser(description="战斗图角色生成器（原型）")
    子 = p.add_subparsers(dest="命令", required=True)
    a = 子.add_parser("目录", help="把素材目录里的战斗图排成带名字的一览图")
    a.add_argument("--素材", required=True)
    a.add_argument("--输出", required=True, help="放一览图的文件夹")
    a.add_argument("--筛", help="只列文件名里带这段字的")
    a.add_argument("--倍数", type=int, default=2)
    a.add_argument("--每行", type=int, default=16)
    a.add_argument("--每页行", type=int, default=8)
    a.add_argument("--字体")
    a.set_defaults(函数=命令_目录)
    b = 子.add_parser("取色", help="列出一张战斗图头上、身上的颜色")
    b.add_argument("名")
    b.add_argument("--素材", required=True)
    b.add_argument("--下巴行", type=int, help="不写就自动量")
    b.set_defaults(函数=命令_取色)
    c = 子.add_parser("导出", help="按配方的「战斗图」一节导出")
    c.add_argument("配方")
    c.add_argument("输出")
    c.add_argument("--素材", required=True)
    c.set_defaults(函数=命令_导出)
    参 = p.parse_args(argv)
    参.函数(参)


if __name__ == "__main__":
    main()
