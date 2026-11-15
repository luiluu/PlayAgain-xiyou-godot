#!/usr/bin/env python3
"""逐条核对乙类文字审「必改」项在 XTextFix 修正后是否改掉了（cc/text-fix-b）。

读 00_项目管理/核查/文字审查乙类_xa_text-audit-b.md 各批表里「必改」行的来源位置，比较 generated 原文与
tests/text_fix_dump 导出的修正后数据在这些位置的玩家可见文字：位置上的文字全都变了算「已改」，
有没变的列出来。报告里登记「不改」的（原文其实没错、原版刻意命名）写在 KNOWN 里并给理由。

用法：
  XIYOU_TEXT_FIX_DUMP=<目录> 07_开发环境/godot --headless --path 01_Godot工程 res://tests/text_fix_dump.tscn
  python3 07_开发环境/文字审/核对必改.py --gen-dir <目录> [--report 00_项目管理/核查/文字审查乙类_xa_text-audit-b.md]
退出码：全部已改或已登记不改＝0，否则 1。只读。
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan_beta_text import GEN_DIR, POS_RE, REPO_ROOT, load_json  # noqa: E402

REPORT = REPO_ROOT / "00_项目管理/核查/文字审查乙类_xa_text-audit-b.md"
TEXT_KEYS = ["name", "nickname", "profile", "description", "message1", "message2", "message3", "message4"]

# 报告判「必改」、核对后不改的（编号 → 理由）
KNOWN = {
    "52-001": "原文已完整：Items:3063 生成数据里就是「……与萨姆变身器。」，报告摘录被截断",
    "38-001": "原版设定就叫「奇拉美」（奇美拉的后裔，首领 Enemies:242/246、技能 1287/4182、状态 132 都这么叫），装备以首领命名，保持原样；只有附加状态 129 叫「奇美拉之毒」（小A乙档核查 P2 撤回）",
    "80-003": "原版刻意命名：「西西卡」是角色 88 的正式名（Actors:88、伙伴号角、专属装备都这么叫），说明里玩的是这个梗，不改成卡卡西",
}

# 报告里位置写错的（核对时按实际位置看）：(文件, 报告写的位置) → 实际位置
LOC_FIX = {
    ("Map136.json", "ev9"): "ev4",  # 104-001：Map136 的副本协会主席是 4 号事件（9 号不存在）
    ("Map154.json", "ev2"): "ev3",  # 106-002：Map154 的「缺少终极副本挑符文」在 3 号事件（2 号不存在）
}


def ids(spec: str) -> list[int]:
    out: list[int] = []
    for part in re.split(r"[,，、\s]+", spec.strip()):
        m = re.fullmatch(r"(\d+)(?:\.\.(\d+))?", part)
        if m:
            a = int(m.group(1))
            b = int(m.group(2) or a)
            out.extend(range(a, b + 1))
    return out


def rec_texts(rec: dict, field: str) -> list[str]:
    """记录上某字段的玩家可见文字（note#k＝备注第 k 行的 text 段；note＝全部 pos 行；空＝全部可见字段）。"""
    out: list[str] = []
    fields = [f.strip() for f in re.split(r"[,，]", field) if f.strip()] or TEXT_KEYS + ["note"]
    for f in fields:
        m = re.fullmatch(r"note#?(\d+)?.*", f)
        if m:
            lines = str(rec.get("note", "")).split("\n")
            pick = [lines[int(m.group(1)) - 1]] if m.group(1) and int(m.group(1)) <= len(lines) else lines
            for line in pick:
                pm = POS_RE.search(line)
                if pm:
                    out.append(pm.group(2))
        elif isinstance(rec.get(f), str):
            out.append(rec[f])
    return out


def list_texts(lst) -> list[str]:
    out: list[str] = []
    for c in lst or []:
        if c.get("code") in (401, 405):
            out.append(str(c["parameters"][0]))
        elif c.get("code") == 102:
            out.extend(str(x) for x in c["parameters"][0])
    return out


class Data:
    def __init__(self, base: Path):
        self.base = base
        self.cache: dict[str, object] = {}

    def get(self, rel: str):
        if rel not in self.cache:
            self.cache[rel] = load_json(self.base / rel)
        return self.cache[rel]

    def texts(self, file: str, rest: str) -> list[str] | None:
        """位置 → 文字；位置认不出返回 None。"""
        name = file[:-5]
        head, _, field = rest.partition("/")
        if re.fullmatch(r"Map\d+", name):
            d = self.get(f"maps/{file}")
            evs = d.get("events", [])
            if not head:
                return [t for e in evs if e for p in e["pages"] for t in list_texts(p.get("list"))]
            out: list[str] = []
            for eid in ids(head.replace("ev", "")):
                e = evs[eid] if eid < len(evs) else None
                if not e:
                    return None
                out += [t for p in e["pages"] for t in list_texts(p.get("list"))]
            return out
        d = self.get(f"db/{file}")
        out = []
        for i in ids(head):
            if i >= len(d) or not isinstance(d[i], dict):
                return None
            r = d[i]
            if name == "CommonEvents":
                out += list_texts(r.get("list"))
            elif name == "Troops":
                out += [t for p in r.get("pages", []) for t in list_texts(p.get("list"))]
            else:
                out += rec_texts(r, field)
        return out if ids(head) else None


def locations(cell: str) -> list[tuple[str, str]]:
    """来源格 → [(文件, 位置)]：反引号段里 X.json:位置 开新文件，后面不带文件名的段沿用上一个文件。"""
    out: list[tuple[str, str]] = []
    file = ""
    for seg in re.findall(r"`([^`]+)`", cell):
        m = re.match(r"([A-Za-z]+\d*\.json)(?::(.*))?$", seg.strip())
        if m:
            file = m.group(1)
            out.append((file, (m.group(2) or "").strip()))
        elif file and re.match(r"(ev)?\d", seg.strip()):
            out.append((file, seg.strip()))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--gen-dir", required=True, help="text_fix_dump 导出的修正后数据目录")
    ap.add_argument("--report", default=str(REPORT))
    args = ap.parse_args()
    raw = Data(GEN_DIR)
    fixed = Data(Path(args.gen_dir).resolve())
    rows = []
    for line in Path(args.report).read_text(encoding="utf-8").splitlines():
        if not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
        if len(cells) >= 7 and cells[5] == "必改":
            rows.append(cells)
    done, known, left = [], [], []
    for c in rows:
        ref = c[0]
        if ref in KNOWN:
            known.append((ref, KNOWN[ref]))
            continue
        locs = locations(c[1])
        bad = []
        for file, rest in locs:
            rest = LOC_FIX.get((file, rest), rest)
            a = raw.texts(file, rest)
            b = fixed.texts(file, rest)
            if a is None or b is None:
                bad.append(f"{file}:{rest}（位置认不出）")
            elif a == b:
                bad.append(f"{file}:{rest}（文字没变）")
        if not locs:
            bad.append("来源格里没有能解析的位置")
        (left if bad else done).append((ref, bad))
    print(f"必改共 {len(rows)} 条：已改 {len(done)}、登记不改 {len(known)}、剩余 {len(left)}")
    for ref, why in known:
        print(f"  不改 {ref}：{why}")
    for ref, bad in left:
        print(f"  剩余 {ref}：" + "；".join(bad))
    return 0 if not left else 1


if __name__ == "__main__":
    sys.exit(main())
