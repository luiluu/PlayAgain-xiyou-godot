#!/usr/bin/env python3
"""天启篇六维全员打分（T280）：实测数据 → 名次 → 按全库名额配档 → R1～R3 降档 → six_dim.json 的 actors 段＋报告。

用法（在仓库任意处）：
  python3 03_再刷重制_Godot/07_开发环境/六维打分.py                 只算、只打印各档分布（不写任何文件）
  python3 .../六维打分.py --write                                   把 actors 写回 six_dim.json（口径 C：全库一把尺）＋重写报告
  python3 .../六维打分.py --ingest --calib 日志…  --stats 日志     先把 godot 探针日志整理成 六维打分_实测数据.json 再算（见下「重跑」）
  --mode A|B|C   写哪一版进 six_dim.json（缺省 C；三版的总分分布报告里一直都算）

数据来源（六维打分_实测数据.json，同目录）：
  输出  ＝ k_calibrate 含烙印整次施放峰值（K_ROW.peak）
  生存／速度 ＝ k_calibrate --stats 的标准养成面板（K_STAT：81 级、进阶满、同一套装备）
  辅助  ＝ 职责底分＋技能描述里的友方词（skill_rework.json）
  战商／韧性 ＝ 手标分（下面 WIT／RESV，依据原作人设，不是实测；T280 起交小A 人审）

重跑（量表要 40 分钟左右，都在 03_再刷重制_Godot 目录外的仓库根执行，带 --audio-driver Dummy）：
  G="03_再刷重制_Godot/07_开发环境/godot --headless --audio-driver Dummy --path 03_再刷重制_Godot/01_Godot工程 -s res://tests/test_main_loop.gd res://tests/virtual_player/k_calibrate.tscn --"
  $=G --tier=all --exact > calib.log                    # 输出（K_ROW）；约 35 分钟
  $=G --stats --tier=all > stats.log                    # 面板（K_STAT）；约 1 分钟
  $=G --tier=all --exact --add-rework --soul=200000 --actors=<calib.log 里 K_SKIP 的号,167> > miss.log   # 补量没量到的、渡鸦灌满魂
  python3 .../六维打分.py --ingest --calib calib.log miss.log --stats stats.log --write
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
BUDGET = {'super': (20, 26), 'strong': (18, 25), 'weak': (13, 22)}
# 全库名额（千分位累计）：SS 前 3.2%、S 累计 10.3%、A 25%、B 50%、C 75%、D 92.3%、其余 E（D／E 合计后 25%）。156 人时 SS5 S11 A23 B39 C39 D27 E12
CUM = [('SS', 32), ('S', 103), ('A', 250), ('B', 500), ('C', 750), ('D', 923), ('E', 1000)]

# ---- 战商／韧性手标分（0～100，缺省 50；依据原作人设，T280 起交小A 人审，打分脚本不改它） ----
WIT = {'诸葛孔明': 95, '五条悟': 100, '宇智波·鼬': 85, '命运编织者': 85, '晴明': 80, '曹操': 80, '宿傩': 80, '荒天弟': 75, '张三丰': 75, '孙权': 70, '町甄': 70, '申公豹': 70, '唐三': 70, '爱莉': 70, '伏黑甚尔': 70, '波风水门': 70, '祈求者': 70, '云裳': 68, '渡鸦': 65, '镜流': 65, '白起': 65, '米拉': 60, '黄泉': 60, '法海': 60, '张楚岚': 60, '大羿': 60, '璇': 60, '刘备': 55, '屠苏': 55, '谷雨': 55, '流萤': 55, '伊莉雅': 55, '窃格瓦拉·周': 55, '魔雷老人': 55, '孙悟空': 60, '紫霞仙子': 50, '花木兰': 50, '炭治郎': 50, '修': 45, '西西卡': 40, '黑崎一护': 40, '艾坤': 30, '狗逍遥': 30, '小痔': 30, '吕布': 30, '张飞': 20, '惠惠': 15, '牢大': 10, '马宝国': 0}
RESV = {'钟离': 95, '张三丰': 85, '镜流': 80, '三笠': 75, '伊莉雅': 95, '宇智波·鼬': 75, '荒天弟': 75, '白起': 70, '关羽': 70, '齐格鲁德': 70, '流萤': 70, '宿傩': 70, '町甄': 70, '刘备': 65, '谷雨': 65, '波风水门': 65, '沙和尚': 60, '修': 60, '曹操': 60, '屠苏': 60, '黄泉': 60, '伏黑甚尔': 60, '孙权': 55, '渡鸦': 55, '云裳': 55, '露茜': 55, '五条悟': 50, '艾坤': 35, '狗逍遥': 35, '克莱德': 30, '琼霄': 25, '小痔': 25, '惠惠': 25, '克比': 25, '东方教主': 25, '吕布': 20, '张飞': 20, '碧霄': 20, '牢大': 15, '马宝国': 0}

# ---- 机制词（扫 skill_rework.json 里每人的技能描述；每类只数「有没有」，类别数封顶 2） ----
SURV = {'shield': r'护盾|代命|替.*承', 'cut': r'承受伤害 ?[−-]|受到.*伤害 ?[−-]|减伤|伤害减免|免疫.*伤害|无敌|免疫死亡|不会死亡|锁血|生命.*不会低于|无下限|不死|免死|濒死',
        'heal': r'回复.*生命|恢复.*生命|回血|吸血|生命偷取|汲取.*生命|治疗自己|自愈|复活自己|再生', 'evade': r'闪避|回避|格挡|反击|反伤|无视.*攻击|免疫.*攻击'}
SURV_NEG = r'消耗.*生命|扣除.*生命|自身受到.*伤害|自己.*眩晕|自晕|失去.*生命|生命.*降低'
SPD = {'first': r'先制|先手|优先行动|立即行动', 'bar': r'行动条|拉条|加速|速度提升'}
SUP = {'heal': r'治疗|回复.*(全队|队友|友方|生命)|复活', 'shield': r'给全队|全队每人|友方.*护盾|队友.*护盾|替.*承|代命|援护',
       'buff': r'全队.*\+|友方.*\+|队友.*\+|光环|驱散|净化|增益', 'sum': r'召唤|援军|小弟'}
WIT_KW = {'weak': r'弱点|破绽|克制|斩杀|低于.*%.*生命|处决|补刀|读取|看破|预判|算', 'debuff': r'驱散|减益|破甲|碎甲|降低.*(攻击|防御)|−\d+%'}
RES_KW = r'免疫.*(眩晕|沉默|封印|混乱|魅惑|睡眠|麻痹|控制|减益|异常|状态|放逐)|不受.*(控制|影响)|霸体|抗性|控制抗|异常抵抗'
# 没有重构技能条目的角色（谷雨等）手补的标签：谷雨「代命替同伴承劫＝护盾类、代替倒下后再生＝自回类；治疗／储备／花期＝辅助类」
HANDF = {'175': {'surv': {'shield': 1, 'heal': 1}, 'sup': {'heal': 3, 'shield': 2, 'buff': 2}}}


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
        txt[str(v['actor'])].append((v.get('kind') or '', v['name'], ' / '.join(v.get('desc', []))))
    return base, tier, txt


def feats(aid, txt):
    rows = txt.get(aid, [])
    t = ' '.join(r[2] + ' ' + r[1] for r in rows)
    cnt = lambda tab: {c: len(re.findall(p, t)) for c, p in tab.items()}
    f = {'surv': cnt(SURV), 'spd': cnt(SPD), 'sup': cnt(SUP), 'wit': cnt(WIT_KW), 'res': len(re.findall(RES_KW, t)),
         'surv_neg': len(re.findall(SURV_NEG, t)), 'kinds': collections.Counter(r[0] for r in rows)}
    for k, v in HANDF.get(aid, {}).items():
        f[k] = {**f[k], **v}
    return f


# ---- 整理探针日志 ----
def ingest(calib, stats, first=()):
    rows, skip, st, pf = {}, set(), {}, {}
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
        if i in skip:
            e['no_damage_row'] = True
        if i in pf and i in rows and pf[i] != rows[i]['peak']:
            e['peak_first'] = pf[i]
        out[i] = e
    MEAS.write_text(json.dumps({'_note': '六维打分.py 的实测输入（由 --ingest 生成）：peak＝k_calibrate 含烙印整次施放峰值；stat＝--stats 标准养成面板；no_damage_row＝探针量不出伤害', 'actors': out}, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')


# ---- 算分 ----
def raw_scores(base, tier, txt, meas):
    ids = sorted(base, key=int)
    notes = {}
    out = {i: {} for i in ids}
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
        # 生存＝有效生命 × 机制：mhp×(防御＋魔防)/2÷(物理／魔法承伤率均值)÷(1−闪避＋魔闪均值，封 50%)，再 +15%×机制类别（封顶 2 类）−10%（自损词 ≥2）
        sp, xp = s['sparam'], s['xparam']
        dur = s['mhp'] * (s['def'] + s['mdf']) / 2.0 / ((sp[6] + sp[7]) / 2.0) / (1.0 - min(0.5, (xp[1] + xp[4]) / 2.0))
        mech = min(2, sum(1 for v in f['surv'].values() if v > 0))
        out[i]['survive'] = dur * (100 + 15 * mech - (10 if f['surv_neg'] >= 2 else 0)) / 100.0
        # 速度＝敏捷×(100＋100×追加行动几率合计＋3×先制／拉条词类别数)÷100
        tags = sum(1 for v in f['spd'].values() if v > 0)
        out[i]['speed'] = s['agi'] * (100 + round(100 * s['action_plus']) + 3 * tags) / 100.0
        # 辅助：职责底分＋友方技能类别（封顶 2），同分看治疗类技能种类数
        kb = f['kinds']
        healk = sum(kb.get(k, 0) for k in ('全体治疗', '治疗', '单体治疗', '复活', '复活全体', '全体增益', '护盾', '光环', '支援', '追加全体治疗'))
        sb = {'辅助': 5, '坦克': 3, '均衡': 2, '输出': 1}[base[i]['role']]
        out[i]['support'] = (sb + min(2, sum(1 for v in f['sup'].values() if v > 0))) * 1000 + healk * 10 + sum(f['sup'].values())
        # 战商／韧性：手标分
        nm = base[i]['name']
        out[i]['wit'] = WIT.get(nm, 50) * 10 + min(9, f['wit']['weak'] * 2 + f['wit']['debuff'])
        out[i]['resolve'] = RESV.get(nm, 50) * 10 + min(9, f['res'] * 3) + meas.get(i, {}).get('state_resist_n', 0) * 3
    return ids, out, notes


def quota_letters(order):
    """order＝从强到弱的名单；按 CUM 配档。"""
    n = len(order)
    res, k = {}, 0
    for L, c in CUM:
        end = round(n * c / 1000)
        for i in order[k:end]:
            res[i] = L
        k = end
    return res


def assign(ids, raw, tier, mode):
    rank = {d: sorted(ids, key=lambda i: (-raw[i][d], int(i))) for d in DIMS}
    let = {i: {} for i in ids}
    for d in DIMS:
        if mode == 'A':   # 各档位内部自己排名
            for t in CN:
                sub = [i for i in rank[d] if tier[i] == t]
                for i, L in quota_letters(sub).items():
                    let[i][d] = L
        else:
            for i, L in quota_letters(rank[d]).items():
                let[i][d] = L
    if mode == 'B':       # 全库一把尺，再按档位基础分：超强者每维 +1 档（封到 S）、弱者每维 −1 档（封到 E）
        for i in ids:
            for d in DIMS:
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
            elif 'ss_s' in v or 'cost' in v:
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
def report(ids, base, tier, raw, meas, notes, res, mode_w, old_sample, prev):
    A = {i: {d: res[mode_w][0][i][d] for d in DIMS} for i in ids}
    let, rank, changes, sss = res[mode_w]
    L = []
    w = L.append
    ts = {m: tier_stats(ids, res[m][0], tier) for m in 'ABC'}
    stc = ts['C']
    g = let['175']
    rk = lambda d, i: rank[d].index(i) + 1
    w('# 六维全员重算报告（T280，cc Sonnet＋medium；第二版：速度、生存换实测）\n')
    w('依据：设定稿《天启篇_角色六维_v0.3定稿》；T271 全员名次表；Kyo 11-19 23:5x 原话（「谷雨不对……生存至少也是 S」「SS 给得太容易，或者超强者／强者／弱者的总分给得不合理」「SS 的代价：至少两个 C 及以下，不用 D」「六维难倒不是量完之后重定吗」）。**本表是草稿，`six_dim.json` 只在分支里，等 Kyo 过目改完再合。**四骑士、普怪模板沿用 T275。战商、韧性两维手标分这一版**没动**，交小A 人审。\n')
    w('## 0. 先说结论（名额口径算出来明显怪的地方）\n')
    w('1. **总分在全库一把尺（口径 C）下没分档**：超强者均值 %.1f、强者 %.1f、弱者 %.1f（中位 %s／%s／%s）。只有输出一维真跟档位挂钩，其余五维名额一压差不多。R4 预算下弱者超 %d 份、强者超 %d 份、超强者超 %d 份，R4 按 Kyo 令只报告不拦。**三种分档方式各算了一版，见第 6 节，不预设。**' % (stc['super']['mean'], stc['strong']['mean'], stc['weak']['mean'], stc['super']['med'], stc['strong']['med'], stc['weak']['med'], stc['weak']['over'], stc['strong']['over'], stc['super']['over']))
    w('2. **谷雨（175）按实测算出来是：%s，总分 %d**（口径 C）。输出 %s；生存排第 %d（S 的线是第 16 名）、辅助排第 %d。没硬套 Kyo 的「生存至少 S」，对不上的在第 4 节标出。她在 `skill_rework.json` 里没有重构技能条目，机制标签是按 ActorNote 手补的。' % (' '.join('%s %s' % (DN[d], g[d]) for d in DIMS), total(g), g['output'], rk('survive', '175'), rk('support', '175')))
    nmeas = sum(1 for i in ids if 'peak' in meas.get(i, {}))
    w('3. **这一版实测补强**：输出 %d/156 人有实测（上一版 136，补量 20 人里 %d 人量到，其余按同档中位数代入、表里标 ※）；生存、速度换成 `k_calibrate --stats` 的标准养成面板（%d 人有面板）加机制分，不再只靠关键词。战商、韧性仍是手标分，**可信度低，等小A 人审**；辅助仍是职责＋关键词，可信度中低。\n' % (nmeas, 20 - sum(1 for i in ids if notes.get(i, '').startswith('输出') and 'no_damage_row' in meas.get(i, {})), sum(1 for i in ids if 'stat' in meas.get(i, {}))))
    gaps = [(k, d, old_sample[k][d], let[k][d]) for k in old_sample for d in ('survive', 'speed') if abs(S[old_sample[k][d]] - S[let[k][d]]) >= 3]
    if gaps:
        w('4. **生存、速度换实测后，和设定稿样板差 3 档以上的**（口径 C，旧→新）：' + '；'.join('%s %s %s→%s' % (base[k]['name'], DN[d], a, b) for k, d, a, b in gaps) + '。生存的实测面板只算生命、防御、承伤率、闪避，**护盾类保命（如钟离的玉璋护盾）按血量比例给的盾没折算进去**，这几处如果设计上就该高，要靠机制分或手改补，请 Kyo 看。\n')
    w('## 1. 口径与名额\n')
    w('- 范围：`base_line.json` 全部 156 人（含 146 苍龙破晓、152 徐凤年等不一定会进卡池的）。档位按 `skill_rework.json` tiers：超强者 17、强者 52、其余 87 为弱者。')
    w('- 名额（口径 C，全库一把尺）：SS 前 3.2%%、S 累计 10.3%%、A 累计 25%%、B 累计 50%%、C 累计 75%%、D 累计 92.3%%、其余 E；156 人时 SS5／S11／A23／B39／C39／D27／E12；SSS 每维只看第 1 名。')
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
    w('| 生存 | **有效生命 × 机制**：`mhp × (物防＋魔防)/2 ÷ (物理承伤率＋魔法承伤率)/2 ÷ (1 − min(50%, (闪避＋魔闪)/2))`（全部取标准养成面板，承伤率＝sparam 6、7，闪避＝xparam 1、4），再 ×(100＋15×机制类别数−10×自损)/100；机制类别＝护盾·代命／减伤·免死／自回·吸血／闪避·反击四类里有几类（封顶 2），自损词 ≥2 次再 −10。 | 中：面板实测，机制类别是技能描述关键词 |')
    w('| 速度 | **敏捷 × 行动次数**：`agi × (100 ＋ 100×追加行动几率合计 ＋ 3×先制／拉条词类别数)/100`；agi 和追加行动几率（`action_plus_set` 合计，含被动、词条、模块）都取标准养成面板。 | 中高 |')
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
    w('- 生存 %s（排第 %d）：标准养成面板 生命 %d、物防 %d、魔防 %d，机制标签是手补的护盾＋自回两类（技能表里没有她的条目）。是否到 S 看「代命」算不算自保机制，**是设计判断，不是排名能算出来的**，请 Kyo 定。' % (g['survive'], rk('survive', '175'), s175['mhp'], s175['def'], s175['mdf']))
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
    w('## 6. 三种总分分档方式各算一版（只给数，不预设，请 Kyo 选）\n')
    w('- **A 各档位自己排名配名额**：超强者、强者、弱者各自内部按同一套名额（SS 3.2%／S 10.3%／A 25%……）配档；\n- **B 全库一把尺＋档位基础分**：先按 C 配档，再给超强者每维 +1 档（封到 S）、弱者每维 −1 档（封到 E）、强者不动，之后同样降档；（我把「−1／+1」理解成每一维的档位，总分约 ∓6；若 Kyo 指的是总分 ∓1，则等于 C 的分布整体平移 1，不需要另算）\n- **C 全库一把尺、不管档位**（现在写在 six_dim.json 里的）。\n')
    w('| 方式 | 档 | 份数 | 总分最小 | 中位 | 均值 | 最大 | 预算 | 超出预算 |\n|---|---|---|---|---|---|---|---|---|')
    for m in 'ABC':
        for t in ('super', 'strong', 'weak'):
            s = ts[m][t]
            lo, hi = BUDGET[t]
            w('| %s | %s | %d | %d | %s | %.1f | %d | %d～%d | %d |' % (m, CN[t], s['n'], s['min'], s['med'], s['mean'], s['max'], lo, hi, s['over']))
    w('')
    w('总分分布（份数）：\n')
    w('| 方式·档 | ' + ' | '.join(str(x) for x in range(8, 40)) + ' |\n|---|' + '---|' * 32)
    for m in 'ABC':
        for t in ('super', 'strong', 'weak'):
            h = ts[m][t]['hist']
            w('| %s·%s | ' % (m, CN[t]) + ' | '.join(str(h[x]) if h[x] else '' for x in range(8, 40)) + ' |')
    w('')
    w('读法：A 的三档均值几乎相等（名额按档内比例分，总分必然一样），档位差全靠战斗里的出伤倍率去体现；B 拉开了档位差，但超强者容易顶到 26 以上（S 档名额被抬升、R3 降档会压回一部分）；C 是现状。\n')
    w('## 7. 要 Kyo 定的事\n')
    w('1. **总分怎么分档**：A／B／C（第 6 节）。')
    w('2. **谷雨生存、辅助**怎么定：照实测，还是 Kyo 直接指定；直接指定建议加一行「手改理由」，不混进名额算法。')
    w('3. 战商、韧性手标分（小A 人审中）。')
    w('4. 东方教主输出低（第 9 节）要不要接受，还是设计上要给他补一个爆发招。')
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
    ap.add_argument('--mode', default='C', choices=list('ABC'))
    ap.add_argument('--ingest', action='store_true')
    ap.add_argument('--calib', nargs='*', default=[])
    ap.add_argument('--stats', nargs='*', default=[])
    ap.add_argument('--first', nargs='*', default=[], help='第一次量（不带 --add-rework）的日志，只用来对比')
    a = ap.parse_args()
    if a.ingest:
        ingest(a.calib, a.stats, a.first)
    base, tier, txt = role_tables()
    meas = load(MEAS)['actors']
    ids, raw, notes = raw_scores(base, tier, txt, meas)
    res = {m: assign(ids, raw, tier, m) for m in 'ABC'}
    for m in 'ABC':
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
                    ' actors 含 156 人（T280 草稿，待 Kyo 过目，当前写的是分档口径 %s）：输出＝k_calibrate 实测名次；生存＝标准养成面板有效生命×机制；速度＝敏捷×行动次数；辅助＝职责＋机制词；'
                    '战商／韧性＝手标分名次（依据原作人设，非实测，待人审）；按全库名额配档再按 R1～R3 降档。打分脚本 07_开发环境/六维打分.py，报告 07_开发环境/六维全员重算报告.md。') % a.mode
    jp.write_text(json.dumps(tab, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    REPORT.write_text(report(ids, base, tier, raw, meas, notes, res, a.mode, old, prev), encoding='utf-8')
    print('已写', jp.relative_to(REPO), '和', REPORT.relative_to(REPO))


if __name__ == '__main__':
    sys.exit(main())
