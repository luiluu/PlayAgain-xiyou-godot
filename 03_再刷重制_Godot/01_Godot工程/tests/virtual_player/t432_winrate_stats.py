#!/usr/bin/env python3
"""T432 普通阵容胜率汇总脚本（T406／D259 同口径）。

用法：
  python3 t432_winrate_stats.py [--out-md <md>] [--out-json <json>] \
      --f33 标签=json路径[,json路径...] ... \
      --f1030 标签=json路径[,json路径...] ...

口径（同 T406 汇总.py／D259）：
- 秒杀＝输且 turns <= 3，单列并在分母中剔除（有秒杀时标「w/k（秒q）」）。
- 逐种子按 `rng` 的高位（int(rng) // 100000，对应 --rng-seeds=1,2,3）分组。
- 同时统计含秒杀的原始胜率与前两回合内倒下人数（如有 trace）。
"""
import argparse
import collections
import json
from pathlib import Path


def load_merged_rows(paths_str: str):
    by_floor = {}
    for raw in paths_str.split(","):
        raw = raw.strip()
        if not raw:
            continue
        d = json.loads(Path(raw).read_text(encoding="utf-8"))
        for r in d.get("rows", []):
            fl = int(r["floor"])
            by_floor[fl] = r
    return [by_floor[k] for k in sorted(by_floor.keys())]


def seed_of(p: dict) -> int:
    rng = int(p.get("rng", 0))
    return rng // 100000 if rng >= 100000 else rng


def deaths_from_trace(p: dict):
    tr = p.get("trace") or []
    prev = None
    ds = []
    for step in tr:
        t, u, sk, _tg, _eh, ah = step
        if prev is not None:
            for a, b in zip(prev, ah):
                if a > 0 and b <= 0:
                    ds.append((t, sk if str(u).startswith("enemy") else "self"))
        prev = ah
    return ds


def summarize_rows(rows: list, seeds=(1, 2, 3)):
    per_all = []
    for r in rows:
        fl = int(r["floor"])
        for p in r.get("per", []):
            q = dict(p)
            q["_floor"] = fl
            per_all.append(q)

    by_seed = {}
    tot_w = tot_k = tot_q = tot_all = 0
    early_deaths = 0
    early_n = 0
    losses = []

    for s in seeds:
        arr = [p for p in per_all if seed_of(p) == s]
        quick = [p for p in arr if (not p.get("won")) and int(p.get("turns", 0)) <= 3]
        kept = [p for p in arr if p not in quick]
        w = sum(1 for p in kept if p.get("won"))
        by_seed[s] = {
            "won": w,
            "kept": len(kept),
            "quick": len(quick),
            "total": len(arr),
            "rate": round(100.0 * w / len(kept), 1) if kept else 0.0,
            "raw_rate": round(100.0 * w / len(arr), 1) if arr else 0.0,
        }
        tot_w += w
        tot_k += len(kept)
        tot_q += len(quick)
        tot_all += len(arr)
        for p in arr:
            if p.get("trace"):
                ds = deaths_from_trace(p)
                early_deaths += sum(1 for t, _ in ds if t <= 1)
                early_n += 1
            if not p.get("won"):
                alien = p.get("alien") or []
                al_s = alien[0] if alien else "无"
                tag = "秒" if int(p.get("turns", 0)) <= 3 else ("超时" if int(p.get("turns", 0)) >= 40 else "")
                losses.append(f"F{p['_floor']}:s{s}:{p.get('team', '')}({al_s},{p.get('turns')}T{tag})")

    # 逐层汇总
    by_floor = {}
    for r in rows:
        fl = int(r["floor"])
        arr = r.get("per", [])
        quick = [p for p in arr if (not p.get("won")) and int(p.get("turns", 0)) <= 3]
        kept = [p for p in arr if p not in quick]
        w = sum(1 for p in kept if p.get("won"))
        by_floor[fl] = {
            "won": w,
            "kept": len(kept),
            "quick": len(quick),
            "total": len(arr),
            "rate": round(100.0 * w / len(kept), 1) if kept else 0.0,
        }

    return {
        "floors": [int(r["floor"]) for r in rows],
        "by_seed": by_seed,
        "by_floor": by_floor,
        "won": tot_w,
        "kept": tot_k,
        "quick": tot_q,
        "total": tot_all,
        "rate": round(100.0 * tot_w / tot_k, 1) if tot_k else 0.0,
        "raw_rate": round(100.0 * tot_w / tot_all, 1) if tot_all else 0.0,
        "early_deaths": early_deaths,
        "early_n": early_n,
        "losses": losses,
        "per": per_all,
    }


def fmt_cell(st: dict) -> str:
    s = f"{st['won']}/{st['kept']}"
    if st["quick"] > 0:
        s += f"（秒{st['quick']}）"
    return s


