#!/usr/bin/env python3
"""从 T438 13 份实测 JSON 自动汇总生成《D271_31至36层毕业胜率实测报告.md》。"""
import json
import os
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT_MD = HERE.parent / "D271_31至36层毕业胜率实测报告.md"

LINES = ["war", "famine", "death", "plague"]
LINE_CN = {"war": "战争·莉co", "famine": "饥荒·做题家", "death": "死亡·勇者", "plague": "瘟疫·混子"}
FLOOR_CN = {
    "31": "31层 女娲",
    "32": "32层 伏羲",
    "33": "33层 鸿蒙老祖",
    "34": "34层 鸿钧",
    "35": "35层 四线影子(总)",
    "36": "36层 四线骑士(总)",
}


def load(name):
    return json.loads((HERE / name).read_text(encoding="utf-8"))


def fmt_pct(x):
    return f"{x * 100:.1f}%"


def paired_cases(tpl_data, f, teams=(0, 1), seed=1):
    fd = tpl_data["floors"][f]
    if int(f) <= 34:
        return [c for c in fd["cases"] if c["team_idx"] in teams and c["seed"] == seed]
    out = []
    for ln in LINES:
        for c in fd["by_line"][ln]["cases"]:
            if c["team_idx"] in teams and c["seed"] == seed:
                out.append(c)
    return out


def agg_cases(cs):
    n = len(cs)
    if n == 0:
        return {"n": 0, "wins": 0, "rate": 0.0, "turns": 0.0, "deaths": 0.0, "falls": 0.0, "inst": 0, "to": 0, "hp0": 0.0}
    w = sum(1 for c in cs if c["won"])
    return {
        "n": n,
        "wins": w,
        "rate": w / n,
        "turns": statistics.mean(c["turns"] for c in cs),
        "deaths": statistics.mean(c["deaths"] for c in cs),
        "falls": statistics.mean(c["falls_total"] for c in cs),
        "inst": sum(1 for c in cs if c.get("instant_loss")),
        "to": sum(1 for c in cs if c.get("timeout")),
        "hp0": statistics.mean(c["party_hp0"] for c in cs),
    }


