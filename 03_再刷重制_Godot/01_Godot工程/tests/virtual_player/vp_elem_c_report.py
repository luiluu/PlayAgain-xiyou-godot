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
    uniq = {}
    for r in load(paths):
        uniq[(r["id"], r["build"])] = r   # 补量的文件放后面，同一角色同一构筑以后者为准
    rows = list(uniq.values())
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
    out.append("| 系 | 构筑数 | 平均增益 | 中位 | 最大 | 最小 | 有资格 | 被免疫 | 掷点 | 挂上 | 实挂/掷 | 敌人被停手位/敌出手 | 我方承伤 开/关−1 |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
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
        ons = [x for r in L for x in r["runs"] if x["on"]]
        offs = [x for r in L for x in r["runs"] if not x["on"]]
        sk = sum(x["eskip"] for x in ons)
        ea = sum(x["eact"] for x in ons)
        io, iff = sum(x["inc"] for x in ons), sum(x["inc"] for x in offs)
        extra = f" {sk}/{ea} | {((io/iff-1)*100 if iff>0 else 0):+.2f}% |"
        out.append(f"| {NAME.get(el, el)} | {len(L)} | {st.mean(gs)*100:.2f}% | {st.median(gs)*100:.2f}% | {max(gs)*100:.2f}% | {min(gs)*100:.2f}% | "
                   f"{tot.get('eligible',0)} | {tot.get('immune',0)} | {tot.get('rolled',0)} | {tot.get('applied',0)} | {tot.get('applied',0)/max(1,tot.get('rolled',0))*100:.1f}% |" + extra)
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
    """场景 3（R2）：分母去重。act 里被元素停手吃掉的位已计入 eact，旧口径再加 eskip 是重复；旧控位（进 act 前就动不了）另列、不进分母。
    逐目标：done＝完成位、eskip＝元素停手位、oskip＝旧控位、stop_need＝战斗结束时保护尚余（>0＝周期没走完）。
    判线只用「完整周期」目标（eskip≥1 且收尾 stop_need=0）；末次保护没走完的目标单列（短战体验）。"""
    rows = load(paths)
    out = ["## 场景 3：群控（12 回合；分母＝完成位＋元素停手位，不含旧控位）", ""]
    out.append("| 队 | 元素 | 敌群 | 目标×种子 | 完成位 | 元素停手位 | 旧控位 | 占比（全部目标） | 完整周期目标数 | 完整周期占比（判线） | 完整周期最大单目标 | 周期未走完目标数 | 冰冻/目标最大 | 旧口径占比（重复计入，对照） |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    worst_full = 0.0
    worst_pooled = 0.0
    worst_all = 0.0
    worst_old = 0.0
    tot = {"done": 0, "eskip": 0, "oskip": 0, "full_d": 0, "full_e": 0, "n_full": 0, "n_part": 0}
    detail = []
    for i, r in enumerate(rows):
        kind = r["kind"]
        label = ("单系·" + NAME.get(r["elem"], str(r["elem"]))) if kind == "single" else (f"混搭{i - 9}" if kind == "mixed" else f"追加行动·{NAME.get(r['elem'], r['elem'])}")
        troop = r.get("troop", "")
        d = e = o = fd = fe = nf = npart = 0
        fmax = 0.0
        fz = 0
        olds = []
        for x in r["runs"]:
            if not x["on"]:
                continue
            fz = max(fz, x["max_frozen"])
            slots_old = x["eskip"] + x["eact"]
            olds.append(x["eskip"] / slots_old if slots_old else 0)
            for k, t in x["tgt"].items():
                d += t.get("done", 0); e += t.get("eskip", 0); o += t.get("oskip", 0)
                if t.get("eskip", 0) >= 1:
                    if t.get("stop_need", 0) == 0:
                        nf += 1
                        fd += t.get("done", 0); fe += t["eskip"]
                        fmax = max(fmax, t["eskip"] / (t["done"] + t["eskip"]))
                        detail.append((label, x["seed"], k, t["done"], t["eskip"], t.get("oskip", 0), t.get("stop_need", 0), "完整"))
                    else:
                        npart += 1
                        detail.append((label, x["seed"], k, t["done"], t["eskip"], t.get("oskip", 0), t.get("stop_need", 0), "未走完"))
        allr = e / (d + e) if d + e else 0
        fr = fe / (fd + fe) if fd + fe else 0
        worst_all = max(worst_all, allr); worst_pooled = max(worst_pooled, fr); worst_full = max(worst_full, fmax); worst_old = max(worst_old, max(olds) if olds else 0)
        for k, v in zip(["done", "eskip", "oskip", "full_d", "full_e", "n_full", "n_part"], [d, e, o, fd, fe, nf, npart]):
            tot[k] += v
        out.append(f"| {label} | {r['ids']} | {troop} | {len(r['runs'])//2}局 | {d} | {e} | {o} | {allr*100:.1f}% | {nf} | {fr*100:.1f}% | {fmax*100:.1f}% | {npart} | {fz} | {max(olds)*100 if olds else 0:.1f}% |")
    out.append("")
    out.append(f"- 全部：完成位 {tot['done']}、元素停手位 {tot['eskip']}、旧控位 {tot['oskip']}；总占比 {tot['eskip']/max(1,tot['done']+tot['eskip'])*100:.1f}%")
    out.append(f"- **完整周期**目标 {tot['n_full']} 个（被停手≥1 次且收尾保护已走完）：合并占比 {tot['full_e']/max(1,tot['full_d']+tot['full_e'])*100:.1f}%，各行合并占比最大 {worst_pooled*100:.1f}%，**单目标单场最大 {worst_full*100:.1f}%**（判线 17%）；周期未走完 {tot['n_part']} 个（单列，不进判线）")
    out.append(f"- 全部目标（含未走完）各行最大占比 {worst_all*100:.1f}%；旧口径（分母重复计入 eskip，对照）各局最大 {worst_old*100:.1f}%")
    out.append("")
    out.append("**逐目标明细（被停手≥1 次的目标；完成位／元素停手位／旧控位／收尾尚余保护）**")
    out.append("")
    out.append("| 队 | 种子 | 目标位 | 完成位 | 元素停手位 | 旧控位 | 收尾 stop_need | 周期 |")
    out.append("|---|---|---|---|---|---|---|---|")
    for lab, sd, k, dd, ee, oo, sn, st_ in detail:
        out.append(f"| {lab} | s{sd} | {k} | {dd} | {ee} | {oo} | {sn} | {st_} |")
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


def count_legal(paths):
    d = json.load(open(paths[0]))
    lg = d["legal"]
    out = ["## 人数（口径 B：含合法装转换书；口径 A：原生，对照）", ""]
    out.append(f"有攻击技能且能出战 {lg['attackers']} 人；逐人按物品正式用书（item_learn_reason，寻常／炼狱／证道各判一次），学后取实际结算元素（action_elements 去重）含目标系才算。")
    out.append("")
    out.append("| 系 | 口径 B 人数 | 档位 | 几率 | 寻常合法人数 | 炼狱合法人数 | 证道合法人数 | 口径 A 原生人数 | 原生档位 | 表里现写 |")
    out.append("|---|---|---|---|---|---|---|---|---|---|")
    nm = dict(NAME); nm.update({11: "虚空", 12: "混沌", 13: "空间"})
    for e in ["2", "3", "4", "5", "6", "7", "8", "9", "14", "15", "11", "12", "13"]:
        v = lg["per_elem"][e]
        nat = d["native"].get(e, {})
        bd = v["n_by_diff"]
        out.append(f"| {nm[int(e)]} | {v['n']} | {v['tier']} | {int(v['chance']*100)}% | {bd['xunchang']} | {bd['lianyu']} | {bd['zhengdao']} | {nat.get('n','-')} | {nat.get('tier','-')} | {v['table_tier'] or '-'} |")
    miss = {}
    for k, v in lg["fails"].items():
        a, e, kind = k.split(":")
        if kind == "use":
            miss.setdefault(a, []).append(e)
    out.append("")
    out.append("学后没出现目标元素的人（编号：元素号）：" + ("；".join(f"{a}：{','.join(es)}" for a, es in sorted(miss.items())) or "无"))
    return "\n".join(out)


def solo_extra(paths):
    """P2-1：按效果实例分项（灼烧伤害、寄生伤害与有效治疗、回合开始伤害、反击伤害、失行动、驱散、挡减益）。合计均为 5 种子「开」的合计。"""
    uniq = {}
    for r in load(paths):
        uniq[(r["id"], r["build"])] = r
    rows = [r for r in uniq.values() if not any(x["turns"] == 0 for x in r["runs"])]
    out = ["## 分项收益（按效果实例；各系构筑 5 种子「开」合计）", ""]
    out.append("| 系 | 构筑数 | 灼烧伤害（tick 归因） | 寄生伤害 | 寄生有效治疗 | 回合开始伤害 | 敌方行动里我方反击伤害 | 敌方元素停手位 | 敌方旧控位 | 我方元素停手位 | 驱散 | 挡减益 | 净收益(出伤＋回合末＋回合开始＋反击，开/关−1) |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    by = {}
    for r in rows:
        el = r["elem"] if r["build"] == "book" else None
        if el is None:
            tot = {}
            for x in r["runs"]:
                if x["on"]:
                    for k, v in x["stats"].items():
                        tot[k] = tot.get(k, 0) + v.get("eligible", 0)
            el = int(max(tot, key=tot.get)) if tot else 0
        by.setdefault(el, []).append(r)
    for el in sorted(by):
        L = by[el]
        ons = [x for r in L for x in r["runs"] if x["on"]]
        offs = [x for r in L for x in r["runs"] if not x["on"]]
        S = lambda xs, k: sum(x.get(k, 0) for x in xs)
        net = lambda xs: sum(x["out"] + x["dot"] + x.get("ts_out", 0) + x.get("ctr", 0) for x in xs)
        n_on, n_off = net(ons), net(offs)
        out.append(f"| {NAME.get(el, el) if el else '无元素事件'} | {len(L)} | {S(ons,'burn_dmg'):.0f} | {S(ons,'parasite_dmg'):.0f} | {S(ons,'para_heal'):.0f} | {S(ons,'ts_out'):.0f} | {S(ons,'ctr'):.0f} | {S(ons,'eskip')} | {S(ons,'oskip')} | {S(ons,'aeskip')} | {S(ons,'dispels')} | {S(ons,'blocks')} | {((n_on/n_off-1)*100 if n_off>0 else 0):+.2f}% |")
    zero = 0
    over = 0
    for r in rows:
        for x in r["runs"]:
            if not x["on"] and x["out"] + x["dot"] == 0:
                zero += 1
            if x.get("rev_e", 0) > 0 and not x["on"]:
                over += 1
    out.append("")
    out.append(f"- 零基线（关效果时出伤＋回合末持续伤害为 0）的场 {zero} 个；过杀（夹具被一击打死后复活补满）的场（关） {over} 个。")
    return "\n".join(out)


def main_baseline(paths):
    """P1-3：合法秘籍格主基线核对（用书→占格→封印流程）。"""
    uniq = {}
    for r in load(paths):
        uniq[(r["id"], r["build"], r.get("diff"))] = r
    out = ["## 合法构筑核对（用书、占格、封印流程）", ""]
    by = {}
    for r in uniq.values():
        by.setdefault(r.get("diff", "?"), []).append(r)
    out.append("| 难度 | 构筑数 | 满格（used=cap） | 转换书合法 | 封印流程走通（满格被拒→封印→再学） | 格数分布 cap（人数） | 零回合剔除 |")
    out.append("|---|---|---|---|---|---|---|")
    for diff, L in by.items():
        full = sum(1 for r in L if r["build_info"].get("used") == r["build_info"].get("cap"))
        conv = sum(1 for r in L if r["elem"] > 0 and r["build_info"].get("conv") == "ok")
        nconv = sum(1 for r in L if r["elem"] > 0)
        seal = sum(1 for r in L if r["build_info"].get("seal_ok"))
        caps = {}
        for r in L:
            c = r["build_info"].get("cap", 0)
            caps[c] = caps.get(c, 0) + 1
        zero = sum(1 for r in L if any(x["turns"] == 0 for x in r["runs"]))
        out.append(f"| {diff} | {len(L)} | {full} | {conv}/{nconv} | {seal} | {dict(sorted(caps.items()))} | {zero} |")
    return "\n".join(out)


def support(paths):
    rows = load(paths)
    out = ["## 无攻击技能角色（13 人）开／关样本", ""]
    out.append("| 角色 | 配队 | 体质 | 有资格(神圣己方入口等) | 掷点 | 挂上 | 挡减益 | 驱散 | 元素停手位(敌/我) | 我方承伤 开/关−1 | 出伤增益 | 零触发？ |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        ons = [x for x in r["runs"] if x["on"]]
        offs = [x for x in r["runs"] if not x["on"]]
        tot = {}
        for x in ons:
            for k, v in x["stats"].items():
                for kk, vv in v.items():
                    tot[kk] = tot.get(kk, 0) + vv
        io, iff = sum(x["inc"] for x in ons), sum(x["inc"] for x in offs)
        _, g = gain(r["runs"])
        out.append(f"| {r['id']} {r['name']} | {'+2号输出' if r['pair'] else '单人'} | {','.join(str(int(n)) for n in r['natures']) or '无'} | {tot.get('eligible',0)} | {tot.get('rolled',0)} | {tot.get('applied',0)} | {sum(x['blocks'] for x in ons)} | {sum(x['dispels'] for x in ons)} | {sum(x['eskip'] for x in ons)}/{sum(x['askip'] for x in ons)} | {((io/iff-1)*100 if iff>0 else 0):+.2f}% | {g*100:+.2f}% | {'是' if tot.get('applied',0)==0 else '否'} |")
    return "\n".join(out)


def defense(paths):
    d = json.load(open(paths[0]))
    out = ["## 场景 4：敌打我方（dev.909 B2；我方 4 人合法构筑，敌方补满、我方不补血不复活；12 回合；各格 5 种子开／关配对）", ""]
    out.append(f"我方分组可选人数：{d['groups']}（按角色自己的原生体质：无体质／水体质／有其他体质）。")
    out.append("")
    out.append("| 我方体质组 | 配装 | 敌方 | 敌群号 | 我方失行动(元素停手位 开→关) | 旧控位(开) | 承伤 开/关−1 | 灭团 关→开 | 平均存活回合 关→开 | 敌方挂上我方效果次数(开) | 圣护挡减益(开) |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|")
    agg = {}
    for r in d["rows"]:
        ons = [x for x in r["runs"] if x["on"]]
        offs = [x for x in r["runs"] if not x["on"]]
        S = lambda xs, k: sum(x.get(k, 0) for x in xs)
        io, iff = S(ons, "inc"), S(offs, "inc")
        lost_on = sum(1 for x in ons if x["lost"]); lost_off = sum(1 for x in offs if x["lost"])
        ap = sum(v.get("applied", 0) for x in ons for v in x["stats"].values())
        ch = f"{(io/iff-1)*100:+.1f}%" if iff > 0 else "-"
        out.append(f"| {r['group']} | {r['diff']} | {r['kind']} | {r['troop']} | {S(ons,'aeskip')} → {S(offs,'aeskip')} | {S(ons,'aoskip')} | {ch} | {lost_off}→{lost_on} (共{len(ons)}) | {st.mean([x['turns'] for x in offs]):.1f}→{st.mean([x['turns'] for x in ons]):.1f} | {ap} | {S(ons,'blocks')} |")
        a = agg.setdefault((r["group"], r["kind"]), {"aes": 0, "io": 0.0, "iff": 0.0, "lo": 0, "lf": 0, "n": 0})
        a["aes"] += S(ons, "aeskip"); a["io"] += io; a["iff"] += iff; a["lo"] += lost_on; a["lf"] += lost_off; a["n"] += len(ons)
    out.append("")
    out.append("**按体质组×敌方类型合计（两个配装合并）**")
    out.append("")
    out.append("| 体质组 | 敌方 | 我方失行动(开) | 承伤 开/关−1 | 灭团 关→开 |")
    out.append("|---|---|---|---|---|")
    for (g, k), a in sorted(agg.items()):
        out.append(f"| {g} | {k} | {a['aes']} | {((a['io']/a['iff']-1)*100 if a['iff']>0 else 0):+.1f}% | {a['lf']}→{a['lo']} (共{a['n']}) |")
    return "\n".join(out)


def floor2(paths):
    d = json.load(open(paths[0]))
    out = [f"## 场景 5：D271 标准队（模板 {d['tpl']}＝{d['diff']}，带装备／秘籍／法宝）打守层者与骑士一阶段（不补血，开／关配对）", ""]
    out.append("| 层 | 队 | 种子 | 关·赢 | 开·赢 | 关·回合 | 开·回合 | 关·我方出手数 | 开·我方出手数 | 关·全灭 | 开·全灭 | 元素事件(开：资格/掷/挂) |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    agg = {}
    byk = {}
    for r in d["rows"]:
        byk.setdefault((r["floor"], r["team_i"], r["seed"]), {})[r["on"]] = r
    for (f, ti, sd), v in sorted(byk.items()):
        off, on = v[False], v[True]
        s = on["stats"]
        el = sum(x.get("eligible", 0) for x in s.values()); ro = sum(x.get("rolled", 0) for x in s.values()); ap = sum(x.get("applied", 0) for x in s.values())
        out.append(f"| {f} | {ti} | s{sd} | {off['won']} | {on['won']} | {off['turns']} | {on['turns']} | {off.get('acts','-')} | {on.get('acts','-')} | {off['lost']} | {on['lost']} | {el}/{ro}/{ap} |")
        a = agg.setdefault(f, {"n": 0, "to": 0, "tf": 0, "ao": 0, "af": 0, "lo": 0, "lf": 0, "ev": 0})
        a["n"] += 1; a["to"] += on["turns"]; a["tf"] += off["turns"]; a["ao"] += on.get("acts", 0); a["af"] += off.get("acts", 0); a["lo"] += on["lost"]; a["lf"] += off["lost"]; a["ev"] += ap
    out.append("")
    out.append("**合计（每层）**")
    out.append("")
    out.append("| 层 | 场数 | 平均通关回合 关→开 | 平均我方出手数 关→开 | 变化 | 灭团 关→开 | 开：挂上效果数 |")
    out.append("|---|---|---|---|---|---|---|")
    for f, a in sorted(agg.items()):
        ch = f"{(a['ao']/a['af']-1)*100:+.1f}%" if a["af"] else "-"
        out.append(f"| {f} | {a['n']} | {a['tf']/a['n']:.2f}→{a['to']/a['n']:.2f} | {a['af']/a['n']:.2f}→{a['ao']/a['n']:.2f} | {ch} | {a['lf']}→{a['lo']} | {a['ev']} |")
    return "\n".join(out)


def csv_solo(paths):
    out = ["id,name,build,elem,natures,seed,on,out,dot,inc,eskip,oskip,eact,rev_e,rev_a,turns,ts_out,ctr,burn_dmg,parasite_dmg,para_heal,stats"]
    uniq = {}
    for r in load(paths):
        uniq[(r["id"], r["build"])] = r
    for r in uniq.values():
        for x in r["runs"]:
            stats = ";".join(f"{k}:{v.get('eligible',0)}/{v.get('immune',0)}/{v.get('blocked',0)}/{v.get('rolled',0)}/{v.get('applied',0)}" for k, v in sorted(x["stats"].items()))
            out.append(f"{r['id']},{r['name']},{r['build']},{r['elem']},{'|'.join(str(int(n)) for n in r['natures'])},{x['seed']},{int(x['on'])},{x['out']:.0f},{x['dot']:.0f},{x['inc']:.0f},{x['eskip']},{x.get('oskip',0)},{x['eact']},{x.get('rev_e',0)},{x.get('rev_a',0)},{x['turns']},{x.get('ts_out',0):.0f},{x.get('ctr',0):.0f},{x.get('burn_dmg',0):.0f},{x.get('parasite_dmg',0):.0f},{x.get('para_heal',0):.0f},{stats}")
    return "\n".join(out)


if __name__ == "__main__":
    print({"solo": solo, "team": team, "floor": floor, "mix": mix, "holy": holy, "dark": dark, "dark2": dark2, "csv_solo": csv_solo, "count_legal": count_legal, "solo_extra": solo_extra, "main_baseline": main_baseline, "support": support, "defense": defense, "floor2": floor2}[sys.argv[1]](sys.argv[2:]))
