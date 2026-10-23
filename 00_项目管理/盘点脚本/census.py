"""未接地图盘点：只读冻结正式源与 xiyou_slice.json，写 00_项目管理/盘点_未接地图_20261023.md。python3 00_项目管理/盘点脚本/census.py"""
import json,glob,re,collections,sys
import pathlib
REPO=pathlib.Path(__file__).resolve().parents[2]
ROOT=str(REPO/'03_再刷重制_Godot')+'/'
OUT=REPO/'00_项目管理'/'盘点_未接地图_20261023.md'
R=ROOT+'02_内容与素材/冻结正式源/app.nw/data/'
S=json.load(open(ROOT+'03_转换工具/xiyou_slice.json'))
slice_maps=set(S['maps']); slice_troops=set(S['troops'])
keep=S['keepEvents']
info=json.load(open(R+'MapInfos.json'))
names={i['id']:i['name'] for i in info if i}
CE=json.load(open(R+'CommonEvents.json'))
maps={}
for f in glob.glob(R+'Map[0-9][0-9][0-9].json'):
    m=int(re.search(r'Map(\d+)',f).group(1)); maps[m]=json.load(open(f))
def kept(m,eid):
    k=keep.get(str(m),'*') if m in slice_maps else None
    if k is None: return False
    return k=='*' or eid in k
# reachable CE closure from slice
def walk_ce(lst,acc):
    for c in lst:
        if c['code']==117 and c['parameters'][0] not in acc:
            acc.add(c['parameters'][0]); walk_ce(CE[c['parameters'][0]]['list'],acc)
slice_ce=set()
for m in slice_maps:
    for e in maps[m]['events']:
        if e and kept(m,e['id']):
            for p in e['pages']: walk_ce(p['list'],slice_ce)
slice_ce|=set(S.get('extraCommonEvents',[]))
# transfers: (src_kind, src_map, ev, target map)
incoming=collections.defaultdict(list)
def scan(lst,src):
    for c in lst:
        if c['code']==201 and c['parameters'][0]==0: incoming[c['parameters'][1]].append(src+((c['parameters'][2],c['parameters'][3]),))
        elif c['code']==201: incoming[-1].append(src)
for m,d in maps.items():
    for e in d['events']:
        if not e: continue
        for i,p in enumerate(e['pages']): scan(p['list'],('map',m,e['id'],i))
for n,c in enumerate(CE):
    if c: scan(c['list'],('ce',n,0,0))
# also map-start (new game transfer) from System.json
sysd=json.load(open(R+'System.json'))
incoming[sysd['startMapId']].append(('system',0,0,0,(sysd['startX'],sysd['startY'])))
T=json.load(open(R+'Troops.json'))
def info_map(m):
    d=maps[m]
    troops=set(); codes=collections.Counter(); plug=set(); ces=set(); nev=0; npages=0
    for e in d['events']:
        if not e: continue
        nev+=1
        for p in e['pages']:
            npages+=1
            for c in p['list']:
                codes[c['code']]+=1
                if c['code']==301 and c['parameters'][0]==0: troops.add(c['parameters'][1])
                if c['code']==117: ces.add(c['parameters'][0])
                if c['code']==356: plug.add(c['parameters'][0].split()[0])
    for en in d['encounterList']: troops.add(en['troopId'])
    return dict(nev=nev,npages=npages,troops=sorted(troops),ces=sorted(ces),plug=sorted(plug),codes=codes,w=d['width'],h=d['height'],disp=d.get('displayName',''))
rows=[]
for m in sorted(maps):
    if m in slice_maps: continue
    im=info_map(m)
    inc=incoming.get(m,[])
    # reachable from slice: source map in slice with kept event, or CE in slice_ce
    live=[]; dead_src=[]
    for src in inc:
        if src[0]=='map':
            (live if kept(src[1],src[2]) else dead_src).append(src)
        elif src[0]=='ce':
            (live if src[1] in slice_ce else dead_src).append(src)
        elif src[0]=='system': live.append(src)
    rows.append(dict(map=m,name=names.get(m,''),inc_total=len(inc),live=live,dead=dead_src,**im))
if False: json.dump({'slice_n':len(slice_maps),'total':len(maps),'rows':rows,'slice_ce_n':len(slice_ce)},open('/dev/null','w'),ensure_ascii=False,default=lambda o:dict(o))
print(len(maps),len(slice_maps),len(rows))

