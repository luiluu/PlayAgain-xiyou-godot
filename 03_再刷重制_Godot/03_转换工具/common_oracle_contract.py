"""共性系统参照的完整性与候选实现对照；不把参照自检冒充Godot功能验收。"""
import json
import math
from pathlib import Path

STOCK_IDS = {'stock.' + s for s in ['purchase-reopen-sell', 'group-scope', 'cancel-preview',
    'affordability', 'memory-roundtrip', 'restock-reset', 'clamp-and-type', 'time-restock',
    'no-restock', 'supply-speed-command', 'currency-and-stock.77', 'currency-and-stock.150',
    'pending-overwrite', 'timer-memory-roundtrip', 'currency-short.77', 'currency-short.150',
    'gear-buy-sell', 'floor-shop.1912', 'floor-shop.1916']}
VARIANTS = ['above-threshold', 'exact-threshold', 'below-threshold', 'variable-off', 'late-variable']
MESSAGE_IDS = {f'message.{tid}.{v}' for tid in [456, 457, 458] for v in VARIANTS} | {'message.contract-nested-common'}
CHALLENGE_IDS = {f'challenge.f{f}.d{d}' for f in [6, 11, 16, 21, 26] for d in [3, 4, 5, 6]} | {
    'challenge.cancel', 'challenge.progression.d4', 'challenge.progression.d5', 'challenge.progression.d6'}
FILES = {'shop_stock.json': STOCK_IDS, 'battle_messages.json': MESSAGE_IDS, 'challenge_passives.json': CHALLENGE_IDS}


def finite(value):
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, dict):
        return all(finite(v) for v in value.values())
    return not isinstance(value, list) or all(finite(v) for v in value)


def case_map(data):
    if not isinstance(data, dict):
        raise ValueError('参照根节点须为对象')
    rows = data.get('cases')
    if not isinstance(rows, list) or not rows:
        raise ValueError('缺少非空cases')
    out = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get('id'), str) or not row['id']:
            raise ValueError('用例缺少稳定id')
        if row['id'] in out:
            raise ValueError('重复用例id：' + row['id'])
        if row.get('errors') or row.get('error') or not isinstance(row.get('observed'), dict) or not finite(row):
            raise ValueError('用例报错、缺测量或含非有限数：' + row['id'])
        out[row['id']] = row['observed']
    return out


def compare_value(expected, actual, path='', differences=None):
    differences = [] if differences is None else differences
    if len(differences) >= 30:
        return differences
    if isinstance(expected, bool) or isinstance(actual, bool):
        equal = type(expected) is type(actual) and expected == actual
    elif isinstance(expected, (int, float)) and isinstance(actual, (int, float)):
        equal = math.isfinite(actual) and abs(expected - actual) <= 0.000001
    elif type(expected) is not type(actual):
        equal = False
    elif isinstance(expected, dict):
        if expected.keys() != actual.keys():
            differences.append(path + ' 字段集合不同')
        for key in expected.keys() & actual.keys():
            compare_value(expected[key], actual[key], path + '/' + key, differences)
        return differences
    elif isinstance(expected, list):
        if len(expected) != len(actual):
            differences.append(path + ' 数组长度不同')
        for i, (a, b) in enumerate(zip(expected, actual)):
            compare_value(a, b, f'{path}/{i}', differences)
        return differences
    else:
        equal = expected == actual
    if not equal:
        differences.append(f'{path} 预期={expected!r} 实际={actual!r}')
    return differences


def compare_reports(reference, actual, prefixes=()):
    expected, candidate = case_map(reference), case_map(actual)
    if prefixes:
        expected = {k: v for k, v in expected.items() if any(k.startswith(p) for p in prefixes)}
        candidate = {k: v for k, v in candidate.items() if any(k.startswith(p) for p in prefixes)}
    if not expected:
        raise ValueError('没有匹配的参照用例')
    problems = []
    if expected.keys() != candidate.keys():
        problems.append('用例集合不同：缺少=' + ','.join(sorted(expected.keys() - candidate.keys()))
                        + '；多出=' + ','.join(sorted(candidate.keys() - expected.keys())))
    for key in sorted(expected.keys() & candidate.keys()):
        compare_value(expected[key], candidate[key], key, problems)
    return {'expectedCases': len(expected), 'actualCases': len(candidate), 'partial': bool(prefixes),
            'passed': not problems, 'differences': problems}


def identity_issues(name, identity, manifest):
    if not isinstance(identity, dict):
        return [name + ' 参照来源结构异常']
    issues = []
    if identity.get('releaseVersion') != manifest['releaseVersion'] or identity.get('runtimeInputs') != manifest['runtimeInputs']:
        issues.append(name + ' 参照版本/脚本不同源')
    for rel, digest in manifest['inputs'].items():
        if (rel.startswith('data/') or rel == 'package.json') and identity.get('inputs', {}).get(rel) != digest:
            issues.append(name + ' 参照数据不同源：' + rel)
    return issues


