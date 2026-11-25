#!/usr/bin/env python3
"""T481 元素效果 C 卡：把 vp_elem_c.gd 的 JSON 结果整理成报告用的表（markdown 到标准输出）。
用法：vp_elem_c_report.py solo <solo_0.json> ... | team <team.json> | floor <floor.json> | mix <mix.json> | holy <holy.json> | dark <dark.json>
"""
import json
import statistics as st
import sys

NAME = {2: "火焰", 3: "寒冰", 4: "大地", 5: "雷电", 6: "自然", 7: "奥术", 8: "神圣", 9: "黑暗", 14: "水", 15: "风"}


def load(paths):
    rows = []
    for p in paths:
        rows += json.load(open(p))["rows"]
    return rows


def pair(runs):
    """按种子配对：{seed: (off, on)}"""
    d = {}
    for r in runs:
        d.setdefault(r["seed"], {})[r["on"]] = r
    return d


def gain(runs, key=lambda r: r["out"] + r["dot"]):
    """各种子的单场收益（开/关−1）和合计收益"""
    per = []
    to = tf = 0.0
    for sd, d in sorted(pair(runs).items()):
        off, on = key(d[False]), key(d[True])
        per.append((on / off - 1.0) if off > 0 else 0.0)
        to += on
        tf += off
    return per, (to / tf - 1.0) if tf > 0 else 0.0


