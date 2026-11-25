#!/usr/bin/env python3
"""T505：从 T504 的《西游战斗怪模板清单.md》生成运行时用的 content/monsters/rift/profiles.json。

by_enemy：敌人 ID → 模板（人形 humanoid／鳍骨 finbone／岩壳 rockshell），取主表「西游战斗引用及运行时记录」。
by_key：实战外观键 → 模板（同一键多数票；ID 查不到时用，变身／冠军之路以外的少数记录兜底）。
review：清单标「需」单独锚点／跟帧复核的敌人 ID（运行时照样挂共用模板，只作回报清单）。
用法：python3 西游异化模板映射.py [--check]（--check 只比对现有文件是否最新，退出码 1＝过期）
"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / '01_Godot工程' / 'content' / 'monsters' / 'rift'
SRC = ROOT / '西游战斗怪模板清单.md'
OUT = ROOT / 'profiles.json'
NAMES = {'人形': 'humanoid', '鳍骨': 'finbone', '岩壳': 'rockshell'}
ROW = re.compile(r'^\| `(\d+)` \| [^|]* \| `([^`]*)` \| (人形|鳍骨|岩壳) \| ([^|]*) \|')


def build() -> dict:
    by_enemy, keys, review = {}, defaultdict(Counter), []
    main = False
    for line in SRC.read_text(encoding='utf-8').splitlines():
        if line.startswith('## '):
            main = line.startswith('## 西游战斗引用及运行时记录')
            continue
        m = ROW.match(line) if main else None
        if not m:
            continue
        eid, key, prof, note = m.group(1), m.group(2), NAMES[m.group(3)], m.group(4).strip()
        by_enemy[eid] = prof
        keys[key][prof] += 1
        if note.startswith('需'):
            review.append(int(eid))
    by_key = {k: c.most_common(1)[0][0] for k, c in sorted(keys.items())}
    return {
        'schema_version': 1,
        'by_enemy': dict(sorted(by_enemy.items(), key=lambda kv: int(kv[0]))),
        'by_key': by_key,
        'review': sorted(set(review)),
    }


def main() -> int:
    text = json.dumps(build(), ensure_ascii=False, indent=1) + '\n'
    if '--check' in sys.argv:
        ok = OUT.exists() and OUT.read_text(encoding='utf-8') == text
        print('profiles.json 最新' if ok else 'profiles.json 过期，重跑本脚本')
        return 0 if ok else 1
    OUT.write_text(text, encoding='utf-8')
    d = json.loads(text)
    print(f"写出 {OUT.name}：敌人 {len(d['by_enemy'])}，外观键 {len(d['by_key'])}，待复核 {len(d['review'])}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
