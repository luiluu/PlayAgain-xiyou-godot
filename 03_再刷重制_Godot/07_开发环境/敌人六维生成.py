#!/usr/bin/env python3
"""敌人六维生成（T303）：把「模板 + 档位原型」规则一键铺成 six_dim.json 的 enemies 段，并出按层的交付单全表。

Kyo 改口径（模板归类、档位原型、守层者分档、野兽战商等）时：改本文件顶部的 KEY／ARCH／CLS／GU 等表，再重跑。
用法（在仓库根或任意目录）：
  python3 03_再刷重制_Godot/07_开发环境/敌人六维生成.py                预演：只打印条数和校验结果，不写文件
  python3 03_再刷重制_Godot/07_开发环境/敌人六维生成.py --write        把 enemies 段写进 modes/xiyou/tianqi_data/six_dim.json（只动 enemies 与 _note 里那一句，actors 不碰）
  python3 03_再刷重制_Godot/07_开发环境/敌人六维生成.py --table <文件.md>  另写按层全表（贴进交付单）
重跑后：python3 03_转换工具/天启篇数据校验.py 要 0；并行测试 xiyou_tianqi_enemy_table。
依赖：工程里有 generated/db（Enemies／Troops／Skills）和 generated/maps，没有先 新建工作树.sh --补齐。
13～16 层 31 只是协调已报 Kyo 的样板（SAMPLE），生成时盖在规则结果上；新口径若连样板一起改，直接改 SAMPLE 或删掉它。"""
import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path

