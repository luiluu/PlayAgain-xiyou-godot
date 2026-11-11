#!/usr/bin/env python3
"""天启篇词条总表校验（只用标准库，云端没有 Godot 和转换产物也能跑）。

和 Godot 专项 tests/xiyou_tianqi_affix_table 验同一套内容。写成「每张表一个检查函数」：
另一条线（五档难度与档位数值表）同时建了 03_转换工具/天启篇数据校验.py（CHECKS 表），
合并后可以把本文件的 run() 登记进它的 CHECKS，见交付单 claude_project-thread-z0d29k.md。

用法：
  python3 03_再刷重制_Godot/03_转换工具/天启篇词条表校验.py
  python3 …/天启篇词条表校验.py --file affix_table=<另一份.json>    # 换一份文件校验（反向验证用）
退出码：0 全部通过；1 有检查失败；2 用法或文件错误。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "01_Godot工程"
DATA_DIR = ROOT / "modes/xiyou/tianqi_data"
TIANQI_GD = ROOT / "modes/xiyou/core/tianqi.gd"

GRADES = ("normal", "fine", "perfect")
EPS = 1e-9


class Report:
    def __init__(self, table: str):
        self.table = table
        self.results: list[tuple[str, bool, str]] = []
        self.warnings: list[str] = []

    def check(self, name: str, ok: bool, detail: object = "") -> None:
        self.results.append((name, bool(ok), "" if ok else str(detail)))

    def warn(self, text: str) -> None:
        self.warnings.append(text)


# ---------------------------------------------------------------- 词条总表

class AffixTable:
    """和 XTianqiAffixTable 同样的查表算法（改一边要改另一边）。"""

    def __init__(self, data: dict):
        self.d = data
        self.layers = {l["key"]: l for l in data["layers"]}
        self.affixes = {a["key"]: a for a in data["affixes"]}
        self.groups = {g["key"]: g for g in data["slot_groups"]}
        self.slots = {s["key"]: s for s in data["slots"]}
        self.qualities = {q["key"]: q for q in data["qualities"]}

    def tier_start(self, key: str) -> int:
        return int(self.layers[self.affixes[key]["layer"]]["tier_start"])

    def value(self, key: str, tier: int, grade: str):
        """不能出的阶返回 None。"""
        a = self.affixes.get(key)
        if a is None or grade not in GRADES or not 1 <= tier <= 4:
            return None
        start = self.tier_start(key)
        if tier < start:
            return None
        if a.get("fixed"):
            return a["values"][0]
        i = tier - start + GRADES.index(grade)
        vals = a["values"]
        return vals[i] if i < len(vals) else None

    def tier_of_level(self, level: int) -> int:
        for t in self.d["tiers"]:
            hi = t["max_level"]
            if level >= t["min_level"] and (hi is None or level <= hi):
                return int(t["tier"])
        return 1 if level < 1 else 4

    def slot_group(self, slot: str) -> str:
        return self.slots.get(slot, {}).get("group", "")

    def candidates(self, layer: str, group: str) -> list[str]:
        g = self.groups.get(group)
        if g is None or layer not in g["layers"]:
            return []
        if layer == "aura":
            return [a["key"] for a in self.d["affixes"] if a["layer"] == "aura"]
        return [a["key"] for a in self.d["affixes"] if a["layer"] == layer and a["tag"] in g["tags"]]

    def layer_odds(self, difficulty: str) -> dict:
        return self.d["layer_odds"].get(difficulty, {})

    def slot_count(self, quality: str) -> int:
        return int(self.qualities.get(quality, {}).get("slots", 0))


def _numbers(node, exempt: set, path: str = ""):
    """表里所有数（跳过豁免键），产出 (路径, 数)。"""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in exempt:
                continue
            yield from _numbers(v, exempt, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from _numbers(v, exempt, f"{path}[{i}]")
    elif isinstance(node, (int, float)) and not isinstance(node, bool):
        yield path, node


def num_text(x) -> str:
    """和 GDScript str(float) 一样去掉多余的 0：1.0→1，0.30→0.3。"""
    return f"{x:.6f}".rstrip("0").rstrip(".") if isinstance(x, float) else str(x)


def tianqi_difficulty_keys() -> list[str]:
    text = TIANQI_GD.read_text(encoding="utf-8")
    m = re.search(r"const DIFFICULTIES := \[(.*?)\n\]", text, re.S)
    return re.findall(r'"key":\s*"([a-z_]+)"', m.group(1)) if m else []


def check_affix_table(data: dict, r: Report) -> None:
    t = AffixTable(data)
    aff = data["affixes"]

    # 表头
    r.check("表头 source", data.get("source") == "天启篇词条重构设计稿 v0.3", data.get("source"))
    r.check("表头 dev 占位", "dev" in data, "缺 dev")

    # 1. 条数、键不重复
    expect = {"base": 12, "special": 18, "legendary": 12, "aura": 9}
    for layer, n in expect.items():
        got = sum(1 for a in aff if a["layer"] == layer)
        r.check(f"条数 {layer}={n}", got == n, got)
    keys = [a["key"] for a in aff]
    r.check("词条键不重复", len(keys) == len(set(keys)), [k for k in keys if keys.count(k) > 1])
    r.check("词条键小写下划线", all(re.fullmatch(r"[a-z][a-z0-9_]*", k) for k in keys), keys)
    names = [a["name"] for a in aff]
    r.check("词条名不重复", len(names) == len(set(names)), names)

    # 每条字段齐、引用的层／标签／叠法／位置都有定义
    tags = {x["key"] for x in data["tags"]}
    stacks = {x["key"] for x in data["stacking"]}
    pools = {x["key"] for x in data["pools"]}
    bad = [a["key"] for a in aff if a["layer"] not in t.layers or a["tag"] not in tags
           or a["stack"] not in stacks or a["pool"] not in pools
           or a["unit"] not in ("percent", "flat", "count") or a["weight"] <= 0]
    r.check("字段引用都有定义", not bad, bad)

    # 2. 一排数值严格递增、长度对层；连击固定 +1
    for a in aff:
        v = a["values"]
        if a.get("fixed"):
            r.check(f"{a['key']} 固定值", v == [1] and a["unit"] == "count", v)
            continue
        n = t.layers[a["layer"]]["row_len"]
        r.check(f"{a['key']} 长度 {n}", len(v) == n, len(v))
        r.check(f"{a['key']} 严格递增", all(x < y for x, y in zip(v, v[1:])), v)
    for layer, n in (("base", 6), ("special", 5), ("legendary", 4), ("aura", 5)):
        r.check(f"层 {layer} 一排 {n} 个", t.layers[layer]["row_len"] == n, t.layers[layer]["row_len"])
    for layer, s in (("base", 1), ("special", 2), ("legendary", 3), ("aura", 2)):
        r.check(f"层 {layer} 从 {s} 阶起", t.layers[layer]["tier_start"] == s, t.layers[layer]["tier_start"])
    combo = t.affixes.get("combo", {})
    r.check("连击：固定 +1、各阶各成色都是 1",
            all(t.value("combo", tr, g) == 1 for tr in (3, 4) for g in GRADES)
            and t.value("combo", 2, "perfect") is None and combo.get("trait_code") == 34, combo)

    # 3. 底线：一阶就能出的词条（基础层），一阶极 < 四阶普通（设计稿第 9 节末、第 11 节验收例 1）；
    #    特效、传说、光环一阶不出。另把「最低可出阶的极 对 四阶普通」逐层报出来（见交付单）。
    for a in aff:
        k = a["key"]
        start = t.tier_start(k)
        if start == 1:
            lo, hi = t.value(k, 1, "perfect"), t.value(k, 4, "normal")
            r.check(f"底线 {k}：一阶极 {lo} < 四阶普通 {hi}", lo < hi, (lo, hi))
        else:
            r.check(f"底线 {k}：一阶不出", t.value(k, 1, "normal") is None and t.value(k, 1, "perfect") is None, k)
    for layer in ("special", "aura", "legendary"):
        rel = set()
        for a in aff:
            if a["layer"] != layer or a.get("fixed"):
                continue
            lo, hi = t.value(a["key"], t.tier_start(a["key"]), "perfect"), t.value(a["key"], 4, "normal")
            rel.add("<" if lo < hi else "=" if lo == hi else ">")
        if rel != {"<"}:
            r.warn(f"{layer} 层：最低可出阶的极 对 四阶普通 是 {'/'.join(sorted(rel))}（不是严格低于，见交付单）")

    # 4. 相邻阶衔接
    broken = []
    for a in aff:
        k = a["key"]
        if a.get("fixed"):
            continue
        for tr in range(t.tier_start(k), 4):
            if t.value(k, tr, "perfect") != t.value(k, tr + 1, "fine") or t.value(k, tr, "fine") != t.value(k, tr + 1, "normal"):
                broken.append((k, tr))
    r.check("相邻阶：上阶极＝下阶上品、上阶上品＝下阶普通", not broken, broken)
    full = [a["key"] for a in aff if any(t.value(a["key"], tr, g) is None for tr in range(t.tier_start(a["key"]), 5) for g in GRADES)]
    r.check("可出阶的三种成色都有值", not full, full)

    # 5. 数值好看：不出现数字 4（豁免键里是个数、阶号）
    exempt = set(data.get("digit_check_exempt", []))
    fours = [(p, x) for p, x in _numbers(data, exempt) if "4" in num_text(x)]
    r.check("不出现数字 4", not fours, fours)
    for a in aff:
        sec = a.get("secondary")
        if sec:
            derived = sorted({num_text(x * sec["factor"]) for x in a["values"]})
            bad4 = [x for x in derived if "4" in x]
            if bad4:
                r.warn(f"{a['key']}（{a['name']}）派生值 ×{sec['factor']} 出现 {bad4}（见交付单）")

    # 6. 难度表
    diffs = tianqi_difficulty_keys()
    r.check("tianqi.gd 能取到五个难度键", len(diffs) == 5, diffs)
    r.check("难度键和 XTianqi.DIFFICULTIES 一致（含顺序）", list(data["layer_odds"].keys()) == diffs, (list(data["layer_odds"]), diffs))
    for k, row in data["layer_odds"].items():
        r.check(f"难度 {k} 三层", set(row) == {"base", "special", "legendary"}, row)
        r.check(f"难度 {k} 合计为 1", abs(sum(row.values()) - 1) < EPS, sum(row.values()))
    r.check("寻常传说为 0", t.layer_odds("xunchang").get("legendary") == 0, t.layer_odds("xunchang"))
    r.check("难度越高传说越多", all(data["layer_odds"][a]["legendary"] < data["layer_odds"][b]["legendary"]
                                    for a, b in zip(diffs[1:], diffs[2:])), data["layer_odds"])

    # 7. 栏位分组
    r.check("12 个栏位", len(data["slots"]) == 12 and len(t.slots) == 12, list(t.slots))
    r.check("栏位组都有定义", all(s["group"] in t.groups for s in data["slots"]), data["slots"])
    expect_groups = {"weapon": "bingqi", "offhand": "bingqi", "head": "fangju", "body": "fangju", "hands": "fangju",
                     "waist": "fangju", "legs": "fangju", "feet": "fangju", "necklace": "shipin", "ring": "shipin",
                     "artifact": "fabao", "mount": "zuoqi"}
    r.check("栏位分组对设计稿 3.5", {k: t.slot_group(k) for k in t.slots} == expect_groups, {k: t.slot_group(k) for k in t.slots})
    for group, ok_tags in (("bingqi", {"atk", "gen"}), ("fangju", {"def", "gen"}), ("shipin", {"atk", "def", "gen"})):
        for layer in ("base", "special", "legendary"):
            got = t.candidates(layer, group)
            want = [a["key"] for a in aff if a["layer"] == layer and a["tag"] in ok_tags]
            r.check(f"{group} {layer} 候选", got == want and all(t.affixes[k]["tag"] in ok_tags for k in got), got)
    r.check("兵器不出光环", t.candidates("aura", "bingqi") == [] and t.candidates("aura", "fangju") == [])
    r.check("坐骑候选为空", all(t.candidates(l, "zuoqi") == [] for l in t.layers))
    r.check("法宝只出光环", all(t.candidates(l, "fabao") == [] for l in ("base", "special", "legendary"))
            and len(t.candidates("aura", "fabao")) == 9)
    r.check("只有项链和法宝带光环", sorted(s["key"] for s in data["slots"] if s.get("aura")) == ["artifact", "necklace"])
    r.check("项链光环 15%、二阶起", data["necklace_aura"]["chance"] == 0.15 and data["necklace_aura"]["min_tier"] == 2)
    r.check("通用法宝 50% 带光环、三分之一／三分之二分阶",
            data["artifact_aura"]["chance"] == 0.5 and data["artifact_aura"]["kinds"] == ["general"]
            and [x["tier"] for x in data["artifact_aura"]["tier_by_growth"]] == [2, 3, 4], data["artifact_aura"])

    # 槽数、层门槛、成色
    r.check("各品质槽数 0/1/1/2/2/3/3", [t.slot_count(q) for q in ("putong", "youxiu", "jingliang", "shishi", "chuanshuo", "buxiu", "shenhua")]
            == [0, 1, 1, 2, 2, 3, 3])
    r.check("每件上限 特效 2、传说 1", t.layers["special"]["per_item_max"] == 2 and t.layers["legendary"]["per_item_max"] == 1)
    r.check("层门槛 特效史诗、传说不朽", t.layers["special"]["min_quality"] == "shishi" and t.layers["legendary"]["min_quality"] == "buxiu")
    r.check("极 3%", data["grade_odds"]["perfect"] == 0.03)
    fq = data["grade_odds"]["fine_by_quality"]
    r.check("上品 10/20/30%", [fq[q] for q in ("youxiu", "jingliang", "shishi", "chuanshuo", "buxiu", "shenhua")] == [0.1, 0.1, 0.2, 0.2, 0.3, 0.3], fq)
    r.check("四阶分界 1/30/60/70", [t.tier_of_level(x) for x in (1, 29, 30, 59, 60, 69, 70, 99)] == [1, 1, 2, 2, 3, 3, 4, 4])
    expect_tags = {
        "atk": ["atk", "mat", "hit", "cri", "crit_damage", "final_damage", "skill_damage", "element_damage", "lifesteal",
                "first_strike", "last_stand", "headhunter", "expose", "suppress", "combo"],
        "def": ["mhp", "def", "mdf", "eva", "hrg", "damage_reduction", "element_resist", "state_resist", "heal_received",
                "opening_shield", "target_rate", "bulwark", "unyielding", "tenacity"],
    }
    got_tags = {tg: [a["key"] for a in aff if a["tag"] == tg and a["layer"] != "aura"] for tg in ("atk", "def")}
    r.check("攻、守标签对设计稿第 4～6 节", got_tags == expect_tags, got_tags)
    r.check("稀有词条：连击、再动，权重 0.3",
            sorted(a["key"] for a in aff if a.get("rare")) == ["combo", "reaction"]
            and all(a["weight"] == (0.3 if a.get("rare") else 1) for a in aff))

    # 8. 抽查对设计稿
    def row(k, tr=4):
        return [t.value(k, tr, g) for g in GRADES]
    r.check("物攻四阶 5/6/8", row("atk") == [5, 6, 8], row("atk"))
    r.check("物攻一阶 1/2/3", row("atk", 1) == [1, 2, 3], row("atk", 1))
    r.check("终伤四阶 9/12/15", row("final_damage") == [9, 12, 15], row("final_damage"))
    r.check("再动四阶 10/15/20、三阶 5/10/15", row("reaction") == [10, 15, 20] and row("reaction", 3) == [5, 10, 15])
    r.check("全能光环四阶 1.5/2/3", row("aura_versatile") == [1.5, 2, 3], row("aura_versatile"))
    r.check("技能消耗全身上限 −50%", t.affixes["skill_cost"].get("cap_total") == 50 and t.affixes["skill_cost"].get("direction") == "down")
    r.check("吸血单次不超过最大生命 10%", t.affixes["lifesteal"].get("cap_per_hit_mhp") == 10)
    r.check("再动、再释放不连锁", t.affixes["reaction"].get("no_chain") and t.affixes["recast"].get("no_chain"))
    r.check("元素类九系随机一系", len(data["elements"]) == 9 and t.affixes["element_damage"].get("random_element") and t.affixes["element_resist"].get("random_element"))
    r.check("引敌／避敌两种随机一种", [v["key"] for v in t.affixes["target_rate"].get("variants", [])] == ["draw", "avoid"])
    r.check("不能出的阶返回空", t.value("first_strike", 2, "perfect") is None and t.value("final_damage", 1, "normal") is None
            and t.value("nope", 4, "normal") is None and t.value("atk", 4, "bad") is None)


TABLES = [
    ("affix_table", DATA_DIR / "affix_table.json", check_affix_table),
]


def run(path: Path | None = None) -> bool:
    """给 天启篇数据校验.py 的 CHECKS 用：校验词条总表，打印结果，全过返回 True。"""
    return main([] if path is None else ["--file", f"affix_table={path}"]) == 0


def main(argv: list[str]) -> int:
    files = {name: path for name, path, _ in TABLES}
    picked = []
    args = list(argv)
    while args:
        a = args.pop(0)
        if a == "--file" and args:
            name, _, p = args.pop(0).partition("=")
            if name not in files or not p:
                print(f"--file 要写成 表名=路径，表名是 {list(files)}", file=sys.stderr)
                return 2
            files[name] = Path(p)
        elif a in files:
            picked.append(a)
        else:
            print(__doc__, file=sys.stderr)
            return 2
    failed = total = 0
    for name, _, fn in TABLES:
        if picked and name not in picked:
            continue
        r = Report(name)
        try:
            data = json.loads(files[name].read_text(encoding="utf-8"))
            fn(data, r)
        except Exception as e:  # 缺键、格式坏也算失败
            r.check("能读表并跑完全部检查", False, f"{type(e).__name__}: {e}")
        bad = [x for x in r.results if not x[1]]
        failed += len(bad)
        total += len(r.results)
        print(f"[{name}] {len(r.results) - len(bad)}/{len(r.results)} 通过　{files[name]}")
        for n, _, d in bad:
            print(f"  ✗ {n}：{d}")
        for w in r.warnings:
            print(f"  注意：{w}")
    print(f"天启篇词条表校验：{total - failed}/{total} 通过")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
