#!/usr/bin/env python3
"""内容覆盖自动检查（沙僧协助计划第 8 项，框架维护约定「守层者变体页与切片覆盖」的 coverage(map,event,page)）。

读转换产物（generated/：切片地图、数据库、素材、事件对照参照），从切片里每张地图的每个事件页、以及它们调得到的公共事件出发，
逐条指令查依赖，给每页一个结论：可运行／缺依赖（附原因）。原因分五类：
- 缺素材：页面行走图、显示文字的脸图、BGM/BGS/ME/SE、图片、动画图、战斗背景、远景、角色图像、移动路线换图与音效、
  地图本身的图块/远景/音乐、敌群成员的战斗图在 generated 里找不到；
- 无效引用：公共事件、敌群、动画、物品/武器/防具、角色在数据库里不存在（或动画是 MZ 格式，Godot 不播）；
- 未翻译：Godot 解释器（MVInterpreter._execute）没有分支的指令、_plugin_command 不认的插件指令、
  条件分支（111）里 _condition 与宿主 _condition_env 都不认的条件类型（运行时记 skipped、按假走；悟空期一的 9／10 就这样漏过）；
  只经战斗场合技能／物品效果（code 44，场合＝战斗）调到的公共事件（含它们 117 调到的）在战斗里由 XBattleEventRunner 跑，
  按共用核心＋battle_event_runner 的指令表查；地图也可达的（地图页 117、场合随时／菜单）仍按地图解释器查；
- 出切片：场所移动到切片外的地图（提示，不算失败）；
- 空页：页里没有任何指令（事件对照探针不为它出用例），无需对照（提示）；
- 未对照：页里有指令，但事件对照参照（oracle/events.json）里没有这一页（提示，不算失败）。
前三类按「类别|位置|细节」登进基线 tests/content_coverage_baseline.json：--check 时出现基线外的新问题即失败（退出码 1），
基线里已经消失的会提示可以 --update-baseline。报告写到 04_验证/本地结果/内容覆盖/报告.json。只读。
"""
import argparse
import collections
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SUB = HERE.parent
GEN = SUB / '01_Godot工程/modes/xiyou/generated'
# 地图解释器：指令语义在共用核心 MVEventCore，MVInterpreter 只接宿主指令；两份一起读
INTERP_FILES = [SUB / '01_Godot工程/modes/xiyou/core/mv_event_core.gd', SUB / '01_Godot工程/modes/xiyou/map/mv_interpreter.gd']
# 战斗事件解释器：共用核心＋XBattleEventRunner（敌人指令 331/333/334/335/336/339 等）
BATTLE_FILES = [SUB / '01_Godot工程/modes/xiyou/core/mv_event_core.gd', SUB / '01_Godot工程/modes/xiyou/battle/battle_event_runner.gd']
BASELINE = SUB / '01_Godot工程/tests/content_coverage_baseline.json'
REPORT = SUB / '04_验证/本地结果/内容覆盖/报告.json'
HARD = ('缺素材', '无效引用', '未翻译')
# 续行与结构码，不单独翻译（同 事件指令统计.py）
STRUCT = {0, 108, 401, 402, 403, 404, 408, 411, 412, 413, 505, 601, 602, 603, 604, 605, 655}
AUDIO = {132: 'bgm', 133: 'me', 139: 'me', 241: 'bgm', 245: 'bgs', 249: 'me', 250: 'se'}
GOODS = {0: 'Items', 1: 'Weapons', 2: 'Armors'}


def handled_codes(text: str) -> set:
    codes = set()
    for line in text.splitlines():
        m = re.match(r'^\t\t(\d+(?:, \d+)*):', line)
        if m:
            codes.update(int(x) for x in m.group(1).split(', '))
    return codes


def handled_plugins(text: str) -> set:
    body = text.split('func _plugin_command', 1)[1].split('\nfunc ', 1)[0] if 'func _plugin_command' in text else ''
    names = set()
    for line in body.splitlines():
        if re.match(r'^\t\t"', line):
            names.update(re.findall(r'"([^"]+)"', line.split(':', 1)[0]))
    return names


def handled_conditions(text: str) -> set:
    """条件分支 111 认得的条件类型：共用核心 _condition 顶层 match 的分支，加宿主 _condition_env 里 int(p[0]) == N 的判断。"""
    kinds = set()
    if 'func _condition(p' in text:
        body = text.split('func _condition(p', 1)[1].split('\nfunc ', 1)[0]
        for line in body.splitlines():
            m = re.match(r'^\t\t(\d+(?:, \d+)*):', line)
            if m:
                kinds.update(int(x) for x in m.group(1).split(', '))
    for part in text.split('func _condition_env(')[1:]:
        kinds.update(int(x) for x in re.findall(r'int\(p\[0\]\) == (\d+)', part.split('\nfunc ', 1)[0]))
    return kinds


