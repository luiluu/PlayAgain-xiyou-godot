#!/usr/bin/env python3
"""车道 worktree 的 generated/oracle 与本分支切片是否同批。

`新建工作树.sh --补齐` 把主工作区较新的 generated/oracle 复制进来，但 maps、manifest 由本分支的转换器按本分支切片重生成。
主工作区合进新楼层后再补齐，就会出现「参照是新切片、地图是旧切片」，xiyou_event_compare 的完整性检查因此假失败。

  record <车道 generated> <主工作区 generated>   补齐复制了主工作区的参照后记批次（主工作区 manifest 的切片指纹与同步戳）
  check  <车道 generated>                        对比本分支 manifest 的切片指纹；不同批时打印提示，退出 3

记批次时同时记下本树当时的同步戳（generated/sync_stamp.json 的 outputsDigest；补齐只刷新 oracle/，不动这个戳）。
之后本树自己跑过 同步正式西游.py（戳变了），参照就是本分支生成的，不再提示。
没有批次记录（主工作区、或从未补齐过参照）时什么也不说。
"""
import json
from pathlib import Path
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


def record(gen, main_gen):
    src = _identity(main_gen)
    if not src['sliceConfigSHA256']:
        print(f'  ⚠ 主工作区 {main_gen}/manifest.json 没有切片指纹，未记参照批次')
        return 0
    batch = {'from': str(Path(main_gen).resolve()), 'sliceConfigSHA256': src['sliceConfigSHA256'],
             'laneOutputsDigest': _identity(gen)['outputsDigest']}
    (Path(gen) / BATCH).write_text(json.dumps(batch, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    return 0


def check(gen):
    gen = Path(gen)
    batch = _read(gen / BATCH)
    if not batch:
        return 0
    own = _identity(gen)
    if own['outputsDigest'] != batch.get('laneOutputsDigest'):
        return 0  # 本树自己同步过，参照按本分支生成
    if own['sliceConfigSHA256'] == batch.get('sliceConfigSHA256'):
        return 0
    print('  ⚠ generated/oracle 与本分支切片不同批：参照来自主工作区切片 '
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
