#!/usr/bin/env python3
"""天启篇技能改写漏项扫描脚本（T524）。

扫两类候选，兜底天启篇数值止血同类漏网之鱼：
1. 改写后残留旧数值标签：
   覆盖 skill_rework.json（叠加全部启用的 tune 层）的 skills / gear / states
   以及 general_books.json 的 skills / states；
   - 列出改写后仍残留 >= min_pct（默认 50%）的旧标签（SkillPass、passiveHarmRi、
     passiveCrHarmRi、passivePBST/XPBST/SPBST、passiveELUP、passiveHarmRe、
     DepassiveHarmRe、SkETypeHarmRi、Element Amplify/Magnify、Critical Multiplier、
     CodexParamRate、ConsumeReduce、AgainUseAll、passiveAPLUS 等）；
   - 同时检查 note_add 与原版残留同名标签冲突（如 7516 ConsumeReduceZj 双标签）。
2. 经公共事件（CommonEvents）学到未改写技能：
   - 扫描全部 CommonEvents 中的 code 318 (op=0) 与脚本 learnSkill(...)；
   - 过滤不开放角色（tiers.不开放）及已在 skill_rework / general_books /
     secret_books（功法）/ trumpet 中改写的技能；
   - 从开放角色的职业学习表、skill_rework.learn 与已改写技能出发，沿未被
     effects_remove 删除的 CE 做传递闭包追踪，并单独标出地图/道具触发的专属 CE；
   - 标出每个未改写技能携带的危险旧标签、原版伤害公式及未改写强力状态。

用法：
  python3 03_再刷重制_Godot/03_转换工具/天启篇漏项扫描.py
  python3 03_再刷重制_Godot/03_转换工具/天启篇漏项扫描.py --min-pct 30 --json
  python3 03_再刷重制_Godot/03_转换工具/天启篇漏项扫描.py --strict   # 发现未豁免的 A 类残留时退出 1
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import copy
import json
from pathlib import Path
import re
import sys

HERE = Path(__file__).resolve().parent
GODOT_DIR = HERE.parent / "01_Godot工程"
DB_DIR = GODOT_DIR / "modes/xiyou/generated/db"
TQ_DIR = GODOT_DIR / "modes/xiyou/tianqi_data"

TUNE_ORDER = ("D189", "D200", "D198", "D208", "D209", "D287")

# 参与战斗数值结算的旧标签正则（用于 A 类残留检测）
COMBAT_TAG_RE = re.compile(
    r"<\s*(SkillPass\d+|passiveHarmRi|passiveCrHarmRi|passivePBST\d+|passiveXPBST\d+|"
    r"passiveSPBST\d+|passiveELUP\d+|passiveHarmRe\d+|DepassiveHarmRe\d+|"
    r"SkETypeHarmRi\d+|passiveELEM\d+|SelfElemRate|SelfPhysRate|"
    r"Element\s+Amplify\s+[^:>]+|Element\s+Magnify\s+[^:>]+|"
    r"Critical\s+Multiplier|CodexParamRate|AgainUseAll|passiveAPLUS|"
    r"passiveEXTTP|passiveIRUP|passiveGRUP|ShieldEffect|ConsumeReduce\w+)\s*:\s*([^>]+)>",
    re.I,
)
TAG_KV_RE = re.compile(r"<\s*([A-Za-z][A-Za-z0-9_ ]*?)\s*:\s*([^>]+)>")

# A 类中已人工核实的设计保留项（按 (section, id, tag_lower) 精确匹配，避免掩盖同条上的其他真漏项）
KNOWN_BENIGN_TAGS: dict[tuple[str, str, str], str] = {
    ("skills", "5986", "passiveelup05"): "卡面明确写「雷电伤害 −500%」（负值封印，设计保留）",
    ("skills", "9980", "passivexpbst0"): "卡面明确写「攻击无视敌人闪避」（命中率 +1000%，设计保留）",
}

# A 类中拿不准、待协调定口径的条目（按 (section, id, tag_regex) 精确匹配，报告中单列）
PENDING_CLASS_A: list[tuple[str, str, str, str]] = [
    ("skills", "5859", r"^SkETypeHarmRi5$", "真*太极拳：原卡面保留「用拳伤害 +50%」，待协调定是否保留或压缩"),
    ("skills", "5861", r"^SkETypeHarmRi2$", "真*太极剑：原卡面保留「用剑伤害 +50%」，待协调定是否保留或压缩"),
    ("skills", "3229", r"^passiveEXTTP$", "龙人·血脉（Boss血脉未停用）：固定最大TP+50，待核是否保留"),
    ("skills", "3232", r"^AgainUseAll$", "丧尸·血脉（Boss血脉未停用）：AgainUseAll 已被 tianqi_skills.gd again_sources() 拦截不生效"),
    ("skills", "4701", r"^AgainUseAll$", "食人魔·血脉（Boss血脉未停用）：AgainUseAll 已被 tianqi_skills.gd again_sources() 拦截不生效"),
    ("skills", "4706", r"^(?:passivePBST[35]|passiveHarmRe\d+)$", "天尊·血脉（Boss血脉未停用）：无%固定双防+100/减伤+500，待核是否清理"),
    ("skills", "4707", r"^passivePBST[67]$", "圣兽·血脉（Boss血脉未停用）：无%固定敏幸+100，待核是否清理"),
]


def classify_class_a_tag(source: str, sec: str, sid: str, tag: str) -> tuple[str, str]:
    if source != "skill_rework":
        return ("unexempted", "")
    key = (sec, str(sid), tag.lower())
    if key in KNOWN_BENIGN_TAGS:
        return ("benign", KNOWN_BENIGN_TAGS[key])
    for p_sec, p_id, pat, reason in PENDING_CLASS_A:
        if p_sec == sec and p_id == str(sid) and re.match(pat, tag, re.I):
            return ("pending", reason)
    return ("unexempted", "")


def load_table(name: str) -> dict[int, dict]:
    raw = json.loads((DB_DIR / f"{name}.json").read_text(encoding="utf-8"))
    return {int(r["id"]): r for r in raw if isinstance(r, dict) and r.get("id") is not None}


def tune_merge(base: dict, patch: dict) -> dict:
    out = copy.deepcopy(base)
    for k, v in patch.items():
        if str(k).startswith("_"):
            continue
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = tune_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def load_effective_skill_rework() -> dict:
    sr = json.loads((TQ_DIR / "skill_rework.json").read_text(encoding="utf-8"))
    eff = copy.deepcopy(sr)
    for key in TUNE_ORDER:
        tune = sr.get("tune", {}).get(key, {})
        for sec in ("skills", "actors", "gear"):
            for k, v in tune.get(sec, {}).items():
                if str(k).startswith("_"):
                    continue
                cur = eff.get(sec, {}).get(k, {})
                eff.setdefault(sec, {})[k] = tune_merge(cur if isinstance(cur, dict) else {}, v)
    return eff


def note_edit(note: str, sp: dict) -> str:
    """与 XTianqiSkills._note_edit 同口径。"""
    for tag in sp.get("note_remove", []):
        note = re.sub(r"<\s*(?:%s)\s*(?::[^>]*)?>" % str(tag), "", note)
    for pair in sp.get("note_sub", []):
        note = re.sub(str(pair[0]), str(pair[1]), note, flags=re.S)
    return note


def parse_tag_magnitude(tag: str, val: str) -> tuple[float, bool]:
    """返回 (最大绝对数值, 是否百分比或高危类型)。"""
    tl = tag.lower().strip()
    is_pct = "%" in val or "％" in val
    if tl == "codexparamrate":
        vals = []
        for part in val.split(","):
            if ":" in part:
                rhs = part.split(":", 1)[1].strip()
                if re.match(r"^[+-]?\d+(?:\.\d+)?$", rhs):
                    vals.append(abs(float(rhs)))
        return (max(vals, default=0.0), True)
    if tl == "againuseall":
        nums = [abs(float(x)) for x in re.findall(r"[+-]?\d+(?:\.\d+)?", val)]
        # AgainUseAll 即使 3%/15% 也单独标出供核实
        return (max(nums, default=0.0), True)
    nums = [abs(float(x)) for x in re.findall(r"[+-]?\d+(?:\.\d+)?", val)]
    return (max(nums, default=0.0), is_pct)


def scan_class_a(
    eff_sr: dict,
    gb: dict,
    skills: dict[int, dict],
    states: dict[int, dict],
    armors: dict[int, dict],
    weapons: dict[int, dict],
    min_pct: float = 50.0,
) -> dict:
    """扫描 A 类：改写后仍残留 >= min_pct 旧数值标签，及 note_add 同名旧标签冲突。"""
    residual_hits = []
    duplicate_hits = []

    def check_section(source: str, sec: str, entries: dict, lookup_fn):
        for k, sp in sorted(entries.items(), key=lambda x: str(x[0])):
            if not isinstance(sp, dict):
                continue
            base = lookup_fn(k)
            if not base:
                continue
            orig_note = str(base.get("note", ""))
            edited = note_edit(orig_note, sp)
            if sec == "skills" and sp.get("guard_note_remove"):
                edited = note_edit(edited, {"note_remove": sp["guard_note_remove"]})
            note_add = str(sp.get("note_add", ""))
            added_exact = {m.group(0) for m in COMBAT_TAG_RE.finditer(note_add)}

            # 1) 旧标签残留 >= min_pct（或 AgainUseAll）
            tags_hit = []
            for m in COMBAT_TAG_RE.finditer(edited):
                raw = m.group(0)
                if raw in added_exact:
                    continue
                tag, val = m.group(1), m.group(2).strip()
                mag, is_pct = parse_tag_magnitude(tag, val)
                if mag >= min_pct or tag.lower() == "againuseall":
                    st, rsn = classify_class_a_tag(source, sec, str(k), tag)
                    tags_hit.append({
                        "raw": raw,
                        "tag": tag,
                        "val": val,
                        "magnitude": mag,
                        "is_pct": is_pct,
                        "status": st,
                        "reason": rsn,
                    })
            if tags_hit:
                statuses = {t["status"] for t in tags_hit}
                if "unexempted" in statuses:
                    status = "unexempted"
                    reason = ""
                elif "pending" in statuses:
                    status = "pending"
                    reason = next(t["reason"] for t in tags_hit if t["status"] == "pending")
                else:
                    status = "benign"
                    reason = next(t["reason"] for t in tags_hit if t["status"] == "benign")
                residual_hits.append({
                    "source": source,
                    "section": sec,
                    "id": str(k),
                    "actor": sp.get("actor"),
                    "name": base.get("name") or sp.get("name", ""),
                    "kind": sp.get("kind", ""),
                    "status": status,
                    "reason": reason,
                    "tags": tags_hit,
                    "desc": sp.get("desc", []),
                })

            # 2) note_add 同名旧标签冲突（添加了新值但原版旧标签没被删）
            if note_add:
                add_keys = {m.group(1).strip().lower() for m in TAG_KV_RE.finditer(note_add)}
                surv = [
                    m.group(0)
                    for m in TAG_KV_RE.finditer(edited)
                    if m.group(1).strip().lower() in add_keys
                ]
                if surv:
                    duplicate_hits.append({
                        "source": source,
                        "section": sec,
                        "id": str(k),
                        "name": base.get("name") or sp.get("name", ""),
                        "surviving": surv,
                        "note_add": note_add,
                    })

    check_section("skill_rework", "skills", eff_sr.get("skills", {}), lambda k: skills.get(int(k)) if str(k).isdigit() else None)
    check_section(
        "skill_rework",
        "gear",
        eff_sr.get("gear", {}),
        lambda k: (armors if k.startswith("armor:") else weapons).get(int(k.split(":", 1)[1])) if ":" in k else None,
    )
    check_section("skill_rework", "states", eff_sr.get("states", {}), lambda k: states.get(int(k)) if str(k).isdigit() else None)
    check_section("general_books", "skills", gb.get("skills", {}), lambda k: skills.get(int(k)) if str(k).isdigit() else None)
    check_section("general_books", "states", gb.get("states", {}), lambda k: states.get(int(k)) if str(k).isdigit() else None)

    return {
        "min_pct": min_pct,
        "residuals": residual_hits,
        "duplicates": duplicate_hits,
    }


def scan_class_b(
    eff_sr: dict,
    gb: dict,
    sb: dict,
    trumpet: dict,
    skills: dict[int, dict],
    states: dict[int, dict],
    actors: dict[int, dict],
    classes: dict[int, dict],
    ces: dict[int, dict],
) -> dict:
    """扫描 B 类：经公共事件学到未改写技能（按角色 + CE 分组）。"""
    reworked_skills: set[int] = set()
    for k in eff_sr.get("skills", {}):
        if str(k).isdigit():
            reworked_skills.add(int(k))
    for k in gb.get("skills", {}):
        if str(k).isdigit():
            reworked_skills.add(int(k))
    for g in sb.get("gongfa", []):
        if isinstance(g, dict) and g.get("skill_id"):
            reworked_skills.add(int(g["skill_id"]))
    for s in trumpet.get("scrolls", []):
        if isinstance(s, dict) and s.get("skill_id"):
            reworked_skills.add(int(s["skill_id"]))

    reworked_states: set[int] = {
        int(k) for k in eff_sr.get("states", {}) if str(k).isdigit()
    } | {int(k) for k in gb.get("states", {}) if str(k).isdigit()}

    hidden_actors = {int(x) for x in eff_sr.get("tiers", {}).get("不开放", [])}
    open_actors: set[int] = set()
    for t, arr in eff_sr.get("tiers", {}).items():
        if t != "不开放" and isinstance(arr, list):
            open_actors.update(int(x) for x in arr)
    for sp in eff_sr.get("skills", {}).values():
        if isinstance(sp, dict) and sp.get("actor") and int(sp["actor"]) not in hidden_actors:
            open_actors.add(int(sp["actor"]))

    def active_effects(sid: int) -> list[dict]:
        sk = skills.get(sid, {})
        effs = list(sk.get("effects", []))
        sp = eff_sr.get("skills", {}).get(str(sid)) or gb.get("skills", {}).get(str(sid))
        if isinstance(sp, dict):
            rem = {(int(e[0]), int(e[1])) for e in sp.get("effects_remove", [])}
            effs = [e for e in effs if (int(e.get("code", -1)), int(e.get("dataId", -1))) not in rem]
            effs.extend(sp.get("effects_add", []))
        return effs

    def actor_base_skills(aid: int) -> set[int]:
        a = actors.get(aid, {})
        cl = classes.get(a.get("classId", 0), {})
        out = {int(l["skillId"]) for l in cl.get("learnings", [])}
        for l in eff_sr.get("learn", {}).get(str(aid), []):
            out.add(int(l[1]))
        for obj in (a, cl):
            for t in obj.get("traits", []):
                if t.get("code") == 43:
                    out.add(int(t["dataId"]))
        for k, sp in eff_sr.get("skills", {}).items():
            if str(k).isdigit() and isinstance(sp, dict) and sp.get("actor") == aid:
                out.add(int(k))
        return out

    # CE -> 哪些未删技能调用了它
    ce_active_callers: dict[int, list[int]] = defaultdict(list)
    ce_removed_callers: dict[int, list[int]] = defaultdict(list)
    for sid, sk in skills.items():
        sp = eff_sr.get("skills", {}).get(str(sid)) or gb.get("skills", {}).get(str(sid))
        rem = {(int(e[0]), int(e[1])) for e in sp.get("effects_remove", [])} if isinstance(sp, dict) else set()
        for e in sk.get("effects", []):
            if e.get("code") == 44:
                cid = int(e["dataId"])
                if (44, cid) in rem:
                    ce_removed_callers[cid].append(sid)
                else:
                    ce_active_callers[cid].append(sid)

    def summarize_skill(sid: int) -> dict:
        sk = skills.get(sid, {})
        note = str(sk.get("note", ""))
        tags = [m.group(0) for m in COMBAT_TAG_RE.finditer(note)]
        push_states = [int(m.group(1)) for m in re.finditer(r"PushState0*(\d+)", note)]
        eff_states = [int(e["dataId"]) for e in sk.get("effects", []) if e.get("code") == 21]
        st_details = []
        high_risk = False
        for stid in sorted(set(push_states + eff_states)):
            if stid <= 0:
                continue
            st = states.get(stid, {})
            in_sr = stid in reworked_states
            big_tr = [
                f"c{t['code']}d{t['dataId']}={t['value']}"
                for t in st.get("traits", [])
                if (t.get("code") == 21 and float(t.get("value", 1)) >= 1.3)
                or (t.get("code") == 22 and abs(float(t.get("value", 0))) >= 0.3)
                or t.get("code") == 61
            ]
            has_confirm = "Custom Confirm Effect" in str(st.get("note", ""))
            if not in_sr and (big_tr or has_confirm):
                high_risk = True
            st_details.append({
                "id": stid,
                "name": st.get("name", ""),
                "reworked": in_sr,
                "big_traits": big_tr,
                "custom_confirm": has_confirm,
            })
        dmg = sk.get("damage", {})
        dmg_formula = dmg.get("formula", "") if dmg.get("type", 0) in (1, 2, 5, 6) else ""
        if dmg_formula:
            high_risk = True
        for m in COMBAT_TAG_RE.finditer(note):
            mag, _ = parse_tag_magnitude(m.group(1), m.group(2))
            if mag >= 50 or m.group(1).lower() in ("againuseall", "passiveaplus"):
                high_risk = True
        return {
            "id": sid,
            "name": sk.get("name", ""),
            "stype": sk.get("stypeId", 0),
            "damage_formula": dmg_formula[:60],
            "combat_tags": tags,
            "states": st_details,
            "high_risk": high_risk,
        }

    # 按开放角色扫描 CE -> 未改写技能
    groups = []
    for aid in sorted(open_actors):
        base_sk = actor_base_skills(aid)
        for cid, ce in sorted(ces.items()):
            taught: set[int] = set()
            for cmd in ce.get("list", []):
                if cmd.get("code") == 318:
                    p = cmd.get("parameters", [])
                    if len(p) >= 4 and p[0] == 0 and p[2] == 0 and int(p[1]) == aid:
                        sid = int(p[3])
                        if sid not in reworked_skills:
                            taught.add(sid)
            if not taught:
                continue
            callers = ce_active_callers.get(cid, [])
            removed = ce_removed_callers.get(cid, [])
            if not callers and removed:
                # 仅由已被 effects_remove 删掉的技能触发，天启篇不可达
                continue
            actor_callers = [c for c in callers if c in base_sk]
            if callers and actor_callers:
                trigger_kind = "actor_active_skill"
            elif callers:
                trigger_kind = "other_skill_chain"
            else:
                trigger_kind = "map_or_item_ce"
            sk_rows = [summarize_skill(s) for s in sorted(taught)]
            any_high = any(r["high_risk"] for r in sk_rows)
            groups.append({
                "actor_id": aid,
                "actor_name": actors.get(aid, {}).get("name", ""),
                "ce_id": cid,
                "ce_name": ce.get("name", ""),
                "trigger_kind": trigger_kind,
                "active_callers": callers[:8],
                "actor_callers": actor_callers[:8],
                "high_risk": any_high,
                "taught_count": len(sk_rows),
                "taught": sk_rows,
            })

    return {
        "group_count": len(groups),
        "high_risk_groups": sum(1 for g in groups if g["high_risk"]),
        "groups": groups,
    }


def print_text_report(res_a: dict, res_b: dict) -> None:
    print(f"=== A 类扫描：改写后残留旧数值标签（阈值 >= {res_a['min_pct']:g}%）===")
    unex = [r for r in res_a["residuals"] if r["status"] == "unexempted"]
    pend = [r for r in res_a["residuals"] if r["status"] == "pending"]
    benign = [r for r in res_a["residuals"] if r["status"] == "benign"]
    print(f"合计命中 {len(res_a['residuals'])} 条：未豁免真漏项 {len(unex)}｜待协调定口径 {len(pend)}｜已核良性 {len(benign)}｜note_add 同名冲突 {len(res_a['duplicates'])}")
    if unex:
        print("\n[A-未豁免漏项]")
        for r in unex:
            tstr = ", ".join(t["raw"] for t in r["tags"][:8])
            print(f"  - {r['source']}.{r['section']}[{r['id']}] {r['name']} (actor={r['actor']}): {tstr}")
    if res_a["duplicates"]:
        print("\n[A-note_add 同名冲突]")
        for d in res_a["duplicates"]:
            print(f"  - {d['source']}.{d['section']}[{d['id']}] {d['name']}: surviving={d['surviving']} vs note_add={d['note_add']!r}")
    if pend:
        print("\n[A-拿不准/待协调定口径]")
        for r in pend:
            tstr = ", ".join(t["raw"] for t in r["tags"][:6])
            print(f"  - {r['section']}[{r['id']}] {r['name']}: {tstr} -> {r['reason']}")
    if benign:
        print("\n[A-已核良性保留]")
        for r in benign:
            tstr = ", ".join(t["raw"] for t in r["tags"][:6])
            print(f"  - {r['section']}[{r['id']}] {r['name']}: {tstr} -> {r['reason']}")

    print(f"\n=== B 类扫描：经公共事件学到未改写技能（开放角色共 {res_b['group_count']} 组，其中高危 {res_b['high_risk_groups']} 组）===")
    for g in res_b["groups"]:
        flag = "高危" if g["high_risk"] else "低危"
        print(f"  [{flag}][{g['trigger_kind']}] 角色 {g['actor_id']}({g['actor_name']}) CE {g['ce_id']}({g['ce_name']}) callers={g['actor_callers'] or g['active_callers'][:4]} -> {g['taught_count']} 招:")
        for sk in g["taught"][:6]:
            parts = []
            if sk["damage_formula"]:
                parts.append(f"公式={sk['damage_formula']}")
            if sk["combat_tags"]:
                parts.append("标签=" + ",".join(sk["combat_tags"][:4]))
            if sk["states"]:
                parts.append("状态=" + ",".join(f"{s['id']}({s['name']},sr={s['reworked']})" for s in sk["states"][:3]))
            print(f"      · {sk['id']} {sk['name']}" + (f" | {'; '.join(parts)}" if parts else ""))
        if len(g["taught"]) > 6:
            print(f"      · ... 其余 {len(g['taught']) - 6} 招")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="天启篇技能改写漏项扫描（T524）")
    ap.add_argument("--min-pct", type=float, default=50.0, help="A 类残留旧标签阈值（默认 50）")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    ap.add_argument("--strict", action="store_true", help="存在未豁免 A 类漏项或 note_add 冲突时退出码 1")
    args = ap.parse_args(argv)

    skills = load_table("Skills")
    states = load_table("States")
    armors = load_table("Armors")
    weapons = load_table("Weapons")
    actors = load_table("Actors")
    classes = load_table("Classes")
    ces = load_table("CommonEvents")

    eff_sr = load_effective_skill_rework()
    gb = json.loads((TQ_DIR / "general_books.json").read_text(encoding="utf-8"))
    sb = json.loads((TQ_DIR / "secret_books.json").read_text(encoding="utf-8"))
    tr_path = TQ_DIR / "trumpet.json"
    trumpet = json.loads(tr_path.read_text(encoding="utf-8")) if tr_path.exists() else {}

    res_a = scan_class_a(eff_sr, gb, skills, states, armors, weapons, min_pct=args.min_pct)
    res_b = scan_class_b(eff_sr, gb, sb, trumpet, skills, states, actors, classes, ces)

    if args.json:
        print(json.dumps({"class_a": res_a, "class_b": res_b}, ensure_ascii=False, indent=2))
    else:
        print_text_report(res_a, res_b)

    if args.strict:
        unex = [r for r in res_a["residuals"] if r["status"] == "unexempted"]
        if unex or res_a["duplicates"]:
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