def skipped_common_events(text: str) -> set:
    m = re.search(r'static var skip_common_events := \[([^\]]*)\]', text)
    return {int(x) for x in re.findall(r'\d+', m.group(1))} if m else set()


class Checker:
    def __init__(self, gen: Path, interp_text: str, battle_text: str = ''):
        self.gen = gen
        self.db = {}
        self.codes = handled_codes(interp_text)
        self.battle_codes = handled_codes(battle_text)
        self.conds = handled_conditions(interp_text)
        self.battle_conds = handled_conditions(battle_text)
        self.battle_only = set()    # 只在战斗里跑的公共事件（run 里算）
        self.plugins = handled_plugins(interp_text)
        self.skip_ce = skipped_common_events(interp_text)
        self.files = collections.defaultdict(set)   # 素材目录 → 去扩展名的文件名
        for folder in [gen / 'img', gen / 'audio']:
            for p in folder.rglob('*') if folder.is_dir() else []:
                if p.is_file() and p.suffix != '.import':
                    self.files[p.parent.relative_to(gen).as_posix()].add(p.stem)
        self.maps = {int(p.stem[3:]): p for p in (gen / 'maps').glob('Map[0-9][0-9][0-9].json')}
        self.issues = []            # (类别, 位置, 细节)
        self.pages = []             # 每页结论

    def table(self, name):
        if name not in self.db:
            p = self.gen / 'db' / (name + '.json')
            self.db[name] = json.loads(p.read_text()) if p.exists() else []
        return self.db[name]

    def rec(self, name, rid):
        t = self.table(name)
        return t[rid] if isinstance(rid, int) and 0 < rid < len(t) and t[rid] else None

    def asset(self, folder, name, where, out):
        if name and name not in self.files[folder]:
            out.append(('缺素材', where, '%s/%s' % (folder, name)))

    def check_animation(self, aid, where, out):
        a = self.rec('Animations', aid)
        if a is None:
            out.append(('无效引用', where, '动画 %s' % aid))
        elif 'frames' not in a or 'timings' not in a:
            out.append(('无效引用', where, '动画 %s 是 MZ 格式' % aid))
        else:
            for k in ['animation1Name', 'animation2Name']:
                self.asset('img/animations', a.get(k), where, out)

    def check_troop(self, tid, where, out):
        t = self.rec('Troops', tid)
        if t is None:
            out.append(('无效引用', where, '敌群 %s' % tid)); return
        for m in t.get('members', []):
            e = self.rec('Enemies', m.get('enemyId'))
            if e is None:
                out.append(('无效引用', where, '敌群 %s 的敌人 %s' % (tid, m.get('enemyId'))))
            else:
                # YEP 侧视：备注 <Sideview Battler: X> 时战斗图用 sv_actors/X，不用 battlerName（同转换器）
                side = str((e.get('meta') or {}).get('Sideview Battler') or '').strip()
                if side:
                    self.asset('img/sv_actors', side, where, out)
                else:
                    self.asset('img/sv_enemies', e.get('battlerName'), where, out)

    def route(self, cmds, where, out):
        for c in cmds or []:
            p = c.get('parameters') or []
            if c.get('code') == 41 and p:
                self.asset('img/characters', p[0], where, out)
            elif c.get('code') == 44 and p and isinstance(p[0], dict):
                self.asset('audio/se', p[0].get('name'), where, out)

    def walk(self, cmds, where, out, calls, battle=False):
        codes, conds = (self.battle_codes, self.battle_conds) if battle else (self.codes, self.conds)
        for c in cmds or []:
            code, p = c.get('code', 0), c.get('parameters') or []
            if code not in STRUCT and code not in codes:
                out.append(('未翻译', where, '指令 %d' % code))
            elif code == 111 and p and isinstance(p[0], int) and p[0] not in conds:
                out.append(('未翻译', where, '条件类型 %d' % p[0]))
            if code == 101 and p:
                self.asset('img/faces', p[0], where, out)
            elif code in AUDIO and p and isinstance(p[0], dict):
                self.asset('audio/' + AUDIO[code], p[0].get('name'), where, out)
            elif code == 231 and len(p) > 1:
                self.asset('img/pictures', p[1], where, out)
            elif code == 212 and len(p) > 1:
                self.check_animation(p[1], where, out)
            elif code == 283 and len(p) > 1:
                self.asset('img/battlebacks1', p[0], where, out); self.asset('img/battlebacks2', p[1], where, out)
            elif code == 284 and p:
                self.asset('img/parallaxes', p[0], where, out)
            elif code == 322 and len(p) > 5:
                self.asset('img/characters', p[1], where, out); self.asset('img/faces', p[3], where, out)
                self.asset('img/sv_actors', p[5], where, out)
            elif code in (205, 505) and len(p) > 1 and isinstance(p[1], dict):
                self.route(p[1].get('list'), where, out)
            elif code == 117 and p:
                ce = p[0]
                if ce in self.skip_ce:
                    continue
                if self.rec('CommonEvents', ce) is None:
                    out.append(('无效引用', where, '公共事件 %s' % ce))
                else:
                    calls.add(ce)
            elif code == 301 and len(p) > 1 and p[0] == 0:
                self.check_troop(p[1], where, out)
            elif code in (302, 605) and len(p) > 1 and p[0] in GOODS:
                if self.rec(GOODS[p[0]], p[1]) is None:
                    out.append(('无效引用', where, '%s %s' % (GOODS[p[0]], p[1])))
            elif code in (126, 127, 128) and p:
                name = {126: 'Items', 127: 'Weapons', 128: 'Armors'}[code]
                if self.rec(name, p[0]) is None:
                    out.append(('无效引用', where, '%s %s' % (name, p[0])))
            elif code == 129 and p and self.rec('Actors', p[0]) is None:
                out.append(('无效引用', where, '角色 %s' % p[0]))
            elif code == 201 and len(p) > 1 and p[0] == 0 and p[1] not in self.maps:
                out.append(('出切片', where, '传送到 Map%03d' % p[1]))
            elif code == 356 and p:
                head = str(p[0]).split(' ')[0]
                if head not in self.plugins:
                    out.append(('未翻译', where, '插件指令 %s' % head))

    def calls_of(self, cmds) -> set:
        return {c['parameters'][0] for c in cmds or [] if c.get('code') == 117 and c.get('parameters')
                and c['parameters'][0] not in self.skip_ce and self.rec('CommonEvents', c['parameters'][0]) is not None}

    def closure(self, start) -> set:
        seen, queue = set(start), list(start)
        while queue:
            for ce in self.calls_of(self.rec('CommonEvents', queue.pop()).get('list')) - seen:
                seen.add(ce); queue.append(ce)
        return seen

    def contexts(self, effect_ces) -> set:
        """只在战斗里跑的公共事件：从 code 44 起点里场合＝战斗（1）的出发可达，且从地图页、场合随时／菜单／不能用的起点都不可达。"""
        occasions = collections.defaultdict(set)
        for name in ('Skills', 'Items'):
            for row in self.table(name):
                for eff in (row or {}).get('effects') or []:
                    if eff.get('code') == 44:
                        occasions[eff.get('dataId')].add(row.get('occasion', 0))
        map_start = set()
        for path in self.maps.values():
            for e in json.loads(path.read_text()).get('events', []):
                for page in (e or {}).get('pages', []):
                    map_start |= self.calls_of(page.get('list'))
        ok = {ce for ce in effect_ces if self.rec('CommonEvents', ce) is not None}
        battle = self.closure({ce for ce in ok if occasions.get(ce) == {1}})
        return battle - self.closure(map_start | {ce for ce in ok if occasions.get(ce) != {1}})

    def run(self, compared: set):
        ce_seen, ce_queue = set(), []
        mf = self.gen / 'manifest.json'
        effect_ces = json.loads(mf.read_text()).get('slice', {}).get('commonEvents', []) if mf.exists() else []
        self.battle_only = self.contexts(effect_ces) if self.battle_codes else set()
        for mid, path in sorted(self.maps.items()):
            m = json.loads(path.read_text())
            where = 'Map%03d' % mid
            out = []
            ts = self.rec('Tilesets', m.get('tilesetId'))
            for n in (ts or {}).get('tilesetNames', []):
                self.asset('img/tilesets', n, where, out)
            self.asset('img/parallaxes', m.get('parallaxName'), where, out)
            for k, folder in [('battleback1Name', 'img/battlebacks1'), ('battleback2Name', 'img/battlebacks2')]:
                self.asset(folder, m.get(k), where, out)
            for k, folder in [('bgm', 'audio/bgm'), ('bgs', 'audio/bgs')]:
                if m.get('autoplay' + k.title()) and isinstance(m.get(k), dict):
                    self.asset(folder, m[k].get('name'), where, out)
            for enc in m.get('encounterList', []):
                self.check_troop(enc.get('troopId'), where, out)
            self.issues += out
            for e in m.get('events', []):
                if not e:
                    continue
                for i, page in enumerate(e.get('pages', [])):
                    w = '%s/EV%03d/p%d' % (where, e['id'], i + 1)
                    out, calls = [], set()
                    self.asset('img/characters', (page.get('image') or {}).get('characterName'), w, out)
                    self.route((page.get('moveRoute') or {}).get('list'), w, out)
                    self.walk(page.get('list'), w, out, calls)
                    self.finish_page(w, out, calls, compared, 'm%de%dp%d' % (mid, e['id'], i), ce_seen, ce_queue, page.get('list'))
        # 只经物品／技能效果（code 44）调用的公共事件（slice.extraCommonEvents）也当起点，否则它们的素材与指令永远查不到
        for ce in effect_ces:
            if ce not in ce_seen:
                ce_seen.add(ce)
                ce_queue.append(ce)
        while ce_queue:
            ce = ce_queue.pop()
            w = 'CE%04d' % ce
            out, calls = [], set()
            self.walk(self.rec('CommonEvents', ce).get('list'), w, out, calls, ce in self.battle_only)
            self.finish_page(w, out, calls, compared, 'ce%d' % ce, ce_seen, ce_queue, self.rec('CommonEvents', ce).get('list'))

    def finish_page(self, where, out, calls, compared, case_id, ce_seen, ce_queue, cmds=None):
        if case_id not in compared:
            # 没有任何指令的空页，事件对照探针本来就不出用例，算「空页」而不是未对照
            if all(int(c.get('code', 0)) == 0 for c in (cmds or [])):
                out.append(('空页', where, '页里没有指令，无需对照'))
            else:
                out.append(('未对照', where, '事件对照里没有这一页'))
        for ce in sorted(calls - ce_seen):
            ce_seen.add(ce); ce_queue.append(ce)
        self.issues += out
        hard = sorted({'%s：%s' % (k, d) for k, _, d in out if k in HARD})
        self.pages.append({'page': where, 'status': '缺依赖' if hard else '可运行', 'reasons': hard,
                           'notes': sorted({'%s：%s' % (k, d) for k, _, d in out if k not in HARD})})


