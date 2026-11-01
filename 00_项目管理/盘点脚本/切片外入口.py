"""切片外地图入口盘点（悟空 reach-air4，2026-11-01）：只读冻结 v0.28。用法：python3 -I 切片外入口.py <仓库根>
逐张列切片外地图：MapInfos 名称／父图、大小、事件数、遇敌表；谁用场所移动（固定地图）传送到它（地图事件、公共事件、敌群事件）；
脚本／插件指令里的 reserveTransfer／transfer 数字；载具位置指令；它自己的出口。另打印「变量指定地图」的场所移动个数（全工程 0）。
tp＝MapTransferPlugin 传送点表（Map Settings）里它的 canTransfer，不在表里写 -。
"""
import json, glob, re, sys, collections
R=sys.argv[1]
D=R+'/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/data/'
JS=R+'/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/js/'
S=set(json.load(open(R+'/03_再刷重制_Godot/03_转换工具/xiyou_slice.json'))['maps'])
info={i['id']:i for i in json.load(open(D+'MapInfos.json')) if i}
maps={int(re.search(r'Map(\d+)',f).group(1)):json.load(open(f)) for f in glob.glob(D+'Map[0-9][0-9][0-9].json')}
CE=json.load(open(D+'CommonEvents.json')); TR=json.load(open(D+'Troops.json'))
out=sorted(set(maps)-S)
ins=collections.defaultdict(list); outs=collections.defaultdict(list); scr=collections.defaultdict(list); veh=collections.defaultdict(list)
def scan(lst, where):
    for c in lst or []:
        k=c['code']; p=c['parameters']
        if k==201 and p[0]==0: ins[p[1]].append(where)
        if k==201 and p[0]!=0: ins['var'].append(where)
        if k==202 and p[1]==0: veh[p[2]].append(where)
        if k in (355,655,356):
            s=str(p[0])
            for m in re.finditer(r'(?:reserveTransfer|UnlockMapTransfer|transfer)\D{0,4}(\d+)',s,re.I): scr[int(m.group(1))].append(where+':'+s[:60])
for mid,m in maps.items():
    for e in m['events']:
        if not e: continue
        for pi,pg in enumerate(e['pages']): scan(pg['list'], f'M{mid}EV{e["id"]}p{pi+1}')
for c in CE:
    if c: scan(c['list'], f'CE{c["id"]}')
for t in TR:
    if t:
        for pg in t['pages']: scan(pg['list'], f'T{t["id"]}')
pj=open(JS+'plugins.js',encoding='utf-8').read()
arr=json.loads(pj[pj.index('['):pj.rindex(']')+1])
mtp=[x for x in arr if x['name']=='MapTransferPlugin'][0]
tp={int(json.loads(x)['id']):json.loads(x)['canTransfer'] for x in json.loads(mtp['parameters']['Map Settings'])}
for mid in out:
    m=maps[mid]; i=info.get(mid,{})
    evs=[e for e in m['events'] if e]
    srcs=[w for w in ins.get(mid,[]) if not w.startswith(f'M{mid}EV')]
    selfsrc=[w for w in ins.get(mid,[]) if w.startswith(f'M{mid}EV')]
    dests=sorted({c['parameters'][1] for e in evs for pg in e['pages'] for c in pg['list'] if c['code']==201 and c['parameters'][0]==0})
    print(f"| {mid} | {i.get('name','')} | parent {i.get('parentId')} | {m['width']}x{m['height']} | ev {len(evs)} | enc {len(m.get('encounterList',[]))} | in {srcs[:6]} self {selfsrc[:2]} | script {scr.get(mid,[])[:2]} | veh {veh.get(mid,[])[:2]} | tp {tp.get(mid, '-')} | out {dests} | from-in-slice {[w for w in srcs if int(re.match(r'M(\d+)',w).group(1)) in S] if srcs else []} |")
print('var-transfers', len(ins['var']), ins['var'][:5])