# ---------- 第二部分：传递闭包分层、依赖、markdown ----------
def handled_codes(text):
    codes=set()
    for line in text.splitlines():
        m=re.match(r'^\t\t(\d+(?:, \d+)*):',line)
        if m: codes.update(int(x) for x in m.group(1).split(', '))
    return codes
interp=''.join(open(ROOT+'01_Godot工程/modes/xiyou/'+f,encoding='utf-8').read() for f in ('core/mv_event_core.gd','map/mv_interpreter.gd'))
handled=handled_codes(interp)|{0,108,401,402,403,404,408,411,412,413,505,601,602,603,604,605,655}
HOST=set(int(x) for x in re.search(r'HOST_CODES := \[([^\]]*)\]',interp).group(1).split(','))
handled|=HOST
STRUCT=set()
def plug_names(text):
    body=text.split('func _plugin_command',1)[1].split('\nfunc ',1)[0] if 'func _plugin_command' in text else ''
    names=set()
    for line in body.splitlines():
        if re.match(r'^\t\t"',line): names.update(re.findall(r'"([^"]+)"',line.split(':',1)[0]))
    return names
plugs=plug_names(interp)
# 脚本里的 reserveTransfer
scr_inc=collections.defaultdict(list)
for m,d in maps.items():
    for e in d['events']:
        if not e: continue
        for p in e['pages']:
            for c in p['list']:
                if c['code'] in(355,655):
                    for mm in re.finditer(r'reserveTransfer\((\d+)',c['parameters'][0]): scr_inc[int(mm.group(1))].append(('script',m,e['id']))
by={r['map']:r for r in rows}
reached=set(slice_maps); layers=[]
pending=set(by)
while True:
    new=[]
    for m in sorted(pending):
        r=by[m]
        for src in r['live']+r['dead']:
            if src[0]=='map' and src[1] in reached and src[1]!=m and (kept(src[1],src[2]) or src[1] not in slice_maps): new.append(m);break
            if src[0]=='ce' and src[1] in slice_ce: new.append(m);break
            if src[0]=='system': new.append(m);break
    if not new: break
    layers.append(new); reached|=set(new); pending-=set(new)
orphans=sorted(pending)
def unsupported(r):
    d=maps[r['map']];miss=collections.Counter();pm=set()
    for e in d['events']:
        if not e: continue
        for p in e['pages']:
            for c in p['list']:
                if c['code'] not in handled: miss[c['code']]+=1
                if c['code']==356:
                    n=c['parameters'][0]
                    if not any(n.startswith(x) for x in plugs): pm.add(n.split()[0])
    return miss,sorted(pm)
def classify(r):
    n=r['name']+r['disp']
    if re.search(r'测试|test|备份|副本\d|demo|DEMO',n): return '疑似测试／备份'
    if r['nev']==0: return '空图（无事件）'
    return '正常内容'
out=[]
P=out.append
P('# 未接地图盘点（2026-10-23，悟空_45）\n')
P('由 `00_项目管理/盘点脚本/census.py`（只读冻结正式源与 xiyou_slice.json）生成，可重跑。\n')
P('## 结论\n')
P(f'- 冻结正式源共 **{len(maps)}** 张地图数据（Map*.json），切片已接 **{len(slice_maps)}** 张（{len(slice_maps)*100/len(maps):.1f}%），未接 **{len(rows)}** 张。')
P(f'- 其中现在就能从切片里的事件走到的 **{len(layers[0]) if layers else 0}** 张（第 1 层），再往里一层层展开共 {sum(len(l) for l in layers)} 张可达；其余 {len(orphans)} 张在原版里没有任何可达来源（或来源本身不可达）：')
P(f'  - 只被未接地图／公共事件指向：{len([m for m in orphans if by[m]["dead"]])}；完全没有传送指向：{len([m for m in orphans if not by[m]["dead"]])}。')
cls=collections.Counter(classify(by[m]) for m in by)
P('- 按名称／事件分类：'+'、'.join(f'{k} {v}' for k,v in cls.items())+'。')
P('- 进度账「楼层、副本与剧情内容」的分母若按全部地图数 231 计，当前实际 '+f'{len(slice_maps)}/{len(maps)}；若扣除疑似测试／备份与空图（{sum(1 for m in by if classify(by[m])!="正常内容")} 张）后为 {len(slice_maps)}/{len(maps)-sum(1 for m in by if classify(by[m])!="正常内容")}。\n')
P(f'- 对进度账：「楼层、副本与剧情内容」行写的 68/231 是 dev.0xx 时的数，实际切片现为 **{len(slice_maps)}/{len(maps)}**（MapInfos 登记 {len([i for i in info if i])} 张，Map*.json 共 {len(maps)} 张，二者差的是没登记的数据文件）。\n')
P('## 接入顺序（按层展开，层内按规模小、依赖少排）\n')
P('排序键：解释器缺指令数＋缺插件数（越少越靠前），其次事件数、敌群数。「缺指令」指事件里出现解释器没有分支的指令码（含出现次数）；敌群列出的是尚未进切片的敌群数。\n')
def key(m):
    r=by[m];miss,pm=unsupported(r)
    return (len(miss)+len(pm),r['nev'],len([t for t in r['troops'] if t not in slice_troops]))
