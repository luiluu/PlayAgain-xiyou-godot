"""event_state_probe.cjs 的分段并行与增量摘要（哪吒 tools81，从 补跑事件状态探针.py 抽出，同步与补跑共用）。

- 分段（BO）：按变体序号轮转分 n 段（XIYOU_PROBE_SHARD=i/n），各段一个 node 进程、各用自己的存档目录，
  跑完按序号交错拼回，与单进程逐字相同。
- 增量（BV，tools81 起按地图）：探针旁边的摘要文件记每个变体的摘要和它读到的冻结源地图；下次把「上次的结果＋摘要」
  交给探针（XIYOU_STATE_PREV／XIYOU_STATE_PREV_KEYS），摘要没变的变体原样取回。
- 摘要账（KeyHistory）：同步开跑前会删掉 .sandbox 里的上次产物，所以摘要另存一本账（按结果文件的 SHA-256 认领），
  上次的结果用已发布的 generated/oracle/event_states.json；账上找不到这份文件的摘要就整份重量（不会错，只是慢）。
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time

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

KEEP = 6   # 账上留几份（主工作区、集成树、失败重跑各有一份时都还认得）


def file_sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def merge_keys(part_keys, merged_out, keys_out):
    """各段的摘要（各自只含本段变体）并成一份，补上拼回后整份结果的摘要。版本或公共摘要不一致就不写（下次整份重量）。"""
    docs = []
    for p in part_keys:
        try:
            docs.append(json.loads(Path(p).read_text()))
        except (OSError, ValueError):
            return False
    if not docs or any(d.get('version') != 2 or d.get('coreFingerprint') != docs[0].get('coreFingerprint') for d in docs):
        return False
    keys, maps = {}, {}
    for d in docs:
        keys.update(d.get('keys') or {})
        maps.update(d.get('maps') or {})
    doc = {'version': 2, 'coreFingerprint': docs[0]['coreFingerprint'], 'keys': keys, 'maps': maps, 'fileSha': file_sha(merged_out)}
    Path(keys_out).write_text(json.dumps(doc))
    return True


class KeyHistory:
    """按结果文件 SHA-256 认领的摘要账（JSON：{"entries": [摘要文档…]}，新的在后）。"""

    def __init__(self, path, version=2):
        # version：摘要文档的版本号（事件状态探针 2，troop 探针 1；tools-probe-deps2 起 troop_event_keys.json 共用这个类）
        self.path = Path(path)
        self.version = version

    def _load(self):
        try:
            entries = json.loads(self.path.read_text()).get('entries')
        except (OSError, ValueError, AttributeError):
            return []
        return [e for e in entries if isinstance(e, dict) and e.get('version') == self.version and isinstance(e.get('fileSha'), str)] \
            if isinstance(entries, list) else []

    def find(self, result_file):
        """result_file 这份结果的摘要文档；没有返回 None。"""
        try:
            sha = file_sha(result_file)
        except OSError:
            return None
        return next((e for e in reversed(self._load()) if e['fileSha'] == sha), None)

    def add(self, keys_file):
        try:
            doc = json.loads(Path(keys_file).read_text())
        except (OSError, ValueError):
            return False
        if doc.get('version') != self.version or not isinstance(doc.get('fileSha'), str):
            return False
        self._write([e for e in self._load() if e['fileSha'] != doc['fileSha']] + [doc])
        return True

    def absorb(self, other):
        """把另一本账（如主工作区的）里本账没有的条目并进来（新建工作树时带账，tools81）。"""
        mine = self._load()
        seen = {e['fileSha'] for e in mine}
        theirs = [e for e in KeyHistory(other, self.version)._load() if e['fileSha'] not in seen]
        if theirs:
            self._write(mine + theirs)   # 带来的当最新：新建工作树刚从主工作区拷来的结果正对应它
        return len(theirs)

    def _write(self, entries):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, temp = tempfile.mkstemp(dir=self.path.parent, prefix=self.path.name + '.')
        try:
            with os.fdopen(fd, 'w') as f:
                json.dump({'entries': entries[-KEEP:]}, f)
            os.replace(temp, self.path)
        finally:
            Path(temp).unlink(missing_ok=True)


def prepare_prev(env, history, prev_file, work):
    """有上次结果且账上认得它时，把 XIYOU_STATE_PREV／XIYOU_STATE_PREV_KEYS 写进 env；返回是否可增量。"""
    prev_file = Path(prev_file)
    doc = history.find(prev_file) if prev_file.is_file() else None
    if doc is None:
        env.pop('XIYOU_STATE_PREV', None)
        env['XIYOU_STATE_PREV_KEYS'] = str(Path(work) / 'no-prev.keys.json')   # 不存在：探针不去认输出旁边的旧摘要
        return False
    keys = Path(work) / 'prev.keys.json'
    keys.write_text(json.dumps(doc))
    env['XIYOU_STATE_PREV'], env['XIYOU_STATE_PREV_KEYS'] = str(prev_file), str(keys)
    return True


PROGRESS_SECS = 60   # 心跳间隔（秒）；环境变量 XIYOU_STATE_PROGRESS_SECS 可改，0＝不打（回到原来整段无输出）


class Progress:
    """长任务的心跳（tools83，哪吒 save2 交付单「留给下一单」）：整份重量的探针一跑近一小时，期间没有任何输出，
    会话被 idle 超时掐掉。这里开一条守护线程，每隔 interval 秒打一行「已 mm:ss，n/总数 段完成」，每段结束也打一行；
    用法：with Progress(shards) as prog: … prog.done(i)。interval≤0 时什么都不打。"""

    def __init__(self, shards, interval=None, out=None, label='事件状态探针'):
        if interval is None:
            try:
                interval = float(os.environ.get('XIYOU_STATE_PROGRESS_SECS', PROGRESS_SECS))
            except ValueError:
                interval = PROGRESS_SECS
        self.shards, self.interval, self.out, self.label = shards, interval, out, label
        self.finished, self.lock, self.stop, self.t0 = 0, threading.Lock(), threading.Event(), time.monotonic()

    def say(self, text):
        out = self.out or sys.stdout
        try:
            print('  [%s] %s' % (self.label, text), file=out, flush=True)
        except (OSError, ValueError):
            pass

    def line(self):
        secs = int(time.monotonic() - self.t0)
        return '已 %d 分 %02d 秒，%d/%d 段完成' % (secs // 60, secs % 60, self.finished, self.shards)

    def done(self, i=None):
        with self.lock:
            self.finished += 1
        if self.interval > 0:
            self.say(self.line() + ('（第 %d 段刚结束）' % (i + 1) if i is not None else ''))

    def _beat(self):
        while not self.stop.wait(self.interval):
            self.say(self.line() + '，还在跑')

    def __enter__(self):
        if self.interval > 0:
            self.say('开始，%d 段并行，每 %g 秒报一次进度' % (self.shards, self.interval))
            self.thread = threading.Thread(target=self._beat, daemon=True)
            self.thread.start()
        return self

    def __exit__(self, *exc):
        self.stop.set()
        # 等心跳线程真停：只 set 不 join 时，正在 say 的那一拍会在退出后才写出（总装三十二 11-07，满载下 6 != 5）
        if getattr(self, 'thread', None) is not None:
            self.thread.join(timeout=5)
        return False


def run_sharded(env, oracle, work, out, keys_out, shards, launch, progress=None):
    """分 shards 段跑 event_state_probe.cjs，结果拼到 out、摘要写 keys_out。
    launch(env, label) 跑 `node event_state_probe.cjs`（cwd=oracle）并返回 CompletedProcess；调用方决定怎么占槽。
    进度：默认每 60 秒（XIYOU_STATE_PROGRESS_SECS，0＝关）往标准输出打一行心跳，传 progress=Progress(…) 可换输出与间隔。
    每段的存档目录从 env['XIYOU_ORACLE_SANDBOX']（没有就 oracle/.sandbox）复制 save／macport。"""
    import concurrent.futures
    oracle, work, out, keys_out = Path(oracle), Path(work), Path(out), Path(keys_out)
    seed = Path(env.get('XIYOU_ORACLE_SANDBOX') or oracle / '.sandbox')
    work.mkdir(parents=True, exist_ok=True)
    if shards <= 1:
        e = dict(env, XIYOU_EVENT_OUT=str(out), XIYOU_STATE_KEYS_OUT=str(keys_out))
        e.pop('XIYOU_PROBE_SHARD', None)
        with progress or Progress(1) as prog:
            r = launch(e, 'event_state_probe')
            prog.done()
        return r

    def part(i):
        sub = work / ('state-shard-%d' % i)
        shutil.rmtree(sub, ignore_errors=True)
        sub.mkdir()
        for name in ['save', 'macport']:
            if (seed / name).is_dir():
                shutil.copytree(seed / name, sub / name)
        e = dict(env, XIYOU_ORACLE_SANDBOX=str(sub), XIYOU_PROBE_SHARD='%d/%d' % (i, shards), XIYOU_EVENT_OUT=str(sub / 'part.json'),
                 XIYOU_STATE_KEYS_OUT=str(sub / 'part.keys.json'))
        r = launch(e, 'event_state_probe %d/%d' % (i + 1, shards))
        prog.done(i)
        return r
    with progress or Progress(shards) as prog, concurrent.futures.ThreadPoolExecutor(shards) as pool:
        done = list(pool.map(part, range(shards)))
    text = ''.join('（第 %d/%d 段）\n%s%s' % (i + 1, shards, p.stdout, p.stderr) for i, p in enumerate(done))
    bad = [p for p in done if p.returncode]
    if bad:
        return subprocess.CompletedProcess(bad[0].args, bad[0].returncode, text, '')
    parts = [str(work / ('state-shard-%d' % i) / 'part.json') for i in range(shards)]
    out.parent.mkdir(parents=True, exist_ok=True)
    m = subprocess.run(['node', '-e', SHARD_MERGE_JS, str(out)] + parts, cwd=oracle, capture_output=True, text=True)
    if m.returncode == 0:
        if not merge_keys([work / ('state-shard-%d' % i) / 'part.keys.json' for i in range(shards)], out, keys_out):
            Path(keys_out).unlink(missing_ok=True)
    for i in range(shards):
        shutil.rmtree(work / ('state-shard-%d' % i), ignore_errors=True)
    return subprocess.CompletedProcess(m.args, m.returncode, text + m.stdout, m.stderr)
