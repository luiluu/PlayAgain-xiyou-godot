#!/usr/bin/env python3
"""按原始权重计算进度。默认只读；--write 更新账表合计/各行计入与当前状态；--check 仅核对。"""
import argparse
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LEDGER = Path('00_项目管理/重制步骤清单.md')
STATE = Path('00_项目管理/当前状态.json')


def number(text):
    if not re.fullmatch(r'\d+(?:\.\d+)?', text.strip()):
        raise ValueError('进度账存在非数字权重或完成度：' + text)
    return Decimal(text.strip())


def display(value):
    return format(value, 'f').rstrip('0').rstrip('.') if '.' in format(value, 'f') else str(value)


def calculate(text):
    lines = text.splitlines(keepends=True)
    active, rows, total_index = False, [], None
    for i, line in enumerate(lines):
        if line.startswith('## 进度账'):
            active = True
            continue
        if active and line.startswith('## '):
            break
        if not active or not line.startswith('|'):
            continue
        cells = [x.strip() for x in line.strip().strip('|').split('|')]
        if len(cells) < 4:
            continue
        if cells[0].replace('*', '') == '合计':
            if total_index is not None:
                raise ValueError('进度账有多行合计')
            total_index = i
            continue
        if cells[0] == '部分' or cells[0].startswith('---'):
            continue
        weight, percent = number(cells[1]), number(cells[2].removesuffix('%'))
        if not 0 <= percent <= 100 or not 0 < weight <= 100:
            raise ValueError('权重或完成度超出范围：' + cells[0])
        rows.append({'line': i, 'cells': cells, 'name': cells[0], 'weight': weight,
                     'completion': percent, 'contribution': weight * percent / 100})
    if total_index is None or not rows or sum(row['weight'] for row in rows) != 100:
        raise ValueError('进度账缺失、合计不唯一或权重之和不为100')
    raw = sum(row['contribution'] for row in rows)
    rounded = raw.quantize(Decimal('0.1'), rounding=ROUND_HALF_UP)
    total_cells = [x.strip() for x in lines[total_index].strip().strip('|').split('|')]
    current = number(total_cells[3].replace('*', ''))
    for row in rows:
        row['cells'][3] = display(row['contribution'])
        lines[row['line']] = '| ' + ' | '.join(row['cells']) + ' |\n'
    total_cells[3] = '**' + format(rounded, '.1f') + '**'
    lines[total_index] = '| ' + ' | '.join(total_cells) + ' |\n'
    return {'raw': raw, 'rounded': rounded, 'current': current, 'rows': rows,
            'text': ''.join(lines)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, default=ROOT)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true')
    mode.add_argument('--check', action='store_true')
    ap.add_argument('--as-of', help='写入/核对的开发编号；省略则保留既有审核口径')
    a = ap.parse_args(argv)
    try:
        ledger, state_file = a.root / LEDGER, a.root / STATE
        result = calculate(ledger.read_text())
        state = json.loads(state_file.read_text())
        current = Decimal(str(state['progress']['percent']))
        if a.as_of and not re.fullmatch(r'dev\.\d{3,}', a.as_of):
            raise ValueError('--as-of 必须为 dev.NNN')
        consistent = (result['current'] == result['rounded'] == current
                      and (not a.as_of or state['progress'].get('asOf') == a.as_of))
        if a.write:
            state['progress']['percent'] = float(result['rounded'])
            if a.as_of:
                state['progress']['asOf'] = a.as_of
            ledger.write_text(result['text'])
            state_file.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'rawPercent': display(result['raw']), 'percent': float(result['rounded']),
                          'consistent': consistent, 'written': a.write,
                          'rows': [{'name': row['name'], 'contribution': display(row['contribution'])}
                                   for row in result['rows']]}, ensure_ascii=False))
        return 1 if a.check and not consistent else 0
    except (ValueError, OSError, KeyError, TypeError, InvalidOperation) as error:
        print('进度账校验失败：' + str(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
