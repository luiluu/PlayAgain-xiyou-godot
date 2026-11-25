#!/usr/bin/env python3
"""T493 洪荒称号兑换码生成（只在本机跑；码原文不进仓库、日志、交付单）。

游戏里的兑换（modes/xiyou/core/honghuang_titles.gd XHonghuangTitles.redeem）：
  输入的码规范化（大写、只留字母数字）后算 sha256("honghuang-redeem-v1|<码>|<存档身份>")，
  在 modes/xiyou/honghuang_redeem.json 的 codes 里找到同样的 hash 才算对；存档身份＝存档的 orbSeed（整数）。

用法：
  python3 洪荒兑换码.py --save <玩家导出的存档 .json> --titles 52,53 [--write] [--out <码写到哪个文件>]
  python3 洪荒兑换码.py --seed <orbSeed> --titles 52,53 [--write] [--out ...]
  python3 洪荒兑换码.py --check <码> --seed <orbSeed>      # 核对一个码在配置里对不对（不打印码）

--write：把 hash 追加进配置（不写码原文）。不带 --write 只打印，不改文件。
--out：码写进这个文件（权限 600），终端只打印「已写入」；不带时码打印到终端。
封存导出（kyo-remake-save-sealed-v2）里的存档是加密的，读不出 orbSeed，请直接给 --seed。
"""
import argparse
import hashlib
import json
import os
import secrets
import sys
from pathlib import Path

SALT = "honghuang-redeem-v1"
ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"  # 去掉 0 O 1 I L，31 个字符；16 位约 79 比特
CONFIG = Path(__file__).resolve().parent.parent / "01_Godot工程" / "modes" / "xiyou" / "honghuang_redeem.json"
SAVE_TITLES = {52, 53}


def normalize(code: str) -> str:
    return "".join(ch for ch in code.upper() if ch.isascii() and ch.isalnum())


def code_hash(code: str, identity: str) -> str:
    return hashlib.sha256(f"{SALT}|{normalize(code)}|{identity}".encode("utf-8")).hexdigest()


def new_code() -> str:
    raw = "".join(secrets.choice(ALPHABET) for _ in range(16))
    return "-".join(raw[i:i + 4] for i in range(0, 16, 4))


def seed_from_save(path: str) -> int:
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(d, dict) and "sealed" in d:
        sys.exit("这是封存导出，读不出 orbSeed；请改用 --seed。")
    data = d.get("data", d) if isinstance(d, dict) else None
    if not isinstance(data, dict) or "orbSeed" not in data:
        sys.exit("存档里没有 orbSeed（旧档由游戏按存档内容算出）；请在游戏里读这份档后取 XState.current.orb_seed，用 --seed。")
    return int(float(data["orbSeed"]))


def load_config() -> dict:
    if CONFIG.exists():
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    return {"codes": []}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--save")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--titles", default="52,53")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--out")
    ap.add_argument("--note", default="")
    ap.add_argument("--check")
    a = ap.parse_args()
    if (a.save is None) == (a.seed is None):
        ap.error("--save 和 --seed 二选一")
    seed = seed_from_save(a.save) if a.save else a.seed
    identity = str(int(seed))
    cfg = load_config()
    if a.check:
        h = code_hash(a.check, identity)
        hit = [e for e in cfg.get("codes", []) if e.get("hash") == h]
        print("对：给称号 %s" % hit[0].get("titles") if hit else "不对：配置里没有这个码（或不是这份存档的）")
        return 0 if hit else 1
    titles = [int(x) for x in a.titles.split(",") if x.strip()]
    bad = [t for t in titles if t not in SAVE_TITLES]
    if not titles or bad:
        ap.error("--titles 只能是 52（洪荒首证）、53（洪荒·阿夜）")
    code = new_code()
    entry = {"hash": code_hash(code, identity), "titles": titles}
    if a.note:
        entry["note"] = a.note
    if a.write:
        cfg.setdefault("codes", []).append(entry)
        CONFIG.write_text(json.dumps(cfg, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
        print("已把 hash 写进 %s（%d 条）" % (CONFIG.name, len(cfg["codes"])))
    else:
        print("没带 --write：配置没改；hash＝%s" % entry["hash"])
    if a.out:
        fd = os.open(a.out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(code + "\n")
        print("码已写入 %s（权限 600）；别贴进仓库、日志、交付单" % a.out)
    else:
        print(code)
    return 0


if __name__ == "__main__":
    sys.exit(main())
