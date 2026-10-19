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

VERSION = 2
SLICE_NAME = 'xiyou_slice.json'
# 分片探针：field 是按单元拆开的切片字段；first 表示该字段第一项另有整体用途（算进公共键）
SHARDS = {
    'smart_ai_probe.cjs': {'kind': 'troops', 'field': 'troops', 'first': True},
    'slice_probe.cjs': {'kind': 'troops', 'field': 'troops'},
    'event_probe.cjs': {'kind': 'events', 'field': 'maps'},
}
# 合并与缓存本身的代码：改了就让分片探针整体重跑
TOOLING = ('incremental_sync.py', 'oracle_shard_merge.cjs')
GENERATED_MARKERS = ('XIYOU_GENERATED', 'modes/xiyou/generated')


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


class ProbeCache:
    def __init__(self, tools, app, generated, force=False):
        self.tools, self.app, self.gen = [Path(p).resolve() for p in (tools, app, generated)]
        self.oracle = self.tools / 'mv_oracle'
        self.path = self.oracle / '.sandbox/incremental-cache.json'
        self.force = force
        try:
            old = json.loads(self.path.read_text())
            self.entries = old['probes'] if old['version'] == VERSION else {}
            if not isinstance(self.entries, dict):
                self.entries = {}
        except (OSError, ValueError, KeyError, TypeError):
            self.entries = {}
        self.pending = {}
        self.source_sha = digest_files(files(self.app), self.app)
        helpers = [p for p in files(self.oracle) if not any(x in p.relative_to(self.oracle).parts for x in ('.sandbox', 'node_modules'))
                   and p.suffix in ('.cjs', '.js', '.json') and not p.name.endswith('_probe.cjs')]
        self.helpers = helpers
        runtime = digest_files(files(self.oracle / 'node_modules'), self.oracle)
        node = subprocess.run(['node', '--version'], capture_output=True, text=True, check=True).stdout.strip()
        seeds = files(self.oracle / '.sandbox/save') + files(self.oracle / '.sandbox/macport')
        # 转换器（*.py）不进公共键：探针不执行 Python，读转换产物的探针另按产物内容算键（converted／地图单元）
        self.common = {'version': VERSION, 'source': self.source_sha, 'app': str(self.app.resolve()),
                       'generated': str(self.gen.resolve()), 'runtime': runtime, 'node': node, 'python': sys.version, 'platform': sys.platform,
                       'helpers': digest_files(helpers, self.oracle),
                       'seedFiles': digest_files(seeds, self.oracle),
                       'environment': {k: os.environ.get(k) for k in ('LANG', 'LC_ALL', 'TZ', 'NODE_OPTIONS', 'NODE_ENV', 'NODE_PATH')}}

    def _slice(self):
        return json.loads((self.tools / SLICE_NAME).read_text())

    def _dependencies(self, command):
        path = self.oracle / command[0]
        dependencies, queue = set(), [path, *self.helpers]
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
        return dependencies, [p.read_text(errors='replace') for p in sorted(dependencies)]

    def shard(self, command):
        """分片规则；切片字段认不出时不分片（整体按键复用或重跑）。"""
        spec = SHARDS.get(command[0])
        if spec is None:
            return None
        _, texts = self._dependencies(command)
        fields = slice_fields(texts)
        if fields is None or spec['field'] not in fields:
            return None
        return spec

    def key(self, command):
        dependencies, texts = self._dependencies(command)
        text = ''.join(texts)
        value = dict(self.common, command=command, dependencies=digest_files(dependencies, self.tools))
        spec = self.shard(command)
        if SLICE_NAME in text:
            fields = slice_fields(texts)
            if fields is None:
                value['slice'] = hashlib.sha256((self.tools / SLICE_NAME).read_bytes()).hexdigest()
            else:
                data = self._slice()
                kept = sorted(fields - {spec['field']}) if spec else sorted(fields)
                value['sliceFields'] = sha_json({f: data.get(f) for f in kept})
                if spec and spec.get('first'):
                    value['sliceFirst'] = (data.get(spec['field']) or [None])[0]
        if spec:
            value['tooling'] = digest_files([self.tools / n for n in TOOLING], self.tools)
        elif any(m in text for m in GENERATED_MARKERS) or command[0] == 'event_probe.cjs':
            value['converted'] = digest_files(files(self.gen / 'maps') + files(self.gen / 'db') +
                                              [self.gen / 'manifest.json', self.gen / 'slice.json'], self.gen)
        return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

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
        if self.force:
            return None
        try:
            old = self.entries[command[0]]
            if old['key'] != key or old['outputs'] != self.outputs(output_names):
                return None
            if units is None:
                return [] if old.get('units') is None else None
            previous = old.get('units')
            if not isinstance(previous, dict):
                return None
            changed = [u for u, v in units.items() if previous.get(u) != v]
            if not changed and list(previous) == list(units):
                return []
            return changed or ['']
        except (KeyError, TypeError, OSError):
            return None

    def invalidate(self, commands):
        # A forced or invalidated probe must not fall back to an older successful cache
        # after this attempt fails, even if its input key happens to be unchanged.
        for command in commands:
            self.entries.pop(command[0], None)
        atomic_json(self.path, {'version': VERSION, 'probes': self.entries})

    def record(self, command, output_names, key, units=None):
        self.pending[command[0]] = {'key': key, 'command': command, 'names': output_names, 'outputs': self.outputs(output_names),
                                    'units': units}

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
        atomic_json(self.path, {'version': VERSION, 'probes': self.pending})