def validate_payload(name, data, manifest):
    issues = []
    try:
        rows = case_map(data)
        if rows.keys() != FILES[name]:
            issues.append(name + ' 用例集合不完整或出现未经登记的新用例')
        if type(data.get('schemaVersion')) is not int or data['schemaVersion'] != 1 or not data.get('hostScope'):
            issues.append(name + ' 缺少版本或宿主范围说明')
        if any(row.get('errors') != [] for row in data['cases']):
            issues.append(name + ' 参照缺少明确的零错误记录')
        issues.extend(identity_issues(name, data.get('sourceIdentity', {}), manifest))
        if name == 'shop_stock.json':
            r = rows['stock.purchase-reopen-sell']
            if [x['stock'] for x in r['trace']] != [5, 3, 3, 0, 1] or r['trace'][3]['enabled']:
                issues.append('限购购买/重开/售完/卖回链不完整')
            if rows['stock.cancel-preview']['before'] != rows['stock.cancel-preview']['after']:
                issues.append('限购取消预览意外消费')
            if not rows['stock.memory-roundtrip']['prototypeRestored']:
                issues.append('限购JsonEx恢复未保留原型')
            if [x['stock'] for x in rows['stock.time-restock']['trace']] != [0, 1, 3, 5]:
                issues.append('定时补货边界缺失')
            for item in [77, 150]:
                row = rows[f'stock.currency-short.{item}']
                if row['before']['enabled'] or row['before'] != row['after']:
                    issues.append(f'限购物品{item}多货币不足异常')
            g = rows['stock.gear-buy-sell']
            if g['after']['stock'] != 0 or not g['instanceSold'] or g['baseAfterSell'] != 0:
                issues.append('限购独立装备买卖链不完整')
            for item in [1912, 1916]:
                if [x['stock'] for x in rows[f'stock.floor-shop.{item}']['trace']] != [5, 3, 3, 0, 0, 5]:
                    issues.append(f'限购索礼商店{item}链不完整')
        elif name == 'battle_messages.json':
            for tid in [456, 457, 458]:
                for variant in VARIANTS:
                    r = rows[f'message.{tid}.{variant}']
                    active = variant in ['exact-threshold', 'below-threshold']
                    if active:
                        if (not r['displayed'] or not r['waiting']['busy'] or not r['waiting']['indexStable']
                                or r['waiting']['forcedCount'] != 0 or not r['waiting']['hpStable']
                                or [x['skill'] for x in r['after']['forced']] != [6070, 6105, 3558 + tid - 456, 8111]
                                or r['repeated']['forcedCount'] != 4):
                            issues.append(f'{tid} 对话等待/恢复/只执行一次链异常')
                    elif r['displayed'] or r['after']['forced'] or r['repeated']['messageBusy']:
                        issues.append(f'{tid}/{variant} 条件或span异常')
                    if not r['after']['finished'] or not r['repeated']['finished']:
                        issues.append(f'{tid}/{variant} 未结束')
            nested = rows['message.contract-nested-common']
            if nested['before']['variable'] != 1 or nested['held'] != 1 or nested['after'] != 111 or not nested['finished']:
                issues.append('嵌套公共事件的挂起恢复异常')
        elif name == 'challenge_passives.json':
            caps = {3: [10] * 5, 4: [11, 14, 17, 20, 23], 5: [12, 16, 20, 24, 28], 6: [13, 18, 23, 28, 33]}
            first_skill = {4: 2873, 5: 2879, 6: 2892}
            for d in [3, 4, 5, 6]:
                for rank, floor in enumerate([6, 11, 16, 21, 26]):
                    r = rows[f'challenge.f{floor}.d{d}']
                    if (r['skillCap'] != caps[d][rank] or r['repeatSkillCap'] != r['skillCap']
                            or r['after'] != r['repeated'] or r['after'] != r['restored']
                            or len(r['after']) != 6 or r['battleMembers'] != [1, 8, 9, 10, 11]):
                        issues.append(f'{floor}/{d} 挑战被动/重复进入/内存恢复/后备覆盖异常')
                    for a in r['after']:
                        wanted = [] if d == 3 else [first_skill[d] + rank]
                        if a['skills'] != wanted:
                            issues.append(f'{floor}/{d}/{a["id"]} 学技结果异常')
            if rows['challenge.cancel']['skillCap'] != 10 or any(a['skills'] for a in rows['challenge.cancel']['actors']):
                issues.append('挑战门取消分支异常')
            for d in [4, 5, 6]:
                trace = rows[f'challenge.progression.d{d}']['trace']
                if len(trace) != 5 or [r['skillCap'] for r in trace] != caps[d] or any(
                        r['actor']['skills'] != list(range(first_skill[d], first_skill[d] + i + 1)) for i, r in enumerate(trace)):
                    issues.append(f'{d} 连续进层的累计挑战被动异常')
    except (KeyError, TypeError, ValueError, IndexError) as error:
        issues.append(name + ' 参照结构异常：' + str(error))
    return issues


def verify_reports(directory: Path, manifest):
    issues = []
    for name in FILES:
        try:
            issues.extend(validate_payload(name, json.loads((directory / name).read_text()), manifest))
        except (OSError, ValueError, TypeError) as error:
            issues.append(name + ' 缺少或不可读：' + str(error))
    return issues
