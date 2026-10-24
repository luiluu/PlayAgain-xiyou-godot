"""带条件的可达性模型：只读冻结正式源，供 census.py 调用（也可直接运行打印摘要）。

从新游戏起点出发做不动点：一条 201 固定地图传送算“可走”，当且仅当
  1) 它所在的地图已可达（或所在公共事件已可达／被物品技能状态菜单调用），
  2) 事件页条件与包住它的条件分支都“可能满足”：开关要置 ON 就必须有写入处，变量比较在初值 0 下不成立就必须有写入处，
     独立开关必须在同一事件里被置 ON；持有物品／角色／金币／脚本等条件按“可能满足”宽算并留作备注。
写入处（121/122/123 与脚本 setValue）只认已可达的地图事件、已可达的公共事件和已可达地图的敌群；插件代码里的写入一律算有。
宽口径：不看事件页之间的先后、不看触发方式、不看变量具体值，只问“有没有任何一条路径”。
没覆盖的见盘点文档「扫描范围」。
"""
import json,glob,re,collections,pathlib
REPO=pathlib.Path(__file__).resolve().parents[2]
SRC=REPO/'03_再刷重制_Godot'/'02_内容与素材'/'冻结正式源'/'app.nw'
D=str(SRC/'data')+'/'
PL=str(SRC/'js'/'plugins')+'/'
maps={}
for f in glob.glob(D+'Map[0-9][0-9][0-9].json'):
    maps[int(re.search(r'Map(\d+)',f).group(1))]=json.load(open(f))
CE=json.load(open(D+'CommonEvents.json')); TR=json.load(open(D+'Troops.json'))
SYS=json.load(open(D+'System.json')); SWN=SYS['switches']; VRN=SYS['variables']
ITEMS=json.load(open(D+'Items.json'))
INFO={i['id']:i['name'] for i in json.load(open(D+'MapInfos.json')) if i}

def walk(lst):
    """逐条给出 (指令, 包住它的条件分支[(111 参数, 是否在 then 分支)])"""
    stack=[]
    for c in lst:
        ind=c['indent']
        while stack and stack[-1][0]>ind: stack.pop()
        if c['code']==411:
            if stack and stack[-1][0]==ind: stack[-1][2]=False
        elif c['code']==412:
            if stack and stack[-1][0]==ind: stack.pop()
        if c['code']==111:
            yield c,[(s[1],s[2]) for s in stack]
            stack.append([ind,c['parameters'],True])
        else:
            yield c,[(s[1],s[2]) for s in stack if s[0]<ind]

# ---- 写入处 ----
sw_on=collections.defaultdict(set); varw=collections.defaultdict(set); selfw=collections.defaultdict(set)
def gather(lst,loc):
    for c in lst:
        cd=c['code'];p=c['parameters']
        if cd==121 and p[2]==0:
            for i in range(p[0],p[1]+1): sw_on[i].add(loc)
        elif cd==122:
            for i in range(p[0],p[1]+1): varw[i].add(loc)
        elif cd==123 and loc[0]=='map' and p[1]==0: selfw[(loc[1],loc[2])].add(p[0])
        elif cd in(355,655):
            for mm in re.finditer(r'\$gameSwitches\.setValue\(\s*(\d+)',p[0]): sw_on[int(mm.group(1))].add(loc)
            for mm in re.finditer(r'\$gameVariables\.setValue\(\s*(\d+)',p[0]): varw[int(mm.group(1))].add(loc)
for m,d in maps.items():
    for e in d['events']:
        if e:
            for i,p in enumerate(e['pages']): gather(p['list'],('map',m,e['id'],i))
for n,c in enumerate(CE):
    if c: gather(c['list'],('ce',n))
for t in TR:
    if t:
        for p in t['pages']: gather(p['list'],('troop',t['id']))
plug_sw=collections.defaultdict(set); plug_var=collections.defaultdict(set)
for f in glob.glob(PL+'*.js'):
    s=open(f,encoding='utf-8',errors='ignore').read(); n=f.split('/')[-1]
    for mm in re.finditer(r'\$gameSwitches\.setValue\(\s*(\d+)',s): plug_sw[int(mm.group(1))].add(n)
    for mm in re.finditer(r'\$gameVariables\.setValue\(\s*(\d+)',s): plug_var[int(mm.group(1))].add(n)

