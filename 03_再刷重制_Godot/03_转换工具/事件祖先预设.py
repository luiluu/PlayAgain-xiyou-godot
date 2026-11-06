#!/usr/bin/env python3
"""按祖先链给「没执行到」的簇合成有状态变体（cc 八戒 events11，沿用 events10 的做法）。

事件写法覆盖.py --missed 的簇只给最近那道门的预设；门外面还有别的条件／选项时，要把整条祖先链的开门预设合到一起，
才能在同一次运行里一路走进去。本工具对每个簇：沿目标实例的上层分支头（111／411／402）逐个取 open_preset，
内层覆盖外层，合成一个变体（base＝页，tag＝--tag_序号）。再按 (页, 预设) 去重，并去掉已有变体里有的相同预设。
随机门（122 随机）不在这里管，另用 random_seq 变体。

  事件祖先预设.py --missed-json 簇.json --tag w1 [--min 3] [--limit N] [--dry-run]
  事件祖先预设.py --prune --cur 本.json --tag w1 --targets 目标.json   删掉 --tag 变体里目标位置本轮仍没执行到的（生成时用 --targets 写出）
"""
import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
P = HERE / 'event_presets.json'
spec = importlib.util.spec_from_file_location('cov', HERE / '事件写法覆盖.py')
cov = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cov)


def merge_into(out, add):
    for k, v in add.items():
        if k == 'answers':
            out['answers'] = list(v)
        elif isinstance(v, dict):
            out.setdefault(k, {}).update(v)
        elif isinstance(v, list):
            out[k] = sorted(set(out.get(k, [])) | set(v))
        else:
            out[k] = v


def chain(lst, i, loc):
    """目标 i 的祖先分支头下标，从外到里。"""
    ind = int(lst[i].get('indent', 0))
    heads = []
    j = i - 1
    while j >= 0 and ind > 0:
        if int(lst[j].get('indent', 0)) == ind - 1:
            heads.append(j)
            ind -= 1
        j -= 1
    heads.reverse()
    return heads


def synth(lst, first, loc):
    """cluster 第一个实例 first 的祖先链合成预设；返回 (预设, 没法开的门数)。"""
    pre, bad = {}, 0
    for j in chain(lst, first, loc):
        code = int(lst[j]['code'])
        if code in (111, 411, 402):
            p = cov.open_preset(lst, j, loc)
            if p is None:
                bad += 1
            else:
                merge_into(pre, p)
    return pre, bad


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--missed-json')
    ap.add_argument('--tag')
    ap.add_argument('--min', type=int, default=3)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--prune', action='store_true')
    ap.add_argument('--tried', action='append', default=[], help='往轮的簇 JSON：按同法合成过（含后来剪掉的）的 (页, 预设) 不再出')
    ap.add_argument('--targets', help='生成时写出／剪枝时读入：变体号→目标位置')
    ap.add_argument('--cur')
    a = ap.parse_args(argv)
    d = json.loads(P.read_text())
    cases = d['cases']
    if a.prune:
        c1 = set(json.loads(Path(a.cur).read_text())['executed'])
        tg = json.loads(Path(a.targets).read_text())
        keep = [c for c in cases if not c['tag'].startswith(a.tag + '_') or tg.get(c['base'] + '#' + c['tag']) in c1
                or c['base'] + '#' + c['tag'] not in tg]
        print('删掉目标仍没执行到的变体', len(cases) - len(keep))
        d['cases'] = keep
        P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
        return 0
    lists = dict(cov.locations())
    clusters = json.loads(Path(a.missed_json).read_text())['clusters']
    clusters = [c for c in clusters if c['preset'] and c['n'] >= a.min]
    clusters.sort(key=lambda c: (-c['n'], c['loc']))
    have = {(c['base'], json.dumps(c['preset'], sort_keys=True)) for c in cases}
    new, seen, bad_n = [], set(), 0
    for tj in a.tried:
        for c in json.loads(Path(tj).read_text())['clusters']:
            if c['preset'] and c['n'] >= a.min and c['loc'] in lists:
                pre, _ = synth(lists[c['loc']], c['first'], c['loc'])
                if pre:
                    seen.add((c['loc'], json.dumps(pre, sort_keys=True)))
    for c in clusters:
        lst = lists.get(c['loc'])
        if lst is None:
            continue
        pre, bad = synth(lst, c['first'], c['loc'])
        if bad:
            bad_n += 1
        if not pre:
            continue
        key = (c['loc'], json.dumps(pre, sort_keys=True))
        if key in have or key in seen:
            continue
        seen.add(key)
        new.append({'base': c['loc'], 'preset': pre, 'n': c['n'], 'target': '%s:%d' % (c['loc'], c['first'])})
        if a.limit and len(new) >= a.limit:
            break
    print('簇', len(clusters), '新变体', len(new), '链上有开不了的门', bad_n)
    if a.dry_run:
        return 0
    out = [{'base': x['base'], 'tag': '%s_%d' % (a.tag, i + 1), 'preset': x['preset']} for i, x in enumerate(new)]
    d['cases'] = cases + out   # 追加在末尾
    if a.targets:
        Path(a.targets).write_text(json.dumps({'%s#%s' % (o['base'], o['tag']): x['target'] for o, x in zip(out, new)}, ensure_ascii=False))
    P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