def solo(paths):
    rows = load(paths)
    out = ["## 场景 1：单人（逐角色）", ""]
    by_el = {}
    big = []
    zero_bad = []
    allg = []
    bad = [r for r in rows if any(x["turns"] == 0 for x in r["runs"])]
    over = [r for r in rows if r not in bad and any(x.get("rev_e", 0) > 0 for x in r["runs"])]
    rows = [r for r in rows if r not in bad]
    out.append(f"- 夹具量不了而剔除：{len(bad)} 条（我方一个动作内被夹具打倒、没出过手）：" + "、".join(f"{r['id']}{r['name']}({r['build']})" for r in bad))
    out.append(f"- 其中 过杀（一个动作打死夹具、复活补满继续，增益偏低）{len(over)} 条仍计入：" + "、".join(f"{r['id']}{r['name']}" for r in over))
    out.append("")
    for r in rows:
        per, tot = gain(r["runs"])
        on_stats = {}
        for x in r["runs"]:
            if x["on"]:
                for k, v in x["stats"].items():
                    for kk, vv in v.items():
                        on_stats.setdefault(k, {}).setdefault(kk, 0)
                        on_stats[k][kk] += vv
        trig = sum(v.get("eligible", 0) for k, v in on_stats.items() if int(k) != 8)   # 神圣己方入口（白名单技能）不看伤害元素，原生无属性的人也会掷
        if r["build"] == "native" and not r["native"] and trig > 0:
            zero_bad.append(r["id"])
        el = r["elem"] if r["build"] == "book" else (max(on_stats, key=lambda k: on_stats[k].get("eligible", 0)) if on_stats else None)
        el = int(el) if el is not None else None
        r["_g"] = tot
        r["_per"] = per
        r["_el"] = el
        r["_stats"] = on_stats
        allg.append(tot)
        if el is not None:
            by_el.setdefault(el, []).append(r)
        if tot > 0.06:
            big.append(r)
    out.append(f"- 角色×构筑 {len(rows)} 条；零触发回归（原生无属性那套）：{'全零 ✓' if not zero_bad else '有触发 ✗ ' + str(zero_bad)}")
    out.append(f"- 单人出伤增益（出伤＋回合末持续伤害，5 种子合计）：中位 {st.median(allg)*100:.2f}%，均值 {st.mean(allg)*100:.2f}%，最大 {max(allg)*100:.2f}%")
    out.append(f"- 超 6%：{len(big)} 条；超 8%：{len([r for r in rows if r['_g'] > 0.08])} 条")
    out.append("")
    out.append("| 系 | 构筑数 | 平均增益 | 中位 | 最大 | 最小 | 有资格 | 被免疫 | 掷点 | 挂上 | 实挂/掷 |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|")
    means = {}
    for el in sorted(by_el):
        L = by_el[el]
        gs = [r["_g"] for r in L]
        tot = {}
        for r in L:
            for k, v in r["_stats"].items():
                if int(k) == el:
                    for kk, vv in v.items():
                        tot[kk] = tot.get(kk, 0) + vv
        means[el] = st.mean(gs)
        out.append(f"| {NAME.get(el, el)} | {len(L)} | {st.mean(gs)*100:.2f}% | {st.median(gs)*100:.2f}% | {max(gs)*100:.2f}% | {min(gs)*100:.2f}% | "
                   f"{tot.get('eligible',0)} | {tot.get('immune',0)} | {tot.get('rolled',0)} | {tot.get('applied',0)} | {tot.get('applied',0)/max(1,tot.get('rolled',0))*100:.1f}% |")
    if means:
        hi, lo = max(means.values()), min(means.values())
        out.append("")
        out.append(f"- 场景 2 十系平均增益最高 {hi*100:.2f}% 最低 {lo*100:.2f}% 差 {(hi-lo)*100:.2f} 个百分点（判线 ≤3）")
    out.append("")
    out.append("**逐种子（各系平均，单位 %；五个种子逐列）**")
    out.append("")
    out.append("| 系 | s0 | s1 | s2 | s3 | s4 |")
    out.append("|---|---|---|---|---|---|")
    for el in sorted(by_el):
        cols = []
        for i in range(5):
            vs = [r["_per"][i] for r in by_el[el] if len(r["_per"]) > i]
            cols.append(f"{st.mean(vs)*100:.2f}" if vs else "-")
        out.append(f"| {NAME.get(el, el)} | " + " | ".join(cols) + " |")
    out.append("")
    out.append("**按体质分组（角色自己的原生体质）**")
    out.append("")
    out.append("| 分组 | 条数 | 平均增益 | 最大 |")
    out.append("|---|---|---|---|")
    groups = {"无体质": [], "水体质": [], "其他体质": []}
    for r in rows:
        n = [int(x) for x in r["natures"]]
        g = "无体质" if not n else ("水体质" if 14 in n else "其他体质")
        groups[g].append(r["_g"])
    for g, v in groups.items():
        if v:
            out.append(f"| {g} | {len(v)} | {st.mean(v)*100:.2f}% | {max(v)*100:.2f}% |")
    out.append("")
    out.append("**超 6% 的条目**")
    out.append("")
    out.append("| 角色 | 构筑 | 系 | 5 种子合计 | 逐种子 |")
    out.append("|---|---|---|---|---|")
    for r in sorted(big, key=lambda r: -r["_g"]):
        out.append(f"| {r['id']} {r['name']} | {r['build']} | {NAME.get(r['_el'], r['_el'])} | {r['_g']*100:.2f}% | " + ", ".join(f"{x*100:.1f}" for x in r["_per"]) + " |")
    return "\n".join(out)