def keys(issues):
    return sorted({'%s|%s|%s' % i for i in issues if i[0] in HARD})


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--generated', type=Path, default=GEN)
    ap.add_argument('--check', action='store_true', help='与基线比较，有新问题时退出码 1')
    ap.add_argument('--update-baseline', action='store_true')
    a = ap.parse_args(argv)
    gen = a.generated
    ck = Checker(gen, '\n'.join(p.read_text() for p in INTERP_FILES), '\n'.join(p.read_text() for p in BATTLE_FILES))
    events = gen / 'oracle/events.json'
    compared = {c['id'] for c in json.loads(events.read_text()).get('cases', [])} if events.exists() else set()
    ck.run(compared)
    found = keys(ck.issues)
    counts = collections.Counter(k for k, _, _ in ck.issues)
    summary = {'pages': len(ck.pages), 'runnable': sum(p['status'] == '可运行' for p in ck.pages),
               'counts': dict(counts), 'hard': len(found), 'battleOnlyCommonEvents': len(ck.battle_only)}
    try:
        REPORT.parent.mkdir(parents=True, exist_ok=True)
        REPORT.write_text(json.dumps({'summary': summary, 'pages': ck.pages, 'issues': found}, ensure_ascii=False, indent=1))
    except OSError:
        pass
    if a.update_baseline:
        BASELINE.write_text(json.dumps({'说明': '内容覆盖检查的已知问题（缺素材／无效引用／未翻译）。修好一项就 --update-baseline；'
                                         '新问题不进基线就会让检查失败。', 'issues': found}, ensure_ascii=False, indent=1) + '\n')
        print(json.dumps(summary, ensure_ascii=False))
        return 0
    base = set(json.loads(BASELINE.read_text())['issues']) if BASELINE.exists() else set()
    new, gone = [k for k in found if k not in base], sorted(base - set(found))
    summary.update(new=len(new), resolved=len(gone))
    print(json.dumps(summary, ensure_ascii=False))
    for k in new[:20]:
        print('  新问题 ' + k)
    if gone:
        print('  基线里有 %d 项已不再出现，可运行 --update-baseline' % len(gone))
    return 1 if (a.check and new) else 0


if __name__ == '__main__':
    sys.exit(main())