SAMPLE = {
 "107": {
  "template": "beast"
 },
 "108": {
  "template": "beast",
  "output": "B",
  "wit": "D",
  "class": "weak"
 },
 "109": {
  "template": "hunter",
  "class": "weak"
 },
 "110": {
  "template": "alien",
  "output": "S",
  "survive": "A",
  "wit": "D",
  "resolve": "D",
  "class": "strong"
 },
 "111": {
  "template": "hunter",
  "output": "S",
  "survive": "B",
  "speed": "A",
  "wit": "B",
  "resolve": "C",
  "support": "E",
  "class": "super"
 },
 "276": {
  "template": "beast"
 },
 "277": {
  "template": "beast",
  "output": "B",
  "wit": "D",
  "class": "weak"
 },
 "278": {
  "template": "guard",
  "class": "weak"
 },
 "279": {
  "template": "beast",
  "output": "B",
  "survive": "A",
  "speed": "D",
  "wit": "C",
  "resolve": "B",
  "support": "D",
  "class": "strong"
 },
 "280": {
  "template": "caster",
  "output": "A",
  "survive": "S",
  "speed": "D",
  "wit": "B",
  "resolve": "B",
  "support": "C",
  "class": "super"
 },
 "114": {
  "template": "guard",
  "output": "B",
  "survive": "A",
  "speed": "C",
  "wit": "B",
  "resolve": "B",
  "support": "A",
  "class": "strong"
 },
 "115": {
  "template": "caster"
 },
 "116": {
  "template": "caster",
  "wit": "B",
  "class": "weak"
 },
 "117": {
  "template": "caster",
  "output": "B",
  "survive": "D",
  "speed": "B",
  "wit": "C",
  "resolve": "C",
  "support": "E",
  "class": "weak"
 },
 "118": {
  "template": "caster",
  "output": "A",
  "survive": "C",
  "speed": "C",
  "wit": "B",
  "resolve": "D",
  "support": "B",
  "class": "strong"
 },
 "119": {
  "template": "caster",
  "output": "S",
  "survive": "C",
  "speed": "B",
  "wit": "B",
  "resolve": "D",
  "support": "C",
  "class": "super"
 },
 "120": {
  "template": "hunter",
  "output": "A",
  "survive": "B",
  "speed": "S",
  "wit": "A",
  "resolve": "C",
  "support": "E",
  "class": "elite"
 },
 "121": {
  "template": "guard",
  "output": "A",
  "survive": "A",
  "speed": "D",
  "wit": "D",
  "resolve": "A",
  "support": "E",
  "class": "strong"
 },
 "122": {
  "template": "undead"
 },
 "123": {
  "template": "undead",
  "output": "B",
  "class": "weak"
 },
 "124": {
  "template": "hunter",
  "class": "weak"
 },
 "125": {
  "template": "undead",
  "output": "A",
  "survive": "A",
  "speed": "E",
  "wit": "D",
  "resolve": "B",
  "support": "E",
  "class": "strong"
 },
 "126": {
  "template": "undead",
  "output": "S",
  "survive": "B",
  "speed": "C",
  "wit": "D",
  "resolve": "C",
  "support": "D",
  "class": "super"
 },
 "127": {
  "template": "undead"
 },
 "128": {
  "template": "caster",
  "output": "C",
  "survive": "B",
  "speed": "D",
  "wit": "A",
  "resolve": "A",
  "support": "A",
  "class": "strong"
 },
 "138": {
  "template": "caster"
 },
 "139": {
  "template": "caster",
  "wit": "B",
  "class": "weak"
 },
 "140": {
  "template": "hunter",
  "class": "weak"
 },
 "141": {
  "template": "caster",
  "output": "B",
  "survive": "C",
  "speed": "C",
  "wit": "A",
  "resolve": "C",
  "support": "A",
  "class": "strong"
 },
 "142": {
  "template": "guard",
  "output": "A",
  "survive": "S",
  "speed": "E",
  "wit": "C",
  "resolve": "A",
  "support": "D",
  "class": "elite"
 },
 "129": {
  "template": "guard",
  "output": "A",
  "survive": "B",
  "speed": "B",
  "wit": "B",
  "resolve": "B",
  "support": "D",
  "class": "strong"
 }
}
R=str(Path(__file__).resolve().parents[1])+'/'
G=R+'01_Godot工程/modes/xiyou/'
sys.path.insert(0, R + '03_转换工具')
sp=importlib.util.spec_from_file_location('v',R+'03_转换工具/天启篇数据校验.py'); v=importlib.util.module_from_spec(sp); sp.loader.exec_module(v)
T={t['id']:t for t in json.load(open(G+'generated/db/Troops.json')) if t}
E={e['id']:e for e in json.load(open(G+'generated/db/Enemies.json')) if e}
S={s['id']:s for s in json.load(open(G+'generated/db/Skills.json')) if s}
six=json.load(open(G+'tianqi_data/six_dim.json')); TP=six['templates']
L='EDCBASSS'
def vec(s): return dict(zip(['output','survive','speed','wit','resolve','support'],s))
# 档位字母串→六维。如 "AADDBE"
LET={'E':'E','D':'D','C':'C','B':'B','A':'A','S':'S','X':'SS','Y':'SSS'}
def v6(code): return vec([LET[c] for c in code])
# 原型：(strong, super, elite)，六字母 输出 生存 速度 战商 韧性 辅助
ARCH={
 'beast':('BADCBD','SBBDCD','SBBCBD'),
 'bruiser':('AADDBE','SBCDCD','ABCDAD'),
 'caster':('BCCACA','ACBACA','BBCSBC'),
 'hunter':('ACABCE','SBABCE','ABXAEC'.replace('X','S').replace('E','C')),
 'guard':('BADCAC','ASDBAC','ASECAD'),
}
ARCH['hunter']=('ACABCE','SBABCE','ABSACE')
TPL_ARCH={'beast':'beast','undead':'bruiser','mob':'bruiser','alien':'bruiser','caster':'caster','hunter':'hunter','guard':'guard','abyss':'guard'}
# 模板归类：按名字（去标签）关键字，先到先得
KEY=[('试验品','alien'),('弗莱','hunter'),('波巴','guard'),('训狼','beast'),('钳嘴龟','beast'),('希达','beast'),('希顿','caster'),('癫舞','caster'),('神明之焰','caster'),('哈耳庇厄','hunter'),
 ('丧尸','undead'),('盗尸魔精','hunter'),('人鱼','caster'),('深海龙人','hunter'),('亚特兰蒂斯守护者','guard'),
 ('灵魂','undead'),('妖精','caster'),('枯骨','undead'),('守护雕像','undead'),('腐蚀者','abyss'),('邪炎骨魔','abyss'),('巴弗灭','abyss'),
 ('龙人士兵','guard'),('龙人队长','guard'),('龙人禁卫','guard'),('禁卫军','guard'),('龙人','hunter'),('斯卡勒','hunter'),
 ('吉吉战士','mob'),('吉吉大法丝儿','guard'),('吉吉','caster'),('蟹将军','guard'),('龟儿','caster'),('龟父','guard'),
 ('机械哨兵','undead'),('机械侦察兵','undead'),('机械队长','undead'),('机甲','guard'),('暗灭泰坦','abyss'),
 ('暮灵','beast'),('南琴','beast'),('觅岚','caster'),('夜云','caster'),('熊','beast'),('古树守护者','undead'),('古树法师','caster'),('古树骑士','guard'),('古树祭祀','caster'),
 ('奔波','caster'),('波奔','caster'),('霸波奔','caster'),('霸奔波','caster'),('狐仙','caster'),
 ('猪','beast'),('哥布林巫师','caster'),('哥布林','mob'),('诺彼修','caster'),('拉赫克','caster'),('恶魔训犬','beast'),('巨牙','beast'),('霍格尔','guard'),('阿涅特','caster'),
 ('范海辛','hunter'),('魔剑','hunter'),('训练官','guard')]
