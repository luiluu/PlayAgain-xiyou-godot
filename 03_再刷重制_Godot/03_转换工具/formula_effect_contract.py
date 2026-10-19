"""Ordered resource oracle completeness only; never substitutes for Godot comparison."""
import json
import re
from common_oracle_contract import case_map, identity_issues

CASE_IDS = frozenset(
    {f'eval.{skill}.{pair}.{hp}_{mp}_{tp}.{str(immortal).lower()}'
     for skill in (857, 858, 4013) for pair in ('actors', 'enemy_actor', 'actor_enemy', 'self')
     for hp, mp, tp in ((10000, 220, 123), (450, 1, 1), (3000, 0, 0), (3001, 201, 200))
     for immortal in (False, True)}
    | {'boundary.' + key for key in ('deathResist', 'permanent', 'capState_buffs', 'removedDeath', 'alreadyDead')}
    | {f'{mode}.{hp}_{mp}_{tp}' for mode in ('apply', 'miss', 'evade') for hp, mp, tp in ((10000, 220, 123), (450, 1, 1))}
    | {'language.' + key for key in ('zero', 'lazy', 'after_write_error', 'before_write_error', 'repeated')})
SLOTS = {'hpAffected', 'hpDamage', 'mpDamage', 'tpDamage', 'success', 'missed', 'evaded', 'critical', 'addedStates', 'removedStates'}
SNAPSHOT = {'resources', 'caps', 'states', 'stateTurns', 'buffs', 'buffTurns', 'alive', 'dead', 'immortal', 'result'}


def valid_snapshot(row):
    return (isinstance(row, dict) and set(row) == SNAPSHOT
            and all(isinstance(row[k], list) and len(row[k]) == n
                    for k, n in [('resources', 3), ('caps', 3), ('buffs', 8), ('buffTurns', 8)])
            and all(type(x) in (int, float) for key in ('resources', 'caps') for x in row[key])
            and isinstance(row['states'], list) and isinstance(row['stateTurns'], dict)
            and all(type(row[k]) is bool for k in ('alive', 'dead', 'immortal'))
            and isinstance(row['result'], dict) and set(row['result']) == SLOTS
            and all(type(row['result'][k]) is bool for k in ('hpAffected', 'success', 'missed', 'evaded', 'critical'))
            and all(type(row['result'][k]) in (int, float) for k in ('hpDamage', 'mpDamage', 'tpDamage')))


def validate_formula_effects(data, manifest):
    name, issues = 'formula_effects.json', []
    try:
        rows = case_map(data)
        if rows.keys() != CASE_IDS:
            issues.append(name + ' 固定112例集合不完整或出现未登记用例')
        if data.get('schemaVersion') != 1 or data.get('hostScope') != 'ordered-resource-reference-only':
            issues.append(name + ' 缺少明确的参照专用范围或结构版本')
        for key, row in rows.items():
            if (not isinstance(row.get('journal'), list) or not isinstance(row.get('popup'), list)
                    or not isinstance(row.get('diagnostics'), list)
                    or type(row.get('randomDraws')) is not int or row['randomDraws'] < 0
                    or not isinstance(row.get('formulaSHA256'), str) or not re.fullmatch('[0-9a-f]{64}', row['formulaSHA256'])):
                raise ValueError(key + ' 缺少逐句/弹字/异常/随机/来源记录')
            for phase in ('before', 'after'):
                if set(row[phase]) != {'a', 'b'} or not all(valid_snapshot(x) for x in row[phase].values()):
                    raise ValueError(key + ' 缺少双方完整快照')
            for entry in row['journal']:
                if (entry.get('receiver') not in ('a', 'b') or entry.get('resource') not in ('hp', 'mp', 'tp')
                        or not valid_snapshot(entry.get('before')) or not valid_snapshot(entry.get('after'))
                        or type(entry.get('requestedDelta')) not in (int, float)
                        or type(entry.get('actualDelta')) not in (int, float)):
                    raise ValueError(key + ' 逐句资源记录不完整')
            if key.startswith('eval.') and [x['resource'] for x in row['journal']] != ['hp', 'mp', 'tp']:
                raise ValueError(key + ' 未完整采样三个有序gain调用')
            if key.startswith(('miss.', 'evade.')) and row['journal']:
                raise ValueError(key + ' 未命中却运行了资源写入')
            if key.startswith('apply.') and len(row['journal']) < 4:
                raise ValueError(key + ' 缺少公式及最终普通伤害调用')
            expected_error = key in ('language.before_write_error', 'language.after_write_error')
            if bool(row['diagnostics']) != expected_error or (expected_error and row['diagnostics'] != [{'label': 'DAMAGE FORMULA ERROR', 'message': 'formula-read-fixture'}]):
                raise ValueError(key + ' 意外公式异常或预期异常未捕获')
        issues.extend(identity_issues(name, data.get('sourceIdentity'), manifest))
    except (KeyError, TypeError, ValueError, AttributeError) as error:
        issues.append(name + ' 参照结构异常：' + str(error))
    return issues


def verify_formula_effects(directory, manifest):
    try:
        return validate_formula_effects(json.loads((directory / 'formula_effects.json').read_text()), manifest)
    except (OSError, ValueError) as error:
        return ['formula_effects.json 缺少或不可读：' + str(error)]


def verify_formula_equipment(directory, manifest):
    name = 'formula_equipment.json'
    path = directory / name
    if not path.is_file():
        return ['装备等级公式参照缺失']
    try:
        data = json.loads(path.read_text())
        rows = case_map(data)
        ids = {int(c['setup']['skill']) for c in data['cases']}
        expected = {f's{sid}.{mode}.{str(edge).lower()}' for sid in ids
                    for mode in ('none', 'wrong_kind', 'zero', 'high', 'first', 'different_base', 'nonmagic') for edge in (False, True)}
        issues = identity_issues(name, data.get('sourceIdentity'), manifest)
        if len(ids) != 24 or set(rows) != expected:
            issues.append('装备等级公式须覆盖24块×14种边界')
        for key, row in rows.items():
            if not {'value', 'valueKind', 'firstLevel', 'randomDraws', 'formulaSHA256'} <= set(row):
                issues.append('装备等级公式参照失败或缺字段：' + key)
        return issues
    except (ValueError, KeyError, TypeError):
        return ['装备等级公式参照结构无效']


def verify_formula_actions(directory, manifest):
    name = 'formula_actions.json'
    try:
        data = json.loads((directory / name).read_text())
        rows = case_map(data)
        expected = {f'{mode}.{values}' for mode in ('repeat', 'reflect', 'counter') for values in ('10000_220_123', '450_1_1')}
        issues = identity_issues(name, data.get('sourceIdentity'), manifest)
        if set(rows) != expected or any(not valid_snapshot(c.get('after', {}).get('b')) for c in rows.values()):
            issues.append('公式反应链参照缺失或失败')
        return issues
    except (OSError, ValueError, KeyError, TypeError):
        return ['公式反应链参照结构无效']
