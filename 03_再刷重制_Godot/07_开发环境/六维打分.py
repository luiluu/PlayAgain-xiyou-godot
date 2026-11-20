#!/usr/bin/env python3
"""天启篇六维全员打分（T280）：实测数据 → 名次 → 按全库名额配档 → R1～R3 降档 → six_dim.json 的 actors 段＋报告。

用法（在仓库任意处）：
  python3 03_再刷重制_Godot/07_开发环境/六维打分.py                 只算、只打印各档分布（不写任何文件）
  python3 .../六维打分.py --write                                   把 actors 写回 six_dim.json（口径 C：全库一把尺）＋重写报告
  python3 .../六维打分.py --ingest --calib 日志…  --stats 日志     先把 godot 探针日志整理成 六维打分_实测数据.json 再算（见下「重跑」）
  --mode A|B|C   写哪一版进 six_dim.json（缺省 C；三版的总分分布报告里一直都算）

数据来源（六维打分_实测数据.json，同目录）：
  输出  ＝ k_calibrate 含烙印整次施放峰值（K_ROW.peak）
  生存  ＝ k_calibrate --survive 实测挨打（K_SURV：标准敌人固定攻击、自动战斗带保命技、撑过的回合数）；面板（K_STAT）只兜底
  速度  ＝ k_calibrate --stats 的标准养成敏捷（K_STAT）×（追加行动几率＋技能描述里的再动／拉条／先制／敏捷加成）
  辅助  ＝ 职责底分＋技能描述里的友方词（skill_rework.json）
  战商／韧性 ＝ 手标分（下面 WIT／RESV，依据原作人设，不是实测；T280 起交小A 人审）

重跑（量表要 40 分钟左右，都在 03_再刷重制_Godot 目录外的仓库根执行，带 --audio-driver Dummy）：
  G="03_再刷重制_Godot/07_开发环境/godot --headless --audio-driver Dummy --path 03_再刷重制_Godot/01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/k_calibrate.tscn --"
  $=G --tier=all --exact > calib.log                    # 输出（K_ROW）；约 35 分钟
  $=G --stats --tier=all > stats.log                    # 面板（K_STAT）；约 1 分钟
  $=G --tier=all --exact --add-rework --soul=200000 --actors=<calib.log 里 K_SKIP 的号,167> > miss.log   # 补量没量到的、渡鸦灌满魂
  for s in 0 1 2; do $=G --survive --tier=all --seed=$s --surv-atk=8000 | sed "s/^K_SURV /K_SURV seed=$s /"; done > surv.log   # 生存（K_SURV）；每个种子约 10 分钟
  python3 .../六维打分.py --ingest --calib calib.log miss.log --stats stats.log --surv surv.log --write
"""
import argparse
import collections
import json
import re
import statistics
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GODOT = HERE.parent
REPO = GODOT.parent
DATA = GODOT / '01_Godot工程/modes/xiyou/tianqi_data'
DB = GODOT / '01_Godot工程/modes/xiyou/generated/db'
MEAS = HERE / '六维打分_实测数据.json'
REPORT = HERE / '六维全员重算报告.md'
LET = ['E', 'D', 'C', 'B', 'A', 'S', 'SS', 'SSS']
S = {l: i + 1 for i, l in enumerate(LET)}
DIMS = ['output', 'survive', 'speed', 'wit', 'resolve', 'support']
DN = {'output': '输出', 'survive': '生存', 'speed': '速度', 'wit': '战商', 'resolve': '韧性', 'support': '辅助'}
CN = {'super': '超强者', 'strong': '强者', 'weak': '弱者'}
ATK_SURV = 8000
MODES = ['A', 'B', 'B2', 'B6', 'C']
D239 = {'2', '22', '1', '162'}   # 绿司机、维利、狗逍遥、诛仙：补量后输出超出 Kyo 定的区间，D239 待定（协调 11-20）
BUDGET = {'super': (20, 26), 'strong': (18, 25), 'weak': (13, 22)}
# 全库名额（千分位累计）：SS 前 3.2%、S 累计 10.3%、A 25%、B 50%、C 75%、D 92.3%、其余 E（D／E 合计后 25%）。156 人时 SS5 S11 A23 B39 C39 D27 E12
CUM = [('SS', 32), ('S', 103), ('A', 250), ('B', 500), ('C', 750), ('D', 923), ('E', 1000)]

# ---- 战商／韧性手标分（0～100，按角色号逐人手标；依据原作人设／技能机制，不是实测）。T280 第四版：156 人全部显式手标（小A 人审清单逐条采纳或微调），不再有缺省。 ----
_WIT_BY_ID = "1 30,2 45,3 30,4 25,5 30,6 30,7 65,8 45,9 50,10 60,11 45,12 42,13 55,14 45,15 20,16 40,17 55,18 55,19 65,20 48,21 18,22 35,23 48,24 35,25 48,26 45,27 40,28 35,29 70,30 60,31 40,32 45,33 80,34 50,35 40,36 52,37 55,38 80,39 45,40 40,41 40,42 42,43 48,44 55,45 40,46 70,47 52,48 35,49 38,50 25,51 60,52 55,53 33,54 40,55 50,56 45,57 50,58 45,59 60,60 0,61 68,62 33,63 50,64 55,65 68,66 18,67 40,68 35,69 58,70 48,71 95,72 75,73 45,74 40,75 50,76 52,77 15,78 52,79 55,80 65,81 70,82 60,83 75,84 50,85 70,86 75,87 55,88 25,89 38,90 50,91 85,92 55,93 50,94 85,95 58,96 45,97 35,98 38,99 40,100 60,101 40,102 38,103 70,104 45,105 68,106 50,107 58,108 55,109 10,115 28,117 50,118 30,119 45,120 55,122 55,123 52,124 55,127 50,128 88,129 35,130 58,131 42,141 50,142 65,146 40,147 48,148 50,149 66,150 56,151 50,152 58,153 15,154 42,155 45,156 55,158 50,159 48,161 60,162 45,163 28,164 25,165 45,167 65,168 60,169 60,170 65,171 70,172 80,173 40,174 68,175 55,176 55,177 60,178 18,179 55,180 100"
_RES_BY_ID = "1 35,2 55,3 35,4 40,5 25,6 20,7 55,8 60,9 50,10 45,11 50,12 30,13 65,14 70,15 20,16 30,17 45,18 55,19 50,20 58,21 22,22 42,23 48,24 25,25 50,26 40,27 70,28 55,29 60,30 50,31 45,32 50,33 62,34 55,35 40,36 45,37 55,38 60,39 60,40 40,41 33,42 55,43 32,44 48,45 25,46 58,47 42,48 28,49 30,50 52,51 62,52 55,53 33,54 55,55 48,56 42,57 55,58 32,59 52,60 0,61 55,62 38,63 35,64 58,65 55,66 22,67 40,68 30,69 62,70 40,71 64,72 55,73 32,74 52,75 58,76 30,77 18,78 30,79 30,80 70,81 35,82 40,83 75,84 40,85 55,86 85,87 62,88 8,89 50,90 52,91 88,92 35,93 68,94 50,95 75,96 45,97 28,98 28,99 40,100 55,101 25,102 66,103 65,104 48,105 72,106 42,107 88,108 62,109 15,115 62,117 60,118 35,119 40,120 45,122 70,123 55,124 72,127 55,128 55,129 55,130 40,131 55,141 30,142 50,146 50,147 60,148 72,149 48,150 50,151 55,152 55,153 25,154 28,155 30,156 52,158 32,159 45,161 62,162 40,163 62,164 45,165 50,167 55,168 50,169 60,170 80,171 60,172 85,173 50,174 55,175 58,176 60,177 55,178 20,179 70,180 50"
WIT_ID = {k: int(v) for k, v in (x.split() for x in _WIT_BY_ID.split(','))}
RESV_ID = {k: int(v) for k, v in (x.split() for x in _RES_BY_ID.split(','))}

