#!/usr/bin/env python3
"""按「门」给事件对照加一轮有状态变体（cc 八戒 events8）。

一轮的做法：
  1. 跑 xiyou_event_compare --coverage=本轮.json（第一轮前先跑一次当底数）；
  2. 事件写法覆盖.py --coverage 本轮.json --missed 126,128,… --suggest 候选.json；
  3. 本工具：去掉上一轮（--drop-tag 前缀）里本轮没带来任何新执行的变体，再按候选加新变体写回 event_presets.json；
  4. 补跑事件状态探针.py --force，再回到 1 比对、量覆盖。

门是上一轮变体才走到的（底数覆盖里没有这个门），新预设叠在该用例最后一个 e8* 变体的预设上（嵌套的门一层层打开）。
新变体插在 cases 开头（和别的车道往末尾追加的分开，合并时不冲突）。每个用例每轮最多 --per 个（tag、tag2、tag3…）。

  事件预设加一轮.py --prev 上轮.json --cur 本轮.json --suggest 候选.json --tag e8c [--drop-tag e8b] [--base 底数.json]
                   [--min 2] [--per 8]

只出报告、不改预设（tools75）：按 tag 前缀统计每个变体比基础用例新增执行了几条指令，列出零贡献的变体。
要 --coverage 跑出的 byCase（用例号含 #变体 → 该例执行到的「位置:下标」）。
  新增＝变体执行到、基础用例（不带 #）没执行到的；独有＝变体执行到、同一基础用例的别的用例（基础与其他变体）都没执行到的。
  零贡献＝新增为 0（这个变体没走得比基础更深）；独有为 0 另列（走得深，但别的变体都覆盖了，删它不丢覆盖）。
  前缀默认按 tag 去掉轮内序号归组（o4_3→o4、e8b2→e8b、a1→a1），--prefix 只看以它开头的 tag（可给多个）。
  事件预设加一轮.py --report 本轮.json [--prefix e8b o4] [--json 报告.json] [--list 50]
"""
import argparse
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent / 'event_presets.json'


def executed(path):
    return set(json.loads(Path(path).read_text())['executed'])


def merge(base, add):
    out = json.loads(json.dumps(base))
    for k, v in add.items():
        if k == 'actors':
            for a, spec in v.items():
                sp = out.setdefault('actors', {}).setdefault(a, {})
                sp['skills'] = sorted(set(sp.get('skills', [])) | set(spec.get('skills', [])))
        elif isinstance(v, dict):
            out.setdefault(k, {}).update(v)
        elif isinstance(v, list):
            out[k] = sorted(set(out.get(k, [])) | set(v))
        else:
            out[k] = v
    return out


def tag_group(tag):
    """轮内序号去掉：o4_3→o4（下划线序号）；e8b2→e8b（字母数字字母后再跟的数字，事件预设加一轮的 tag2、tag3）；a1、e8 不动。"""
    m = re.match(r'^(.+?)_\d+$', tag)
    if m:
        return m[1]
    m = re.match(r'^([A-Za-z]+\d+[A-Za-z]+)\d+$', tag)
    return m[1] if m else tag


def contribution(by_case, prefixes=()):
    """byCase → 每个变体的 {id, base, tag, group, n, new, own}，按 base、tag 排；基础用例没进 byCase 的记 base_missing。"""
    sibs = {}
    for cid, keys in by_case.items():
        sibs.setdefault(cid.split('#', 1)[0], []).append((cid, set(keys)))
    rows = []
    for cid, keys in by_case.items():
        if '#' not in cid:
            continue
        base, tag = cid.split('#', 1)
        if prefixes and not any(tag.startswith(p) for p in prefixes):
            continue
        mine = set(keys)
        base_keys = set(by_case.get(base, ()))
        others = set().union(*[k for c, k in sibs[base] if c != cid]) if len(sibs[base]) > 1 else set()
        rows.append({'id': cid, 'base': base, 'tag': tag, 'group': tag_group(tag), 'n': len(mine),
                     'new': len(mine - base_keys), 'own': len(mine - others), 'base_missing': base not in by_case})
    rows.sort(key=lambda r: (r['base'], r['tag']))
    return rows


def report(rows):
    groups = {}
    for r in rows:
        g = groups.setdefault(r['group'], {'group': r['group'], 'variants': 0, 'new': 0, 'own': 0, 'zero': 0, 'zero_own': 0})
        g['variants'] += 1
        g['new'] += r['new']
        g['own'] += r['own']
        g['zero'] += r['new'] == 0
        g['zero_own'] += r['own'] == 0
    return sorted(groups.values(), key=lambda g: (-g['variants'], g['group']))


