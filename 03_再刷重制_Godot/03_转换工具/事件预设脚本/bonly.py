"""bonly.py [GEN目录] → 打印只在战斗里跑的公共事件 id（调用方全是 occasion=1 的技能／物品、敌群页、或只在战斗里跑的公共事件）"""
import json, re, sys, glob, os
from pathlib import Path
G = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / '01_Godot工程/modes/xiyou/generated')
CE = json.load(open(G / 'db/CommonEvents.json'))
callers = {}  # ce -> set of caller kinds: 'map', 'battle', ('ce', id)
def add(ce, who): callers.setdefault(ce, set()).add(who)
REF = re.compile(r'(?:reserveCommonEvent|CommonEvent|commonEvent)\D{0,4}(\d+)')
def scan(lst, who):
    for c in lst or []:
        if c['code'] == 117: add(c['parameters'][0], who)
        if c['code'] in (355, 655, 356, 108, 408):
            for m in REF.finditer(str(c['parameters'][0])): add(int(m.group(1)), who)
for f in ('Skills', 'Items'):
    for x in json.load(open(G / f'db/{f}.json')):
        if not x: continue
        for e in x.get('effects', []):
            if e['code'] == 44: add(e['dataId'], 'battle' if x['occasion'] == 1 else 'map')
        for m in REF.finditer(x.get('note', '')): add(int(m.group(1)), 'map')
for t in json.load(open(G / 'db/Troops.json')):
    if t:
        for p in t['pages']: scan(p['list'], 'battle')
for f in glob.glob(str(G / 'maps/Map*.json')) + glob.glob(str(G / 'Map*.json')):
    d = json.load(open(f))
    for ev in d.get('events') or []:
        if ev:
            for p in ev['pages']: scan(p['list'], 'map')
for c in CE:
    if not c: continue
    if c['trigger'] in (1, 2): add(c['id'], 'map')
    scan(c['list'], ('ce', c['id']))
# 不动点：map 可达
mapr = set(k for k, v in callers.items() if 'map' in v)
ch = True
while ch:
    ch = False
    for k, v in callers.items():
        if k not in mapr and any(isinstance(w, tuple) and w[1] in mapr for w in v):
            mapr.add(k); ch = True
bonly = sorted(k for k, v in callers.items() if k not in mapr and v)
print(json.dumps(bonly))