def team(paths):
    rows = load(paths)
    out = ["## 场景 3：群控（3 只普通怪，12 回合）", ""]
    out.append("| 队 | 元素 | 种子 | 吃位 eskip | 敌出手 eact | 占比 | 冰冻/目标最大 | 我方出伤增益 | 敌方每场失行动 |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    worst = 0.0
    for i, r in enumerate(rows):
        label = ("单系·" + NAME.get(r["elem"], str(r["elem"]))) if r["kind"] == "single" else f"混搭{i - 9}"
        ratios = []
        for sd, d in sorted(pair(r["runs"]).items()):
            on = d[True]
            slots = on["eskip"] + on["eact"]
            ratio = on["eskip"] / slots if slots else 0
            ratios.append(ratio)
            worst = max(worst, ratio)
            out.append(f"| {label} | {r['ids']} | s{sd} | {on['eskip']} | {on['eact']} | {ratio*100:.1f}% | {on['max_frozen']} | - | {on['eskip']} |")
        per, tot = gain(r["runs"])
        out.append(f"| **{label} 合计** | | | | | 平均 {st.mean(ratios)*100:.1f}% 最大 {max(ratios)*100:.1f}% | | {tot*100:.2f}% | |")
    out.append("")
    out.append(f"- 全部种子×队伍中，敌方被元素停手吃掉的行动位占比最大 {worst*100:.1f}%（判线 17%）")
    return "\n".join(out)


def refill_table(rows, title, keys):
    out = [title, ""]
    out.append("| " + " | ".join(keys) + " | 出伤增益(开/关，合计) | 逐种子出伤增益% | 我方承伤 开/关−1 | 敌方被停手位 | 我方被停手位 | 挂上效果数 |")
    out.append("|" + "---|" * (len(keys) + 6))
    for r in rows:
        per, tot = gain(r["runs"])
        ons = [x for x in r["runs"] if x["on"]]
        offs = [x for x in r["runs"] if not x["on"]]
        io, iff = sum(x["inc"] for x in ons), sum(x["inc"] for x in offs)
        ap = sum(v.get("applied", 0) for x in ons for v in x["stats"].values())
        out.append("| " + " | ".join(str(r.get(k, "")) for k in keys) + f" | {tot*100:+.2f}% | {', '.join(f'{p*100:+.1f}' for p in per)} | {((io/iff-1)*100 if iff>0 else 0):+.1f}% | {sum(x['eskip'] for x in ons)} | {sum(x['askip'] for x in ons)} | {ap} |")
    return "\n".join(out)


def floor(paths):
    rows = load(paths)
    if json.load(open(paths[0])).get("refill"):
        return refill_table(rows, "## 场景 5：楼层守层者（补血口径：每次出手前补满，12 回合）", ["floor", "team_i", "ids"])
    out = ["## 场景 5：楼层守层者（不补血，12 回合）", ""]
    out.append("| 层 | 队 | 关·敌剩血% | 开·敌剩血% | 逐种子（关→开 打掉血量比，单位 %） | 关·我方全灭 | 开·我方全灭 | 关·获胜 | 开·获胜 |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        offs = [x for x in r["runs"] if not x["on"]]
        ons = [x for x in r["runs"] if x["on"]]
        def left(xs):
            return st.mean([x["ehp_left"] / x["ehp_max"] for x in xs]) * 100 if xs else 0
        per = []
        for sd, d in sorted(pair(r["runs"]).items()):
            a = d[False]["ehp_max"] - d[False]["ehp_left"]
            b = d[True]["ehp_max"] - d[True]["ehp_left"]
            per.append(f"{(b / a - 1) * 100:+.1f}" if a > 0 else "-")
        out.append(f"| {r['floor']} | {r['team_i']} | {left(offs):.1f} | {left(ons):.1f} | {', '.join(per)} | "
                   f"{sum(1 for x in offs if x['lost'])}/{len(offs)} | {sum(1 for x in ons if x['lost'])}/{len(ons)} | "
                   f"{sum(1 for x in offs if x['won'])}/{len(offs)} | {sum(1 for x in ons if x['won'])}/{len(ons)} |")
    return "\n".join(out)


def mix(paths):
    rows = load(paths)
    if json.load(open(paths[0])).get("refill"):
        return refill_table(rows, "## 场景 3b：合法混搭实战队 vs 纯基础队（补血口径）", ["team_i", "kind", "ids"])
    out = ["## 场景 3b：合法混搭实战队 vs 纯基础队（守层者，保留首领固定阶段，不补血）", ""]
    out.append("| 队号 | 构成 | 开/关打掉血量比（合计） | 逐种子 | 我方失行动(开，合计) | 敌方失行动(开，合计) | 我方全灭 关→开 | 获胜 关→开 |")
    out.append("|---|---|---|---|---|---|---|---|")
    for r in rows:
        per = []
        tot_on = tot_off = 0.0
        for sd, d in sorted(pair(r["runs"]).items()):
            a = d[False]["ehp_max"] - d[False]["ehp_left"]
            b = d[True]["ehp_max"] - d[True]["ehp_left"]
            tot_on += b
            tot_off += a
            per.append(f"{(b / a - 1) * 100:+.1f}" if a > 0 else "-")
        ons = [x for x in r["runs"] if x["on"]]
        offs = [x for x in r["runs"] if not x["on"]]
        out.append(f"| {r['team_i']} | {r['kind']} {r['ids']} | {((tot_on / tot_off) - 1) * 100:+.2f}% | {', '.join(per)} | "
                   f"{sum(x['askip'] for x in ons)} | {sum(x['eskip'] for x in ons)} | "
                   f"{sum(1 for x in offs if x['lost'])}→{sum(1 for x in ons if x['lost'])} | {sum(1 for x in offs if x['won'])}→{sum(1 for x in ons if x['won'])} |")
    return "\n".join(out)


def holy(paths):
    rows = load(paths)
    out = ["## 神圣·群体圣护（人人给盾）收益：几率 15%（中档）对 11%（降一档）", ""]
    out.append("| 档 | 队 | 种子 | 有资格 | 掷点 | 给盾次数 | 盾挡下减益 | 驱散日志 | 我方承伤(开) | 我方承伤(关) | 承伤变化 |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|")
    agg = {}
    for r in rows:
        for sd, d in sorted(pair(r["runs"]).items()):
            on, off = d[True], d[False]
            s8 = on["stats"].get("8", {})
            ch = (on["inc"] / off["inc"] - 1) * 100 if off["inc"] > 0 else 0
            out.append(f"| {r['variant']} | {r['team_i']} | s{sd} | {s8.get('eligible',0)} | {s8.get('rolled',0)} | {s8.get('applied',0)} | {on['blocks']} | {on['dispels']} | {on['inc']:.0f} | {off['inc']:.0f} | {ch:+.1f}% |")
            a = agg.setdefault(r["variant"], {"elig": 0, "rolled": 0, "applied": 0, "blocks": 0, "dispels": 0, "inc_on": 0.0, "inc_off": 0.0, "n": 0})
            a["elig"] += s8.get("eligible", 0); a["rolled"] += s8.get("rolled", 0); a["applied"] += s8.get("applied", 0)
            a["blocks"] += on["blocks"]; a["dispels"] += on["dispels"]; a["inc_on"] += on["inc"]; a["inc_off"] += off["inc"]; a["n"] += 1
    out.append("")
    out.append("**合计**")
    out.append("")
    out.append("| 档 | 场数 | 有资格 | 掷点 | 给盾 | 盾挡下减益 | 驱散 | 承伤 开/关 −1 |")
    out.append("|---|---|---|---|---|---|---|---|")
    for k, a in agg.items():
        out.append(f"| {k} | {a['n']} | {a['elig']} | {a['rolled']} | {a['applied']} | {a['blocks']} | {a['dispels']} | {(a['inc_on']/a['inc_off']-1)*100 if a['inc_off']>0 else 0:+.2f}% |")
    return "\n".join(out)


def dark(paths):
    rows = load(paths)
    out = ["## 首领线遮蔽锋芒补偿前后（boss_chance_rate 0.5 → 1.0）", ""]
    out.append("| 变体 | 层 | 种子 | 有资格 | 被体质挡 | 掷点 | 挂上 | 我方出伤增益 | 敌方出手伤害(开/关−1) |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    agg = {}
    for r in rows:
        for sd, d in sorted(pair(r["runs"]).items()):
            on, off = d[True], d[False]
            s9 = on["stats"].get("9", {})
            ch = (on["inc"] / off["inc"] - 1) * 100 if off["inc"] > 0 else 0
            out.append(f"| {r['variant']} | {r['floor']} | s{sd} | {s9.get('eligible',0)} | {s9.get('immune',0)} | {s9.get('rolled',0)} | {s9.get('applied',0)} | {(on['out']+on['dot'])/(off['out']+off['dot'])*100-100:+.2f}% | {ch:+.1f}% |")
            a = agg.setdefault(r["variant"], {"elig": 0, "imm": 0, "rolled": 0, "applied": 0, "inc_on": 0.0, "inc_off": 0.0})
            a["elig"] += s9.get("eligible", 0); a["imm"] += s9.get("immune", 0); a["rolled"] += s9.get("rolled", 0); a["applied"] += s9.get("applied", 0)
            a["inc_on"] += on["inc"]; a["inc_off"] += off["inc"]
    out.append("")
    out.append("**合计**")
    out.append("")
    out.append("| 变体 | 有资格 | 被体质挡 | 挡掉占比 | 掷点 | 挂上 | 挂上/有资格 | 敌方出手伤害 开/关−1 |")
    out.append("|---|---|---|---|---|---|---|---|")
    for k, a in agg.items():
        out.append(f"| {k} | {a['elig']} | {a['imm']} | {a['imm']/max(1,a['elig'])*100:.1f}% | {a['rolled']} | {a['applied']} | {a['applied']/max(1,a['elig'])*100:.1f}% | {(a['inc_on']/a['inc_off']-1)*100 if a['inc_off']>0 else 0:+.2f}% |")
    return "\n".join(out)


def dark2(paths):
    rows = load(paths)
    out = ["## 首领线遮蔽锋芒补偿前后（直接量：33 个守层者各 20 场，每场暗伤打首领一下）", ""]
    agg = {}
    per = {}
    for r in rows:
        a = agg.setdefault(r["variant"], {"eligible": 0, "immune": 0, "blocked": 0, "rolled": 0, "applied": 0})
        for k in a:
            a[k] += r[k]
        per.setdefault(r["floor"], {})[r["variant"]] = r
    out.append("| 变体 | 有资格 | 被体质挡 | 被体质挡占比 | 其他落空 | 实际掷点 | 挂上 | 挂上/有资格 | 挂上/掷点 |")
    out.append("|---|---|---|---|---|---|---|---|---|")
    for k, a in agg.items():
        out.append(f"| {k} | {a['eligible']} | {a['immune']} | {a['immune']/max(1,a['eligible'])*100:.1f}% | {a['blocked']} | {a['rolled']} | {a['applied']} | {a['applied']/max(1,a['eligible'])*100:.2f}% | {a['applied']/max(1,a['rolled'])*100:.1f}% |")
    out.append("")
    out.append("逐层（有资格／被挡／挂上，补偿前 → 补偿后）：")
    out.append("")
    out.append("| 层 | 前：有资格/被挡/挂上 | 后：有资格/被挡/挂上 |")
    out.append("|---|---|---|")
    for f in sorted(per):
        b, a = per[f]["before_0.5"], per[f]["after_1.0"]
        out.append(f"| {f} | {b['eligible']}/{b['immune']}/{b['applied']} | {a['eligible']}/{a['immune']}/{a['applied']} |")
    return "\n".join(out)


def csv_solo(paths):
    out = ["id,name,build,elem,natures,seed,on,out,dot,inc,eskip,eact,rev_e,rev_a,turns,stats"]
    for r in load(paths):
        for x in r["runs"]:
            stats = ";".join(f"{k}:{v.get('eligible',0)}/{v.get('immune',0)}/{v.get('blocked',0)}/{v.get('rolled',0)}/{v.get('applied',0)}" for k, v in sorted(x["stats"].items()))
            out.append(f"{r['id']},{r['name']},{r['build']},{r['elem']},{'|'.join(str(int(n)) for n in r['natures'])},{x['seed']},{int(x['on'])},{x['out']:.0f},{x['dot']:.0f},{x['inc']:.0f},{x['eskip']},{x['eact']},{x.get('rev_e',0)},{x.get('rev_a',0)},{x['turns']},{stats}")
    return "\n".join(out)


if __name__ == "__main__":
    print({"solo": solo, "team": team, "floor": floor, "mix": mix, "holy": holy, "dark": dark, "dark2": dark2, "csv_solo": csv_solo}[sys.argv[1]](sys.argv[2:]))
