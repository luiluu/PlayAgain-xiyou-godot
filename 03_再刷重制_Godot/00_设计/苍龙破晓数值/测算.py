#!/usr/bin/env python3
"""苍龙破晓（角色 146）五回合木桩测算：算出与南宫恨·狂刀（角色 122）的比值。

不读、不改任何游戏数据。用法：

    python3 测算.py              # 按「最终参数」出表，并检查各项约束
    python3 测算.py --search     # 在不含 4 的整数候选里找比值最接近 0.8 的几组
    python3 测算.py --all-scaled # 对照方案：逐道也吃真龙之力
    python3 测算.py --mastery 50 # 换熟练等级看出招顺序是否还成立

口径（与草案 v0.1 实测一致）：冻结 v0.62.12，原版无画面引擎 sim/dmg5.cjs，
70 级、熟练 32、法宝 888、全暴击、保留强者压制、单体木桩、每回合回满 TP。
狂刀五回合木桩 = 1066.63 万亿，记作 10 份（1 份 = 106.663 万亿）。

模型：同一角色同一等级下，每招伤害与公式里的倍率成正比（倍率只是乘在最外层），
所以用草案 v0.1 在原版引擎上量到的「某倍率下每次几份」做锚点，按倍率换算；
真龙之力 (1 + 等级² × 2%) 是乘在伤害上的独立乘区。
锚点里玉玺禁章、血浪两招是草案按公式推算的（原版挂机五回合没出过这两招），其余三招是实测。
实现后要在原版引擎上用最终倍率重跑 dmg5.cjs 复核，见同目录 数值表.md「复核」。
"""
from __future__ import annotations

import argparse
import itertools

KUANGDAO_WANYI = 1066.63          # 狂刀五回合木桩，万亿
UNIT_WANYI = KUANGDAO_WANYI / 10  # 1 份
TARGET = 0.8
BENCH_LEVEL = 70
BENCH_MASTERY = 32
MAX_LEVEL = 99                    # 146 的 maxLevel
TURNS = 5

# 技能：键、名字、习得等级、段数、冷却、是否吃熟练、
#       锚点倍率（草案 v0.1）、锚点每次份数（70 级、熟练 32、无真龙之力）、锚点来源
SKILLS = [
    ("yuxi",   "玉玺禁章",          10, 2, 0, True,  500_000,    0.46, "推算"),
    ("xuelang", "天子御龙篇·血浪",  20, 3, 0, True,  500_000,    0.73, "推算"),
    ("feixiao", "天子御龙篇·飞霄",  30, 4, 0, True, 333_333, 1.00, "实测"),
    ("zhumie", "雷霆天罚·诛灭",     50, 1, 3, False, 10_000_000, 2.04, "实测"),
    ("zhudao", "苍龙御宇【逐道】",  60, 4, 3, False, 80_000,  1.46, "实测"),
]
FORMULA = {
    "yuxi":    "(物攻＋魔攻) × (1＋熟练) × {c}",
    "xuelang": "(物攻＋魔攻) × (1＋熟练) × {c}",
    "feixiao": "(物攻＋魔攻＋幸运) × (1＋熟练) × {c}",
    "zhumie":  "八项属性之和 × {c}",
    "zhudao":  "(物攻＋魔攻＋幸运) × 当前 TP × {c}",
}

# 最终参数（本分支定稿）：每段倍率。
FINAL = {"yuxi": 5_000, "xuelang": 5_000, "feixiao": 2_600, "zhumie": 57_000, "zhudao": 135_000}
# 对照方案：逐道也吃真龙之力时的一组（--all-scaled）。
FINAL_ALL_SCALED = {"yuxi": 5_000, "xuelang": 5_000, "feixiao": 3_500, "zhumie": 56_000, "zhudao": 1_300}


def zhenlong(level: int) -> float:
    """真龙之力：× (1 + 等级² × 2%)，不封顶。"""
    return 1 + level * level * 0.02


