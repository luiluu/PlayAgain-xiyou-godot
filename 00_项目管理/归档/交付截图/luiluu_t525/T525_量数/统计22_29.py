#!/usr/bin/env python3
"""T525 统计：现行 main（0826cb6fe，D273 开、balance_table.json 未改）22/29 层基线复测 vs T405 旧数。
口径（协调确认，沿用 T405/T402 同源 baseline_dps.gd --duel --events ＋ r6/t298 两链 × 4 普通队 × 3 种子 ＋ 奶妈队单列）：
- 剔除：三态判先剔除事件中止场（aborted == True）；
- 普通阵容＝team != '奶妈队'（两链合计 24 场），奶妈队单列（6 场）；
- 强队＝普通阵容每回合直伤（dmg）前四分之一（6 场）；
- 统计量：同时报告强队胜率、全部赢场回合中位数／均值、剔除 ≤3 回合秒杀场后的赢场回合中位数／均值、≤3 秒杀场数、普通队胜率、奶妈队胜率与逐种子分布；
- 目标回合带：寻常 6±2（4～8）、艰险 8±2（6～10）。
用法（仓库根）：python3 00_项目管理/归档/交付截图/luiluu_t525/T525_量数/统计22_29.py"""
import json
import statistics as st
from pathlib import Path

HERE = Path(__file__).resolve().parent
T405_DIR = HERE.parent.parent / "luiluu_t405" / "T405_量数"
TURNS = {"xunchang": 6, "jianxian": 8}
NAMES = {"xunchang": "寻常", "jianxian": "艰险"}
FAST = 3


def load(base_dir: Path, prefix: str, diff: str, floor: int) -> list:
    per = []
    for c in ("r6", "t298"):
        p = base_dir / f"{prefix}_{diff}_{c}.json"
        if not p.exists():
            continue
        for r in json.load(open(p))["rows"]:
            if int(r["floor"]) == floor:
                for x in r.get("per", []):
                    per.append(dict(x, chain=c))
    return per


def seed_of(p: dict) -> int:
    return int(p["rng"]) // 100000


def pct_direct(p: dict) -> float:
    return float(p["dmg"]) * int(p["turns"]) / max(1.0, float(p["enemyHp"])) * 100.0


def pct_end(p: dict) -> float:
    return float(p.get("endTurnDmg", 0.0)) * int(p["turns"]) / max(1.0, float(p["enemyHp"])) * 100.0


