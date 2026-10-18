#!/usr/bin/env python3
"""冻结源只读静态预检；不执行公式，不导入游戏，不触碰存档。stdout 为 JSON。"""
import argparse, collections, hashlib, importlib.util, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / '03_再刷重制_Godot/03_转换工具'
p = argparse.ArgumentParser()
p.add_argument('--app', type=Path, default=Path('/Users/kyo/Documents/再刷项目资料库/03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw'))
a = p.parse_args()
spec = importlib.util.spec_from_file_location('xiyou_export', TOOL / 'xiyou_export.py')
import sys
sys.dont_write_bytecode = True
sys.path.insert(0, str(TOOL))
x = importlib.util.module_from_spec(spec)
spec.loader.exec_module(x)
load = lambda name: json.loads((a.app / 'data' / (name + '.json')).read_text())
db = {n: load(n) for n in ['Skills','Items','Actors','Classes','Enemies','Troops','Weapons','Armors','States','CommonEvents','MapInfos']}
cfg = json.loads((TOOL / 'xiyou_slice.json').read_text())
hashfile = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
# 只按明确数据库引用建边；脚本/备注中的数字命中另列候选，绝不当作实际可达。
refs = collections.defaultdict(list)
for table in ['Actors','Classes','Enemies','Weapons','Armors','States']:
    for r in db[table]:
        if not r: continue
        actors = [z['id'] for z in db['Actors'] if z and z['classId'] == r['id']] if table == 'Classes' else []
        for i, z in enumerate(r.get('actions', [])):
            refs[z['skillId']].append({'table':table,'id':r['id'],'name':r['name'],'field':'actions','index':i})
        for i, z in enumerate(r.get('learnings', [])):
            refs[z['skillId']].append({'table':table,'id':r['id'],'name':r['name'],'field':'learnings','index':i,'level':z['level'],'actors':actors})
        for i, z in enumerate(r.get('traits', [])):
            if z['code'] == 43:
                refs[z['dataId']].append({'table':table,'id':r['id'],'name':r['name'],'field':'traits43','index':i,'actors':actors})
# 明确命名的替换标签按技能引用登记，SkillPass/动画/物品号等不误认成使用者。
for table in ['Skills','States','Weapons','Armors','Actors','Classes']:
    for r in db[table]:
        if not r: continue
        for tag,pat in [('ChangeTo',r'<ChangeTo\[(\d+)\]\s*:\s*([^>]+)>'),('Replace Attack',r'<Replace Attack\s*:\s*(\d+)\s*>')]:
            for hit in re.finditer(pat,r.get('note',''),re.I):
                refs[int(hit.group(1))].append({'table':table,'id':r['id'],'name':r['name'],'field':tag,'condition':hit.group(2) if tag=='ChangeTo' else None})
# 地图→固定敌群和公共事件调用；保留事件条件，不把静态引用称为通关可达证明。
maps = {int(f.stem[3:]):json.loads(f.read_text()) for f in sorted((a.app/'data').glob('Map[0-9][0-9][0-9].json'))}
map_name = lambda mid: db['MapInfos'][mid]['name'] if mid < len(db['MapInfos']) and db['MapInfos'][mid] else '(MapInfos未登记)'
troop_maps = collections.defaultdict(list)
ce_callers = collections.defaultdict(list)
for skill in db['Skills']:
    if not skill: continue
    for e in skill.get('effects',[]):
        if e['code']==44: ce_callers[e['dataId']].append({'skill':skill['id'],'name':skill['name'],'kind':'effect44'})
    for hit in re.finditer(r'COMMON EVENT\s*:\s*(\d+)',skill.get('note',''),re.I):
        ce_callers[int(hit.group(1))].append({'skill':skill['id'],'name':skill['name'],'kind':'yepSeq-common-event'})
def event_list(commands, loc):
    for i,c in enumerate(commands):
        code, q = c['code'], c['parameters']
        here = dict(loc, commandIndex=i, code=code)
        if code == 117: ce_callers[q[0]].append(here)
        if code == 301 and q[0] == 0: troop_maps[q[1]].append(here)
        if code == 318: refs[q[3]].append(dict(here, actorSelector=q[:2], operation=q[2]))
        if code == 339: refs[q[2]].append(dict(here, subject=q[:2], target=q[3]))
for mid,m in maps.items():
    for e in m.get('encounterList',[]): troop_maps[e['troopId']].append({'map':mid,'mapName':map_name(mid),'kind':'encounter','mapInSlice':mid in cfg['maps'],'enabled':mid in cfg['maps']})
    for ev in m.get('events',[]):
        if not ev: continue
        keep=cfg.get('keepEvents',{}).get(str(mid),[])
        enabled=mid in cfg['maps'] and (keep=='*' or ev['id'] in keep)
        for pi,page in enumerate(ev.get('pages',[])):
            event_list(page['list'], {'map':mid,'mapName':map_name(mid),'event':ev['id'],'eventName':ev['name'],'page':pi+1,'conditions':page.get('conditions',{}),'mapInSlice':mid in cfg['maps'],'enabled':enabled})
for ce in db['CommonEvents']:
    if ce:event_list(ce['list'],{'commonEvent':ce['id'],'name':ce['name']})
