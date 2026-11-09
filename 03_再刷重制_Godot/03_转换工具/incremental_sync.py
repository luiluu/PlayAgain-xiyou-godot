"""Conservative, per-probe input and output content validation. No timestamps as cache keys.

切片按字段算指纹：探针只读 SLICE.<字段> 时，只有这些字段变化才失效；写法认不出就退回整份切片。
SHARDS 里的慢探针再按单元（敌群／地图）复用：公共输入不变时只跑新增或变了的单元，
旧单元从上次产物原样取回，由 oracle_shard_merge.cjs 按全量顺序合并（与全量逐字节一致由回归和实测保证）。"""
import hashlib
import json
import os
import re
import sys
from pathlib import Path
import subprocess
import tempfile
import shutil

VERSION = 3
SLICE_NAME = 'xiyou_slice.json'
# 分片探针：field 是按单元拆开的切片字段；first 表示该字段第一项另有整体用途（算进公共键）
SHARDS = {
    'smart_ai_probe.cjs': {'kind': 'troops', 'field': 'troops', 'first': True},
    'slice_probe.cjs': {'kind': 'troops', 'field': 'troops'},
    'event_probe.cjs': {'kind': 'events', 'field': 'maps'},
}
# 合并与缓存本身的代码：改了就让分片探针整体重跑
TOOLING = ('incremental_sync.py', 'oracle_shard_merge.cjs')
# tools-probe-deps（XIYOU_PROBE_HELPER_DEPS 开着时）：incremental_sync.py 不再按整份内容进分片探针的键（改缓存键算法本身不改分片产物，
# 以前改这个文件就让 smart_ai／slice／event 三个分片探针整份重跑 2～4 小时），改按下面的修订号：
# 改了单元划分、单元核对、分片合并相关的逻辑（units／plan／_verified_units／_unit_digests／record 里的单元摘要）就把它加一。
SHARD_TOOLING_REVISION = 1
# 按探针实际用到的 helper 算键（tools-probe-deps，XIYOU_PROBE_HELPER_DEPS=0 退回旧的「mv_oracle 里任一 helper 改了全部探针重跑」）：
# 依赖＝探针文件起的静态 require 图（只认字面量本地路径）∪ 上次运行时记下的读过／require 过的 mv_oracle 文件（probe_dep_recorder.cjs）。
# 依赖链里出现认不出的写法（非字面量 require、用 __dirname／ORACLE_DIR 拼非字面量路径）又还没有运行时记录时，保守地带上全部 helper。
DYNAMIC_LOCAL = re.compile(r"\brequire\(\s*+(?!['\"][^'\"]*['\"]\s*\))"
                           r"|\bpath\.(?:join|resolve)\(\s*(?:__dirname|ORACLE_DIR)\s*,\s*+(?!['\"]\.\./)(?!['\"]\.sandbox['\"/])")
LITERAL_LOCAL_READ = re.compile(r"\bpath\.(?:join|resolve)\(\s*(?:__dirname|ORACLE_DIR)\s*,\s*((?:['\"][^'\"]+['\"]\s*,?\s*)+)\)")
RECORD_DIR = '.sandbox/probe_deps'
RECORDER = 'probe_dep_recorder.cjs'
# 审过的 helper 改动影响面（helper_change_scope.json，XIYOU_HELPER_SCOPE=0 不用）：某 helper 从 from 改到 to，声明只影响 rerun 里的探针；
# 其余探针算键时把这份 helper 当作还是 from（可连成链）。声明要交叉核查（同 GENERATED_SHARD_AUDITS），写错会让产物过期。
SCOPE_FILE = 'helper_change_scope.json'
EXCLUDED_PARTS = ('.sandbox', 'node_modules', 'real')


def helper_deps_on():
    return os.environ.get('XIYOU_PROBE_HELPER_DEPS', '1') != '0'


def helper_scope_on():
    return os.environ.get('XIYOU_HELPER_SCOPE', '1') != '0'