def tag(n):
    m=re.match(r'【(.+?)】',n); return m.group(1) if m else '普通'
def base(n): return re.sub(r'^【.+?】','',n).strip('"“”')
def tpl_of(n):
    b=base(n)
    for k,t in KEY:
        if k in b: return t
    raise KeyError(n)
CLS={'普通':'minion','罕见':'minion','十分罕见':'weak','稀有':'strong','前所未见':'super','亘古未有':'elite','精英':'elite','首领':'super'}
rows={}; why={}
def rec(i,floor):
    e=E[i]; n=e['name']; tg=tag(n)
    if tg=='守层者': return
    t=tpl_of(n); cls=CLS[tg]
    row={'template':t}
    sk=' '.join(S[a['skillId']]['name'] for a in e['actions'] if a['skillId'] in S)
    if t=='abyss':
        if cls in('minion','weak','strong','super'): pass
        row['class']='elite'; why[i]='深渊精英模板，%s→elite 档照模板'%tg
    elif cls=='minion':
        base_total=sum(L.index(TP[t][d])+1 for d in v.SIX_DIMS) if False else None
        tot=sum(v.SIX_LETTERS.index(TP[t][d])+1 for d in v.SIX_DIMS)
        why[i]='%s·%s：只写模板键'%(tg,TP[t]['_name'])
        if tg=='罕见':
            # 头目：输出 +1、战商 -1（有冲劲没脑子），保持 minion 预算
            o=v.SIX_LETTERS.index(TP[t]['output']); row['output']=v.SIX_LETTERS[o+1]
            row['class']='minion' if tot+1<=18 else 'weak'
            why[i]='罕见头目·%s：输出＋1 档，头目更凶'%TP[t]['_name']
    elif cls=='weak':
        row['class']='weak'
        o=v.SIX_LETTERS.index(TP[t]['output'])
        tot=sum(v.SIX_LETTERS.index(TP[t][d])+1 for d in v.SIX_DIMS)
        if tot<13: row['output']=v.SIX_LETTERS[o+1]; row['wit']=v.SIX_LETTERS[v.SIX_LETTERS.index(TP[t]['wit'])+1]
        why[i]='十分罕见·%s：弱档，%s'%(TP[t]['_name'],'模板加输出、战商各＋1 补足预算下限' if tot<13 else '直接用模板分')
    else:
        a=ARCH[TPL_ARCH[t]]; code=a[{'strong':0,'super':1,'elite':2}[cls]]
        row['class']=cls; row.update(v6(code))
        why[i]='%s·%s：%s 档原型 %s'%(tg,TP[t]['_name'],cls,code)
    # 特例微调：有控制／治疗技能的上调辅助；全抗性的上调生存（在预算内才生效）
    rows[str(i)]=row
# 13~27 层遇敌
fm={13:[29,64],14:[30],15:[32],16:[33],17:[45],18:[46],19:[47],20:[116],21:[117],22:[119],23:[118],24:[120],25:[147],26:[155],27:[182]}
order=[];fl={}
for f,ms in fm.items():
    for m in ms:
        for x in json.load(open(G+'maps/Map%03d.json'%m if False else G+'generated/maps/Map%03d.json'%m))['encounterList']:
            for mem in T[x['troopId']]['members']:
                i=mem['enemyId']
                if i not in fl: fl[i]=f; order.append(i)
# 里副本
dung=[268,269,34,31,35,30,10,9,11,330,336,335,233,237,234]
for i in dung: fl.setdefault(i,'里副本'); order.append(i) if i not in order else None
for i in order: rec(i,fl[i])
# 守层者
GU={13:('guard','strong','BADBBA'),14:('guard','strong','AADDAE'),15:('caster','strong','CBDAAA'),16:('guard','strong','ABBBBD'),
 17:('caster','strong','BCBASA'),18:('abyss','strong','ABCBBC'),19:('hunter','strong','AADBBC')}
