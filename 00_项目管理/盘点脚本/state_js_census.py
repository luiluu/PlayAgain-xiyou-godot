"""状态效果 js 剩余块盘点（八戒_75，2026-10-26）：读转换产物 generated/db 与 manifest 切片，
按形状（数字、字符串归一）分类，标切片可达（切片技能／角色与职业／敌人与其行动技能／全部武器防具物品的
特性 32、效果 21、备注里的状态号，公共事件／地图／敌群的 313 指令，再沿状态备注闭包；武器防具物品不分是否能拿到，偏宽）。
python3 00_项目管理/盘点脚本/state_js_census.py [前 N 类]"""
import json,re,sys,collections
import pathlib
REPO=pathlib.Path(__file__).resolve().parents[2]
W=str(REPO/'03_再刷重制_Godot')+'/'
sys.path.insert(0,W+'03_转换工具')
from formula_program import Parser, Unsupported
from xiyou_export import strip_js_comments
G=W+'01_Godot工程/modes/xiyou/generated/'
db={t:json.load(open(G+'db/%s.json'%t)) for t in ['States','Skills','Actors','Classes','Enemies','Weapons','Armors','Items']}
man=json.load(open(G+'manifest.json'))['slice']
def toks(code):
    try: return [r[0] for r in Parser(code).tokens[:-1]]
    except Exception: return None
def shape(body):
    code=re.sub(r'\s+',' ',strip_js_comments(body)).strip()
    t=toks(code)
    if t is None: return 'RAW:'+re.sub(r'\d+','N',code)[:200]
    return ' '.join('N' if re.fullmatch(r'\d+(\.\d+)?',x) else x for x in t)
STREF=[re.compile(p,re.I) for p in [r'Passive State:\s*([\d,\s]+)',r'addState\(\s*(\d+)',r'State[s]?\s*:?\s*(\d+(?:\s*,\s*\d+)*)',r'states?\s*[:=]\s*(\d+)']]
def refs_from_note(note):
    out=set()
    for p in STREF:
        for m in p.finditer(note or ''):
            out|={int(x) for x in re.findall(r'\d+',m.group(1))}
    return out
def refs_rec(rec):
    out=set()
    for tr in rec.get('traits',[]) or []:
        if tr['code'] in (32,):  out.add(tr['dataId'])
    for ef in rec.get('effects',[]) or []:
        if isinstance(ef,dict) and ef.get('code')==21 and ef.get('dataId',0)>0: out.add(ef['dataId'])
    out|=refs_from_note(rec.get('note'))
    return out
seeds=collections.defaultdict(set)  # state -> sources
def add(rec,tag):
    for s in refs_rec(rec): seeds[s].add(tag)
for sid in man['skills']:
    r=db['Skills'][sid]
    if r: add(r,'skill')
for aid in man['actors']:
    r=db['Actors'][aid]
    if r:
        add(r,'actor'); c=db['Classes'][r['classId']]
        if c: add(c,'class')
for eid in man['enemies']:
    r=db['Enemies'][eid]
    if r:
        add(r,'enemy')
        for a in r.get('actions',[]):
            sk=db['Skills'][a['skillId']] if a['skillId']<len(db['Skills']) else None
            if sk: add(sk,'enemy-skill')
for t in ('Weapons','Armors','Items'):
    for r in db[t]:
        if r: add(r,t[0].lower())
import glob
def walk(o):
    if isinstance(o,dict):
        if o.get('code')==313 and isinstance(o.get('parameters'),list):
            p=o['parameters']
            if len(p)>=4 and p[3]: seeds[p[3]].add('event')
        if o.get('code') in (355,655):
            for x in refs_from_note(str(o.get('parameters'))): seeds[x].add('event-js')
        for v in o.values(): walk(v)
    elif isinstance(o,list):
        for v in o: walk(v)
walk(json.load(open(G+'db/CommonEvents.json')))
for f in glob.glob(G+'maps/*.json'): walk(json.load(open(f)))
walk(json.load(open(G+'db/Troops.json')))
# closure through states (notes)
reach=set(s for s in seeds if 0<s<len(db['States']))
frontier=list(reach)
while frontier:
    s=frontier.pop(); r=db['States'][s]
    if not r: continue
    for x in refs_rec(r):
        if 0<x<len(db['States']) and x not in reach:
            reach.add(x); seeds[x].add('state'); frontier.append(x)
groups=collections.defaultdict(list)
for r in db['States']:
    if not r: continue
    for e in r.get('effects') or []:
        if e['op']=='js':
            groups[(e['phase'],shape(e['source']))].append(r['id'])
fam=collections.defaultdict(list)
for (ph,sh),ids in groups.items():
    k=re.sub(r"'[^']*'","S",sh); k=re.sub(r'\b\d+\b','N',k)
    fam[(ph,k)]+=ids
tot=sum(len(v) for v in groups.values()); totr=sum(1 for v in groups.values() for s in v if s in reach)
print('未翻译 js 块 %d，可达 %d，形状 %d 类（字符串、数字归一后 %d 类）' % (tot,totr,len(groups),len(fam)))
print('| 阶段 | 形状（开头） | 块数 | 可达 | 可达状态（来源） |')
print('| --- | --- | --- | --- | --- |')
N=int(sys.argv[1]) if len(sys.argv)>1 else 10
for (ph,k),ids in sorted(fam.items(),key=lambda kv:(-sum(1 for s in kv[1] if s in reach),-len(kv[1])))[:N]:
    rr=[s for s in ids if s in reach]
    k=k.replace('RAW:','').replace('|','¦')
    print('| %s | `%s` | %d | %d | %s |' % (ph,k[:90],len(ids),len(rr),'、'.join('%d %s(%s)'%(s,db['States'][s]['name'],'/'.join(sorted(seeds[s]))) for s in rr)))