# 探针读的、不在 mv_oracle 里也不是转换产物的输入文件（相对 03_转换工具）：内容进该探针的键，改了只重跑它自己
# event_state_shards.py：同步里分段跑、拼回 event_state 结果的代码（tools81），改了要让它重跑
PROBE_INPUTS = {'event_state_probe.cjs': ('event_presets.json', 'event_state_shards.py')}
GENERATED_MARKERS = ('XIYOU_GENERATED', 'modes/xiyou/generated')
# 只有审视过「仅 maps 与 manifest.slice.commonEvents」的事件读取器能按地图分片。
# 新读取法先退回全产物键，不能因 SHARDS 优先而漏掉 converted。
# 审过的值有两种：整份文件的 SHA-256（旧写法，探针改任何一行都失效），或 'reads:' 加「读取面」的 SHA-256：
# 只取含文件读写、转换产物路径、require、切片／manifest、环境变量的行（READ_SURFACE），改别的逻辑不影响分片资格，
# 改了读法才失效、退回整轮（2026-10-25 哪吒：event_probe 10-24 两次只改运行逻辑，整份哈希失效后每次加地图都整轮跑 50 分钟）。
# 探针本身改了照样整体重跑一次（依赖指纹进键）；这里只决定之后能否按地图增量。
READ_SURFACE = re.compile(r'\bfs\b|\bGEN\b|XIYOU_GENERATED|modes/xiyou/generated|\brequire\s*\(|\bMANIFEST\b|\bSLICE\b'
                          r'|process\.env|readFile|readdir')
GENERATED_SHARD_AUDITS = {
    # a558a0ed（沙僧审过的整份 17f82a28…）与 c26755e8 的读取面相同（reads:46f0696a9f62e039）；
    # 唐僧 2026-10-25 只加了 XIYOU_EVENT_OUT 输出路径（写，不读产物），读取面改为下值，待 Codex 核
    'mv_oracle/event_probe.cjs': 'reads:b8ffbf2d6b5a3c38',
}


def read_surface(code):
    return hashlib.sha256('\n'.join(l.strip() for l in code.splitlines() if READ_SURFACE.search(l)).encode()).hexdigest()


def audit_ok(expected, data):
    """data 为文件字节；expected 为整份 SHA-256，或 'reads:' 加读取面 SHA-256（可只写前缀，至少 16 位）。"""
    if not expected:
        return False
    if expected.startswith('reads:'):
        want = expected[len('reads:'):]
        return len(want) >= 16 and read_surface(data.decode(errors='replace')).startswith(want)
    return expected == hashlib.sha256(data).hexdigest()


def digest_files(paths, base):
    h = hashlib.sha256()
    for p in sorted(set(paths)):
        if p.is_file():
            h.update(str(p.relative_to(base)).encode() + b'\0')
            with p.open('rb') as f:
                for block in iter(lambda: f.read(1024 * 1024), b''):
                    h.update(block)
    return h.hexdigest()


def sha_json(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def files(root):
    return [p for p in root.rglob('*') if p.is_file()] if root.is_dir() else []


def slice_fields(texts):
    """探针及其依赖读到的切片字段集合；有任何认不出的用法返回 None（按整份切片算）。"""
    fields = set()
    for text in texts:
        if SLICE_NAME not in text:
            if re.search(r'\bSLICE\b', text):
                return None
            continue
        if len(re.findall(r'xiyou_slice\.json', text)) != 1 or not re.search(
                r"const SLICE\s*=\s*JSON\.parse\(fs\.readFileSync\(path\.join\(__dirname,\s*'\.\./xiyou_slice\.json'\),\s*'utf8'\)\);", text):
            return None
        for m in re.finditer(r'\bSLICE\b', text):
            rest = text[m.end():]
            if text[max(0, m.start() - 6):m.start()] == 'const ' and re.match(r'\s*=', rest):
                continue
            f = re.match(r'\.([A-Za-z_]\w*)', rest)
            if not f:
                return None
            fields.add(f[1])
    return fields


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=path.name + '.')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(value, f, ensure_ascii=False, indent=2)
            f.write('\n')
        os.replace(temp, path)
    finally:
        Path(temp).unlink(missing_ok=True)


PROBE_DEPS_DIR = Path(RECORD_DIR).name


def carry_probe_deps(source, target):
    """探针运行时依赖记录（.sandbox/probe_deps/，tools-probe-deps）：目标没有的记录文件逐个复制过去，已有的不覆盖。
    recorded() 本来就按记录文件取并集，所以这就是「取并集」；不改目标已有的文件，车道／main 自己记下、算进现有缓存键的那份不变。
    不带的话车道里 slice_probe／shared_system_probe／event_state_probe 这类动态读取的探针没有记录、改带全部 helper，键对不上就重跑。
    source／target 是两边的 mv_oracle/.sandbox；返回复制的文件名。"""
    src, dst = Path(source) / PROBE_DEPS_DIR, Path(target) / PROBE_DEPS_DIR
    if not src.is_dir() or src.is_symlink() or dst.is_symlink():
        return []
    copied = []
    for f in sorted(src.glob('*.json')):
        out = dst / f.name
        if f.is_symlink() or not f.is_file() or out.exists():
            continue
        try:
            rows = json.loads(f.read_text()).get('files')
        except (OSError, ValueError, AttributeError):
            continue
        if not isinstance(rows, list):
            continue
        atomic_json(out, {'files': sorted({r for r in rows if isinstance(r, str)})})
        copied.append(f.name)
    return copied