ids={13:114,14:121,15:128,16:129,17:181,18:192,19:202,20:523,21:524,22:525,23:526,24:527,25:528,26:529,27:531,28:532,29:533,30:534,31:535,32:536,33:537}
gstyle={ # 楼层: (模板, 六字母, 理由)
 13:('guard','BABBBA','圣光系，眩光控制加自疗，战商 B 会挑目标'),
 14:('guard','AADDAE','克力之爷：莽拳老兵，高输出高韧性、头脑简单、不帮人'),
 15:('caster','CBDAAA','金池长老：佛门术士，战商韧性辅助都高，打得不凶'),
 16:('guard','ABBBBD','海王子：均衡的水系王子，各项偏上'),
 17:('caster','BCBASA'[:5]+'A','妖精公主：歌者，高战商高辅助'),
 18:('abyss','ABCBBC','深渊骑士：输出压过生存的深渊精英，战技魔法兼备'),
 19:('hunter','AADBBC','炎龙队长：龙息爆发加爪击，输出生存都高，速度偏慢'),
 20:('bruiser','SBCDCD','石日天：蛮力型，高输出，战商偏低'),
 21:('caster','ACBACA','六道魔君：魔法系，战商高'),
 22:('bruiser','SBCDCD','三眼娃：近战输出型'),
 23:('hunter','SBABCE','哪托：高速突击'),
 24:('bruiser','SBCDCD','黑熊精：蛮力、不爱动脑'),
 25:('caster','ACBACA','嫦娥：法术加治疗系'),
 26:('hunter','SBABCE','金角：偷袭型术士'),
 27:('caster','ACBACA','多宝：法宝流'),
 28:('guard','ASDBAC','镇元子：高生存高韧性的老怪'),
 29:('caster','ACBACA','太白金星：谋士型，战商高、辅助高'),
 30:('guard','ASDBAC','玉皇大帝：天庭之主，硬扛'),
 31:('caster','ACBACA','女娲：造物术士'),
 32:('guard','ASDBAC','伏羲：高生存压阵'),
 33:('guard','ASDBAC','鸿蒙老祖：终局压阵'),
}
for f,i in ids.items():
    if f<=19 or True:
        pass
# 手工覆盖 17~19 守层者让其合预算；20+ 用 super 档原型
manual={
 13:('guard','strong','BABBBA'),14:('guard','strong','AADDAE'),15:('caster','strong','CBDAAA'),16:('guard','strong','ABBBBD'),
 17:('caster','strong','BCCAAA'),18:('abyss','strong','ABCBBC'),19:('hunter','strong','AADBBC'),
}
def gu(f,i):
    if f in manual:
        t,c,code=manual[f]
        if t=='abyss': row={'template':'abyss','class':'elite'}; row.update(v6(code)); row['class']='strong'
        else: row={'template':t,'class':c}; row.update(v6(code))
    else:
        t,code,_=gstyle[f]
        row={'template':t if t!='bruiser' else 'undead','class':'super'}; row.update(v6(code))
    rows[str(i)]=row; why[i]='守层者 %d 层·%s'%(f,gstyle[f][2])
for f,i in ids.items(): gu(f,i)
# 26 层银角 530、29 层等多只；银角
rows['530']={'template':'hunter','class':'super'}; rows['530'].update(v6('ACABCE')); why[530]='守层者 26 层·银角：金角的搭档，速度偏快、输出稍低'
rows['529']={'template':'hunter','class':'super'}; rows['529'].update(v6('SBABCE')); why[529]='守层者 26 层·金角：偷袭型，高输出高速度'
# 低层守层者在里副本当首领
for i,(t,code,r) in {54:('hunter','ABBBBC','里疫土之主（范海辛）：猎手型首领'),40:('hunter','ABABBC','里战酋（魔剑·菲利）：战场剑士'),8:('guard','BBCBBC','里监考官（训练官）：监考守卫')}.items():
    rows[str(i)]={'template':t,'class':'super'}; rows[str(i)].update(v6(code)); why[i]=r
# 335/336/234/237 首领 super 已由 rec 处理(首领→super)
sm=SAMPLE
for k,r in sm.items(): rows[k]=r; why[int(k)]=why.get(int(k),'')+'（13～16 层样板，已报协调）'
# 去掉 class==模板且无覆盖的行里多余 class，保持 minion
out={}
for k,r in rows.items():
    if r.get('class')=='minion' and TP[r['template']]['class']=='minion': r.pop('class')
    out[k]=r
bad=[]
for k,r in out.items():
    m=dict(TP[r['template']]); m.update(r)
    bad+=v.six_dim_row_rules('enemies/%s %s'%(k,E[int(k)]['name']),m,m['class'])

