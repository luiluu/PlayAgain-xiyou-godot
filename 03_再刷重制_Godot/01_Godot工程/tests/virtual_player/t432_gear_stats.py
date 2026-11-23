#!/usr/bin/env python3
"""T432 存档链装备品质分布与练度统计脚本。

用法：
  python3 t432_gear_stats.py [--floors 10,20,30,33] [--out-md <md>] [--out-json <json>] \
      标签1=快照目录1 标签2=快照目录2 ...

说明：
- 每个快照目录下按 `floor_<层>_*.json`（优先不带 `_retry`）找对应层的存档。
- 品质档照 `modes/xiyou/generated/db/UnifiedQuality.json` 的 `itemGrades`（0 普通～6 神话）。
- 至臻判定照 `XTreasureBatch`（`baseName` 或 `name` 匹配 `^[“「"]?至臻`）。
- 角色强/弱档位照 `Actors.json` 备注 `<KyoTier:...>`。
"""
import argparse
import glob
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB_DIR = ROOT / "modes/xiyou/generated/db"
TIANQI_DIR = ROOT / "modes/xiyou/tianqi_data"

GRADE_NAMES = ["普通", "优秀", "精良", "史诗", "传说", "不朽", "神话"]
PRESTIGE_RE = re.compile(r'^[“「"]?至臻')


def load_db():
    uq = json.loads((DB_DIR / "UnifiedQuality.json").read_text(encoding="utf-8"))
    sys_d = json.loads((DB_DIR / "System.json").read_text(encoding="utf-8"))
    actors = json.loads((DB_DIR / "Actors.json").read_text(encoding="utf-8"))
    sr = json.loads((TIANQI_DIR / "skill_rework.json").read_text(encoding="utf-8"))
    tiers_cfg = sr.get("tiers", {})
    tier_map = {}
    for tname in ("超强者", "强者"):
        for aid in tiers_cfg.get(tname, []):
            tier_map[int(aid)] = tname
    actor_info = {}
    for a in actors:
        if not isinstance(a, dict) or not a.get("name"):
            continue
        aid = int(a["id"])
        actor_info[aid] = {
            "name": str(a["name"]),
            "tier": tier_map.get(aid, "弱者"),
        }
    return {
        "grades": uq["itemGrades"],
        "grade_names": uq["names"],
        "equip_types": sys_d.get("equipTypes", []),
        "actors": actor_info,
    }


def find_floor_file(snap_dir: Path, floor: int):
    # 兼容传 saves 根目录或上层目录
    candidates = []
    for base in (snap_dir, snap_dir / "saves"):
        if not base.is_dir():
            continue
        for p in sorted(base.glob(f"floor_{floor}_*.json")):
            if "_retry" in p.name:
                continue
            candidates.append(p)
        if candidates:
            break
    return candidates[0] if candidates else None