def run_report(a):
    by_case = json.loads(Path(a.report).read_text()).get('byCase')
    if not by_case:
        print('覆盖文件里没有 byCase（要 xiyou_event_compare --coverage= 跑出的新格式）')
        return 2
    rows = contribution(by_case, a.prefix or ())
    groups = report(rows)
    print('%-10s %6s %8s %8s %6s %8s' % ('前缀', '变体', '新增合计', '独有合计', '零贡献', '独有为0'))
    for g in groups:
        print('%-10s %6d %8d %8d %6d %8d' % (g['group'], g['variants'], g['new'], g['own'], g['zero'], g['zero_own']))
    zero = [r for r in rows if r['new'] == 0]
    dup = [r for r in rows if r['new'] > 0 and r['own'] == 0]
    print('\n零贡献（新增 0，比基础用例没多走一条）%d 个%s' % (len(zero), '' if a.list < 0 or len(zero) <= a.list else '，只列前 %d 个' % a.list))
    for r in zero[:None if a.list < 0 else a.list]:
        print('  %s%s' % (r['id'], '（基础用例不在覆盖里）' if r['base_missing'] else ''))
    print('独有为 0（比基础多走了，但同基础的别的用例都走到了）%d 个' % len(dup))
    missing = sorted({r['base'] for r in rows if r['base_missing']})
    if missing:
        print('⚠ 基础用例不在 byCase 里（新增按全部算）：%d 个，如 %s' % (len(missing), '、'.join(missing[:5])))
    if a.json:
        Path(a.json).write_text(json.dumps({'groups': groups, 'variants': rows}, ensure_ascii=False, indent=1) + '\n')
        print('写了', a.json)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--report', help='只出贡献报告（覆盖 JSON，要有 byCase），不改预设')
    ap.add_argument('--prefix', nargs='+', help='--report 只看以这些开头的 tag')
    ap.add_argument('--json', help='--report 另写一份 JSON')
    ap.add_argument('--list', type=int, default=50, help='--report 零贡献最多列几个（-1 全列）')
    ap.add_argument('--prev')
    ap.add_argument('--cur')
    ap.add_argument('--suggest')
    ap.add_argument('--tag')
    ap.add_argument('--drop-tag')
    ap.add_argument('--base', help='判断「门是不是上一轮变体才走到的」用的底数覆盖（默认 --prev）')
    ap.add_argument('--min', type=int, default=2)
    ap.add_argument('--per', type=int, default=8)
    a = ap.parse_args(argv)
    if a.report:
        return run_report(a)
    if not (a.prev and a.cur and a.suggest and a.tag):
        ap.error('加一轮要 --prev --cur --suggest --tag（只出报告用 --report）')
    c0, c1 = executed(a.prev), executed(a.cur)
    c0base = executed(a.base) if a.base else c0
    gain = {x.split(':')[0] for x in c1 - c0}
    d = json.loads(P.read_text())
    cases = d['cases']
    if a.drop_tag:
        before = len(cases)
        cases = [c for c in cases if not (c['tag'].startswith(a.drop_tag) and c['base'] not in gain)]
        print('去掉没增益的变体', before - len(cases))
    e8 = {}
    for c in cases:
        if c['tag'].startswith('e8'):
            e8.setdefault(c['base'], []).append(c)
    have = {(c['base'], c['tag']) for c in cases}
    seen, per = {}, {}
    for x in json.loads(Path(a.suggest).read_text()):
        kk = per.get(x['base'], 0)
        tag = a.tag if kk == 0 else '%s%d' % (a.tag, kk + 1)
        if kk >= a.per or x['n'] < a.min or (x['base'], tag) in have:
            continue
        loc, gi = x['gate'].split(' ')[0].rsplit(':', 1)
        pre = dict(x['preset'])
        if '%s:%s' % (loc, gi) not in c0base and x['base'] in e8:
            pre = merge(e8[x['base']][-1]['preset'], pre)
        if any(c['preset'] == pre for c in e8.get(x['base'], [])):
            continue
        if any(v['base'] == x['base'] and v['preset'] == pre for v in seen.values()):
            continue
        per[x['base']] = kk + 1
        seen[(x['base'], tag)] = {'base': x['base'], 'tag': tag, 'preset': pre, 'n': x['n']}
    new = [{k: v[k] for k in ('base', 'tag', 'preset')} for v in sorted(seen.values(), key=lambda v: -v['n'])]
    d['cases'] = new + cases
    P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
    print('加了', len(new))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
