#!/usr/bin/env python3
"""新建工作树.sh --快速（T036）：引擎软链、generated 克隆、info/exclude、主工作区缺 generated 时跳过；orca.yaml 接线。只用临时目录，几秒。"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / '新建工作树.sh'
GODOT = '03_再刷重制_Godot'
ENV = dict(os.environ, GIT_AUTHOR_NAME='f', GIT_AUTHOR_EMAIL='f@example.invalid',
           GIT_COMMITTER_NAME='f', GIT_COMMITTER_EMAIL='f@example.invalid')


def run(cwd, *args, check=True):
    return subprocess.run(args, cwd=cwd, env=ENV, text=True, capture_output=True, check=check)


def make_main(tmp, with_generated):
    main = Path(tmp) / ('main_g' if with_generated else 'main_n')
    env = main / GODOT / '07_开发环境'
    env.mkdir(parents=True)
    shutil.copy2(SCRIPT, env / '新建工作树.sh')
    (env / '参照批次.py').write_text('import sys\nsys.exit(0)\n')   # 桩：record 不管
    (main / '.gitignore').write_text(f'{GODOT}/07_开发环境/引擎/\n{GODOT}/07_开发环境/当前Godot.app\n{GODOT}/01_Godot工程/modes/xiyou/generated/\n')
    run(main, 'git', 'init', '-q', '-b', 'main')
    (env / '引擎' / '4.7' / 'Godot.app').mkdir(parents=True)
    os.symlink('引擎/4.7/Godot.app', env / '当前Godot.app')   # 和真库一样的相对软链
    if with_generated:
        gen = main / GODOT / '01_Godot工程/modes/xiyou/generated'
        (gen / 'db').mkdir(parents=True)
        (gen / 'db' / 'manifest.json').write_text('{}')
    run(main, 'git', 'add', '-A'); run(main, 'git', 'commit', '-qm', 'base')
    return main


def quick(main, name):
    wt = main.parent / name
    run(main, 'git', 'worktree', 'add', '-q', '-b', 'cc/' + name, str(wt), 'main')
    p = run(main, 'zsh', str(main / GODOT / '07_开发环境/新建工作树.sh'), '--快速', str(wt), check=False)
    return wt, p


with tempfile.TemporaryDirectory(prefix='xiyou_quick_prepare_') as tmp:
    main = make_main(tmp, True)
    wt, p = quick(main, 'a')
    assert p.returncode == 0, p.stdout + p.stderr
    app = wt / GODOT / '07_开发环境/当前Godot.app'
    assert app.is_symlink() and app.exists(), '引擎软链要能解析到主工作区的引擎'
    gen = wt / GODOT / '01_Godot工程/modes/xiyou/generated'
    assert (gen / 'db/manifest.json').is_file() and not gen.is_symlink(), 'generated 要克隆成真目录'
    (gen / 'db/manifest.json').write_text('changed')
    mg = main / GODOT / '01_Godot工程/modes/xiyou/generated/db/manifest.json'
    assert mg.read_text() == '{}', '克隆后改工作树的 generated 不能影响主工作区'
    (gen / 'db/manifest.json').write_text('{}')
    assert run(wt, 'git', 'status', '--short').stdout.strip() == '', '软链和 generated 不能出现在 git status'
    # 幂等：再跑一次不报错、不重复写 exclude
    p2 = run(main, 'zsh', str(main / GODOT / '07_开发环境/新建工作树.sh'), '--快速', str(wt), check=False)
    assert p2.returncode == 0, p2.stdout + p2.stderr
    ex = (main / '.git/info/exclude').read_text().splitlines()
    assert ex.count(f'{GODOT}/07_开发环境/引擎') == 1 and ex.count(f'{GODOT}/07_开发环境/当前Godot.app') == 1, ex
    # 已有 generated 不覆盖
    (gen / 'mine').write_text('x')
    run(main, 'zsh', str(main / GODOT / '07_开发环境/新建工作树.sh'), '--快速', str(wt))
    assert (gen / 'mine').is_file()
    assert not (mg.parent / 'mine').exists()
    # 悬空软链（别处残留）也不挂
    wt2, _ = quick(main, 'b')   # 已补齐一次
    app2 = wt2 / GODOT / '07_开发环境/当前Godot.app'
    app2.unlink(); os.symlink('不存在', app2)
    p3 = run(main, 'zsh', str(main / GODOT / '07_开发环境/新建工作树.sh'), '--快速', str(wt2), check=False)
    assert p3.returncode == 0, p3.stdout + p3.stderr

    # 主工作区没有 generated：跳过并提示，退出码 0
    main2 = make_main(tmp, False)
    wt3, p4 = quick(main2, 'c')
    assert p4.returncode == 0, p4.stdout + p4.stderr
    assert '没有 generated' in p4.stderr, p4.stderr
    assert not (wt3 / GODOT / '01_Godot工程/modes/xiyou/generated').exists()

    # 主工作区自己不能被「补齐」
    p5 = run(main, 'zsh', str(main / GODOT / '07_开发环境/新建工作树.sh'), '--快速', str(main), check=False)
    assert p5.returncode != 0

# 接线：orca.yaml 的 setup 调 --快速
root = HERE.parents[1]
y = (root / 'orca.yaml').read_text(encoding='utf-8')
assert 'scripts:' in y and 'setup:' in y and '--快速' in y and 'ORCA_WORKTREE_PATH' in y
print('OK 快速补齐')