for li,l in enumerate(layers):
    P(f'### 第 {li+1} 层（{len(l)} 张）\n')
    P('| 图 | 名称 | 尺寸 | 事件／页 | 未入切片敌群 | 来源（谁传到这里） | 缺指令／插件 | 分类 |')
    P('|---|---|---|---|---|---|---|---|')
    for m in sorted(l,key=key):
        r=by[m];miss,pm=unsupported(r)
        src=[]
        for x in (r['live']+r['dead'])[:3]:
            src.append('Map%d EV%d'%(x[1],x[2]) if x[0]=='map' else ('CE%d'%x[1] if x[0]=='ce' else '新游戏起点'))
        src=sorted(set(src))
        nt=len([t for t in r['troops'] if t not in slice_troops])
        mi='、'.join(f'{k}×{v}' for k,v in sorted(miss.items()))+(' 插件:'+','.join(pm) if pm else '')
        P(f'| {m} | {r["name"] or r["disp"]} | {r["w"]}×{r["h"]} | {r["nev"]}／{r["npages"]} | {nt} | {"、".join(src)} | {mi or "—"} | {classify(r)} |')
    P('')
P('## 原版里到不了的地图\n')
P('| 图 | 名称 | 尺寸 | 事件／页 | 指向它的来源（均不可达） | 分类 |')
P('|---|---|---|---|---|---|')
for m in orphans:
    r=by[m]
    src=sorted(set(('Map%d EV%d'%(x[1],x[2]) if x[0]=='map' else 'CE%d'%x[1]) for x in r['dead']+scr_inc.get(m,[]) if x[0] in('map','ce') ) | set('脚本 Map%d EV%d'%(x[1],x[2]) for x in scr_inc.get(m,[])))
    P(f'| {m} | {r["name"] or r["disp"]} | {r["w"]}×{r["h"]} | {r["nev"]}／{r["npages"]} | {"、".join(src[:4]) or "无"} | {classify(r)} |')
open(OUT,'w',encoding='utf-8').write('\n'.join(out)+'\n')
print('layers',[len(l) for l in layers],'orphans',len(orphans))

# ---------- 第三部分：来源事件在切片图里但没放 ----------
cand=collections.defaultdict(list)
for m,r in by.items():
    for src in r['dead']:
        if src[0]=='map' and src[1] in slice_maps and not kept(src[1],src[2]):
            cand[m].append(src)
P2=[]
P2.append('\n## 来源事件就在已接地图里、只是没放进 keepEvents 的未接地图\n')
P2.append('这些图的入口门在切片地图上被 keepEvents 挡掉了（或属于原版条件页）。放开对应事件即可「玩家能到达」，是最便宜的接入点。\n')
P2.append('| 目标图 | 名称 | 来源（已接地图 事件） | 事件名 | 事件／页 | 未入切片敌群 | 缺指令／插件 |')
P2.append('|---|---|---|---|---|---|---|')
for m in sorted(cand,key=key):
    r=by[m];miss,pm=unsupported(r)
    srcs=sorted(set((x[1],x[2]) for x in cand[m]))
    names_=[]
    for sm,se in srcs[:3]:
        ev=[e for e in maps[sm]['events'] if e and e['id']==se][0]
        names_.append(ev['name'])
    nt=len([t for t in r['troops'] if t not in slice_troops])
    mi='、'.join(f'{k}×{v}' for k,v in sorted(miss.items()))+(' 插件:'+','.join(pm) if pm else '')
    P2.append(f'| {m} | {r["name"] or r["disp"]} | {"、".join("Map%d EV%d"%x for x in srcs[:4])} | {"、".join(names_)} | {r["nev"]}／{r["npages"]} | {nt} | {mi or "—"} |')
open(OUT,'a',encoding='utf-8').write('\n'.join(P2)+'\n')
print('cand maps',len(cand))
