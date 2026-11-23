#!/usr/bin/env python3
"""T392 对比表：T363 最终表＋第三遍真打（d3）对 T392（19 层吸血封顶＋P2-1 band 校准）。
「后」重打了血量变了的层和带 3805 厄运剥夺的守层者层（19 f19_jianxian_*；7～28、33 v1a／v1b；r2 补 29～32 w1a／w1b；34 取第二遍 v2；29、30 band 重校后取 w2a／w2b）；
其余层（1～6、8～15、17、18、20、21、25、26）表没变、守层者也没有 3805，后＝前。另列 19 层五档各一组（f19_<难度>_*）。
用法（仓库根）：python3 00_项目管理/归档/交付截图/luiluu_t392/T392_量数/对比表生成.py，打印 Markdown。"""
import json, statistics as st, subprocess
from pathlib import Path
HERE = Path(__file__).resolve().parent
OLD = HERE.parent.parent / 'luiluu_t363' / 'T363_量数'
TABLE = '03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/balance_table.json'
TURNS = {'xunchang': 6, 'jianxian': 8, 'jiusi': 10, 'lianyu': 12, 'zhengdao': 15}
NAMES = {'xunchang': '寻常', 'jianxian': '艰险', 'jiusi': '九死', 'lianyu': '炼狱', 'zhengdao': '证道'}


def duel(paths):
    by = {}
    for p in paths:
        if Path(p).exists():
            for r in json.load(open(p))['rows']:
                by.setdefault(int(r['floor']), []).extend(r.get('per', []))
    return by


def summ(per):
    nm = [p for p in per if p.get('team') != '奶妈队']
    hl = [p for p in per if p.get('team') == '奶妈队']
    w = [p for p in nm if p.get('won')]
    top = sorted(nm, key=lambda p: -float(p.get('dmg', 0)))[:max(1, len(nm) // 4)]   # 同 T363：每回合打得最多的四分之一＝强队
    tw = [p['turns'] for p in top if p.get('won')]
    return {'g': '%d/%d' % (len(w), len(nm)) if nm else '－', 'wavg': ('%.1f' % st.mean([p['turns'] for p in w])) if w else '－',
            'top': '%d/%d 均%s' % (len(tw), len(top), ('%.1f' % st.mean(tw)) if tw else '－') if nm else '－', 'tavg': st.mean(tw) if tw else None,
            'h': '%d/%d' % (len([p for p in hl if p.get('won')]), len(hl)) if hl else '－'}


def fmt(x):
    x = float(x)
    return ('%.1f万' % (x / 1e4)) if x >= 1e5 else ('%.3g' % x)


def main():
    root = HERE.parents[4]
    git = lambda ref: json.loads(subprocess.run(['git', 'show', '%s:%s' % (ref, TABLE)], capture_output=True, text=True, check=True, cwd=root).stdout)['guardian_phase4']
    oldt, newt = git('4ed357edd'), json.load(open(root / TABLE))['guardian_phase4']
    o = duel([OLD / 'd3_r6.json', OLD / 'd3_t298.json'])
    n = duel(sorted(HERE.glob('v1*_jianxian_*.json')) + [HERE / 'f19_jianxian_r6.json', HERE / 'f19_jianxian_t298.json'])
    n.update(duel(sorted(HERE.glob('w1*_jianxian_*.json'))))   # r2（T392 核 P1-1）：29～32 层守层者也放 3805，封顶后补打
    n.update(duel(sorted(HERE.glob('v2_jianxian_*.json'))))   # 第二遍只重打 34 层（v1 量出 4.5 回合矫枉过正，按 750 万再量），整层替换
    n.update(duel(sorted(HERE.glob('w2*_jianxian_*.json'))))   # r2：29、30 层封顶后强队太快，band 重校血量后再量，整层替换
    print('### 艰险 1～34 层（真打 2 存档链×4 队×2 种子＋奶妈队，40 回合带敌群事件；强队＝每回合打得最多的四分之一，目标 8±2）\n')
    print('| 层 | 血/回合 前 | **血/回合 后** | 普通胜/队 前 | **后** | 赢的均回合 前 | **后** | 强队¼ 前 | **强队¼ 后** | 奶妈队 前 | **后** | 重打 |')
    print('|' + '---|' * 12)
    for f in range(1, 35):
        k = str(f)
        so = summ(o.get(f, []))
        sn = summ(n[f]) if f in n else so
        print('| %d | %s | **%s** | %s | **%s** | %s | **%s** | %s | **%s** | %s | **%s** | %s |' % (
            f, fmt(oldt['hp_base'][k]), fmt(newt['hp_base'][k]), so['g'], sn['g'], so['wavg'], sn['wavg'], so['top'], sn['top'], so['h'], sn['h'], '是' if f in n else '－'))
    print('\n### 19 层五档（快照存档换成该档难度，阵容照存档；吸血封顶 pct 照表，目标＝本档回合±2）\n')
    print('| 难度 | 封顶 pct | 目标回合 | 普通胜/队 | 赢的均回合 | 强队¼ | 奶妈队 | 强队达标 |')
    print('|---|---|---|---|---|---|---|---|')
    pct = newt.get('lifesteal_cap', {}).get('pct', {})
    for key, t in TURNS.items():
        d = duel([HERE / ('f19_%s_r6.json' % key), HERE / ('f19_%s_t298.json' % key)])
        if 19 not in d:
            print('| %s | %s | %d | 没量 | | | | |' % (NAMES[key], pct.get(key), t))
            continue
        s = summ(d[19])
        ok = s['tavg'] is not None and t - 2 <= s['tavg'] <= t + 2
        print('| %s | %s%% | %d±2 | %s | %s | %s | %s | %s |' % (NAMES[key], pct.get(key), t, s['g'], s['wavg'], s['top'], s['h'], '✓' if ok else '✗'))


if __name__ == '__main__':
    main()
