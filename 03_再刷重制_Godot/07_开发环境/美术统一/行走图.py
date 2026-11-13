#!/usr/bin/env python3
"""行走图稳定出图工具（原型）。

三个子命令：
  体检  量一张行走图，和基准图比，不合格就退出码 1（出图门禁）
  换装  拿基准行走图当模板，按配方换色、叠加，生成新角色行走图（同样输入必得同样输出）
  预览  把几张行走图并排放大成一张对比图

只处理 `$` 单人行走图（3 列×4 行）。图片不进仓库：输入输出路径都由命令行给。
依赖：Pillow、numpy。
"""
from __future__ import annotations

import argparse
import colorsys
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

列数, 行数 = 3, 4
方向名 = ["下", "左", "右", "上"]


# ---------- 基础 ----------

def 读图(路径: str) -> np.ndarray:
    return np.array(Image.open(路径).convert("RGBA")).astype(np.int32)


def 切格(图: np.ndarray):
    高, 宽 = 图.shape[:2]
    if 宽 % 列数 or 高 % 行数:
        raise SystemExit(f"图尺寸 {宽}×{高} 不能整除成 {列数}×{行数} 格")
    格宽, 格高 = 宽 // 列数, 高 // 行数
    for 行 in range(行数):
        for 列 in range(列数):
            yield 行, 列, 图[行 * 格高:(行 + 1) * 格高, 列 * 格宽:(列 + 1) * 格宽]


def 亮度(色: np.ndarray) -> np.ndarray:
    return 0.299 * 色[..., 0] + 0.587 * 色[..., 1] + 0.114 * 色[..., 2]


def 外缘(实: np.ndarray) -> np.ndarray:
    垫 = np.pad(实, 1)
    四邻都实 = 垫[:-2, 1:-1] & 垫[2:, 1:-1] & 垫[1:-1, :-2] & 垫[1:-1, 2:]
    return 实 & ~四邻都实


def 找脖子(实: np.ndarray):
    """返回 (顶行, 脖子行, 底行)。脖子＝身高 40%～80% 之间最窄的一行（并列取靠下）。"""
    行有 = np.where(实.any(1))[0]
    顶, 底 = int(行有.min()), int(行有.max())
    高 = 底 - 顶 + 1
    宽 = 实.sum(1)
    段 = range(顶 + int(高 * 0.4), 顶 + int(高 * 0.8))
    脖 = min(段, key=lambda y: (宽[y], -y))
    return 顶, int(脖), 底


# ---------- 体检 ----------

def 量一格(格: np.ndarray) -> dict:
    透明度 = 格[..., 3]
    实 = 透明度 >= 128
    if not 实.any():
        return {"空": True}
    顶, 脖, 底 = 找脖子(实)
    列有 = np.where(实.any(0))[0]
    宽 = 实.sum(1)
    色 = 格[..., :3]
    计 = {}
    for 点 in 色[实] // 16:      # 每个通道归到 16 档再数，手绘像素图和缩小出来的柔边图才能放一起比
        键 = (int(点[0]), int(点[1]), int(点[2]))
        计[键] = 计.get(键, 0) + 1
    边 = 外缘(实)
    亮 = 亮度(色)
    # 死黑线：外缘的近黑点，里面紧挨着的却是亮色。深色头发、深色衣服自己的暗边不算
    里 = 实 & ~边
    垫亮 = np.pad(np.where(里, 亮, 0), 1)
    邻最亮 = np.maximum.reduce([垫亮[:-2, 1:-1], 垫亮[2:, 1:-1], 垫亮[1:-1, :-2], 垫亮[1:-1, 2:]])
    死黑 = 边 & (亮 < 40) & (邻最亮 > 110)
    差x = (np.abs(色[:, 1:] - 色[:, :-1]).sum(-1) > 24) & 实[:, 1:] & 实[:, :-1]
    差y = (np.abs(色[1:] - 色[:-1]).sum(-1) > 24) & 实[1:] & 实[:-1]
    return {
        "空": False,
        "顶": 顶, "底": 底, "左": int(列有.min()), "右": int(列有.max()),
        "身高": 底 - 顶 + 1,
        "头占比": (脖 - 顶) / (底 - 顶 + 1),
        "头宽": int(宽[顶:脖].max()),
        "身宽": int(宽[脖:].max()),
        "色数": sum(1 for 次 in 计.values() if 次 >= 3),
        "细节": float((差x.sum() + 差y.sum()) / (2 * 实.sum())),
        "死黑线占比": float(死黑.sum() / max(边.sum(), 1)),
        "半透明": int(((透明度 > 0) & (透明度 < 255)).sum()),
    }