def analyze_save(path: Path, db: dict):
    d = json.loads(path.read_text(encoding="utf-8"))
    slots = [int(x) for x in d.get("battleSlots", [])[:4] if int(x) > 0]
    helper = int(d.get("battleSlots", [0, 0, 0, 0, 0])[4]) if len(d.get("battleSlots", [])) >= 5 else 0
    actors_map = d.get("actors", {})
    grades = db["grades"]
    gnames = db["grade_names"]
    etypes = db["equip_types"]
    ainfo = db["actors"]

    grade_counts = {n: 0 for n in gnames}
    zhizhen_items = []
    mythic_zhizhen_items = []
    boosts = []
    fabao_levels = []
    actor_rows = []
    total_non_fb = 0

    for aid in slots:
        a = actors_map.get(str(aid), {})
        info = ainfo.get(aid, {"name": f"#{aid}", "tier": "未知"})
        lv = int(a.get("level", 0))
        equips = a.get("equips", [])
        slot_details = []
        a_fabao = None
        a_zz = 0
        a_mzz = 0
        a_boosts = []
        a_grades = {n: 0 for n in gnames}

        for si, eq in enumerate(equips):
            if not isinstance(eq, dict) or not eq:
                continue
            et = int(eq.get("etypeId", 0))
            et_name = etypes[et] if 0 <= et < len(etypes) else f"格{si}"
            meta = eq.get("meta", {}) if isinstance(eq.get("meta"), dict) else {}
            is_fb = bool(meta.get("Magic Weapon")) or et == 13
            q_raw = str(meta.get("quality", "0")).strip()
            qi = int(q_raw) if q_raw.isdigit() else 0
            g_idx = grades[qi] if 0 <= qi < len(grades) else 0
            g_idx = max(0, min(g_idx, len(gnames) - 1))
            g_name = gnames[g_idx]
            base_name = str(eq.get("baseName", eq.get("name", "")))
            full_name = str(eq.get("name", base_name))
            is_zz = bool(PRESTIGE_RE.search(base_name))
            is_mzz = is_zz and g_name == "神话"
            boost = int(eq.get("boostCount", 0))

            if is_fb:
                fb_lv = int(round(float(eq.get("level", 1))))
                a_fabao = {
                    "slot": si,
                    "name": base_name,
                    "level": fb_lv,
                    "quality": g_name,
                    "boost": boost,
                }
                fabao_levels.append(fb_lv)
            else:
                total_non_fb += 1
                grade_counts[g_name] += 1
                a_grades[g_name] += 1
                boosts.append(boost)
                a_boosts.append(boost)
                if is_zz:
                    a_zz += 1
                    zhizhen_items.append(f"{info['name']}:{base_name}({g_name}+{boost})")
                if is_mzz:
                    a_mzz += 1
                    mythic_zhizhen_items.append(f"{info['name']}:{base_name}(+{boost})")
                slot_details.append({
                    "slot": si,
                    "etype": et_name,
                    "quality": g_name,
                    "quality_raw": qi,
                    "boost": boost,
                    "zhizhen": is_zz,
                    "mythic_zhizhen": is_mzz,
                    "name": base_name,
                    "full_name": full_name,
                })

        actor_rows.append({
            "id": aid,
            "name": info["name"],
            "tier": info["tier"],
            "level": lv,
            "non_fb_count": len(slot_details),
            "grade_counts": a_grades,
            "zhizhen_count": a_zz,
            "mythic_zhizhen_count": a_mzz,
            "boost_min": min(a_boosts) if a_boosts else 0,
            "boost_max": max(a_boosts) if a_boosts else 0,
            "boost_avg": round(sum(a_boosts) / len(a_boosts), 2) if a_boosts else 0.0,
            "fabao": a_fabao,
            "slots": slot_details,
        })

    # 读同名 meta（如有）
    meta_info = {}
    meta_file = path.parent / "meta" / path.name
    if meta_file.is_file():
        try:
            meta_info = json.loads(meta_file.read_text(encoding="utf-8"))
        except Exception:
            pass

    return {
        "file": path.name,
        "floor": int(d.get("variables", {}).get("20", 0)) if isinstance(d.get("variables"), dict) else 0,
        "gold": int(d.get("gold", 0)),
        "helper": helper,
        "actors": actor_rows,
        "total_non_fb": total_non_fb,
        "grade_counts": grade_counts,
        "zhizhen_count": len(zhizhen_items),
        "zhizhen_items": zhizhen_items,
        "mythic_zhizhen_count": len(mythic_zhizhen_items),
        "mythic_zhizhen_items": mythic_zhizhen_items,
        "boost_min": min(boosts) if boosts else 0,
        "boost_max": max(boosts) if boosts else 0,
        "boost_avg": round(sum(boosts) / len(boosts), 2) if boosts else 0.0,
        "fabao_levels": fabao_levels,
        "fabao_avg": round(sum(fabao_levels) / len(fabao_levels), 1) if fabao_levels else 0.0,
        "gifted_count": len(meta_info.get("gifted_floors", [])) if meta_info else None,
        "real_count": len(meta_info.get("real_floors", [])) if meta_info else None,
    }


def fmt_grades_compact(gc: dict) -> str:
    parts = []
    for k in reversed(GRADE_NAMES):
        v = gc.get(k, 0)
        if v > 0:
            parts.append(f"{k}{v}")
    return "/".join(parts) if parts else "无"


