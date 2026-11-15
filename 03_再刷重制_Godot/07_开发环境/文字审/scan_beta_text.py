#!/usr/bin/env python3
"""只读扫描《再刷一把：天启篇》乙类数据（批 21～128）。

严格只读 `modes/xiyou/generated/db/*.json`、`modes/xiyou/generated/maps/*.json`
及 `modes/xiyou/tianqi_data/skill_rework.json`，不修改任何游戏数据文件。
结果归档至同目录 `scan_results_by_batch.json` 与 `scan_summary.md`。
"""

from __future__ import annotations

import argparse
import collections
import glob
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[3]
GODOT_DIR = REPO_ROOT / "03_再刷重制_Godot/01_Godot工程/modes/xiyou"
GEN_DIR = GODOT_DIR / "generated"
DB_DIR = GEN_DIR / "db"
MAPS_DIR = GEN_DIR / "maps"
OUT_DIR = Path(__file__).resolve().parent

POS_RE = re.compile(
    r"<pos=([^\s>]+)\s+text=(.+?)\s+size=([^\s>]+)\s+color=([^\s>]+)\s+line=(true|false)\s+align=(0|1|2)>",
    re.I,
)
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
PURE_DIGITS_RE = re.compile(r"^\d+$")

# 乱码 / 替换符 / 明显占位
GARBLED_RE = re.compile(r"[\ufffd\u25a1\u25a0]|\?\?\?|？{3,}|◆小明")
CTRL_CHAR_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\ufeff\u200b-\u200f]")

# HTML 实体与常见 HTML 标签
HTML_RE = re.compile(
    r"&(?:nbsp|lt|gt|amp|quot|apos|#\d+|#x[0-9a-fA-F]+);|</?(?:br|p|div|span|font|b|i|u|strong|em)\b[^>]*>",
    re.I,
)

## MV 控制符（XMVText 与 message_box 支持的转义）
VALID_ESC_WITH_ARG = {"c", "C", "i", "I", "n", "N", "v", "V", "p", "P", "fs", "FS", "px", "PX", "py", "PY", "af", "AF"}
VALID_ESC_NO_ARG = {"g", "G", "{", "}", ".", "|", "!", ">", "<", "^", "$", "\\"}
ANY_ESC_RE = re.compile(r"(\\+)([A-Za-z]+|\{|\}|\.|\||!|>|<|\^|\$)?(\[[^\]]*\])?")
UNCLOSED_ESC_RE = re.compile(r"\\(?:c|C|i|I|n|N|v|V|p|P|fs|FS|px|PX|py|PY|af|AF)\[[^\]]*$")
NAMEBOX_TAG_RE = re.compile(r"\\(?:n|N|nc|NC|nr|NR)<[^>]*>")

# 中文语境下半角标点混用（汉字间夹半角 , ; ? !）
HALF_PUNCT_BETWEEN_CJK_RE = re.compile(r"[\u4e00-\u9fff][,;?!][\u4e00-\u9fff]")

# 空串 / 占位（如「效果:」后为空、待定、TODO、测试）
EMPTY_LABEL_RE = re.compile(r"(?:^|\n)(?:\\+[cC]\[\d+\])?(?:效果|特效|说明|限制|来源|触发|条件|消耗|冷却|备注)\s*[:：]\s*$")
PLACEHOLDER_RE = re.compile(
    r"(?:待定|待办|待补充|见待办|TODO|FIXME|TBD|未命名|占位|测试技能|测试物品|测试装备|测试状态|暂时无用|废弃不用)",
    re.I,
)

# 极少数虽在 GB2312 中但现代简体不作正字使用的繁体字
EXTRA_TRAD_CHARS = set("後餘裏準藉")


