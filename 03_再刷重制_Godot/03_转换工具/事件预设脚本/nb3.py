"""门变量的初值搜索：门（111 变量比常量／411）有供体走到门头，在供体预设上把门变量的初值换成一批候选，
用 sim.py 模拟，选第一个让目标下标执行到的值（模拟认不出的条件当真）。
用法：nb3.py cov.json missed.json tag [--skip-ce bonly.json] [--write]"""
import json, sys, copy
from pathlib import Path
import sim, importlib.util
W = Path(__import__('os').environ.get('SA_WORK', '.'))
sp = importlib.util.spec_from_file_location('anc', sim.T / '事件祖先预设.py'); anc = importlib.util.module_from_spec(sp); sp.loader.exec_module(anc)
bc = json.load(open(sys.argv[1]))['byCase']
clusters = json.load(open(sys.argv[2]))['clusters']
tag = sys.argv[3]
bonly = set(json.load(open(sys.argv[sys.argv.index('--skip-ce') + 1]))) if '--skip-ce' in sys.argv else set()
d = json.loads(anc.P.read_text())
pre = {c['base'] + '#' + c['tag']: c['preset'] for c in d['cases']}
seen = {(c['base'], json.dumps(c['preset'], sort_keys=True)) for c in d['cases']}
for c in json.load(open(W / 'tried.json'))['cases']:
    seen.add((c['base'], json.dumps(c['preset'], sort_keys=True)))
who = {}
for k, v in bc.items():
    for x in v:
        who.setdefault(x, []).append(k)
out, targets, why = [], {}, {}
for cl in clusters:
    loc, g = cl['loc'], cl['gate']
    if (loc.startswith('ce') and int(loc[2:]) in bonly) or g is None or g < 0 or cl['group'] == 'm4':
        continue
    lst = sim.LISTS[loc]
    head = g
    if int(lst[g]['code']) == 411:
        ind = int(lst[g].get('indent', 0))
        head = next(j for j in range(g - 1, -1, -1) if int(lst[j]['code']) == 111 and int(lst[j].get('indent', 0)) == ind)
    q = lst[head]['parameters']
    if int(lst[head]['code']) != 111 or int(q[0]) != 1 or int(q[2]) != 0:
        continue
    var, c0 = int(q[1]), int(q[3])
    tgt = '%s:%d' % (loc, cl['first'])
    donors = [k for k in who.get('%s:%d' % (loc, head), []) if k in pre or '#' not in k]
    donors.sort(key=lambda k: len(json.dumps(pre.get(k, {}))))
    made = None
    for dk in donors[:4]:
        base = dk.split('#')[0]
        for cand in sorted({c0 + k for k in range(-3, 4)} | {c0 * 2, -1, 0, 1}, key=lambda v: abs(v - c0)):
            p = copy.deepcopy(pre.get(dk, {}))
            p.setdefault('variables', {})[str(var)] = cand
            dr, ex, unk = sim.sim(base, p.get('random_seq', []), p.get('variables'), p.get('switches'), p.get('items'))
            if tgt not in ex:
                continue
            key = (base, json.dumps(p, sort_keys=True))
            if key in seen:
                continue
            seen.add(key)
            made = (base, p)
            break
        if made:
            break
    why['出' if made else '没出'] = why.get('出' if made else '没出', 0) + 1
    if made:
        n = len(out) + 1
        out.append({'base': made[0], 'tag': '%s_%d' % (tag, n), 'preset': made[1]})
        targets['%s#%s_%d' % (made[0], tag, n)] = tgt
print(len(out), why)
(W / ('targets_%s.json' % tag)).write_text(json.dumps(targets, ensure_ascii=False))
if '--write' in sys.argv:
    d['cases'] += out
    anc.P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
    print('已写')
else:
    for c in out:
        print(c['base'], json.dumps(c['preset'], ensure_ascii=False)[:160])