def per_cast(key: str, coef: float, level: int, mastery: int, scaled: set[str]) -> float:
    """每次出招的伤害（份；狂刀五回合 = 10）。属性按 70 级口径，只换真龙之力与熟练。"""
    s = next(x for x in SKILLS if x[0] == key)
    _, _, _, _, _, uses_mastery, ref_coef, ref_units, _ = s
    v = ref_units * coef / ref_coef
    if uses_mastery:
        v *= (1 + mastery) / (1 + BENCH_MASTERY)
    if key in scaled:
        v *= zhenlong(level)
    return v


def rotation(coefs: dict, level: int, mastery: int, scaled: set[str]):
    """五回合：每回合在已学会、不在冷却的招里挑单次伤害最高的（原版智能挂机的选法）。"""
    ready = {k: 1 for k in coefs}
    plan = []
    for t in range(1, TURNS + 1):
        usable = [s for s in SKILLS if s[2] <= level and ready[s[0]] <= t]
        best = max(usable, key=lambda s: per_cast(s[0], coefs[s[0]], level, mastery, scaled))
        dmg = per_cast(best[0], coefs[best[0]], level, mastery, scaled)
        plan.append((t, best[1], dmg))
        if best[4]:
            ready[best[0]] = t + best[4]
    total = sum(d for _, _, d in plan)
    return plan, total, total / 10


def ordering_violations(coefs: dict, mastery: int, scaled: set[str]):
    """低等级习得的招，单次伤害不得高于高等级习得的招（在两招都学会的每个等级上查）。"""
    bad = []
    for level in range(10, MAX_LEVEL + 1):
        learned = [s for s in SKILLS if s[2] <= level]
        vals = [per_cast(s[0], coefs[s[0]], level, mastery, scaled) for s in learned]
        for i in range(len(learned) - 1):
            if vals[i] > vals[i + 1] + 1e-12:
                bad.append((level, learned[i][1], learned[i + 1][1], vals[i], vals[i + 1]))
    return bad


def margin_at_cap(coefs: dict, mastery: int, scaled: set[str]) -> float:
    """99 级时诛灭与逐道的差距（逐道 ÷ 诛灭），> 1 才算守住顺序。"""
    z = per_cast("zhumie", coefs["zhumie"], MAX_LEVEL, mastery, scaled)
    d = per_cast("zhudao", coefs["zhudao"], MAX_LEVEL, mastery, scaled)
    return d / z


def no_four(n: int) -> bool:
    return "4" not in str(n)


def nice(lo: int, hi: int, step: int):
    return [n for n in range(lo, hi + 1, step) if no_four(n)]


def search(scaled: set[str], mastery: int, top: int = 8):
    zhumie = nice(30_000, 90_000, 1_000)
    zhudao = nice(80_000, 200_000, 5_000) if "zhudao" not in scaled else nice(500, 3_000, 100)
    feixiao = nice(2_000, 3_900, 100)
    yuxi = [5_000]
    found = []
    for cz, cd, cf, cy in itertools.product(zhumie, zhudao, feixiao, yuxi):
        coefs = {"yuxi": cy, "xuelang": cy, "feixiao": cf, "zhumie": cz, "zhudao": cd}
        if ordering_violations(coefs, mastery, scaled):
            continue
        _, _, ratio = rotation(coefs, BENCH_LEVEL, mastery, scaled)
        m = margin_at_cap(coefs, mastery, scaled)
        if m < 1.02:  # 99 级时逐道至少比诛灭高 2%，留点余量
            continue
        found.append((abs(ratio - TARGET), ratio, m, coefs))
    found.sort(key=lambda x: (x[0], x[2]))
    return found[:top]


def fmt(n: float, nd: int = 2) -> str:
    return f"{n:,.{nd}f}"


