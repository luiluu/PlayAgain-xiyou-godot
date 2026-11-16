#!/usr/bin/env python3
"""造测试档：全通关、全角色养成满（T066）。可复跑。

  python3 造测试档.py --project <Godot 工程目录> --out <输出目录> [--slot 10] [--seed 20261015]

- --project：要用哪份代码造档。给 v0.03.00 测试用补丁线 cc/v00300 的工程（存档格式跟玩家手里的一致）；默认本工作树的工程。
  只读用那份工程：场景脚本在本目录，临时场景写在系统临时目录，工程里一个文件都不写。
- 存档先写到那份工程的 user://test_max_save（开发数据目录下的测试子目录，跑完删掉），再复制到 --out；不碰 user://modes/xiyou 真存档。
- --out 里得到 save_<slot>.json 和 report.json（通关、招募、各角色养成结果）。

读档验证（带窗口，静音）：
  python3 造测试档.py --check <存档所在目录> --project <工程> --shot <截图.png> [--slot 10]
  先把存档复制到临时目录再读（main 开着封存时会在临时目录里封成 .ksv，--seal-out 给了就把 .ksv 拷出来），
  读档、进地图、截图，打印 LOAD_CHECK_RESULT 和日志里的 SCRIPT ERROR 行数。
"""
import shutil
import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ENV = HERE.parent
DEFAULT_PROJECT = ENV.parent / '01_Godot工程'


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--project', type=Path, default=DEFAULT_PROJECT)
    ap.add_argument('--out', type=Path)
    ap.add_argument('--check', type=Path, help='读档验证：存档所在目录')
    ap.add_argument('--shot', type=Path)
    ap.add_argument('--seal-out', type=Path, help='读档验证后把临时目录里封好的 save_<slot>.ksv 拷到这里')
    ap.add_argument('--slot', type=int, default=10)
    ap.add_argument('--seed', type=int, default=20261015)
    ap.add_argument('--godot', default=str(ENV / 'godot'))
    ap.add_argument('--timeout', type=int, default=3600, help='秒；脚本解析失败时 Godot 不会自己退出')
    a = ap.parse_args(argv)
    if not 1 <= a.slot <= 10:
        ap.error('--slot 要 1～10（开局固定存档位）')
    proj = a.project.resolve()
    if not (proj / 'project.godot').exists() or not (proj / 'tests' / 'xiyou_floor_run.gd').exists():
        ap.error(f'{proj} 不是带 tests/xiyou_floor_run.gd 的 Godot 工程')
    if a.check:
        return check(a, proj)
    if a.out is None:
        ap.error('要 --out 或 --check')
    script = HERE / 'full_clear_max.gd'
    with tempfile.TemporaryDirectory(prefix='max_save_') as tmp:
        scene = Path(tmp) / 'max_save.tscn'
        scene.write_text(
            '[gd_scene load_steps=2 format=3]\n\n'
            f'[ext_resource type="Script" path="{script}" id="1"]\n\n'
            '[node name="MaxSave" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
        a.out.mkdir(parents=True, exist_ok=True)
        cmd = [a.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(proj),
               '-s', 'res://tests/test_main_loop.gd', str(scene), '--',
               f'--out={a.out.resolve()}', f'--slot={a.slot}', f'--seed={a.seed}']
        print(' '.join(cmd), flush=True)
        log = a.out / 'godot.log'
        with open(log, 'w', encoding='utf-8') as f:
            try:
                rc = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT, timeout=a.timeout)
            except subprocess.TimeoutExpired:
                rc = 124
    text = log.read_text(encoding='utf-8', errors='replace')
    errs = [l for l in text.splitlines() if 'SCRIPT ERROR' in l or l.startswith('ERROR:')]
    print(f'退出码 {rc}；日志 {log}；SCRIPT ERROR/ERROR 行 {len(errs)}')
    for l in errs[:20]:
        print('  ', l)
    for l in text.splitlines():
        if l.startswith('MAX_SAVE_RESULT='):
            print(l)
    return rc


def scene_for(script: Path, tmp: str) -> Path:
    scene = Path(tmp) / 'run.tscn'
    scene.write_text('[gd_scene load_steps=2 format=3]\n\n'
                     f'[ext_resource type="Script" path="{script}" id="1"]\n\n'
                     '[node name="Run" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
    return scene


def check(a, proj: Path) -> int:
    src = a.check.resolve()
    with tempfile.TemporaryDirectory(prefix='max_save_check_') as tmp:
        work = Path(tmp) / 'saves'
        work.mkdir()
        shutil.copy2(src / f'save_{a.slot}.json', work / f'save_{a.slot}.json')
        cmd = [a.godot, '--audio-driver', 'Dummy', '--path', str(proj), '-s', 'res://tests/test_main_loop.gd',
               str(scene_for(HERE / 'load_check.gd', tmp)), '--', f'--dir={work}', f'--slot={a.slot}']
        if a.shot:
            a.shot.parent.mkdir(parents=True, exist_ok=True)
            cmd.append(f'--shot={a.shot.resolve()}')
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
            rc, text = p.returncode, p.stdout + p.stderr
        except subprocess.TimeoutExpired as e:
            rc, text = 124, str(e.stdout or '')
        if a.seal_out and (work / f'save_{a.slot}.ksv').exists():
            a.seal_out.mkdir(parents=True, exist_ok=True)
            shutil.copy2(work / f'save_{a.slot}.ksv', a.seal_out / f'save_{a.slot}.ksv')
            print('封存档：', a.seal_out / f'save_{a.slot}.ksv')
    errs = [l for l in text.splitlines() if 'SCRIPT ERROR' in l]
    for l in text.splitlines():
        if l.startswith('LOAD_CHECK_RESULT='):
            print(l)
    print(f'退出码 {rc}；SCRIPT ERROR {len(errs)} 行')
    for l in errs[:10]:
        print('  ', l)
    return rc if not errs else 1


if __name__ == '__main__':
    sys.exit(main())
