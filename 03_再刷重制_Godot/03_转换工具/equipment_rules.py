"""将装备备注与 GT 套装参数转成纯数据；不执行来源中的 JavaScript。"""
import json
import re

PARAMS = ['MHP','MMP','ATK','DEF','MAT','MDF','AGI','LUK']
ALIASES = {'HP':0,'MAXHP':0,'MAX HP':0,'MP':1,'MAXMP':1,'MAX MP':1,'SP':1,'MAXSP':1,'MAX SP':1,'STR':2,'INT':4,'SPI':4,'RES':5,'SPD':6}
ALIASES.update({p:i for i,p in enumerate(PARAMS)})


def ranges(text):
    out=[]
    for part in re.split(r'[,\s]+',text.strip()):
        m=re.fullmatch(r'(\d+)(?:-(\d+))?',part)
        if m: out.extend(range(int(m[1]),int(m[2] or m[1])+1))
    return out


def definition(rec, defaults):
    note=rec.get('note','')
    get=lambda tag,default: int(re.search(r'<'+tag+r':\s*(\d+)>',note,re.I)[1]) if re.search(r'<'+tag+r':\s*(\d+)>',note,re.I) else default
    affixes=[]
    for block in re.finditer(r'<(Prefixes|Suffixes)>(.*?)</\1>',note,re.S|re.I):
        for line in block[2].splitlines():
            choices=[{'chance':int(m[2]),'ids':ranges(m[1])} for m in re.finditer(r'([\d,\s-]+)\s+(\d+)%',line)]
            if choices: affixes.append({'kind':'prefix' if block[1].lower()=='prefixes' else 'suffix','choices':choices})
    suit_ids=[]
    for m in re.finditer(r'<Equip Suit:\s*(.*?)>',note,re.I):
        suit_ids += ranges(re.sub(r'\s+(?:to|through)\s+','-',m[1],flags=re.I))
    return {'affixes':affixes,'suits':suit_ids,'variance':get('Random Variance',0),
            'slots':get('Upgrade Slots?',int(defaults.get('Default Slots',6))),
            'slotVariance':get('Slots Variance',int(defaults.get('Slot Variance',6))),
            'requirements':{'actors':ranges(str(rec.get('meta',{}).get('req_actors','')))}}


def upgrade(rec):
    note=rec.get('note','');result={'weapon':[],'armor':[],'weaponTypes':[],'armorTypes':[],'cost':1,'boost':1,'issues':[]}
    for m in re.finditer(r'<Upgrade (Weapon |Armor )?Effect>(.*?)</Upgrade (?:Weapon |Armor )?Effect>',note,re.S|re.I):
        if not m[1]:
            result['issues'].append('legacy Upgrade Effect: 正式启用插件不识别')
            continue
        kinds=[m[1].strip().lower()]
        for line in m[2].splitlines():
            line=line.strip()
            if not line:continue
            slot=re.fullmatch(r'Slots?:\s*(\d+)',line,re.I)
            boost=re.fullmatch(r'Boost Count:\s*([+-]\d+)',line,re.I)
            if slot:result['cost']=int(slot[1]);continue
            if boost:result['boost']=int(boost[1]);continue
            effect=None
            match=re.fullmatch(r'(Random )?([\w ]+):\s*([+-]?\d+)([%％]?)',line,re.I)
            if match:
                symbol=match[2].upper()
                if symbol in ALIASES or symbol in ['ALL','CURRENT']:
                    effect={'op':'param','param':ALIASES.get(symbol,symbol.lower()),'value':int(match[3]),'percent':bool(match[4]),'random':bool(match[1]),'signed':match[3][0] in '+-'}
                elif symbol.startswith('ELEMENT AMPLIFY '):
                    effect={'op':'element','element':int(symbol.split()[-1]),'value':int(match[3])/100}
                elif symbol in ['XIANGQIAN MZ','XIANGQIAN BJ']:
                    effect={'op':'xparam','param':0 if symbol.endswith('MZ') else 2,'value':int(match[3])/100}
            if line.upper() in ['ADD SLOTS','DELETE SLOTS']:
                effect={'op':'slots','value':1 if line.upper()=='ADD SLOTS' else -1}
                result['weapon'].append(effect.copy());result['armor'].append(effect.copy());continue
            if effect:
                for kind in kinds:result[kind].append(effect)
            else:result['issues'].append(line)
    for kind in ['weapon','armor']:
        for m in re.finditer(r'<Upgrade '+kind+r' Type:\s*(.*?)>',note,re.I):
            result[kind+'Types']+=ranges(re.sub(r'\s+(?:to|through)\s+','-',m[1],flags=re.I))
        if not result['weaponTypes'] and not result['armorTypes']:
            pass
    if not result['weaponTypes'] and not result['armorTypes']:
        result['weaponTypes']=[0];result['armorTypes']=[0]
    return result


def suits(plugins):
    result=[None]*301
    groups={'param':PARAMS,'xparam':['HIT','EVA','CRI','CEV','MEV','MRF','CNT','HRG','MRG','TRG'],
            'sparam':['TGR','GRD','REC','PHA','MCR','TCR','PDR','MDR','FDR','EXR'],'bResult':['EXP','GOLD','ITEM']}
    for key,value in plugins.get('GT_EquipSuitCore',{}).items():
        if not re.fullmatch(r'Suit \d+',key) or not value:continue
        source=json.loads(value)
        if not source:continue
        id=int(key.split()[-1]);bonus=[]
        for encoded in json.loads(source['SuitBonuses']):
            b=json.loads(encoded);row={'requirePieces':int(b['RequirePieces'])}
            for src,target in [('PassiveStates','states'),('StatesResist','statesResist'),('AddSkills','skills')]:row[target]=[int(v) for v in json.loads(b[src]) if str(v).strip().isdigit()]
            for group,symbols in groups.items():
                row[group+'Plus']=[0]*len(symbols);row[group+'Rate']=[1.0]*len(symbols)
                src={'param':'ParamBonuses','xparam':'XParamBonuses','sparam':'SParamBonuses','bResult':'BResultBonuses'}[group]
                for line in json.loads(b[src]):
                    entry=json.loads(line)
                    if entry['ParamName'] in symbols:
                        i=symbols.index(entry['ParamName']);row[group+'Plus'][i]=float(entry['ParamPlus'] or 0);row[group+'Rate'][i]=float(entry['ParamRate'] or 0)
            bonus.append(row)
        result[id]={'id':id,'name':source['SuitName'],'bonuses':bonus}
    return result


def runewords(plugins):
    result=[None]*251
    for key,value in plugins.get('Star_EquipmentMosaic',{}).items():
        if not re.fullmatch(r'EMosaic \d+',key) or not value:continue
        s=json.loads(value);id=int(key.split()[-1])
        result[id]={'id':id,'name':s['EMosaicName'],
                    'weapon':int(s['EMosaicWId'] or 0),'armor':int(s['EMosaicAId'] or 0),
                    'weaponTypes':json.loads(s['EMosaicWtepy'] or '[]'),
                    'armorSlots':json.loads(s['EMosaicAtepy'] or '[]'),
                    'materials':json.loads(s['EMosaicZID'] or '[]')}
    return result