def render_markdown(results: dict, floors: list) -> str:
    lines = ["# 存档链装备品质与练度分布表（10 / 20 / 30 / 33 层）", ""]

    # 一、总览对照表（按层分组）
    lines.append("## 一、各层汇总对照（上场 4 人常规装备格，不含法宝格）")
    lines.append("")
    lines.append("| 层 | 链 | 上场 4 人（档位） | 等级 | 装备格 | 神话 | 不朽 | 传说 | 史诗 | 精良及以下 | 至臻件数 | 强化（min~max／均） | 法宝等级（4人） |")
    lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for f in floors:
        for label, fdict in results.items():
            row = fdict.get(f)
            if row is None:
                lines.append(f"| {f} | {label} | （无该层存档） | - | - | - | - | - | - | - | - | - | - |")
                continue
            gc = row["grade_counts"]
            low = gc["精良"] + gc["优秀"] + gc["普通"]
            team_s = "、".join(f"{a['name']}({a['tier'][0]})" for a in row["actors"])
            lvs = "/".join(str(a["level"]) for a in row["actors"])
            fbs = "/".join(str(a["fabao"]["level"]) if a["fabao"] else "无" for a in row["actors"])
            boost_s = f"+{row['boost_min']}~+{row['boost_max']}（均 +{row['boost_avg']:.1f}）"
            zz_s = f"{row['mythic_zhizhen_count']}" if row['mythic_zhizhen_count'] == row['zhizhen_count'] else f"{row['mythic_zhizhen_count']}（含非神话共{row['zhizhen_count']}）"
            lines.append(
                f"| {f} | {label} | {team_s} | {lvs} | {row['total_non_fb']} | "
                f"{gc['神话']} | {gc['不朽']} | {gc['传说']} | {gc['史诗']} | {low} | "
                f"{zz_s} | {boost_s} | {fbs} |"
            )

    # 二、逐链逐层每人每格明细
    lines.append("")
    lines.append("## 二、逐链逐层每人每格明细")
    for label, fdict in results.items():
        lines.append("")
        lines.append(f"### 链：{label}")
        for f in floors:
            row = fdict.get(f)
            lines.append("")
            if row is None:
                lines.append(f"#### 第 {f} 层：无存档")
                continue
            lines.append(
                f"#### 第 {f} 层（{row['file']}，常规装 {row['total_non_fb']} 件：{fmt_grades_compact(row['grade_counts'])}，"
                f"至臻 {row['zhizhen_count']} 件，强化 +{row['boost_min']}~+{row['boost_max']} 均 +{row['boost_avg']:.1f}）"
            )
            lines.append("")
            lines.append("| 角色（ID／档位／等级） | 各格明细（部位:品质+强化[至臻]） | 品质合计 | 至臻 | 法宝 |")
            lines.append("| --- | --- | --- | --- | --- |")
            for a in row["actors"]:
                slot_strs = []
                for s in a["slots"]:
                    zz_tag = "★至臻" if s["zhizhen"] else ""
                    slot_strs.append(f"{s['etype']}:{s['quality']}+{s['boost']}{zz_tag}")
                fb_s = f"{a['fabao']['name']} Lv{a['fabao']['level']}" if a["fabao"] else "无"
                lines.append(
                    f"| {a['name']}（#{a['id']}／{a['tier']}／Lv{a['level']}） | "
                    f"{'；'.join(slot_strs)} | {fmt_grades_compact(a['grade_counts'])} | "
                    f"{a['zhizhen_count']} | {fb_s} |"
                )
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--floors", default="10,20,30,33")
    ap.add_argument("--out-md", default="")
    ap.add_argument("--out-json", default="")
    ap.add_argument("chains", nargs="+", help="标签=快照目录")
    args = ap.parse_args()

    floors = [int(x) for x in args.floors.split(",") if x.strip()]
    db = load_db()
    results = {}
    for item in args.chains:
        label, raw_dir = item.split("=", 1)
        snap_dir = Path(os.path.expanduser(raw_dir))
        fdict = {}
        for f in floors:
            fp = find_floor_file(snap_dir, f)
            fdict[f] = analyze_save(fp, db) if fp else None
        results[label] = fdict

    md = render_markdown(results, floors)
    if args.out_md:
        Path(args.out_md).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out_md).write_text(md, encoding="utf-8")
    else:
        print(md)
    if args.out_json:
        Path(args.out_json).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out_json).write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
