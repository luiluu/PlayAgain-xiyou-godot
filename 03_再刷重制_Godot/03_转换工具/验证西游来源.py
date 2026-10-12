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
    for difficulty in [2, 3, 4]:
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
