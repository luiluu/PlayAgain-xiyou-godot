#!/usr/bin/env python3
"""补跑 event_state_probe（审查 41 P2-1，cc·哪吒 fix4）：generated/oracle/event_states.json 缺失或比预设旧时补量一次（约 10 秒）。

它是 gitignore 的产物，只有同步会生成；新工作树、没同步过的 main 里没有，于是 xiyou_event_compare 的变体段和
事件空绿扫描 --check 要么报红要么（旧版）静默跳过。检查.sh 在 Godot 测试前、新建工作树.sh --补齐 在收尾时调用它。
探针只许写 mv_oracle/.sandbox（守卫），量完再拷进 generated/oracle。参照引擎或冻结正式源不在（云端等）就跳过，不算失败，
缺文件由对照专项与空绿扫描照实报红。用法：补跑事件状态探针.py [--force]（--force 关增量、整份重量，约 1 小时，开跑时会提示）
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ENV = Path(__file__).resolve().parent
TOOLS = ENV.parent / '03_转换工具'
GEN = ENV.parent / '01_Godot工程/modes/xiyou/generated'
ORACLE = TOOLS / 'mv_oracle'
OUT = GEN / 'oracle/event_states.json'
SRC = ORACLE / '.sandbox/event_states.json'


def needs(force):
    if force or not OUT.exists():
        return True
    stamp = OUT.stat().st_mtime
    # 预设在 03_转换工具/ 下（event_state_probe.cjs 读 ../event_presets.json）；原先写成 mv_oracle/ 下，找不到就永远不补跑（八戒 events8 发现）
    deps = [TOOLS / 'event_presets.json', ORACLE / 'event_state_probe.cjs', GEN / 'oracle/events.json']
    missing = [str(p.relative_to(ENV.parent)) for p in deps if not p.exists()]
    if missing:
        print('⚠ 判断要不要补跑时找不到：' + '、'.join(missing))
    return any(p.exists() and p.stat().st_mtime > stamp for p in deps)


# 分段并行（BO，派单第十一批）：5833 个变体单进程补跑约 14 分钟（新源上 24 分钟）。每个变体都从新局快照起跑、互不依赖，
# 所以按变体序号轮转分 n 段（XIYOU_PROBE_SHARD=i/n，难易搭配均衡），n 个 node 进程各占 1 个共用槽（占槽.py）、各用自己的存档目录，
# 跑完按序号交错拼回，与单进程逐字相同（测试事件探针分段.py 的合并用例＋v0.28 实测逐字节对比）。XIYOU_STATE_SHARDS=1 退回单进程。
# 分段、拼回与摘要账在 03_转换工具/event_state_shards.py（tools81 抽出，同步也用）。
sys.path.insert(0, str(TOOLS))
import event_state_shards  # noqa: E402
SHARD_MERGE_JS = event_state_shards.SHARD_MERGE_JS
HISTORY = ORACLE / '.sandbox/event_state_keys.json'


def run_probe(env):
    shards = max(1, int(os.environ.get('XIYOU_STATE_SHARDS', '4')))
    box = ORACLE / '.sandbox/run'
    box.mkdir(parents=True, exist_ok=True)
    history = event_state_shards.KeyHistory(HISTORY)
    keys = SRC.with_suffix('.keys.json')
    env = dict(env)
    # 上次的结果：账上认得已发布的那份就用它（同步写的账），否则沿用 .sandbox 里上次补跑的结果和旁边的摘要
    if not event_state_shards.prepare_prev(env, history, OUT, box):
        env['XIYOU_STATE_PREV'], env['XIYOU_STATE_PREV_KEYS'] = str(SRC), str(keys)
    slot = ENV / '占槽.py'

    def launch(e, label):
        return subprocess.run([sys.executable, str(slot), '--label', label, '--', 'node', 'event_state_probe.cjs'],
                              cwd=ORACLE, env=e, capture_output=True, text=True)
    r = event_state_shards.run_sharded(env, ORACLE, box, SRC, keys, shards, launch)
    if r.returncode == 0 and keys.is_file():
        history.add(keys)
    return r


def main():
    force = '--force' in sys.argv[1:]
    if not needs(force):
        print('事件状态探针产物在，不用补跑')
        return 0
    if not (ORACLE / 'node_modules').exists() or not (GEN / 'maps').exists():
        print('⚠ 没有参照引擎依赖或转换产物，跳过补跑 event_states.json（事件对照与空绿扫描会照实报缺）')
        return 0
    app = os.environ.get('XIYOU_APP')
    env = dict(os.environ, XIYOU_GENERATED=str(GEN))
    if not app:   # 探针默认读主工作区的冻结源绝对路径；工作树里那条链接同一份，优先用本树的
        link = ENV.parent / '02_内容与素材/冻结正式源/app.nw'
        if link.exists():
            env['XIYOU_APP'] = str(link)
    env.pop('XIYOU_EVENT_OUT', None)
    if force:
        env['XIYOU_STATE_INCREMENTAL'] = '0'   # --force＝整份重量（增量取回上次结果的路径关掉，BV）
        # 11-07：车道以为 --force 只是「强制补跑」，结果关了增量整份重量，占满槽一小时；先说清楚
        print('⚠ --force 会关掉增量、整份重量全部预设（本机约 1 小时、占测试槽）；只想补跑缺的，去掉 --force（默认增量，'
              'XIYOU_STATE_SHARDS=2 约 12 分钟）', flush=True)
    r = run_probe(env)
    if r.returncode or not SRC.exists():
        print('✗ event_state_probe 失败：' + (r.stderr or r.stdout).strip()[-300:])
        return 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SRC, OUT)
    print('✓ 已补跑 event_states.json：' + r.stdout.strip()[-120:])
    # 产物变了而云端快照还是旧的：留个标记，检查.sh --cloud 看到就不能沿用 CHECK_CLOUD_NO_UPLOAD（合并工具只看切片／转换器判 refresh，
    # 只改 event_presets.json 的合并 refresh=false，云端拿旧参照会挂；BK2）。云端传完后由 检查.sh 删标记
    try:
        gd = subprocess.run(['git', '-C', str(ENV), 'rev-parse', '--path-format=absolute', '--git-dir'], capture_output=True, text=True, check=True).stdout.strip()
        (Path(gd) / 'xiyou_cloud_upload_needed').write_text('event_states.json 已补跑，云端需重传产物\n')
    except (subprocess.CalledProcessError, OSError):
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
