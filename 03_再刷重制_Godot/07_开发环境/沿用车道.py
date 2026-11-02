#!/usr/bin/env python3
"""合并沿用车道测试结果（tools43，用户 2026-11-02）：检查.sh --affected 选出场景后，去掉车道交付时已测过、合并后又没被波及的场景。

用法：沿用车道.py <基准> --godot G --project P [--root 资料库] [--no-cloud] [--shell] 场景…
- 候选提交：git rev-list <基准>..HEAD（本次合并带进来的提交，新的在前）。
- 结果来源：
  本机：并行测试.py 在工作区干净时按提交记的 <共用状态目录>/commit_results/<提交>.json；Godot 版本、generated/ 摘要、超时上限
  都要与现在相同。
  云端：origin 上 refs/ci/results/<提交>/{affected,full,scenes} 里 passed 的 result.json（要有 sceneNames，tools43 起才写）；
  它测时用的产物快照（generatedCommit 的树）要与本工作区 generated/ 的快照树相同。--no-cloud 或 XIYOU_REUSE_CLOUD=0 不看云端。
- 判波及：对每个有记录的候选提交 C，用 选测.select(C, 不抽样) 算「C → 现在工作区」的差异会选哪些场景；结论整轮、或差异里有
  转换器／切片／测量接受单（generated 的来源）时这个 C 一个都不沿用。没被选中、且在 C 的记录里通过的场景沿用 C 的结果。
- 抽样族（选测对照.json 的 sample）：抽中的段没有可沿用结果、但同组另一段有时，按同组那段沿用（车道测的是同组别的段）。
- 拿不准就重跑：记录读不了、git 失败、云端连不上，都当没有记录，照跑。
- --shell：标准输出给 检查.sh 的 REUSE_KEEP=(要跑的) REUSE_COUNT=沿用数；说明打到标准错误，并写进 <git-dir>/xiyou_reuse_note.txt
  （合并车道.py 收尾提交的「沿用:」尾注读它）。
- 回退：XIYOU_REUSE_LANE=0 时原样输出全部场景（检查.sh 也不调本脚本）。
"""
import argparse
import fnmatch
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PROJECT_REL = '03_再刷重制_Godot/01_Godot工程'
GENERATED_REL = PROJECT_REL + '/modes/xiyou/generated'
RESULT_PREFIX = 'refs/ci/results/'
# 差异里有这些（generated/ 的来源），任何场景都不沿用：产物可能跟着变
GENERATED_INPUTS = ['03_再刷重制_Godot/03_转换工具/*', '03_再刷重制_Godot/04_验证/测量接受/*']
NOTE = 'xiyou_reuse_note.txt'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def git(root, *args, timeout=60):
    p = subprocess.run(['git', '-C', str(root), '-c', 'core.quotepath=false', *args], capture_output=True, text=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip())
    return p.stdout


def local_records(sdir, candidates, now):
    """{提交: (来源说明, {场景: True})}：本机按提交记的结果里，环境与现在相同、通过的场景。"""
    out = {}
    for sha in candidates:
        try:
            rec = json.loads((sdir / 'commit_results' / (sha + '.json')).read_text())
        except (OSError, ValueError):
            continue
        if not isinstance(rec, dict) or not isinstance(rec.get('scenes'), dict):
            continue
        if any(rec.get(k) != now[k] for k in ('godot', 'generated', 'timeout')):
            continue
        ok = {n for n, v in rec['scenes'].items() if v is True}
        if ok:
            out[sha] = ('本机 ' + rec.get('time', ''), ok)
    return out


def cloud_records(root, candidates, tree_of, my_tree):
    """{提交: (来源说明, 通过的场景)}：origin 上候选提交的云端结果。连不上、没有 sceneNames、产物树对不上的不算。
    tree_of(提交)：云端用的产物快照提交的树号（本机缓存库里没有就 None）；my_tree()：本工作区 generated/ 的快照树（只在用得上时才算）。"""
    out = {}
    try:
        refs = git(root, 'ls-remote', 'origin', RESULT_PREFIX + '*', timeout=30).split('\n')
    except (RuntimeError, subprocess.SubprocessError, OSError):
        return out
    want = set(candidates)
    for line in refs:
        if '\t' not in line:
            continue
        ref = line.split('\t')[1]
        sha = ref[len(RESULT_PREFIX):].split('/')[0]
        if sha not in want:
            continue
        try:
            git(root, 'fetch', '-q', '--no-tags', 'origin', '+%s:refs/xiyou-reuse/%s' % (ref, ref[len(RESULT_PREFIX):]), timeout=60)
            res = json.loads(git(root, 'cat-file', '-p', 'refs/xiyou-reuse/%s:result.json' % ref[len(RESULT_PREFIX):]))
        except (RuntimeError, subprocess.SubprocessError, OSError, ValueError):
            continue
        names = res.get('sceneNames')
        if not res.get('passed') or not isinstance(names, list):
            continue
        tree = tree_of(res.get('generatedCommit', ''))
        if not tree or tree != my_tree():
            continue
        got = out.setdefault(sha, ('云端 ' + res.get('runUrl', ''), set()))
        got[1].update(n for n in names if isinstance(n, str))
    return out


