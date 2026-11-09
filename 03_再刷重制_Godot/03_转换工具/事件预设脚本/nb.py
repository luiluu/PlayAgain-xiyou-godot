"""邻居变体：没执行到的簇，门头（111／411）已被某个用例执行到——拿那个用例（供体）的预设，叠上开门预设
（经 事件祖先预设.trace_var 倒推：+=常量、X=变量Y、物品数、随机位置），出变体。
用法：nb.py cov.json missed.json tag [--skip-ce bonly.json] [--write]
  - 门是 402（选项）的不管（答案前缀要另算）
  - 随机：trace_var 给 _rand{位置:值} 时，在供体的 random_seq 上改那一位（不够长补 0.5）
  - 去重：event_presets 现有＋tried.json（全部历史版本）里同 (页, 预设) 的不出"""
import json, sys, copy, importlib.util
from pathlib import Path
T = Path(__file__).resolve().parent.parent
W = Path(__import__('os').environ.get('SA_WORK', '.'))
sp = importlib.util.spec_from_file_location('anc', T / '事件祖先预设.py'); anc = importlib.util.module_from_spec(sp); sp.loader.exec_module(anc)
cov = anc.cov
covj = json.load(open(sys.argv[1]))
bc = covj['byCase']
clusters = json.load(open(sys.argv[2]))['clusters']
tag = sys.argv[3]
bonly = set()
if '--skip-ce' in sys.argv:
    bonly = set(json.load(open(sys.argv[sys.argv.index('--skip-ce') + 1])))
lists = dict(cov.locations())
d = json.loads(anc.P.read_text())
pre = {c['base'] + '#' + c['tag']: c['preset'] for c in d['cases']}
pre.update({c['base']: {} for c in d['cases']})
seen = {(c['base'], json.dumps(c['preset'], sort_keys=True)) for c in d['cases']}
for c in json.load(open(W / 'tried.json'))['cases']:
    seen.add((c['base'], json.dumps(c['preset'], sort_keys=True)))
# 位置:下标 → 执行到它的用例
who = {}
for k, v in bc.items():
    for x in v:
        who.setdefault(x, []).append(k)


def size(p):
    return len(json.dumps(p or {}))


out, targets, skipped = [], {}, {}
for cl in clusters:
    loc, g = cl['loc'], cl['gate']
    if loc.startswith('ce') and int(loc[2:]) in bonly:
        skipped['战斗专用'] = skipped.get('战斗专用', 0) + 1; continue
    if g is None or g < 0 or not cl.get('preset'):
        skipped['无预设'] = skipped.get('无预设', 0) + 1; continue
    lst = lists[loc]
    code = int(lst[g]['code'])
    if code not in (111, 411):
        skipped['非111/411'] = skipped.get('非111/411', 0) + 1; continue
    head = g
    if code == 411:   # 否则：找配对的 111
        ind = int(lst[g].get('indent', 0))
        head = next(j for j in range(g - 1, -1, -1) if int(lst[j]['code']) == 111 and int(lst[j].get('indent', 0)) == ind)
    donors = [k for k in who.get('%s:%d' % (loc, head), []) if k in pre or k.split('#')[0] in pre]
    if not donors:
        skipped['没有供体'] = skipped.get('没有供体', 0) + 1; continue
    donors.sort(key=lambda k: size(pre.get(k)))
    add = anc.trace_var(lst, g, copy.deepcopy(cl['preset']))
    made = False
    for dk in donors[:3]:
        p = copy.deepcopy(pre.get(dk) or {})
        a = copy.deepcopy(add)
        if '_rand' in a:
            seq = list(p.get('random_seq', []))
            for pos, v in a.pop('_rand').items():
                pos = int(pos)
                seq += [0.5] * (pos + 1 - len(seq))
                seq[pos] = v
            p['random_seq'] = seq
        anc.merge_into(p, a)
        base = dk.split('#')[0]
        key = (base, json.dumps(p, sort_keys=True))
        if key in seen:
            continue
        seen.add(key)
        n = len(out) + 1
        out.append({'base': base, 'tag': '%s_%d' % (tag, n), 'preset': p})
        targets['%s#%s_%d' % (base, tag, n)] = '%s:%d' % (loc, cl['first'])
        made = True
        break
    if not made:
        skipped['都试过'] = skipped.get('都试过', 0) + 1
print('出', len(out), '跳过', skipped)
(W / ('targets_%s.json' % tag)).write_text(json.dumps(targets, ensure_ascii=False, indent=0))
if '--write' in sys.argv:
    d['cases'] += out
    anc.P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
    print('已写')
else:
    for c in out[:40]:
        print(c['base'], json.dumps(c['preset'], ensure_ascii=False)[:150])