# ---- 机制词（扫 skill_rework.json 里每人的技能描述；每类只数「有没有」，类别数封顶 2） ----
SURV = {'shield': r'护盾|代命|替.*承', 'cut': r'承受伤害 ?[−-]|受到.*伤害 ?[−-]|减伤|伤害减免|免疫.*伤害|无敌|免疫死亡|不会死亡|锁血|生命.*不会低于|无下限|不死|免死|濒死',
        'heal': r'回复.*生命|恢复.*生命|回血|吸血|生命偷取|汲取.*生命|治疗自己|自愈|复活自己|再生', 'evade': r'闪避|回避|格挡|反击|反伤|无视.*攻击|免疫.*攻击'}
SURV_NEG = r'消耗.*生命|扣除.*生命|自身受到.*伤害|自己.*眩晕|自晕|失去.*生命|生命.*降低'
# 速度机制词（技能描述）：概率再动、提前行动／拉条、先制、敏捷加成；measured 追加行动几率（action_plus_set）取两者较大值，不叠加
SPD_AGAIN = r'(\d+)%[^。；/，]{0,12}再动|再动[^。；/，]{0,12}?(\d+)%'
SPD_AGAIN_PLAIN = r'再动|额外行动|追加行动|行动次数 ?\+'
SPD_PULL = r'提前行动|拉条|行动条|先行动'
SPD_FIRST = r'先制|先手|先攻|优先行动'
SPD_BUFF = r'敏捷 ?\+(\d+)%'
# 辅助（P1-2）：只算「给队友」的治疗／盾／增益／复活／召唤；自己回血、自己复活、目标受治疗降低、驱散敌人都不算。
# 以「友方主语」逐行匹配（技能描述每条效果一行，用 / 分隔）：主语＋动作须同一条里出现
FRIEND = r'(全队|队友|友方|己方|我方|同伴|友军|全体友|每名友|每个友)'
SUP = {'heal': FRIEND + r'[^/]{0,24}(回复|恢复|治疗|回血|复活|起死回生)|(回复|恢复|治疗)[^/]{0,12}' + FRIEND,
       'shield': FRIEND + r'[^/]{0,24}(护盾|免疫死亡|免死|减伤|承受伤害 ?[−-]|代命|援护|替.*承)|替' + FRIEND + r'(承|挡)|代命',
       'buff': FRIEND + r'[^/]{0,24}(\+\d+|提升|加速|提前行动|净化|解除.*异常|驱散.*异常)|光环|领袖',
       'sum': r'召唤|援军|小弟'}
# 彻底独狼（小A 人审：纯自私输出／只顾自己，无任何友方技能）：辅助分压到所有人之下，凑成 E 档（名额约 8%）
SUP_LONE = {'179', '180', '60', '6', '45', '50', '5', '26', '4', '88', '153', '109'}   # 流萤 五条悟 马宝国 吕布 东方教主 劲夫 小痔 曼德斯 窃格瓦拉·周 西西卡 惠惠 牢大
# 技能类别（skill_rework 的 kind）里直接就是给友方的
SUP_KINDS = ('全体治疗', '单体治疗', '治疗', '复活', '复活全体', '全体增益', '光环', '支援', '追加全体治疗')
WIT_KW = {'weak': r'弱点|破绽|克制|斩杀|低于.*%.*生命|处决|补刀|读取|看破|预判|算', 'debuff': r'驱散|减益|破甲|碎甲|降低.*(攻击|防御)|−\d+%'}
RES_KW = r'免疫.*(眩晕|沉默|封印|混乱|魅惑|睡眠|麻痹|控制|减益|异常|状态|放逐)|不受.*(控制|影响)|霸体|抗性|控制抗|异常抵抗'
# 没有重构技能条目的角色（谷雨等）手补的标签：谷雨「代命替同伴承劫＝护盾类、代替倒下后再生＝自回类；治疗／储备／花期＝辅助类」
HANDF = {'175': {'surv': {'shield': 1, 'heal': 1}, 'sup': {'heal': 3, 'shield': 2, 'buff': 2}, 'kinds': {'全体治疗': 2, '复活': 1, '支援': 2}}}


def load(p):
    return json.loads(Path(p).read_text(encoding='utf-8'))


def role_tables():
    sk = load(DATA / 'skill_rework.json')
    base = load(DATA / 'base_line.json')['actors']
    tiers = sk['tiers']
    sup, st = set(map(str, tiers['超强者'])), set(map(str, tiers['强者']))
    tier = {i: ('super' if i in sup else 'strong' if i in st else 'weak') for i in base}
    txt = collections.defaultdict(list)
    for v in sk['skills'].values():
        if v.get('actor') is None or v['name'].startswith('超越极限'):
            continue
        # 「已移除／已并入／不再」类描述是原版效果的注销说明，不是现在有的机制（P1-4：奈叶「原再动效果已移除」曾被当成再动）
        lines = [d for d in v.get('desc', []) if not re.search(r'已移除|已并入|已去掉|已删除|不再', d)]
        txt[str(v['actor'])].append((v.get('kind') or '', v['name'], ' / '.join(lines)))
    return base, tier, txt


