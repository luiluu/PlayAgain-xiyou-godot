#!/usr/bin/env python3
"""云端选测：Godot 测试场景放到 GitHub Actions 上分片并行跑（用户 2026-10-30 同意把选测移出 Mac）。

工作流是 .github/workflows/godot-tests.yml（名为「云端选测」），说明见 云端测试.md「GitHub Actions 分片并行」。本脚本两头都用：

Mac 端（总装、车道）
  upload [--branch 名]          把本工作树的转换产物（modes/xiyou/generated，不入 Git）做成快照，
                                推到 GitHub 的 refs/ci/generated/<分支>；内容与上次相同就不推。
  run [--full] [--branch 名]    先 upload，再把 HEAD 推到 ci/<分支>（--full 时 ci-full/<分支>），触发云端选测；
                                基准是 GitHub 上的 main（取分叉点）。打印要等的提交号。
  wait [提交] [--timeout 秒]    等云端结果 refs/ci/results/<提交>/<affected|full>，打印汇总。
                                通过返回 0，失败 1，超时 124。
CI 端（工作流调用，本机一般不用）
  godot / fetch / plan / shard / report

为什么这样传：转换产物 1.4 GB、几份 slice 单个超过 GitHub 100 MB 的上限，又不能进普通分支。快照按文件存成
Git 对象（大文件切成 CHUNK 大小的段），放在 refs/ci/ 下：clone 和普通 fetch 只取 refs/heads 与 tags，
不会把它拉到任何工作区；Git 按内容去重，下次只传改了的文件。快照对象另存在 <git-common-dir>/xiyou_ci_generated.git
（裸库），不往主工作区 .git 里塞 1 GB 对象，不用了可以整个删掉。云端结果也放在 refs/ci/results/ 下，
Mac 只用 git ls-remote / fetch 就能读，不需要 GitHub 令牌。
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PROJECT_REL = '03_再刷重制_Godot/01_Godot工程'
GENERATED_REL = PROJECT_REL + '/modes/xiyou/generated'
SEED = HERE / '云端测试耗时.json'
CHUNK = 45 * 1024 * 1024  # GitHub 单个对象上限 100 MB，超过 50 MB 会警告
PART = '.ci-part-'  # 大文件分段名：<文件名>.ci-part-000、-001 …
GEN_PREFIX = 'refs/ci/generated/'
RESULT_PREFIX = 'refs/ci/results/'
BOT = {'GIT_AUTHOR_NAME': 'xiyou-ci', 'GIT_AUTHOR_EMAIL': 'xiyou-ci@localhost',
       'GIT_COMMITTER_NAME': 'xiyou-ci', 'GIT_COMMITTER_EMAIL': 'xiyou-ci@localhost'}
TEST_TIMEOUT = 1200  # 云端单核比 Mac 慢，xiyou_rules 在 Mac 并行时已近 390 秒；本机 并行测试.py 仍是 600


def log(*a):
    print('[云端选测]', *a, file=sys.stderr, flush=True)


def git(*args, cwd=ROOT, git_dir=None, input=None, env=None, check=True, text=True):
    cmd = ['git'] + (['--git-dir', str(git_dir)] if git_dir else ['-C', str(cwd)]) + ['-c', 'core.quotepath=false'] + list(args)
    p = subprocess.run(cmd, input=input, capture_output=True, text=text, env=dict(os.environ, **(env or {})))
    if check and p.returncode:
        err = p.stderr if text else p.stderr.decode(errors='replace')
        raise RuntimeError('git %s 失败：%s' % (' '.join(args[:3]), err.strip()[-400:]))
    return p.stdout.strip() if text else p.stdout


def remote_name():
    names = git('remote').split()
    for n in ('github', 'origin'):  # Mac 主工作区的 GitHub 远端叫 github，云端容器与 Actions 里叫 origin
        if n in names:
            return n
    raise RuntimeError('没有 github／origin 远端')


def cache_repo():
    common = Path(git('rev-parse', '--path-format=absolute', '--git-common-dir'))
    bare = common / 'xiyou_ci_generated.git'
    if not (bare / 'HEAD').exists():
        subprocess.run(['git', 'init', '-q', '--bare', str(bare)], check=True)
    return bare


def current_branch():
    b = git('rev-parse', '--abbrev-ref', 'HEAD')
    if b == 'HEAD':
        raise RuntimeError('HEAD 不在分支上，用 --branch 指定')
    return b


def ls_remote(remote, *refs, git_dir=None):
    out = git('ls-remote', remote, *refs, git_dir=git_dir) if git_dir else git('ls-remote', remote, *refs)
    return {line.split('\t')[1]: line.split('\t')[0] for line in out.splitlines() if '\t' in line}


# ---------- 产物快照 ----------

def blob_sha(data):
    return hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()


def snapshot(generated, bare):
    """把 generated 目录写成 Git 树（只写库里没有的对象），返回 (树号, 分段表)。"""
    entries = {}  # 目录相对路径 → [(模式, 类型, 号, 名字)]
    pending = []  # (号, 数据) 待写
    parts = {}
    for path in sorted(generated.rglob('*')):
        if path.is_dir() or path.name == '.DS_Store' or path.name.startswith('._'):
            continue
        rel = path.relative_to(generated)
        if PART in rel.name:
            raise RuntimeError('产物里有与分段名冲突的文件：%s' % rel)
        data = path.read_bytes()
        chunks = [data] if len(data) <= CHUNK else [data[i:i + CHUNK] for i in range(0, len(data), CHUNK)]
        if len(chunks) > 1:
            parts[str(rel)] = len(chunks)
        for i, chunk in enumerate(chunks):
            name = rel.name if len(chunks) == 1 else '%s%s%03d' % (rel.name, PART, i)
            sha = blob_sha(chunk)
            mode = '100755' if os.access(path, os.X_OK) and len(chunks) == 1 else '100644'
            entries.setdefault(str(rel.parent), []).append((mode, 'blob', sha, name))
            pending.append((sha, chunk))
    if not pending:
        raise RuntimeError('产物目录是空的：%s' % generated)
    have = git('cat-file', '--batch-check', git_dir=bare, input=''.join(s + '\n' for s, _ in pending)).splitlines()
    missing = {line.split()[0] for line in have if line.endswith(' missing')}
    written = 0
    for sha, chunk in pending:
        if sha in missing:
            got = git('hash-object', '-w', '--stdin', git_dir=bare, input=chunk, text=False).decode().strip()
            assert got == sha, (got, sha)
            missing.discard(sha)
            written += len(chunk)
    log('产物 %d 个对象，新写 %.1f MB' % (len(pending), written / 1e6))

    def tree(node):
        rows = list(node.get(None, []))
        rows += [('040000', 'tree', tree(child), name) for name, child in sorted((k, v) for k, v in node.items() if k is not None)]
        return git('mktree', '-z', git_dir=bare, input=''.join('%s %s %s\t%s\0' % r for r in rows))
    root = {}
    for rel, rows in entries.items():
        node = root
        for name in ([] if rel == '.' else Path(rel).parts):
            node = node.setdefault(name, {})
        node.setdefault(None, []).extend(rows)
    return tree(root), parts


def cmd_upload(a):
    branch = a.branch or current_branch()
    generated = ROOT / GENERATED_REL
    if not (generated / 'manifest.json').is_file():
        raise RuntimeError('本工作树没有转换产物（%s）' % generated)
    bare, remote = cache_repo(), remote_name()
    url = git('remote', 'get-url', remote)
    stamp = json.loads((generated / 'sync_stamp.json').read_text()) if (generated / 'sync_stamp.json').is_file() else {}
    tree_sha, parts = snapshot(generated, bare)
    ref = GEN_PREFIX + branch
    remote_has = ls_remote(url, ref, GEN_PREFIX + 'main', git_dir=bare)

    def same(r):  # 远端那份快照的树与本次相同（本地裸库没有那个提交时当作不同）
        return r in remote_has and git('rev-parse', '--verify', '-q', remote_has[r] + '^{tree}', git_dir=bare, check=False) == tree_sha
    if same(ref) or (branch != 'main' and ref not in remote_has and same(GEN_PREFIX + 'main')):
        r = ref if same(ref) else GEN_PREFIX + 'main'
        log('产物与远端 %s 相同，不用推（%s）' % (r, remote_has[r][:10]))
        print('GENERATED_REF=%s %s' % (r, remote_has[r]))
        return 0
    meta = {'branch': branch, 'source': git('rev-parse', 'HEAD'), 'time': datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
            'syncStamp': stamp, 'parts': parts, 'chunk': CHUNK}
    commit = git('commit-tree', tree_sha, git_dir=bare, env=BOT,
                 input='ci generated snapshot %s\n\n%s\n' % (branch, json.dumps(meta, ensure_ascii=False, indent=1)))
    git('update-ref', ref, commit, git_dir=bare)
    log('推送 %s → %s（首次约 400 MB，之后只传改了的文件）' % (commit[:10], ref))
    git('push', '--force', '--no-verify', url, '%s:%s' % (commit, ref), git_dir=bare, env={'GIT_TERMINAL_PROMPT': '0'})
    # 只留每个分支最后一次快照：旧对象随 gc 清掉，裸库不会越攒越大
    git('-c', 'gc.pruneExpire=now', 'gc', '--auto', '--quiet', git_dir=bare, check=False)
    print('GENERATED_REF=%s %s' % (ref, commit))
    return 0


def cmd_run(a):
    branch = a.branch or current_branch()
    if not a.no_upload:
        a.branch = branch
        cmd_upload(a)
    remote = remote_name()
    target = ('ci-full/' if a.full else 'ci/') + branch
    head = git('rev-parse', 'HEAD')
    if git('status', '--porcelain', '--untracked-files=no'):
        log('注意：工作区有未提交改动，云端只测已提交的 HEAD')
    git('push', '--force', '--no-verify', remote, 'HEAD:refs/heads/' + target, env={'GIT_TERMINAL_PROMPT': '0'})
    print('已推送 %s → %s，云端开始选测（基准 GitHub main 的分叉点%s）' % (head[:10], target, '，整轮' if a.full else ''))
    print('等结果：python3 %s wait %s%s' % (Path(__file__).relative_to(ROOT), head, ' --mode full' if a.full else ''))
    return 0


def cmd_wait(a):
    sha = git('rev-parse', a.commit or 'HEAD')
    bare, remote = cache_repo(), remote_name()
    url = git('remote', 'get-url', remote)
    modes = [a.mode] if a.mode else ['affected', 'full']
    refs = [RESULT_PREFIX + sha + '/' + m for m in modes]
    deadline = time.time() + a.timeout
    while True:
        found = ls_remote(url, *refs, git_dir=bare)
        if found:
            ref = next(r for r in refs if r in found)
            git('fetch', '-q', '--no-tags', url, '+%s:%s' % (ref, ref), git_dir=bare)
            res = json.loads(git('cat-file', '-p', ref + ':result.json', git_dir=bare))
            print(git('cat-file', '-p', ref + ':summary.md', git_dir=bare))
            return 0 if res.get('passed') else 1
        if time.time() > deadline:
            print('等了 %d 秒还没有 %s 的云端结果（看 GitHub Actions「云端选测」）' % (a.timeout, sha[:10]))
            return 124
        time.sleep(a.interval)


# ---------- CI 端 ----------

def gh_output(**kv):
    out = os.environ.get('GITHUB_OUTPUT')
    lines = ''.join('%s=%s\n' % (k, v) for k, v in kv.items())
    if out:
        with open(out, 'a') as f:
            f.write(lines)
    else:
        sys.stdout.write(lines)


def summary(text):
    out = os.environ.get('GITHUB_STEP_SUMMARY')
    if out:
        with open(out, 'a') as f:
            f.write(text + '\n')
    else:
        print(text)


def godot_version():
    return json.loads((HERE / '环境登记.json').read_text())['version']


def cmd_godot(a):
    """与 云端准备.sh 相同：官方 Linux 版，按官方 SHA512 清单校验。"""
    ver = godot_version()
    gdir = Path.home() / '.cache/xiyou-godot' / ver
    exe = gdir / ('Godot_v%s-stable_linux.x86_64' % ver)
    if not exe.is_file():
        gdir.mkdir(parents=True, exist_ok=True)
        base = 'https://github.com/godotengine/godot-builds/releases/download/%s-stable/' % ver
        z = 'Godot_v%s-stable_linux.x86_64.zip' % ver
        subprocess.run(['curl', '-fsSL', '--retry', '3', '-o', str(gdir / z), base + z], check=True)
        sums = subprocess.run(['curl', '-fsSL', '--retry', '3', base + 'SHA512-SUMS.txt'], check=True, capture_output=True, text=True).stdout
        want = next(l.split()[0] for l in sums.splitlines() if l.endswith(' ' + z))
        if hashlib.sha512((gdir / z).read_bytes()).hexdigest() != want:
            raise RuntimeError('Godot 下载包 SHA512 不符')
        with zipfile.ZipFile(gdir / z) as zf:
            zf.extract(exe.name, gdir)
        (gdir / z).unlink()
        exe.chmod(0o755)
    print(subprocess.run([str(exe), '--headless', '--version'], capture_output=True, text=True).stdout.strip(), file=sys.stderr)
    if os.environ.get('GITHUB_ACTIONS') == 'true':
        cjk_font(gdir.parent / 'fonts')
    gh_output(godot=str(exe))
    return 0


def cjk_font(cache):
    """GitHub 的 Ubuntu 机器没有中文字体：core/game_font.gd 的回退字体是 PingFang SC／Microsoft YaHei UI／sans-serif，
    Linux 上落到无中文的字体，生僻字（如「燚」）宽度和换行就变了（xiyou_inlay_book、xiyou_status_power 因此失败）。
    装文泉驿正黑后这两项与 Mac 一样通过（2026-10-30 云端容器实测）。字体文件随 Godot 一起进 Actions 缓存，各片不用再装。"""
    if subprocess.run(['fc-list', ':lang=zh'], capture_output=True, text=True).stdout.strip():
        return
    ttc = cache / 'wqy-zenhei.ttc'
    if not ttc.is_file():
        subprocess.run('sudo apt-get update -qq && sudo apt-get install -y -qq --no-install-recommends fonts-wqy-zenhei',
                       shell=True, check=True, stdout=subprocess.DEVNULL)
        cache.mkdir(parents=True, exist_ok=True)
        shutil.copy('/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc', ttc)
    else:
        subprocess.run(['sudo', 'install', '-D', '-m', '644', str(ttc), '/usr/local/share/fonts/wqy-zenhei.ttc'], check=True)
        subprocess.run(['fc-cache', '-f'], check=True, stdout=subprocess.DEVNULL)
    log('中文字体：' + subprocess.run(['fc-match', 'sans-serif:lang=zh-cn'], capture_output=True, text=True).stdout.strip())


def generated_ref(branch):
    """CI 跑的分支用哪份产物：ci/<分支>、ci-full/<分支> 先找 <分支> 自己的，没有就用 main 的。"""
    if os.environ.get('XIYOU_CI_GENERATED'):  # 指定某份快照（refs/ci/generated/… 或提交号），试跑与对照用
        want = os.environ['XIYOU_CI_GENERATED']
        return want, ls_remote('origin', want).get(want, want)
    src = re.sub(r'^ci(-full)?/', '', branch)
    found = ls_remote('origin', GEN_PREFIX + src, GEN_PREFIX + 'main')
    for ref in (GEN_PREFIX + src, GEN_PREFIX + 'main'):
        if ref in found:
            return ref, found[ref]
    return '', ''


def cmd_fetch(a):
    ref = a.ref
    target = ROOT / GENERATED_REL
    git('fetch', '-q', '--no-tags', 'origin', '+%s:refs/xiyou-ci/generated' % ref)
    commit = git('rev-parse', 'refs/xiyou-ci/generated')
    marker = ROOT / PROJECT_REL / '.godot/xiyou_ci_snapshot'
    if marker.is_file() and marker.read_text().strip() == commit and (target / 'manifest.json').is_file():
        log('缓存里的产物就是 %s，不用重新解开' % commit[:10])
        return 0
    shutil.rmtree(target, ignore_errors=True)
    target.mkdir(parents=True)
    archive = subprocess.Popen(['git', '-C', str(ROOT), 'archive', '--format=tar', commit], stdout=subprocess.PIPE)
    subprocess.run(['tar', '-x', '-C', str(target)], stdin=archive.stdout, check=True)
    if archive.wait():
        raise RuntimeError('git archive 失败')
    for first in sorted(target.rglob('*' + PART + '000')):
        whole = first.with_name(first.name[:-len(PART + '000')])
        segs = sorted(first.parent.glob(glob_escape(whole.name) + PART + '[0-9][0-9][0-9]'))
        with open(whole, 'wb') as out:
            for s in segs:
                out.write(s.read_bytes())
                s.unlink()
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(commit + '\n')
    msg = git('log', '-1', '--format=%B', commit)
    log('产物 %s 已解开：%s' % (commit[:10], ' '.join(msg.split())[:300]))
    return 0


def glob_escape(s):
    return re.sub(r'([*?\[])', r'[\1]', s)


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def estimates(scenes, timings_file):
    seed = json.loads(SEED.read_text())
    est = {k: v * seed.get('seedFactor', 1.5) for k, v in seed['scenes'].items()}
    if timings_file and Path(timings_file).is_file():
        try:
            est.update({k: float(v) for k, v in json.loads(Path(timings_file).read_text()).items()})
        except (ValueError, AttributeError):
            log('云端耗时缓存读不出，改用种子')
    known = sorted(est[s] for s in scenes if s in est) or [30.0]
    fill = known[len(known) // 2]
    return {s: est.get(s, fill) for s in scenes}


def partition(scenes, est, jobs, target, max_shards):
    """最长的先放、每次放进当前最轻的一片（LPT）；片数按总耗时 ÷（每片并行数 × 目标秒数）取整。"""
    if not scenes:
        return []
    total = sum(est.values())
    n = max(1, min(max_shards, len(scenes), math.ceil(total / (jobs * target))))
    shards = [[0.0, []] for _ in range(n)]
    for s in sorted(scenes, key=lambda s: -est[s]):
        lightest = min(shards, key=lambda x: x[0])
        lightest[0] += est[s] / jobs
        lightest[1].append(s)
    return [sorted(x[1]) for x in shards if x[1]]


def cmd_plan(a):
    sha = git('rev-parse', 'HEAD')
    branch = a.branch
    mode = a.mode or ('full' if branch.startswith('ci-full/') else 'affected')
    project = ROOT / PROJECT_REL
    all_scenes = sorted(p.name for p in (project / 'tests').glob('*.tscn'))
    done = ls_remote('origin', RESULT_PREFIX + sha + '/full', RESULT_PREFIX + sha + '/affected')
    covered = [r for r in done if mode == 'affected' or r.endswith('/full')]
    if covered and not a.force:
        # 只在结果是通过时跳过：总装先推 ci/main 测过、通过后再推 main，main 不用再测一遍
        git('fetch', '-q', '--no-tags', 'origin', '+%s:refs/xiyou-ci/result' % covered[0], check=False)
        res = json.loads(git('cat-file', '-p', 'refs/xiyou-ci/result:result.json', check=False) or '{}')
        if res.get('passed'):
            summary('这个提交（%s）已在云端测过并通过（%s，%s），不再重跑。要重跑就手动触发并勾 force。' % (sha[:10], covered[0], res.get('runUrl', '')))
            gh_output(skip='true', count=0, matrix='{"include":[]}')
            return 0
    reasons = []
    if a.scenes:  # 只跑指定的场景（重跑失败项）
        scenes, base = sorted(set(a.scenes.split()) & set(all_scenes)), ''
        reasons = ['手动指定 %d 个场景' % len(scenes)]
        missing = set(a.scenes.split()) - set(all_scenes)
        if missing:
            reasons.append('不存在、已略过：' + '、'.join(sorted(missing)))
    elif mode == 'full':
        scenes, base = all_scenes, ''
    else:
        base = a.base
        if not base or set(base) == {'0'} or git('rev-parse', '--verify', '-q', base + '^{commit}', check=False) == '':
            base = 'HEAD~1'  # 新分支第一次推送时 before 全 0
        selector = load_module('selector', HERE / '选测.py')
        sel = selector.select(ROOT, base)
        base = sel['base']
        scenes = all_scenes if sel['full'] else sel['scenes']
        if sel['full']:
            mode = 'full'
        reasons = ['%s → %s' % (p, why) for p, why, _, _, _ in sel['reasons']]
        if sel['checks']:
            reasons.append('（非 Godot 检查 %s 不在云端跑，仍在 Mac 上跑）' % '、'.join(sel['checks']))
    est = estimates(scenes, a.timings)
    shards = partition(scenes, est, a.jobs, a.target, a.max_shards)
    ref, gen = generated_ref(branch) if shards else ('', '')
    if shards and not ref:
        raise RuntimeError('GitHub 上没有转换产物快照（%s main），先在 Mac 上跑 云端选测.py upload' % GEN_PREFIX)
    plan = {'sha': sha, 'branch': branch, 'mode': mode, 'base': base, 'scenes': scenes, 'reasons': reasons,
            'generatedRef': ref, 'generatedCommit': gen, 'estimatedSeconds': round(sum(est.values())),
            'shards': [{'shard': i + 1, 'scenes': s, 'estimatedSeconds': round(sum(est[x] for x in s) / a.jobs)} for i, s in enumerate(shards)]}
    Path(a.out).write_text(json.dumps(plan, ensure_ascii=False, indent=1) + '\n')
    lines = ['## 云端选测计划', '', '- 提交 `%s`（%s），%s' % (sha[:10], branch, '整轮' if mode == 'full' else '选测，基准 ' + base),
             '- 场景 %d 个，分 %d 片，预计单机串行 %d 分钟' % (len(scenes), len(shards), sum(est.values()) / 60),
             '- 产物快照 `%s` %s' % (ref or '（不用）', gen[:10])]
    if reasons:
        lines += ['', '<details><summary>选测理由</summary>', '', *['- ' + r.replace('|', '｜') for r in reasons], '', '</details>']
    summary('\n'.join(lines))
    matrix = {'include': [{'shard': i + 1, 'scenes': ' '.join(s)} for i, s in enumerate(shards)]}
    gh_output(skip='false', count=len(shards), matrix=json.dumps(matrix), generated_ref=ref, generated_commit=gen, mode=mode)
    return 0


def cmd_shard(a):
    """跑一片：照搬 并行测试.py（同样的判定、偶发重跑、日志），只把单场景超时放宽到 TEST_TIMEOUT。"""
    runner = load_module('parallel_tests', HERE / '并行测试.py')
    runner.TIMEOUT, runner.SLOW = TEST_TIMEOUT, TEST_TIMEOUT // 2
    names = a.scenes.split()
    log_dir = Path(a.log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)
    names_file = log_dir / 'scenes.txt'
    names_file.write_text(''.join(n + '\n' for n in names))
    failed_file = log_dir / 'failed.tsv'
    os.environ.update(CHECK_FAILED_FILE=str(failed_file), CHECK_GLOBAL_JOBS=str(a.jobs),
                      XIYOU_TEST_STATE_DIR=str(log_dir.parent / 'xiyou_test_state'), XIYOU_TEST_HEARTBEAT='120')
    sys.argv = ['并行测试.py', a.godot, str(ROOT / PROJECT_REL), '--jobs', str(a.jobs), '--log-dir', str(log_dir),
                '--names-file', str(names_file)]
    start = time.time()
    rc = runner.main()
    timings = json.loads((log_dir / 'test_timings.json').read_text()) if (log_dir / 'test_timings.json').is_file() else {}
    result = {'shard': a.shard, 'rc': rc, 'wallSeconds': round(time.time() - start, 1), 'scenes': names,
              'timings': {s['name']: s['seconds'] for s in timings.get('scenes', [])},
              'failed': sorted(timings.get('failed', [])), 'flaky': sorted(timings.get('flakyRerunPassed', []))}
    if rc and not result['failed']:
        result['failed'] = [n for n in names if not next((s['passed'] for s in timings.get('scenes', []) if s['name'] == n), False)] or names
    Path(a.out).write_text(json.dumps(result, ensure_ascii=False, indent=1) + '\n')
    return rc


def cmd_report(a):
    plan = json.loads(Path(a.plan).read_text()) if a.plan and Path(a.plan).is_file() else {}
    results = [json.loads(p.read_text()) for p in sorted(Path(a.results).glob('**/shard-*.json'))] if a.results else []
    sha = plan.get('sha') or git('rev-parse', 'HEAD')
    want = {s['shard'] for s in plan.get('shards', [])}
    got = {r['shard'] for r in results}
    failed = sorted({f for r in results for f in r['failed']})
    flaky = sorted({f for r in results for f in r['flaky']})
    lost = sorted(want - got)
    if a.job_status == 'cancelled':
        summary('运行被取消（多半是同一分支又推了新提交），不写结果。')
        return 0
    passed = not failed and not lost and a.job_status in ('success', 'skipped')
    timings = {}
    if a.timings and Path(a.timings).is_file():
        try:
            timings = json.loads(Path(a.timings).read_text())
        except ValueError:
            timings = {}
    for r in results:
        timings.update(r['timings'])
    if a.timings:
        Path(a.timings).parent.mkdir(parents=True, exist_ok=True)
        Path(a.timings).write_text(json.dumps(dict(sorted(timings.items())), ensure_ascii=False, indent=0) + '\n')
    run_url = '%s/%s/actions/runs/%s' % (os.environ.get('GITHUB_SERVER_URL', ''), os.environ.get('GITHUB_REPOSITORY', ''), os.environ.get('GITHUB_RUN_ID', ''))
    walls = [r['wallSeconds'] for r in results]
    res = {'sha': sha, 'branch': plan.get('branch', ''), 'mode': plan.get('mode', a.mode or 'affected'), 'base': plan.get('base', ''),
           'passed': passed, 'scenes': len(plan.get('scenes', [])), 'failed': failed, 'flaky': flaky, 'lostShards': lost,
           'jobStatus': a.job_status, 'shards': len(want), 'longestShardSeconds': max(walls or [0]),
           'testSeconds': round(sum(sum(r['timings'].values()) for r in results)),
           'generatedRef': plan.get('generatedRef', ''), 'generatedCommit': plan.get('generatedCommit', ''), 'runUrl': run_url,
           'time': datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')}
    head = '✓ 云端选测通过' if passed else '✗ 云端选测有失败'
    lines = ['## %s' % head, '', '- 提交 %s（%s），%s，%d 个场景、%d 片，最长一片 %d 分钟' % (
        sha[:10], res['branch'], '整轮' if res['mode'] == 'full' else '选测（基准 %s）' % res['base'], res['scenes'], res['shards'], res['longestShardSeconds'] / 60)]
    if failed:
        lines.append('- 失败场景 %d 个：%s（日志在运行页的 logs-shard-* 附件）' % (len(failed), '、'.join(failed)))
    if lost:
        lines.append('- 第 %s 片没有交回结果（任务出错或超时，看运行页）' % '、'.join(map(str, lost)))
    if a.job_status not in ('success', 'skipped') and not failed and not lost:
        lines.append('- 准备或测试任务状态 %s（看运行页）' % a.job_status)
    if flaky:
        lines.append('- 偶发（并行时失败、单跑通过，算通过）：%s' % '、'.join(flaky))
    lines.append('- 运行页：%s' % run_url)
    text = '\n'.join(lines) + '\n'
    summary(text)
    if a.publish:
        tmp = tempfile.mkdtemp()
        idx = dict(os.environ, GIT_INDEX_FILE=os.path.join(tmp, 'index'), **BOT)
        blobs = [(git('hash-object', '-w', '--stdin', input=json.dumps(res, ensure_ascii=False, indent=1) + '\n'), 'result.json'),
                 (git('hash-object', '-w', '--stdin', input=text), 'summary.md')]
        tree = git('mktree', input=''.join('100644 blob %s\t%s\n' % b for b in blobs))
        commit = git('commit-tree', tree, input='ci result %s %s\n' % (sha, res['mode']), env=idx)
        git('push', '-q', '--force', 'origin', '%s:%s%s/%s' % (commit, RESULT_PREFIX, sha, res['mode']))
        shutil.rmtree(tmp, ignore_errors=True)
    return 0 if passed else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('upload'); p.add_argument('--branch')
    p = sub.add_parser('run'); p.add_argument('--branch'); p.add_argument('--full', action='store_true')
    p.add_argument('--no-upload', action='store_true', help='不传产物（用 GitHub 上已有的本分支或 main 的快照）')
    p = sub.add_parser('wait'); p.add_argument('commit', nargs='?'); p.add_argument('--mode', choices=['affected', 'full'])
    p.add_argument('--timeout', type=int, default=3600); p.add_argument('--interval', type=int, default=30)
    sub.add_parser('godot')
    p = sub.add_parser('fetch'); p.add_argument('--ref', required=True)
    p = sub.add_parser('plan'); p.add_argument('--branch', required=True); p.add_argument('--mode', choices=['affected', 'full', ''])
    p.add_argument('--base', default='origin/main'); p.add_argument('--force', action='store_true')
    p.add_argument('--scenes', default='', help='只跑这些场景（空格分隔），不按选测')
    p.add_argument('--timings'); p.add_argument('--jobs', type=int, default=2); p.add_argument('--target', type=int, default=600)
    p.add_argument('--max-shards', type=int, default=16); p.add_argument('--out', default='plan.json')
    p = sub.add_parser('shard'); p.add_argument('--godot', required=True); p.add_argument('--scenes', required=True)
    p.add_argument('--shard', type=int, required=True); p.add_argument('--jobs', type=int, default=2)
    p.add_argument('--log-dir', required=True); p.add_argument('--out', required=True)
    p = sub.add_parser('report'); p.add_argument('--plan'); p.add_argument('--results'); p.add_argument('--timings')
    p.add_argument('--job-status', default='success'); p.add_argument('--mode'); p.add_argument('--publish', action='store_true')
    a = ap.parse_args(argv)
    try:
        return globals()['cmd_' + a.cmd](a)
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print('云端选测 %s 失败：%s' % (a.cmd, error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