def 量整张(路径: str) -> dict:
    图 = 读图(路径)
    格高, 格宽 = 图.shape[0] // 行数, 图.shape[1] // 列数
    每格 = [(行, 列, 量一格(格)) for 行, 列, 格 in 切格(图)]
    有 = [m for _, _, m in 每格 if not m["空"]]
    if not 有:
        raise SystemExit(f"{路径}：整张都是透明的")
    均 = lambda 键: float(np.mean([m[键] for m in 有]))
    return {
        "路径": 路径, "格宽": 格宽, "格高": 格高, "空格数": len(每格) - len(有),
        "身高": 均("身高"), "头占比": 均("头占比"), "头宽": 均("头宽"), "身宽": 均("身宽"),
        "色数": 均("色数"), "细节": 均("细节"), "死黑线占比": 均("死黑线占比"),
        "半透明": int(sum(m["半透明"] for m in 有)),
        "身高差": max(m["身高"] for m in 有) - min(m["身高"] for m in 有),
        "底边差": max(m["底"] for m in 有) - min(m["底"] for m in 有),
        "贴边格": [f"{方向名[行]}{列}" for 行, 列, m in 每格
                 if not m["空"] and (m["左"] == 0 or m["右"] == 格宽 - 1)],
    }


# 每项：(名字, 怎么比, 说明)。基准范围取几张基准图的最小～最大，再放宽。
规则 = [
    ("头占比", ("范围", 0.05), "头占身高的比例；小了就是头小身子大，不像原版的二头身"),
    ("头宽", ("范围", 2.5), "头最宽处的像素数"),
    ("身高", ("范围", 2.0), "人物可见高"),
    ("色数", ("下限", 0.6), "每格用到的颜色数（每通道归 16 档、出现 3 点以上的才算）；太少就是平涂、没明暗层次"),
    ("细节", ("下限", 0.75), "人物内部相邻像素变色的比例；太低就是大片死色"),
    ("死黑线占比", ("上限", 0.1), "外缘上「近黑、里面却紧挨亮色」的点占多少；高了就是亮色外面套了一圈死黑线，原版是带色的选择性描边"),
]


def 体检(待测: dict, 基准们: list[dict]) -> list[tuple]:
    结果 = []
    for 键, (法, 松), 说明 in 规则:
        值们 = [b[键] for b in 基准们]
        小, 大 = min(值们), max(值们)
        if 法 == "范围":
            下, 上 = 小 - 松, 大 + 松
        elif 法 == "上限":
            下, 上 = 0.0, 大 + 松
        else:
            下, 上 = 小 * 松, float("inf")
        结果.append((键, 待测[键], 下, 上, 下 <= 待测[键] <= 上, 说明))
    结果.append(("空格数", 待测["空格数"], 0, 0, 待测["空格数"] == 0, "12 格都要有人"))
    结果.append(("身高差", 待测["身高差"], 0, 4, 待测["身高差"] <= 4, "各格人物高度相差多少；大了就是大小忽高忽低"))
    结果.append(("底边差", 待测["底边差"], 0, 2, 待测["底边差"] <= 2, "各格脚底相差多少行；大了走起来会上下跳"))
    结果.append(("贴边格", len(待测["贴边格"]), 0, 0, not 待测["贴边格"], "人物碰到格子左右边"))
    结果.append(("半透明", 待测["半透明"], 0, 0, 待测["半透明"] == 0, "半透明像素个数；有就先做 alpha 二值化"))
    return 结果


def 命令_体检(参):
    基准们 = [量整张(p) for p in 参.基准]
    总失败 = 0
    for 路径 in 参.图:
        待测 = 量整张(路径)
        结果 = 体检(待测, 基准们)
        失败 = [r for r in 结果 if not r[4]]
        总失败 += len(失败)
        print(f"\n== {路径}：{'合格' if not 失败 else f'不合格（{len(失败)} 项）'}")
        for 键, 值, 下, 上, 过, 说明 in 结果:
            上文 = "∞" if 上 == float("inf") else f"{上:.2f}"
            print(f"  {'✓' if 过 else '✗'} {键:<8} {值:>8.2f}   基准 {下:.2f}～{上文}" + ("" if 过 else f"   ← {说明}"))
        if 待测["贴边格"]:
            print("    贴边的格：" + "、".join(待测["贴边格"]))
    if 参.json:
        Path(参.json).write_text(json.dumps([量整张(p) for p in 参.图], ensure_ascii=False, indent=1), "utf-8")
    return 1 if 总失败 else 0