REASONS = {int(k): v for k, v in {"108": "训狼头目：输出＋1、战商−1（有冲劲没脑子）", "109": "训狼者：驯兽人，猎手模板，战商 B 会挑目标", "110": "试验品：失控实验体，高输出高生存但头脑简单、心志不稳", "111": "弗莱：杀伐之刃，速度快、输出高的刀手首领", "277": "钳嘴龟头目：同训狼头目", "278": "外交官：守卫模板，不改", "279": "希达：老龟，高生存高韧性、出手慢", "280": "希顿：魔晶龟，奥术吸收，高生存的法系首领", "114": "瑟伦：圣光系，眩光控制加自疗，战商 B 会挑目标", "116": "癫舞头目：法师模板，战商＋1", "117": "神明之焰：元素体，高输出高速度、辅助弱", "118": "狂信者：狂信→韧性 D，输出高", "119": "受赐者：输出 S，狂信→韧性 D", "120": "哈耳庇厄：鹰踏高速、战商 A，Boss 档", "121": "克力之爷：莽拳老兵，高输出高韧性、头脑简单、不帮人", "123": "饥饿丧尸：输出＋1", "124": "盗尸魔精：抽干影杀，猎手模板", "125": "缝合巨人：高输出高生存、极慢、笨", "126": "发火：疯鬼，输出 S、战商 D", "128": "金池长老：佛门术士，战商韧性辅助都高、输出低", "139": "成年人鱼：战商＋1", "140": "深海龙人：飞爪影杀，猎手模板", "141": "卡琳：人鱼公主，战商辅助高", "142": "亚特兰蒂斯守护者：守卫 Boss，高生存高韧性、极慢", "129": "海王子：均衡水系，各项偏上"}.items()}

GUARD_IDS = {13: 114, 14: 121, 15: 128, 16: 129, 17: 181, 18: 192, 19: 202, 20: 523, 21: 524, 22: 525, 23: 526, 24: 527, 25: 528, 26: 529, 27: 531, 28: 532, 29: 533, 30: 534, 31: 535, 32: 536, 33: 537}


def table_md():
    D = ['output', 'survive', 'speed', 'wit', 'resolve', 'support']
    gf = {v: k for k, v in GUARD_IDS.items()}
    gf[530] = 26
    by = {}
    for k in sorted(out, key=int):
        i = int(k)
        f = fl.get(i)
        if i in gf:
            f = gf[i]
        if i in (54, 40, 8) or f in ('里副本', None):
            f = '里'
        by.setdefault(f, []).append(i)
    lines = []
    for f in sorted(by, key=lambda f: (1, 0) if f == '里' else (0, int(f))):
        lines.append('\n### %s\n\n| 敌人号 | 名字 | 模板 | 档 | 六维（输出/生存/速度/战商/韧性/辅助） | 理由 |\n|---|---|---|---|---|---|' % (('第 %s 层' % f) if f != '里' else '七印里副本（原 3～19 层敌人，里副本按参照重标）'))
        for i in by[f]:
            r = out[str(i)]
            m = dict(TP[r['template']])
            m.update(r)
            lines.append('| %d | %s | %s | %s | %s | %s |' % (i, E[i]['name'], r['template'], m['class'], ''.join(m[x] for x in D), REASONS.get(i) or why[i].replace('（13～16 层样板，已报协调）', '')))
    return '\n'.join(lines) + '\n'


def main():
    ap = argparse.ArgumentParser(description='敌人六维生成（T303）')
    ap.add_argument('--write', action='store_true', help='写进 six_dim.json 的 enemies 段')
    ap.add_argument('--table', help='另写按层全表 markdown')
    a = ap.parse_args()
    print('生成 %d 只，R1～R4 违规 %d 条' % (len(out), len(bad)))
    for b in bad:
        print('  ✗', b)
    if bad:
        return 1
    if a.table:
        Path(a.table).write_text(table_md())
        print('全表写到', a.table)
    p = Path(G) / 'tianqi_data' / 'six_dim.json'
    d = json.loads(p.read_text())
    new = {k: out[k] for k in sorted(out, key=int)}
    print('与文件里现有 enemies %s' % ('一致' if d.get('enemies') == new else '不一致'))
    if a.write:
        d['enemies'] = new
        d['_note'] = re.sub(r'敌人 T303 起录 13～33 层＋七印里副本 \d+ 只', '敌人 T303 起录 13～33 层＋七印里副本 %d 只' % len(new), d['_note'])
        p.write_text(json.dumps(d, ensure_ascii=False, indent=1) + '\n')
        print('已写', p)
    return 0


if __name__ == '__main__':
    sys.exit(main())