# ---- 传送来源（固定地图 201）----
class Src: pass
srcs=[]
def pagecond(p):
    c=p['conditions'];out=[]
    if c['switch1Valid']: out.append(('sw',c['switch1Id'],True))
    if c['switch2Valid']: out.append(('sw',c['switch2Id'],True))
    if c['variableValid']: out.append(('var',c['variableId'],c['variableValue']))
    if c['selfSwitchValid']: out.append(('self',c['selfSwitchCh']))
    if c['itemValid']: out.append(('item',c['itemId']))
    if c['actorValid']: out.append(('actor',c['actorId']))
    return out
OTHER={3:'计时器',4:'角色',5:'敌人',6:'角色朝向',7:'金币',9:'武器',10:'防具',11:'按键',12:'脚本',13:'乘坐载具'}
def cmdconds(conds):
    out=[]
    for p,pol in conds:
        t=p[0]
        if t==0: out.append(('sw',p[1],(p[2]==0)==pol))
        elif t==1: out.append(('var2',p[1],p[2],p[3],p[4],pol))
        elif t==2: out.append(('self',p[1]) if pol==(p[2]==0) else ('selfoff',p[1]))
        elif t==8: out.append(('item',p[1]) if pol else ('itemoff',p[1]))
        else: out.append(('other',OTHER.get(t,'其它')))
    return out
def scan(lst,kind,m,ev,pg,pconds):
    for c,conds in walk(lst):
        if c['code']==201 and c['parameters'][0]==0:
            s=Src(); s.kind=kind; s.m=m; s.ev=ev; s.pg=pg; s.target=c['parameters'][1]
            s.conds=pconds+cmdconds(conds); srcs.append(s)
for m,d in maps.items():
    for e in d['events']:
        if e:
            for i,p in enumerate(e['pages']): scan(p['list'],'map',m,e['id'],i,pagecond(p))
for n,c in enumerate(CE):
    if c: scan(c['list'],'ce',n,0,0,[])

# ---- 间接调用的公共事件（宽算：自动／并行、物品技能效果、States 等备注里的调用、主菜单项）----
def ce_closure(lst,acc):
    for c in lst:
        if c['code']==117 and c['parameters'][0] not in acc:
            acc.add(c['parameters'][0]); ce_closure(CE[c['parameters'][0]]['list'],acc)
INDIRECT=set(n for n,c in enumerate(CE) if c and c.get('trigger',0)>0)
for fn in('Items.json','Skills.json'):
    for it in json.load(open(D+fn)):
        for ef in (it or {}).get('effects',[]):
            if ef.get('code')==44: INDIRECT.add(ef['dataId'])
for fn in('States','Skills','Items','Weapons','Armors','Enemies'):
    s=open(D+fn+'.json',encoding='utf-8').read()
    INDIRECT|=set(int(x) for x in re.findall(r'reserveCommonEvent\((\d+)\)',s))|set(int(x) for x in re.findall(r'(?i)common event:?\s*(\d+)',s))
_pl=open(str(SRC/'js'/'plugins.js'),encoding='utf-8').read(); _pl=json.loads(_pl[_pl.index('['):_pl.rindex(']')+1])
for x in _pl:
    if x['name']=='YEP_MainMenuManager':
        for k,v in x['parameters'].items():
            if k.endswith('Ext') and v.isdigit(): INDIRECT.add(int(v))
INDIRECT={n for n in INDIRECT if 0<n<len(CE) and CE[n]}
# 传送菜单（MapTransferPlugin）：canTransfer 才能传；hidden 的进入过一次才自动解锁，所以不产生新入口
_mt=[x for x in _pl if x['name']=='MapTransferPlugin'][0]['parameters']
MENU={}
for _s in json.loads(_mt['Map Settings']):
    _s=json.loads(_s)
    MENU[int(_s['id'])]=dict(can=_s.get('canTransfer')!='false',hidden=_s.get('hidden')=='true')

OPS={0:lambda a,b:a==b,1:lambda a,b:a>=b,2:lambda a,b:a<=b,3:lambda a,b:a>b,4:lambda a,b:a<b,5:lambda a,b:a!=b}
OPN=['=','≥','≤','>','<','≠']
def state(reached):
    live_ce=set(INDIRECT); live_troop=set()
    for m in reached:
        d=maps[m]
        for en in d['encounterList']: live_troop.add(en['troopId'])
        for e in d['events']:
            if e:
                for p in e['pages']:
                    for c in p['list']:
                        if c['code']==117: live_ce.add(c['parameters'][0])
                        if c['code']==301 and c['parameters'][0]==0: live_troop.add(c['parameters'][1])
    for t in live_troop:
        for p in TR[t]['pages']: ce_closure(p['list'],live_ce)
    for n in list(live_ce): ce_closure(CE[n]['list'],live_ce)
    return live_ce,live_troop
