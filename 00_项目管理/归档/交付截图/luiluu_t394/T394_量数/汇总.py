#!/usr/bin/env python3
"""T394 汇总：baseline_dps --duel 的输出，按层×种子列胜/场，剔除「≤3 回合就团灭」的秒杀场单列（不进胜率）。
4 弱链（weak）只算上场 4 人全是弱者的（allWeak=true，同 T244）；普通链（norm）4 队全算（同 T363 d3）。
用法：python3 汇总.py <标签>=<结果目录里的前缀>…   例：修前=base 只修bug=fix1 修bug＋16=fix16
读 <前缀>_weak_a/b.json、<前缀>_norm_a/b.json（没有的跳过），结果目录默认 03_再刷重制_Godot/04_验证/本地结果/t394（--dir= 换）。"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
DIR = ROOT / '03_再刷重制_Godot/04_验证/本地结果/t394'
args = []
for a in sys.argv[1:]:
    if a.startswith('--dir='):
        DIR = Path(a[6:])
    else:
        args.append(a)
SEEDS = ('1', '2', '3')


def load(prefix, chain):
    rows = {}
    for part in ('a', 'b', 'c'):
        p = DIR / f'{prefix}_{chain}_{part}.json'
        if not p.exists():
            continue
        for r in json.load(open(p))['rows']:
            fs = [x for x in r['per'] if chain == 'norm' or x.get('allWeak')]
            rows.setdefault(int(r['floor']), []).extend(fs)
    return rows


def seed_of(x):
    return str(int(x['rng']) // 100000)


def kill(x):
    return (not x['won']) and int(x['turns']) <= 3


def cell(fs):
    k = [x for x in fs if not kill(x)]
    w = sum(1 for x in k if x['won'])
    s = sum(1 for x in fs if kill(x))
    return w, len(k), s


def fmt(w, n, s):
    t = f'{w}/{n}' if n else '－'
    return t + (f'（秒{s}）' if s else '')


def kinds(fs):
    out = {}
    for x in fs:
        for a in x.get('alien', []):
            k = a.split(':', 1)[1]
            out[k] = out.get(k, 0) + 1
    return '、'.join(f'{k}×{v}' for k, v in sorted(out.items())) or '无'


data = {}
for a in args:
    label, prefix = a.split('=', 1)
    data[label] = {c: load(prefix, c) for c in ('weak', 'norm')}

for chain, title in (('weak', '纯 4 弱（r7 链，allWeak）'), ('norm', '普通阵容（r6 链，4 队）')):
    print(f'\n### {title}：逐层逐种子 胜/场（秒＝≤3 回合团灭，单列、不进胜/场）\n')
    labels = list(data)
    print('| 层 | ' + ' | '.join(f'{l} s{s}' for l in labels for s in SEEDS) + ' | ' + ' | '.join(f'{l} 合计' for l in labels) + ' | 抽到的异化（第一列） |')
    print('|---|' + '---|' * (len(labels) * (len(SEEDS) + 1) + 1))
    floors = sorted(set().union(*[set(data[l][chain]) for l in labels]))
    seg = {}
    for fl in floors:
        cells = []
        tots = []
        for l in labels:
            fs = data[l][chain].get(fl, [])
            for s in SEEDS:
                cells.append(fmt(*cell([x for x in fs if seed_of(x) == s])))
            c = cell(fs)
            tots.append(fmt(*c))
            key = '10～30' if fl <= 30 else '31～33'
            g = seg.setdefault((l, key), [0, 0, 0])
            for i in range(3):
                g[i] += c[i]
        print(f'| {fl} | ' + ' | '.join(cells) + ' | ' + ' | '.join(tots) + f' | {kinds(data[labels[0]][chain].get(fl, []))} |')
    print(f'\n分段合计（{title}）：\n')
    print('| 数据 | 10～30 层 胜/场 | 胜率 | 31～33 层 胜/场 | 胜率 | 31～33 秒杀场 |')
    print('|---|---|---|---|---|---|')
    for l in labels:
        lo = seg.get((l, '10～30'), [0, 0, 0])
        hi = seg.get((l, '31～33'), [0, 0, 0])
        pct = lambda g: f'{100 * g[0] / g[1]:.0f}%' if g[1] else '－'
        print(f'| {l} | {lo[0]}/{lo[1]} | {pct(lo)} | {hi[0]}/{hi[1]} | {pct(hi)} | {hi[2]} |')