def main():
    mains = {k: load(f"main_{k}.json") for k in ["A", "B", "C", "D"]}
    art_mid = load("art_mid_BCD.json")
    art_cap = load("art_cap_BCD.json")
    split_hh = load("split_hh_cap_CD.json")
    split_cr = load("split_crown_cap_CD.json")
    cross_c = {m: load(f"cross_C_zd_{m}.json") for m in ["none", "mid", "cap"]}
    cross_a = load("cross_A_xc.json")
    cross_b = load("cross_B_ly.json")

    lines = []
    lines.append("# [T438] 天启篇 31～36 层五档毕业胜率实测报告（D271 标尺＋成长神器对照）")
    lines.append("")
    lines.append("- **依据**：Kyo 11-23 **D271** 五档难度总纲与毕业标尺（寻常／艰险／九死／炼狱／证道；九死＝4 强＋同级毕业装含不少神话较轻松过；炼狱＝2 超强 2 强＋养成 80% 较轻松过；证道＝养成 95%+ 几乎无法优化才过）；协调补充要求把成长神器（心之钢 7900／杰作利维坦 7901、狂妄 7902／杰作无我 7903、魔冠「\"头顶\"」7940）与 `gear_table.json` 现行 `artifact_cap` 纳入对照。")
    lines.append("- **测试范围与口径**：严格**只测不改游戏本体与数值表**；新增独立脚本 `03_再刷重制_Godot/01_Godot工程/tests/virtual_player/t438_d271_benchmark.gd`，全部走游戏真实战斗结算、敌群事件（31～34 层含变身与按段终焉异化）、四线 35 层影子与 36 层骑士本体战（战争／饥荒／死亡／瘟疫四线全覆）与虚拟玩家复活 AI（`VPLogic`，含常规复活道具）。")
    lines.append("- **总实测场次**：**588 场**真实战斗（13 份原始 JSON 均存放在 `00_项目管理/归档/交付截图/luiluu_t438/T438_量数/`，脚本错误为 0，无任何剔除）：")
    lines.append("  - 主矩阵（4 套模板 A/B/C/D × 31～36 层，无成长神器基线 `--artifact=none`）：3 支随机合法阵容 × 2 种子（31～34 层每层 6 场轮覆四线按段异化，35～36 层每线 6 场共 24 场/层），共 **288 场**；")
    lines.append("  - 成长神器对照（九死 B／炼狱 C／证道 D × 31～36 层）：同阵容配对中度刷高 `--artifact=mid`（72 场）＋刷满当前上限 `--artifact=cap`（72 场），共 **144 场**；")
    lines.append("  - 三神器拆解对照（炼狱 C／证道 D × 33/35/36 层）：仅 10 阶杰作无我＋10 阶杰作利维坦 `--artifact=hh_cap`（36 场）vs 全员头顶 +300% `--artifact=crown_cap`（36 场），共 **72 场**；")
    lines.append("  - 跨档边界对照：炼狱 80%（C）打证道 35～36 层（`none`/`mid`/`cap` 各 16 场＝48 场）、艰险混搭（A）打寻常（18 场）、九死 4 强（B）打炼狱（18 场），共 **84 场**。")
    lines.append("")

    # Section 1: 4 templates spec & gear req_level table
    lines.append("## 一、四套 D271 标准测算模板与装备需求等级（`req_level`）明细表")
    lines.append("")
    lines.append("严格遵循 `XTianqiSummit.level_cap` 真实等级上限：**31～33 层 Lv75，34～35 层 Lv80，36 层 Lv81**。常规装备 1～10 栏（不含法宝／坐骑／神器）严格校验 `Weapons.json` / `Armors.json` 的 `req_level` 与 `XTianqiQiyinEquip` 七印神话等级，**严禁将 Lv35～50 低级不朽混充毕业装**。")
    lines.append("")
    lines.append("| 模板 | 对应难度 | 阵容构成（上场 4 人｜助力位） | 装备口径与词条 | 其余养成配置 |")
    lines.append("| --- | --- | --- | --- | --- |")
    lines.append("| **A 艰险顺推混搭对照** | 艰险 (`jianxian`) | 2 强＋2 弱（含 1 复活辅）｜弱者 | 对标 T432 顺推混搭（无七印／无 Lv80 神话，Lv40～75 传说/不朽混搭，常规随机词条） | 进阶≤2阶、法宝 Lv90、熟练度 0%、秘籍 0、种族 1 阶、输出烙印 40%/坦辅 20%、天平酒 |")
    lines.append("| **B 九死 4 强毕业装** | 九死 (`jiusi`) | 4 强者（2 输出＋1 坦 1 辅／2 辅，含 1 复活辅）｜强者 | 100% `req_level≥70`：31～33 层 4 件 Lv75 七印常规神话＋6 件 Lv70～75 不朽；34～35 层 6～7 件 Lv80 神话；36 层 7～8 件 Lv80 神话（**全常规随机词条，不洗最优**） | 进阶满、法宝 Lv99、不朽坐骑、熟练度 50%、秘籍 50%、号卷 0、种族 3 阶、输出烙印 55%/坦辅 30%、天平酒 |")
    lines.append("| **C 炼狱 2 超 2 强 80%** | 炼狱 (`lianyu`) | 2 超强输出＋2 强坦辅（含 1 复活辅）｜强者 | 100% `req_level≥70`：成套 6 件七印神话（34+ 层半真印）＋七印武器＋Lv80 神话项链＋Lv70～75 不朽副手/戒指；**上品词条 2 槽职责优选＋1 槽随机（~80%）** | 进阶满、法宝 Lv99、不朽坐骑、熟练度 80%、秘籍 80%、输出号卷 1 卷、种族 5 阶、输出烙印 75%/坦辅 40%、天平酒＋油 |")
    lines.append("| **D 证道 95%+ 拉满** | 证道 (`zhengdao`) | 前排高梯队 2 超强输出＋高承伤坦＋强复活辅｜**超强者同步拉满** | 100% `req_level≥70`：全套 6 件七印**真印**神话＋真印毕业武器＋Lv80 神话项链＋Lv70～75 最高副手/戒指；**全 4 阶极品（`perfect`）3 槽职责最优词条＋团队光环** | 进阶满、法宝 Lv99（带极品光环）、不朽坐骑、熟练度 100%、秘籍满格、号卷满格、种族 7 阶满、输出烙印 100%/坦辅 40%、天平酒＋油 |")
    lines.append("")

    lines.append("### 1.1 实测装备需求等级（`req_level`）与品质明细表（上场 4 人 1～10 常规装备栏，3 支阵容合计）")
    lines.append("")
    lines.append("| 模板 | 层段（角色等级） | 统计件数 | 均 `req_level` | 中位 | 范围 | `<60` 件 | `60～69` 件 | `70～75` 件 | `80～81` 件 | 史诗及以下 | 传说 | 不朽 | 神话（占比） | 七印／真印件数 |")
    lines.append("| --- | --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |")
    for tk in ["A", "B", "C", "D"]:
        tpl = mains[tk]["templates"][tk]
        for label, fkey, lv in [("31～33 层", "31", 75), ("34～35 层", "34", 80), ("36 层", "36", 81)]:
            g = tpl["gear_summary"][fkey]
            b = g["bands"]
            gr = g["grades"]
            lines.append(
                f"| {tk} | {label} (Lv{lv}) | {g['total_items']} | **{g['req_mean']:.1f}** | {g['req_median']:.0f} | {g['req_min']}～{g['req_max']} | "
                f"{b['<60']} | {b['60-69']} | {b['70-75']} | {b['80-81']} | "
                f"{gr['史诗及以下']} | {gr['传说']} | {gr['不朽']} | {gr['神话']} ({fmt_pct(g['myth_ratio'])}) | {g['qiyin']}／{g['true_seal']} |"
            )
    lines.append("")
    lines.append("> 核验结论：模板 A 均 `req_level = 63.6`（中位 60，范围 45～75，0 件神话），与 T432 实测 33 层顺推存档（r6 均 60.4、s3 均 59.1、s5 均 58.4，中位 60）高度接近；模板 B/C/D 全部 **0 件 `<70` 装备**，31～33 层 100% 落在 Lv70～75，34～36 层 100% 落在 Lv70～80 且神话占比达 70%～82%，杜绝低级不朽混充。")
    lines.append("")

    # Section 2: Main benchmark matrix
    lines.append("## 二、主矩阵实测结果：31～36 层逐档逐层胜率、回合与阵亡（无成长神器基线）")
    lines.append("")
    lines.append("### 2.1 四模板 × 31～36 层总览表（每层：胜率｜平均回合｜终局均阵亡｜全战均倒下人次｜秒杀≤3回合败）")
    lines.append("")
    lines.append("| 层级（Boss） | A 艰险顺推混搭 (`jianxian`) | B 九死 4 强毕业 (`jiusi`) | C 炼狱 2 超 2 强 80% (`lianyu`) | D 证道 95%+ 拉满 (`zhengdao`) |")
    lines.append("| --- | --- | --- | --- | --- |")
    for f in ["31", "32", "33", "34", "35", "36"]:
        cells = []
        for tk in ["A", "B", "C", "D"]:
            s = mains[tk]["templates"][tk]["floors"][f]["summary"]
            inst_s = f"，秒{s['instant_losses']}" if s["instant_losses"] > 0 else ""
            cells.append(f"**{fmt_pct(s['win_rate'])}** ({s['wins']}/{s['n']})｜{s['turns_mean']:.1f}回｜死{s['deaths_mean']:.2f}/倒{s['falls_mean']:.2f}{inst_s}")
        lines.append(f"| {FLOOR_CN[f]} | " + " | ".join(cells) + " |")
    lines.append("")

    lines.append("### 2.2 35 层四线影子与 36 层四线骑士决战逐线明细（每格 N＝6 场，3 阵容 × 2 种子）")
    lines.append("")
    lines.append("| 层级与线路 | 基准血量（艰险） | A 艰险顺推 | B 九死 4 强毕业 | C 炼狱 80% | D 证道 95%+ |")
    lines.append("| --- | ---: | --- | --- | --- | --- |")
    base_hp_ref = {
        ("35", "war"): "1,895,000（含援军）",
        ("35", "famine"): "1,670,000",
        ("35", "death"): "1,670,000",
        ("35", "plague"): "1,670,000",
        ("36", "war"): "2,225,000（本体200万）",
        ("36", "famine"): "1,995,000（本体177万）",
        ("36", "death"): "2,220,000（免暴击）",
        ("36", "plague"): "660,000（证道288万）",
    }
    for f in ["35", "36"]:
        kind_cn = "影子" if f == "35" else "骑士决战"
        for ln in LINES:
            cells = []
            for tk in ["A", "B", "C", "D"]:
                s = mains[tk]["templates"][tk]["floors"][f]["by_line"][ln]["summary"]
                cells.append(f"{fmt_pct(s['win_rate'])} ({s['wins']}/{s['n']})｜{s['turns_mean']:.1f}回｜死{s['deaths_mean']:.2f}")
            lines.append(f"| {f}层 {LINE_CN[ln]}({kind_cn}) | {base_hp_ref[(f, ln)]} | " + " | ".join(cells) + " |")
    lines.append("")

    lines.append("### 2.3 31～34 层守层者血量断层与败因核实（无神器基线）")
    lines.append("")
    lines.append("| 层级 | 艰险血量 | 九死血量 | 炼狱血量 | 证道血量 | 失败场次特征（超时 vs 团灭，败局剩余血量%） |")
    lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
    for f in ["31", "32", "33", "34"]:
        ehps = []
        notes = []
        for tk in ["A", "B", "C", "D"]:
            cs = mains[tk]["templates"][tk]["floors"][f]["cases"]
            ehps.append(f"{cs[0]['enemy_hp0']:,}")
            to_n = sum(1 for c in cs if c["timeout"])
            lo_n = sum(1 for c in cs if c["lost"])
            lefts = [c["enemy_hp_left_pct"] * 100 for c in cs if not c["won"]]
            if lefts:
                notes.append(f"{tk}:超时{to_n}/灭{lo_n}(均剩{statistics.mean(lefts):.0f}%)")
            else:
                notes.append(f"{tk}:全胜")
        lines.append(f"| {FLOOR_CN[f]} | " + " | ".join(ehps) + " | " + "；".join(notes) + " |")
    lines.append("")
    lines.append("> **致命结构性发现**：")
    lines.append("> 1. **31 层女娲（1,296 万～2,430 万）与 34 层鸿钧（6,000 万～1.125 亿）是血牛＋成长回血死局**：`6056` 成长招回血与叠最大生命让残血不降反升（败局结束时剩余血量达初始血量的 120%～145%），同时 `atk_scale` 偏低导致我方九死/炼狱/证道几乎 **0 阵亡**，纯属打不穿的僵局超时。")
    lines.append("> 2. **33 层鸿蒙老祖（64 万～121 万）→ 34 层鸿钧（6,000 万～1.125 亿）→ 35 层影子（167 万～468 万）→ 36 层骑士（66 万～1,110 万）血量断崖倒挂高达 30～93 倍**，导致毕业队卡死在 31、34 层，却在 35、36 层 1～2 回合瞬间蒸发 Boss。")
    lines.append("")

    # Section 3: Artifact growth comparison
    lines.append("## 三、成长神器（心之钢／狂妄／头顶）刷高对照与 `artifact_cap` 评估")
    lines.append("")
    lines.append("核实现行 `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/gear_table.json` 的 `artifact_cap`（均标 `draft: true` 占位）：")
    lines.append("- `heartsteel_stage = 10`：杰作利维坦（7901）满 10 阶（5,500 层）最大生命 **×2.1（+110%）**＋每回合末回血 5%＋巨人吞噬（经 `XHeartsteel.param` 直接裸乘，不吃九线属性 +30% 封顶）；")
    lines.append("- `hubris_stage = 10`：杰作无我（7903）满 10 阶（5,500 盛名）物理穿透 **27%**＋扬名物攻 **×2.2（+120%）**（经 `XHubris.param` 直接裸乘）；")
    lines.append("- `crown_bonus_pct = 300`：魔冠「\"头顶\"」（7940）满上限八项全属性 **×4.0（+300%）**；**关键代码核查**：`tianqi_ledger.gd:642` `bucket_of()` 仅将 `XHubris` 归入 `hubris` 桶，**`XDemonCrown`（7940）落入 `equip` 桶，未受 `param_cap` 九线 +30% 封顶限制，+300% 全额裸乘八维！**")
    lines.append("")
    lines.append("### 3.1 同阵容精确配对对照：无神器 (`none`) vs 中度刷高 (`mid`: 6阶/头顶+150%) vs 刷满上限 (`cap`: 10阶/头顶+300%)")
    lines.append("")
    lines.append("（均取各模板前 2 支完全相同阵容、种子 1 精确配对；31～34 层每格 2 场，35～36 层每格四线合计 8 场）")
    lines.append("")
    lines.append("| 模板（难度） | 层级 | 无神器基线 (`none`) | 中度刷高 (`mid`) | 刷满上限 (`cap`) | 胜率／回合变化（`none → cap`） |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    for tk in ["B", "C", "D"]:
        m0 = mains[tk]["templates"][tk]
        mm = art_mid["templates"][tk]
        mc = art_cap["templates"][tk]
        for f in ["31", "32", "33", "34", "35", "36"]:
            s0 = agg_cases(paired_cases(m0, f))
            sm = agg_cases(paired_cases(mm, f))
            sc = agg_cases(paired_cases(mc, f))
            dr = (sc["rate"] - s0["rate"]) * 100
            dt = sc["turns"] - s0["turns"]
            lines.append(
                f"| {tk} ({m0['difficulty']}) | {FLOOR_CN[f]} | "
                f"{fmt_pct(s0['rate'])} ({s0['wins']}/{s0['n']})｜{s0['turns']:.1f}回 | "
                f"{fmt_pct(sm['rate'])} ({sm['wins']}/{sm['n']})｜{sm['turns']:.1f}回 | "
                f"**{fmt_pct(sc['rate'])}** ({sc['wins']}/{sc['n']})｜**{sc['turns']:.1f}回** | "
                f"胜率 {dr:+.1f}pp，回合 {dt:+.1f} |"
            )
    lines.append("")

    lines.append("### 3.2 三神器贡献拆解：仅 10 阶无我＋利维坦 (`hh_cap`) vs 混配满上限 (`cap`) vs 全员头顶 +300% (`crown_cap`)")
    lines.append("")
    lines.append("| 模板 | 观测点 | 无神器 (`none`) | 仅 10 阶无我+利维坦 (`hh_cap`) | 混配满上限 (`cap`: 1头顶+1无我+2利维坦) | 全员头顶 +300% (`crown_cap`) |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    for tk in ["C", "D"]:
        m0 = mains[tk]["templates"][tk]
        mhh = split_hh["templates"][tk]
        mcap = art_cap["templates"][tk]
        mcr = split_cr["templates"][tk]
        for label, f, only_ln in [("33层 鸿蒙", "33", None), ("36层 死亡·勇者(唯一硬仗)", "36", "death"), ("36层 四线合计", "36", None)]:
            def get_cs(td):
                if only_ln:
                    return [c for c in td["floors"][f]["by_line"][only_ln]["cases"] if c["team_idx"] in (0, 1) and c["seed"] == 1]
                return paired_cases(td, f)
            s0 = agg_cases(get_cs(m0))
            sh = agg_cases(get_cs(mhh))
            sc = agg_cases(get_cs(mcap))
            sr = agg_cases(get_cs(mcr))
            lines.append(
                f"| {tk} | {label} | "
                f"{fmt_pct(s0['rate'])}｜{s0['turns']:.1f}回｜总血{s0['hp0']/1e4:.0f}万 | "
                f"{fmt_pct(sh['rate'])}｜{sh['turns']:.1f}回｜总血{sh['hp0']/1e4:.0f}万 | "
                f"{fmt_pct(sc['rate'])}｜{sc['turns']:.1f}回｜总血{sc['hp0']/1e4:.0f}万 | "
                f"**{fmt_pct(sr['rate'])}｜{sr['turns']:.1f}回｜总血{sr['hp0']/1e4:.0f}万** |"
            )
    lines.append("")
    lines.append("> **拆解结论**：")
    lines.append("> - **仅 10 阶杰作无我＋10 阶杰作利维坦（`hh_cap`）**：在 36 层死亡骑士·勇者上仅缩短 **12.5%～15.8% 回合**（炼狱 12.0→10.5 回合，证道 9.5→8.0 回合），团队血量 ×1.46～1.61，增幅**温和且符合毕业神器预期**。")
    lines.append("> - **魔冠「\"头顶\"」（7940）是绝对数值核爆源**：仅 1 名输出戴头顶 +150%（`mid`）就把死亡勇者回合从 12.0/9.5 砍到 5.0/3.5（提速 **2.4～2.7 倍**）；戴头顶 +300%（`cap`）直接砍到 **2.5 回合（提速 3.8～4.8 倍）**；全员头顶 +300% 时证道队伍血量从 226 万暴涨至 **905 万（×4.0）**，证道 36 层全四线 1.2 回合 0 伤亡蒸发。")
    lines.append("")

    # Section 4: Cross-difficulty boundaries
    lines.append("## 四、跨档边界对照：验证 D271 梯度与 `artifact_cap` 是否破坏证道门禁")
    lines.append("")
    lines.append("| 对照组（模板 → 跨档目标难度） | 神器档 | 33 层 | 35 层四线总计 | 36 层战争 | 36 层饥荒 | 36 层死亡·勇者 | 36 层瘟疫 | 36 层总计 |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")

    def cross_row(name, art_cn, td, has33=True):
        c33 = "—"
        if has33 and "33" in td["floors"]:
            s33 = td["floors"]["33"]["summary"]
            c33 = f"{fmt_pct(s33['win_rate'])} ({s33['turns_mean']:.1f}回)"
        s35 = td["floors"]["35"]["summary"]
        s36 = td["floors"]["36"]["summary"]
        bl = td["floors"]["36"]["by_line"]
        def fc(ln):
            s = bl[ln]["summary"]
            return f"{fmt_pct(s['win_rate'])} ({s['turns_mean']:.1f}回)"
        return (
            f"| {name} | {art_cn} | {c33} | {fmt_pct(s35['win_rate'])} ({s35['turns_mean']:.1f}回) | "
            f"{fc('war')} | {fc('famine')} | {fc('death')} | {fc('plague')} | "
            f"**{fmt_pct(s36['win_rate'])}** ({s36['turns_mean']:.1f}回, 死{s36['deaths_mean']:.2f}) |"
        )

    lines.append(cross_row("A 艰险顺推混搭 → **寻常(1档)**", "无神器", cross_a["templates"]["A"], True))
    lines.append(cross_row("B 九死 4 强毕业 → **炼狱(4档)**", "无神器", cross_b["templates"]["B"], True))
    lines.append(cross_row("C 炼狱 80% 养成 → **证道(5档)**", "无神器 (`none`)", cross_c["none"]["templates"]["C"], False))
    lines.append(cross_row("C 炼狱 80% 养成 → **证道(5档)**", "中度 (`mid` 头顶+150%)", cross_c["mid"]["templates"]["C"], False))
    lines.append(cross_row("C 炼狱 80% 养成 → **证道(5档)**", "满上限 (`cap` 头顶+300%)", cross_c["cap"]["templates"]["C"], False))
    lines.append("")
    lines.append("> **跨档门禁结论**：")
    lines.append("> 1. **无神器下，现行 35～36 层已严重偏软**：九死 4 强毕业队（B）越级打炼狱 35～36 层 **100%（16/16，均 3.4～4.3 回合）**；炼狱 80% 队（C）越级打证道 36 层战争/饥荒/瘟疫也是 **100%**，仅免暴击的死亡勇者（0/2）守住了证道门禁。")
    lines.append("> 2. **刷高头顶直接击穿证道最后一道防线**：炼狱 80% 养成队只要戴上中度刷高神器（头顶 +150%），越级打证道 36 层死亡勇者立刻从 **0% 暴涨到 100%**（全四线 8/8）；刷满上限（头顶 +300%）更是 **2.8 回合 0 阵亡闭眼速刷证道**。**现行 `crown_bonus_pct = 300` 占位值对炼狱与证道均严重超标，必须大幅下压。**")
    lines.append("")

    # Section 5: Per-seed distribution
    lines.append("## 五、主矩阵逐种子分布与统计量（无剔除，全部计入）")
    lines.append("")
    lines.append("| 模板（难度） | 种子 1（31～34层 / 35～36层 / 合计） | 种子 2（31～34层 / 35～36层 / 合计） | 3 支独立阵容合计胜率分布（min～max / 中位 / 均值 / 样本标准差） | 剔除说明 |")
    lines.append("| --- | --- | --- | --- | --- |")
    for tk in ["A", "B", "C", "D"]:
        tpl = mains[tk]["templates"][tk]
        s_strs = {}
        team_rates = []
        for sd in [1, 2]:
            c3134 = [c for f in ["31", "32", "33", "34"] for c in tpl["floors"][f]["cases"] if c["seed"] == sd]
            c3536 = [c for f in ["35", "36"] for ln in LINES for c in tpl["floors"][f]["by_line"][ln]["cases"] if c["seed"] == sd]
            w1, n1 = sum(1 for c in c3134 if c["won"]), len(c3134)
            w2, n2 = sum(1 for c in c3536 if c["won"]), len(c3536)
            s_strs[sd] = f"{w1}/{n1}({w1/n1*100:.0f}%) / {w2}/{n2}({w2/n2*100:.0f}%) / {w1+w2}/{n1+n2}({(w1+w2)/(n1+n2)*100:.1f}%)"
        for ti in range(len(tpl["teams"])):
            all_t = (
                [c for f in ["31", "32", "33", "34"] for c in tpl["floors"][f]["cases"] if c["team_idx"] == ti]
                + [c for f in ["35", "36"] for ln in LINES for c in tpl["floors"][f]["by_line"][ln]["cases"] if c["team_idx"] == ti]
            )
            team_rates.append(sum(1 for c in all_t if c["won"]) / len(all_t) * 100.0)
        mn, mx = min(team_rates), max(team_rates)
        med = statistics.median(team_rates)
        mean = statistics.mean(team_rates)
        std = statistics.stdev(team_rates) if len(team_rates) > 1 else 0.0
        lines.append(
            f"| {tk} ({tpl['difficulty']}) | {s_strs[1]} | {s_strs[2]} | "
            f"{mn:.1f}%～{mx:.1f}% / 中位 {med:.1f}% / 均值 {mean:.1f}% / SD {std:.1f}% (N=3队×24场) | 全部计入，无剔除 |"
        )
    lines.append("")

    # Section 6: Floor-by-floor & tier-by-tier diagnosis
    lines.append("## 六、逐档逐层评估结论（对照 D271 目标口径）")
    lines.append("")
    lines.append("| 难度档（D271 标尺） | 31 层女娲 | 32 层伏羲 | 33 层鸿蒙 | 34 层鸿钧 | 35 层四线影子 | 36 层四线骑士 |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- |")
    lines.append("| **1 档 寻常**（顺推混搭轻松过） | 未单测（推算偏难） | 未单测 | 适中（A 100%/8回） | 未单测（推算偏难） | 适中偏紧（A 75%，死/瘟 50%） | 适中（A 87.5%，死亡 50%） |")
    lines.append("| **2 档 艰险**（顺推混搭能过有挑战） | **严重偏难**（0%超时） | **偏难**（33%超时） | **适中**（66.7%） | **严重偏难**（0%超时） | 适中（70.8%，死/瘟偏难） | 适中（75.0%，死亡偏难） |")
    lines.append("| **3 档 九死**（4 强毕业较轻松 75～90%） | **严重偏难**（0%超时） | **严重偏难**（0%超时） | 偏简单（100%/8.2回） | **严重偏难**（16.7%超时） | **严重偏简单**（100%/1.5回秒） | **严重偏简单**（100%/2.3回秒） |")
    lines.append("| **4 档 炼狱**（2 超 2 强 80% 较轻松 75～90%） | **严重偏难**（16.7%） | **偏难**（33.3%） | **适中**（83.3%/11.3回） | **严重偏难**（0%超时） | **严重偏简单**（100%/2.5回秒） | **严重偏简单**（战/饥/瘟 2回秒；仅死亡 83%） |")
    lines.append("| **5 档 证道**（95%+ 拉满才过） | **偏难**（33.3%超时） | 偏简单（100%/12.2回） | **适中**（83.3%/5回） | **严重偏难**（0%超时） | **严重偏简单**（100%/1.8回秒） | **严重偏简单**（战/饥/瘟 1～1.5回秒；炼狱80%越级75%～100%） |")
    lines.append("")

    # Section 7: Actionable tuning proposal
    lines.append("## 七、可执行调数建议方案（只测不改数，供 Kyo 拍板）")
    lines.append("")
    lines.append("### 方案 1（P0）：打平 31～34 层守层者血量曲线，消除 31／34 层血牛回血死局")
    lines.append("- **目标文件**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/balance_table.json` → `guardian_phase4`")
    lines.append("- **建议改动**：")
    lines.append("  1. `hp_base[\"31\"]`：`1,620,000 → 380,000`（下调约 76%，解决 31 层 0% 刮痧死局）；同步将 `atk_scale[\"31\"]` 从 `0.000247` 回调至约 `0.00045`（×1.8），恢复正常生存压力。")
    lines.append("  2. `hp_base[\"32\"]`：`247,000 → 185,000`（下调约 25%，抵消 929 变身回满＋成长招导致的九死/炼狱超时）。")
    lines.append("  3. `hp_base[\"33\"]` 与 `hp_pct[\"33\"]`：**暂不动**（实测表现最健康：艰险 66.7%、炼狱 83.3%、证道 83.3%）。")
    lines.append("  4. `hp_base[\"34\"]`：`7,500,000 → 1,000,000`（下调约 87%，消除 34 层 93 倍于 33 层、36 倍于 35 层的极端血量断崖，使 34 层鸿钧在九死 1000 万／炼狱 1200 万／证道 1500 万，对标 Lv80 毕业装 8～14 回合）；同步在 `guardian_rework.gd` 将 `HONGJUN_SCALE` 从 `0.0000109` 回调至约 `0.000020`（×1.8）。")
    lines.append("")
    lines.append("### 方案 2（P0）：按 D271 毕业装输出重锚 35 层影子与 36 层四骑士血量，拉平四线差距")
    lines.append("- **目标文件**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/horsemen.json`")
    lines.append("- **建议改动**：")
    lines.append("  1. **35 层影子** `shadow.hp`：`1,670,000 → 7,000,000`（约 ×4.2，九死 1,050 万／炼狱 1,400 万／证道 1,960 万），消除 1～2 回合秒杀；死亡影子因免暴击，单独给死亡影子加 0.45 血量系数或取消影子的完全免暴击（改为暴击闪避 50%），拉平四线影子耗时至 5～9 回合。")
    lines.append("  2. **36 层四骑士本体基准血量（艰险）**：")
    lines.append("     - 战争骑士·莉co `knights.war.hp`：`2,000,000 → 13,500,000`（×6.75），使其在炼狱／证道进入火药配方 4～6 层与狂暴节奏；")
    lines.append("     - 饥荒骑士·小镇做题家 `knights.famine.hp`：`1,770,000 → 12,000,000`（×6.8），使其进入资历二／三阶段与百亿剑雨；")
    lines.append("     - 瘟疫骑士·混子 `knights.plague.hp`：`660,000 → 7,000,000`（×10.6），`hp_override.zhengdao` 从 `2,880,000` 提至 `38,000,000`（考虑混子自带减伤与嘲讽盾，血量设为莉co 约 52%～55%）；")
    lines.append("     - 死亡骑士·勇者 `knights.death.hp`：`2,220,000 → 3,800,000`（×1.7，因免暴击自带 ~4 倍有效血量，只需温和上调即可在炼狱打 11～14 回合、证道逼近第 18 回合死期狂暴线）。")
    lines.append("  3. **五档骑士血量倍率 `hp_rate` 梯度**：由现行 `0.7 / 1.0 / 1.5 / 3.0 / 5.0` 调整为 **`0.55 / 1.0 / 1.8 / 3.2 / 5.8`**（寻常更友好、九死→炼狱→证道拉开明显梯度，确保炼狱 80% 越级打证道胜率压回 ≤20%）。")
    lines.append("  4. **攻击压迫感微调**：36 层四骑士在九死～证道几乎 0 阵亡，可将 `balance_table.json` 高档 `enemy_atk`（或 `horsemen.json` 骑士基准攻）在炼狱／证道上调 15%～25%，让坦克与复活辅助在 10～16 回合决战中发挥真实价值。")
    lines.append("")
    lines.append("### 方案 3（P0）：重定成长神器 `artifact_cap` 占位值，封堵魔冠「\"头顶\"」逃逸九线封顶")
    lines.append("- **目标文件**：`03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/gear_table.json` → `artifact_cap` 及 `modes/xiyou/core/tianqi_ledger.gd`")
    lines.append("- **建议改动（需 Kyo 拍板）**：")
    lines.append("  1. **`crown_bonus_pct`：`300 → 30`（或 40～50 上限）**，并建议在 `tianqi_ledger.gd:642` `bucket_of()` 中将 `XDemonCrown.is_gear(o)` 归入 `hubris`（成长装备）桶，使其遵循九线属性总上限规则；否则只要头顶保留 +150%～+300% 裸乘八维，炼狱 80% 养成就能 100% 碾压证道，D271 证道标尺形同虚设。")
    lines.append("  2. **`heartsteel_stage`：`10 → 6`**（杰作利维坦最大生命封顶 ×1.7，心之钢 ×1.6，保留强力坦克定位而不让血量膨胀到 120 万）。")
    lines.append("  3. **`hubris_stage`：`10 → 6`**（杰作无我扬名物攻封顶 ×1.8＋27% 穿甲，与毕业七印神器处于同一强力梯队，不破坏超强者输出标定）。")
    lines.append("")
    lines.append("### 建议落地验证顺序")
    lines.append("1. 先请 Kyo 拍板上述三项调数方向（特别是 `crown_bonus_pct` 下压幅度与是否纳入九线封顶）；")
    lines.append("2. 另开改数单写入 `balance_table.json` / `horsemen.json` / `gear_table.json` 后，直接复用本单脚本 `tests/virtual_player/t438_d271_benchmark.gd` 复跑同阵容同种子，验证：九死 4 强毕业 31～36 层稳定落在 **75%～90%**、炼狱 2 超 2 强 80% 稳定落在 **75%～90%**、炼狱 80% 越级打证道 **≤20%**、证道 95%+ 拉满队 **75%～85%** 过关。")
    lines.append("")

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"WROTE {OUT_MD} ({len(lines)} lines)")


if __name__ == "__main__":
    main()
