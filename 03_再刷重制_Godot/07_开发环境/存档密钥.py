#!/usr/bin/env python3
"""存档封存发行密钥（D28，co 甲档核查 P2④）：生成、查看。密钥文件放在私密设计仓，绝不放进本（公开）仓库。

  python3 存档密钥.py --init            在默认位置生成 {"current": 1, "keys": {"1": 64 位十六进制}}（已有就不动）
  python3 存档密钥.py --rotate          加一个新号并设为 current（旧号留着，发行包仍读得了旧号封存的档）
  python3 存档密钥.py --check           只查格式，不打印密钥
  --file <路径>                          换位置（默认 ~/Documents/xiyou-design-docs/发行密钥/save_seal_key.json，或环境变量 XIYOU_SAVE_KEY）

出包：发行出包.py 把它复制进导出用的工程副本 res://content/save_seal_key.json，导完删（本仓库 .gitignore 了这个路径）。
注意：发行后不要删旧号——删了玩家用旧号封存的档就读不了（读不了算「存档校验失败」，文件仍留着）。
"""
import argparse
import json
import os
import re
import secrets
from pathlib import Path

SEED_RE = re.compile(r'^[0-9a-f]{64}$')

DEFAULT = Path(os.environ.get('XIYOU_SAVE_KEY') or Path.home() / 'Documents' / 'xiyou-design-docs' / '发行密钥' / 'save_seal_key.json')


def load(p: Path) -> dict:
    return json.loads(p.read_text(encoding='utf-8'))


def check(d) -> str:
    """密钥文件格式检查；与游戏运行时 XSaveSeal._load_keys 的要求逐条一致（改一边必须改另一边，两边测试用同一批样例）：
    keys 非空；每个号是 1～255 的十进制整数串；每个种子是 64 位小写十六进制；current 是整数 1～255 且在 keys 里。
    任何一条不符整份不认（运行时就不封存）。返回问题，空串＝合格。"""
    if not isinstance(d, dict):
        return '不是 JSON 对象'
    keys = d.get('keys')
    if not isinstance(keys, dict) or not keys:
        return '没有 keys'
    for k, v in keys.items():
        if not re.fullmatch(r'[1-9][0-9]{0,2}', str(k)) or not 1 <= int(k) <= 255:
            return f'号 {k} 不对（要 1～255）'
        if not isinstance(v, str) or not SEED_RE.match(v):
            return f'号 {k} 的种子不对（要 64 位小写十六进制）'
    cur = d.get('current')
    if isinstance(cur, bool) or not isinstance(cur, int) or not 1 <= cur <= 255:
        return 'current 要是 1～255 的整数'
    if str(cur) not in keys:
        return 'current 不在 keys 里'
    return ''


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--file', type=Path, default=DEFAULT)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--init', action='store_true')
    g.add_argument('--rotate', action='store_true')
    g.add_argument('--check', action='store_true')
    a = ap.parse_args(argv)
    p = a.file
    if a.init:
        if p.exists():
            print(f'已有：{p}（不动）')
            return 0
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps({'current': 1, 'keys': {'1': secrets.token_hex(32)}}, indent=1) + '\n', encoding='utf-8')
        os.chmod(p, 0o600)
        print(f'已生成：{p}（号 1）。记得在私密设计仓提交它；不要拷进游戏仓库。')
        return 0
    if not p.is_file():
        print(f'✗ 没有 {p}')
        return 1
    d = load(p)
    bad = check(d)
    if bad:
        print(f'✗ {p}：{bad}')
        return 1
    if a.rotate:
        n = max(int(k) for k in d['keys']) + 1
        if n > 255:
            print('✗ 号用完了')
            return 1
        d['keys'][str(n)] = secrets.token_hex(32)
        d['current'] = n
        p.write_text(json.dumps(d, indent=1) + '\n', encoding='utf-8')
        print(f'已加号 {n} 并设为 current（旧号留着）')
        return 0
    print(f'✓ {p}：current {d["current"]}，共 {len(d["keys"])} 个号')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
