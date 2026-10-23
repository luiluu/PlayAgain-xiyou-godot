#!/usr/bin/env python3
"""重放读数→既有fixture→Godot专项的可重放核对；不改参照或放宽既有排除范围。"""
import argparse
import json
import struct
from pathlib import Path


def read(path):
    return json.loads(path.read_text())


def drawn(ops, actor):
    # 与原xiyou_actor_book相同：undefined不绘制；专属角色自带图标不属于IconSet。
    return [o for o in ops if str(o[0]) != "undefined" and not
            (len(o) == 3 and (actor >= 167 or not isinstance(o[0], (int, float))))]


def equal(a, b):
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(equal(x, y) for x, y in zip(a, b))
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return abs(a - b) <= 0.05
    return a == b


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("formal", type=Path)
    ap.add_argument("godot", type=Path)
    ap.add_argument("fixture", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    fresh = read(args.formal / "actor_book_replay.json")
    fixture = read(args.fixture)
    checks, differences = {}, {}
    checks["fresh_engine_no_errors"] = fresh["done"] and not fresh["errors"]
    checks["source_identity_unchanged"] = read(args.formal / "source_before.json") == read(args.formal / "source_after.json")
    checks["all_179_index_names"] = fresh["index"] == fixture["index"] and len(fresh["actors"]) == 179
    excluded_sprites = {108, 143, 144, 145, 157, 160, *range(167, 178)}
    for kind in ("status", "header", "list", "skills", "sprite"):
        bad = []
        for key, want in fixture["actors"].items():
            actor = int(key)
            if kind not in want or kind == "sprite" and actor in excluded_sprites:
                continue
            got = fresh["actors"][key][kind]
            expected = want[kind]
            if kind in ("status", "header", "list"):
                got, expected = drawn(got, actor), drawn(expected, actor)
            if not equal(got, expected):
                bad.append(key)
        differences[kind] = bad
        checks["fixture_" + kind] = not bad
    checks["formal_fixture_geometry"] = all(equal(fresh["geo"][k], v) for k, v in fixture["geo"].items())
    g = read(args.godot / "actor_book_1.json")
    for k in ("index", "status", "header", "list"):
        checks["paired_rect_" + k] = equal(g[k], fresh["geo"][k][:4])
    checks["paired_line_height"] = g["lineHeight"] == fresh["geo"]["index"][4] == 36
    detail = read(args.godot / "actor_book_1_skills.json")
    checks["same_selected_actor_skill"] = (detail["actor"], detail["skill"]) == (fresh["details"]["actor"], fresh["details"]["skill"])
    checks["paired_help_position_width"] = equal(detail["help"][:3], fresh["details"]["help"][:3])
    checks["paired_details_visibility"] = detail["visible"] == fresh["details"]["visible"]
    checks["formal_empty_slot_rejected"] = fresh["emptySlotRejected"]
    back = read(args.godot / "actor_book_back.json")
    checks["paired_back_visibility"] = back["visible"] == fresh["back"]["visible"]
    checks["formal_residual_border_reproduced"] = len(fresh["back"]["borders"]) == 4 and all(b["visible"] for b in fresh["back"]["borders"])
    for directory, label in ((args.formal, "formal"), (args.godot, "godot")):
        for name in ("actor_book_1", "actor_book_1_skills", "actor_book_back"):
            data = (directory / (name + ".png")).read_bytes()
            checks[label + "_native_png_" + name] = data[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", data[16:24]) == (1280, 720)
    result = {"checks": checks, "passed": sum(checks.values()), "total": len(checks), "differences": differences,
              "limits": ["原专项>=167自带图标及17个未切片SV排除范围未扩张", "O-007说明字号优化：原版卡高295，Godot307，未作逐像素相等断言",
                         "仅核本批人物图鉴；全量/战斗/进阶/切片外图像不在通过范围"]}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{result['passed']}/{result['total']}")
    if not all(checks.values()):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
