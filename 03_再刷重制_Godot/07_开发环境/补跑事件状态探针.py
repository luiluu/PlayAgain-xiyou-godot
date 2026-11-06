#!/usr/bin/env python3
"""补跑 event_state_probe（审查 41 P2-1，cc·哪吒 fix4）：generated/oracle/event_states.json 缺失或比预设旧时补量一次（约 10 秒）。

它是 gitignore 的产物，只有同步会生成；新工作树、没同步过的 main 里没有，于是 xiyou_event_compare 的变体段和
事件空绿扫描 --check 要么报红要么（旧版）静默跳过。检查.sh 在 Godot 测试前、新建工作树.sh --补齐 在收尾时调用它。
探针只许写 mv_oracle/.sandbox（守卫），量完再拷进 generated/oracle。参照引擎或冻结正式源不在（云端等）就跳过，不算失败，
缺文件由对照专项与空绿扫描照实报红。用法：补跑事件状态探针.py [--force]
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
SHARD_MERGE_JS = r'''
const fs = require('fs'), [out, ...parts] = process.argv.slice(1);
const docs = parts.map(p => JSON.parse(fs.readFileSync(p, 'utf8')));
for (const d of docs) if (JSON.stringify([d.sourceIdentity, d.setup]) !== JSON.stringify([docs[0].sourceIdentity, docs[0].setup])) throw new Error('分段的来源或设置不一致');
const n = docs.length, total = docs.reduce((a, d) => a + d.cases.length, 0), cases = [];
for (let k = 0; k < total; k++) {
  const c = docs[k % n].cases[Math.floor(k / n)];
  if (!c) throw new Error('分段的用例数对不上（第 ' + k + ' 个）');
  cases.push(c);
}
fs.writeFileSync(out, JSON.stringify(Object.assign({sourceIdentity: docs[0].sourceIdentity, setup: docs[0].setup, cases}, docs[0].skippedPresets ? {skippedPresets: docs[0].skippedPresets} : {})));
console.log(JSON.stringify({cases: cases.length, shards: n}));
'''


def run_probe(env):
    shards = max(1, int(os.environ.get('XIYOU_STATE_SHARDS', '4')))
    if shards == 1:
        return subprocess.run(['node', 'event_state_probe.cjs'], cwd=ORACLE, env=env, capture_output=True, text=True)
    import concurrent.futures
    box = ORACLE / '.sandbox/run'
    box.mkdir(parents=True, exist_ok=True)
    slot = ENV / '占槽.py'

    def part(i):
        sub = box / ('state-shard-%d' % i)
        shutil.rmtree(sub, ignore_errors=True)
        sub.mkdir()
        for name in ['save', 'macport']:
            if (ORACLE / '.sandbox' / name).is_dir():
                shutil.copytree(ORACLE / '.sandbox' / name, sub / name)
        e = dict(env, XIYOU_ORACLE_SANDBOX=str(sub), XIYOU_PROBE_SHARD='%d/%d' % (i, shards), XIYOU_EVENT_OUT=str(sub / 'part.json'),
                 XIYOU_STATE_PREV=str(SRC), XIYOU_STATE_KEYS_OUT=str(sub / 'part.keys.json'))
        return subprocess.run([sys.executable, str(slot), '--label', 'event_state_probe %d/%d' % (i + 1, shards), '--',
                               'node', 'event_state_probe.cjs'], cwd=ORACLE, env=e, capture_output=True, text=True)
    with concurrent.futures.ThreadPoolExecutor(shards) as pool:
        done = list(pool.map(part, range(shards)))
    bad = [p for p in done if p.returncode]
    if bad:
        return subprocess.CompletedProcess(bad[0].args, bad[0].returncode, bad[0].stdout, bad[0].stderr)
    parts = [str(box / ('state-shard-%d' % i) / 'part.json') for i in range(shards)]
    keys_part = box / 'state-shard-0' / 'part.keys.json'
    keys_doc = json.loads(keys_part.read_text()) if keys_part.is_file() else None
    m = subprocess.run(['node', '-e', SHARD_MERGE_JS, str(SRC)] + parts, cwd=ORACLE, capture_output=True, text=True)
    if m.returncode == 0 and keys_doc is not None:   # 增量用的摘要：各段的全部变体摘要相同，取第 0 段的，补上拼回后整份文件的摘要（BV）
        import hashlib
        keys_doc['fileSha'] = hashlib.sha256(SRC.read_bytes()).hexdigest()
        SRC.with_suffix('.keys.json').write_text(json.dumps(keys_doc))
    for i in range(shards):
        shutil.rmtree(box / ('state-shard-%d' % i), ignore_errors=True)
    return m


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
