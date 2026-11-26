# T527：T438 胜率 JSON → 三态判（胜／负／中止），中止场剔除后报胜率＋回合中位数，逐种子列；可并排对照 T501 那一轮。
# 中止＝既没赢也没全灭、且回合数 < max_turns（被事件结束）；超时＝打满 max_turns 没分胜负，算「没赢」。
# 用法：python3 胜率三态.py <目录> [<对照目录>]
import json, glob, os, sys, statistics
from collections import defaultdict

def load(d):
    agg = {}
    for f in sorted(glob.glob(os.path.join(d, '*.json'))):
        j = json.load(open(f)); mt = int(j['max_turns'])
        for t, x in j['templates'].items():
            for fl, v in x['floors'].items():
                groups = [v['cases']] if 'cases' in v else [g['cases'] for g in v['by_line'].values()]
                for cs in groups:
                    for c in cs:
                        st = '胜' if c['won'] else ('负' if c.get('lost') else ('超时' if c['turns'] >= mt else '中止'))
                        c = dict(c, state=st)
                        agg.setdefault((t, int(fl), c['line'] if int(fl) >= 35 else 'ALL'), []).append(c)
    return agg

def cell(cs):
    keep = [c for c in cs if c['state'] != '中止']
    ab = len(cs) - len(keep)
    w = sum(c['state'] == '胜' for c in keep)
    by = defaultdict(lambda: [0, 0, []])
    for c in keep:
        by[c['seed']][0] += c['state'] == '胜'; by[c['seed']][1] += 1; by[c['seed']][2].append(c['turns'])
    seeds = ' '.join(f"s{s} {by[s][0]}/{by[s][1]} 中位{statistics.median(by[s][2]):g}" for s in sorted(by))
    med = statistics.median([c['turns'] for c in keep]) if keep else float('nan')
    to = sum(c['state'] == '超时' for c in keep)
    return w, len(keep), ab, med, to, seeds

if __name__ == '__main__':
    cur = load(sys.argv[1]); base = load(sys.argv[2]) if len(sys.argv) > 2 else {}
    print('| 模板 | 层 | 线 | 本轮 胜/场（剔中止） | 中止 | 回合中位 | 超时 | 逐种子 | 对照 胜/场 | 对照回合中位 |')
    print('|---|---|---|---|---|---|---|---|---|---|')
    tot = defaultdict(lambda: [0, 0, 0]); btot = defaultdict(lambda: [0, 0])
    for k in sorted(cur):
        w, n, ab, med, to, seeds = cell(cur[k])
        tot[k[0]][0] += w; tot[k[0]][1] += n; tot[k[0]][2] += ab
        b = cell(base[k]) if k in base else None
        if b: btot[k[0]][0] += b[0]; btot[k[0]][1] += b[1]
        print(f"| {k[0]} | {k[1]} | {k[2]} | {w}/{n} | {ab} | {med:g} | {to} | {seeds} | {f'{b[0]}/{b[1]}' if b else '—'} | {f'{b[3]:g}' if b else '—'} |")
    print()
    for t in sorted(tot):
        print(f"{t}：本轮 {tot[t][0]}/{tot[t][1]}（中止剔除 {tot[t][2]}）" + (f"；对照 {btot[t][0]}/{btot[t][1]}" if t in btot else ''))
