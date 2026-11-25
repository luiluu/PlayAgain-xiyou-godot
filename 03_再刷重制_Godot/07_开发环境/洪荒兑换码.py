#!/usr/bin/env python3
"""T493／T508 洪荒称号兑换码生成（只在本机跑；码原文不进仓库、日志、交付单）。

游戏里的兑换（modes/xiyou/core/honghuang_titles.gd XHonghuangTitles.redeem）：
  输入的码规范化（大写、只留字母数字）后算 sha256("honghuang-redeem-v2|<码>")，
  在 modes/xiyou/honghuang_redeem.json 的 codes 里找到同样的 hash 才算对。
  T508 起码不绑存档、不绑设备：在一台设备上兑一次，这台设备上的西游存档（含之后新开档）都永久拥有；
  只有发行包缺封存密钥的兼容路径才退回只记在当前存档。

用法：
  python3 洪荒兑换码.py --out <码写到哪个文件> --titles 52,53 [--write] [--note ...]
  python3 洪荒兑换码.py --check-file <码所在文件>     # 核对一个码在配置里对不对（不打印码）

--out（必填）：码原文只写进这个文件（权限 600），终端只打印「已写入」和 hash，从不打印码原文。
--write：把 hash 追加进配置（不写码原文）。不带 --write 只写码文件、打印 hash，不改配置。
建议放 ~/Documents/再刷私密_兑换码/ 下。
"""
import argparse
import hashlib
import json
import os
import secrets
import stat
import sys
from pathlib import Path

SALT = "honghuang-redeem-v2"
ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"  # 去掉 0 O 1 I L，31 个字符；16 位约 79 比特
CONFIG = Path(__file__).resolve().parent.parent / "01_Godot工程" / "modes" / "xiyou" / "honghuang_redeem.json"
SAVE_TITLES = {52, 53}


def normalize(code: str) -> str:
    return "".join(ch for ch in code.upper() if ch.isascii() and ch.isalnum())


def code_hash(code: str) -> str:
    return hashlib.sha256(f"{SALT}|{normalize(code)}".encode("utf-8")).hexdigest()


def new_code() -> str:
    raw = "".join(secrets.choice(ALPHABET) for _ in range(16))
    return "-".join(raw[i:i + 4] for i in range(0, 16, 4))


def load_config() -> dict:
    if CONFIG.exists():
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    return {"codes": []}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--titles", default="52,53")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--out", help="码原文写到这个文件（权限 600）；生成码时必填")
    ap.add_argument("--note", default="")
    ap.add_argument("--check-file", help="从文件第一行读码核对（码不经命令行，免得进 shell 历史）")
    a = ap.parse_args()
    cfg = load_config()
    if a.check_file:
        code = Path(a.check_file).read_text(encoding="utf-8").splitlines()[0]
        h = code_hash(code)
        hit = [e for e in cfg.get("codes", []) if e.get("hash") == h]
        print("对：给称号 %s" % hit[0].get("titles") if hit else "不对：配置里没有这个码")
        return 0 if hit else 1
    if not a.out:
        ap.error("生成码必须给 --out <文件>：码原文只写进权限 600 的文件，不打印到终端")
    titles = [int(x) for x in a.titles.split(",") if x.strip()]
    bad = [t for t in titles if t not in SAVE_TITLES]
    if not titles or bad:
        ap.error("--titles 只能是 52（洪荒首证）、53（洪荒·阿夜）")
    code = new_code()
    entry = {"hash": code_hash(code), "titles": titles}
    if a.note:
        entry["note"] = a.note
    # 先写码文件（写不了就停，配置里不会留下没人知道原文的 hash）
    # 不跟符号链接、不截断地打开，再按文件描述符确认是普通文件（终端、管道、设备一律拒绝），然后才截断写入；不是就报错，配置不动
    try:
        fd = os.open(a.out, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
    except OSError as e:
        sys.exit("--out 打不开（%s）：必须是普通文件；配置没改" % e.strerror)
    if not stat.S_ISREG(os.fstat(fd).st_mode):
        os.close(fd)
        sys.exit("--out 必须是普通文件（不能是终端、管道、设备、符号链接）；配置没改")
    os.set_blocking(fd, True)
    os.ftruncate(fd, 0)
    os.fchmod(fd, 0o600)  # 覆写已有文件时 O_CREAT 的权限位不生效，这里再收紧一次
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(code + "\n")
    print("码已写入 %s（权限 600）；别贴进仓库、日志、交付单" % a.out)
    if a.write:
        cfg.setdefault("codes", []).append(entry)
        CONFIG.write_text(json.dumps(cfg, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
        print("已把 hash 写进 %s（%d 条）" % (CONFIG.name, len(cfg["codes"])))
    else:
        print("没带 --write：配置没改；hash＝%s" % entry["hash"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