def summarize(per: list, diff: str) -> dict:
    aborted = [p for p in per if p.get("aborted")]
    valid = [p for p in per if not p.get("aborted")]
    nm = [p for p in valid if p.get("team") != "奶妈队"]
    hl = [p for p in valid if p.get("team") == "奶妈队"]
    top = sorted(nm, key=lambda p: -float(p.get("dmg", 0.0)))[: max(1, len(nm) // 4)]
    fast = [p for p in top if int(p["turns"]) <= FAST]
    wins_all = [p for p in top if p.get("won")]
    wins_ok = [p for p in top if p.get("won") and int(p["turns"]) > FAST]
    lo, hi = TURNS[diff] - 2, TURNS[diff] + 2
    med_all = st.median([p["turns"] for p in wins_all]) if wins_all else None
    avg_all = st.mean([p["turns"] for p in wins_all]) if wins_all else None
    med_ok = st.median([p["turns"] for p in wins_ok]) if wins_ok else None
    avg_ok = st.mean([p["turns"] for p in wins_ok]) if wins_ok else None
    dir_pct = st.mean([pct_direct(p) for p in wins_all]) if wins_all else None
    end_pct = st.mean([pct_end(p) for p in wins_all]) if wins_all else None
    if med_ok is None:
        band = "✗（全秒杀/无有效赢样）" if wins_all else "－"
    elif lo <= med_ok <= hi and lo <= avg_ok <= hi:
        band = "✓"
    else:
        band = "✗"
    return {
        "aborted": aborted,
        "nm": nm,
        "hl": hl,
        "top": top,
        "fast": fast,
        "wins_all": wins_all,
        "wins_ok": wins_ok,
        "med_all": med_all,
        "avg_all": avg_all,
        "med_ok": med_ok,
        "avg_ok": avg_ok,
        "dir_pct": dir_pct,
        "end_pct": end_pct,
        "band": band,
        "enemy_hp": per[0]["enemyHp"] if per else 0,
    }


def fmt(v, spec="%.1f"):
    return "－" if v is None else (spec % v)


def outcome_zh(p: dict) -> str:
    if p.get("aborted"):
        return "中止"
    if p.get("won"):
        return "赢"
    if p.get("lost"):
        return "输"
    return "超时"


def cell(p: dict) -> str:
    return "%s%d(直%.0f%%/末%.0f%%)" % (
        outcome_zh(p),
        int(p["turns"]),
        pct_direct(p),
        pct_end(p),
    )


def main() -> None:
    lines = []
    w = lines.append
    w("# T525 22、29 层现行基线复测 vs T405 旧数（D273 开态，3 种子）\n")
    w("- 对比基线：T405 旧数（`1ce9f1568`，T501 前 `K=0.13`／敌人血 `100%`） vs 现行 `main`（`0826cb6fe`，T501 R2 `K=0.5`／`enemy_hp_pct=40%`＋T445/T446/T451/T514/T515 合入后，`balance_table.json` 未改：`hp_base[22]=139万`、`hp_base[29]=321万`）。")
    w("- 全部场次 `aborted=0`（事件中止场 0 场，无剔除）；秒杀场定义为 `turns ≤ 3`。\n")
    w("## 一、总表（T405 旧数 vs 现行 main）\n")
    w("| 层 | 难度（目标） | 版本 | 实血 | 中止 | 强队胜 | 强队全赢中位/均值 | 强队>3中位/均值 | 秒杀场(≤3) | 带判 | 直伤/回合末占比 | 普通胜/场（r6｜t298） | 奶妈队 |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    now_details = []
    for fl in (22, 29):
        for diff in ("xunchang", "jianxian"):
            for label, bdir, pref in [
                ("T405旧数（T501前）", T405_DIR, "cap"),
                ("现行main（0826cb6fe）", HERE, "base"),
            ]:
                per = load(bdir, pref, diff, fl)
                s = summarize(per, diff)
                if pref == "base":
                    now_details.append((fl, diff, s))
                r6_nm = [p for p in s["nm"] if p["chain"] == "r6"]
                t2_nm = [p for p in s["nm"] if p["chain"] == "t298"]
                r6_w = sum(1 for p in r6_nm if p.get("won"))
                t2_w = sum(1 for p in t2_nm if p.get("won"))
                nw = sum(1 for p in s["nm"] if p.get("won"))
                hw = sum(1 for p in s["hl"] if p.get("won"))
                w(
                    "| %d | %s %d±2 | %s | %.0f | %d | %d/%d | %s / %s | %s / %s | %d | %s | %s / %s | %d/%d（%d/%d｜%d/%d） | %d/%d |"
                    % (
                        fl,
                        NAMES[diff],
                        TURNS[diff],
                        label,
                        s["enemy_hp"],
                        len(s["aborted"]),
                        len(s["wins_all"]),
                        len(s["top"]),
                        fmt(s["med_all"]),
                        fmt(s["avg_all"]),
                        fmt(s["med_ok"]),
                        fmt(s["avg_ok"]),
                        len(s["fast"]),
                        s["band"],
                        fmt(s["dir_pct"], "%.1f%%"),
                        fmt(s["end_pct"], "%.1f%%"),
                        nw,
                        len(s["nm"]),
                        r6_w,
                        len(r6_nm),
                        t2_w,
                        len(t2_nm),
                        hw,
                        len(s["hl"]),
                    )
                )
    w("\n## 二、现行 main 逐种子明细（强队＝两链合看 dmg 前四分之一；全部计入，aborted=0）\n")
    for fl, diff, s in now_details:
        w(f"### {fl} 层 · {NAMES[diff]}（目标 {TURNS[diff]}±2，实血 {s['enemy_hp']:.0f}）\n")
        w("| 种子 | 强队各场 | 强队胜 | 强队全赢中位/均值 | 剔除/说明 | 全部普通队各场（r6＋t298） |")
        w("|---|---|---|---|---|---|")
        for sd in sorted({seed_of(p) for p in s["nm"]}):
            tp = [p for p in s["top"] if seed_of(p) == sd]
            tw = [p for p in tp if p.get("won")]
            tf = [p for p in tp if int(p["turns"]) <= FAST]
            al = [p for p in s["nm"] if seed_of(p) == sd]
            note = "全部计入，其中秒杀(≤3) %d 场" % len(tf) if tf else "没剔除（aborted=0，秒杀 0）"
            med_s = fmt(st.median([p["turns"] for p in tw]) if tw else None)
            avg_s = fmt(st.mean([p["turns"] for p in tw]) if tw else None)
            w(
                "| %d | %s | %d/%d | %s / %s | %s | %s |"
                % (
                    sd,
                    "、".join("%s·%s %s" % (p["chain"], p["team"], cell(p)) for p in tp) or "无",
                    len(tw),
                    len(tp),
                    med_s,
                    avg_s,
                    note,
                    "、".join("%s·%s %s%d" % (p["chain"], p["team"], outcome_zh(p), int(p["turns"])) for p in al),
                )
            )
        w("")
    out = "\n".join(lines)
    (HERE / "统计22_29结果.md").write_text(out, encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