def report(coefs: dict, mastery: int, scaled: set[str], title: str):
    print(f"## {title}\n")
    print(f"口径：{BENCH_LEVEL} 级、熟练 {mastery}；1 份 = {fmt(UNIT_WANYI, 3)} 万亿（狂刀五回合 = 10 份）。")
    print(f"真龙之力作用于：{'、'.join(s[1] for s in SKILLS if s[0] in scaled)}；"
          f"{BENCH_LEVEL} 级 × {zhenlong(BENCH_LEVEL):g}\n")
    print("| 技能 | 习得 | 每段公式 | 段数 | 冷却 | 每次（份） | 每次（万亿） | 锚点 |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for s in SKILLS:
        k = s[0]
        v = per_cast(k, coefs[k], BENCH_LEVEL, mastery, scaled)
        f = FORMULA[k].format(c=f"{coefs[k]:,}") + (" × 真龙之力" if k in scaled else "")
        print(f"| {s[1]} | {s[2]} 级 | {f} | {s[3]} | {s[4] or '无'} | {fmt(v, 3)} | {fmt(v * UNIT_WANYI)} | {s[8]} |")
    plan, total, ratio = rotation(coefs, BENCH_LEVEL, mastery, scaled)
    print("\n五回合出招（每回合挑可用的单次最高）：\n")
    print("| 回合 | 出招 | 份 | 万亿 |")
    print("| --- | --- | --- | --- |")
    for t, name, d in plan:
        print(f"| {t} | {name} | {fmt(d, 3)} | {fmt(d * UNIT_WANYI)} |")
    print(f"| 合计 | | {fmt(total, 3)} | {fmt(total * UNIT_WANYI)} |")
    print(f"\n**与狂刀之比：{ratio:.3f}**（目标 {TARGET}）\n")

    bad = ordering_violations(coefs, mastery, scaled)
    print(f"低等级招单次不高于高等级招（10～{MAX_LEVEL} 级逐级查）："
          + ("全部成立" if not bad else f"{len(bad)} 处不成立，首处 {bad[0][0]} 级 {bad[0][1]} > {bad[0][2]}"))
    print(f"{MAX_LEVEL} 级时逐道 ÷ 诛灭 = {margin_at_cap(coefs, mastery, scaled):.3f}\n")

    print("各等级（属性按两人同比成长粗估；只有真龙之力改变两人的相对强弱）：\n")
    print("| 等级 | 真龙之力 | 已学会 | 五回合（份） | 约合狂刀 |")
    print("| --- | --- | --- | --- | --- |")
    for level in (10, 20, 30, 50, 60, 70, 81, 90, 99):
        # 粗估：只计真龙之力随等级的变化，属性成长当作与狂刀同比（约掉）
        _, total_l, _ = rotation(coefs, level, mastery, scaled)
        learned = sum(1 for s in SKILLS if s[2] <= level)
        print(f"| {level} | × {zhenlong(level):g} | {learned} 招 | {fmt(total_l, 2)} | {total_l / 10:.2f} |")
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--search", action="store_true", help="搜索比值接近 0.8 的不含 4 的倍率组合")
    ap.add_argument("--all-scaled", action="store_true", help="对照方案：逐道也吃真龙之力")
    ap.add_argument("--mastery", type=int, default=BENCH_MASTERY, help="熟练等级（默认 32）")
    args = ap.parse_args()

    scaled = {"yuxi", "xuelang", "feixiao", "zhumie"}
    coefs = FINAL
    title = "最终参数（逐道不吃真龙之力）"
    if args.all_scaled:
        scaled = scaled | {"zhudao"}
        coefs = FINAL_ALL_SCALED
        title = "对照方案（五招都吃真龙之力）"

    if args.search:
        print(f"## 搜索：{title}，熟练 {args.mastery}\n")
        print("| 比值 | 99 级逐道÷诛灭 | 玉玺/血浪 | 飞霄 | 诛灭 | 逐道 |")
        print("| --- | --- | --- | --- | --- | --- |")
        for _, ratio, m, c in search(scaled, args.mastery):
            print(f"| {ratio:.4f} | {m:.3f} | {c['yuxi']:,} | {c['feixiao']:,} | {c['zhumie']:,} | {c['zhudao']:,} |")
        return

    for k, v in coefs.items():
        assert no_four(v), f"{k} 的倍率 {v} 含 4"
    report(coefs, args.mastery, scaled, title)


if __name__ == "__main__":
    main()