def find_trad_chars(text: str) -> list[str]:
    out = set()
    for ch in text:
        if "\u4e00" <= ch <= "\u9fff":
            if ch in EXTRA_TRAD_CHARS:
                out.add(ch)
            else:
                try:
                    ch.encode("gb2312")
                except UnicodeEncodeError:
                    out.add(ch)
    return sorted(out)


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def check_escapes(text: str, allow_rich: bool) -> list[tuple[str, str]]:
    """检查 MV 控制符残留与括号不配对。"""
    issues: list[tuple[str, str]] = []
    # 若允许富文本，先剥离合法的 YEP_MessageCore 名字框标签 \n<...> / \nc<...> / \nr<...>
    cleaned = NAMEBOX_TAG_RE.sub("", text) if allow_rich else text

    if UNCLOSED_ESC_RE.search(cleaned):
        issues.append(("mv_ctrl_unclosed", "控制符方括号未闭合"))

    for m in ANY_ESC_RE.finditer(cleaned):
        slashes, code, arg = m.group(1), m.group(2) or "", m.group(3) or ""
        token = slashes + code + arg
        if not code and not arg:
            continue
        if len(slashes) >= 2:
            issues.append(("mv_ctrl_double_slash", f"疑似双反斜杠控制符: {token}"))
            continue
        if not allow_rich:
            issues.append(("mv_ctrl_in_plain", f"纯文本字段含转义符: {token}"))
        else:
            if code in VALID_ESC_WITH_ARG:
                if not arg:
                    issues.append(("mv_ctrl_missing_arg", f"控制符缺少[参数]: {token}"))
                elif arg == "[]":
                    issues.append(("mv_ctrl_empty_arg", f"控制符参数为空: {token}"))
            elif code in VALID_ESC_NO_ARG:
                pass
            elif code == "evalText":
                pass
            elif code:
                issues.append(("mv_ctrl_unknown", f"XMVText未处理的控制符: {token}"))
    return issues


def check_brackets(text: str) -> list[tuple[str, str]]:
    """检查中文/英文括号、引号不成对或全半角混搭。"""
    issues: list[tuple[str, str]] = []
    # 剔除 \n<...> 名字框与 \evalText<<...>> 中的内容以免干扰
    cleaned = NAMEBOX_TAG_RE.sub("", text)
    pairs = [("（", "）"), ("(", ")"), ("【", "】"), ("「", "」"), ("『", "』"), ("‘", "’"), ("“", "”")]
    for left, right in pairs:
        lc = cleaned.count(left)
        rc = cleaned.count(right)
        if lc != rc:
            if left == "(" and rc - lc == 1 and re.match(r"^\s*[0-9A-Za-z]\)", cleaned):
                continue
            issues.append(("bracket_mismatch", f"括号/引号不成对 {left}{right} ({lc} vs {rc})"))
    if re.search(r"（[^（）()]*\)|\([^（）()]*）", cleaned):
        issues.append(("bracket_half_full_mix", "全角/半角括号混搭"))
    return issues


def analyze_text(text: str, allow_rich: bool, check_empty_name: bool = False) -> list[dict[str, str]]:
    """返回命中问题列表: [{type, detail}]。"""
    hits: list[dict[str, str]] = []
    if not text:
        return hits

    if GARBLED_RE.search(text):
        hits.append({"type": "garbled", "detail": "含乱码/替换符/???/◆小明占位"})
    if CTRL_CHAR_RE.search(text):
        hits.append({"type": "ctrl_char", "detail": "含不可见控制字符"})
    if HTML_RE.search(text):
        hits.append({"type": "html_entity", "detail": "含HTML实体或标签"})

    for typ, msg in check_escapes(text, allow_rich=allow_rich):
        hits.append({"type": typ, "detail": msg})

    for typ, msg in check_brackets(text):
        hits.append({"type": typ, "detail": msg})

    if HALF_PUNCT_BETWEEN_CJK_RE.search(text):
        hits.append({"type": "punct_mix", "detail": "汉字间夹半角标点(,;?!) "})

    if EMPTY_LABEL_RE.search(text):
        hits.append({"type": "empty_placeholder", "detail": "标签冒号后为空"})
    if PLACEHOLDER_RE.search(text):
        hits.append({"type": "empty_placeholder", "detail": "含待定/TODO/测试/废弃占位词"})
    if check_empty_name and PURE_DIGITS_RE.match(text.strip()):
        hits.append({"type": "empty_placeholder", "detail": "纯数字名称"})

    trad_found = find_trad_chars(text)
    if trad_found:
        hits.append({"type": "trad_simp_mix", "detail": f"含非常用/繁体字: {''.join(trad_found[:12])}"})

    return hits


def extract_pos_lines(note: str) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    if not note:
        return out
    for idx, line in enumerate(note.splitlines(), 1):
        m = POS_RE.search(line)
        if m:
            txt = m.group(2)
            if "DreamX_bonus" in txt:
                continue
            out.append((idx, txt))
    return out


