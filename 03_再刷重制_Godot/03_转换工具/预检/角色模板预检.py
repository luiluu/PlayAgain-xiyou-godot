#!/usr/bin/env python3
"""冻结 v0.28 角色依赖静态预检；不加载/执行 JS，不读玩家存档。

只写本工作树 04_验证/本地结果/ 下，源固定为冻结正式源。
index.json 可人工审阅后复制为 Git 中的源数据目录；evidence.json 是本地证据。
静态候选不是运行时可达性证明，未知脚本不自动认定为已支持。
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / '02_内容与素材/冻结正式源/app.nw'
LOCAL = ROOT / '04_验证/本地结果'


def sha(value):
    b = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    return hashlib.sha256(b).hexdigest()


def read(rel):
    return json.loads((SOURCE / rel).read_text())


def nodes(value, pointer=''):
    if isinstance(value, dict):
        yield pointer, value
        for k, v in value.items():
            yield from nodes(v, pointer + '/' + k)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from nodes(v, pointer + '/' + str(i))


def integers(value):
    # MV plugin parameters contain JSON strings with a second escaped layer.
    return [int(s) for s in re.findall(r'\d+', str(value))]


def tags(note):
    return sorted(set(re.findall(r'<([\w ]+)(?::[^<>]*)?>', note)))


SPECIAL = {
    108: ['installNanohaSharedKillRuntime', 'Bailong_NaiyeACS_FastSettlement.'],
    163: ['installQiyuDimensionRuntime', 'installImportedBalanceRuntime'],
    167: ['installNativeRavenRuntime', 'installNativeSkillProgressionRuntime', 'installRavenSkillEffectsRuntime', 'installMiraRavenNumberBoostRuntime'],
    168: ['installNativeMiraRuntime', 'installNativeSkillProgressionRuntime', 'installMiraRavenNumberBoostRuntime'],
    169: ['installNativeYomiJingliuRuntime', 'installDamageElementRuntime'],
    170: ['installNativeYomiJingliuRuntime'],
    171: ['installNativeTojiRuntime', 'installNativeBlackFlashRuntime'],
    172: ['installNativeSukunaRuntime', 'installNativeBlackFlashRuntime', 'installDamageElementRuntime'],
    173: ['installNativeGarouRuntime'],
    174: ['installNativeYunshangRuntime'],
    175: ['installNativeGuyuRuntime', 'installSourceShieldLedgerRuntime', 'installThreeGrowthRelicRuntime'],
    176: ['installNativeTusuRuntime', 'installNativeBindingChargeRuntime', 'installSourceShieldLedgerRuntime', 'installThreeGrowthRelicRuntime'],
    177: ['installNativeXuanRuntime', 'installNativeBindingChargeRuntime', 'installSourceShieldLedgerRuntime', 'installThreeGrowthRelicRuntime'],
    178: ['installImportedBalanceRuntime'],
}


def module_source(name, aid, main_text, plugin_map):
    """Curated ownership anchors; these are code locations, separate from regex candidates."""
    if name in plugin_map:
        rel = 'js/plugins/' + name + '.js'
        return {'path': rel, 'loadEvidence': 'js/plugins.js#' + name + '/status=true',
                'identityEvidence': '奈叶专属 ACS 插件；安装与钩子需运行时探针确认', 'confidence': 'enabled_plugin_source'}
    rel = 'js/codex/runtime/' + name + '.js'
    text = (SOURCE / rel).read_text()
    lines = text.splitlines()
    main_lines = [i+1 for i,l in enumerate(main_text.splitlines()) if re.search(r'^\s+' + re.escape(name) + r'\(\);|CodexRuntime\.install\([\"\']' + re.escape(name) + r'[\"\']', l)]
    anchors = {
      'installImportedBalanceRuntime': ['importedActorIds:', 'B.outgoingRate =', "wrapActionContext('apply')", "wrapActionContext('executeDamage')"],
      'installNanohaSharedKillRuntime': ['skillId=10168, actorId=108', 'BattleManager.endAction=function'],
      'installQiyuDimensionRuntime': ['actorId()===163', 'actorId() === 163', 'actorId: 163', 'actorId:163'],
      'installNativeRavenRuntime': ['R.ACTOR_ID = 167', 'Game_Actor.prototype.setup'],
      'installNativeMiraRuntime': ['168', 'Game_Actor.prototype'],
      'installNativeYomiJingliuRuntime': ['Y_ACTOR = 169, J_ACTOR = 170', 'Game_Action.prototype'],
      'installNativeTojiRuntime': ['ACTOR = 171', 'function toji(actor)'],
      'installNativeSukunaRuntime': ['172', 'Game_Action.prototype'],
      'installNativeGarouRuntime': ['"actor":173', 'a.actorId()===cfg.actor'],
      'installNativeYunshangRuntime': ['"actor":174', 'a.actorId()===C.actor'],
      'installNativeGuyuRuntime': ["tag(a, 'GuyuActor')", 'function isGuyu(b)'],
      'installNativeTusuRuntime': ["tagOf(a) === 'actor'", 'T.isTusu'],
      'installNativeXuanRuntime': ["tagOf(a) === 'actor'", 'X.isXuan'],
    }.get(name, ['CodexRuntime.register'])
    references = [{'source': rel + ':' + str(i+1), 'anchor': token} for token in anchors for i,l in enumerate(lines) if token in l and not l.lstrip().startswith(('//','/*','*'))][:12]
    assert main_lines, name
    return {'path': rel, 'loadEvidence': 'js/codex/modules.json#/modules', 'installEvidence': ['js/main.js:' + str(n) for n in main_lines],
            'ownershipAndHookEvidence': references, 'confidence': 'curated_active_code_source_not_observed_execution', 'actorId': aid}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', default=str(LOCAL / '20261018_角色模板预检'))
    parser.add_argument('--verify-index', type=pathlib.Path)
    args = parser.parse_args()
    out = pathlib.Path(args.out).resolve()
    if not out.is_relative_to(LOCAL.resolve()) or out == LOCAL.resolve():
        parser.error('--out 必须在本工作树 04_验证/本地结果/ 的子目录；不得写源与跟踪文件')
    db = {name: read('data/' + name + '.json') for name in ['Actors', 'Classes', 'Skills', 'States', 'Items', 'Weapons', 'Armors', 'CommonEvents']}
    actors = [a for a in db['Actors'] if a and a['name'].strip()]
    ids = {a['id'] for a in actors}
    assert len(actors) == len(ids) == 166
    assert ids == set(range(1, 179)) - {116, 125, 126, 132, 133, 134, 135, 136, 137, 138, 139, 140}
    plugin_text = (SOURCE / 'js/plugins.js').read_text()
    plugins = json.loads(plugin_text.split('=', 1)[1].strip().rstrip(';'))
    plugin_map = {p['name']: p for p in plugins}
    modules = read('js/codex/modules.json')['modules']
    main_text = (SOURCE / 'js/main.js').read_text()
    installed = set(re.findall(r'CodexRuntime\.install\(\s*["\']([^"\']+)', main_text))
    installed.update(re.findall(r'^\s+(install\w+)\(\);', main_text, re.M))
    # All loaded runtime files are scanned, including the one loaded but not installed in main.
    active_js = ['js/plugins/' + p['name'] + '.js' for p in plugins if p['status']] + modules + ['js/main.js', 'js/codex/RuntimeRegistry.js']
    assert all((SOURCE / f).is_file() for f in active_js)
    script_evidence = []
    literal_by_actor = collections.defaultdict(list)
    # Candidate evidence: retain generic id comparisons separately, never attribute them as proven actor-specific effects.
    patterns = [r'(?:_actorId|actorId\(\))\s*(?:===?|!==?)\s*(\d+)',
                r'\b(?:[A-Z_]*ACTOR(?:_ID)?|actorId|actor)\s*[":]*\s*[:=]\s*(\d+)']
    for rel in active_js:
        text = (SOURCE / rel).read_text(errors='replace')
        hits = []
        for lineno, line in enumerate(text.splitlines(), 1):
            if re.search(r'actorId|_actorId|ACTOR|CodexTusu|CodexXuan|GuyuActor|YunshangActor|GarouProgressionActor|CodexCat', line):
                candidates = sorted({int(v) for pat in patterns for v in re.findall(pat, line) if int(v) in ids})
                row = {'line': lineno, 'candidateActorIds': candidates, 'kind': 'comment_line_candidate' if line.lstrip().startswith(('//', '/*', '*')) else 'code_line_candidate', 'text': line}
                hits.append(row)
                for aid in candidates:
                    literal_by_actor[aid].append({'source': rel + ':' + str(lineno), 'kind': row['kind']})
        if hits:
            script_evidence.append({'path': rel, 'sha256': sha((SOURCE / rel).read_bytes()), 'hits': hits})
    advanced = collections.defaultdict(list)
    for key, val in plugin_map['Star_ActorAdvanced']['parameters'].items():
        if re.fullmatch(r'Advanced \d+', key) and val:
            row = json.loads(val)
            aid = int(row['AdvancedActId'])
            advanced[aid].append({'source': 'js/plugins.js#Star_ActorAdvanced/parameters/' + key, 'data': row})
    bonds = collections.defaultdict(list)
    for key, val in plugin_map['Star_JiBanSiklls']['parameters'].items():
        if re.fullmatch(r'JiBan \d+', key) and val:
            row = json.loads(val)
            for aid in integers(row['JiBanActId']) + integers(row.get('JiBanNeceActId', '')):
                if aid in ids:
                    bonds[aid].append({'source': 'js/plugins.js#Star_JiBanSiklls/parameters/' + key, 'data': row})
    event_refs = collections.defaultdict(list)
    event_skill = collections.defaultdict(set)
    data_files = sorted((SOURCE / 'data').glob('Map[0-9][0-9][0-9].json')) + [SOURCE / 'data/CommonEvents.json', SOURCE / 'data/Troops.json']
    for file in data_files:
        rel = str(file.relative_to(SOURCE))
        for pointer, row in nodes(json.loads(file.read_text())):
            params = row.get('parameters', [])
            code = row.get('code')
            aid = None
            if code == 129 and params:
                aid = params[0]
            elif code in {319, 320, 321, 322, 324, 325} and params:
                aid = params[0]
            elif code in {311, 312, 313, 314, 315, 316, 317, 318, 326} and len(params) > 1 and params[0] == 0:
                aid = params[1]
            if aid in ids:
                event_refs[aid].append(rel + '#' + pointer)
                if code == 318 and len(params) > 3 and params[2] == 0:
                    event_skill[aid].add(params[3])
    groups = {name: {} for name in ['curve', 'experience', 'traits', 'learning', 'appearance']}
    rows = []
    detail = []
    tree_files = set()
    for a in actors:
        aid, cid = a['id'], a['classId']
        c = db['Classes'][cid]
        assert c and len(c['params']) == 8 and all(len(v) >= 100 for v in c['params'])
        appearance = {k: a[k] for k in ['battlerName', 'characterName', 'characterIndex', 'faceName', 'faceIndex']}
        appearance['tags'] = {k: v for k, v in re.findall(r'<([^<>:]+):\s*([^<>]*)>', a['note']) if k.startswith(('sv', 'SV', 'Anchor', 'Cfdz', 'YCyy'))}
        signatures = {}
        for name, value in [('curve', c['params']), ('experience', c['expParams']), ('traits', [a['traits'], c['traits']]), ('learning', c['learnings']), ('appearance', appearance)]:
            sig = name + ':' + sha(value)[:16]
            signatures[name] = sig
            group = groups[name].setdefault(sig, {'sha256': sha(value), 'actorIds': []})
            group['actorIds'].append(aid)
            group.setdefault('representativeSource', f'data/Classes.json#/{cid}' if name in {'curve','experience','learning'} else f'data/Actors.json#/{aid} + data/Classes.json#/{cid}')
            if name == 'experience':
                group['values'] = value
        tree_rel = f'data/PKD_SimpleSkillsTree/Generated/skillTree_{cid}.json'
        tree_nodes = []
        if (SOURCE / tree_rel).is_file():
            tree_files.add(tree_rel)
            tree_nodes = [{'source': tree_rel + '#' + ptr, 'data': row} for ptr, row in nodes(read(tree_rel)) if 'skillId' in row and row.get('skillId')]
        skill_origins = collections.defaultdict(set)
        def add(sid, origin):
            if 0 < sid < len(db['Skills']) and db['Skills'][sid]:
                skill_origins[sid].add(origin)
        for sid in [1, 2]:
            add(sid, 'engineAttackGuard')
        for l in c['learnings']:
            add(l['skillId'], 'classLearning')
        initial_equips = []
        for slot, eid in enumerate(a.get('equips', [])):
            table = 'Weapons' if slot == 0 else 'Armors'
            if eid and 0 < eid < len(db[table]) and db[table][eid]:
                initial_equips.append({'slot': slot, 'source': f'data/{table}.json#/{eid}', 'data': db[table][eid]})
        for obj in [a, c] + [e['data'] for e in initial_equips]:
            for raw in re.findall(r'<(?:Attack|Guard) Skill:\s*(\d+)>', obj.get('note', ''), re.I):
                add(int(raw), 'attackGuardOverride')
            for t in obj['traits']:
                if t['code'] == 43:
                    add(t['dataId'], 'trait43')
        for item in tree_nodes:
            add(int(item['data']['skillId']), 'skillTree')
        for item in advanced[aid]:
            for n in integers(item['data']['AdvancedSkiId']):
                add(n, 'advance')
        for item in bonds[aid]:
            for n in integers(item['data']['JiBanSkiId']):
                add(n, 'bond')
        for n in event_skill[aid]:
            add(n, 'event318Literal')
        # Find skill-granting states reached from effect 21 and passive-state tags; fixed point avoids one-hop omissions.
        states = set()
        pending = list(skill_origins)
        visited = set()
        while pending:
            sid = pending.pop()
            if sid in visited:
                continue
            visited.add(sid)
            s = db['Skills'][sid]
            new_states = {e['dataId'] for e in s.get('effects', []) if e['code'] in {21, 22} and e['dataId'] > 0}
            for raw in re.findall(r'<Passive States?:\s*([^>]+)>', s.get('note', ''), re.I):
                new_states.update(integers(raw))
            for state_id in new_states - states:
                states.add(state_id)
                st = db['States'][state_id] if state_id < len(db['States']) else None
                for t in (st or {}).get('traits', []):
                    if t['code'] == 43:
                        add(t['dataId'], 'stateTrait43')
                        pending.append(t['dataId'])
        notes = [e['data'].get('note', '') for e in initial_equips] + [db['Skills'][s].get('note', '') for s in skill_origins] + [db['States'][s].get('note', '') for s in states if s < len(db['States']) and db['States'][s]]
        passive_tags = sorted({tag for note in notes for tag in tags(note) if 'passive' in tag.lower()})
        script_skills = sorted(s for s in skill_origins if re.search(r'<(?:Custom |Before Eval|After Eval|Pre-Damage Eval|Post-Damage Eval|.*Eval>)|\{|\$game|\.gain(?:Hp|Mp|Tp)|\.addState', db['Skills'][s].get('note', '') + '\n' + db['Skills'][s].get('damage', {}).get('formula', ''), re.I))
        common_events = sorted({e['dataId'] for s in skill_origins for e in db['Skills'][s].get('effects', []) if e['code'] == 44})
        modules_needed = list(SPECIAL.get(aid, []))
        if 141 <= aid <= 166:
            modules_needed.append('installImportedBalanceRuntime')
        modules_needed = sorted(set(modules_needed))
        category = 'C_independent_module' if modules_needed else 'B_data_with_pending_mechanisms'
        risks = ['static_not_runtime_verified', 'generic_actor_script_candidates_need_probe']
        if tree_nodes:
            risks.append('skill_tree_progression_not_bulk_accepted')
        if advanced[aid]:
            risks.append('advanced_progression_not_bulk_accepted')
        if bonds[aid]:
            risks.append('party_bond_and_shared_skill_lifecycle')
        if script_skills or common_events:
            risks.append('skill_scripts_or_common_events')
        if '<CodexDisabledActor>' in a['note']:
            risks.append('disabled_preserve_do_not_enable')
        if modules_needed:
            risks.append('module_runtime_state_and_save_schema')
        rows.append({'actorId': aid, 'name': a['name'], 'classId': cid, 'category': category,
                     'source': f'data/Actors.json#/{aid}', 'classSource': f'data/Classes.json#/{cid}',
                     'actorSha256': sha(a), 'classSha256': sha(c), 'templates': signatures,
                     'initialEquips': [{'slot': e['slot'], 'source': e['source']} for e in initial_equips], 'initialLevel': a['initialLevel'], 'databaseMaxLevel': a['maxLevel'],
                     'actorTags': tags(a['note']), 'classTags': tags(c['note']), 'appearance': appearance,
                     'curveSamples': {str(lv): [v[lv] for v in c['params']] for lv in [1,10,35,65,99]}, 'expParams': c['expParams'], 'classLearnings': c['learnings'], 'skillIds': sorted(skill_origins), 'stateIds': sorted(states),
                     'skillOriginCounts': dict(collections.Counter(v for vv in skill_origins.values() for v in vv)),
                     'passiveTags': passive_tags, 'scriptSkillCandidates': script_skills, 'commonEventIds': common_events,
                     'treeSource': tree_rel if tree_nodes else None, 'treeNodeCount': len(tree_nodes),
                     'advancedSources': [x['source'] for x in advanced[aid]], 'bondSources': [x['source'] for x in bonds[aid]],
                     'runtimeModuleCandidates': modules_needed, 'confirmedModuleSources': [module_source(m, aid, main_text, plugin_map) for m in modules_needed], 'literalScriptCandidates': literal_by_actor[aid],
                     'eventReferenceCount': len(event_refs[aid]), 'risks': risks})
        detail.append({'actorId': aid, 'advanced': advanced[aid], 'bonds': bonds[aid], 'treeNodes': tree_nodes,
                       'skillOrigins': {k: sorted(v) for k, v in sorted(skill_origins.items())}, 'eventReferences': event_refs[aid]})
    # Hash every scanned database/code/config input; no unrelated media or player save locations are traversed.
    input_files = {SOURCE / ('data/' + n + '.json') for n in db} | set(data_files)
    input_files |= {SOURCE / f for f in active_js + list(tree_files) + ['js/plugins.js', 'js/codex/modules.json', 'import_manifest.json']}
    input_files |= set((SOURCE / 'js/codex').glob('*.json'))
    fingerprints = {str(f.relative_to(SOURCE)): sha(f.read_bytes()) for f in sorted(input_files)}
    categories = {cat: [a['actorId'] for a in rows if a['category'] == cat] for cat in ['A_template_only', 'B_data_with_pending_mechanisms', 'C_independent_module']}
    assert set().union(*(set(v) for v in categories.values())) == ids
    assert sum(map(len, categories.values())) == 166
    index = {'schema': 1, 'source': '冻结正式源/app.nw v0.28', 'method': 'static_inventory_not_behavior_acceptance',
             'scope': {'namedActors': 166, 'databaseActors': len(db['Actors']) - 1, 'excludedBlankActorIds': sorted(set(range(1, len(db['Actors']))) - ids),
                       'disabledActorIds': [r['actorId'] for r in rows if 'disabled_preserve_do_not_enable' in r['risks']],
                       'enabledPlugins': sum(p['status'] for p in plugins), 'loadedRuntimeFiles': len(modules),
                       'mainInstalledRuntimeNames': len(installed), 'runtimeLoadedButNotMainInstalled': sorted(pathlib.Path(f).stem for f in modules if pathlib.Path(f).stem not in installed)},
             'inputSetSha256': sha(fingerprints), 'fingerprints': fingerprints, 'categories': categories,
             'templateGroups': groups, 'actors': rows,
             'limitations': ['literal actor IDs are candidates, not proven effect ownership', 'dynamic script/variable IDs require runtime probes',
                             'skillIds include static class/trait/tree/advance/bond/event/state closure; do not include arbitrary learned skills from JS or equipment',
                             'scriptSkillCandidates are conservative regex candidates; absence does not prove supported',
                             'source data values may be rewritten by main.js-installed runtime modules',
                             'no actor is declared behaviorally complete by this static inventory']}
    if args.verify_index:
        previous = json.loads(args.verify_index.read_text())
        if previous != index:
            raise SystemExit('索引与冻结源/扫描结果不同；请读差异，不自动覆盖索引')
    out.mkdir(parents=True, exist_ok=True)
    (out / 'index.json').write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
    (out / 'evidence.json').write_text(json.dumps({'scripts': script_evidence, 'actors': detail}, ensure_ascii=False, indent=2) + '\n')
    summary = {'namedActors': len(rows), 'categories': {k: len(v) for k, v in categories.items()},
               'templateGroups': {k: len(v) for k, v in groups.items()}, 'fingerprints': len(fingerprints),
               'inputSetSha256': index['inputSetSha256'], 'scope': index['scope'], 'output': str(out)}
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