def carry_cache(source, target):
    """只携带初始种子与已发布缓存；不覆盖车道现场，不跟随种子符号链接。"""
    source, target = Path(source), Path(target)
    # event_state_keys.json：事件状态探针的摘要账（event_state_shards.KeyHistory，tools81）；按结果文件摘要认领，带过去不会冒充
    names = ('save', 'macport', 'incremental-cache.json', 'event_state_keys.json')
    for base in (source, target):
        for q in (base / PROBE_DEPS_DIR, *(base / PROBE_DEPS_DIR).glob('*')):
            if q.is_symlink():
                raise RuntimeError('探针依赖记录含符号链接，拒绝携带：' + str(q))
    for base in (source, target):
        if base.is_symlink():
            raise RuntimeError('探针种子目录不能是符号链接：' + str(base))
    for name in names:
        for base in (source, target):
            p = base / name
            if p.is_symlink() or any(q.is_symlink() for q in p.rglob('*')):
                raise RuntimeError('探针种子／缓存含符号链接，拒绝携带：' + str(p))
    target.mkdir(parents=True, exist_ok=True)
    copied = []
    with tempfile.TemporaryDirectory(prefix='carry-', dir=target) as temp:
        for name in names:
            src, dst, stage = source / name, target / name, Path(temp) / name
            if dst.exists() or not src.exists():
                continue
            # 与 node_modules 一样优先 APFS 克隆；其它文件系统仍能安全地复制。
            result = subprocess.run(['cp', '-cR', str(src), str(stage)], capture_output=True)
            if result.returncode:
                if stage.is_dir():
                    shutil.rmtree(stage)
                else:
                    stage.unlink(missing_ok=True)
                shutil.copytree(src, stage) if src.is_dir() else shutil.copy2(src, stage)
            stage.rename(dst)
            copied.append(name)
    if carry_probe_deps(source, target):
        copied.append('probe_deps')
    keys_src, keys_dst = source / 'event_state_keys.json', target / 'event_state_keys.json'
    if 'event_state_keys.json' not in copied and keys_src.is_file() and keys_dst.is_file():
        from event_state_shards import KeyHistory
        if KeyHistory(keys_dst).absorb(keys_src):
            copied.append('event_state_keys-merged')
    # 车道已有缓存时也带上主工作区的单元摘要账（carried）：只在逐单元核对 generated 里的记录与账上相同、
    # 且输入键相同时才复用，不会让旧结果冒充新结果（木吒 2026-10-26）
    src_cache, dst_cache = source / 'incremental-cache.json', target / 'incremental-cache.json'
    if 'incremental-cache.json' not in copied and src_cache.is_file() and dst_cache.is_file():
        try:
            src, dst = json.loads(src_cache.read_text()), json.loads(dst_cache.read_text())
        except (OSError, ValueError):
            return copied
        if isinstance(src, dict) and isinstance(dst, dict) and src.get('version') == VERSION == dst.get('version'):
            dst['carried'] = unit_ledger(src)
            atomic_json(dst_cache, dst)
            copied.append('carried-ledger')
    return copied


def unit_ledger(cache):
    """缓存文件里带单元摘要的条目（已发布的 probes 与随产物写入的 ledger，后者更新）。"""
    out = {}
    for part in ('probes', 'ledger'):
        for name, entry in (cache.get(part) or {}).items():
            if isinstance(entry, dict) and isinstance(entry.get('unitOutputs'), dict):
                out[name] = entry
    return out