def spd_text(t):
    pcts = [int(a or b) for a, b in re.findall(SPD_AGAIN, t)]
    again = min(100, max(pcts)) if pcts else (30 if re.search(SPD_AGAIN_PLAIN, t) else 0)   # 没写几率的再动按 30%
    buf = [int(x) for x in re.findall(SPD_BUFF, t)]
    return {'again': again, 'pull': 30 if re.search(SPD_PULL, t) else 0, 'first': 10 if re.search(SPD_FIRST, t) else 0, 'buff': min(20, max(buf) // 2) if buf else 0}


def feats(aid, txt):
    rows = txt.get(aid, [])
    t = ' / '.join(r[2] + ' / ' + r[1] for r in rows)   # 用 / 分隔，避免跨技能串台（P2-4：天虎令、伊莉雅再动几率串到别的技能的 %）
    cnt = lambda tab: {c: len(re.findall(p, t)) for c, p in tab.items()}
    f = {'surv': cnt(SURV), 'spd': spd_text(t), 'sup': cnt(SUP), 'wit': cnt(WIT_KW), 'res': len(re.findall(RES_KW, t)),
         'surv_neg': len(re.findall(SURV_NEG, t)), 'kinds': collections.Counter(r[0] for r in rows)}
    for k, v in HANDF.get(aid, {}).items():
        f[k] = {**f[k], **v}
        if k == 'kinds':
            f[k] = collections.Counter({**f[k], **v})
    return f


# ---- 整理探针日志 ----
def ingest(calib, stats, first=(), surv=()):
    rows, skip, st, pf, dis = {}, set(), {}, {}, set()
    sv = collections.defaultdict(list)
    for fn in surv:   # K_SURV seed=N {json}：每个种子一行
        for l in open(fn, errors='ignore'):
            m = re.match(r'K_SURV seed=\d+ (\{.*\})', l)
            if m:
                r = json.loads(m.group(1))
                sv[str(r['actor'])].append(r)
    for fn in first:   # 第一次量（没带 --add-rework）的峰值，只用来在报告里说「补技能后变了谁」
        for l in open(fn, errors='ignore'):
            if l.startswith('K_ROW '):
                r = json.loads(l[6:])
                pf[str(r['actor'])] = r['peak']
    for fn in calib:
        for l in open(fn, errors='ignore'):
            if l.startswith('K_ROW '):
                r = json.loads(l[6:])
                rows[str(r['actor'])] = {'peak': r['peak'], 'skill': r.get('skill'), 'segs': r.get('segs', {}).get('n'), 'mhp': r.get('mhp')}
                skip.discard(str(r['actor']))
            elif l.startswith('K_SKIP '):
                a = l.split()[1]
                if 'disabled' in l:
                    dis.add(a)
                if a not in rows:
                    skip.add(a)
    for fn in stats:
        for l in open(fn, errors='ignore'):
            if l.startswith('K_STAT '):
                r = json.loads(l[7:])
                st[str(r['actor'])] = {k: r[k] for k in ('mhp', 'mmp', 'atk', 'def', 'mat', 'mdf', 'agi', 'luk', 'action_plus', 'attack_times', 'sparam', 'xparam')}
    acts = {str(v['id']): v for v in load(DB / 'Actors.json') if v} if (DB / 'Actors.json').is_file() else {}
    base = load(DATA / 'base_line.json')['actors']
    out = {}
    for i in base:
        e = {}
        if i in rows:
            e.update(rows[i])
        if i in st:
            e['stat'] = st[i]
        if i in acts:
            e['state_resist_n'] = len({t['dataId'] for t in acts[i].get('traits', []) if t['code'] == 14})
        if i in sv:
            rs = sv[i]
            e['surv'] = {'n': len(rs), 'taken': statistics.median(r['taken'] for r in rs), 'rounds': statistics.median(r['rounds'] for r in rs), 'died': sum(1 for r in rs if r['died']), 'healed': statistics.median(r['healed'] for r in rs), 'atk': rs[0]['atk']}
        if i in skip:
            e['no_damage_row'] = True
        if i in dis or (i in acts and 'CodexDisabledActor' in acts[i].get('note', '')):
            e['disabled'] = True   # 停用角色（146 苍龙破晓、152 徐凤年、161 胡桃、141 女儿国王）：不占名额，六维暂记 C
            e.pop('surv', None)
        if i in pf and i in rows and pf[i] != rows[i]['peak']:
            e['peak_first'] = pf[i]
        out[i] = e
    MEAS.write_text(json.dumps({'_note': '六维打分.py 的实测输入（由 --ingest 生成）：peak＝k_calibrate 含烙印整次施放峰值；stat＝--stats 标准养成面板；no_damage_row＝探针量不出伤害', 'actors': out}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')


# ---- 算分 ----
def raw_scores(base, tier, txt, meas):
    ids = sorted(base, key=int)
    notes = {}
    out = {i: {} for i in ids}
    panel = {}
    # 输出：实测峰值；没量到的：辅助职责＝无伤害技能记 0，其余按同档实测中位数
    peak = {i: meas[i]['peak'] for i in ids if 'peak' in meas.get(i, {})}
    med = {t: statistics.median([peak[i] for i in peak if tier[i] == t]) for t in CN}
    for i in ids:
        if i in peak:
            out[i]['output'] = float(peak[i])
        elif base[i]['role'] == '辅助':
            out[i]['output'] = 0.0
            notes[i] = '输出：无伤害技能，按 0'
        else:
            out[i]['output'] = float(med[tier[i]])
            notes[i] = '输出：无实测，按同档实测中位数'
    # 面板：没有 K_STAT 的（141、161）按同职责实测中位数
    stat = {i: meas[i]['stat'] for i in ids if 'stat' in meas.get(i, {})}
    def stat_of(i):
        if i in stat:
            return stat[i]
        same = [stat[j] for j in stat if base[j]['role'] == base[i]['role']]
        notes[i] = (notes.get(i, '') + '；' if i in notes else '') + '面板：无实测，按同职责中位数'
        return {k: statistics.median(s[k] for s in same) for k in ('mhp', 'def', 'mdf', 'agi', 'action_plus')} | {'sparam': [1.0] * 10, 'xparam': [0.05] * 10}
    for i in ids:
        f = feats(i, txt)
        s = stat_of(i)
        # 生存＝实测（回合数优先）：标准敌人（攻击固定，每回合物理＋魔法各打一下）面前，角色自动战斗带着自己的护盾／回复／减伤／复活技能打到死（最多 60 回合），
        # 取 3 个种子「死前总承伤」的中位数（含被治疗又掉掉的血，护盾撑住的回合会让它变大）；没有实测的用面板兜底：有效生命÷同职责面板中位×同职责实测中位
        sp, xp = s['sparam'], s['xparam']
        dur = s['mhp'] * (s['def'] + s['mdf']) / 2.0 / ((sp[6] + sp[7]) / 2.0) / (1.0 - min(0.5, (xp[1] + xp[4]) / 2.0))
        panel[i] = dur
        sv = meas.get(i, {}).get('surv')
        if sv:
            out[i]['survive'] = float(sv['rounds']) * 1e9 + float(sv['taken'])   # 先比撑过的回合数，同回合再比死前总承伤
        else:
            out[i]['survive'] = None
        # 速度＝敏捷×(100＋再动＋拉条＋先制＋敏捷加成)÷100：再动＝max(面板追加行动几率×100, 技能描述里的「N%再动」，没写几率按 30)，拉条／提前行动 +30，先制 +10，敏捷 +x% 取 x/2（封 20）
        sx = f['spd']
        out[i]['speed'] = s['agi'] * (100 + max(round(100 * s['action_plus']), sx['again']) + sx['pull'] + sx['first'] + sx['buff']) / 100.0
        # 辅助：职责底分＋友方技能类别（封顶 2），同分看治疗类技能种类数
        kb = f['kinds']
        healk = sum(kb.get(k, 0) for k in SUP_KINDS)
        sb = {'辅助': 5, '坦克': 3, '均衡': 2, '输出': 1}[base[i]['role']]
        out[i]['support'] = (sb + min(2, sum(1 for v in f['sup'].values() if v > 0))) * 1000 + healk * 10 + sum(f['sup'].values())
        if i in SUP_LONE:
            out[i]['support'] = min(out[i]['support'], 500)   # 独狼一律压到同一个分数（并列同档＝E）
        # 战商／韧性：手标分
        nm = base[i]['name']
        out[i]['wit'] = WIT_ID[i] * 10 + min(9, f['wit']['weak'] * 2 + f['wit']['debuff'])
        out[i]['resolve'] = RESV_ID[i] * 10 + min(9, f['res'] * 3) + meas.get(i, {}).get('state_resist_n', 0) * 3
    # 生存没有实测的：按面板有效生命在同职责里的比例，换算到同职责实测中位数
    for i in ids:
        if out[i]['survive'] is None:
            same = [j for j in ids if base[j]['role'] == base[i]['role'] and out[j]['survive'] is not None]
            if same:
                out[i]['survive'] = statistics.median(out[j]['survive'] for j in same) * panel[i] / statistics.median(panel[j] for j in same)
            else:
                out[i]['survive'] = 0.0
            notes[i] = (notes[i] + '；' if i in notes else '') + '生存：无实测，面板兜底'
    return ids, out, notes


def quota_letters(order, vals):
    """order＝从强到弱的名单，vals＝对应分值；按 CUM 配档。分值相同的人（并列）取并列组的平均名次定档，所以并列的人同档（这时实际人数会偏离名额）。"""
    n = len(order)
    res, k = {}, 0
    while k < n:
        j = k
        while j + 1 < n and vals[order[j + 1]] == vals[order[k]]:
            j += 1
        pos = (k + j) / 2.0 + 0.5      # 并列组的平均名次（1 起）
        for L, c in CUM:
            if pos <= n * c / 1000.0:
                break
        for i in order[k:j + 1]:
            res[i] = L
        k = j + 1
    return res


def assign(ids_all, raw, tier, mode, disabled=frozenset()):
    ids = [i for i in ids_all if i not in disabled]   # 停用角色不进排名、不占名额
    rank = {d: sorted(ids, key=lambda i: (-raw[i][d], int(i))) for d in DIMS}
    let = {i: {} for i in ids_all}
    for i in disabled:
        for d in DIMS:
            let[i][d] = 'C'
    for d in DIMS:
        if mode == 'A':   # 各档位内部自己排名
            for t in CN:
                sub = [i for i in rank[d] if tier[i] == t]
                for i, L in quota_letters(sub, {i: raw[i][d] for i in sub}).items():
                    let[i][d] = L
        else:
            for i, L in quota_letters(rank[d], {i: raw[i][d] for i in ids}).items():
                let[i][d] = L
    if mode in ('B', 'B2', 'B6'):   # 全库一把尺，再按档位基础分（封顶 S／封底 E）
        # B6＝每维 ±1（总分约 ±6，第三版的 B）；B＝收窄版（小A 人审建议）：只动输出、生存、速度三个核心战斗维，总分约 ±3
        dims_b = DIMS if mode == 'B6' else ['output', 'survive', 'speed'] if mode == 'B' else ['output', 'survive']
        for i in ids:
            for d in dims_b:
                v = S[let[i][d]]
                if tier[i] == 'super' and v < 6:
                    v += 1
                elif tier[i] == 'weak' and v > 1:
                    v -= 1
                let[i][d] = LET[v - 1]
    pos = {d: {i: n for n, i in enumerate(rank[d])} for d in DIMS}
    sc = lambda i: {d: S[let[i][d]] for d in DIMS}

    def cap_s(c):
        return 1 if c == 'weak' else 2

    def viol(i):
        x = sc(i)
        ss = [d for d in DIMS if x[d] == 7]
        sss = [d for d in DIMS if x[d] == 8]
        s6 = [d for d in DIMS if x[d] == 6]
        bad = []
        if len(ss) + len(sss) > 1:
            bad.append('multi')
        if ss:
            rest = [v for d, v in x.items() if d != ss[0]]
            if sum(1 for v in rest if v == 6) > 1:
                bad.append('ss_s')
            if sum(1 for v in rest if v <= 3) < 2:   # Kyo 11-19：SS 的代价至少两个 C 及以下，不用 D
                bad.append('cost')
        if not ss and not sss and len(s6) > cap_s(tier[i]):
            bad.append('s_cap')
        return bad

    changes = []

    def demote(i, d):
        old = let[i][d]
        let[i][d] = LET[S[old] - 2]
        changes.append((i, d, old, let[i][d]))

    for _ in range(80):
        moved = False
        for i in ids:
            v = viol(i)
            if not v:
                continue
            x = sc(i)
            if 'multi' in v:
                ds = [d for d in DIMS if x[d] >= 7]
                keep = min(ds, key=lambda d: pos[d][i])
                for d in ds:
                    if d != keep:
                        demote(i, d)
                moved = True
            elif 'ss_s' in v:   # SS 之外 S 超过 1 个：先压名次最靠后的那个 S，保住 SS
                ssd = [d for d in DIMS if x[d] == 7][0]
                demote(i, max([d for d in DIMS if x[d] == 6 and d != ssd], key=lambda d: pos[d][i]))
                moved = True
            elif 'cost' in v:
                demote(i, [d for d in DIMS if x[d] == 7][0])
                moved = True
            elif 's_cap' in v:
                demote(i, max([d for d in DIMS if x[d] == 6], key=lambda d: pos[d][i]))
                moved = True
        if not moved:
            break
    # SSS：每维全库第 1 名，其余五维过 R1（无 S 以上、至多 1 个 A、至少 3 个 ≤C、至少 1 个 ≤D、总分 ≤22）才给，否则空
    sss = []
    for d in DIMS:
        i = rank[d][0]
        x = sc(i)
        rest = [v for k, v in x.items() if k != d]
        ok = all(v < 6 for v in rest) and sum(1 for v in rest if v == 5) <= 1 and sum(1 for v in rest if v <= 3) >= 3 and any(v <= 2 for v in rest) and sum(rest) + 8 <= 22
        sss.append((d, i, ok))
        if ok and not any(S[let[i][k]] == 8 for k in DIMS):
            let[i][d] = 'SSS'
    return let, rank, changes, sss


def total(row):
    return sum(S[row[d]] for d in DIMS)


def tier_stats(ids, let, tier):
    out = {}
    for t in CN:
        v = sorted(sum(S[let[i][d]] for d in DIMS) for i in ids if tier[i] == t)
        lo, hi = BUDGET[t]
        out[t] = {'n': len(v), 'min': v[0], 'med': statistics.median(v), 'mean': statistics.mean(v), 'max': v[-1], 'over': sum(1 for x in v if not lo <= x <= hi), 'hist': collections.Counter(v)}
    return out


# ---- 报告 ----
def report(ids, base, tier, raw, meas, notes, res, mode_w, old_sample, prev, txt0):
    A = {i: {d: res[mode_w][0][i][d] for d in DIMS} for i in ids}
    let, rank, changes, sss = res[mode_w]
    L = []
    w = L.append
    ts = {m: tier_stats(ids, res[m][0], tier) for m in MODES}
    stc = ts['C']
    g = let['175']
    rk = lambda d, i: rank[d].index(i) + 1
    w('# 六维全员重算报告（T280，cc Sonnet＋medium；第二版：速度、生存换实测）\n')
    w('依据：设定稿《天启篇_角色六维_v0.3定稿》；T271 全员名次表；Kyo 11-19 23:5x 原话（「谷雨不对……生存至少也是 S」「SS 给得太容易，或者超强者／强者／弱者的总分给得不合理」「SS 的代价：至少两个 C 及以下，不用 D」「六维难倒不是量完之后重定吗」）。**本表是草稿，`six_dim.json` 只在分支里，等 Kyo 过目改完再合。**四骑士、普怪模板沿用 T275。战商、韧性两维手标分这一版**没动**，交小A 人审。\n')
    w('## 0. 先说结论（名额口径算出来明显怪的地方）\n')
    w('1. **总分在全库一把尺（口径 C）下没分档**：超强者均值 %.1f、强者 %.1f、弱者 %.1f（中位 %s／%s／%s）。只有输出一维真跟档位挂钩，其余五维名额一压差不多。R4 预算下弱者超 %d 份、强者超 %d 份、超强者超 %d 份，R4 按 Kyo 令只报告不拦。**三种分档方式各算了一版，见第 6 节，不预设。**' % (stc['super']['mean'], stc['strong']['mean'], stc['weak']['mean'], stc['super']['med'], stc['strong']['med'], stc['weak']['med'], stc['weak']['over'], stc['strong']['over'], stc['super']['over']))
    w('2. **谷雨（175）按实测算出来是：%s，总分 %d**（口径 C）。输出 %s；生存排第 %d（S 的线是第 16 名）、辅助排第 %d。没硬套 Kyo 的「生存至少 S」，对不上的在第 4 节标出。她在 `skill_rework.json` 里没有重构技能条目，机制标签是按 ActorNote 手补的。' % (' '.join('%s %s' % (DN[d], g[d]) for d in DIMS), total(g), g['output'], rk('survive', '175'), rk('support', '175')))
    nmeas = sum(1 for i in ids if 'peak' in meas.get(i, {}))
    nsv = sum(1 for i in ids if 'surv' in meas.get(i, {}))
    w('3. **这一版实测补强**：输出 %d/156 人有实测（补量 20 人里 14 人量到，其余按同档中位数代入、表里标 ※）；**生存＝每人在标准敌人面前自动战斗挨打的回合数（%d 人有实测，3 种子中位数）**；速度＝标准养成敏捷×（追加行动几率＋技能描述里的再动／拉条／先制／敏捷加成），并列的人同档。战商、韧性仍是手标分，**可信度低，等小A 人审**；辅助仍是职责＋关键词，可信度中低。\n   **生存实测的局限**：单人对一个敌人，只能反映「自己救自己」；钟离这类「全队护盾」「嘲讽替队友扛」的设计价值在队伍里才显出来，这里测不到，要不要手改，请 Kyo 看。' % (nmeas, nsv))
    gaps = [(k, d, old_sample[k][d], let[k][d]) for k in old_sample for d in ('survive', 'speed') if abs(S[old_sample[k][d]] - S[let[k][d]]) >= 3]
    if gaps:
        w('4. **和设定稿样板差 3 档以上的**（口径 C，旧→新）：' + '；'.join('%s %s %s→%s' % (base[k]['name'], DN[d], a, b) for k, d, a, b in gaps) + '。这些是设定稿手标分和实测对不上的地方，是否按设计手改，请 Kyo 看。\n')
    if prev:
        w('5. **和第三版（上一次提交）比，谁变了、为什么**（口径 C）：')
        for d in ('survive', 'speed'):
            ch = [(i, prev[i][d], let[i][d]) for i in ids if prev[i][d] != let[i][d]]
            up = sum(1 for i, a, b in ch if S[b] > S[a])
            w('   - %s：%d 人变了档位（升 %d、降 %d）。' % (DN[d], len(ch), up, len(ch) - up))
        for k in ('107', '175', '180', '174', '45'):
            sv = meas[k].get('surv', {})
            sx = feats(k, txt0)['spd']
            w('   - %s：生存 %s→%s（撑 %s 回合、死前总承伤 %.0f 万、被治疗 %.0f 万）；速度 %s→%s（agi %d、面板追加行动 %.2f、描述里再动 %d／拉条 %d／先制 %d／敏捷加成 %d）。' % (base[k]['name'], prev[k]['survive'], let[k]['survive'], sv.get('rounds', '—'), sv.get('taken', 0) / 1e4, sv.get('healed', 0) / 1e4, prev[k]['speed'], let[k]['speed'], meas[k]['stat']['agi'], meas[k]['stat']['action_plus'], sx['again'], sx['pull'], sx['first'], sx['buff']))
        w('   - 为什么：生存变化主要来自剔除 7242 生命之火（弱者不再白捡两倍血和每回合 15% 回血）；辅助只算给队友的技能；战商、韧性换成逐人手标；奈叶再动误判去掉。速度只有再动误判那几个人变。')
    w('6. **第四版（小A 人审退回后）修了什么**：①生存实测里把天启篇不掉的「权能·生命之火」（7242，生命 ×2、每回合回 15%）从秘籍候选里剔除（原来它当 0 分填充物只学给了秘籍格 6 个的弱者，弱者全库前 29 名都是它造成的），重跑 `--survive`；②辅助只算「给队友」的治疗／盾／增益／复活，自疗、自复活、驱散敌人不再算；③战商、韧性 156 人全部显式手标（采纳小A 清单），不再有缺省 50；④再动正则排除「已移除／已并入」类描述（奈叶）；⑤停用角色（146、152、161、141）不占名额；⑥分档增加收窄版 B；⑦D239 四人标记同步到第 7 节和 `_note`；⑧单人测不到的机制（全队盾、嘲讽、先自伤后变身）列成建议手改清单（第 7 节）。\n')
    w('## 1. 口径与名额\n')
    w('- 范围：`base_line.json` 全部 156 人（含 146 苍龙破晓、152 徐凤年等不一定会进卡池的）。档位按 `skill_rework.json` tiers：超强者 17、强者 52、其余 87 为弱者。')
    w('- 名额（口径 C，全库一把尺）：SS 前 3.2%、S 累计 10.3%、A 累计 25%、B 累计 50%、C 累计 75%、D 累计 92.3%、其余 E；156 人时 SS5／S11／A23／B39／C39／D27／E12（并列的人取并列组平均名次同档，所以实际人数略偏离）；停用角色不占名额；SSS 每维只看第 1 名。')
    w('- **SSS**：每维第 1 名，其余五维过 R1（无 S 以上、至多 1 个 A、至少 3 个 ≤C、至少 1 个 ≤D、总分 ≤22）才给：' + '；'.join('%s 第 1 %s%s' % (DN[d], base[i]['name'], '给 SSS' if ok else '不够格留空') for d, i, ok in sss) + '。')
    w('- **降档**：配完名额逐人查 R2（SS 与 SSS 合计 ≤1、其余五维 S 至多 1 个、**其余五维至少 2 项 ≤C**）、R3（无 SS／SSS 时 S：弱者 ≤1、强者／超强者 ≤2），不够格降一档，不回补名额；口径 C 共降档 %d 次。\n' % len(changes))
    w('## 2. 各维实际档位分布（口径 C，降档后）\n')
    w('| 维度 | SSS | SS | S | A | B | C | D | E |\n|---|---|---|---|---|---|---|---|---|')
    for d in DIMS:
        c = collections.Counter(let[i][d] for i in ids)
        w('| %s | %s |' % (DN[d], ' | '.join(str(c[l]) for l in reversed(LET))))
    w('')
    w('## 3. 每一维怎么算（公式）\n')
    w('所有量都在同一套标准养成下取：81 级、进阶满、每栏挑主属性最高的一件神话装备、本人专属法宝 99 级、技能熟练度拿满（`k_calibrate` 的 `_state`）。')
    w('| 维度 | 公式 | 可信度 |\n|---|---|---|')
    w('| 输出 | `k_calibrate --tier=all --exact` 含烙印整次施放峰值（T271 口径）。没量到的：纯辅助记 0；其余按同档实测中位数代入（※）。渡鸦用 `--soul=200000` 灌满魂量。 | 高（※ 除外） |')
    w('| 生存 | **实测挨打**：标准敌人（攻击固定 %d，每回合物理＋魔法各打一下，伤害走游戏自己的防御／魔防／承伤率／档位承伤／护盾／减伤／复活结算）面前，角色**自动战斗**带着自己的护盾、回复、减伤、复活类技能正常放（魔法、TP 照耗），打到倒下（最多 60 回合）；取 3 个种子「撑过的回合数」的中位数排名，同回合再比死前总承伤。角色自动战斗之外加一条「保命技先放」：技能表里不带伤害、类别是护盾／治疗／复活或描述含自盾／减伤／免死／回血的技能，能用就放（护盾减伤类每回合，回复类血量不到 90%% 才放），因为游戏自带自动战斗的默认选招不一定放它们。面板（生命、防御）只给没实测的人兜底。 | 高（自动战斗选招是游戏自己的 AI） |' % ATK_SURV)
    w('| 速度 | **敏捷 × 行动次数**：`agi × (100 ＋ 再动 ＋ 拉条 ＋ 先制 ＋ 敏捷加成)/100`：再动＝max(面板追加行动几率合计×100，技能描述里「N%再动」，没写几率的再动按 30)；技能描述里有「提前行动／拉条」+30、「先制／先手」+10、「敏捷 +x%」取 x/2（封 20）。agi 和追加行动几率取标准养成面板（模块里的条件再动，如五条悟六眼 10%，面板读不到，由描述补）。 | 中高 |')
    w('| 辅助 | 职责底分（辅助5／坦克3／均衡2／输出1）＋友方技能类别（治疗·复活／护盾·代命／增益·光环·驱散／召唤，封顶 2）；同分看治疗类技能种类数＋词条数。**这一版没动。** | 中低 |')
    w('| 战商 | **手标分**（依据原作人设，缺省 50），＋弱点／控制／减益词小项。**没动，等小A 人审。** | 低 |')
    w('| 韧性 | **手标分**＋抗控词＋原版状态免疫特性数。**没动，等小A 人审。** | 低 |')
    w('')
    w('## 4. 谷雨（175）\n')
    w('| | 输出 | 生存 | 速度 | 战商 | 韧性 | 辅助 | 总分 |\n|---|---|---|---|---|---|---|---|')
    w('| T275 设定稿样板（已撤，Kyo 11-19 说不对） | E | C | C | B | C | SSS | 22 |')
    w('| **本次按实测（口径 C）** | %s | **%s** | %s | %s | %s | %s | **%d** |' % (*[g[d] for d in DIMS], total(g)))
    w('| 上一版草稿（关键词版） | %s | %s | %s | %s | %s | %s | %d |' % (*[prev['175'][d] for d in DIMS], total(prev['175'])) if prev else '| 上一版草稿 | — | — | — | — | — | — | — |')
    w('| Kyo 说的（只作对照） | 爆发输出 S | 生存至少 S | — | — | — | — | — |')
    s175 = meas['175']['stat']
    w('')
    w('- 输出 %s：实测含烙印 %.1f 万，全库第 %d。' % (g['output'], raw['175']['output'] / 1e4, rk('output', '175')))
    sv175 = meas['175'].get('surv', {})
    w('- 生存 %s（排第 %d）：标准敌人面前撑 %s 回合、死前总承伤 %.0f 万、期间被治疗 %.0f 万（3 种子中位数）；面板 生命 %d、物防 %d、魔防 %d。到不到 S 还看「代命」这类机制在自动战斗里放不放得出来，**是设计判断，不是排名能算出来的**，请 Kyo 定。' % (g['survive'], rk('survive', '175'), sv175.get('rounds'), sv175.get('taken', 0) / 1e4, sv175.get('healed', 0) / 1e4, s175['mhp'], s175['def'], s175['mdf']))
    w('- 辅助 %s（排第 %d）：设定稿给 SSS，名额口径下 SSS／SS 全库只有 0／3 个，她的治疗／储备／花期词条没被扫到，手补了治疗 3、护盾 2、增益 2 仍排在辅助职责角色之后。' % (g['support'], rk('support', '175')))
    w('- 速度 %s：agi %d，追加行动 %.2f。\n' % (g['speed'], s175['agi'], s175['action_plus']))
    w('## 5. 与 T275 十三份样板对照（旧→新，口径 C）\n')
    w('| 角色 | 旧（输出 生存 速度 战商 韧性 辅助） | 新 | 旧总分→新总分 |\n|---|---|---|---|')
    for k, r0 in old_sample.items():
        r = let[k]
        w('| %s（%s） | %s | %s | %d→%d |' % (base[k]['name'], k, ' '.join(r0[d] for d in DIMS), ' '.join(r[d] for d in DIMS), total(r0), total(r)))
    if prev:
        ch = {d: sum(1 for i in ids if prev[i][d] != let[i][d]) for d in DIMS}
        w('\n与上一版草稿（关键词版）比，每维变了档位的人数：' + '、'.join('%s %d' % (DN[d], ch[d]) for d in DIMS) + '（战商、韧性变化只来自降档连带）。')
    w('')
    w('## 6. 总分分档方式（A／B／B2／B6／C 各算一版，只给数，不预设，请 Kyo 选）\n')
    w('- **A 各档位自己排名配名额**：超强者、强者、弱者各自内部按同一套名额配档；\n- **B 收窄版（小A 人审推荐）**：全库一把尺先按 C 配档，再只动输出、生存、速度三个核心战斗维——超强者各 +1 档（封到 S）、弱者各 −1 档（封到 E）、强者不动，总分约 ±3，之后同样 R1～R3 降档；\n- **B2 更窄**：只动输出、生存两维，总分约 ±2；\n- **B6 每维 ±1（第三版的 B）**：六维全动，总分约 ±6，留作对照；\n- **C 全库一把尺、不管档位**（现在写在 six_dim.json 里的）。\n')
    w('| 方式 | 档 | 份数 | 总分最小 | 中位 | 均值 | 最大 | 预算 | 超出预算 |\n|---|---|---|---|---|---|---|---|---|')
    for m in MODES:
        for t in ('super', 'strong', 'weak'):
            s = ts[m][t]
            lo, hi = BUDGET[t]
            w('| %s | %s | %d | %d | %s | %.1f | %d | %d～%d | %d |' % (m, CN[t], s['n'], s['min'], s['med'], s['mean'], s['max'], lo, hi, s['over']))
    w('')
    w('总分分布（份数）：\n')
    w('| 方式·档 | ' + ' | '.join(str(x) for x in range(8, 40)) + ' |\n|---|' + '---|' * 32)
    for m in MODES:
        for t in ('super', 'strong', 'weak'):
            h = ts[m][t]['hist']
            w('| %s·%s | ' % (m, CN[t]) + ' | '.join(str(h[x]) if h[x] else '' for x in range(8, 40)) + ' |')
    w('')
    w('**小A 推荐 B2**（本版超强 %.1f／强 %.1f／弱 %.1f）：三档均值阶梯清晰、弱者均值落回预算正中、超强者顶出上限的人最少；若 Kyo 要强弱差距再大一点、不介意超强者普遍 27～28 分，备选 B。（以上是核查方意见，选哪个由 Kyo 定。）\n' % (ts['B2']['super']['mean'], ts['B2']['strong']['mean'], ts['B2']['weak']['mean']))
    w('读法：A 的三档均值几乎相等（名额按档内比例分，总分必然一样），档位差全靠战斗里的出伤倍率去体现；B 拉开档位差又不过分；B6 拉得最开，超强者容易顶到预算上沿以外；C 是现状。\n')
    w('## 7. 要 Kyo 定的事\n')
    w('1. **总分怎么分档**：A／B／B2／B6／C（第 6 节）；小A 推荐 B2。')
    w('2. **谷雨生存、辅助**怎么定：照实测，还是 Kyo 直接指定；直接指定建议加一行「手改理由」，不混进名额算法。')
    w('3. 战商、韧性手标分（已全员显式手标，采纳小A 清单；第五版再按复核下调：韧性 伊莉雅 95→72、町甄／要乐奈／小铃兰／爱莉／立希 62→55、诸葛孔明 72→64、拳一 70→62；战商 刘备 62→55、阿语 85→75、布兰德瓦登 50→42，全部同意小A 意见。Kyo 可再改脚本里 WIT_ID／RESV_ID）。')
    w('4. 东方教主输出低（第 9 节）要不要接受，还是设计上要给他补一个爆发招。')
    w('5. **D239 待定的四人**：绿司机（2）、维利（22）、狗逍遥（1）、诛仙（162）补量后输出超出 Kyo 定的区间，Kyo 定后这四人的输出档可能变（表里已标，six_dim.json 的 _note 也写了）。')
    w('6. **建议手改清单（单人挨打测不到的机制）**：见下表，生存档要不要手改请 Kyo 定。\n')
    w('| 角色 | 现生存档 | 单人实测 | 为什么测不到 | 建议 |\n|---|---|---|---|---|')
    for k, why, sug in (('107', '全队护盾（20%／10%／30% 生命盾）、全队免死 1 回合、被动减伤，价值在队伍里；单人只能盾自己', '生存 S'),
                         ('128', '300% 受击率嘲讽＋反伤，替队友扛；单人 1 对 1 没有队友可护', '生存 B'),
                         ('131', '同张楚岚，专职嘲讽坦克', '生存 B'),
                         ('168', '黑龙形态（+20% 生命、−10% 承伤）挂在伤害技上，保命技规则不会先开；被动「禁忌」每次放技自扣 5% 血，没队友奶妈', '生存 B（保底 C）'),
                         ('102', '全队每回合回 3% 血光环、开局敌伤 −30%，价值在队伍里（现 A 已够，不手改）', '生存 A 维持'),
                         ('89', '500% 受击率嘲讽＋说唱全队治疗／加伤，替队友扛；单人 1 对 1 没有队友可护', '生存 B'),
                         ('39', '流沙护体：全队抵抗一次除大地以外的伤害，价值在队伍里', '生存 B'),
                         ('180', '无下限「每回合第一次被单体攻击拦下」被每回合两下打穿，反转术式抽蓝', '生存 维持，仅供参考')):
        sv = meas.get(k, {}).get('surv', {})
        w('| %s（%s） | %s | 撑 %s 回合、承伤 %.0f 万 | %s | %s |' % (base[k]['name'], k, let[k]['survive'], sv.get('rounds', '—'), sv.get('taken', 0) / 1e4, why, sug))
    w('')
    w('## 8. R4 报告（口径 C，只报告不拦）\n')
    w('见第 6 节表里 C 行；`天启篇数据校验.py` 每次校验也打印同样的分档总分报告行。\n')
    chg = sorted(((i, meas[i]['peak_first'], meas[i]['peak']) for i in ids if 'peak_first' in meas.get(i, {})), key=lambda x: -abs(x[2] - x[1]) / max(1, x[1]))
    w('## 9. 东方教主（45）输出为什么低，以及这次补量带出的问题\n')
    m45 = meas['45']
    w('**第一版量到 %.1f 万、排第 145，是量漏了，不是真弱到那个程度。**原因：`k_calibrate` 只量 `skill_ids`（角色当前学会的技能）里的伤害技能，东方教主的普攻「劫运神镖」（6161，三段）不在里面，只量到「漫天花雨」一招。加 `--add-rework`（技能表里有伤害、却不在 `skill_ids` 里的也补进来）后量到 **%.1f 万**（技能 %s，%s 段，排第 %d）。他的设计是「攻击次数 +1、一石三鸟和漫天花雨 30%% 再放一次、追加行动」靠出手次数补，探针按一次施放量、不乘出手次数，所以仍偏低（输出 %s），**这是口径问题，不是数据错**；要不要给他补一个爆发招是设计判断，请 Kyo 定。' % (m45.get('peak_first', m45['peak']) / 1e4, m45['peak'] / 1e4, m45.get('skill'), m45.get('segs'), rk('output', '45'), let['45']['output']))
    w('')
    w('**同一个漏洞影响了别人**：`--add-rework` 补量后峰值变了的有 %d 人（相对变化最大的前 10：%s）。第一版名次对这些人是偏低的。\n' % (len(chg), '、'.join('%s %.0f→%.0f 万' % (base[i]['name'], a / 1e4, b / 1e4) for i, a, b in chg[:10])))
    w('## 10. 全员六维表（156 人，口径 C，按档位、总分从高到低；※＝输出或面板无实测，见备注）\n')
    w('| 档 | 角色号 | 名字 | 输出 | 生存 | 速度 | 战商 | 韧性 | 辅助 | 总分 | 备注 |\n|---|---|---|---|---|---|---|---|---|---|---|')
    for t in ('super', 'strong', 'weak'):
        for k in sorted([i for i in ids if tier[i] == t], key=lambda i: (-total(let[i]), int(i))):
            r = let[k]
            nt = notes.get(k, '')
            if meas.get(k, {}).get('disabled'):
                nt = (nt + '；' if nt else '') + '停用角色，不占名额，六维暂记 C'
            if k in D239:
                nt = (nt + '；' if nt else '') + '输出：补量后超区间，D239 待 Kyo 定，档位可能变'
            mark = '※' if nt and '按 0' not in nt else ''
            w('| %s | %s | %s | %s%s | %s | %s | %s | %s | %s | %d | %s |' % (CN[t], k, base[k]['name'], r['output'], mark, r['survive'], r['speed'], r['wit'], r['resolve'], r['support'], total(r), nt))
    w('')
    w('## 11. 怎么重跑\n')
    w('打分脚本：`03_再刷重制_Godot/07_开发环境/六维打分.py`；实测输入：同目录 `六维打分_实测数据.json`。')
    w('- 只改手标分／机制词／名额：改脚本顶部 WIT、RESV、HANDF、CUM 后 `python3 03_再刷重制_Godot/07_开发环境/六维打分.py --write`（几秒，会重写 `six_dim.json` 的 actors 和本报告）。')
    w('- 重新实测：脚本文件头「重跑」一节有三条 godot 命令（`k_calibrate` 加了 `--stats`、`--add-rework` 两个开关）和 `--ingest` 的用法。')
    w('- `--mode A|B` 可把另一种分档方式写进 `six_dim.json`；校验 `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py`。\n')
    return '\n'.join(L) + '\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--mode', default='C', choices=MODES)
    ap.add_argument('--ingest', action='store_true')
    ap.add_argument('--calib', nargs='*', default=[])
    ap.add_argument('--stats', nargs='*', default=[])
    ap.add_argument('--surv', nargs='*', default=[], help='生存实测日志（K_SURV）')
    ap.add_argument('--first', nargs='*', default=[], help='第一次量（不带 --add-rework）的日志，只用来对比')
    a = ap.parse_args()
    if a.ingest:
        ingest(a.calib, a.stats, a.first, a.surv)
    base, tier, txt = role_tables()
    meas = load(MEAS)['actors']
    ids, raw, notes = raw_scores(base, tier, txt, meas)
    DISABLED = {i for i in ids if meas.get(i, {}).get('disabled')}
    res = {m: assign(ids, raw, tier, m, DISABLED) for m in MODES}
    for m in MODES:
        ts = tier_stats(ids, res[m][0], tier)
        print(m, ' '.join('%s 均%.1f 中%s 超预算%d' % (CN[t], ts[t]['mean'], ts[t]['med'], ts[t]['over']) for t in CN))
    if not a.write:
        return
    jp = DATA / 'six_dim.json'
    tab = load(jp)
    try:
        prev = {k: {d: v[d] for d in DIMS} for k, v in json.loads(subprocess.check_output(['git', 'show', 'HEAD:' + str(jp.relative_to(REPO))], cwd=REPO, text=True))['actors'].items()}
        if len(prev) != 156:
            prev = None
    except Exception:
        prev = None
    try:
        old = json.loads(subprocess.check_output(['git', 'show', 'c09536415:' + str(jp.relative_to(REPO))], cwd=REPO, text=True))['actors']
    except Exception:
        old = {}
    old = {k: {d: v[d] for d in DIMS} for k, v in old.items()}
    let = res[a.mode][0]
    tab['actors'] = {i: {'name': base[i]['name'], 'class': tier[i], **{d: let[i][d] for d in DIMS}} for i in ids}
    tab['_note'] = ('天启篇六维（T275 表结构；T280 全员按实测重算，设定稿 天启篇_角色六维_v0.3定稿，Kyo D234）。刻度 E～SSS＝1～8 分；全表整数（附则 E）。只读数据，战斗中不重算；本表不碰伤害、血防、敏捷。'
                    ' actors 含 156 人（T280 草稿，待 Kyo 过目，当前写的是分档口径 %s）：输出＝k_calibrate 实测名次；生存＝标准敌人面前自动战斗实测挨打；速度＝敏捷×行动次数（再动／拉条／先制）；辅助＝职责＋机制词；'
                    '战商／韧性＝按角色号逐人手标分名次（依据原作人设／技能，非实测）；按全库名额配档再按 R1～R3 降档；停用角色（146、152、161、141）不占名额、暂记 C；D239 待 Kyo 定：绿司机(2)、维利(22)、狗逍遥(1)、诛仙(162) 补量后输出超区间，输出档可能变。打分脚本 07_开发环境/六维打分.py，报告 07_开发环境/六维全员重算报告.md。') % a.mode
    jp.write_text(json.dumps(tab, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    REPORT.write_text(report(ids, base, tier, raw, meas, notes, res, a.mode, old, prev, txt), encoding='utf-8')
    print('已写', jp.relative_to(REPO), '和', REPORT.relative_to(REPO))


if __name__ == '__main__':
    sys.exit(main())
