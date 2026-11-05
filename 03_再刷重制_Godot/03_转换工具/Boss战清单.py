#!/usr/bin/env python3
"""剧情／副本 Boss 战清单与对照覆盖（cc 悟空 accept3，只读）。

扫切片全部地图事件页与公共事件里「战斗处理」（指令 301，指定敌群），按敌群汇总：来源事件、敌人、敌群事件页数、
能不能输（canLose 分支 601／602／603）、掉落条数，以及现有对照覆盖：
- 开场：mv_oracle/troop_event_probe.cjs 的 TROOPS（真实 BattleManager 跑两回合，tests/xiyou_troop_events 对照）；
- 胜后事件：generated/oracle/events.json 里该页用例记到这场战斗（event_probe 一律按胜利回调，xiyou_event_compare 对照）；
- 输的分支：event_probe 不走（只回调胜利），本表单列出来。
「Boss」按敌群：有敌群事件页（开场／血线脚本）或来源事件名／敌人名不是杂兵；守层者（楼层图 EV 进战）也列，标「楼层」。
用法：Boss战清单.py [--md 输出.md] [--json 输出.json] [--pick N]（--pick 给出还没开场对照、有敌群事件页的前 N 个）
"""
import argparse, json, re
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'


def load(p):
    return json.loads(Path(p).read_text())


def probe_troops():
    src = (HERE / 'mv_oracle/troop_event_probe.cjs').read_text()
    m = re.search(r'TROOPS\s*=\s*\[(.*?)\];', src, re.S)
    body = re.sub(r'//[^\n]*', '', m.group(1))
    # 不在 TROOPS 里、单独 run(敌群号, …) 的例（accept4：控尸者 160 的 preset／noPreset 两例）也算开场对照
    return {int(x) for x in re.findall(r'\d+', body)} | {int(x) for x in re.findall(r'\brun\((\d+)', src)}


def troop_pages(t):
    n = 0
    for pg in t.get('pages', []):
        if any(c['code'] != 0 for c in pg.get('list', [])):
            n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--md')
    ap.add_argument('--json')
    ap.add_argument('--pick', type=int, default=0)
    a = ap.parse_args()
    troops = load(GEN / 'db/Troops.json')
    enemies = load(GEN / 'db/Enemies.json')
    maps = {m['id']: m['name'] for m in load(GEN / 'db/MapInfos.json') if m}
    covered_open = probe_troops()
    ev_cases = load(GEN / 'oracle/events.json')['cases']
    battle_pages = defaultdict(set)  # troop -> 有胜后对照的页 id
    for c in ev_cases:
        for r in json.dumps(c).split('"t": "battle"')[1:]:
            mt = re.search(r'"troop": (\d+)', r)
            if mt:
                battle_pages[int(mt.group(1))].add(c.get('id', ''))
    uses = defaultdict(list)

    def scan(lst, src, floor):
        for i, cmd in enumerate(lst):
            if cmd['code'] == 301 and cmd['parameters'][0] == 0:
                p = cmd['parameters']
                lose = any(x['code'] == 602 and x['indent'] == cmd['indent'] for x in lst[i + 1:i + 400])
                uses[p[1]].append(dict(src=src, can_lose=bool(p[3]), lose_branch=lose, floor=floor))

    for f in sorted((GEN / 'maps').glob('Map*.json')):
        mid = int(f.stem[3:])
        m = load(f)
        for e in m['events']:
            if not e:
                continue
            for pi, pg in enumerate(e['pages']):
                scan(pg['list'], 'm%de%dp%d「%s」' % (mid, e['id'], pi, e['name']), '层' in maps.get(mid, ''))
    for ce in load(GEN / 'db/CommonEvents.json'):
        if ce:
            scan(ce['list'], 'ce%d「%s」' % (ce['id'], ce['name']), False)
    rows = []
    for tid, us in sorted(uses.items()):
        t = troops[tid] if tid < len(troops) and troops[tid] else None
        if not t:
            continue
        mem = [enemies[x['enemyId']] for x in t['members'] if x['enemyId'] < len(enemies) and enemies[x['enemyId']]]
        drops = sum(1 for en in mem for d in en.get('dropItems', []) if d.get('kind'))
        rows.append(dict(troop=tid, name=t['name'], enemies=[en['name'] for en in mem], pages=troop_pages(t), drops=drops,
                         floor=all(u['floor'] for u in us), uses=[u['src'] for u in us][:6], n_uses=len(us),
                         can_lose=any(u['can_lose'] for u in us), lose_branch=any(u['lose_branch'] for u in us),
                         open_cmp=tid in covered_open, win_cmp=bool(battle_pages.get(tid))))
    boss = [r for r in rows if r['pages'] > 0]
    lines = ['# 剧情／副本 Boss 战清单（自动生成，`03_转换工具/Boss战清单.py`）', '',
             '事件里指定敌群的战斗 %d 个敌群；其中有敌群事件页（开场／血线脚本）的 %d 个，开场已对照 %d 个；胜后事件已对照 %d 个；有「输了」分支的 %d 个。' % (
                 len(rows), len(boss), sum(r['open_cmp'] for r in boss), sum(r['win_cmp'] for r in boss), sum(r['lose_branch'] for r in boss)), '',
             '| 敌群 | 名称 | 敌人 | 敌群页 | 掉落 | 楼层 | 来源（前 2） | 开场对照 | 胜后对照 | 输分支 |', '| ---: | --- | --- | ---: | ---: | --- | --- | --- | --- | --- |']
    for r in boss:
        lines.append('| %d | %s | %s | %d | %d | %s | %s | %s | %s | %s |' % (
            r['troop'], r['name'].replace('|', '／'), '、'.join(r['enemies'][:3]).replace('|', '／'), r['pages'], r['drops'], '是' if r['floor'] else '',
            '、'.join(r['uses'][:2]).replace('|', '／'), '✓' if r['open_cmp'] else '**无**', '✓' if r['win_cmp'] else '无', '有' if r['lose_branch'] else ''))
    md = '\n'.join(lines) + '\n'
    if a.md:
        Path(a.md).write_text(md)
    if a.json:
        Path(a.json).write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    print('\n'.join(lines[:3]))
    if a.pick:
        cand = [r for r in boss if not r['open_cmp'] and not r['floor']]
        cand.sort(key=lambda r: (-r['pages'], -r['n_uses'], r['troop']))
        for r in cand[:a.pick]:
            print(r['troop'], r['name'], r['pages'], r['uses'][:2])


main()
