#!/usr/bin/env python3
"""敌群战斗事件页有没有原版对照（cc events13，只读）：generated/db/Troops.json 每个敌群页的每条指令，
看 troop_event_probe（XIYOU_COVER=1 写的 .sandbox/troop_events_cover.json）和 xiyou_troop_events --coverage（Godot 侧，
四份场景各一个 JSON）有没有真执行到它。两边都给时「有对照」＝两边都执行到；只给一边就按那一边。

  敌群页覆盖.py --oracle <troop_events_cover.json> [--godot a.json b.json …] [--out 报告.md] [--json 结果.json]

没执行到的指令按「门」聚簇（同 事件写法覆盖.py --missed）：
- 敌群没进探针：整个敌群不在 troop_event_probe 的用例里（加进 troop_event_cases.cjs 的 TROOPS 就有开局两回合）；
- 页条件没满足：敌群在探针里但这页一条都没执行到，门＝页条件（回合 turnA+turnB·X、敌人 HP≤%、角色 HP≤%、开关、回合末）；
- 页内分支：门＝离它最近、本身执行到了的上层分支头（111 条件、411 否则、402 选项……）。
无条件页（五个条件都没勾）原版 Game_Troop.meetsConditions 直接不跑，单列不计。
写法键、续行跳过规则与 事件写法覆盖.py 相同。「原版走到、Godot 没走到」列成差异候选（Godot 五轮随机种子取并集，
反过来的 Godot 多走到的多是随机分支，只计数）。
"""
import argparse
import collections
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('event_cover', HERE / '事件写法覆盖.py')
ec = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ec)
GEN = HERE.parent / '01_Godot工程/modes/xiyou/generated'


def page_cond(c):
    """页条件的文字与类型（类型给汇总用：哪种预设能补）"""
    parts, kinds = [], []
    if c.get('turnEnding'):
        parts.append('回合末'); kinds.append('回合末')
    if c.get('turnValid'):
        a, b = int(c.get('turnA', 0)), int(c.get('turnB', 0))
        parts.append('回合 %d%s' % (a, '+%d·X' % b if b else ''))
        kinds.append('回合' if (a > 2 or b) else '回合≤2')
    if c.get('enemyValid'):
        parts.append('敌人 %d HP≤%d%%' % (int(c['enemyIndex']), int(c['enemyHp'])))
        kinds.append('敌人HP')
    if c.get('actorValid'):
        parts.append('角色 %d HP≤%d%%' % (int(c['actorId']), int(c['actorHp'])))
        kinds.append('角色HP')
    if c.get('switchValid'):
        parts.append('开关 %d' % int(c['switchId']))
        kinds.append('开关')
    return '、'.join(parts), '+'.join(kinds)


def troop_pages():
    for t in json.loads((GEN / 'db/Troops.json').read_text()):
        if not t:
            continue
        for pi, page in enumerate(t.get('pages', [])):
            lst = page.get('list', [])
            if any(int(c['code']) not in ec.SKIP for c in lst):
                yield int(t['id']), pi, page, lst


def load_union(paths):
    out = set()
    for p in paths:
        d = json.loads(Path(p).read_text())
        if 'executed' in d:
            out |= set(d['executed'])
        for v in d.get('byCase', {}).values():
            out |= set(v)
    return out


