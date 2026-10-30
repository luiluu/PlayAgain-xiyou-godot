#!/usr/bin/env python3
"""车道 worktree 的 generated/oracle 与本分支切片是否同批。

`新建工作树.sh --补齐` 把主工作区较新的 generated/oracle 复制进来，但 maps、manifest 由本分支的转换器按本分支切片重生成。
主工作区合进新楼层后再补齐，就会出现「参照是新切片、地图是旧切片」，xiyou_event_compare 的完整性检查因此假失败。

  record <车道 generated> <主工作区 generated>   补齐复制了主工作区的参照后记批次（主工作区 manifest 的切片指纹与同步戳）
  check  <车道 generated>                        对比本分支 manifest 的切片指纹；不同批时打印提示，退出 3

记批次时同时记下本树当时的同步戳（generated/sync_stamp.json 的 outputsDigest；补齐只刷新 oracle/，不动这个戳）。
之后本树自己跑过 同步正式西游.py（戳变了），参照就是本分支生成的，不再提示。
豁免只认「有效的新戳」（64 位十六进制摘要，且与记批次时不同）：戳文件丢了、损坏、缺字段都不算同步过证明，照常比对并多提示一句（沙僧第十五期 P2）。
记批次时还记下主工作区每份参照（oracle/*.json）的 SHA-256；check 逐份对本树的文件：不同（本树留了较新的另一版、或没复制过去）
就算混批，列出文件名并提示——不能只凭 manifest 切片指纹相同就当整份同批（沙僧第十五期 P2）。
没有批次记录（主工作区、或从未补齐过参照）时什么也不说。
"""
import hashlib
import json
from pathlib import Path
import re
import sys

BATCH = 'oracle_batch.json'


def _read(path):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def _identity(gen):
    gen = Path(gen)
    return {'sliceConfigSHA256': _read(gen / 'manifest.json').get('sliceConfigSHA256'),
            'outputsDigest': _read(gen / 'sync_stamp.json').get('outputsDigest')}


def _valid_digest(value):
    return isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value) is not None


def _oracle_digests(gen):
    out = {}
    for f in sorted((Path(gen) / 'oracle').glob('*.json')):
        try:
            out[f.name] = hashlib.sha256(f.read_bytes()).hexdigest()
        except OSError:
            pass
    return out


def record(gen, main_gen):
    src = _identity(main_gen)
    if not src['sliceConfigSHA256']:
        print(f'  ⚠ 主工作区 {main_gen}/manifest.json 没有切片指纹，未记参照批次')
        return 0
    batch = {'from': str(Path(main_gen).resolve()), 'sliceConfigSHA256': src['sliceConfigSHA256'],
             'laneOutputsDigest': _identity(gen)['outputsDigest'], 'mainOracle': _oracle_digests(main_gen)}
    (Path(gen) / BATCH).write_text(json.dumps(batch, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    return 0


def check(gen):
    gen = Path(gen)
    batch = _read(gen / BATCH)
    if not batch:
        return 0
    own = _identity(gen)
    note = ''
    if _valid_digest(own['outputsDigest']) and own['outputsDigest'] != batch.get('laneOutputsDigest'):
        return 0  # 本树自己同步过（有效的新戳），参照按本分支生成
    if _valid_digest(batch.get('laneOutputsDigest')) and not _valid_digest(own['outputsDigest']):
        note = '本树的同步戳丢失或损坏（sync_stamp.json），无法证明本树自己同步过；'
    mixed = []
    recorded = batch.get('mainOracle')
    if isinstance(recorded, dict):
        now = _oracle_digests(gen)
        mixed = sorted(n for n, d in recorded.items() if now.get(n) != d)
    if own['sliceConfigSHA256'] == batch.get('sliceConfigSHA256') and not mixed and not note:
        return 0
    if mixed:
        print(f'  ⚠ generated/oracle 有 {len(mixed)} 份参照与补齐时的主工作区版本不同（{"、".join(mixed[:4])}{"等" if len(mixed) > 4 else ""}），'
              '混批：可能留着较新的另一版或没复制过来。')
        if own['sliceConfigSHA256'] == batch.get('sliceConfigSHA256'):
            return 3
    if note and own['sliceConfigSHA256'] == batch.get('sliceConfigSHA256'):
        print('  ⚠ ' + note + '切片指纹相同，仅提示。')
        return 0
    print(note + '  ⚠ generated/oracle 与本分支切片不同批：参照来自主工作区切片 '
          f"{str(batch.get('sliceConfigSHA256'))[:12]}，本分支切片 {str(own['sliceConfigSHA256'])[:12]}。"
          'xiyou_event_compare 等按切片数例的检查会假失败。'
          '本分支落后 main：先 git merge main，再 新建工作树.sh --补齐 本树；本分支改了切片：在本树跑 同步正式西游.py。')
    return 3


def main(argv):
    if len(argv) == 3 and argv[0] == 'record':
        return record(argv[1], argv[2])
    if len(argv) == 2 and argv[0] == 'check':
        return check(argv[1])
    print(__doc__.strip(), file=sys.stderr)
    return 64


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
