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
"""
import argparse
import json
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


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--prev', required=True)
    ap.add_argument('--cur', required=True)
    ap.add_argument('--suggest', required=True)
    ap.add_argument('--tag', required=True)
    ap.add_argument('--drop-tag')
    ap.add_argument('--base', help='判断「门是不是上一轮变体才走到的」用的底数覆盖（默认 --prev）')
    ap.add_argument('--min', type=int, default=2)
    ap.add_argument('--per', type=int, default=8)
    a = ap.parse_args(argv)
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
