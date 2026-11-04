#!/usr/bin/env python3
"""车道 worktree 的 generated/oracle 与本分支切片是否同批。

`新建工作树.sh --补齐` 把主工作区较新的 generated/oracle 复制进来，但 maps、manifest 由本分支的转换器按本分支切片重生成。
主工作区合进新楼层后再补齐，就会出现「参照是新切片、地图是旧切片」，xiyou_event_compare 的完整性检查因此假失败。

  record <车道 generated> <主工作区 generated>   补齐复制了主工作区的参照后记批次（主工作区 manifest 的切片指纹与同步戳）
  flux   <主工作区 .git 目录>                    总装正在合并中（合并状态在「已合并…待收尾」阶段）时打印说明，退出 4；否则退出 0（tools59）
  check  <车道 generated>                        对比本分支 manifest 的切片指纹；不同批时打印提示，退出 3
  refresh <主 oracle 目录> <车道 oracle 目录>     按内容刷新车道参照（不再只比 mtime）；刷新了文件退出 10，没有退出 0（tools64）
  pending <车道 generated> [set|clear]           补齐因总装合并跳过了刷新时留标记；标记在时 compare 一律比对参照（tools64）

记批次时同时记下本树当时的同步戳（generated/sync_stamp.json 的 outputsDigest；补齐只刷新 oracle/，不动这个戳）。
之后本树自己跑过 同步正式西游.py（戳变了），参照就是本分支生成的，不再提示。
豁免只认「有效的新戳」（64 位十六进制摘要，且与记批次时不同）：戳文件丢了、损坏、缺字段都不算同步过证明，照常比对并多提示一句（沙僧第十五期 P2）。
记批次时还记下主工作区每份参照（oracle/*.json）的 SHA-256；check 逐份对本树的文件：不同（本树留了较新的另一版、或没复制过去）
就算混批，列出文件名并提示——不能只凭 manifest 切片指纹相同就当整份同批（沙僧第十五期 P2）。
没有批次记录（主工作区、或从未补齐过参照）时什么也不说。
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time

BATCH = 'oracle_batch.json'
PENDING = 'oracle_pending.json'  # 补齐遇总装合并跳过了刷新：参照可能是旧的，等合并收尾后再补齐才清


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


def refresh(src, dst, gen=None):
    """按内容刷新车道的 generated/oracle（tools64，原 shell 只比 mtime：车道的文件时间戳比主工作区新就永远不刷新，
    例如整份克隆 generated/ 时文件时间被改成克隆时刻，之后主工作区更新参照也不会被拿过来）。
    主工作区有、车道没有或内容不同时：车道那份与上次补齐记的主工作区版本相同（本树没自己改过）、或主工作区的更新，就覆盖；
    否则（本树自己同步出的、且不比主工作区旧）保留，并列出来提醒。"""
    src, dst = Path(src), Path(dst)
    if not src.is_dir():
        return 0
    dst.mkdir(parents=True, exist_ok=True)
    recorded = (_read(Path(gen) / BATCH) if gen else {}).get('mainOracle') or {}
    copied, kept = [], []
    for f in sorted(src.glob('*')):
        if not f.is_file():
            continue
        t = dst / f.name
        if t.exists():
            if hashlib.sha256(t.read_bytes()).hexdigest() == hashlib.sha256(f.read_bytes()).hexdigest():
                continue
            mine_unchanged = recorded.get(f.name) == hashlib.sha256(t.read_bytes()).hexdigest()
            if not mine_unchanged and t.stat().st_mtime_ns > f.stat().st_mtime_ns:
                kept.append(f.name)
                continue
        tmp = t.with_name(t.name + '.refresh_tmp')
        shutil.copy2(f, tmp)  # 保留时间戳
        os.replace(tmp, t)
        copied.append(f.name)
    own = sorted(f.name for f in dst.glob('*') if f.is_file() and not (src / f.name).exists())
    print(f'== generated/oracle：从主工作区刷新 {len(copied)} 个文件' + (f'（{"、".join(copied[:6])}{"等" if len(copied) > 6 else ""}）' if copied else '')
          + (f'；保留本分支独有 {"、".join(own)}' if own else ''))
    if kept:
        print(f'  ⚠ {len(kept)} 份参照与主工作区不同，但本树自己改过且不比主工作区旧，没覆盖：{"、".join(kept[:6])}；'
              '这些是你自己同步出来的就不用管，不是就删掉该文件再 --补齐。')
    return 10 if copied else 0


def pending(gen, action):
    mark = Path(gen) / PENDING
    if action == 'set':
        mark.write_text(json.dumps({'time': time.strftime('%Y-%m-%d %H:%M:%S'),
                                    'note': '补齐时总装正在合并，没刷新 generated/oracle；合并收尾后重跑 新建工作树.sh --补齐'}, ensure_ascii=False) + '\n', encoding='utf-8')
    else:
        mark.unlink(missing_ok=True)
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


def compare(gen, main_gen):
    """并行测试开跑前比对车道与主工作区当前的 generated/。

    只在「本树没有自己的改动」时判落后，车道改了切片、自己同步过的一律不拦：
    ① 两边切片指纹相同，manifest 产物清单（outputs）却有差异＝产物旧了（yunshang_shop 因此挂在 HD 图标，补齐后 418/418）；
    ② 本树没自己同步过（同步戳与记批次时一致，或没有批次记录），主工作区的参照（oracle/*.json）已比本树新。
    任何一边缺 manifest 都不说话（主工作区就是自己、或还没生成）。"""
    gen, main_gen = Path(gen), Path(main_gen)
    lane_m, main_m = _read(gen / 'manifest.json'), _read(main_gen / 'manifest.json')
    if not lane_m.get('sliceConfigSHA256') or lane_m.get('sliceConfigSHA256') != main_m.get('sliceConfigSHA256'):
        return 0
    stale = []
    lo, mo = lane_m.get('outputs'), main_m.get('outputs')
    if isinstance(lo, dict) and isinstance(mo, dict):
        stale += sorted(k for k in set(lo) | set(mo) if lo.get(k) != mo.get(k))
    own = _identity(gen)['outputsDigest']
    batch = _read(gen / BATCH)
    self_synced = _valid_digest(own) and (not batch or own != batch.get('laneOutputsDigest'))
    if (gen / PENDING).is_file():  # 上次补齐因总装合并跳过了刷新：没记批次时本树的同步戳不算「自己同步过」（tools64）
        self_synced = self_synced and bool(batch) and own != batch.get('laneOutputsDigest')
    if not self_synced:
        now = _oracle_digests(gen)
        stale += ['oracle/' + n for n, d in sorted(_oracle_digests(main_gen).items()) if now.get(n) != d]
    if not stale:
        return 0
    print(f'  ✗ 本树 generated/ 落后主工作区（{len(stale)} 项不同：{"、".join(stale[:4])}{"等" if len(stale) > 4 else ""}）。'
          '直接跑会出一堆假失败（图标、地图、参照对不上）。先 git merge main，再 新建工作树.sh --补齐 <本树> --branch <本分支>；'
          '确认要照现状跑就加 --skip-generated-check（或 XIYOU_SKIP_GENERATED_CHECK=1）。')
    return 3


IN_FLUX_PHASES = ('merged', 'synced', 'numbering', 'versioned', 'prepared')
# 状态文件超过这么久没动，当作总装已中断／卡住、不再算「正在合并」，车道恢复正常比对（tools61，审查 38 P3-9：
# 原来只看 phase，总装中断后停在 prepared，车道的陈旧产物检查会一直被跳过）。一次合并收尾全程约 13 分钟。
# 环境变量 XIYOU_MERGE_FLUX_MAX_AGE=秒 可改，0＝不看时间（旧行为）。
FLUX_MAX_AGE = 30 * 60


def flux(git_common_dir):
    """主工作区的合并走到「已合并、同步、编号、待收尾」之间时，它的 generated/ 带着还没验收提交的新参照和产物：
    车道此时 --补齐 会拷走这些未定稿的参照，并行测试比对也会拿它当标准而拦车道（悟空 tail2、tail3 报，tools59）。
    读 <git 目录>/lane-merge/state.json 的 phase；读不到、其它阶段（planned、committed）都不算。
    回退：环境变量 XIYOU_IGNORE_MERGE_FLUX=1 当没在合并。"""
    if os.environ.get('XIYOU_IGNORE_MERGE_FLUX') == '1':
        return 0
    state = _read(Path(git_common_dir) / 'lane-merge' / 'state.json')
    phase = state.get('phase')
    if phase not in IN_FLUX_PHASES:
        return 0
    try:
        max_age = float(os.environ.get('XIYOU_MERGE_FLUX_MAX_AGE', FLUX_MAX_AGE))
    except ValueError:
        max_age = FLUX_MAX_AGE
    if max_age > 0:
        try:
            age = time.time() - (Path(git_common_dir) / 'lane-merge' / 'state.json').stat().st_mtime
        except OSError:
            return 0
        if age > max_age:
            return 0
    print(f'  ⚠ 总装正在合并 {state.get("branch", "?")}（阶段 {phase}），主工作区的 generated/ 还没定稿；'
          '本次不从它刷新参照、不拿它比对，所以这次测试可能用着过期产物：等合并收尾后再 --补齐并补跑一次；XIYOU_IGNORE_MERGE_FLUX=1 照旧比对。')
    return 4


def main(argv):
    if len(argv) == 3 and argv[0] == 'record':
        return record(argv[1], argv[2])
    if len(argv) == 2 and argv[0] == 'check':
        return check(argv[1])
    if len(argv) == 2 and argv[0] == 'flux':
        return flux(argv[1])
    if len(argv) in (3, 4) and argv[0] == 'refresh':
        return refresh(argv[1], argv[2], argv[3] if len(argv) == 4 else None)
    if len(argv) in (2, 3) and argv[0] == 'pending':
        return pending(argv[1], argv[2] if len(argv) == 3 else 'set')
    if len(argv) == 3 and argv[0] == 'compare':
        return compare(argv[1], argv[2])
    print(__doc__.strip(), file=sys.stderr)
    return 64


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