def analyse(oracle: set, godot, probe_troops: set):
    executed = oracle & godot if godot is not None else oracle
    rows = {}
    clusters = {}
    totals = collections.Counter()
    for tid, pi, page, lst in troop_pages():
        loc = 't%dp%d' % (tid, pi)
        text, kind = page_cond(page.get('conditions', {}))
        entered = any(('%s:%d' % (loc, i)) in executed for i in range(len(lst)))
        for i, c in enumerate(lst):
            if int(c['code']) in ec.SKIP:
                continue
            k = ec.key_of(lst, i)
            r = rows.setdefault(k, {'key': k, 'count': 0, 'covered': 0, 'examples': []})
            r['count'] += 1
            at = '%s:%d' % (loc, i)
            if at in executed:
                r['covered'] += 1
                totals['执行到'] += 1
                continue
            if not kind:
                totals['无条件页'] += 1
                continue
            if len(r['examples']) < 4:
                r['examples'].append(at)
            if tid not in probe_troops:
                ck, why, gkind = ('troop', tid), '敌群没进探针', '敌群没进探针'
            elif not entered:
                ck, why, gkind = ('page', tid, pi), '页条件：' + text, '页条件·' + kind
            else:
                g = ec.gate_of(lst, i, executed, loc)
                if g is None:
                    ck, why, gkind = ('page', tid, pi), '页条件：' + text, '页条件·' + kind
                else:
                    desc = ec.describe_gate(lst, g)
                    ck, why, gkind = ('gate', tid, pi, g), desc, '页内·' + desc.split(' ')[0] + (
                        '·' + ec.COND.get(int(lst[g]['parameters'][0]), '?') if int(lst[g]['code']) == 111 else '')
            cl = clusters.setdefault(ck, {'where': loc if ck[0] != 'troop' else 't%d' % tid, 'gate': why, 'kind': gkind,
                                          'troop': tid, 'instances': 0, 'keys': collections.Counter()})
            if ck[0] != 'troop' and ck[0] != 'page':
                cl['gateAt'] = '%s:%d' % (loc, ck[3])
            cl['instances'] += 1
            cl['keys'][k] += 1
            totals['没执行到'] += 1
    by_kind = collections.Counter()
    for cl in clusters.values():
        by_kind[cl['kind']] += cl['instances']
    cl_list = sorted(clusters.values(), key=lambda c: (-c['instances'], c['where']))
    for cl in cl_list:
        cl['keys'] = dict(cl['keys'].most_common(6))
    return sorted(rows.values(), key=lambda r: (r['covered'] > 0, -r['count'], r['key'])), cl_list, by_kind, totals


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--oracle', required=True, help='troop_event_probe XIYOU_COVER=1 写的 troop_events_cover.json')
    ap.add_argument('--godot', nargs='*', help='xiyou_troop_events --coverage 写的 JSON（可多份）')
    ap.add_argument('--cases', default=str(GEN / 'oracle/troop_events.json'), help='参照用例（取探针里有哪些敌群）')
    ap.add_argument('--out')
    ap.add_argument('--json')
    ap.add_argument('--top', type=int, default=40)
    a = ap.parse_args(argv)
    oracle = load_union([a.oracle])
    godot = load_union(a.godot) if a.godot else None
    probe = {int(c['troop']) for c in json.loads(Path(a.cases).read_text())['cases']}
    rows, clusters, by_kind, totals = analyse(oracle, godot, probe)
    tp = {(t, p) for t, p, _, _ in troop_pages()}
    lines = ['# 敌群页覆盖（敌群页覆盖.py）', '',
             '- 敌群页：%d 个敌群、%d 页；探针里的敌群 %d 个' % (len({t for t, _ in tp}), len(tp), len(probe)),
             '- 指令：执行到 %d、没执行到 %d、无条件页（原版不跑）%d' % (totals['执行到'], totals['没执行到'], totals['无条件页']),
             '- 「有对照」＝' + ('原版与 Godot 都执行到' if godot is not None else '原版执行到（没给 Godot 覆盖）')]
    if godot is not None:
        only_o = sorted(x for x in oracle - godot if x.startswith('t'))
        only_g = sorted(x for x in godot - oracle if x.startswith('t'))
        lines += ['- 原版走到、Godot 没走到（差异候选）%d 条；Godot 多走到 %d 条（多为五轮随机分支）' % (len(only_o), len(only_g))]
    lines += ['', '## 没执行到按门型汇总', '', '| 门型 | 实例 |', '|---|---|']
    lines += ['| %s | %d |' % kv for kv in by_kind.most_common()]
    lines += ['', '## 簇（实例多的在前，前 %d）' % a.top, '', '| 位置 | 门 | 实例 | 主要写法 |', '|---|---|---|---|']
    for cl in clusters[:a.top]:
        lines.append('| %s | %s | %d | %s |' % (cl.get('gateAt', cl['where']), cl['gate'], cl['instances'],
                                                 '；'.join('%s×%d' % kv for kv in list(cl['keys'].items())[:3])))
    if godot is not None and only_o:
        lines += ['', '## 原版走到、Godot 没走到（前 40）', ''] + ['- ' + x for x in only_o[:40]]
    text = '\n'.join(lines) + '\n'
    if a.out:
        Path(a.out).write_text(text)
    else:
        print(text)
    if a.json:
        Path(a.json).write_text(json.dumps({'totals': totals, 'byKind': by_kind, 'clusters': clusters, 'keys': rows,
                                            'oracleOnly': only_o if godot is not None else None}, ensure_ascii=False, indent=1))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