# ---------- 换装 ----------

def 十六进制(文: str) -> np.ndarray:
    文 = 文.lstrip("#")
    return np.array([int(文[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def 色带取色(色带: list[str], t: np.ndarray) -> np.ndarray:
    """色带从暗到亮；t 在 0～1。相邻两色之间线性过渡，保住模板原有的明暗层次。"""
    色们 = np.array([十六进制(c) for c in 色带])
    if len(色们) == 1:
        return np.repeat(色们, len(t), axis=0)
    位 = np.clip(t, 0, 1) * (len(色们) - 1)
    低 = np.floor(位).astype(int).clip(0, len(色们) - 2)
    比 = (位 - 低)[:, None]
    return 色们[低] * (1 - 比) + 色们[低 + 1] * 比


def 模板脖子(实: np.ndarray, 档: dict, 行: int):
    """模板是固定的一张图，脖子位置直接写在模板档里（按方向，离脚底几行），不靠猜。"""
    行有 = np.where(实.any(1))[0]
    顶, 底 = int(行有.min()), int(行有.max())
    return 顶, 底 - 档["脖子距底"][行], 底


def 分区(格: np.ndarray, 档: dict, 行: int) -> np.ndarray:
    """把模板一格里的每个像素分到：发、眼、眼白、肤、上衣、下装、鞋、空。"""
    高, 宽 = 格.shape[:2]
    区 = np.full((高, 宽), "空", dtype=object)
    实 = 格[..., 3] >= 128
    if not 实.any():
        return 区
    顶, 脖, 底 = 模板脖子(实, 档, 行)
    身长 = 底 - 脖 + 1
    下装起 = 脖 + round(身长 * 档["上衣占身长"])
    鞋起 = 脖 + round(身长 * 档["鞋起于身长"])
    亮 = 亮度(格[..., :3])
    肤档, 眼档 = 档["肤"], 档["眼"]
    for y in range(高):
        for x in range(宽):
            if not 实[y, x]:
                continue
            r, g, b = (格[y, x, :3] / 255.0)
            h, s, _ = colorsys.rgb_to_hsv(r, g, b)
            h *= 360
            L = 亮[y, x]
            if 肤档["色相"][0] <= h <= 肤档["色相"][1] and s >= 肤档["最低饱和"] and L >= 肤档["最低亮度"]:
                区[y, x] = "肤"
            elif y < 脖 and 眼档["色相"][0] <= h <= 眼档["色相"][1] and s >= 眼档["最低饱和"] and L >= 眼档["最低亮度"]:
                区[y, x] = "眼"
            elif y < 脖:
                区[y, x] = "发"
            elif y < 下装起:
                区[y, x] = "上衣"
            elif y < 鞋起:
                区[y, x] = "下装"
            else:
                区[y, x] = "鞋"
    # 头部里夹在脸上的近黑点（下巴、脸颊轮廓、上眼线）跟着皮肤走，不跟头发走
    for y in range(1, 高 - 1):
        for x in range(1, 宽 - 1):
            if 区[y, x] == "发" and 亮[y, x] < 档["暗线亮度"]:
                邻 = [区[y - 1, x], 区[y + 1, x], 区[y, x - 1], 区[y, x + 1]]
                if 邻.count("肤") + 邻.count("眼") >= 1 and y >= 顶 + (脖 - 顶) * 档["脸起于头高"]:
                    区[y, x] = "肤线"
    # 眼白：紧挨眼睛、很亮、没什么颜色的点
    for y in range(高):
        for x in range(1, 宽 - 1):
            if 区[y, x] == "发" and 亮[y, x] >= 档["眼白最低亮度"] and ("眼" in (区[y, x - 1], 区[y, x + 1])):
                区[y, x] = "眼白"
    return 区


def 换一格(格: np.ndarray, 档: dict, 配方: dict, 行: int) -> np.ndarray:
    出 = 格.copy()
    实 = 格[..., 3] >= 128
    if not 实.any():
        return 出
    出[..., 3] = np.where(实, 255, 0)          # alpha 二值化
    出[~实, :3] = 0
    区 = 分区(格, 档, 行)
    边 = 外缘(实)
    亮 = 亮度(格[..., :3])
    换色 = 配方["换色"]
    for 名, 项 in 换色.items():
        罩 = 区 == 名
        if 名 == "肤":
            罩 = 罩 | (区 == "肤线")
        if not 罩.any():
            continue
        色带, 描边 = 项["色带"], 项.get("描边")
        # 用整张模板这一区的亮度范围定 t，各格一致（范围在配方里由 准备范围() 填好）
        暗, 明 = 项["_范围"]
        t = np.clip((亮[罩] - 暗) / max(明 - 暗, 1.0), 0, 1)
        均衡 = 项.get("均衡", 0.0)
        if 均衡:
            # 模板这一区大半是同一档亮度时（白发），按名次拉开，明暗层次才留得住
            名次 = np.searchsorted(项["_全"], 亮[罩]) / max(len(项["_全"]) - 1, 1)
            t = t * (1 - 均衡) + 名次 * 均衡
        新 = 色带取色(色带, t)
        出[罩, :3] = np.round(新).astype(np.int32)
        if 描边:
            # 外缘、或模板里本来就是暗线的点，用描边色
            线 = 罩 & (边 | (亮 <= 暗 + (明 - 暗) * 0.04))
            if 名 == "肤":
                线 = 线 | (区 == "肤线")
            if 项.get("内部暗线改阴影"):
                # 例：上衣改成赤膊时，衣服上的拉链、褶线不能留成黑线，只留外缘
                线 = 罩 & 边
            出[线, :3] = np.round(十六进制(描边)).astype(np.int32)
    # 腰带：上衣和下装交界往上几行
    腰带 = 配方.get("腰带")
    if 腰带:
        顶, 脖, 底 = 模板脖子(实, 档, 行)
        交界 = 脖 + round((底 - 脖 + 1) * 档["上衣占身长"])
        for y in range(交界 - 腰带["行数"], 交界):
            罩 = (区[y] == "上衣") | (区[y] == "下装")
            # 只画躯干，不画垂在两边的手臂：取这一行最中间那一段连续像素
            xs = np.where(罩)[0]
            if len(xs) == 0:
                continue
            中 = 格.shape[1] // 2
            段们, 起 = [], xs[0]
            for i in range(1, len(xs) + 1):
                if i == len(xs) or xs[i] != xs[i - 1] + 1:
                    段们.append((起, xs[i - 1]))
                    if i < len(xs):
                        起 = xs[i]
            a, b = min(段们, key=lambda 段: abs((段[0] + 段[1]) / 2 - 中))
            出[y, a:b + 1, :3] = np.round(十六进制(腰带["色"])).astype(np.int32)
            出[y, a, :3] = 出[y, b, :3] = np.round(十六进制(腰带.get("描边", 腰带["色"]))).astype(np.int32)
    # 眼下纹：每只眼睛正下方画短横线
    纹 = 配方.get("眼下纹")
    if 纹:
        眼 = 区 == "眼"
        色 = np.round(十六进制(纹["色"])).astype(np.int32)
        xs_all = np.where(眼.any(0))[0]
        if len(xs_all):
            组, 起 = [], xs_all[0]
            for i in range(1, len(xs_all) + 1):
                if i == len(xs_all) or xs_all[i] > xs_all[i - 1] + 2:
                    组.append((起, xs_all[i - 1]))
                    if i < len(xs_all):
                        起 = xs_all[i]
            for a, b in 组:
                ys = np.where(眼[:, a:b + 1].any(1))[0]
                for 行偏 in 纹["行偏"]:
                    y = int(ys.max()) + 行偏
                    for x in range(a, b + 1):
                        if 0 <= y < 格.shape[0] and 区[y, x] in ("肤",):
                            出[y, x, :3] = 色
    return 出


def 准备范围(图: np.ndarray, 档: dict, 配方: dict):
    """每一区在整张模板里的亮度范围（去掉两头 2%），保证 12 格用同一把尺。"""
    收 = {名: [] for 名 in 配方["换色"]}
    for 行, _, 格 in 切格(图):
        区 = 分区(格, 档, 行)
        亮 = 亮度(格[..., :3])
        for 名 in 收:
            罩 = 区 == 名
            if 罩.any():
                收[名].append(亮[罩])
    for 名, 段 in 收.items():
        if 段:
            全 = np.concatenate(段)
            配方["换色"][名]["_范围"] = (float(np.percentile(全, 2)), float(np.percentile(全, 98)))
            配方["换色"][名]["_全"] = np.sort(全)
        else:
            配方["换色"][名]["_范围"] = (0.0, 255.0)
            配方["换色"][名]["_全"] = np.array([0.0, 255.0])


def 叠图层(底: np.ndarray, 层路径: str) -> np.ndarray:
    层 = 读图(层路径)
    if 层.shape != 底.shape:
        raise SystemExit(f"图层 {层路径} 尺寸 {层.shape[1]}×{层.shape[0]} 和模板不一样")
    罩 = 层[..., 3] >= 128
    出 = 底.copy()
    出[罩] = 层[罩]
    出[罩, 3] = 255
    return 出


def 命令_换装(参):
    配方 = json.loads(Path(参.配方).read_text("utf-8"))
    档 = json.loads((Path(参.配方).parent / 配方["模板档"]).read_text("utf-8"))
    图 = 读图(参.模板)
    准备范围(图, 档, 配方)
    出 = 图.copy()
    格高, 格宽 = 图.shape[0] // 行数, 图.shape[1] // 列数
    for 行, 列, 格 in 切格(图):
        出[行 * 格高:(行 + 1) * 格高, 列 * 格宽:(列 + 1) * 格宽] = 换一格(格, 档, 配方, 行)
    for 层 in 参.图层 or []:
        出 = 叠图层(出, 层)
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(出.astype(np.uint8), "RGBA").save(参.输出)
    print(f"已生成 {参.输出}（模板 {参.模板}，配方 {参.配方}）")
    return 0


# ---------- 预览 ----------

def 命令_预览(参):
    倍 = 参.倍数
    图们 = [Image.open(p).convert("RGBA") for p in 参.图]
    名们 = 参.标题.split(",") if 参.标题 else [Path(p).stem for p in 参.图]
    间, 顶 = 24, 34
    宽 = sum(i.width * 倍 for i in 图们) + 间 * (len(图们) + 1)
    高 = max(i.height * 倍 for i in 图们) + 顶 + 间
    板 = Image.new("RGBA", (宽, 高), tuple(int(参.底色.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) + (255,))
    画 = ImageDraw.Draw(板)
    try:
        from PIL import ImageFont
        字 = ImageFont.truetype(参.字体, 18) if 参.字体 else ImageFont.load_default()
    except OSError:
        字 = None
    x = 间
    for 图, 名 in zip(图们, 名们):
        大 = 图.resize((图.width * 倍, 图.height * 倍), Image.NEAREST)
        板.alpha_composite(大, (x, 顶))
        画.text((x + 4, 8), 名, fill=(220, 225, 235, 255), font=字)
        x += 大.width + 间
    Path(参.输出).parent.mkdir(parents=True, exist_ok=True)
    板.save(参.输出)
    print(f"已生成 {参.输出}")
    return 0


def main(argv=None):
    解 = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    子 = 解.add_subparsers(dest="命令", required=True)
    a = 子.add_parser("体检", help="和基准图比，不合格退出码 1")
    a.add_argument("图", nargs="+")
    a.add_argument("--基准", nargs="+", required=True, help="一张或几张基准行走图（五条悟 v2、原版角色）")
    a.add_argument("--json", help="把量到的数写进这个文件")
    a.set_defaults(函=命令_体检)
    b = 子.add_parser("换装", help="模板＋配方 → 新行走图")
    b.add_argument("模板")
    b.add_argument("配方")
    b.add_argument("输出")
    b.add_argument("--图层", nargs="*", help="换色后再叠上去的透明图层（发型、饰物），尺寸同模板")
    b.set_defaults(函=命令_换装)
    c = 子.add_parser("预览", help="几张行走图并排放大")
    c.add_argument("图", nargs="+")
    c.add_argument("--输出", required=True)
    c.add_argument("--倍数", type=int, default=4)
    c.add_argument("--标题", help="逗号分隔，和图一一对应")
    c.add_argument("--底色", default="#1D2733")
    c.add_argument("--字体")
    c.set_defaults(函=命令_预览)
    参 = 解.parse_args(argv)
    return 参.函(参)


if __name__ == "__main__":
    sys.exit(main())