for t in db['Troops']:
    if not t:continue
    for pi,page in enumerate(t.get('pages',[])):event_list(page['list'],{'troop':t['id'],'name':t['name'],'page':pi+1,'conditions':page.get('conditions',{})})
def ce_origins(ce,seen=()):
    if ce in seen:return []
    out=[]
    for r in ce_callers.get(ce,[]):
        if 'commonEvent' in r:out.extend(ce_origins(r['commonEvent'],seen+(ce,)))
        else:out.append(r)
    return out
for t,rr in list(troop_maps.items()):
    expanded=[]
    for r in rr:
        if 'commonEvent' in r:
            expanded.extend(dict(o,viaCommonEvent=r['commonEvent']) for o in ce_origins(r['commonEvent']))
    rr.extend(expanded)
for sid,rr in refs.items():
    for r in rr:
        if r.get('table')=='Enemies':
            enemy=r['id']; ts=[t['id'] for t in db['Troops'] if t and any(m['enemyId']==enemy for m in t['members'])]
            r['troops']=ts;r['troopsInSlice']=[t for t in ts if t in cfg['troops']]
            r['mapOrigins']=[dict(o,troop=t) for t in ts for o in troop_maps.get(t,[])]
        elif r.get('commonEvent'):r['mapOrigins']=ce_origins(r['commonEvent'])
rows=[]; calls=collections.defaultdict(list); counters={}
mut = re.compile(r'\.(?:gainHp|gainMp|gainTp|setHp|setMp|setTp|addShield|addState|removeState|clearStates|learnSkill|forgetSkill|setValue|gainItem|gainGold)\s*\(|(?:\b(?:a|b|user|target|subject)\.[\w$]+|\b[vs]\[[^\]]+\])\s*(?:=(?!=)|\+=|-=|\*=|/=|\+\+|--)')
for table in ['Skills','Items']:
    all_rows=[]
    for r in db[table]:
        if not r:continue
        block=x.yep_damage_block(r.get('note',''))
        f=block if block is not None else r['damage']['formula']
        gd,why=x.translate_custom_block(block,r['id']) if block is not None else x.translate_formula(f,r['id'])
        effective=x.strip_js_comments(f)
        cs=sorted(set(re.findall(r'([\w$]+(?:\.[\w$]+)*)\s*\(',effective)))
        for c in cs:calls[c].append({'table':table,'id':r['id']})
        row={'table':table,'id':r['id'],'name':r['name'],'damageType':r['damage']['type'],'customBlock':block is not None,'formula':f,'formulaSHA256':hashlib.sha256(f.encode()).hexdigest(),'translated':gd is not None,'translationIssue':why,'directMutationSyntax':bool(mut.search(effective)),'calls':cs,'refs':refs[r['id']] if table=='Skills' else []}
        # 全部公式均扫描；报告只展开自定义块/写入/未翻译，调用清单保留其他类型。
        all_rows.append(row)
        if row['customBlock'] or row['directMutationSyntax'] or not row['translated']:rows.append(row)
    counters[table]={'records':len(all_rows),'customBlocks':sum(r['customBlock'] for r in all_rows),'untranslatedAllRecords':sum(not r['translated'] for r in all_rows),'untranslatedWithDamage':sum(not r['translated'] and r['damageType']>0 for r in all_rows),'directMutationSyntax':sum(r['directMutationSyntax'] for r in all_rows)}
# 候选备注命中只用于人工复核：不能仅凭数字证明技能使用者。
interesting={r['id'] for r in rows if r['table']=='Skills' and (r['customBlock'] or r['directMutationSyntax'])}
for row in rows:
    if row['table']!='Skills' or row['id'] not in interesting:continue
    sid=row['id']; pat=re.compile(r'(?<!\d)'+str(sid)+r'(?!\d)');out=[]
    for table in ['Actors','Classes','Enemies','Weapons','Armors','States','Skills','Items']:
        for r in db[table]:
            if not r:continue
            for ln,line in enumerate(r.get('note','').splitlines(),1):
                if pat.search(line):out.append({'table':table,'id':r['id'],'name':r['name'],'line':ln,'text':line})
    row['noteNumberCandidates']=out
rng=[]
pattern=re.compile(r'\b(?:randf(?:_range)?|randi(?:_range)?|seed|randomize)\s*\(|\.\s*(?:pick_random|shuffle)\s*\(')
for f in sorted((ROOT/'03_再刷重制_Godot/01_Godot工程/modes/xiyou').rglob('*.gd')):
    for ln,line in enumerate(f.read_text().splitlines(),1):
        if pattern.search(line) and not line.lstrip().startswith('#'):rng.append({'file':str(f.relative_to(ROOT)),'line':ln,'text':line.strip()})
result={'schema':1,'reportBaselineGit':'07c2660','source':str(a.app),'sourceSHA256':{n:hashfile(a.app/'data'/ (n+'.json')) for n in ['Skills','Items','Actors','Classes','Enemies','Troops']},'sliceSHA256':hashfile(TOOL/'xiyou_slice.json'),'converterSHA256':hashfile(TOOL/'xiyou_export.py'),'counters':counters,'rows':rows,'calls':dict(calls),'rngSites':rng,'reachabilityDisclaimer':'静态引用/切片存在不代表完成招募、事件条件、公共事件插件脚本均可执行。动态脚本和任意插件内部写入未被本工具证明。'}
print(json.dumps(result,ensure_ascii=False,indent=2))
