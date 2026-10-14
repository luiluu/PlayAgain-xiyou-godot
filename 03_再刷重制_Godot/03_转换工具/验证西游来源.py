#!/usr/bin/env python3
"""只读核对当前正式来源、转换产物与三难度 oracle；不读取任何存档。"""
import argparse
import hashlib
import json
from pathlib import Path
from xiyou_export import DEFAULT_APP, DEFAULT_OUT


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(app, generated, oracle):
    manifest = json.loads((generated / 'manifest.json').read_text())
    issues = []
    if Path(manifest['source']).resolve() != app.resolve():
        issues.append('正式来源路径不一致')
    for field in ['inputs', 'runtimeInputs', 'outputs']:
        rows = manifest.get(field, {})
        if not rows:
            issues.append(field + ' 缺少指纹')
        base = generated if field == 'outputs' else app
        for rel, digest in rows.items():
            file = (base / rel).resolve()
            if not file.is_relative_to(base.resolve()) or not file.is_file() or sha(file) != digest:
                issues.append(field + ' 指纹不符：' + rel)
    version = json.loads((app / 'package.json').read_text()).get('releaseVersion')
    if version != manifest['releaseVersion']:
        issues.append('实际来源版本不一致')
    for difficulty in [1, 2, 3, 4, 5, 6]:
        file = oracle / f'slice_d{difficulty}.json'
        if not file.is_file():
            issues.append(f'缺少难度 {difficulty} 对照')
            continue
        data = json.loads(file.read_text())
        identity = data.get('sourceIdentity', {})
        if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
            issues.append(f'难度 {difficulty} 参照版本/脚本不一致')
        for rel, digest in manifest['inputs'].items():
            if rel.startswith('data/') or rel == 'package.json':
                if identity.get('inputs', {}).get(rel) != digest:
                    issues.append(f'难度 {difficulty} 参照数据不一致：{rel}')
        if data.get('difficulty') != difficulty or any(row.get('error') for row in data.get('damage', [])):
            issues.append(f'难度 {difficulty} 测量异常')
    equipment = oracle / 'equipment.json'
    if manifest.get('toolVersion', 0) >= 5:
        if not equipment.is_file():
            issues.append('缺少装备对照')
        else:
            data = json.loads(equipment.read_text())
            identity = data.get('sourceIdentity', {})
            if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
                issues.append('装备参照版本/脚本不一致')
            for rel, digest in manifest['inputs'].items():
                if rel.startswith('data/') or rel == 'package.json':
                    if identity.get('inputs', {}).get(rel) != digest:
                        issues.append('装备参照数据不一致：' + rel)
            if not data.get('gear') or not data.get('upgrades') or not data.get('sets'):
                issues.append('装备参照缺少测量结果')
    map_identity_file = oracle / 'maps_source.json'
    if not map_identity_file.is_file():
        issues.append('地图参照缺少来源指纹（重新运行 map_probe）')
    else:
        identity = json.loads(map_identity_file.read_text())
        if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
            issues.append('地图参照版本/脚本不一致')
        for rel, digest in manifest['inputs'].items():
            if rel.startswith('data/') or rel == 'package.json':
                if identity.get('inputs', {}).get(rel) != digest:
                    issues.append('地图参照数据不一致：' + rel)
    help_file = oracle / 'help_cards.json'
    if not help_file.is_file():
        issues.append('说明卡参照缺失（重新运行 help_probe）')
    else:
        identity = json.loads(help_file.read_text()).get('sourceIdentity', {})
        if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
            issues.append('说明卡参照版本/脚本不一致')
        for rel, digest in manifest['inputs'].items():
            if rel.startswith('data/') or rel == 'package.json':
                if identity.get('inputs', {}).get(rel) != digest:
                    issues.append('说明卡参照数据不一致：' + rel)
    hang_up = oracle / 'hang_up.json'
    if manifest.get('toolVersion', 0) >= 8:
        if not hang_up.is_file():
            issues.append('挂机/星级参照缺失（重新运行 hang_up_probe）')
        else:
            data = json.loads(hang_up.read_text())
            identity = data.get('sourceIdentity', {})
            if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
                issues.append('挂机/星级参照版本/脚本不一致')
            for rel, digest in manifest['inputs'].items():
                if rel.startswith('data/') or rel == 'package.json':
                    if identity.get('inputs', {}).get(rel) != digest:
                        issues.append('挂机/星级参照数据不一致：' + rel)
            if not data.get('windows') or not data.get('recovery') or len(data.get('stars', [])) != 64:
                issues.append('挂机/星级参照缺少测量结果')
    smart = oracle / 'smart_ai.json'
    if manifest.get('toolVersion', 0) >= 9:
        if not smart.is_file():
            issues.append('智能AI参照缺失（重新运行 smart_ai_probe）')
        else:
            data = json.loads(smart.read_text())
            identity = data.get('sourceIdentity', {})
            if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
                issues.append('智能AI参照版本/脚本不一致')
            for rel, digest in manifest['inputs'].items():
                if rel.startswith('data/') or rel == 'package.json':
                    if identity.get('inputs', {}).get(rel) != digest:
                        issues.append('智能AI参照数据不一致：' + rel)
            if not data.get('cases') or not data.get('damage') or not data.get('sequence'):
                issues.append('智能AI参照缺少测量结果')
    options = oracle / 'options.json'
    if manifest.get('toolVersion', 0) >= 9:
        if not options.is_file():
            issues.append('基础设置参照缺失（重新运行 options_probe）')
        else:
            data = json.loads(options.read_text())
            identity = data.get('sourceIdentity', {})
            if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
                issues.append('基础设置参照版本/脚本不一致')
            for rel, digest in manifest['inputs'].items():
                if rel.startswith('data/') or rel == 'package.json':
                    if identity.get('inputs', {}).get(rel) != digest:
                        issues.append('基础设置参照数据不一致：' + rel)
            if not data.get('volume') or not data.get('dash') or not data.get('commands') or not data.get('notices') or not data.get('misc') or not data.get('pingbi') or not data.get('follow'):
                issues.append('基础设置参照缺少测量结果')
    sequences = oracle / 'sequences.json'
    if manifest.get('toolVersion', 0) >= 10:
        if not sequences.is_file():
            issues.append('行动序列参照缺失（重新运行 sequence_probe）')
        else:
            data = json.loads(sequences.read_text())
            identity = data.get('sourceIdentity', {})
            if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
                issues.append('行动序列参照版本/脚本不一致')
            for rel, digest in manifest['inputs'].items():
                if rel.startswith('data/') or rel == 'package.json':
                    if identity.get('inputs', {}).get(rel) != digest:
                        issues.append('行动序列参照数据不一致：' + rel)
            phases = ['setup', 'whole', 'target', 'follow', 'finish']
            for key, table in (('skills', 'Skills'), ('items', 'Items')):
                rows = json.loads((generated / 'db' / (table + '.json')).read_text())
                wrong = [r['id'] for r in rows if isinstance(r, dict) and data.get(key, {}).get(str(r['id'])) != hashlib.sha1(
                    json.dumps([r.get('yepSeq', {}).get(k, []) for k in phases], ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()]
                if wrong or len(data.get(key, {})) != sum(1 for r in rows if isinstance(r, dict)):
                    issues.append('行动序列与正式解析不一致：%s %d 项（如 %s）' % (table, len(wrong), wrong[:5]))
    party_file = oracle / 'party.json'
    if not party_file.is_file():
        issues.append('整队参照缺失（重新运行 party_probe）')
    else:
        data = json.loads(party_file.read_text())
        identity = data.get('sourceIdentity', {})
        if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
            issues.append('整队参照版本/脚本不一致')
        for rel, digest in manifest['inputs'].items():
            if rel.startswith('data/') or rel == 'package.json':
                if identity.get('inputs', {}).get(rel) != digest:
                    issues.append('整队参照数据不一致：' + rel)
        if len(data.get('trace', [])) != 11 or len(data.get('eligibility', [])) != 4 or not data.get('layout'):
            issues.append('整队参照缺少测量结果')
    events_file = oracle / 'events.json'
    if manifest.get('toolVersion', 0) >= 11:
        if not events_file.is_file():
            issues.append('地图事件对照参照缺失（重新运行 event_probe）')
        else:
            data = json.loads(events_file.read_text())
            identity = data.get('sourceIdentity', {})
            if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
                issues.append('地图事件对照参照版本/脚本不一致')
            for rel, digest in manifest['inputs'].items():
                if rel.startswith('data/') or rel == 'package.json':
                    if identity.get('inputs', {}).get(rel) != digest:
                        issues.append('地图事件对照参照数据不一致：' + rel)
            if len(data.get('cases', [])) < 100:
                issues.append('地图事件对照参照缺少用例')
    # 新参照不能只在某个测试里比较脚本身份：完整入口也要拒绝缺失、旧数据或探针报错。
    for name, key in [('troop_events.json', 'cases'), ('drop_record.json', 'record')]:
        file = oracle / name
        if not file.is_file():
            issues.append('缺少参照：' + name)
            continue
        data = json.loads(file.read_text())
        identity = data.get('sourceIdentity', {})
        if identity.get('releaseVersion') != version or identity.get('runtimeInputs') != manifest.get('runtimeInputs'):
            issues.append(name + ' 参照版本/脚本不一致')
        for rel, digest in manifest['inputs'].items():
            if rel.startswith('data/') or rel == 'package.json':
                if identity.get('inputs', {}).get(rel) != digest:
                    issues.append(name + ' 参照数据不一致：' + rel)
        if not data.get(key) or any(row.get('errors') for row in data.get(key, [])):
            issues.append(name + ' 缺少测量或测量出错')
        if name == 'troop_events.json' and {4, 5, 8, 28} - {row.get('troop') for row in data.get('cases', [])}:
            issues.append('敌群事件参照缺少守层者用例')
    if sequences.is_file():
        data = json.loads(sequences.read_text())
        if not data.get('operations') or not data.get('parseIntNumbers'):
            issues.append('行动序列缺少数值边界参照')
    return {'releaseVersion': version, 'inputs': len(manifest['inputs']),
            'runtimeInputs': len(manifest.get('runtimeInputs', {})),
            'outputs': len(manifest['outputs']), 'issues': issues}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=DEFAULT_APP)
    parser.add_argument('--generated', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--oracle-dir', type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.app, args.generated, args.oracle_dir or args.generated / 'oracle')
    except (OSError, ValueError, KeyError) as error:
        result = {'issues': [str(error)]}
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(1 if result['issues'] else 0)