def live_loc(l,reached,lc,lt):
    if l[0]=='map': return l[1] in reached
    if l[0]=='ce': return l[1] in lc
    return l[1] in lt
def has_writer(store,plug,i,reached,lc,lt):
    if plug.get(i): return ('plugin',sorted(plug[i])[0])
    for l in sorted(store.get(i,()),key=str):
        if live_loc(l,reached,lc,lt): return l
    return None
def fmt(l):
    if l[0]=='plugin': return '插件'+l[1]
    return ('Map%d EV%d'%(l[1],l[2])) if l[0]=='map' else (('CE%d'%l[1]) if l[0]=='ce' else '敌群%d'%l[1])
def check(s,reached,lc,lt):
    """返回 (可能满足, 依赖说明, 卡住的原因)"""
    notes=[];block=[]
    def need_var(vid,desc):
        w=has_writer(varw,plug_var,vid,reached,lc,lt)
        (notes if w else block).append('变量%d「%s」%s%s'%(vid,VRN[vid],desc,(' ⇐'+fmt(w)) if w else ' 无处写入'))
    for c in s.conds:
        t=c[0]
        if t=='sw' and c[2]:
            w=has_writer(sw_on,plug_sw,c[1],reached,lc,lt)
            (notes if w else block).append('开关%d「%s」%s'%(c[1],SWN[c[1]],(' ⇐'+fmt(w)) if w else ' 无处置 ON'))
        elif t=='var':
            if c[2]>0: need_var(c[1],'≥%d'%c[2])
        elif t=='var2':
            _,vid,ot,opd,op,pol=c
            if ot==1: notes.append('变量%d 与变量比较'%vid); continue
            r=OPS[op](0,opd)
            if not pol: r=not r
            if not r: need_var(vid,'%s%d%s'%(OPN[op],opd,'' if pol else '(取反)'))
        elif t=='self':
            if c[1] in selfw.get((s.m,s.ev),()) or s.kind=='ce': notes.append('独立开关%s'%c[1])
            else: block.append('独立开关%s 无处置 ON'%c[1])
        elif t=='item': notes.append('持有物品%d「%s」'%(c[1],(ITEMS[c[1]] or {}).get('name','')))
        elif t=='actor': notes.append('队伍含角色%d'%c[1])
        elif t=='other': notes.append('条件:'+c[1])
    return (not block),notes,block
def fixpoint():
    reached={SYS['startMapId']}; parent={}
    while True:
        lc,lt=state(reached); new=False
        for s in srcs:
            if s.target in reached or s.target not in maps: continue
            if s.kind=='map' and s.m not in reached: continue
            if s.kind=='ce' and s.m not in lc: continue
            ok,notes,block=check(s,reached,lc,lt)
            if ok: reached.add(s.target); parent[s.target]=(s,notes); new=True
        if not new: break
    lc,lt=state(reached)
    return reached,parent,lc,lt
def blockers(m,reached,lc,lt):
    """不可达地图：每条指向它的 201 为什么走不通"""
    out=[]
    for s in srcs:
        if s.target!=m: continue
        name='Map%d EV%d'%(s.m,s.ev) if s.kind=='map' else 'CE%d'%s.m
        if s.kind=='map' and s.m not in reached: out.append(name+'（所在地图不可达）'); continue
        if s.kind=='ce' and s.m not in lc: out.append(name+'（无处调用）'); continue
        ok,notes,block=check(s,reached,lc,lt)
        out.append(name+'：'+'；'.join(block) if block else name+'（可满足？）')
    return out
def route(m,parent,slice_maps):
    """从已接地图走到 m 的入口链：[(src, notes), …]，由外向里"""
    chain=[]; cur=m
    while cur in parent:
        s,notes=parent[cur]; chain.append((s,notes))
        if s.kind=='ce' or s.m in slice_maps: break
        cur=s.m
    return chain[::-1]

if __name__=='__main__':
    reached,parent,lc,lt=fixpoint()
    print('可达',len(reached),'/',len(maps),'；不可达',sorted(set(maps)-reached))
