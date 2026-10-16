#!/usr/bin/env python3
"""默认校验三类正式参照；--reference FILE --actual FILE 对照实现输出。部分实现可显式 --prefix。"""
import argparse
import json
from pathlib import Path
from common_oracle_contract import compare_reports, verify_reports, FILES
from xiyou_export import DEFAULT_OUT

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--generated', type=Path, default=DEFAULT_OUT)
ap.add_argument('--oracle-dir', type=Path)
ap.add_argument('--reference', type=Path)
ap.add_argument('--actual', type=Path)
ap.add_argument('--prefix', action='append', default=[])
a = ap.parse_args()
try:
    if a.reference or a.actual or a.prefix:
        if not (a.reference and a.actual):
            ap.error('对照须同时提供 --reference 与 --actual')
        result = compare_reports(json.loads(a.reference.read_text()), json.loads(a.actual.read_text()), a.prefix)
    else:
        issues = verify_reports(a.oracle_dir or a.generated / 'oracle', json.loads((a.generated / 'manifest.json').read_text()))
        result = {'referenceIntegrityOnly': True, 'cases': sum(map(len, FILES.values())), 'passed': not issues, 'issues': issues}
except (OSError, ValueError, TypeError, KeyError) as error:
    result = {'passed': False, 'issues': [str(error)]}
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(0 if result['passed'] else 1)
