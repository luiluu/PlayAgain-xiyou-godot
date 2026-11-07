#!/usr/bin/env python3
"""按祖先链给「没执行到」的簇合成有状态变体（cc 八戒 events11，沿用 events10 的做法）。

事件写法覆盖.py --missed 的簇只给最近那道门的预设；门外面还有别的条件／选项时，要把整条祖先链的开门预设合到一起，
才能在同一次运行里一路走进去。本工具对每个簇：沿目标实例的上层分支头（111／411／402）逐个取 open_preset，
内层覆盖外层，合成一个变体（base＝页，tag＝--tag_序号）。再按 (页, 预设) 去重，并去掉已有变体里有的相同预设。
随机门（122 随机）不在这里管，另用 random_seq 变体。

  事件祖先预设.py --missed-json 簇.json --tag w1 [--min 3] [--limit N] [--dry-run]
  事件祖先预设.py --prune --cur 本.json --tag w1 --targets 目标.json [--states event_states.json]
      删掉 --tag 变体里目标位置本轮仍没执行到的（生成时用 --targets 写出）。给了 --states 时口径同 事件空绿扫描.zero_effect：
      目标没执行到、但文字轨迹和基础用例不同（走进了别的对话）的变体留下当文字对照（审查 50 P3-1；--old-zero-effect 回到旧口径）。
"""
import argparse
import importlib.util
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
P = HERE / 'event_presets.json'
spec = importlib.util.spec_from_file_location('cov', HERE / '事件写法覆盖.py')
cov = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cov)
_spec = importlib.util.spec_from_file_location('empty_scan', HERE / '事件空绿扫描.py')
scan = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(scan)


def merge_into(out, add):
    for k, v in add.items():
        if k == 'answers':
            out['answers'] = list(v)
        elif k == 'actors':   # 按角色深合并（同一角色的 skills／armors 各自并起来，不互相覆盖；八戒 DR w14）
            for aid, spec in v.items():
                merge_into(out.setdefault('actors', {}).setdefault(aid, {}), spec)
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


def trace_var(lst, j, p):
    """条件变量若在门前被 122 从游戏数据（物品／武器／防具数量、金钱）赋值，直接设预设变量会被覆盖：
    改成设那个数据（物品 items、武器 weapons、防具 armors、金钱 gold）。"""
    vs = p.get('variables')
    if not vs or len(vs) != 1:
        return p
    vid, val = int(next(iter(vs))), next(iter(vs.values()))
    for k in range(j - 1, -1, -1):
        c = lst[k]
        if int(c['code']) != 122:
            continue
        q = c['parameters']
        if int(q[0]) <= vid <= int(q[1]):
            if int(q[2]) == 0 and int(q[3]) == 3:
                t = int(q[4])
                if t in (0, 1, 2) and int(val) >= 0:
                    key = {0: 'items', 1: 'weapons', 2: 'armors'}[t]
                    return {key: {str(q[5]): int(val)}}
                if t == 7 and int(q[5]) == 2:
                    return {'gold': int(val)}
                if t == 7 and int(q[5]) == 4 and int(val) >= 0:
                    return {'playtime': int(val)}
            if int(q[2]) == 0 and int(q[3]) == 4 and str(q[4]).strip().rstrip(';').strip() == '$gameSystem.playtime()' and int(val) >= 0:
                return {'playtime': int(val)}   # events14：122 脚本「$gameSystem.playtime();」
            if int(q[2]) == 0 and int(q[3]) == 2 and isinstance(val, (int, float)):
                # 随机赋值（DR）：门前只有这一条 122 随机时，用 random_seq 让它抽到 val（MV：min + floor(random × (max−min+1))）
                # w14：门前有多条 122 随机时，按执行顺序数位置——只数祖先链在门的祖先链里的那些（同一路径上必然先执行的），
                # 每条按变量个数各取一个随机数；目标那条之前的位置填 0.5（同两边不给序列时的默认值）。旁支里的随机数、
                # 117 调用的公共事件里的随机数会挪位置，合成后目标没走到的照旧剪掉。
                lo, hi = int(q[4]), int(q[5])
                if not (lo <= int(val) <= hi and int(val) == val):
                    return p
                anc = set(chain(lst, j, None)) | {j}
                pos = 0
                for x in range(k):
                    cx = lst[x]
                    if int(cx['code']) == 122 and int(cx['parameters'][3]) == 2 and set(chain(lst, x, None)) <= anc:
                        pos += int(cx['parameters'][1]) - int(cx['parameters'][0]) + 1
                if not set(chain(lst, k, None)) <= anc:
                    return p
                pos += vid - int(q[0])
                return {'_rand': {pos: round((int(val) - lo + 0.5) / (hi - lo + 1), 6)}}
            return p
    return p


