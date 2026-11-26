# T527 返修：读自己生命的招名单（合并 tune 六层后扫，见 改写表合并.py），输出 markdown 到标准输出。
# 一、改写表 damage.stats 带 mhp≠0；二、改写表 shield（施放者生命上限×pct）；三、没改写伤害的招看原版 Skills.json 公式 a.mhp|a.hp；
# 四、伤害条件按自己生命比例（self_hp_lost／self_hp_below／self_hp_above／self_shield）；目标生命类条件另列。
# 代码模块入口（谷雨、甚尔被动、镜流剑势等）不在表里，人工核过写在 读生命名单.md 第一节第 5 小节，本脚本不出。
import json, os, re, sys, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('rwm', os.path.join(HERE, '改写表合并.py')); rwm = importlib.util.module_from_spec(spec); spec.loader.exec_module(rwm)
RAW = json.load(open(os.path.join(rwm.DB, 'tianqi_data/skill_rework.json')))['skills']
D = rwm.merged(); RW = D['skills']; TOUCH = D['_touched']
SK = {x['id']: x for x in json.load(open(os.path.join(rwm.DB, 'generated/db/Skills.json'))) if x}
BASE = {95,107,108,122,152,163,167,168,169,171,172,173,175,176,177,179,180,1,2,22,3,12,18}  # T501／T527 23 人基准队

def rows():
    a1, a2, a3, a4, a5, gone = [], [], [], [], [], []
    for k, s in RW.items():
        if not isinstance(s, dict) or not str(k).isdigit():
            continue
        sid = int(k); act = s.get('actor'); tag = '★' if act in BASE else ''
        src = '＋'.join(TOUCH.get(k, [])) or '裸表'
        mhp = float(s.get('damage', {}).get('stats', {}).get('mhp', 0) or 0)
        raw_mhp = float(RAW.get(k, {}).get('damage', {}).get('stats', {}).get('mhp', 0) or 0) if isinstance(RAW.get(k), dict) else 0
        if mhp:
            a1.append((act, sid, tag, s.get('name'), s.get('kind'), f"mhp×{mhp:g}", src, '新增（裸表没有）' if not raw_mhp else ('改过' if raw_mhp != mhp else '')))
        elif raw_mhp:
            gone.append((act, sid, s.get('name'), f"裸表 mhp×{raw_mhp:g} → tune 清零", src))
        if s.get('shield'):
            a2.append((act, sid, tag, s.get('name'), s.get('kind'), f"护盾 施放者生命上限×{s['shield'].get('pct')}", src))
        if 'damage' not in s and 'heal' not in s:
            f = str(SK.get(sid, {}).get('damage', {}).get('formula', ''))
            if re.search(r'\ba\.(mhp|hp)\b', f) and (SK.get(sid, {}).get('damage', {}).get('type') in (1, 5) or 'addShield' in f):
                a3.append((act, sid, tag, s.get('name'), s.get('kind'), '原版公式 `' + f[:60].replace('|', '｜') + '`', src))
        for c in s.get('damage', {}).get('conds', []):
            t = c.get('if')
            if t in ('self_hp_lost', 'self_hp_below', 'self_hp_above', 'self_shield'):
                a4.append((act, sid, tag, s.get('name'), s.get('kind'), json.dumps(c, ensure_ascii=False), src))
            if t in ('target_hp_lost', 'target_hp_below', 'target_hp_above', 'target_hp_rate', 'target_full_hp'):
                a5.append((act, sid, tag, s.get('name'), s.get('kind'), json.dumps(c, ensure_ascii=False), src))
    key = lambda r: (r[0] or 0, r[1])
    return [sorted(x, key=key) for x in (a1, a2, a3, a4, a5, gone)]

def table(head, rs):
    print('| ' + ' | '.join(head) + ' |'); print('|' + '---|' * len(head))
    for r in rs:
        print('| ' + ' | '.join('' if v is None else str(v) for v in (r[1], f"{r[0]}{r[2]}") + tuple(r[3:])) + ' |')
    print()

if __name__ == '__main__':
    a1, a2, a3, a4, a5, gone = rows()
    H = ['技能', '角色（★基准队）', '名字', '类', '读法', '经过的 tune 层']
    print(f'### 1. 伤害 stats 带自己生命上限（{len(a1)} 招）\n'); table(H + ['对裸表'], a1)
    print(f'### 1 附. 裸表有 mhp、合 tune 后清零（{len(gone)} 招，不再读生命）\n')
    print('| 技能 | 角色 | 名字 | 变化 | 经过的 tune 层 |\n|---|---|---|---|---|')
    for r in gone: print(f'| {r[1]} | {r[0]} | {r[2]} | {r[3]} | {r[4]} |')
    print(f'\n### 2. 改写表护盾按施放者生命上限（{len(a2)} 招）\n'); table(H, a2)
    print(f'### 3. 没改写伤害、原版公式读自己生命（{len(a3)} 招）\n'); table(H, a3)
    print(f'### 4. 伤害条件按自己生命比例或护盾（{len(a4)} 招；倍率随血量／盾量变，不随生命上限放大）\n'); table(H, a4)
    print(f'### 附：目标生命类条件（{len(a5)} 招，读目标生命的改写表那一半，第二节是原版公式那一半）\n'); table(H, a5)