def split_into_batches(items: list[dict[str, Any]], start_batch: int, count: int) -> None:
    """按段数均匀切分 items 到 [start_batch, start_batch + count)。"""
    if not items:
        return
    # 按 entity_key 聚合以保证同一条目/同一地图不跨批拆分
    groups: list[list[dict[str, Any]]] = []
    cur_key = None
    cur_group: list[dict[str, Any]] = []
    for it in items:
        k = it.get("group_key", it["loc"])
        if k != cur_key and cur_group:
            groups.append(cur_group)
            cur_group = []
        cur_key = k
        cur_group.append(it)
    if cur_group:
        groups.append(cur_group)

    total = len(items)
    target = total / count
    batch_idx = 0
    acc = 0
    for gi, grp in enumerate(groups):
        if batch_idx < count - 1:
            # 如果加上下一组后超出太多，且当前批已有内容，且剩余组足够后面的批次，则切到下一批
            remaining_groups = len(groups) - gi
            remaining_batches = count - batch_idx
            if acc > 0 and acc + len(grp) * 0.5 > target and remaining_groups >= remaining_batches:
                batch_idx += 1
                acc = 0
        bnum = start_batch + batch_idx
        for it in grp:
            it["batch"] = bnum
        acc += len(grp)


def collect_all() -> tuple[list[dict[str, Any]], dict[int, list[int]]]:
    records: list[dict[str, Any]] = []

    def add(loc: str, field: str, text: str, allow_rich: bool, group_key: str,
            batch: int | None = None, is_name: bool = False, extra: dict[str, Any] | None = None) -> None:
        if not isinstance(text, str) or text.strip() == "":
            return
        rec = {
            "loc": loc,
            "field": field,
            "text": text,
            "allow_rich": allow_rich,
            "group_key": group_key,
            "is_name": is_name,
        }
        if batch is not None:
            rec["batch"] = batch
        if extra:
            rec.update(extra)
        records.append(rec)

    # ---------- 批 21～23：乙-01 ----------
    sys_d = load_json(DB_DIR / "System.json")
    for key in ("gameTitle", "currencyUnit"):
        add(f"System.json:{key}", key, sys_d.get(key, ""), False, "System", batch=21)
    for arr_key in ("elements", "equipTypes", "skillTypes", "weaponTypes", "armorTypes"):
        for idx, val in enumerate(sys_d.get(arr_key, [])):
            add(f"System.json:{arr_key}[{idx}]", arr_key, val or "", False, f"System.{arr_key}", batch=21, is_name=True)
    terms = sys_d.get("terms", {})
    for arr_key in ("basic", "commands", "params"):
        for idx, val in enumerate(terms.get(arr_key, [])):
            add(f"System.json:terms.{arr_key}[{idx}]", f"terms.{arr_key}", val or "", False, f"System.terms.{arr_key}", batch=21)
    for k, val in terms.get("messages", {}).items():
        add(f"System.json:terms.messages.{k}", "terms.messages", val or "", True, "System.terms.messages", batch=21)

    uq = load_json(DB_DIR / "UnifiedQuality.json")
    for idx, val in enumerate(uq.get("names", [])):
        add(f"UnifiedQuality.json:names[{idx}]", "names", val or "", False, "UnifiedQuality", batch=21)
    for k, val in uq.get("gearTags", {}).items():
        add(f"UnifiedQuality.json:gearTags.{k}", "gearTags", val or "", False, "UnifiedQuality", batch=21)

    cde = load_json(DB_DIR / "CodexDamageElements.json")
    for idx, val in enumerate(cde.get("names", [])):
        add(f"CodexDamageElements.json:names[{idx}]", "names", val or "", False, "CodexDamageElements", batch=21)

    cr = load_json(DB_DIR / "CodexRaces.json")
    for idx, val in enumerate(cr.get("names", [])):
        add(f"CodexRaces.json:names[{idx}]", "names", val or "", False, "CodexRaces", batch=21)

    co = load_json(DB_DIR / "CodexOrbs.json")
    for idx, val in enumerate(co.get("tiers", [])):
        add(f"CodexOrbs.json:tiers[{idx}]", "tiers", val or "", False, "CodexOrbs", batch=21)
    for fi, fam in enumerate(co.get("families", [])):
        add(f"CodexOrbs.json:families[{fi}].name", "name", fam.get("name", ""), False, "CodexOrbs", batch=21)
        add(f"CodexOrbs.json:families[{fi}].role", "role", fam.get("role", ""), False, "CodexOrbs", batch=21)
        add(f"CodexOrbs.json:families[{fi}].slot", "slot", fam.get("slot", ""), False, "CodexOrbs", batch=21)
        for li, line in enumerate(fam.get("lines", [])):
            if isinstance(line, list) and len(line) >= 3:
                add(f"CodexOrbs.json:families[{fi}].lines[{li}][2]", "line", str(line[2]), False, "CodexOrbs", batch=21)

    # CodexMerchants 里若有文本字段也一并扫入批 21
    cm = load_json(DB_DIR / "CodexMerchants.json")
    def walk_strings(obj: Any, prefix: str, bnum: int) -> None:
        if isinstance(obj, str) and CJK_RE.search(obj):
            add(prefix, "text", obj, True, prefix.split(":")[0], batch=bnum)
        elif isinstance(obj, list):
            for idx, v in enumerate(obj):
                walk_strings(v, f"{prefix}[{idx}]", bnum)
        elif isinstance(obj, dict):
            for k, v in obj.items():
                walk_strings(v, f"{prefix}.{k}", bnum)
    walk_strings(cm, "CodexMerchants.json", 21)

    pc = load_json(DB_DIR / "PlayerChangelog.json")
    for ei, ent in enumerate(pc.get("entries", [])):
        ver = ent.get("version", "")
        add(f"PlayerChangelog.json:entries[{ei}].version", "version", ver, False, "PlayerChangelog", batch=21)
        for pi, pg in enumerate(ent.get("pages", [])):
            add(f"PlayerChangelog.json:entries[{ei}].pages[{pi}]", "pages", pg, True, "PlayerChangelog", batch=21)

    # 批 22：EquipSuits + Runewords
    for row in load_json(DB_DIR / "EquipSuits.json"):
        if not row:
            continue
        add(f"EquipSuits.json:{row['id']}/name", "name", row.get("name", ""), False, f"EquipSuits:{row['id']}", batch=22, is_name=True)
    for row in load_json(DB_DIR / "Runewords.json"):
        if not row:
            continue
        add(f"Runewords.json:{row['id']}/name", "name", row.get("name", ""), False, f"Runewords:{row['id']}", batch=22, is_name=True)

    # 批 23：MapInfos
    for row in load_json(DB_DIR / "MapInfos.json"):
        if not row:
            continue
        add(f"MapInfos.json:{row['id']}/name", "name", row.get("name", ""), False, f"MapInfos:{row['id']}", batch=23, is_name=True)

    # ---------- 批 24～26：乙-02（Actors, Classes, Enemies） ----------
    for row in load_json(DB_DIR / "Actors.json"):
        if not row:
            continue
        for k in ("name", "nickname", "profile"):
            add(f"Actors.json:{row['id']}/{k}", k, row.get(k, ""), False, f"Actors:{row['id']}", batch=24, is_name=(k == "name"))
    for row in load_json(DB_DIR / "Classes.json"):
        if not row:
            continue
        add(f"Classes.json:{row['id']}/name", "name", row.get("name", ""), False, f"Classes:{row['id']}", batch=24, is_name=True)

    enemies_recs: list[dict[str, Any]] = []
    for row in load_json(DB_DIR / "Enemies.json"):
        if not row:
            continue
        name = row.get("name", "")
        if isinstance(name, str) and name.strip():
            enemies_recs.append({
                "loc": f"Enemies.json:{row['id']}/name",
                "field": "name",
                "text": name,
                "allow_rich": False,
                "group_key": f"Enemies:{row['id']}",
                "is_name": True,
            })
    split_into_batches(enemies_recs, 25, 2)
    records.extend(enemies_recs)

    # ---------- 批 27～30：乙-03（States） ----------
    state_recs: list[dict[str, Any]] = []
    for row in load_json(DB_DIR / "States.json"):
        if not row:
            continue
        for k in ("name", "description", "message1", "message2", "message3", "message4"):
            val = row.get(k, "")
            if isinstance(val, str) and val.strip():
                state_recs.append({
                    "loc": f"States.json:{row['id']}/{k}",
                    "field": k,
                    "text": val,
                    "allow_rich": (k != "name"),
                    "group_key": f"States:{row['id']}",
                    "is_name": (k == "name"),
                })
    split_into_batches(state_recs, 27, 4)
    records.extend(state_recs)

    # ---------- 批 31～43：乙-04（Weapons 31..34, Armors 35..43） ----------
    for fn, b_start, b_cnt in [("Weapons.json", 31, 4), ("Armors.json", 35, 9)]:
        sub: list[dict[str, Any]] = []
        for row in load_json(DB_DIR / fn):
            if not row:
                continue
            for k in ("name", "description"):
                val = row.get(k, "")
                if isinstance(val, str) and val.strip():
                    sub.append({
                        "loc": f"{fn}:{row['id']}/{k}",
                        "field": k,
                        "text": val,
                        "allow_rich": (k != "name"),
                        "group_key": f"{fn}:{row['id']}",
                        "is_name": (k == "name"),
                    })
            for ln, txt in extract_pos_lines(row.get("note", "")):
                sub.append({
                    "loc": f"{fn}:{row['id']}/note#{ln}",
                    "field": "note.pos",
                    "text": txt,
                    "allow_rich": True,
                    "group_key": f"{fn}:{row['id']}",
                    "is_name": False,
                })
        split_into_batches(sub, b_start, b_cnt)
        records.extend(sub)

    # ---------- 批 44～52：乙-05（Items） ----------
    item_recs: list[dict[str, Any]] = []
    for row in load_json(DB_DIR / "Items.json"):
        if not row:
            continue
        for k in ("name", "description"):
            val = row.get(k, "")
            if isinstance(val, str) and val.strip():
                item_recs.append({
                    "loc": f"Items.json:{row['id']}/{k}",
                    "field": k,
                    "text": val,
                    "allow_rich": (k != "name"),
                    "group_key": f"Items:{row['id']}",
                    "is_name": (k == "name"),
                })
        for ln, txt in extract_pos_lines(row.get("note", "")):
            item_recs.append({
                "loc": f"Items.json:{row['id']}/note#{ln}",
                "field": "note.pos",
                "text": txt,
                "allow_rich": True,
                "group_key": f"Items:{row['id']}",
                "is_name": False,
            })
    split_into_batches(item_recs, 44, 9)
    records.extend(item_recs)

    # ---------- 批 53～88：乙-06（Skills） ----------
    sr = load_json(GODOT_DIR / "tianqi_data/skill_rework.json")
    rework_skill_ids = {int(k) for k in sr.get("skills", {}).keys()}

    skill_recs: list[dict[str, Any]] = []
    for row in load_json(DB_DIR / "Skills.json"):
        if not row:
            continue
        sid = int(row["id"])
        reworked = sid in rework_skill_ids
        for k in ("name", "description", "message1", "message2"):
            val = row.get(k, "")
            if isinstance(val, str) and val.strip():
                skill_recs.append({
                    "loc": f"Skills.json:{sid}/{k}",
                    "field": k,
                    "text": val,
                    "allow_rich": (k != "name"),
                    "group_key": f"Skills:{sid}",
                    "is_name": (k == "name"),
                    "skill_id": sid,
                    "tianqi_reworked": reworked,
                })
        for ln, txt in extract_pos_lines(row.get("note", "")):
            skill_recs.append({
                "loc": f"Skills.json:{sid}/note#{ln}",
                "field": "note.pos",
                "text": txt,
                "allow_rich": True,
                "group_key": f"Skills:{sid}",
                "is_name": False,
                "skill_id": sid,
                "tianqi_reworked": reworked,
            })
    split_into_batches(skill_recs, 53, 36)
    reworked_by_batch: dict[int, set[int]] = collections.defaultdict(set)
    for r in skill_recs:
        if r.get("tianqi_reworked"):
            reworked_by_batch[r["batch"]].add(r["skill_id"])
    reworked_sorted = {b: sorted(s) for b, s in reworked_by_batch.items()}
    records.extend(skill_recs)

    # ---------- 批 89～91：乙-07（CommonEvents 89..90, Troops 91） ----------
    ce_recs: list[dict[str, Any]] = []
    for row in load_json(DB_DIR / "CommonEvents.json"):
        if not row:
            continue
        cid = row["id"]
        for li, cmd in enumerate(row.get("list") or []):
            code = cmd.get("code")
            params = cmd.get("parameters", [])
            if code in (401, 405) and params and isinstance(params[0], str) and params[0].strip():
                ce_recs.append({
                    "loc": f"CommonEvents.json:{cid}/cmd#{li}({code})",
                    "field": f"cmd{code}",
                    "text": params[0],
                    "allow_rich": True,
                    "group_key": f"CE:{cid}",
                    "is_name": False,
                })
            elif code == 102 and params and isinstance(params[0], list):
                for ci, ch in enumerate(params[0]):
                    if isinstance(ch, str) and ch.strip():
                        ce_recs.append({
                            "loc": f"CommonEvents.json:{cid}/cmd#{li}(102)[{ci}]",
                            "field": "cmd102",
                            "text": ch,
                            "allow_rich": True,
                            "group_key": f"CE:{cid}",
                            "is_name": False,
                        })
    split_into_batches(ce_recs, 89, 2)
    records.extend(ce_recs)

    for row in load_json(DB_DIR / "Troops.json"):
        if not row:
            continue
        tid = row["id"]
        for pi, pg in enumerate(row.get("pages", [])):
            for li, cmd in enumerate(pg.get("list") or []):
                code = cmd.get("code")
                params = cmd.get("parameters", [])
                if code in (401, 405) and params and isinstance(params[0], str) and params[0].strip():
                    add(f"Troops.json:{tid}/p{pi}/cmd#{li}({code})", f"cmd{code}", params[0], True, f"Troop:{tid}", batch=91)
                elif code == 102 and params and isinstance(params[0], list):
                    for ci, ch in enumerate(params[0]):
                        if isinstance(ch, str) and ch.strip():
                            add(f"Troops.json:{tid}/p{pi}/cmd#{li}(102)[{ci}]", "cmd102", ch, True, f"Troop:{tid}", batch=91)

    # ---------- 批 92～128：乙-08（maps/*.json） ----------
    map_recs: list[dict[str, Any]] = []
    for mp in sorted(MAPS_DIR.glob("Map*.json")):
        mname = mp.name
        m = load_json(mp)
        dname = m.get("displayName", "")
        if isinstance(dname, str) and dname.strip():
            map_recs.append({
                "loc": f"{mname}:displayName",
                "field": "displayName",
                "text": dname,
                "allow_rich": False,
                "group_key": f"{mname}:0",
                "is_name": True,
            })
        for ev in m.get("events", []):
            if not ev:
                continue
            eid = ev.get("id")
            for pi, pg in enumerate(ev.get("pages", [])):
                for li, cmd in enumerate(pg.get("list") or []):
                    code = cmd.get("code")
                    params = cmd.get("parameters", [])
                    if code in (401, 405) and params and isinstance(params[0], str) and params[0].strip():
                        map_recs.append({
                            "loc": f"{mname}:ev{eid}/p{pi}/cmd#{li}({code})",
                            "field": f"cmd{code}",
                            "text": params[0],
                            "allow_rich": True,
                            "group_key": f"{mname}:ev{eid}",
                            "is_name": False,
                        })
                    elif code == 102 and params and isinstance(params[0], list):
                        for ci, ch in enumerate(params[0]):
                            if isinstance(ch, str) and ch.strip():
                                map_recs.append({
                                    "loc": f"{mname}:ev{eid}/p{pi}/cmd#{li}(102)[{ci}]",
                                    "field": "cmd102",
                                    "text": ch,
                                    "allow_rich": True,
                                    "group_key": f"{mname}:ev{eid}",
                                    "is_name": False,
                                })
    split_into_batches(map_recs, 92, 37)
    records.extend(map_recs)

    return records, reworked_sorted