def render_md(f33_data: dict, f1030_data: dict) -> str:
    lines = ["# T432 普通阵容胜率汇总（T406／D259 同口径）", ""]
    lines.append("口径：`baseline_dps.gd --duel --events --turns=40 --lineups=4 --rng-seeds=1,2,3`；秒杀（≤3 回合败）单列并剔出主胜率分母，同时括号列原始胜/总场。")
    lines.append("")

    # 一、33 层 vs 10~30 层总表
    lines.append("## 一、33 层普通阵容胜率（逐链逐种子）与 10～30 层对照")
    lines.append("")
    lines.append("| 链 | 33层 s1 | 33层 s2 | 33层 s3 | 33层 合计 | 10~30层 s1 | 10~30层 s2 | 10~30层 s3 | 10~30层 合计 | 差值（33层 - 10~30层） |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")

    all_labels = list(dict.fromkeys(list(f33_data.keys()) + list(f1030_data.keys())))
    for lab in all_labels:
        a = f33_data.get(lab)
        b = f1030_data.get(lab)
        if a:
            c33 = [fmt_cell(a["by_seed"][s]) for s in (1, 2, 3)]
            t33 = f"{fmt_cell(a)} {a['rate']:.1f}%"
        else:
            c33 = ["-", "-", "-"]
            t33 = "-"
        if b:
            c10 = [fmt_cell(b["by_seed"][s]) for s in (1, 2, 3)]
            t10 = f"{fmt_cell(b)} {b['rate']:.1f}%"
        else:
            c10 = ["-", "-", "-"]
            t10 = "-"
        diff = f"{a['rate'] - b['rate']:+.1f} pp" if (a and b) else "-"
        lines.append(f"| {lab} | {' | '.join(c33)} | {t33} | {' | '.join(c10)} | {t10} | {diff} |")

    # 二、33 层逐队明细
    if f33_data:
        lines.append("")
        lines.append("## 二、33 层逐链逐队明细")
        lines.append("")
        lines.append("| 链 | 队 | 成员 ID | s1 | s2 | s3 |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for lab, a in f33_data.items():
            teams_order = []
            by_team = collections.defaultdict(dict)
            team_ids = {}
            for p in a["per"]:
                tname = p.get("team", "原队")
                if tname not in teams_order:
                    teams_order.append(tname)
                team_ids[tname] = p.get("members", p.get("party", []))
                by_team[tname][seed_of(p)] = p
            for tn in teams_order:
                cells = []
                for s in (1, 2, 3):
                    p = by_team[tn].get(s)
                    if not p:
                        cells.append("-")
                    else:
                        res = "赢" if p.get("won") else "输"
                        al = (p.get("alien") or [""])[0]
                        al_short = al.split(":")[-1] if al else "无"
                        cells.append(f"{res}{p.get('turns')}T({al_short})")
                lines.append(f"| {lab} | {tn} | {team_ids[tn]} | {' | '.join(cells)} |")

    # 三、10~30 层逐层明细
    if f1030_data:
        lines.append("")
        lines.append("## 三、10～30 层逐层胜率明细（胜/有效场）")
        lines.append("")
        fl_set = sorted({fl for b in f1030_data.values() for fl in b["floors"]})
        labs = list(f1030_data.keys())
        lines.append("| 层 | " + " | ".join(labs) + " |")
        lines.append("| --- | " + " | ".join(["---"] * len(labs)) + " |")
        for fl in fl_set:
            row_cells = []
            for lab in labs:
                st = f1030_data[lab]["by_floor"].get(fl)
                row_cells.append(fmt_cell(st) if st else "-")
            lines.append(f"| {fl} | " + " | ".join(row_cells) + " |")

    return "\n".join(lines) + "\n"


def parse_kv(items):
    out = {}
    for item in items or []:
        lab, paths = item.split("=", 1)
        out[lab] = summarize_rows(load_merged_rows(paths))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--f33", action="append", default=[])
    ap.add_argument("--f1030", action="append", default=[])
    ap.add_argument("--out-md", default="")
    ap.add_argument("--out-json", default="")
    args = ap.parse_args()

    f33 = parse_kv(args.f33)
    f1030 = parse_kv(args.f1030)
    md = render_md(f33, f1030)
    if args.out_md:
        Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out_md).write_text(md, encoding="utf-8")
    else:
        print(md)
    if args.out_json:
        Path(args.out_json).parent.mkdir(parents=True, exist_ok=True)
        # 去掉原始 per 以保持 json 简洁
        clean = {
            "f33": {k: {kk: vv for kk, vv in v.items() if kk != "per"} for k, v in f33.items()},
            "f1030": {k: {kk: vv for kk, vv in v.items() if kk != "per"} for k, v in f1030.items()},
        }
        Path(args.out_json).write_text(json.dumps(clean, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