def synth(lst, first, loc):
    """cluster 第一个实例 first 的祖先链合成预设；返回 (预设, 没法开的门数)。"""
    pre, bad = {}, 0
    for j in chain(lst, first, loc):
        code = int(lst[j]['code'])
        if code in (111, 411, 402, 602, 603):   # 602／603 战斗结果门：battleResult（八戒 interp4）
            p = cov.open_preset(lst, j, loc)
            if p is not None and code in (111, 411):
                p = trace_var(lst, j, p)
            if p is None:
                bad += 1
            elif '_rand' in p and any(pre.get('_rand', {}).get(i, v) != v for i, v in p['_rand'].items()):
                bad += 1   # 两道随机门要同一个位置抽不同的数
            else:
                merge_into(pre, p)
    # 新源 installBossDifficultyRuntime 包了 addActor：超强者在地狱（难度 9）以下进不了队，参照探针摆预设时就弹
    # 「超强者仅限地狱及以上难度获取。」、人也没进队；重制摆预设不走这层，于是对不上（八戒 DR：w5 四例）。预设里有超强者进队就带上难度 9。
    if '_rand' in pre:   # 位置→随机数，排成序列，空位填 0.5
        r = pre.pop('_rand')
        pre['random_seq'] = [r.get(i, 0.5) for i in range(max(r) + 1)]
    if 'difficulty' not in pre and any(i in super_ids() for i in pre.get('party', [])):
        pre['difficulty'] = 9
    return pre, bad


_SUPER = None


def super_ids():
    """角色备注带 <KyoTier:超强者>／<CodexSuperStrong> 的（同 XItemMarks.super_strong_ids 认标签的那一支）。"""
    global _SUPER
    if _SUPER is None:
        rows = json.loads((cov.GEN / 'db/Actors.json').read_text())
        pat = re.compile(r'<KyoTier:\s*超强者>|<CodexSuperStrong>', re.I)
        _SUPER = {int(a['id']) for a in rows if a and pat.search(a.get('note') or '')}
    return _SUPER


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--missed-json')
    ap.add_argument('--tag')
    ap.add_argument('--min', type=int, default=3)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--skip-bad', action='store_true', help='祖先链上有开不了的门（playtime、敌人条件等）的簇不出变体')
    ap.add_argument('--tried-presets', action='append', default=[], help='往轮的 event_presets.json（含后来剪掉的）：其中的 (页, 预设) 不再出')
    ap.add_argument('--prune', action='store_true')
    ap.add_argument('--tried', action='append', default=[], help='往轮的簇 JSON：按同法合成过（含后来剪掉的）的 (页, 预设) 不再出')
    ap.add_argument('--targets', help='生成时写出／剪枝时读入：变体号→目标位置')
    ap.add_argument('--cur')
    ap.add_argument('--states', help='剪枝时读入：本轮量出的 event_states.json；文字轨迹与基础用例不同的变体不剪')
    ap.add_argument('--old-zero-effect', action='store_true', help='回到旧口径：只看目标有没有执行到')
    a = ap.parse_args(argv)
    d = json.loads(P.read_text())
    cases = d['cases']
    if a.prune:
        c1 = set(json.loads(Path(a.cur).read_text())['executed'])
        tg = json.loads(Path(a.targets).read_text())
        states = {c['id']: c for c in json.loads(Path(a.states).read_text())['cases']} if a.states else {}
        traces = scan.base_traces() if states and not a.old_zero_effect else {}

        def text_kept(c):  # 同 事件空绿扫描.zero_effect 的文字半边：走进了别的对话就留下
            v = states.get(c['base'] + '#' + c['tag'])
            return bool(traces) and v is not None and traces.get(c['base']) is not None and v.get('trace') != traces[c['base']]
        keep = [c for c in cases if not c['tag'].startswith(a.tag + '_') or tg.get(c['base'] + '#' + c['tag']) in c1
                or c['base'] + '#' + c['tag'] not in tg or text_kept(c)]
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
    for pj in a.tried_presets:
        for c in json.loads(Path(pj).read_text())['cases']:
            seen.add((c['base'], json.dumps(c['preset'], sort_keys=True)))
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
            if a.skip_bad:
                continue
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