def detect_variant_names(records: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    """检测全库同名异写（忽略空格、全半角冒号/括号差异）与常见术语混用。"""
    # 1. 同名不同标点/空格写法（仅限 name 类字段）
    norm_map: dict[str, dict[str, list[str]]] = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in records:
        if not r.get("is_name"):
            continue
        raw = r["text"].strip()
        if not raw or not CJK_RE.search(raw):
            continue
        norm = (
            raw.replace(" ", "")
            .replace("　", "")
            .replace("：", ":")
            .replace("（", "(")
            .replace("）", ")")
            .replace("【", "[")
            .replace("】", "]")
            .replace("·", "")
            .replace("•", "")
        )
        norm_map[norm][raw].append(r["loc"])

    variants_by_batch: dict[int, list[dict[str, str]]] = collections.defaultdict(list)
    dup_groups: list[dict[str, Any]] = []
    for norm, forms in norm_map.items():
        if len(forms) > 1:
            dup_groups.append({"norm": norm, "forms": {k: v[:5] for k, v in forms.items()}})

    # 2. 高置信度错别字/术语异写正则（在单条内直接标记）
    term_patterns = [
        (re.compile(r"几率"), "术语混用: 「几率」vs「概率」"),
        (re.compile(r"奥数"), "术语/疑似错字: 「奥数」(元素表为奥术)"),
        (re.compile(r"爆击"), "疑似错字: 「爆击」(应为暴击)"),
        (re.compile(r"回和"), "错字: 「回和」(应为回合)"),
        (re.compile(r"防预|防卸"), "错字: 「防预/防卸」(应为防御)"),
        (re.compile(r"装被|装各"), "错字: 「装被/装各」(应为装备)"),
        (re.compile(r"附魔"), "术语检查: 「附魔」"),
        (re.compile(r"金钱|金币"), "货币口径检查: 「金钱/金币」vs「精魂」"),
        (re.compile(r"能量值"), "术语口径检查: 「能量值」vs「TP」"),
    ]
    for r in records:
        txt = r["text"]
        for pat, desc in term_patterns:
            if pat.search(txt):
                variants_by_batch[r["batch"]].append({
                    "loc": r["loc"],
                    "text": txt,
                    "type": "term_variant",
                    "detail": desc,
                })

    return {"dup_name_groups": dup_groups, "term_hits_by_batch": variants_by_batch}


def run_scan() -> None:
    records, reworked_by_batch = collect_all()
    variant_info = detect_variant_names(records)

    batches: dict[int, dict[str, Any]] = {}
    for b in range(21, 129):
        batches[b] = {
            "batch": b,
            "total_segments": 0,
            "tianqi_reworked_skill_ids": reworked_by_batch.get(b, []),
            "hit_count": 0,
            "term_hit_count": 0,
            "hits": [],
            "term_hits": [],
        }

    type_counts = collections.Counter()
    for r in records:
        b = r["batch"]
        batches[b]["total_segments"] += 1
        hits = analyze_text(r["text"], allow_rich=r["allow_rich"], check_empty_name=r.get("is_name", False))
        if hits:
            batches[b]["hit_count"] += 1
            for h in hits:
                type_counts[h["type"]] += 1
            batches[b]["hits"].append({
                "loc": r["loc"],
                "field": r["field"],
                "tianqi_reworked": r.get("tianqi_reworked", False),
                "text": r["text"],
                "issues": hits,
            })

    for b, thits in variant_info["term_hits_by_batch"].items():
        batches[b]["term_hits"] = thits
        batches[b]["term_hit_count"] = len(thits)

    archive = {
        "total_records": len(records),
        "total_batches": len(batches),
        "issue_type_counts": dict(type_counts.most_common()),
        "dup_name_groups": variant_info["dup_name_groups"],
        "batches": {str(b): batches[b] for b in range(21, 129)},
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with (OUT_DIR / "scan_results_by_batch.json").open("w", encoding="utf-8") as f:
        json.dump(archive, f, ensure_ascii=False, indent=2)

    # 全记录缓存放 /tmp，避免把 12MB 原始文本镜像带进 Git；--batch 缺失时可自动重建
    cache_path = Path("/tmp/xa_text_audit_b_records.json")
    with cache_path.open("w", encoding="utf-8") as f:
        by_b: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
        for r in records:
            by_b[str(r["batch"])].append({
                "loc": r["loc"],
                "field": r["field"],
                "text": r["text"],
                "tianqi_reworked": r.get("tianqi_reworked", False),
            })
        json.dump(by_b, f, ensure_ascii=False)

    # 输出可读汇总 scan_summary.md
    lines = [
        "# 乙类全库只读扫描汇总（批 21～128）",
        "",
        f"- 扫描总段数：**{len(records):,}** 段（含 `<pos=... text=...>` 说明行）",
        f"- 问题总命中段数：**{sum(b['hit_count'] for b in batches.values()):,}** 段",
        f"- 同名不同标点/空格组数：**{len(variant_info['dup_name_groups'])}** 组",
        "",
        "## 按问题类型统计",
        "",
        "| 类型 | 命中数 |",
        "| --- | --- |",
    ]
    for typ, cnt in type_counts.most_common():
        lines.append(f"| `{typ}` | {cnt} |")
    lines.extend([
        "",
        "## 按批汇总（批 21～128）",
        "",
        "| 批号 | 段数 | 机械命中数 | 术语/口径提示数 | 天启篇覆盖跳过数 |",
        "| --- | --- | --- | --- | --- |",
    ])
    for b in range(21, 129):
        bi = batches[b]
        lines.append(
            f"| 批 {b} | {bi['total_segments']} | {bi['hit_count']} | {bi['term_hit_count']} | {len(bi['tianqi_reworked_skill_ids'])} |"
        )
    with (OUT_DIR / "scan_summary.md").open("w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Scan complete: {len(records)} segments across 108 batches (21..128).")
    print("Issue counts:", dict(type_counts.most_common()))
    print("Dup name groups:", len(variant_info["dup_name_groups"]))


def inspect_batch(batch_num: int, sample_count: int = 50, skip_reworked: bool = True, include_terms: bool = False) -> None:
    arch = load_json(OUT_DIR / "scan_results_by_batch.json")
    cache_path = Path("/tmp/xa_text_audit_b_records.json")
    if not cache_path.exists():
        records, _ = collect_all()
        by_b: dict[str, list[dict[str, Any]]] = collections.defaultdict(list)
        for r in records:
            by_b[str(r["batch"])].append({
                "loc": r["loc"],
                "field": r["field"],
                "text": r["text"],
                "tianqi_reworked": r.get("tianqi_reworked", False),
            })
        with cache_path.open("w", encoding="utf-8") as f:
            json.dump(by_b, f, ensure_ascii=False)
    recs_all = load_json(cache_path)
    binfo = arch["batches"][str(batch_num)]
    recs = recs_all[str(batch_num)]

    print(f"=== 批 {batch_num} ===")
    print(f"总段数: {binfo['total_segments']} | 机械命中: {binfo['hit_count']} | 术语提示: {binfo['term_hit_count']}")
    reworked_ids = binfo.get("tianqi_reworked_skill_ids", [])
    if reworked_ids:
        print(f"天启篇 skill_rework.json 覆盖技能 ({len(reworked_ids)} 个): {reworked_ids}")

    print("\n--- [1] 机械命中（全部） ---")
    for i, h in enumerate(binfo["hits"], 1):
        if skip_reworked and h.get("tianqi_reworked"):
            continue
        iss = ", ".join(f"{x['type']}:{x['detail']}" for x in h["issues"])
        print(f"[{i}] {h['loc']} | {iss}")
        print(f"    {h['text']!r}")

    if include_terms and binfo["term_hits"]:
        print("\n--- [2] 术语/口径提示 ---")
        for i, t in enumerate(binfo["term_hits"], 1):
            print(f"[T{i}] {t['loc']} | {t['detail']} | {t['text']!r}")

    # 均匀抽样 N 段用于人工排查错字、半截句子
    pool = [r for r in recs if not (skip_reworked and r.get("tianqi_reworked"))]
    if sample_count > 0:
        print(f"\n--- [3] 人工抽读样本（从 {len(pool)} 段非跳过段中均匀抽 {min(sample_count, len(pool))} 段） ---")
        if pool:
            step = max(1, len(pool) / min(sample_count, len(pool)))
        seen = set()
        idx_float = 0.0
        n = 0
        while n < sample_count and int(idx_float) < len(pool):
            idx = int(idx_float)
            if idx not in seen:
                seen.add(idx)
                r = pool[idx]
                print(f"[S{n+1}] {r['loc']} | {r['text']!r}")
                n += 1
            idx_float += step


def main() -> None:
    parser = argparse.ArgumentParser(description="只读扫描乙类数据（批 21～128）")
    parser.add_argument("--scan", action="store_true", help="执行全量只读扫描并写入归档")
    parser.add_argument("--batch", type=int, help="查看指定批次的机械命中与抽读样本")
    parser.add_argument("--samples", type=int, default=50, help="抽读样本段数（默认 50）")
    parser.add_argument("--include-reworked", action="store_true", help="不跳过天启篇 skill_rework 覆盖的技能")
    parser.add_argument("--include-terms", action="store_true", help="一并打印术语/口径提示")
    args = parser.parse_args()

    if args.scan:
        run_scan()
    elif args.batch is not None:
        inspect_batch(
            args.batch,
            sample_count=args.samples,
            skip_reworked=not args.include_reworked,
            include_terms=args.include_terms,
        )
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
