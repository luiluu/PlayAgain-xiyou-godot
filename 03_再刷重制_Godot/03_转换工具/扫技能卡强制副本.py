#!/usr/bin/env python3
"""T255：扫技能卡里 effects code 44 → 公共事件 → 强制行动(339)指向的技能，副本不在 skill_rework.json 卡里即缺口。
用法：python3 扫技能卡强制副本.py [--all]   --all 连不在卡里的技能也列（只读，不改任何文件）"""
import json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / '01_Godot工程/modes/xiyou'
DB = ROOT / 'generated/db'
sk = {x['id']: x for x in json.load(open(DB/'Skills.json')) if x}
ce = {x['id']: x for x in json.load(open(DB/'CommonEvents.json')) if x}
card = json.load(open(ROOT/'tianqi_data/skill_rework.json'))
cards = {**card.get('skills', {}), **card.get('new_skills', {})}

def forced(cid, seen=None):
    seen = seen or set()
    if cid in seen or cid not in ce: return set(), set()
    seen.add(cid); out = set(); calls = set()
    for c in ce[cid]['list']:
        if c['code'] == 339: out.add(c['parameters'][2])
        if c['code'] == 117:
            calls.add(c['parameters'][0])
            o, _ = forced(c['parameters'][0], seen); out |= o
    return out, calls

def removed(card_entry):
    return {tuple(e) for e in card_entry.get('effects_remove', [])}

def run(show_all):
    rows = []; no339 = set(); total44 = 0
    for sid, s in sk.items():
        for e in s.get('effects', []):
            if e['code'] != 44: continue
            if str(sid) not in cards and not show_all: continue
            total44 += 1
            f, _ = forced(e['dataId'])
            if not f: no339.add(e['dataId']); continue
            ent = cards.get(str(sid))
            for t in f:
                rows.append((sid, s['name'], e['dataId'], t, sk.get(t, {}).get('name', '?'),
                             str(t) in cards, ent is not None and (44, e['dataId']) in removed(ent),
                             (ent or {}).get('actor')))
    return rows, no339, total44

if __name__ == '__main__':
    rows, no339, n = run('--all' in sys.argv)
    print('扫到 code44 效果', n, '条；其中无 339 的公共事件', len(no339), '个')
    gap = [r for r in rows if not r[5] and not r[6]]
    print('强制放技能条目', len(rows), '；缺口（副本不在卡、也没 effects_remove）', len(gap))
    for r in rows:
        tag = '缺口' if (not r[5] and not r[6]) else ('已去' if r[6] else '副本在卡')
        print(tag, '技能', r[0], r[1], '| 公共事件', r[2], '| 副本', r[3], r[4], '| 角色', r[7])
