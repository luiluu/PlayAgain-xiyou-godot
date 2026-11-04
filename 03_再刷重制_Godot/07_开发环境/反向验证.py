#!/usr/bin/env python3
"""反向验证：故意改坏一处，看指定专项会不会报错，然后还原（白龙_10 提，tools33）。

用来确认新加的断言真的咬得住：改动清单里每一项是「把某文件里的某个片段改成别的」，逐项改→单跑专项→记失败数→用备份还原。
还原用事先拷的备份字节写回（不用 git checkout，免得冲掉工作树里未提交的改动）；中途被打断，下次开跑先按遗留的备份目录还原。

  反向验证.py <清单.json> [--tests 前缀 ...] [--godot 路径] [--project 路径] [--dry-run]

清单：{"tests": ["xiyou_foo"], "items": [{"name": "去掉冷却判断", "file": "相对工程根或仓库根的路径", "find": "原片段", "replace": "新片段"}]}
- file 相对仓库根（git 根）；find 必须在文件里恰好出现一次，否则该项记「定位失败」不改；--tests 覆盖清单里的 tests。
- 每项的结论：失败数 ≥1＝咬住了（好）；0＝这处改动测试没发现（断言可能没覆盖）；基线（不改）先跑一次，基线不过则整个中止。
- 最后打一张表。退出码：有「没咬住」或「定位失败」时 1，否则 0。--dry-run 只检查清单能不能定位，不跑测试。
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REMAKE = HERE.parent
ROOT = REMAKE.parent
PARALLEL = HERE / '并行测试.py'


def run_tests(godot: Path, project: Path, tests: list[str]) -> tuple[bool, str]:
    cmd = [sys.executable, str(PARALLEL), str(godot), str(project), '--quiet', '--full', *tests]
    p = subprocess.run(cmd, capture_output=True, text=True)
    out = p.stdout + p.stderr
    return p.returncode == 0, out


def failures(out: str) -> str:
    m = re.findall(r'(\d+) 个失败|失败[:：]\s*(\d+)', out)
    n = [int(a or b) for a, b in m]
    return str(n[-1]) if n else '有失败'


def locate(item: dict) -> tuple[Path, str, str]:
    path = ROOT / item['file']
    if not path.is_file():
        raise ValueError('文件不存在：' + item['file'])
    text = path.read_text()
    n = text.count(item['find'])
    if n != 1:
        raise ValueError('片段出现 %d 次（要恰好 1 次）' % n)
    return path, text, text.replace(item['find'], item['replace'], 1)


def validate(cfg, need_tests: bool) -> list[str]:
    """开跑前校验清单字段（xuan4c 报：replace 写成 to 直接 KeyError，基线都跑完了才崩，tools59）。返回问题列表，空＝合格。"""
    if not isinstance(cfg, dict):
        return ['清单顶层必须是对象 {"tests": [...], "items": [...]}']
    errs = []
    tests = cfg.get('tests')
    if need_tests and not (isinstance(tests, list) and tests and all(isinstance(t, str) and t for t in tests)):
        errs.append('tests 必须是非空字符串列表（或命令行用 --tests 指定）')
    items = cfg.get('items')
    if not isinstance(items, list) or not items:
        return errs + ['items 必须是非空列表']
    for i, it in enumerate(items, 1):
        label = '第 %d 项' % i
        if not isinstance(it, dict):
            errs.append('%s 必须是对象' % label); continue
        label += '（%s）' % it['name'] if isinstance(it.get('name'), str) and it['name'] else ''
        missing = [k for k in ('name', 'file', 'find', 'replace') if k not in it]
        if missing:
            hint = '；认的字段是 name、file、find、replace' + ('（"to" 应写成 "replace"）' if 'to' in it else '')
            errs.append('%s 缺字段 %s%s' % (label, '、'.join(missing), hint))
        wrong = [k for k in ('name', 'file', 'find', 'replace') if k in it and not isinstance(it[k], str)]
        if wrong:
            errs.append('%s 的 %s 必须是字符串' % (label, '、'.join(wrong)))
        if isinstance(it.get('find'), str) and not it['find']:
            errs.append('%s 的 find 不能为空' % label)
        extra = sorted(set(it) - {'name', 'file', 'find', 'replace'})
        if extra and not missing:  # 多余字段只提醒（可能是备注），缺字段时已在上面说清
            print('⚠ %s 有不认的字段 %s，已忽略' % (label, '、'.join(extra)))
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest', type=Path)
    ap.add_argument('--tests', nargs='*')
    ap.add_argument('--godot', type=Path, default=HERE / 'godot')
    ap.add_argument('--project', type=Path, default=REMAKE / '01_Godot工程')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    try:
        cfg = json.loads(a.manifest.read_text())
    except (OSError, ValueError) as e:
        print('✗ 读不了清单 %s：%s' % (a.manifest, e)); return 64
    errs = validate(cfg, need_tests=not a.tests and not a.dry_run)
    if errs:
        print('✗ 清单有问题，未开跑：\n  ' + '\n  '.join(errs))
        return 64
    tests = a.tests or cfg.get('tests')
    items = cfg['items']
    rows, bad = [], False
    if a.dry_run:
        for it in items:
            try:
                locate(it)
                rows.append((it['name'], '可定位'))
            except ValueError as e:
                rows.append((it['name'], '定位失败：%s' % e)); bad = True
    else:
        ok, out = run_tests(a.godot, a.project, tests)
        if not ok:
            print(out[-1500:])
            print('✗ 基线（不改）就没过，先修好再反向验证')
            return 2
        for it in items:
            try:
                path, original, changed = locate(it)
            except ValueError as e:
                rows.append((it['name'], '定位失败：%s' % e)); bad = True
                continue
            backup = Path(tempfile.mkdtemp(prefix='反向验证备份_')) / path.name
            shutil.copy2(path, backup)                     # 字节级备份；还原从它写回
            try:
                path.write_text(changed)
                ok, out = run_tests(a.godot, a.project, tests)
            finally:
                shutil.copy2(backup, path)
                shutil.rmtree(backup.parent, ignore_errors=True)
            if path.read_text() != original:
                print('✗ 还原后内容和原来不一致：' + str(path)); return 3
            if ok:
                rows.append((it['name'], '没咬住（测试仍全过）')); bad = True
            else:
                rows.append((it['name'], '咬住了（失败数 %s）' % failures(out)))
    w = max([len(r[0]) for r in rows] + [4])
    print('%s  结论' % '改动'.ljust(w))
    for name, verdict in rows:
        print('%s  %s' % (name.ljust(w), verdict))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