class ProbeCache:
    def __init__(self, tools, app, generated, force=False):
        self.tools, self.app, self.gen = [Path(p).resolve() for p in (tools, app, generated)]
        self.oracle = self.tools / 'mv_oracle'
        self.path = self.oracle / '.sandbox/incremental-cache.json'
        self.force = force
        self.cache_issue = None
        # ledger：每次产物复制进 generated 就记下那份产物的单元摘要（失败、作废都不删，因为它描述的正是 generated 里现有的内容）；
        # carried：新建工作树.sh 从主工作区带来的同类账。两者只在 plan 里经逐单元核对后使用。
        self.ledger, self.carried = {}, {}
        try:
            old = json.loads(self.path.read_text())
            self.entries = old['probes'] if old['version'] == VERSION else {}
            if old['version'] == VERSION:
                self.ledger = {k: v for k, v in (old.get('ledger') or {}).items() if isinstance(v, dict)}
                self.carried = {k: v for k, v in (old.get('carried') or {}).items() if isinstance(v, dict)}
            if old['version'] != VERSION:
                self.cache_issue = {'kind': 'cache-version', 'previous': old['version'], 'current': VERSION}
            if not isinstance(self.entries, dict):
                self.entries = {}
                self.cache_issue = {'kind': 'cache-invalid'}
        except FileNotFoundError:
            self.entries = {}
            self.cache_issue = {'kind': 'cache-missing'}
        except (OSError, ValueError, KeyError, TypeError):
            self.entries = {}
            self.cache_issue = {'kind': 'cache-invalid'}
        self.pending = {}
        self.details, self.misses, self.reuse = {}, {}, {}
        self.source_sha = digest_files(files(self.app), self.app)
        helpers = [p for p in files(self.oracle) if not any(x in p.relative_to(self.oracle).parts for x in EXCLUDED_PARTS)  # real/：无头 Chrome 量具，探针不 require，不进公共键
                   and p.suffix in ('.cjs', '.js', '.json') and not p.name.endswith('_probe.cjs')]
        self.helpers = helpers
        self.helper_deps = helper_deps_on()
        self.scope = self._load_scope() if self.helper_deps and helper_scope_on() else []
        runtime = digest_files(files(self.oracle / 'node_modules'), self.oracle)
        node = subprocess.run(['node', '--version'], capture_output=True, text=True, check=True).stdout.strip()
        seeds = files(self.oracle / '.sandbox/save') + files(self.oracle / '.sandbox/macport')
        # 转换器（*.py）不进公共键：探针不执行 Python，读转换产物的探针另按产物内容算键（converted／地图单元）
        self.common = {'version': VERSION, 'source': self.source_sha, 'app': str(self.app.resolve()),
                       'runtime': runtime, 'node': node, 'python': sys.version, 'platform': sys.platform,
                       **({} if self.helper_deps else {'helpers': digest_files(helpers, self.oracle)}),
                       'seedFiles': digest_files(seeds, self.oracle),
                       'environment': {k: os.environ.get(k) for k in ('LANG', 'LC_ALL', 'TZ', 'NODE_OPTIONS', 'NODE_ENV', 'NODE_PATH')}}

    def _slice(self):
        return json.loads((self.tools / SLICE_NAME).read_text())

    def _closure(self, roots, dynamic=None):
        dependencies, queue = set(), list(roots)
        while queue:
            p = queue.pop()
            if p in dependencies:
                continue
            dependencies.add(p)
            text = p.read_text(errors='replace')
            for match in re.finditer(r"require\(\s*['\"](\.[^'\"]+)['\"]\s*\)", text):
                target = p.parent / match[1]
                candidates = [target, Path(str(target) + '.cjs'), Path(str(target) + '.js'), Path(str(target) + '.json'), target / 'index.js']
                resolved = next((q.resolve() for q in candidates if q.is_file()), None)
                if resolved is None or not resolved.is_relative_to(self.tools.resolve()):
                    raise RuntimeError('无法确认探针依赖：' + match[1])
                queue.append(resolved)
            if dynamic is not None and p.suffix in ('.cjs', '.js'):
                code = '\n'.join(l for l in text.splitlines() if not l.lstrip().startswith('//'))
                for match in LITERAL_LOCAL_READ.finditer(code):
                    parts = re.findall(r"['\"]([^'\"]+)['\"]", match[1])
                    target = p.parent.joinpath(*parts).resolve()
                    if target.is_file() and target.is_relative_to(self.oracle.resolve()) and not self._excluded(target):
                        queue.append(target)
                if DYNAMIC_LOCAL.search(code):
                    dynamic.add(p.relative_to(self.tools).as_posix() if p.is_relative_to(self.tools) else str(p))
        return dependencies

    def _excluded(self, path):
        try:
            return any(x in path.resolve().relative_to(self.oracle.resolve()).parts for x in EXCLUDED_PARTS)
        except ValueError:
            return True

    def _record_files(self, name):
        d = self.oracle / RECORD_DIR
        return sorted(d.glob(name + '.*.json')) + ([d / (name + '.json')] if (d / (name + '.json')).is_file() else [])

    def recorded(self, name):
        """上次运行时记下的 mv_oracle 内文件（相对 mv_oracle）；没有记录返回 None。多段／多次运行取并集（只会多不会少）。"""
        out, seen = set(), False
        for f in self._record_files(name):
            try:
                rows = json.loads(f.read_text()).get('files')
            except (OSError, ValueError, AttributeError):
                continue
            if isinstance(rows, list):
                seen = True
                out.update(r for r in rows if isinstance(r, str))
        return out if seen else None

    def compact_record(self, name):
        """把各进程的记录并成一份 <探针>.json（并集），删掉逐进程的文件。"""
        rows = self.recorded(name)
        if rows is None:
            return
        atomic_json(self.oracle / RECORD_DIR / (name + '.json'), {'files': sorted(rows)})
        for f in (self.oracle / RECORD_DIR).glob(name + '.*.json'):
            f.unlink(missing_ok=True)

    def _dependencies(self, command):
        path = self.oracle / command[0]
        if not self.helper_deps:
            dependencies = self._closure([path, *self.helpers])
            return dependencies, [p.read_text(errors='replace') for p in sorted(dependencies)]
        dynamic = set()
        dependencies = self._closure([path], dynamic)
        rows = self.recorded(command[0])
        extra = []
        if rows is not None:
            for r in rows:
                q = (self.oracle / r).resolve()
                if q.is_file() and q.is_relative_to(self.oracle.resolve()) and not self._excluded(q) and q not in dependencies:
                    extra.append(q)
        elif dynamic:
            extra = [q.resolve() for q in self.helpers]
        if extra:
            dependencies |= self._closure(extra, set())
        self.dynamic = getattr(self, 'dynamic', {})
        self.dynamic[command[0]] = {'files': sorted(dynamic), 'recorded': rows is not None}
        return dependencies, [p.read_text(errors='replace') for p in sorted(dependencies)]

    def _load_scope(self):
        p = self.tools / SCOPE_FILE
        try:
            rows = json.loads(p.read_text()).get('changes') or []
        except FileNotFoundError:
            return []
        except (OSError, ValueError, AttributeError) as error:
            raise RuntimeError('%s 读不了：%s' % (SCOPE_FILE, error))
        for r in rows:
            if not (isinstance(r, dict) and all(isinstance(r.get(k), str) and r.get(k) for k in ('file', 'from', 'to', 'why'))
                    and isinstance(r.get('rerun'), list) and len(r['from']) == 64 and len(r['to']) == 64):
                raise RuntimeError('%s 的条目缺 file／from／to（整份 SHA-256）／rerun／why：%r' % (SCOPE_FILE, r))
        return rows

    def _scoped_sha(self, probe, rel, sha):
        """rel 相对 03_转换工具。声明过「从 from 改到 to 只影响 rerun」且本探针不在 rerun 里时，把 to 当作 from（沿链往回找）。"""
        seen = set()
        while sha not in seen:
            seen.add(sha)
            row = next((r for r in self.scope if r['file'] == rel and r['to'] == sha and probe not in r['rerun']), None)
            if row is None:
                break
            sha = row['from']
        return sha

    def _dependency_details(self, probe, paths):
        out = {}
        for p in sorted(set(paths)):
            if p.is_file():
                rel = p.relative_to(self.tools).as_posix()
                out[rel] = self._scoped_sha(probe, rel, hashlib.sha256(p.read_bytes()).hexdigest())
        return out

    def _tooling(self, spec_on):
        if not self.helper_deps:
            paths = [self.tools / n for n in TOOLING]
            return digest_files(paths, self.tools), self._file_details(paths, self.tools)
        detail = self._file_details([self.tools / n for n in TOOLING if n != 'incremental_sync.py'], self.tools)
        detail['incremental_sync.py'] = 'rev:%d' % SHARD_TOOLING_REVISION
        return sha_json(detail), detail

    def _compatible(self, old, current):
        """旧条目的输入明细与本次相容（本次的依赖是旧依赖的子集且逐份相同，其余输入相同）：
        换成按实际依赖算键、或某个本探针没用到的 helper 改了时，旧条目换上新键接着用，不整份重跑。"""
        if not (isinstance(old, dict) and isinstance(current, dict)):
            return False
        oc, cc = old.get('common'), current.get('common')
        if not (isinstance(oc, dict) and isinstance(cc, dict)) or any(oc.get(k) != v for k, v in cc.items()):
            return False
        od, cd = old.get('dependencies'), current.get('dependencies')
        if not (isinstance(od, dict) and isinstance(cd, dict)) or any(od.get(k) != v for k, v in cd.items()):
            return False
        for field in set(old) | set(current):
            if field in ('common', 'dependencies'):
                continue
            a, b = old.get(field), current.get(field)
            if field == 'tooling' and isinstance(a, dict) and isinstance(b, dict):
                a = dict(a)
                if not str(a.get('incremental_sync.py', 'rev:')).startswith('rev:'):
                    a['incremental_sync.py'] = 'rev:1'  # 改用修订号以前的旧条目算作修订 1
            if a != b:
                return False
        return True

    def upgrade(self, command, key):
        """各本账里本探针的旧条目，输入明细与本次相容的，换成本次的键（只改内存；发布照旧经 record／commit）。"""
        if not self.helper_deps or self.force:
            return []
        name, current, done = command[0], self.details.get(command[0]), []
        for label, book in (('entry', self.entries), ('ledger', self.ledger), ('carried', self.carried)):
            c = book.get(name)
            if isinstance(c, dict) and c.get('key') != key and self._compatible(c.get('inputs'), current):
                c['key'] = key
                c['inputs'] = current
                done.append(label)
        if done:
            self.upgraded = getattr(self, 'upgraded', {})
            self.upgraded[name] = done
        return done

    def shard(self, command):
        """分片规则；切片字段认不出时不分片（整体按键复用或重跑）。"""
        spec = SHARDS.get(command[0])
        if spec is None:
            return None
        dependencies, texts = self._dependencies(command)
        fields = slice_fields(texts)
        if fields is None or spec['field'] not in fields:
            return None
        for dependency in dependencies:
            code = dependency.read_text(errors='replace')
            if any(marker in code for marker in GENERATED_MARKERS):
                rel = dependency.relative_to(self.tools).as_posix()
                if not audit_ok(GENERATED_SHARD_AUDITS.get(rel), dependency.read_bytes()):
                    # 记下原因，同步日志打 SHARD_OFF：之前失效时一声不响地整轮跑
                    self.shard_issues = getattr(self, 'shard_issues', {})
                    self.shard_issues[command[0]] = {'file': rel, 'reads': read_surface(code)[:16]}
                    return None
        return spec

    def key(self, command):
        dependencies, texts = self._dependencies(command)
        text = ''.join(texts)
        if self.helper_deps:
            deps = self._dependency_details(command[0], dependencies)
            value = dict(self.common, command=command, dependencies=sha_json(deps))
        else:
            deps = self._file_details(dependencies, self.tools)
            value = dict(self.common, command=command, dependencies=digest_files(dependencies, self.tools))
        detail = {'common': {k: sha_json(v) for k, v in self.common.items()},
                  'dependencies': deps, 'command': command}
        detail['common']['environment'] = {k: sha_json(v) for k, v in self.common['environment'].items()}
        spec = self.shard(command)
        if SLICE_NAME in text:
            fields = slice_fields(texts)
            if fields is None:
                value['slice'] = hashlib.sha256((self.tools / SLICE_NAME).read_bytes()).hexdigest()
                detail['slice'] = value['slice']
            else:
                data = self._slice()
                kept = sorted(fields - {spec['field']}) if spec else sorted(fields)
                value['sliceFields'] = sha_json({f: data.get(f) for f in kept})
                detail['sliceFields'] = {f: sha_json(data.get(f)) for f in kept}
                if spec and spec.get('first'):
                    value['sliceFirst'] = (data.get(spec['field']) or [None])[0]
                    detail['sliceFirst'] = sha_json(value['sliceFirst'])
        if spec:
            value['tooling'], detail['tooling'] = self._tooling(True)
        elif any(m in text for m in GENERATED_MARKERS) or command[0] == 'event_probe.cjs':
            converted = files(self.gen / 'maps') + files(self.gen / 'db') + [self.gen / 'manifest.json', self.gen / 'slice.json']
            value['converted'] = digest_files(converted, self.gen)
            detail['converted'] = self._file_details(converted, self.gen)
        extra = [self.tools / n for n in PROBE_INPUTS.get(command[0], ())]
        if extra:
            value['extraInputs'] = digest_files(extra, self.tools)
            detail['extraInputs'] = self._file_details(extra, self.tools)
        self.details[command[0]] = detail
        return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

    @staticmethod
    def _file_details(paths, base):
        return {p.relative_to(base).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(set(paths)) if p.is_file()}

    def explain(self, command, output_names, key, units=None):
        """未命中原因只写字段名和相对文件名，不泄露环境变量或种子内容。"""
        if self.force:
            return [{'kind': 'forced-full'}]
        old = self.entries.get(command[0])
        if not isinstance(old, dict):
            return [self.cache_issue or {'kind': 'probe-not-cached'}]
        why = []
        if old.get('names') != output_names:
            why.append({'kind': 'output-declaration'})
        if old.get('key') != key:
            current = self.details.get(command[0], {})
            previous = old.get('inputs') if isinstance(old.get('inputs'), dict) else {}
            old_common = previous.get('common') if isinstance(previous.get('common'), dict) else {}
            for field in sorted(set(current.get('common', {})) | set(old_common)):
                a, b = old_common.get(field), current.get('common', {}).get(field)
                if a != b:
                    item = {'kind': 'common-input', 'field': field}
                    if field == 'environment' and isinstance(a, dict) and isinstance(b, dict):
                        item['names'] = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
                    why.append(item)
            for field in sorted((set(current) | set(previous)) - {'common'}):
                a, b = previous.get(field), current.get(field)
                if a != b:
                    item = {'kind': field}
                    if isinstance(a, dict) and isinstance(b, dict):
                        item['names'] = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
                    why.append(item)
            if not why:
                why.append({'kind': 'input-fingerprint'})
        expected = old.get('outputs') if isinstance(old.get('outputs'), dict) else {}
        changed, unavailable = [], []
        for p in output_names:
            name = Path(p).name
            try:
                actual = hashlib.sha256((self.gen / 'oracle' / name).read_bytes()).hexdigest()
            except OSError as error:
                actual = None
                unavailable.append({'name': name, 'error': type(error).__name__})
            if actual is None or actual != expected.get(name):
                changed.append(name)
        if changed:
            item = {'kind': 'output-sha', 'names': changed}
            if unavailable:
                item['unavailable'] = unavailable
            why.append(item)
        previous = old.get('units')
        if units != previous or isinstance(units, dict) and isinstance(previous, dict) and list(units) != list(previous):
            item = {'kind': 'units'}
            if isinstance(units, dict) and isinstance(previous, dict):
                item.update(added=[u for u in units if u not in previous], removed=[u for u in previous if u not in units],
                            changed=[u for u in units if u in previous and units[u] != previous[u]],
                            reordered=[u for u in units if u in previous] != [u for u in previous if u in units])
            why.append(item)
        return why

    def units(self, command):
        """分片探针的当前单元 → 单元键；全量顺序即字典顺序。非分片探针返回 None。"""
        spec = self.shard(command)
        if spec is None:
            return None
        data = self._slice()
        if spec['kind'] == 'troops':
            return {str(t): 'troop' for t in data.get('troops', [])}
        out = {}
        for mid in data.get('maps', []):
            p = self.gen / 'maps' / ('Map%03d.json' % int(mid))
            out['m%d' % int(mid)] = hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else 'missing'
        manifest = json.loads((self.gen / 'manifest.json').read_text())
        for ce in manifest.get('slice', {}).get('commonEvents', []):
            out['ce%d' % int(ce)] = 'common'
        return out

    def outputs(self, output_names):
        return {Path(p).name: hashlib.sha256((self.gen / 'oracle' / Path(p).name).read_bytes()).hexdigest()
                for p in output_names}

    def hit(self, command, output_names, key, units=None):
        return self.plan(command, output_names, key, units) == []

    def plan(self, command, output_names, key, units=None):
        """None＝整体重跑；[]＝整体复用；单元列表＝只跑这些单元再合并。
        分片探针只删了或换了顺序时返回 ['']：不跑探针，只按新顺序合并。"""
        name = command[0]
        if name not in self.details:
            self.key(command)
        self.upgrade(command, key)
        self.misses[name] = self.explain(command, output_names, key, units)
        self.reuse.pop(name, None)
        if self.force:
            return None
        if all(reason['kind'] == 'units' for reason in self.misses[name]):
            try:
                old = self.entries[name]
                if units is None:
                    return [] if old.get('units') is None else None
                previous = old.get('units')
                if isinstance(previous, dict):
                    changed = [u for u, v in units.items() if previous.get(u) != v]
                    if not changed and list(previous) == list(units):
                        return []
                    return changed or ['']
            except (KeyError, TypeError, OSError):
                pass
        return self._verified_units(command, output_names, key, units)

    def _verified_units(self, command, output_names, key, units):
        """产物 SHA 对不上（generated 被主工作区的产物刷新、上次失败后缓存作废、车道还没有自己的条目）时，逐单元核对：
        某个单元可复用，当且仅当某条账（本条目、ledger、carried）的输入键与本次完全相同、该单元的单元键相同，
        且 generated 现有产物里该单元的全部记录与账上记下的摘要逐份相同——也就是现有记录正是这组输入测出来的那份。
        其余单元重跑，再由 oracle_shard_merge.cjs 按全量顺序合并；什么都对不上就整轮（None）。"""
        name = command[0]
        spec = self.shard(command)
        if spec is None or not isinstance(units, dict) or not units:
            return None
        names = [Path(p).name for p in output_names]
        sources = []
        for label, book in (('entry', self.entries), ('ledger', self.ledger), ('carried', self.carried)):
            c = book.get(name)
            if (isinstance(c, dict) and c.get('key') == key and c.get('names') == output_names and isinstance(c.get('units'), dict)
                    and isinstance(c.get('unitOutputs'), dict) and all(isinstance(c['unitOutputs'].get(n), dict) for n in names)):
                sources.append((label, c))
        if not sources:
            return None
        current = self._unit_digests(spec['kind'], output_names)
        if current is None:
            return None

        def unit_ok(c, u):
            return c['units'].get(u) == units[u] and all(
                current[n]['units'].get(u) == (c['unitOutputs'][n].get('units') or {}).get(u) for n in names)

        todo = [u for u in units if not any(unit_ok(c, u) for _, c in sources)]
        rest_ok = any(all(current[n]['rest'] == c['unitOutputs'][n].get('rest') for n in names) for _, c in sources)
        if len(todo) == len(units):
            return None
        # 一个单元都不用跑时，非分片部分（来源身份、开局设定等）取自现有产物，必须也对得上；对不上就重跑一个单元，让它取自新产物
        if not todo and not rest_ok:
            todo = [next(iter(units))]
        self.reuse[name] = {'kind': 'unit-verified', 'reused': len(units) - len(todo), 'run': len(todo),
                            'sources': [label for label, _ in sources]}
        self.misses[name].append(self.reuse[name])
        return todo or ['']

    def _unit_digests(self, kind, output_names):
        """generated/oracle 里各产物的单元摘要（oracle_shard_merge.cjs --digest，与合并同一套分组）；读不了返回 None。"""
        paths = [self.gen / 'oracle' / Path(p).name for p in output_names]
        if not all(p.is_file() for p in paths):
            return None
        # 与同步合并时一样用本模块旁边的 oracle_shard_merge.cjs
        p = subprocess.run(['node', str(Path(__file__).resolve().parent / 'oracle_shard_merge.cjs'), '--digest', kind, *map(str, paths)],
                           capture_output=True, text=True)
        lines = p.stdout.splitlines()
        if p.returncode or len(lines) != len(paths):
            return None
        try:
            out = {path.name: json.loads(line) for path, line in zip(paths, lines)}
        except ValueError:
            return None
        if not all(isinstance(v, dict) and isinstance(v.get('units'), dict) and isinstance(v.get('rest'), str) for v in out.values()):
            return None
        return out

    def _save(self):
        atomic_json(self.path, {'version': VERSION, 'probes': self.entries, 'ledger': self.ledger, 'carried': self.carried})

    def invalidate(self, commands):
        # A forced or invalidated probe must not fall back to an older successful cache
        # after this attempt fails, even if its input key happens to be unchanged.
        # （ledger 不删：它只描述 generated 里现有的产物，复用前还要逐单元核对内容。）
        for command in commands:
            self.entries.pop(command[0], None)
        self._save()

    def record(self, command, output_names, key, units=None):
        """产物复制进 generated 之后调用（命中的探针也调）。分片探针另记单元摘要，并立刻写进 ledger。"""
        if self.helper_deps:
            # 这次运行可能记下了新的运行时依赖：并成一份后按它重算键，与 commit 时重算的一致
            self.compact_record(command[0])
            key = self.key(command)
        entry = {'key': key, 'command': command, 'names': output_names, 'outputs': self.outputs(output_names),
                 'units': units, 'inputs': self.details.get(command[0], {})}
        spec = self.shard(command)
        if spec is not None and isinstance(units, dict):
            old = self.entries.get(command[0]) or {}
            if old.get('outputs') == entry['outputs'] and isinstance(old.get('unitOutputs'), dict):
                entry['unitOutputs'] = old['unitOutputs']
            else:
                entry['unitOutputs'] = self._unit_digests(spec['kind'], output_names)
            if entry['unitOutputs'] is None:
                del entry['unitOutputs']
            else:
                self.ledger[command[0]] = entry
                self._save()
        self.pending[command[0]] = entry

    def commit(self):
        if digest_files(files(self.app), self.app) != self.source_sha:
            raise RuntimeError('同步期间冻结源改变，不发布增量缓存')
        current = ProbeCache(self.tools, self.app, self.gen)
        for name, entry in self.pending.items():
            # Commands may carry arguments; preserve them alongside the key.
            if current.common != self.common:
                raise RuntimeError('同步期间工具、运行环境或输入种子改变，不发布缓存')
            if (current.key(entry['command']) != entry['key'] or current.outputs(entry['names']) != entry['outputs']
                    or current.units(entry['command']) != entry.get('units')):
                raise RuntimeError('同步期间探针输入或产物改变，不发布缓存：' + name)
        atomic_json(self.path, {'version': VERSION, 'probes': self.pending, 'ledger': self.ledger, 'carried': self.carried})


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description='携带探针缓存与起始种子（不会覆盖已有车道现场）')
    ap.add_argument('--carry-cache', nargs=2, metavar=('SOURCE', 'TARGET'), required=True)
    args = ap.parse_args()
    print(json.dumps({'carried': carry_cache(*args.carry_cache)}, ensure_ascii=False))
