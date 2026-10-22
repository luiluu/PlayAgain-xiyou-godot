#!/usr/bin/env python3
"""用临时资料库验证工作树清理边界；不会操作真实工作树。"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

SCRIPT = Path(__file__).with_name('清理工作树.sh')
ENV = dict(os.environ, GIT_AUTHOR_NAME='fixture', GIT_AUTHOR_EMAIL='fixture@example.invalid',
           GIT_COMMITTER_NAME='fixture', GIT_COMMITTER_EMAIL='fixture@example.invalid')


def run(cwd, *args, check=True):
    return subprocess.run(args, cwd=cwd, env=ENV, text=True, capture_output=True, check=check)


with tempfile.TemporaryDirectory(prefix='xiyou_worktree_cleanup_') as tmp:
    main = Path(tmp) / 'main'
    main.mkdir()
    run(main, 'git', 'init', '-b', 'main')
    helper = main / '03_再刷重制_Godot/07_开发环境/清理工作树.sh'
    helper.parent.mkdir(parents=True)
    shutil.copy2(SCRIPT, helper)
    (main / '.gitignore').write_text('03_再刷重制_Godot/04_验证/本地结果/\ncache/\n')
    (main / 'file').write_text('base')
    run(main, 'git', 'add', '.')
    run(main, 'git', 'commit', '-m', 'base')
    # 分离 HEAD 上的新提交仍是需要保护的工作；不能因没有分支名就略过祖先检查。
    detached = Path(tmp) / 'detached'
    run(main, 'git', 'worktree', 'add', '--detach', str(detached))
    (detached / 'file').write_text('unmerged detached')
    run(detached, 'git', 'commit', '-am', 'unmerged')
    p = run(main, 'zsh', str(helper), str(detached), check=False)
    assert p.returncode != 0 and detached.exists(), p.stdout + p.stderr
    # 同样保护未合并分支和未提交现场。
    branch = Path(tmp) / 'branch'
    run(main, 'git', 'worktree', 'add', '-b', 'fixture/branch', str(branch))
    (branch / 'file').write_text('unmerged branch')
    run(branch, 'git', 'commit', '-am', 'unmerged')
    p = run(main, 'zsh', str(helper), str(branch), check=False)
    assert p.returncode != 0 and branch.exists(), p.stdout + p.stderr
    dirty = Path(tmp) / 'dirty'
    run(main, 'git', 'worktree', 'add', '-b', 'fixture/dirty', str(dirty))
    (dirty / 'file').write_text('dirty')
    p = run(main, 'zsh', str(helper), str(dirty), check=False)
    assert p.returncode != 0 and dirty.exists(), p.stdout + p.stderr
    # 允许清理已合并的干净分支；先搬回不入 Git 的证据，再删工作树和分支。
    clean = Path(tmp) / 'clean'
    run(main, 'git', 'worktree', 'add', '-b', 'fixture/clean', str(clean))
    evidence = Path('03_再刷重制_Godot/04_验证/本地结果')
    (clean / evidence).mkdir(parents=True)
    (clean / evidence / 'result.txt').write_text('keep me')
    run(main, 'zsh', str(helper), str(clean))
    assert not clean.exists()
    assert (main / evidence / 'worktree_clean/result.txt').read_text() == 'keep me'
    assert run(main, 'git', 'show-ref', '--verify', 'refs/heads/fixture/clean', check=False).returncode != 0
    # 同一路径复用：第二次清理时归档目录已有同名 自动同步/，逐层合并，两次的证据都保留。
    def reuse(branch_name, files):
        run(main, 'git', 'worktree', 'add', '-b', branch_name, str(clean))
        for rel, text in files.items():
            (clean / evidence / rel).parent.mkdir(parents=True, exist_ok=True)
            (clean / evidence / rel).write_text(text)
        return run(main, 'zsh', str(helper), str(clean), check=False)
    keep = main / evidence / 'worktree_clean'
    p = reuse('fixture/reuse1', {'自动同步/run_a/log.txt': 'a', 'sync.lock': ''})
    assert p.returncode == 0 and not clean.exists(), p.stdout + p.stderr
    p = reuse('fixture/reuse2', {'自动同步/run_b/log.txt': 'b', 'sync.lock': ''})
    assert p.returncode == 0 and not clean.exists(), p.stdout + p.stderr
    assert (keep / '自动同步/run_a/log.txt').read_text() == 'a'
    assert (keep / '自动同步/run_b/log.txt').read_text() == 'b'
    assert (keep / 'sync.lock').exists() and not (keep / 'sync.lock.2').exists()  # 内容相同的空锁只留一份
    # 同名文件内容不同：旧的不被覆盖，新来的加后缀。
    p = reuse('fixture/reuse3', {'自动同步/run_a/log.txt': 'a2', 'result.txt': 'second'})
    assert p.returncode == 0 and not clean.exists(), p.stdout + p.stderr
    assert (keep / '自动同步/run_a/log.txt').read_text() == 'a'
    assert (keep / '自动同步/run_a/log.txt.2').read_text() == 'a2'
    assert (keep / 'result.txt').read_text() == 'keep me'
    assert (keep / 'result.txt.2').read_text() == 'second'
    # 归档失败（目标不可写）时非零退出，worktree 与分支都保留。
    (keep / '自动同步').chmod(0o500)
    try:
        p = reuse('fixture/reuse4', {'自动同步/run_c/log.txt': 'c'})
    finally:
        (keep / '自动同步').chmod(0o700)
    assert p.returncode != 0 and clean.exists(), p.stdout + p.stderr
    assert run(main, 'git', 'show-ref', '--verify', 'refs/heads/fixture/reuse4', check=False).returncode == 0
print('TEST_RESULT={"passed":7,"total":7}')
