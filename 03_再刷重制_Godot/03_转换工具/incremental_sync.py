"""Conservative, per-probe input and output content validation. No timestamps as cache keys."""
import hashlib
import json
import os
import re
import sys
from pathlib import Path
import subprocess
import tempfile

VERSION = 1


def digest_files(paths, base):
    h = hashlib.sha256()
    for p in sorted(set(paths)):
        if p.is_file():
            h.update(str(p.relative_to(base)).encode() + b'\0')
            with p.open('rb') as f:
                for block in iter(lambda: f.read(1024 * 1024), b''):
                    h.update(block)
    return h.hexdigest()


def files(root):
    return [p for p in root.rglob('*') if p.is_file()] if root.is_dir() else []


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
        converter = digest_files(list(self.tools.glob('*.py')), self.tools)
        seeds = files(self.oracle / '.sandbox/save') + files(self.oracle / '.sandbox/macport')
        self.common = {'version': VERSION, 'source': self.source_sha, 'app': str(self.app.resolve()),
                       'generated': str(self.gen.resolve()), 'runtime': runtime, 'node': node, 'python': sys.version, 'platform': sys.platform,
                       'converter': converter, 'helpers': digest_files(helpers, self.oracle),
                       'seedFiles': digest_files(seeds, self.oracle),
                       'environment': {k: os.environ.get(k) for k in ('LANG', 'LC_ALL', 'TZ', 'NODE_OPTIONS', 'NODE_ENV', 'NODE_PATH')}}

    def key(self, command):
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
        text = ''.join(p.read_text(errors='replace') for p in dependencies)
        value = dict(self.common, command=command, dependencies=digest_files(dependencies, self.tools))
        # Current probes which consume the slice declare the same literal filename.
        # All shared helpers are also inspected, so moving a read into a helper remains safe.
        if 'xiyou_slice.json' in text:
            value['slice'] = hashlib.sha256((self.tools / 'xiyou_slice.json').read_bytes()).hexdigest()
        if 'XIYOU_GENERATED' in text or command[0] == 'event_probe.cjs':
            value['converted'] = digest_files(files(self.gen / 'maps') + files(self.gen / 'db') +
                                              [self.gen / 'manifest.json', self.gen / 'slice.json'], self.gen)
        return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

    def outputs(self, output_names):
        return {Path(p).name: hashlib.sha256((self.gen / 'oracle' / Path(p).name).read_bytes()).hexdigest()
                for p in output_names}

    def hit(self, command, output_names, key):
        if self.force:
            return False
        try:
            old = self.entries[command[0]]
            return old['key'] == key and old['outputs'] == self.outputs(output_names)
        except (KeyError, TypeError, OSError):
            return False

    def invalidate(self, commands):
        # A forced or invalidated probe must not fall back to an older successful cache
        # after this attempt fails, even if its input key happens to be unchanged.
        for command in commands:
            self.entries.pop(command[0], None)
        atomic_json(self.path, {'version': VERSION, 'probes': self.entries})

    def record(self, command, output_names, key):
        self.pending[command[0]] = {'key': key, 'command': command, 'names': output_names, 'outputs': self.outputs(output_names)}

    def commit(self):
        if digest_files(files(self.app), self.app) != self.source_sha:
            raise RuntimeError('同步期间冻结源改变，不发布增量缓存')
        current = ProbeCache(self.tools, self.app, self.gen)
        for name, entry in self.pending.items():
            # Commands may carry arguments; preserve them alongside the key.
            if current.common != self.common:
                raise RuntimeError('同步期间工具、运行环境或输入种子改变，不发布缓存')
            if current.key(entry['command']) != entry['key'] or current.outputs(entry['names']) != entry['outputs']:
                raise RuntimeError('同步期间探针输入或产物改变，不发布缓存：' + name)
        atomic_json(self.path, {'version': VERSION, 'probes': self.pending})
