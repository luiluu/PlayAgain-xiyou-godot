#!/usr/bin/env python3
"""行走图角色生成器（原型）：拿原版角色当部件库，选头、选身体、换色，一条命令导出 `$` 行走图。

原版的行走图绝大多数是同一套 Q 版骨架（48×48 一格，脚底贴格底，迈步时头往下沉 1 点），
所以任意两个角色的头和身体可以直接对上。部件就是原版的像素，画工和原版完全一样；
生成器只做三件事：换部件、换颜色、加几个点（纹、饰物）。

  目录  把素材目录里的角色排成带编号的一览图，用来挑部件
  取色  列出某个角色头上、身上主要有哪几种颜色，写配方时照着填
  导出  按配方拼头和身体、换色、加点缀，导出 144×192 的行走图

部件写成「文件名#序号」：8 人一张的图序号 0～7（先上排从左到右，再下排）；`$` 单人图不用写序号。
同样的素材和配方，导出结果逐字节相同。

素材目录是原版的 img/characters（不在仓库里，路径由 --素材 给）。依赖：Pillow、numpy。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from 行走图 import 亮度, 十六进制, 色带取色, 方向名  # noqa: E402

格 = 48
列数, 行数 = 3, 4
站立列 = 1
默认脖子行 = 30      # 站立帧里身体的第一行；迈步帧再往下 1 行。量不出来时用它


# ---------- 读素材 ----------

def 色相饱和(色: np.ndarray):
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


def 切块(图: np.ndarray, 名: str, 序: int):
    """从一张素材图里取出一个角色的 12 帧。不是标准骨架时返回 None。"""
    高, 宽 = 图.shape[:2]
    if 名.startswith("$") or 名.startswith("!$"):
        块 = 图
    else:
        if 宽 % 12 or 高 % 8:
            return None
        行, 列 = divmod(序, 4)
        块 = 图[行 * 高 // 2:(行 + 1) * 高 // 2, 列 * 宽 // 4:(列 + 1) * 宽 // 4]
    if 块.shape[:2] != (行数 * 格, 列数 * 格):
        return None
    块 = 块.copy()
    实 = 块[..., 3] >= 128
    块[..., 3] = np.where(实, 255, 0)
    块[~实] = 0
    return 块


def 读部件(素材: Path, 号: str) -> np.ndarray:
    """返回 192×144 的 12 帧图（RGBA，alpha 只有 0 和 255）。"""
    名, _, 序 = 号.partition("#")
    路 = 素材 / 名
    if not 路.exists():
        raise SystemExit(f"素材目录里没有 {名}")
    图 = np.array(Image.open(路).convert("RGBA")).astype(np.int32)
    块 = 切块(图, 名, int(序 or 0))
    if 块 is None:
        raise SystemExit(f"{号} 一格不是 {格}×{格}，不是标准骨架，不能当部件")
    return 块


def 取格(图, 行, 列):
    return 图[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格]


def 头沉(图, 行, 列) -> int:
    """迈步帧的头比站立帧低几点。头顶被格子上边裁掉、量不出来时按原版骨架的 1。"""
    if 列 == 站立列:
        return 0

    def 顶(块):
        ys = np.where((块[..., 3] > 0).any(1))[0]
        return int(ys.min()) if len(ys) else None

    a, b = 顶(取格(图, 行, 站立列)), 顶(取格(图, 行, 列))
    if a is None or b is None or a == 0 or b == 0 or not 0 <= b - a <= 2:
        return 1
    return b - a


# ---------- 头和身体的分界 ----------

def 找脖子行(图) -> int:
    """身体的第一行（站立帧）。看正面：脸中间一列肤色往下走，走到下巴的描边为止，描边那一行的上一行算头的最后一行。

    原版有两套头：生成器捏的（多数，结果是 30）和手绘的大头（31～34）。
    不是肤色的脸（面具、兽人）量不出来，按 30；配方里可以用「头脖子行」「身体脖子行」直接写。
    """
    正 = 取格(图, 0, 站立列)
    h, s = 色相饱和(正)
    L = 亮度(正[..., :3])
    肤 = (正[..., 3] > 0) & (h >= 5) & (h <= 45) & (s >= 0.12) & (s <= 0.8) & (L >= 90)
    for y in range(28, 38):
        if 肤[y, 21:26].sum() < 3:
            return y - 1 if y >= 30 else 默认脖子行
    return 默认脖子行


def 头的下摆(图, 脖) -> np.ndarray:
    """头伸到脖子行以下的部分：压在肩膀上的下巴、垂下来的头发，连同贴着它们的描边。返回整块的罩。

    认法是从脖子行的上一行往下「漫」：头发的颜色（头顶出现过的）能一直漫下去，
    脸的颜色最多漫 3 行（下巴），碰到描边就停。
    """
    罩 = np.zeros(图.shape[:2], bool)
    正 = 取格(图, 0, 站立列)
    颈肤 = {tuple(正[y, x, :3]) for y in range(脖 - 8, 脖) for x in range(20, 28) if 正[y, x, 3] > 0}   # 脸下半截的颜色是皮肤，不算头发（光头）
    for 行 in range(行数):
        站 = 取格(图, 行, 站立列)
        ys = np.where((站[..., 3] > 0).any(1))[0]
        if len(ys) == 0:
            continue
        顶 = int(ys.min())
        冠 = 站[顶:顶 + 10]
        冠色: dict = {}
        for 点 in 冠[(冠[..., 3] > 0) & (亮度(冠[..., :3]) >= 40)][:, :3]:
            冠色[tuple(点)] = 冠色.get(tuple(点), 0) + 1
        发色 = {色 for 色, 次 in 冠色.items() if 次 >= 2} - 颈肤
        for 列 in range(列数):
            块 = 取格(图, 行, 列)
            切 = 脖 + 头沉(图, 行, 列)
            实 = 块[..., 3] > 0
            暗 = 实 & (亮度(块[..., :3]) < 40)
            颌 = 块[切 - 3:切]
            颌色 = {tuple(p) for p in 颌[(颌[..., 3] > 0) & (亮度(颌[..., :3]) >= 40)][:, :3]} - 发色
            选 = np.zeros((格, 格), bool)
            栈 = [(切 - 1, x) for x in range(格) if 实[切 - 1, x] and not 暗[切 - 1, x]]
            见 = set(栈)
            while 栈:
                y, x = 栈.pop()
                if y >= 切:
                    选[y, x] = True
                是发 = tuple(块[y, x, :3]) in 发色
                for dy, dx in ((1, 0), (0, -1), (0, 1), (-1, 0)) + (((1, 1), (1, -1)) if 是发 else ()):
                    yy, xx = y + dy, x + dx
                    if not (切 - 1 <= yy < 格 and 0 <= xx < 格) or (yy, xx) in 见 or not 实[yy, xx] or 暗[yy, xx]:
                        continue
                    色 = tuple(块[yy, xx, :3])
                    if 色 in 发色 or (色 in 颌色 and yy <= 切 + 2):
                        见.add((yy, xx))
                        栈.append((yy, xx))
            边 = np.zeros((格, 格), bool)
            for y, x in zip(*np.where(暗)):                   # 贴着下巴、发梢的描边
                if y >= 切 and any(0 <= y + dy < 格 and 0 <= x + dx < 格 and 选[y + dy, x + dx]
                                  for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                    边[y, x] = True
            for y, x in zip(*np.where(暗)):                   # 描边有两点宽的地方，把外面那一点也带上
                if y >= 切 and not 边[y, x] and any(0 <= x + dx < 格 and 边[y, x + dx] for dx in (-1, 1)):
                    选[y, x] = True
            选 |= 边
            # 悬空的描边（正下方没有身体托着）是伸到身体外面的发梢，也算头的；只看脖子下 3 行，而且要和头连着
            悬 = np.zeros((格, 格), bool)
            底 = min(切 + 2, 格 - 1)
            for y in range(底, 切 - 1, -1):
                for x in np.where(暗[y] & ~选[y])[0]:
                    下 = y + 1
                    托 = 下 < 格 and 实[下, x] and not 选[下, x] and not 悬[下, x]
                    悬[y, x] = not 托
            栈 = [(y, x) for y, x in zip(*np.where(悬))
                  if any(0 <= y + dy < 格 and 0 <= x + dx < 格 and (选[y + dy, x + dx] or (y + dy < 切 and 实[y + dy, x + dx]))
                         for dy in (-1, 0, 1) for dx in (-1, 0, 1))]
            连 = set(栈)
            while 栈:
                y, x = 栈.pop()
                选[y, x] = True
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < 格 and 0 <= xx < 格 and 悬[yy, xx] and (yy, xx) not in 连:
                            连.add((yy, xx))
                            栈.append((yy, xx))
            罩[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格] = 选
    return 罩


def 去领口(图, 脖) -> int:
    """头供体脖子上方几行里常带着它原来衣服的领口。认法：这种颜色在头的上半截从没出现过。就地擦掉，返回擦了几点。"""
    数 = 0
    for 行 in range(行数):
        上色 = set()
        for 列 in range(列数):
            块 = 取格(图, 行, 列)
            上 = 块[:脖 - 4]
            上色 |= {tuple(p) for p in 上[上[..., 3] > 0][:, :3]}
        for 列 in range(列数):
            块 = 取格(图, 行, 列)
            切 = 脖 + 头沉(图, 行, 列)
            for y in range(切 - 4, 切):
                for x in range(格):
                    if 块[y, x, 3] > 0 and 亮度(块[y, x, :3]) >= 40 and tuple(块[y, x, :3]) not in 上色:
                        块[y, x] = 0
                        数 += 1
            for _ in range(2):                                # 领口擦掉后落单的描边一并擦掉
                for y in range(切 - 4, 切):
                    for x in range(格):
                        if 块[y, x, 3] > 0 and 亮度(块[y, x, :3]) < 40:
                            邻 = [块[y + dy, x + dx] for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1))
                                  if 0 <= y + dy < 切 and 0 <= x + dx < 格]
                            if not any(p[3] > 0 and 亮度(p[:3]) >= 40 for p in 邻):
                                块[y, x] = 0
    return 数


# ---------- 换色 ----------

def 选罩(图, 项) -> np.ndarray:
    """按「选色」挑出同一种材质的像素：色相接近、饱和度接近；选的是灰白黑时按亮度挑。"""
    实 = 图[..., 3] > 0
    h, s = 色相饱和(图)
    L = 亮度(图[..., :3])
    if isinstance(项["选色"], list):           # 直接点名几种颜色，最准
        罩 = np.zeros(图.shape[:2], bool)
        for 色 in 项["选色"]:
            罩 |= (图[..., :3] == np.round(十六进制(色)).astype(np.int32)).all(-1)
        return 罩 & 实 & 限定(图, 项)
    选 = 十六进制(项["选色"])[None, None, :]
    sh, ss = 色相饱和(选)
    sh, ss, sL = float(sh[0, 0]), float(ss[0, 0]), float(亮度(选)[0, 0])
    if ss < 0.15:
        罩 = 实 & (s < 项.get("最高饱和", 0.2)) & (np.abs(L - sL) <= 项.get("亮度容差", 70))
    else:
        距 = np.abs(h - sh)
        距 = np.minimum(距, 360 - 距)
        罩 = 实 & (距 <= 项.get("色相容差", 18)) & (s >= 项.get("最低饱和", 0.15)) & (np.abs(s - ss) <= 项.get("饱和容差", 0.35))
        罩 &= L >= 项.get("最低亮度", 25)      # 近黑的描边不动
    return 罩 & 限定(图, 项)


def 限定(图, 项) -> np.ndarray:
    罩 = np.ones(图.shape[:2], bool)
    if "行范围" in 项:                         # 只换格子里第几行到第几行（含两头），比如只换裤子
        上, 下 = 项["行范围"]
        行号 = np.arange(图.shape[0]) % 格
        罩 &= ((行号 >= 上) & (行号 <= 下))[:, None]
    if "列范围" in 项:                         # 格子里第几列到第几列（含两头）
        左, 右 = 项["列范围"]
        列号 = np.arange(图.shape[1]) % 格
        罩 &= ((列号 >= 左) & (列号 <= 右))[None, :]
    if "方向" in 项:
        限 = np.zeros(图.shape[:2], bool)
        for 向 in 项["方向"] if isinstance(项["方向"], list) else [项["方向"]]:
            行 = 方向名.index(向)
            限[行 * 格:(行 + 1) * 格] = True
        罩 &= 限
    return 罩


def 换色(图, 项) -> int:
    罩 = 选罩(图, 项)
    if not 罩.any():
        return 0
    L = 亮度(图[..., :3])
    全 = L[罩]
    暗, 明 = float(np.percentile(全, 1)), float(np.percentile(全, 99))
    t = np.clip((L[罩] - 暗) / max(明 - 暗, 1.0), 0, 1)
    图[罩, :3] = np.round(色带取色(项["色带"], t)).astype(np.int32)
    return int(罩.sum())


# ---------- 拼 ----------

def 去孤点(块, 切):
    """脖子附近和谁都不挨着的三两个点（旧发梢擦剩下的）擦掉。"""
    实 = 块[..., 3] > 0
    见 = np.zeros((格, 格), bool)
    for y0 in range(max(切 - 1, 0), min(切 + 6, 格)):
        for x0 in range(格):
            if not 实[y0, x0] or 见[y0, x0]:
                continue
            堆, 栈 = [], [(y0, x0)]
            见[y0, x0] = True
            while 栈:
                y, x = 栈.pop()
                堆.append((y, x))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < 格 and 0 <= xx < 格 and 实[yy, xx] and not 见[yy, xx]:
                            见[yy, xx] = True
                            栈.append((yy, xx))
            if len(堆) <= 4:
                for y, x in 堆:
                    块[y, x] = 0


def 拼(配方, 素材: Path, 配方目录: Path):
    头图 = 读部件(素材, 配方["头"])
    身图 = 读部件(素材, 配方["身体"])
    头脖 = 配方.get("头脖子行") or 找脖子行(头图)
    身脖 = 配方.get("身体脖子行") or 找脖子行(身图)
    提示 = [f"脖子行：头 {头脖}，身体 {身脖}"]
    if 配方.get("去领口", True):
        去领口(头图, 头脖)
    头摆 = 头的下摆(头图, 头脖)
    身摆 = 头的下摆(身图, 身脖)
    for 项 in 配方.get("换色", []):
        部位 = 项.get("部位", "全部")
        数 = 0
        if 部位 in ("头", "全部"):
            数 += 换色(头图, 项)
        if 部位 in ("身体", "全部"):
            数 += 换色(身图, 项)
        if 数 == 0:
            提示.append(f"换色「{项.get('名', 项['选色'])}」在{部位}上一个点都没选中")
    出 = np.zeros((行数 * 格, 列数 * 格, 4), np.int32)
    空洞, 出顶 = 0, 0
    for 行 in range(行数):
        for 列 in range(列数):
            头, 身 = 取格(头图, 行, 列), 取格(身图, 行, 列)
            头切 = 头脖 + 头沉(头图, 行, 列)
            身切 = 身脖 + 头沉(身图, 行, 列)
            块 = np.zeros((格, 格, 4), np.int32)
            身罩 = 身[..., 3] > 0
            身罩[:身切] = False
            去 = 取格(身摆, 行, 列) & 身罩
            空洞 = max(空洞, int(去.sum()))
            身罩 &= ~去
            块[身罩] = 身[身罩]
            for y, x in sorted(zip(*np.where(去)), reverse=True):   # 擦掉的地方照正下方最近的非描边点补上；下面是空的就留空
                for 下 in range(y + 1, min(y + 5, 格)):
                    if 块[下, x, 3] == 0:
                        break
                    if 亮度(块[下, x, :3]) >= 40:
                        块[y, x] = 块[下, x]
                        break
            移 = 身切 - 头切
            头罩 = 头[..., 3] > 0
            头罩[头切:] = False
            头罩 |= 取格(头摆, 行, 列)
            for y, x in zip(*np.where(头罩)):
                yy = y + 移
                if 0 <= yy < 格:
                    块[yy, x] = 头[y, x]
                elif yy < 0:
                    出顶 += 1
            去孤点(块, 身切)
            出[行 * 格:(行 + 1) * 格, 列 * 格:(列 + 1) * 格] = 块
    if 空洞 > 160:
        提示.append(f"身体供体有一帧被它自己的长发遮了 {空洞} 个点，是照着正下方的颜色补的，放大看一眼；不行就换短发的身体供体")
    if 出顶:
        提示.append(f"头顶有 {出顶} 个点超出格子被裁掉了；换矮一点的发型，或者换脖子行更靠上的身体")
    for 组 in 配方.get("点缀", []):
        for 向 in 组["方向"] if isinstance(组["方向"], list) else [组["方向"]]:
            行 = 方向名.index(向)
            for 列 in range(列数):
                沉 = 头沉(身图, 行, 列)
                for x, y, 色 in 组["点"]:
                    yy = y + (沉 if y < 身脖 else 0)
                    if 0 <= yy < 格 and 0 <= x < 格:
                        出[行 * 格 + yy, 列 * 格 + x] = [int(v) for v in np.round(十六进制(色))] + [255]
    if 配方.get("图层"):
        层 = np.array(Image.open(配方目录 / 配方["图层"]).convert("RGBA")).astype(np.int32)
        if 层.shape != 出.shape:
            raise SystemExit(f"图层尺寸要 {出.shape[1]}×{出.shape[0]}")
        罩 = 层[..., 3] >= 128
        出[罩] = 层[罩]
        出[罩, 3] = 255
    return 出, 提示


def 命令_导出(参):
    配方路 = Path(参.配方)
    配方 = json.loads(配方路.read_text(encoding="utf-8"))
    出, 提示 = 拼(配方, Path(参.素材), 配方路.parent)
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(出.astype(np.uint8), "RGBA").save(参.输出, optimize=False)
    print(f"已导出 {参.输出}（头 {配方['头']}，身体 {配方['身体']}）")
    for 句 in 提示:
        print("注意：" + 句)


# ---------- 目录 ----------

def 全部部件(素材: Path, 排除=("Codex",)):
    """素材目录里所有标准骨架的角色。文件名带「Codex」的是后来补画的，不是原版，默认不收。"""
    for 路 in sorted(素材.glob("*.png")):
        名 = 路.name
        if 名.startswith("!") or any(词 in 名 for 词 in 排除):
            continue
        try:
            图 = np.array(Image.open(路).convert("RGBA")).astype(np.int32)
        except OSError:
            continue
        单 = 名.startswith("$")
        for 序 in range(1 if 单 else 8):
            块 = 切块(图, 名, 序)
            if 块 is None or (块[..., 3] > 0).sum() < 200:
                continue
            yield (名 if 单 else f"{名}#{序}"), 块


def 命令_目录(参):
    字 = ImageFont.truetype(参.字体, 11) if 参.字体 else ImageFont.load_default()
    倍 = 参.倍数
    件 = [(号, 图) for 号, 图 in 全部部件(Path(参.素材)) if not 参.筛 or 参.筛 in 号]
    if not 件:
        raise SystemExit("没有符合条件的角色")
    宽格, 高格 = 格 * 倍 * 2 + 8, 格 * 倍 + 16
    每页 = 参.每行 * 参.每页行
    出 = Path(参.输出)
    出.mkdir(parents=True, exist_ok=True)
    for 页 in range(0, len(件), 每页):
        批 = 件[页:页 + 每页]
        行 = (len(批) + 参.每行 - 1) // 参.每行
        布 = Image.new("RGBA", (参.每行 * 宽格, 行 * 高格), (58, 62, 70, 255))
        画 = ImageDraw.Draw(布)
        for i, (号, 图) in enumerate(批):
            x0, y0 = (i % 参.每行) * 宽格, (i // 参.每行) * 高格
            for j, 向 in enumerate((0, 1)):                  # 正面和左侧的站立帧
                小 = Image.fromarray(取格(图, 向, 站立列).astype(np.uint8), "RGBA")
                小 = 小.resize((格 * 倍, 格 * 倍), Image.NEAREST)
                布.alpha_composite(小, (x0 + j * 格 * 倍, y0))
            画.text((x0 + 2, y0 + 格 * 倍 + 1), 号.replace(".png", ""), fill=(235, 235, 235, 255), font=字)
        名 = 出 / f"目录_{页 // 每页 + 1:02d}.png"
        布.save(名)
        print(f"{名}：{len(批)} 个角色")
    print(f"共 {len(件)} 个标准骨架的角色")


# ---------- 取色 ----------

def 命令_取色(参):
    图 = 读部件(Path(参.素材), 参.部件)
    脖 = 参.脖子行 or 找脖子行(图)
    print(f"脖子行 {脖}")
    行号 = (np.arange(图.shape[0]) % 格)[:, None] * np.ones((1, 图.shape[1]), int)
    for 名, 区 in (("头", 行号 < 脖), ("身体", 行号 >= 脖)):
        罩 = (图[..., 3] > 0) & 区
        数: dict = {}
        for 点 in 图[罩][:, :3]:
            数[tuple(int(v) for v in 点)] = 数.get(tuple(int(v) for v in 点), 0) + 1
        组: dict = {}
        for 色, 次 in 数.items():
            a = np.array(色, float)[None, None, :]
            h, s = 色相饱和(a)
            h, s, L = float(h[0, 0]), float(s[0, 0]), float(亮度(a)[0, 0])
            键 = "近黑描边" if L < 25 else ("灰白" if s < 0.15 else f"色相{int(h // 24) * 24:03d}")
            组.setdefault(键, []).append((L, 色, 次))
        print(f"【{名}】")
        for 键, 列 in sorted(组.items(), key=lambda kv: -sum(c for _, _, c in kv[1])):
            总 = sum(c for _, _, c in 列)
            if 总 < 6:
                continue
            列.sort()
            多 = max(列, key=lambda v: v[2])[1]
            列 = [v for v in 列 if v[2] >= 3] or 列
            样 = " ".join("#%02X%02X%02X" % 色 for _, 色, _ in (列 if len(列) <= 12 else 列[:: len(列) // 10 + 1]))
            print(f"  {键:8s} {总:5d} 点  选色 #%02X%02X%02X  从暗到亮：{样}" % 多)


def main(argv=None):
    p = argparse.ArgumentParser(description="行走图角色生成器（原型）")
    子 = p.add_subparsers(dest="命令", required=True)
    a = 子.add_parser("目录", help="把素材目录里的角色排成带编号的一览图")
    a.add_argument("--素材", required=True)
    a.add_argument("--输出", required=True, help="放一览图的文件夹")
    a.add_argument("--筛", help="只列文件名里带这段字的")
    a.add_argument("--倍数", type=int, default=2)
    a.add_argument("--每行", type=int, default=10)
    a.add_argument("--每页行", type=int, default=8)
    a.add_argument("--字体")
    a.set_defaults(函数=命令_目录)
    b = 子.add_parser("取色", help="列出一个角色头上、身上的主要颜色")
    b.add_argument("部件")
    b.add_argument("--素材", required=True)
    b.add_argument("--脖子行", type=int, help="不写就自动量")
    b.set_defaults(函数=命令_取色)
    c = 子.add_parser("导出", help="按配方导出行走图")
    c.add_argument("配方")
    c.add_argument("输出")
    c.add_argument("--素材", required=True)
    c.set_defaults(函数=命令_导出)
    参 = p.parse_args(argv)
    参.函数(参)


if __name__ == "__main__":
    main()