def plan(root, base, scenes, records, selector, table=None):
    """返回 (要跑的场景, {沿用的场景: (提交, 来源, 代替的场景)}, 说明行)。"""
    table = table or selector.TABLE
    notes, reused = [], {}
    usable = {}  # 场景 → (提交, 来源)：新的提交在前
    for sha, (src, ok) in records.items():
        try:
            sel = selector.select(root, sha, table, sample=False)
        except (RuntimeError, ValueError, KeyError, OSError) as e:
            notes.append('%s：判不出差异（%s），不沿用' % (sha[:9], e))
            continue
        gen = [f for f in sel['files'] if any(fnmatch.fnmatchcase(f, g) for g in GENERATED_INPUTS)]
        if sel['full']:
            notes.append('%s：到现在的差异按选测是整轮，不沿用' % sha[:9])
            continue
        if gen:
            notes.append('%s：之后改了产物来源（%s 等），不沿用' % (sha[:9], gen[0]))
            continue
        hit = set(sel['scenes'])
        for n in ok - hit:
            usable.setdefault(n, (sha, src))
    sample = selector.load_sample(table)
    all_scenes = sorted(p.name for p in (Path(root) / PROJECT_REL / 'tests').glob('*.tscn'))
    chunks = {s: c for _, c in selector.sample_chunks(all_scenes, sample) for s in c} if sample else {}
    keep = []
    for s in scenes:
        if s in usable:
            reused[s] = usable[s] + (s,)
            continue
        alt = next((m for m in chunks.get(s, []) if m in usable), None)
        if alt:
            reused[s] = usable[alt] + (alt,)
        else:
            keep.append(s)
    return keep, reused, notes


def summarize(reused):
    by = {}
    for s, (sha, src, alt) in sorted(reused.items()):
        by.setdefault((sha, src.split(' ')[0]), []).append(s[:-5] + ('（按同组 %s）' % alt[:-5] if alt != s else ''))
    return ['沿用 %s（%s）%d 个：%s' % (sha[:9], src, len(v), '、'.join(v)) for (sha, src), v in by.items()]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('base')
    ap.add_argument('scenes', nargs='*')
    ap.add_argument('--root', type=Path, default=ROOT)
    ap.add_argument('--godot', required=True)
    ap.add_argument('--project', required=True)
    ap.add_argument('--no-cloud', action='store_true')
    ap.add_argument('--shell', action='store_true')
    a = ap.parse_args(argv)
    scenes = [s if s.endswith('.tscn') else s + '.tscn' for s in a.scenes]
    note_file = None
    keep, reused, notes = scenes, {}, []
    try:
        note_file = Path(git(a.root, 'rev-parse', '--path-format=absolute', '--git-dir').strip()) / NOTE
        note_file.unlink(missing_ok=True)
        if os.environ.get('XIYOU_REUSE_LANE', '') != '0' and scenes:
            runner = load('runner', HERE / '并行测试.py')
            selector = load('selector', HERE / '选测.py')
            sdir = runner.state_dir(a.project)
            gen = Path(a.project) / 'modes/xiyou/generated'
            now = {'godot': runner.godot_version(a.godot), 'timeout': runner.TIMEOUT,
                   'generated': runner.walk_digest(gen, sdir, ()) if gen.is_dir() else ''}
            candidates = [x for x in git(a.root, 'rev-list', a.base + '..HEAD').split() if x]
            records = local_records(sdir, candidates, now)
            if not a.no_cloud and os.environ.get('XIYOU_REUSE_CLOUD', '') != '0' and gen.is_dir():
                cloud, memo = load('cloud', HERE / '云端选测.py'), {}

                def tree_of(commit):
                    if not commit:
                        return None
                    out = cloud.git('rev-parse', '--verify', '-q', commit + '^{tree}', git_dir=cloud.cache_repo(), check=False)
                    return out or None

                def my_tree():
                    if 'tree' not in memo:
                        try:
                            memo['tree'] = cloud.snapshot(gen, cloud.cache_repo())[0]
                        except Exception as e:  # noqa: BLE001 云端只是额外来源，算不出就不用
                            memo['tree'] = ''
                            notes.append('云端结果不看：产物快照算不出（%s）' % e)
                    return memo['tree']
                for sha, (src, ok) in cloud_records(a.root, candidates, tree_of, my_tree).items():
                    if sha in records:
                        records[sha] = (records[sha][0], records[sha][1] | ok)
                    else:
                        records[sha] = (src, ok)
            if records:
                keep, reused, more = plan(a.root, a.base, scenes, records, selector)
                notes += more
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as e:
        keep, reused = scenes, {}
        notes.append('沿用判断出错（%s），全部照跑' % e)
    lines = summarize(reused) + notes
    for line in lines:
        print('  · ' + line, file=sys.stderr if a.shell else sys.stdout)
    if reused:
        print('  · 车道结果沿用 %d 个、照跑 %d 个（XIYOU_REUSE_LANE=0 关）' % (len(reused), len(keep)), file=sys.stderr if a.shell else sys.stdout)
        if note_file:
            note_file.write_text('\n'.join(summarize(reused)) + '\n')
    if a.shell:
        print('REUSE_KEEP=(%s)' % ' '.join(keep))
        print('REUSE_COUNT=%d' % len(reused))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
