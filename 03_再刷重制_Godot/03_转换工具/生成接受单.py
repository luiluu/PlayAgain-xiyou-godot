#!/usr/bin/env python3
"""按同步报告的 changeCandidates 生成测量接受单草稿（期七，2026-10-26 哪吒）。

同步拒收（退出码 2，测量有改变）后，原来要从 同步报告.json 手抄 changeCandidates、逐条补 reason。这里照抄成接受单：
用法：python3 03_再刷重制_Godot/03_转换工具/生成接受单.py --out 04_验证/测量接受/<分支名把 / 换成 _>.json
        [--report <同步报告.json>] [--reason 理由 | --reason-from <交付单.md>] [--only 文件名…]
- --report 默认取本工作树 04_验证/本地结果/自动同步/ 里最新一份带 changeCandidates 的报告。
- reason：--reason 给全部条目同一句；--reason-from 读交付单「预期测量变化」节（没有就「变更记录草稿」节第一条）的正文；
  都不给就留空，草稿此时还不能用（接受单要求理由至少 4 字），打开文件逐条填上。
- --out 已存在就只追加还没有的条目（按 file／collection／key 判断），不改已有条目。
- 只生成草稿，不放行任何东西：同步时每条仍要和本轮变化的摘要、字段逐项对上、每条都用上，否则整轮拒收。
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
from oracle_additions import ACCEPT_FIELDS  # noqa: E402

BACKUPS = ROOT / '03_再刷重制_Godot/04_验证/本地结果/自动同步'


def latest_report(folder=BACKUPS):
    for d in sorted((p for p in folder.glob('*') if p.is_dir()), reverse=True):
        f = d / '同步报告.json'
        try:
            if json.loads(f.read_text()).get('changeCandidates'):
                return f
        except (OSError, ValueError):
            continue
    return None


def reason_from_sheet(path):
    text = Path(path).read_text()
    for title in ('预期测量变化', '变更记录草稿'):
        m = re.search(r'^## [^\n]*' + title + r'[^\n]*\n(.*?)(?=^## (?!.*【)|\Z)', text, re.M | re.S)
        if not m:
            continue
        body = [l.strip() for l in m.group(1).splitlines() if l.strip() and not l.startswith('## ')]
        if body:
            return re.sub(r'^[-*]\s*', '', body[0])
    return ''


def build(report, out, reason='', only=()):
    candidates = json.loads(Path(report).read_text()).get('changeCandidates') or []
    if only:
        candidates = [c for c in candidates if c['file'] in only]
    if not candidates:
        raise ValueError('报告里没有 changeCandidates（或 --only 过滤后为空）：' + str(report))
    data = json.loads(Path(out).read_text()) if Path(out).exists() else {'schema': 1, 'accept': []}
    if data.get('schema') != 1 or not isinstance(data.get('accept'), list):
        raise ValueError('已有接受单格式不对：' + str(out))
    have = {(e['file'], e['collection'], e['key']) for e in data['accept']}
    added = 0
    for c in candidates:
        if (c['file'], c['collection'], c['key']) in have:
            continue
        data['accept'].append({**{k: c[k] for k in ACCEPT_FIELDS[:6]}, 'reason': reason})
        added += 1
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    Path(out).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    blank = sum(1 for e in data['accept'] if len(e.get('reason', '').strip()) < 4)
    return {'out': str(out), 'report': str(report), 'added': added, 'total': len(data['accept']), 'needReason': blank}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--report', type=Path)
    g = ap.add_mutually_exclusive_group()
    g.add_argument('--reason', default='')
    g.add_argument('--reason-from', type=Path)
    ap.add_argument('--only', nargs='*', default=[], help='只收这些产物文件的变化，如 slice_d1.json')
    a = ap.parse_args(argv)
    report = a.report or latest_report()
    if report is None:
        print('找不到带 changeCandidates 的同步报告（先跑一轮同步，或用 --report 指定）', file=sys.stderr)
        return 2
    reason = reason_from_sheet(a.reason_from) if a.reason_from else a.reason
    try:
        result = build(report, a.out, reason, set(a.only))
    except (OSError, ValueError, KeyError) as error:
        print('生成失败：' + str(error), file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False))
    if result['needReason']:
        print('还有 %d 条 reason 不足 4 字：打开 %s 逐条核对变化并写上理由，再交给同步 --accept-changes' % (result['needReason'], a.out),
              file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
