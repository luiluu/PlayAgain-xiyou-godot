#!/usr/bin/env python3
"""天启篇技能改写漏项扫描脚本（T524／T541）。

扫三类候选，兜底天启篇数值止血同类漏网之鱼：
1. A 类——改写后残留旧数值标签：
   覆盖 skill_rework.json（叠加全部启用的 tune 层）的 skills / gear / states
   以及 general_books.json 的 skills / states；
   - 列出改写后仍残留 >= min_pct（默认 50%）的旧标签（SkillPass、passiveHarmRi、
     passiveCrHarmRi、passivePBST/XPBST/SPBST、passiveELUP、passiveHarmRe、
     DepassiveHarmRe、SkETypeHarmRi、Element Amplify/Magnify、Critical Multiplier、
     CodexParamRate、ConsumeReduce、AgainUseAll、passiveAPLUS 等）；
   - 同时检查 note_add 与原版残留同名标签冲突（如 7516 ConsumeReduceZj 双标签）。
2. B 类——经公共事件（CommonEvents）学到未改写技能：
   - 学习来源：CommonEvents 里的 318「学会」（固定角色／全队／变量指定角色）与脚本 learnSkill(…)；
     脚本按括号配平取参数（可套多层括号，注释里的不算）；参数是变量／表达式的尽量还原（常量、$dataSkills[N]、
     按备注标签 filter），变量被重赋值／复合赋值／自增／循环改过就不还原，还原不了或调用写法解析不了都列人工核对；
   - 过滤不开放角色（tiers.不开放）及已在 skill_rework / general_books /
     secret_books.skills（功法）/ trumpet.scrolls[].skill（号卷）中改写的技能；
   - 可达性：未删技能与物品的 code 44、公共事件 117 与脚本 reserveCommonEvent、地图与敌群事件、
     状态／物品／装备备注里的 reserveCommonEvent、自动／并行触发作根，沿公共事件调用传递（技能效果与运行时同序：先 effects_remove 再 effects_add）；
     只有能证实「调用方全是天启篇删掉的技能、或已判删掉的公共事件」才略过，略过的列在 dropped 里；
     父事件找不到调用、调用成环的标「入口未证实」（parent_unconfirmed）人工核对，绝不静默判 dropped；
     只要有变量形式的公共事件调用（117／reserveCommonEvent 调用号追不到），一个都不判删掉，改标 dynamic_call_possible；
   - 目标角色追不到的（318 全队／变量、脚本没写死单个角色号、写死号旁边还有别的取角色方式）进 manual；
   - 标出每个未改写技能携带的危险旧标签、原版伤害公式及未改写强力状态；
     已由别的天启篇模块接管的技能（KNOWN_HANDLED_SKILLS）只标注、不算高危。
3. C 类（T541）——装备赋予／触发的未改写技能：
   - 覆盖 Weapons / Armors 经 5 条运行期通道带出的技能：
     特性 code 43（Add Skill）、<ShareLearnSkill:N>、<Replace Attack: N>／<Attack Replace: N>、
     <Weapon Unleash X%: N>、<Magic Weapon Learn Skill N: …>；
   - 按 XTianqiSkills.gear_view 同序先叠加 skill_rework.gear 的 traits_remove／traits_set 与 note_remove／note_sub／note_add：
     被 skill_rework.gear 明确移除且未再加回、或 <req_actors> 全部落在 tiers.不开放 的条目显式列进 dropped（不静默丢）；
   - 标签值不是纯技能号（表达式、技能名、缺参）、未知 *LearnSkill*／*AddSkill* 标签、或 <req_actors> 无法解析的，一律进 manual 人工核对，不静默判 dropped。

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
MAP_DIR = GODOT_DIR / "modes/xiyou/generated/maps"
TQ_DIR = GODOT_DIR / "modes/xiyou/tianqi_data"

TUNE_ORDER = ("D189", "D200", "D198", "D208", "D209", "D287")

# 参与战斗数值结算的旧标签正则（用于 A 类残留检测）
COMBAT_TAG_RE = re.compile(
    r"<\s*(SkillPass\d+|passiveHarmRi|passiveCrHarmRi|passivePBST\d+|passiveXPBST\d+|"
    r"passiveSPBST\d+|passiveELUP\d+|passiveHarmRe\d+|DepassiveHarmRe\d+|"
    r"SkETypeHarmRi\d+|passiveELEM\d+|SelfElemRate|SelfPhysRate|"
    r"Element\s+Amplify\s+[^:>]+|Element\s+Magnify\s+[^:>]+|"
    r"Critical\s+Multiplier|CodexParamRate|AgainUseAll|passiveAPLUS|"
    r"passiveEXTTP|passiveIRUP|passiveGRUP|ShieldEffect|ConsumeReduce\w+|passiveATKST\d+)\s*:\s*([^>]+)>",
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


# C 类豁免登记（T549）：技能号 → 理由。未改写又没登记的，--strict 退出码 1
# 登记在 天启篇漏项扫描_C类登记.json（skills：技能号→理由；manual：[{gear, raw, reason}]）
_C_REG = json.loads((HERE / "天启篇漏项扫描_C类登记.json").read_text(encoding="utf-8"))
CLASS_C_EXEMPT: dict[int, str] = {int(k): str(v) for k, v in _C_REG.get("skills", {}).items()}
# C 类人工核对条目豁免：(来源, 原文) → 理由
CLASS_C_MANUAL_EXEMPT: dict[tuple[str, str], str] = {(m["gear"], m["raw"]): m["reason"] for m in _C_REG.get("manual", [])}


def classify_class_a_tag(source: str, sec: str, sid: str, tag: str, reworked_states: set[int] | None = None) -> tuple[str, str]:
    if source != "skill_rework":
        return ("unexempted", "")
    m_atk = re.match(r"^passiveATKST0*(\d+)$", tag, re.I)
    if m_atk and reworked_states is not None and int(m_atk.group(1)) in reworked_states:
        # 攻击附加状态的「付与率」不是增伤；附加的状态已在 skill_rework.states 改写，按改写后的状态生效，设计保留
        return ("benign", f"攻击附加状态 {int(m_atk.group(1))} 的付与率；该状态已在 skill_rework.states 改写（设计保留）")
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


def load_maps() -> dict[int, dict]:
    out: dict[int, dict] = {}
    for f in sorted(MAP_DIR.glob("Map[0-9][0-9][0-9]*.json")):
        try:
            out[int(f.stem[3:])] = json.loads(f.read_text(encoding="utf-8"))
        except (ValueError, json.JSONDecodeError) as exc:
            print(f"！地图读不了，跳过：{f.name}（{exc}）", file=sys.stderr)
    return out


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
    reworked_states = {int(k) for k in eff_sr.get("states", {}) if str(k).isdigit()}

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
                    st, rsn = classify_class_a_tag(source, sec, str(k), tag, reworked_states)
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


# B/C 类：已由天启篇别的模块接管（不走 skill_rework）的技能，人工核过；只标注、不算高危
KNOWN_HANDLED_SKILLS: dict[int, str] = {
    6168: "XTianqiNoDiffPassive：天启篇不学（拦在 XActor.learn_skill），净效果改读 balance_table.legacy_passive",
    6178: "XTianqiSect：挣脱枷锁三个被动天启篇只留抽奖被动上限 +1",
    6179: "XTianqiSect：挣脱枷锁三个被动天启篇只留抽奖被动上限 +1",
    6180: "XTianqiSect：挣脱枷锁三个被动天启篇只留抽奖被动上限 +1",
    7510: "XMagicWeapon.TIANQI_SKIP_LEARN_SKILL：天启篇停用 3550 烽舞按等级领悟（T523）",
    7511: "XMagicWeapon.TIANQI_SKIP_LEARN_SKILL：天启篇停用 3550 烽舞按等级领悟（T523）",
    7512: "XMagicWeapon.TIANQI_SKIP_LEARN_SKILL：天启篇停用 3550 烽舞按等级领悟（T523）",
    7513: "XMagicWeapon.TIANQI_SKIP_LEARN_SKILL：天启篇停用 3550 烽舞按等级领悟（T523）",
}


def _reworked_skill_ids(eff_sr: dict, gb: dict, sb: dict, trumpet: dict) -> set[int]:
    out: set[int] = set()
    for k in eff_sr.get("skills", {}):
        if str(k).isdigit():
            out.add(int(k))
    for k in gb.get("skills", {}):
        if str(k).isdigit():
            out.add(int(k))
    for k, g in (sb.get("skills", {}) or {}).items():
        if str(k).isdigit():
            out.add(int(k))
        if isinstance(g, dict) and g.get("skill"):
            out.add(int(g["skill"]))
    for s in trumpet.get("scrolls", []) or []:
        if isinstance(s, dict) and s.get("skill"):
            out.add(int(s["skill"]))
    return out


def _reworked_state_ids(eff_sr: dict, gb: dict) -> set[int]:
    return {
        int(k) for k in eff_sr.get("states", {}) if str(k).isdigit()
    } | {int(k) for k in gb.get("states", {}) if str(k).isdigit()}


def _summarize_skill(
    sid: int | None,
    skills: dict[int, dict],
    states: dict[int, dict],
    reworked_states: set[int],
    expr: str = "",
) -> dict:
    if sid is None:
        return {
            "id": None,
            "handled_by": "",
            "name": f"动态技能号 learnSkill({expr})，追不到",
            "dynamic_expr": expr,
            "stype": 0,
            "damage_formula": "",
            "combat_tags": [],
            "states": [],
            "high_risk": True,
        }
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
    handled_by = KNOWN_HANDLED_SKILLS.get(sid, "")
    if handled_by:
        high_risk = False
    return {
        "id": sid,
        "dynamic_expr": expr,
        "handled_by": handled_by,
        "name": sk.get("name", ""),
        "stype": sk.get("stypeId", 0),
        "damage_formula": dmg_formula[:60],
        "combat_tags": tags,
        "states": st_details,
        "high_risk": high_risk,
    }

SCRIPT_ACTOR_RE = re.compile(r"\$gameActors\.actor\(\s*(\d+)\s*\)")
LEARN_TOKEN_RE = re.compile(r"(?<![\w$])learnSkill(?![\w$])")
# 脚本里「目标角色不止一个写死号」的迹象：非字面 actor()、队伍／战斗对象、循环。出现任何一个都不归给块内唯一字面角色号
SCRIPT_DYNAMIC_ACTOR_RE = re.compile(
    r"\$gameActors\.actor\(\s*(?!\d+\s*\))|\$gameParty\b|\$gameTroop\b|BattleManager\b|\$gameActors\._data|"
    r"\.forEach\b|\bfor\s*\(|\bwhile\s*\("
)
RESERVE_CE_RE = re.compile(r"reserveCommonEvent\(\s*(\d+)\s*\)")
FOR_TOKEN_RE = re.compile(r"(?<![\w$.])for(?![\w$])")
RESERVE_ANY_RE = re.compile(r"(?<![\w$])reserveCommonEvent(?![\w$])")


def _strip_js_comments(script: str) -> str:
    """去掉 // 与 /* */ 注释（引号里的不动），注释里提到 learnSkill／reserveCommonEvent 不算调用。"""
    out, i, quote, n = [], 0, "", len(script)
    while i < n:
        ch = script[i]
        if quote:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(script[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = ""
        elif ch in "'\"`":
            quote = ch
            out.append(ch)
        elif script.startswith("//", i):
            j = script.find("\n", i)
            i = n if j < 0 else j
            continue
        elif script.startswith("/*", i):
            j = script.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def _call_args(script: str, token_re: re.Pattern) -> list[tuple[str | None, str]]:
    """找出脚本里每一处 token(…) 调用，按括号配平取整段参数（参数可以套多层括号）。
    token 后面不是「(」、或括号配不平的，返回 (None, 片段)，调用方一律进人工核对，不静默丢。"""
    out: list[tuple[str | None, str]] = []
    for m in token_re.finditer(script):
        snippet = script[m.start(): m.start() + 80].split("\n", 1)[0]
        i = m.end()
        while i < len(script) and script[i] in " \t":
            i += 1
        if i >= len(script) or script[i] != "(":
            out.append((None, snippet))
            continue
        depth, j, quote = 0, i, ""
        while j < len(script):
            ch = script[j]
            if quote:
                if ch == "\\":
                    j += 2
                    continue
                if ch == quote:
                    quote = ""
            elif ch in "'\"`":
                quote = ch
            elif ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if depth != 0 or j >= len(script):
            out.append((None, snippet))
        else:
            out.append((script[i + 1: j].strip(), snippet))
    return out


def _name_rebound(name: str, script: str) -> bool:
    """变量除了一次普通赋值以外还被改过：复合赋值、++/--、for 头、函数参数、解构。改过就不能按那一次赋值还原。"""
    n = re.escape(name)
    pats = (
        r"(?<![\w$.])%s\s*(?:\*\*|>>>|<<|>>|&&|\|\||\?\?|[-+*/%%&|^])=" % n,
        r"(?<![\w$.])%s\s*(?:\+\+|--)" % n,
        r"(?:\+\+|--)\s*%s(?![\w$])" % n,
        r"\bfunction\b[^(]*\([^)]*(?<![\w$.])%s(?![\w$])[^)]*\)" % n,
        r"(?<![\w$.])%s\s*=>" % n,
        r"[\[{][^\]};]*(?<![\w$.])%s(?![\w$])[^\]};]*[\]}]\s*=(?![=>])" % n,
    )
    if any(re.search(p, script) for p in pats):
        return True
    # for 头按括号配平取整段（头里可以有函数调用），名字出现在头里就算改过
    for head, _ in _call_args(script, FOR_TOKEN_RE):
        if head is None or re.search(r"(?<![\w$.])%s(?![\w$])" % n, head):
            return True
    return False


def _script_blocks(cmds: list) -> list[str]:
    """把 355＋655 续行拼成一段脚本。"""
    blocks: list[list[str]] = []
    cur: list[str] | None = None
    for c in cmds:
        code = c.get("code")
        if code == 355:
            cur = [str((c.get("parameters") or [""])[0])]
            blocks.append(cur)
        elif code == 655 and cur is not None:
            cur.append(str((c.get("parameters") or [""])[0]))
        else:
            cur = None
    return [_strip_js_comments("\n".join(b)) for b in blocks]


def _resolve_script_skill(expr: str, script: str, skills: dict[int, dict]) -> int | None:
    """learnSkill 参数不是字面号时尽量还原：常量变量、$dataSkills[N]、按备注标签 filter 出来的技能。还原不了返回 None。"""
    expr = expr.strip()
    if expr.isdecimal():
        return int(expr)
    m = re.fullmatch(r"\$dataSkills\[\s*(\d+)\s*\](?:\.id)?", expr)
    if m:
        return int(m.group(1))
    m = re.fullmatch(r"([A-Za-z_$][\w$]*)(\.id)?", expr)
    if not m:
        return None
    name, dot_id = m.group(1), bool(m.group(2))
    if _name_rebound(name, script):
        return None
    if dot_id:
        # var hh = $dataSkills.filter(function(s){return s&&/<Tag>/.test(s.note);})[0]; … learnSkill(hh.id)
        if len(re.findall(r"(?<![\w$.])%s\s*=(?![=>])" % re.escape(name), script)) != 1:
            return None  # 重赋值过：filter 那一次不一定是最终值
        mf = re.findall(
            r"(?<![\w$.])%s\s*=(?!=)\s*\$dataSkills\.filter\(.*?/(<[^/]+>)/\.test\(\s*\w+\.note\s*\).*?\)\s*\[\s*0\s*\]" % re.escape(name),
            script,
            re.S,
        )
        if len(mf) == 1:
            hits = sorted(sid for sid, sk in skills.items() if mf[0] in str(sk.get("note", "")))
            return hits[0] if hits else None
    if _name_rebound(name, script):
        return None  # 被复合赋值／自增／循环／参数／解构改过：追不到
    assigns = re.findall(r"(?<![\w$.])%s\s*=(?![=>])\s*([^;\n]+)" % re.escape(name), script)
    if len(assigns) != 1:
        return None  # 没赋值或多次赋值：追不到
    rhs = assigns[0].strip()
    if not dot_id and rhs.isdecimal():
        return int(rhs)
    if dot_id:
        m2 = re.fullmatch(r"\$dataSkills\[\s*(\d+)\s*\]", rhs)
        if m2:
            return int(m2.group(1))
    return None


def _ce_refs_in_script(script: str, dynamic: list[str] | None = None) -> set[int]:
    """脚本里 reserveCommonEvent(…)：参数是字面号的收进来；是变量／表达式的记进 dynamic（调到哪个追不到）。"""
    out: set[int] = set()
    # 备注不是纯脚本（夹着说明文字，单引号可能不成对），这里不去注释：注释里的调用宁可多算成根
    for arg, snippet in _call_args(script, RESERVE_ANY_RE):
        if arg is not None and arg.isdecimal():
            out.add(int(arg))
        elif dynamic is not None:
            dynamic.append(snippet)
    return out


def _ce_refs_in_cmds(cmds: list, dynamic: list[str] | None = None) -> set[int]:
    """事件指令里调到的公共事件：117 直接调用＋脚本 reserveCommonEvent(N)。调用号追不到的记进 dynamic。"""
    out: set[int] = set()
    for c in cmds:
        if c.get("code") == 117:
            p = c.get("parameters") or []
            if p and re.fullmatch(r"\s*\d+\s*", str(p[0])):
                out.add(int(p[0]))
            elif dynamic is not None:
                dynamic.append(f"117 {p[:1]}")
    for s in _script_blocks(cmds):
        out |= _ce_refs_in_script(s, dynamic)
    return out


def _event_pages_cmds(maps: dict, troops: dict):
    """(来源标记, 指令列表)：地图事件各页、敌群各页。"""
    for mid, m in (maps or {}).items():
        for ev in (m or {}).get("events", []) or []:
            if not isinstance(ev, dict):
                continue
            for pi, pg in enumerate(ev.get("pages", []) or []):
                yield (f"map{mid}:ev{ev.get('id')}", pg.get("list", []) or [])
    for tid, t in (troops or {}).items():
        for pg in (t or {}).get("pages", []) or []:
            yield (f"troop{tid}", pg.get("list", []) or [])


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
    items: dict[int, dict] | None = None,
    troops: dict[int, dict] | None = None,
    maps: dict[int, dict] | None = None,
    note_tables: dict[str, dict[int, dict]] | None = None,
) -> dict:
    """扫描 B 类：经公共事件学到、未改写的技能。

    学习来源：318（固定角色／全队／变量指定角色）与脚本 learnSkill(N)。
    可达性：技能／物品 code 44、公共事件 117 与脚本 reserveCommonEvent、地图与敌群事件、自动／并行触发；
    沿 117 传递。只有「全部调用方都是天启篇已 effects_remove 掉的技能、且没有任何别的调用」才判不可达、略过，
    略过的也列在 dropped 里，不静默丢。目标角色追不到的（全队、变量、脚本没写死角色）进 manual 人工核对清单。
    """
    items = items or {}
    reworked_skills = _reworked_skill_ids(eff_sr, gb, sb, trumpet)
    reworked_states = _reworked_state_ids(eff_sr, gb)

    hidden_actors = {int(x) for x in eff_sr.get("tiers", {}).get("不开放", [])}
    open_actors: set[int] = set()
    for t, arr in eff_sr.get("tiers", {}).items():
        if t != "不开放" and isinstance(arr, list):
            open_actors.update(int(x) for x in arr)
    for sp in eff_sr.get("skills", {}).values():
        if isinstance(sp, dict) and sp.get("actor") and int(sp["actor"]) not in hidden_actors:
            open_actors.add(int(sp["actor"]))

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

    # ---- 调用图 ----
    skill_active_callers: dict[int, list[int]] = defaultdict(list)
    skill_removed_callers: dict[int, list[int]] = defaultdict(list)
    dynamic_ce_calls: list[str] = []  # 调用号是变量／表达式的公共事件调用：调到哪个追不到
    for sid, sk in skills.items():
        sp = eff_sr.get("skills", {}).get(str(sid)) or gb.get("skills", {}).get(str(sid))
        rem = {(int(e[0]), int(e[1])) for e in sp.get("effects_remove", [])} if isinstance(sp, dict) else set()
        # 与 XTianqiSkills 同序：先按 effects_remove 删原版效果，再追加 effects_add（先删后加同一公共事件＝仍可达）
        active_effs = [e for e in sk.get("effects", []) if (int(e.get("code", -1)), int(e.get("dataId", -1))) not in rem]
        if isinstance(sp, dict):
            active_effs += list(sp.get("effects_add", []))
        active_ids = {int(e["dataId"]) for e in active_effs if e.get("code") == 44}
        for cid in sorted(active_ids):
            skill_active_callers[cid].append(sid)
        for e in sk.get("effects", []):
            if e.get("code") == 44 and int(e["dataId"]) not in active_ids and (44, int(e["dataId"])) in rem:
                skill_removed_callers[int(e["dataId"])].append(sid)
        dyn: list[str] = []
        for cid in _ce_refs_in_script(str(sk.get("note", "")), dyn):
            skill_active_callers[int(cid)].append(sid)
        dynamic_ce_calls.extend(f"skill{sid}: {d}" for d in dyn)
    item_callers: dict[int, list[int]] = defaultdict(list)
    for iid, it in items.items():
        for e in it.get("effects", []) or []:
            if e.get("code") == 44:
                item_callers[int(e["dataId"])].append(iid)
    # 状态／物品／装备备注里的 reserveCommonEvent（YEP 自定义效果脚本）：按根算，宁可多列不漏
    note_callers: dict[int, list[str]] = defaultdict(list)
    for tname, table in {"state": states, "item": items, **(note_tables or {})}.items():
        for rid, row in (table or {}).items():
            dyn = []
            for ref in _ce_refs_in_script(str((row or {}).get("note", "")), dyn):
                note_callers[ref].append(f"{tname}{rid}")
            dynamic_ce_calls.extend(f"{tname}{rid}: {d}" for d in dyn)
    ce_callers: dict[int, set[int]] = defaultdict(set)  # 被谁（公共事件）调
    for cid, ce in ces.items():
        dyn = []
        for ref in _ce_refs_in_cmds(ce.get("list", []) or [], dyn):
            ce_callers[ref].add(cid)
        dynamic_ce_calls.extend(f"CE{cid}: {d}" for d in dyn)
    event_callers: dict[int, list[str]] = defaultdict(list)  # 地图／敌群事件
    for tag, cmds in _event_pages_cmds(maps, troops):
        dyn = []
        for ref in _ce_refs_in_cmds(cmds, dyn):
            event_callers[ref].append(tag)
        dynamic_ce_calls.extend(f"{tag}: {d}" for d in dyn)
    maps_scanned = bool(maps)

    # 可达：从根（未删技能、物品、状态／装备备注、地图／敌群事件、自动／并行触发）出发沿 CE→CE 传递
    roots = set(skill_active_callers) | set(item_callers) | set(note_callers) | set(event_callers)
    roots |= {cid for cid, ce in ces.items() if int(ce.get("trigger", 0) or 0) != 0}
    children: dict[int, set[int]] = defaultdict(set)
    for callee, callers in ce_callers.items():
        for c in callers:
            children[c].add(callee)
    reachable: set[int] = set()
    stack = [c for c in roots if c in ces]
    while stack:
        c = stack.pop()
        if c in reachable:
            continue
        reachable.add(c)
        stack.extend(children.get(c, ()))

    # 判「删掉」只认能证实的：调用方要么是天启篇删掉的技能，要么是本身已判删掉的公共事件（不动点）。
    # 父事件找不到调用、调用成环没有外部入口的，都不算证实，进「入口未证实」人工核对，不判 dropped。
    dropped_ces: set[int] = set()
    changed = True
    while changed:
        changed = False
        for cid in ces:
            if cid in reachable or cid in dropped_ces:
                continue
            ce_cs = ce_callers.get(cid, set())
            if not (skill_removed_callers.get(cid) or ce_cs):
                continue
            if all(c in dropped_ces for c in ce_cs):
                dropped_ces.add(cid)
                changed = True
    # 有变量形式的调用（调到哪个追不到）时，任何公共事件都可能被它调到：一个都不能证实删掉，全部改标人工核对
    dynamic_suspect: set[int] = set()
    if dynamic_ce_calls:
        dynamic_suspect, dropped_ces = dropped_ces, set()

    def reach_kind(cid: int) -> str:
        if cid in reachable:
            return "reachable"
        if cid in dropped_ces:
            return "dropped"
        if cid in dynamic_suspect:
            return "dynamic_call_possible"  # 已知调用方全删了，但有变量形式的调用可能调到它：人工核对
        if skill_removed_callers.get(cid) or ce_callers.get(cid):
            return "parent_unconfirmed"  # 有调用方，但上游追到「没找到调用」或成环：入口未证实，人工核对
        return "no_caller_found"  # 一处调用都没找到：可能是插件／脚本里拼出来的调用，进人工核对

    def trigger_info(cid: int, base_sk: set[int] | None) -> dict:
        callers = skill_active_callers.get(cid, [])
        actor_callers = [c for c in callers if base_sk and c in base_sk]
        if actor_callers:
            kind = "actor_active_skill"
        elif callers:
            kind = "other_skill_chain"
        elif item_callers.get(cid):
            kind = "item"
        elif note_callers.get(cid):
            kind = "note_script"
        elif event_callers.get(cid):
            kind = "map_or_troop_event"
        elif ce_callers.get(cid):
            kind = "via_common_event"
        elif int(ces.get(cid, {}).get("trigger", 0) or 0) != 0:
            kind = "auto_or_parallel"
        elif skill_removed_callers.get(cid):
            kind = "removed_skill_only"
        else:
            kind = "no_caller_found"
        return {
            "trigger_kind": kind,
            "reach": reach_kind(cid),
            "active_callers": callers[:8],
            "actor_callers": actor_callers[:8],
            "item_callers": item_callers.get(cid, [])[:8],
            "note_callers": note_callers.get(cid, [])[:8],
            "event_callers": event_callers.get(cid, [])[:6],
            "ce_callers": sorted(ce_callers.get(cid, set()))[:8],
            "removed_callers": skill_removed_callers.get(cid, [])[:8],
        }

    def summarize_skill(sid: int | None, expr: str = "") -> dict:
        return _summarize_skill(sid, skills, states, reworked_states, expr)

    # ---- 每个公共事件里学到的技能，按目标分：固定角色／追不到 ----
    # taught_fixed[cid][aid] = {sid}；taught_unresolved[cid] = [(how, sid)]
    taught_fixed: dict[int, dict[int, set[int]]] = defaultdict(lambda: defaultdict(set))
    taught_unresolved: dict[int, list[tuple[str, int | None, str]]] = defaultdict(list)
    for cid, ce in ces.items():
        cmds = ce.get("list", []) or []
        for cmd in cmds:
            if cmd.get("code") != 318:
                continue
            p = cmd.get("parameters", [])
            if len(p) < 4 or int(p[2]) != 0:
                continue  # 只看「学会」，遗忘不算
            sid = int(p[3])
            if sid in reworked_skills:
                continue
            if int(p[0]) == 0 and int(p[1]) > 0:
                taught_fixed[cid][int(p[1])].add(sid)
            elif int(p[0]) == 0:
                taught_unresolved[cid].append(("318 全队", sid, ""))
            else:
                taught_unresolved[cid].append((f"318 变量{p[1]} 指定角色", sid, ""))
        for s in _script_blocks(cmds):
            calls = _call_args(s, LEARN_TOKEN_RE)
            if not calls:
                continue
            exprs = []
            for arg, snippet in calls:
                if arg is None:
                    # learnSkill 后面不是正常调用（括号配不平、call/apply、取函数引用…）：整段列人工核对
                    taught_unresolved[cid].append(("脚本 learnSkill（调用写法解析不了）", None, snippet))
                else:
                    exprs.append(arg)
            fixed = sorted({int(x) for x in SCRIPT_ACTOR_RE.findall(s)})
            # 只有「块内唯一一个写死角色号、且没有任何别的取角色方式」才归给该角色；混合目标一律人工核对
            single_actor = fixed[0] if len(fixed) == 1 and not SCRIPT_DYNAMIC_ACTOR_RE.search(s) else None
            for expr in exprs:
                sid = _resolve_script_skill(expr, s, skills)
                if sid is not None and sid in reworked_skills:
                    continue
                if sid is None:
                    taught_unresolved[cid].append(("脚本 learnSkill（技能号是变量／表达式，追不到）", None, expr))
                elif not expr.isdecimal():
                    how = "脚本 learnSkill（技能号由变量还原）" + ("" if single_actor is None else f"｜角色 {single_actor}")
                    taught_unresolved[cid].append((how, sid, expr))
                elif single_actor is not None:
                    taught_fixed[cid][single_actor].add(sid)
                else:
                    taught_unresolved[cid].append(("脚本 learnSkill（目标角色不是写死的单个号）", sid, ""))

    groups = []
    dropped = []
    base_cache: dict[int, set[int]] = {}
    for cid in sorted(taught_fixed):
        for aid in sorted(taught_fixed[cid]):
            if aid in hidden_actors or aid not in open_actors:
                continue
            if aid not in base_cache:
                base_cache[aid] = actor_base_skills(aid)
            info = trigger_info(cid, base_cache[aid])
            sk_rows = [summarize_skill(s) for s in sorted(taught_fixed[cid][aid])]
            row = {
                "actor_id": aid,
                "actor_name": actors.get(aid, {}).get("name", ""),
                "ce_id": cid,
                "ce_name": ces[cid].get("name", ""),
                **info,
                "high_risk": any(r["high_risk"] for r in sk_rows),
                "taught_count": len(sk_rows),
                "taught": sk_rows,
            }
            (dropped if info["reach"] == "dropped" else groups).append(row)

    manual = []
    for cid in sorted(taught_unresolved):
        info = trigger_info(cid, None)
        by_how: dict[str, set[tuple[int, str]]] = defaultdict(set)
        for how, sid, expr in taught_unresolved[cid]:
            by_how[how].add((-1 if sid is None else sid, expr))
        for how, pairs in sorted(by_how.items()):
            sk_rows = [summarize_skill(None if s < 0 else s, e) for s, e in sorted(pairs)]
            manual.append({
                "ce_id": cid,
                "ce_name": ces[cid].get("name", ""),
                "target": how,
                **info,
                "high_risk": any(r["high_risk"] for r in sk_rows),
                "taught_count": len(sk_rows),
                "taught": sk_rows,
            })
    # 一处调用都没找到、或上游入口未证实的固定角色组也进人工核对（可能由插件／拼接脚本调用）
    no_caller = [g for g in groups if g["reach"] in ("no_caller_found", "parent_unconfirmed", "dynamic_call_possible")]

    return {
        "group_count": len(groups),
        "high_risk_groups": sum(1 for g in groups if g["high_risk"]),
        "groups": groups,
        "manual_count": len(manual),
        "manual_high_risk": sum(1 for m in manual if m["high_risk"]),
        "manual": manual,
        "no_caller_groups": len(no_caller),
        "no_caller": [(g["actor_id"], g["ce_id"], g["reach"]) for g in no_caller],
        "dropped_count": len(dropped),
        "dropped": dropped,
        "maps_scanned": maps_scanned,
        "dynamic_ce_calls": dynamic_ce_calls,
    }


# ---- C 类（T541）：装备赋予／触发的未改写技能 ----
GEAR_SHARE_LEARN_RE = re.compile(r"<\s*ShareLearnSkill\b(?:\s*:\s*([^>]*))?>", re.I)
GEAR_REPLACE_ATTACK_RE = re.compile(r"<\s*(?:ATTACK\s+REPLACE|REPLACE\s+ATTACK)\b(?:\s*:\s*([^>]*))?>", re.I)
GEAR_WEAPON_UNLEASH_RE = re.compile(r"<\s*WEAPON\s+UNLEASH\b([^>]*)>", re.I)
GEAR_WEAPON_UNLEASH_OK_RE = re.compile(r"^\s+\d+\s*[%％]\s*:\s*(\d+)\s*$")
GEAR_WEAPON_UNLEASH_RATE_RE = re.compile(r"^\s*:\s*[+-]?\d+(?:\.\d+)?\s*[%％]\s*$")
GEAR_MW_LEARN_RE = re.compile(r"<\s*Magic\s+Weapon\s+Learn\s+Skill\b([^>]*)>", re.I)
GEAR_MW_LEARN_OK_RE = re.compile(r"^\s+(\d+)\s*:\s*\S")
GEAR_UNKNOWN_LEARN_RE = re.compile(r"<\s*(?:learningSkill\w*|LearnSkill\w*|AddSkill\w*)\b(?:\s*:\s*([^>]*))?>", re.I)
GEAR_REQ_ACTORS_RE = re.compile(r"<\s*req_actors\s*:\s*([^>]*)>", re.I)


def _apply_gear_spec(row: dict, sp: dict | None) -> tuple[list[dict], str]:
    """与 XTianqiSkills.gear_view 同序：note_remove/note_sub + note_add；traits_remove + traits_set。"""
    traits = [dict(t) for t in (row.get("traits", []) or []) if isinstance(t, dict)]
    note = str(row.get("note", ""))
    if not isinstance(sp, dict):
        return traits, note
    note = note_edit(note, sp) + str(sp.get("note_add", ""))
    rem = {(int(e[0]), int(e[1])) for e in sp.get("traits_remove", [])}
    if rem:
        traits = [t for t in traits if (int(t.get("code", -1)), int(t.get("dataId", -1))) not in rem]
    for e in sp.get("traits_set", []):
        if not isinstance(e, dict):
            continue
        code, did, val = int(e.get("code", -1)), int(e.get("dataId", -1)), float(e.get("value", 0))
        hit = False
        for t in traits:
            if int(t.get("code", -1)) == code and int(t.get("dataId", -1)) == did:
                t["value"] = val
                hit = True
        if not hit:
            traits.append({"code": code, "dataId": did, "value": val})
    return traits, note


def _extract_gear_skill_grants(traits: list[dict], note: str) -> tuple[list[tuple[str, int, str]], list[tuple[str, str, str]]]:
    """返回 (resolved[(channel, sid, raw)], manual[(channel, raw, reason)])。解析不了的一律进 manual，不静默丢。"""
    resolved: list[tuple[str, int, str]] = []
    manual: list[tuple[str, str, str]] = []

    for t in traits:
        if int(t.get("code", -1)) != 43:
            continue
        raw_id = t.get("dataId")
        if isinstance(raw_id, int) and not isinstance(raw_id, bool) and raw_id > 0:
            resolved.append(("trait_43", raw_id, f"trait 43:{raw_id}"))
        elif raw_id not in (None, 0):
            manual.append(("trait_43", repr(t), "特性 43 dataId 非正整数，追不到"))

    for m in GEAR_SHARE_LEARN_RE.finditer(note):
        val = (m.group(1) or "").strip()
        if val.isdecimal() and int(val) > 0:
            resolved.append(("share_learn", int(val), m.group(0)))
        else:
            manual.append(("share_learn", m.group(0), "ShareLearnSkill 参数非纯技能号，追不到"))

    for m in GEAR_REPLACE_ATTACK_RE.finditer(note):
        val = (m.group(1) or "").strip()
        if val.isdecimal() and int(val) > 0:
            resolved.append(("replace_attack", int(val), m.group(0)))
        else:
            manual.append(("replace_attack", m.group(0), "Replace Attack 参数非纯技能号，追不到"))

    for m in GEAR_WEAPON_UNLEASH_RE.finditer(note):
        body = m.group(1)
        if GEAR_WEAPON_UNLEASH_RATE_RE.match(body):
            continue  # <Weapon Unleash: +10%> 是触发几率加成，不是技能号
        m_ok = GEAR_WEAPON_UNLEASH_OK_RE.match(body)
        if m_ok and int(m_ok.group(1)) > 0:
            resolved.append(("weapon_unleash", int(m_ok.group(1)), m.group(0)))
        else:
            manual.append(("weapon_unleash", m.group(0), "Weapon Unleash 参数非纯技能号，追不到"))

    for m in GEAR_MW_LEARN_RE.finditer(note):
        body = m.group(1)
        m_ok = GEAR_MW_LEARN_OK_RE.match(body)
        if m_ok and int(m_ok.group(1)) > 0:
            resolved.append(("magic_weapon_learn", int(m_ok.group(1)), m.group(0)))
        else:
            manual.append(("magic_weapon_learn", m.group(0), "Magic Weapon Learn Skill 参数解析不了，追不到"))

    for m in GEAR_UNKNOWN_LEARN_RE.finditer(note):
        manual.append(("unknown_learn_tag", m.group(0), "未知技能学习标签，人工核对"))

    return resolved, manual


def scan_class_c(
    eff_sr: dict,
    gb: dict,
    sb: dict,
    trumpet: dict,
    skills: dict[int, dict],
    states: dict[int, dict],
    weapons: dict[int, dict],
    armors: dict[int, dict],
    suits: dict[int, dict] | None = None,
    suit_templates: dict | None = None,
) -> dict:
    """扫描 C 类（T541）：装备（Weapons / Armors）经 5 条通道赋予或触发的未改写技能。

    通道：trait_43（特性 43）、share_learn（<ShareLearnSkill>）、replace_attack（<Replace Attack>）、
    weapon_unleash（<Weapon Unleash X%>）、magic_weapon_learn（<Magic Weapon Learn Skill>）。
    先按 XTianqiSkills.gear_view 口径叠加 eff_sr.gear；明确移除或仅不开放角色可用的列在 dropped，
    解析不了的标签／<req_actors> 一律进 manual，不静默判 dropped。
    """
    reworked_skills = _reworked_skill_ids(eff_sr, gb, sb, trumpet)
    reworked_states = _reworked_state_ids(eff_sr, gb)
    hidden_actors = {int(x) for x in eff_sr.get("tiers", {}).get("不开放", [])}
    gear_specs = eff_sr.get("gear", {})

    by_skill: dict[int, list[dict]] = defaultdict(list)
    manual: list[dict] = []
    dropped: list[dict] = []

    for gtype, tbl in (("weapon", weapons), ("armor", armors)):
        for gid in sorted(tbl):
            row = tbl[gid]
            if not isinstance(row, dict):
                continue
            gkey = f"{gtype}:{gid}"
            gname = str(row.get("name", ""))
            sp = gear_specs.get(gkey)

            raw_grants, _ = _extract_gear_skill_grants(
                [dict(t) for t in (row.get("traits", []) or []) if isinstance(t, dict)],
                str(row.get("note", "")),
            )
            eff_traits, eff_note = _apply_gear_spec(row, sp)
            eff_grants, eff_manual = _extract_gear_skill_grants(eff_traits, eff_note)

            # 解析 <req_actors: ...>：全部是不开放角色才判 hidden_actor_only；解析不了绝不静默丢，记进 manual
            req_matches = GEAR_REQ_ACTORS_RE.findall(eff_note)
            hidden_only = False
            req_unparseable = False
            if req_matches:
                toks = [t for p in req_matches for t in re.split(r"[\s,，]+", p.strip()) if t]
                if toks and all(t.isdecimal() and int(t) > 0 for t in toks):
                    hidden_only = all(int(t) in hidden_actors for t in toks)
                else:
                    req_unparseable = True

            eff_pairs = {(ch, sid) for ch, sid, _ in eff_grants}
            for ch, sid, raw in raw_grants:
                if (ch, sid) not in eff_pairs and sid not in reworked_skills:
                    sk_info = _summarize_skill(sid, skills, states, reworked_states)
                    dropped.append({
                        "gear": gkey,
                        "gear_name": gname,
                        "channel": ch,
                        "raw": raw,
                        "reason": "removed_by_skill_rework_gear",
                        "skill": sk_info,
                    })

            seen_eff: set[tuple[str, int]] = set()
            has_unreworked_eff = False
            for ch, sid, raw in eff_grants:
                if (ch, sid) in seen_eff:
                    continue
                seen_eff.add((ch, sid))
                if sid in reworked_skills:
                    continue
                has_unreworked_eff = True
                if hidden_only:
                    sk_info = _summarize_skill(sid, skills, states, reworked_states)
                    dropped.append({
                        "gear": gkey,
                        "gear_name": gname,
                        "channel": ch,
                        "raw": raw,
                        "reason": "hidden_actor_only",
                        "skill": sk_info,
                    })
                else:
                    by_skill[sid].append({
                        "gear": gkey,
                        "gear_name": gname,
                        "channel": ch,
                        "raw": raw,
                    })

            for ch, raw, reason in eff_manual:
                manual.append({
                    "gear": gkey,
                    "gear_name": gname,
                    "channel": ch,
                    "raw": raw,
                    "reason": reason,
                    "high_risk": True,
                })
            if req_unparseable and (has_unreworked_eff or eff_manual):
                manual.append({
                    "gear": gkey,
                    "gear_name": gname,
                    "channel": "req_actors",
                    "raw": "; ".join(f"<req_actors:{m}>" for m in req_matches),
                    "reason": "req_actors 含非角色号，未判不开放，人工核对",
                    "high_risk": True,
                })

    # 第 6 通道（T549，T541 核 P2-3）：套装给技能（actor.gd native_skill_ids → XEquipSuits.ids(self, "skills")）。
    # 天启篇有原版套装模板（suit_template.json suits）的套装只留 1 件档（XTianqiSuits.bonuses_of），多件档的 skills 记 dropped
    tpl_ids = {str(k) for k in (suit_templates or {}).get("suits", {})}
    for suit_id in sorted(suits or {}):
        srow = (suits or {})[suit_id]
        if not isinstance(srow, dict):
            continue
        sname = str(srow.get("name", ""))
        for b in srow.get("bonuses", []) or []:
            n = int(b.get("requirePieces", 0) or 0)
            for sid in b.get("skills", []) or []:
                if not isinstance(sid, int) or sid <= 0:
                    manual.append({"gear": f"suit:{suit_id}", "gear_name": sname, "channel": "suit_skill",
                                   "raw": repr(sid), "reason": "套装 skills 不是正整数技能号，追不到", "high_risk": True})
                    continue
                if sid in reworked_skills:
                    continue
                raw = f"套装{suit_id}（{n}件）skills:{sid}"
                if str(suit_id) in tpl_ids and n > 1:
                    dropped.append({"gear": f"suit:{suit_id}", "gear_name": sname, "channel": "suit_skill", "raw": raw,
                                    "reason": "suit_template_replaced",
                                    "skill": _summarize_skill(sid, skills, states, reworked_states)})
                    continue
                by_skill[sid].append({"gear": f"suit:{suit_id}", "gear_name": sname, "channel": "suit_skill", "raw": raw})

    items: list[dict] = []
    for sid in sorted(by_skill):
        sk_info = _summarize_skill(sid, skills, states, reworked_states)
        sources = sorted(by_skill[sid], key=lambda x: (x["gear"], x["channel"]))
        items.append({
            **sk_info,
            "sources": sources,
            "source_count": len(sources),
            "channels": sorted({s["channel"] for s in sources}),
            "exempt": CLASS_C_EXEMPT.get(sid, ""),
        })
    for m in manual:
        m["exempt"] = CLASS_C_MANUAL_EXEMPT.get((m["gear"], m["raw"]), "")

    return {
        "skill_count": len(items),
        "high_risk_count": sum(1 for it in items if it["high_risk"]),
        "unexempted_count": sum(1 for it in items if not it["exempt"]) + sum(1 for m in manual if not m["exempt"]),
        "items": items,
        "manual_count": len(manual),
        "manual": manual,
        "dropped_count": len(dropped),
        "dropped": dropped,
    }


def print_text_report(res_a: dict, res_b: dict, res_c: dict | None = None) -> None:
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
    if not res_b.get("maps_scanned", True):
        print("  ！地图事件没读到：只靠技能／物品／公共事件／敌群判可达，地图调用的公共事件会落进「没找到调用」")

    if res_b.get("dynamic_ce_calls"):
        print(f"  ！有 {len(res_b['dynamic_ce_calls'])} 处变量形式的公共事件调用（调到哪个追不到），本轮不判任何公共事件删掉：" + "；".join(res_b["dynamic_ce_calls"][:6]))
    if res_b.get("no_caller"):
        print(f"  ！其中入口没证实（没找到调用／父事件没找到调用）{res_b['no_caller_groups']} 组，要人工核对：" + "、".join(f"角色{a} CE{c}({r})" for a, c, r in res_b["no_caller"]))

    def _print_group(g: dict, head: str) -> None:
        flag = "高危" if g["high_risk"] else "低危"
        who = g["actor_callers"] or g["active_callers"][:4] or g["item_callers"][:4] or g["event_callers"][:3] or g["ce_callers"][:4]
        print(f"  [{flag}][{g['trigger_kind']}|{g['reach']}] {head} CE {g['ce_id']}({g['ce_name']}) 调用={who} -> {g['taught_count']} 招:")
        for sk in g["taught"][:6]:
            parts = []
            if sk["damage_formula"]:
                parts.append(f"公式={sk['damage_formula']}")
            if sk["combat_tags"]:
                parts.append("标签=" + ",".join(sk["combat_tags"][:4]))
            if sk["states"]:
                parts.append("状态=" + ",".join(f"{s['id']}({s['name']},sr={s['reworked']})" for s in sk["states"][:3]))
            if sk.get("handled_by"):
                parts.insert(0, "已接管=" + sk["handled_by"])
            if sk.get("dynamic_expr") and sk["id"] is not None:
                parts.insert(0, f"由 learnSkill({sk['dynamic_expr']}) 还原")
            print(f"      · {'?' if sk['id'] is None else sk['id']} {sk['name']}" + (f" | {'; '.join(parts)}" if parts else ""))
        if len(g["taught"]) > 6:
            print(f"      · ... 其余 {len(g['taught']) - 6} 招")

    for g in res_b["groups"]:
        _print_group(g, f"角色 {g['actor_id']}({g['actor_name']})")
    print(f"\n=== B 类人工核对：目标角色或技能号追不到（全队／变量／脚本）{res_b['manual_count']} 组，其中高危 {res_b['manual_high_risk']} 组 ===")
    for m in res_b["manual"]:
        _print_group(m, f"[{m['target']}]")
    print(f"\n=== B 类判不可达而略过：{res_b['dropped_count']} 组（已知调用方全是天启篇删掉的技能或不可达的公共事件）===")
    for g in res_b["dropped"]:
        print(f"  - 角色 {g['actor_id']}({g['actor_name']}) CE {g['ce_id']}({g['ce_name']}) 删掉的调用={g['removed_callers']} 公共事件调用={g['ce_callers']} -> {g['taught_count']} 招")

    if res_c is not None:
        print(f"\n=== C 类扫描：装备赋予／触发的未改写技能（共 {res_c['skill_count']} 招，其中高危 {res_c['high_risk_count']} 招；未登记豁免 {res_c.get('unexempted_count', 0)} 条）===")
        for it in res_c["items"]:
            flag = "高危" if it["high_risk"] else "低危"
            srcs = "、".join(f"{s['gear']}({s['gear_name']}|{s['channel']})" for s in it["sources"][:4])
            if it["source_count"] > 4:
                srcs += f" 等{it['source_count']}件"
            parts = []
            if it.get("handled_by"):
                parts.append("已接管=" + it["handled_by"])
            if it["damage_formula"]:
                parts.append(f"公式={it['damage_formula']}")
            if it["combat_tags"]:
                parts.append("标签=" + ",".join(it["combat_tags"][:4]))
            if it["states"]:
                parts.append("状态=" + ",".join(f"{s['id']}({s['name']},sr={s['reworked']})" for s in it["states"][:3]))
            if it.get("exempt"):
                parts.append("豁免=" + it["exempt"])
            print(f"  [{flag}] {it['id']} {it['name']} 来源={srcs}" + (f" | {'; '.join(parts)}" if parts else ""))
        print(f"\n=== C 类人工核对：装备技能标签追不到 {res_c['manual_count']} 条 ===")
        for m in res_c["manual"]:
            print(f"  - {m['gear']}({m['gear_name']}) [{m['channel']}] {m['raw']} -> {m['reason']}" + (f"｜豁免={m['exempt']}" if m.get("exempt") else ""))
        print(f"\n=== C 类显式略过（gear 改写已移除、仅不开放角色可用或天启篇套装模板替换的多件档）：{res_c['dropped_count']} 条 ===")
        for d in res_c["dropped"]:
            print(f"  - {d['gear']}({d['gear_name']}) [{d['channel']}|{d['reason']}] -> {d['skill']['id']} {d['skill']['name']}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="天启篇技能改写漏项扫描（T524／T541）")
    ap.add_argument("--min-pct", type=float, default=50.0, help="A 类残留旧标签阈值（默认 50）")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    ap.add_argument("--strict", action="store_true", help="存在未豁免 A 类漏项、note_add 冲突或未登记的 C 类漏项时退出码 1")
    args = ap.parse_args(argv)

    skills = load_table("Skills")
    states = load_table("States")
    armors = load_table("Armors")
    weapons = load_table("Weapons")
    actors = load_table("Actors")
    classes = load_table("Classes")
    ces = load_table("CommonEvents")
    items = load_table("Items")
    troops = load_table("Troops")
    maps = load_maps()

    eff_sr = load_effective_skill_rework()
    gb = json.loads((TQ_DIR / "general_books.json").read_text(encoding="utf-8"))
    sb = json.loads((TQ_DIR / "secret_books.json").read_text(encoding="utf-8"))
    tr_path = TQ_DIR / "trumpet.json"
    trumpet = json.loads(tr_path.read_text(encoding="utf-8")) if tr_path.exists() else {}

    res_a = scan_class_a(eff_sr, gb, skills, states, armors, weapons, min_pct=args.min_pct)
    res_b = scan_class_b(
        eff_sr, gb, sb, trumpet, skills, states, actors, classes, ces, items, troops, maps,
        note_tables={"armor": armors, "weapon": weapons},
    )
    suits = load_table("EquipSuits")
    suit_tpl = json.loads((TQ_DIR / "suit_template.json").read_text(encoding="utf-8"))
    res_c = scan_class_c(eff_sr, gb, sb, trumpet, skills, states, weapons, armors, suits, suit_tpl)

    if args.json:
        print(json.dumps({"class_a": res_a, "class_b": res_b, "class_c": res_c}, ensure_ascii=False, indent=2))
    else:
        print_text_report(res_a, res_b, res_c)

    if args.strict:
        unex = [r for r in res_a["residuals"] if r["status"] == "unexempted"]
        if unex or res_a["duplicates"]:
            return 1
        if res_c["unexempted_count"]:  # T549：C 类未改写又没登记豁免理由的也拦
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
