#!/usr/bin/env python3
"""系统页成对截图读数核对（八戒_63）：原版重放（review_system_pages）↔ Godot 取证（tests/xiyou_system_evidence 与各专项 --out）。

用法：python3 -I review_system_pages_compare.py <原版目录> <Godot目录> <tests/fixtures 目录> <输出.json>
只比运行时窗口矩形、行文与说明、原尺寸 PNG 与来源身份；画面观感另须逐张打开看（交付单逐页记结论）。"""
import argparse
import json
import struct
from pathlib import Path

# Godot 取证读数里的窗口名 → 原版窗口类
PAIRS = {
    "craft_0_category": {"help": "Window_Help", "cat": "Window_RecCategory", "list": "Window_RecipeList", "detail": "Window_RecipeDetail",
                         "confirm": "Window_RecipeConfirm", "gold": "Window_Gold", "gauge": "Window_RecGauge"},
    "magic_shop_buy": {"cmd": "Window_ShopCommand", "info": "Window_ShopInfo", "list": "Window_ShopBuy", "status": "Window_ShopStatus", "gold": "Window_Gold"},
    "magic_equip_slot": {"cmd": "Window_EquipCommand", "status": "Window_SkillStatus", "list": "Window_EquipSlot", "lower": "Window_ItemInfo"},
    "magic_item_info": {"cat": "Window_ItemCategory", "status": "Window_ItemStatus", "list": "Window_ItemList", "info": "Window_ItemInfo"},
    "pet_bottom": {"index": "Window_PetSystemIndex", "status": "Window_PetSystemStatus", "bottom": "Window_PotBottomConfirm"},
    "pet_feed": {"index": "Window_PetSystemIndex", "status": "Window_PetSystemStatus", "bottom": "Window_PotBottomConfirm", "feed": "Window_PetUpLevelList"},
    "pet_synth": {"index": "Window_PetSystemIndex", "status": "Window_PetSystemStatus", "bottom": "Window_PotBottomConfirm", "syn": "Window_PetSynthesisConfirm"},
}
RACE = ["race_1_default", "race_2_confirm", "race_3_members", "race_4_actor", "race_5_change"]
# 只有原版读数的状态（Godot 截图由专项产出，矩形由专项对 fixture 断言）：原版矩形 → fixture 几何
CRAFT_GEO = {"help": "Window_Help", "cat": "Window_RecCategory", "list": "Window_RecipeList", "detail": "Window_RecipeDetail",
             "confirm": "Window_RecipeConfirm", "gold": "Window_Gold", "gauge": "Window_RecGauge"}
PET_GEO = {"index": "Window_PetSystemIndex", "status": "Window_PetSystemStatus", "bottom": "Window_PotBottomConfirm"}
# 怪物图鉴（八戒_64）：Godot 读数来自 tests/xiyou_enemy_book 与 xiyou_battle_ui 的 --out；说明卡只比位置与宽（卡高随 O-007 最小字号）
BOOK = {
    "enemy_book_0": {"index_win": "Window_EnemyBookIndex", "status_win": "Window_EnemyBookStatus"},
    "enemy_book_0_drops": {"index_win": "Window_EnemyBookIndex", "drop_win": "Window_EnemyBookItemList"},
    "battle_42_enemy_book": {"index_win": "Window_EnemyBookIndex", "status_win": "Window_EnemyBookStatus"},
}


def read(path):
    return json.loads(path.read_text())


def near(a, b, tol=0.05):
    return len(a) >= 4 and len(b) >= 4 and all(abs(float(x) - float(y)) <= tol for x, y in zip(a[:4], b[:4]))


def formal_rect(data, cls):
    hits = [w["rect"] for w in data["windows"] if w["type"] == cls]
    return hits[0] if hits else None


