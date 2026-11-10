"""随机门的邻居变体：门（111 变量比常量／411 否则）的变量在门前被 122 随机赋值时，拿走到门头的用例当供体，
用 sim.py 沿供体路径数随机数位置，解出让变量取开门值的 random_seq。
用法：nb2.py cov.json missed.json tag [--skip-ce bonly.json] [--write]"""
import json, sys, copy
from pathlib import Path
import sim
import importlib.util
T = sim.T
W = Path(__import__('os').environ.get('SA_WORK', '.'))
sp = importlib.util.spec_from_file_location('anc', T / '事件祖先预设.py'); anc = importlib.util.module_from_spec(sp); sp.loader.exec_module(anc)
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


def note(k):
    why[k] = why.get(k, 0) + 1


for cl in clusters:
    loc, g = cl['loc'], cl['gate']
    if (loc.startswith('ce') and int(loc[2:]) in bonly) or g is None or g < 0:
        continue
    lst = sim.LISTS[loc]
    c = lst[g]; code = int(c['code'])
    head = g
    if code == 411:
        ind = int(c.get('indent', 0))
        head = next(j for j in range(g - 1, -1, -1) if int(lst[j]['code']) == 111 and int(lst[j].get('indent', 0)) == ind)
    q = lst[head]['parameters']
    if int(lst[head]['code']) != 111 or int(q[0]) != 1 or int(q[2]) != 0:
        continue
    var = int(q[1])
    want = (cl.get('preset') or {}).get('variables', {}).get(str(var))
    if want is None:
        continue
    donors = [k for k in who.get('%s:%d' % (loc, head), []) if k in pre or '#' not in k]
    donors.sort(key=lambda k: len(json.dumps(pre.get(k, {}))))
    made = False
    for dk in donors[:4]:
        base = dk.split('#')[0]
        p = copy.deepcopy(pre.get(dk, {}))
        dr, ex, unk = sim.sim(base, p.get('random_seq', []), p.get('variables'), p.get('switches'), p.get('items'))
        if not any(x[1] == var for x in dr):
            continue
        seq = sim.solve(base, var, int(want), p.get('random_seq', []), p.get('variables'), p.get('switches'), p.get('items'))
        if not seq:
            continue
        p['random_seq'] = seq
        key = (base, json.dumps(p, sort_keys=True))
        if key in seen:
            continue
        seen.add(key)
        n = len(out) + 1
        out.append({'base': base, 'tag': '%s_%d' % (tag, n), 'preset': p})
        targets['%s#%s_%d' % (base, tag, n)] = '%s:%d' % (loc, cl['first'])
        made = True
        break
    note('出' if made else '没出')
print(len(out), why)
(W / ('targets_%s.json' % tag)).write_text(json.dumps(targets, ensure_ascii=False))
if '--write' in sys.argv:
    d['cases'] += out
    anc.P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
    print('已写')
else:
    for c in out:
        print(c['base'], json.dumps(c['preset'], ensure_ascii=False)[:160])
