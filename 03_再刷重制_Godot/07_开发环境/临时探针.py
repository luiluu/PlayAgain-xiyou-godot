#!/usr/bin/env python3
"""临时探针产物带车道标签（cc tools-probe-tags，2026-11-08）。

问题：车道手动跑探针常把产物写成固定名（如 .sandbox/dev_troop_events.json），同一车道下一次临时探针就盖掉上一次，
两个 clone／车道共用输出目录时更会互相盖（rules-gaps7 的 7 例被 826 调查盖掉过）。本工具按「车道标签」生成产物名，
不改 mv_oracle 里的任何文件（那里的 .cjs 是各探针缓存键的一部分，一改整轮重量）。

用法：
  临时探针.py path <名> [--label 标签]            打印产物路径 mv_oracle/.sandbox/dev_<名>.<车道>[.<标签>].json
  临时探针.py tag                                  打印本车道标签
  临时探针.py run [--label 标签] [--weight N] <探针.cjs> [参数…]
        经 占槽.py 在 mv_oracle 里跑探针，输出路径自动设成上面的带标签名（troop_event_probe.cjs→XIYOU_TROOP_OUT，
        event_probe.cjs／event_state_probe.cjs→XIYOU_EVENT_OUT），最后一行打印产物路径。其余环境变量原样传给探针。
车道标签：环境变量 XIYOU_LANE_TAG，否则当前 git 分支名（/ 换成 _），否则工作树目录名；只留字母数字、汉字、点、下划线、减号。"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ORACLE = HERE.parent / '03_转换工具' / 'mv_oracle'
SLOT = HERE / '占槽.py'
# 探针 → 输出路径的环境变量（只列有这个变量的探针）
OUT_ENV = {'troop_event_probe.cjs': 'XIYOU_TROOP_OUT', 'event_probe.cjs': 'XIYOU_EVENT_OUT', 'event_state_probe.cjs': 'XIYOU_EVENT_OUT'}


def clean(text):
    return re.sub(r'[^0-9A-Za-z一-鿿._-]+', '_', text).strip('._') or 'lane'


def lane_tag(root=None, env=None):
    env = os.environ if env is None else env
    if env.get('XIYOU_LANE_TAG'):
        return clean(env['XIYOU_LANE_TAG'])
    root = Path(root or HERE.parent.parent)
    r = subprocess.run(['git', '-C', str(root), 'symbolic-ref', '--short', '-q', 'HEAD'], capture_output=True, text=True)
    branch = r.stdout.strip() if r.returncode == 0 else ''
    return clean(branch or root.name)


def out_path(name, label='', root=None, env=None):
    name = re.sub(r'\.json$', '', name)
    if not re.fullmatch(r'[0-9A-Za-z_]+', name):
        raise SystemExit('产物名只许字母数字下划线：%r' % name)
    parts = ['dev_' + name, lane_tag(root, env)] + ([clean(label)] if label else [])
    return ORACLE / '.sandbox' / ('.'.join(parts) + '.json')


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('tag')
    p = sub.add_parser('path')
    p.add_argument('name')
    p.add_argument('--label', default='')
    r = sub.add_parser('run')
    r.add_argument('--label', default='')
    r.add_argument('--weight', type=int, default=1)
    r.add_argument('probe')
    r.add_argument('args', nargs=argparse.REMAINDER)
    a = ap.parse_args(argv)
    if a.cmd == 'tag':
        print(lane_tag())
        return 0
    if a.cmd == 'path':
        print(out_path(a.name, a.label))
        return 0
    probe = Path(a.probe).name
    var = OUT_ENV.get(probe)
    if not var:
        print('没有登记这个探针的输出变量：%s（登记在 临时探针.py 的 OUT_ENV）' % probe, file=sys.stderr)
        return 64
    out = out_path(probe.replace('_probe.cjs', '').replace('.cjs', ''), a.label)
    out.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, **{var: str(out)})
    cmd = [sys.executable, str(SLOT), '--weight', str(a.weight), '--label', '临时探针 ' + probe, '--', 'node', probe, *a.args]
    rc = subprocess.run(cmd, cwd=ORACLE, env=env).returncode
    print('产物：%s' % out)
    return rc


if __name__ == '__main__':
    sys.exit(main())