def png_ok(path):
    data = path.read_bytes()
    return data[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", data[16:24]) == (1280, 720)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("formal", type=Path)
    ap.add_argument("godot", type=Path)
    ap.add_argument("fixtures", type=Path)
    ap.add_argument("output", type=Path)
    a = ap.parse_args()
    checks, diffs = {}, {}
    run = read(a.formal / "run.json")
    checks["formal_no_engine_errors"] = not run.get("errors") and all(not p["errors"] for p in run["pages"].values())
    before, after = a.formal / "source_before.json", a.formal / "source_after.json"
    checks["source_identity_unchanged"] = after.exists() and read(before) == read(after)
    for shot, pairs in PAIRS.items():
        f, g = read(a.formal / (shot + ".json")), read(a.godot / (shot + ".json"))
        bad = [k for k, cls in pairs.items() if not near(g["windows"][k]["rect"], formal_rect(f, cls) or [])]
        checks["rects_" + shot] = not bad
        if bad:
            diffs[shot] = {k: [g["windows"][k]["rect"], formal_rect(f, pairs[k])] for k in bad}
    for shot in RACE:
        f, g = read(a.formal / (shot + ".json")), read(a.godot / (shot + ".json"))
        checks["race_" + shot] = near(g["windows"]["choice"]["rect"], formal_rect(f, "Window_YunChoices")) \
            and f["extra"]["rows"] == g["extra"]["rows"] and f["extra"]["info"] == g["extra"]["info"]
    craft = read(a.fixtures / "crafting_oracle.json")
    for shot in ["craft_1_list", "craft_3_confirm_x3", "craft_4_popup"]:
        f = read(a.formal / (shot + ".json"))
        checks["fixture_geo_" + shot] = all(near(formal_rect(f, cls), craft["geo"][k]) for k, cls in CRAFT_GEO.items())
        buttons = [w for w in f["windows"] if w["type"] == "Sprite_Button"]
        shown = shot != "craft_1_list"
        checks["buttons_" + shot] = len(buttons) == 5 and all(b["visible"] == shown for b in buttons) \
            and (not shown or [b["rect"] for b in buttons] == craft["buttons"])
    pet = read(a.fixtures / "pet_oracle.json")
    for shot in ["pet_0", "pet_1_skills"]:
        f = read(a.formal / (shot + ".json"))
        checks["fixture_geo_" + shot] = all(near(formal_rect(f, cls), pet["geo"][k]) for k, cls in PET_GEO.items())
        made = f["extra"]["pets"]
        checks["pets_regenerated_" + shot] = [p["name"] for p in made] == [p["name"] for p in pet["pets"]] \
            and [p["skills"] for p in made] == [p["skills"] for p in pet["pets"]]
    for shot in ["alien_list", "alien_list_pending", "alien_config_bound"]:
        pane = read(a.formal / (shot + ".json"))["extra"]["pane"]
        checks["alien_pane_" + shot] = abs(pane[0] - 100) <= 0.5 and abs(pane[2] - 1080) <= 0.5
    for shot, pairs in BOOK.items():
        f, g = read(a.formal / (shot + ".json")), read(a.godot / (shot + ".json"))
        bad = [k for k, cls in pairs.items() if not near(g["windows"][k]["rect"], formal_rect(f, cls) or [])]
        checks["book_rects_" + shot] = not bad
        if bad:
            diffs[shot] = {k: [g["windows"][k]["rect"], formal_rect(f, pairs[k])] for k in bad}
    f, g = read(a.formal / "enemy_book_0_drops.json"), read(a.godot / "enemy_book_0_drops.json")
    card = [w for w in f["windows"] if w["type"] == "Sprite_ItemHelp"][0]
    checks["book_help_card_pos"] = card["visible"] and g["windows"]["help_card"]["visible"] \
        and near(g["windows"]["help_card"]["rect"][:3] + [0], card["rect"][:3] + [0])
    # 修炼底部「修炼」：Godot XTrainingScene.SPACE_W 取自这项读数（44 个空格的原版实测宽）
    t = read(a.formal / "training_bottom.json")["extra"]
    checks["training_space_width"] = abs(t["spaces44"] - 317.28125) < 0.01 and t["fontSize"] == 26
    for d, label in ((a.formal, "formal"), (a.godot, "godot")):
        for shot in list(PAIRS) + RACE + ["craft_1_list", "craft_3_confirm_x3", "craft_4_popup", "pet_0", "pet_1_skills",
                                          "alien_list", "alien_list_pending", "alien_config_bound"] + list(BOOK) + ["training_bottom"]:
            checks["png_%s_%s" % (label, shot)] = png_ok(d / (shot + ".png"))
    result = {"checks": checks, "passed": sum(checks.values()), "total": len(checks), "differences": diffs,
              "limits": ["只比窗口矩形与行文；文字逐条绘制由各专项对 fixture 断言，画面观感逐张人工看",
                         "说明卡位置／字号／出售价分别是已登记 O-008／O-007／O-049，不比",
                         "背景粒子（MOG 菜单粒子）为动态，不比",
                         "怪物图鉴说明卡高随 O-007 最小字号（原版 239、Godot 267），只比位置与宽"]}
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"{result['passed']}/{result['total']}")
    if not all(checks.values()):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
