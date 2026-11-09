"""greedy.py cov.json 前缀1,前缀2 [--drop-extra id,id] [--write]：本轮新变体（tag 以这些前缀开头）按新增覆盖贪心留，
其余（执行到的指令别的用例全都有）删。"""
import json, sys
from pathlib import Path
P = Path(__file__).resolve().parent.parent / 'event_presets.json'
bc = json.load(open(sys.argv[1]))['byCase']
pres = tuple(p + '_' for p in sys.argv[2].split(','))
extra = set(sys.argv[sys.argv.index('--drop-extra') + 1].split(',')) if '--drop-extra' in sys.argv else set()
d = json.loads(P.read_text())
new = [c['base'] + '#' + c['tag'] for c in d['cases'] if c['tag'].startswith(pres)]
newset = set(new)
base = set()
for k, v in bc.items():
    if k not in newset:
        base |= set(v)
keep, gain = [], 0
left = [k for k in new if k not in extra]
while True:
    best, bn = None, 0
    for k in left:
        n = len(set(bc.get(k, [])) - base)
        if n > bn:
            best, bn = k, n
    if not best:
        break
    keep.append(best); gain += bn; base |= set(bc[best]); left.remove(best)
drop = set(new) - set(keep)
by = {}
for k in keep:
    t = k.split('#')[1].split('_')[0]
    by[t] = by.get(t, 0) + 1
print('新变体', len(new), '留', len(keep), by, '新增执行指令', gain, '删', len(drop))
if '--write' in sys.argv:
    d['cases'] = [c for c in d['cases'] if c['base'] + '#' + c['tag'] not in drop]
    P.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
    print('已写')
