#!/usr/bin/env python3
"""T397：D242 封顶关／开配对汇总。读 04_验证/本地结果/t397/{g,m,k}_{off,on}_<链>[_<线>].json，
按（链、层、线、队、种子）配对；逐种子列通关率、倒下人次、都赢场回合比（开/关，几何平均）；≤3 回合的场（两边任一）单列。"""
import json, sys, math, glob, os, collections
R = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith('--') else '03_再刷重制_Godot/04_验证/本地结果/t397'

def load(kind, cfg):
    out = {}
    for p in glob.glob(f'{R}/{kind}_{cfg}_*.json'):
        tag = os.path.basename(p)[len(kind) + len(cfg) + 2:-5]  # r6 / r6_war
        chain, _, line = tag.partition('_')
        for row in json.load(open(p))['rows']:
            for f in row['fights']:
                key = (chain, int(row['floor']), line, str(f.get('label', '')), int(f.get('rep', 0)) // 100000)  # t239_rng＝种子×100000＋层
                out[key] = {'won': bool(f['won']), 'turns': int(f['turns']), 'downs': int(f['downs']), 'troop': row.get('troop')}
    return out

def gm(xs):
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else float('nan')

DETAIL = '--detail' in sys.argv

def table(kind, title, group):
    off, on = load(kind, 'off'), load(kind, 'on')
    keys = sorted(set(off) & set(on))
    print(f'\n### {title}（配对 {len(keys)} 场；关只有 {len(set(off)-set(on))}、开只有 {len(set(on)-set(off))} 场没配上）\n')
    print('| 分组 | 种子 | 场 | 通关 关→开 | 倒下人次均 关→开 | 都赢场回合比 开/关（场） | ≤3 回合场 | 胜负翻（关输开赢／关赢开输） |')
    print('|---|---|---|---|---|---|---|---|')
    groups = collections.defaultdict(list)
    for k in keys:
        if DETAIL:
            groups[(group(k), k[4])].append(k)
        groups[(group(k), '合')].append(k)
        groups[('全部·种子', k[4])].append(k)
        groups[('全部', '合')].append(k)
    def gkey(x):
        g, s = x
        return (g == '全部', str(g).zfill(6) if isinstance(g, str) else g, s == '合', s)
    for g, s in sorted(groups, key=lambda x: (x[0] == '全部', str(x[0]), x[1] == '合', str(x[1]))):
        ks = groups[(g, s)]
        fast = [k for k in ks if off[k]['turns'] <= 3 or on[k]['turns'] <= 3]
        main = [k for k in ks if k not in fast]
        n = len(main)
        if n == 0 and not fast:
            continue
        wo = sum(off[k]['won'] for k in main); wn = sum(on[k]['won'] for k in main)
        do = sum(off[k]['downs'] for k in main) / max(1, n); dn = sum(on[k]['downs'] for k in main) / max(1, n)
        both = [on[k]['turns'] / off[k]['turns'] for k in main if off[k]['won'] and on[k]['won']]
        up = sum(1 for k in main if not off[k]['won'] and on[k]['won']); dn2 = sum(1 for k in main if off[k]['won'] and not on[k]['won'])
        fw = f"{len(fast)}（胜 关{sum(off[k]['won'] for k in fast)}／开{sum(on[k]['won'] for k in fast)}）"
        print(f"| {g} | {s} | {n} | {wo}/{n}→{wn}/{n} | {do:.2f}→{dn:.2f} | {gm(both):.3f}（{len(both)}） | {fw} | {up}／{dn2} |")

table('g', '守层者战（10～33 层，两链×4 队×种子 1～3）', lambda k: f'{k[0]}·{k[1]:02d}层')
table('m', '小怪战（10／20／25 层遇敌敌群 63／476／501）', lambda k: f'{k[0]}·{k[1]:02d}层')
table('k', '骑士战（36 层本体，四线；r6 读 33 层档、t298 读 32 层档）', lambda k: f'{k[0]}·{k[2]}')
