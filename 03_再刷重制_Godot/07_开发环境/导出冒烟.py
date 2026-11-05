#!/usr/bin/env python3
"""Mac 导出包启动冒烟（哪吒 mac1，2026-11-05）：一条命令导出「macOS 验收」调试包、解开、在隔离 HOME 里无头跑包内检查，写报告。

  python3 导出冒烟.py                 导出 → 解包 → 签名与架构只读检查 → 包内跑下面几项 → 报告
  python3 导出冒烟.py --zip <包.zip>   不导出，直接冒烟现成的包
  python3 导出冒烟.py --keep           留下解开的 .app（给 Kyo 实机验收用，见 00_项目管理/Mac实机验收清单.md）
  python3 导出冒烟.py --out <目录>     报告目录（默认 04_验证/本地结果/导出冒烟/<时间>/）
  python3 导出冒烟.py --scenes xiyou_mac_export,xiyou_flow   只跑这几项

包内跑的（都是调试包里的 tests/，发行包排除 tests/、跑不到）：
  xiyou_mac_export  字体、中文换行、皮肤、角色图、音效资源、隔离存档的写读删（--verify-export 默认场景）
  xiyou_flow        入口 → 西游 → 新游戏开局事件 → 大厅存档 → 进一层 → 遇敌自动战斗获胜 → 守层者战败回大厅 → 存档／读档一致
每项各用一个新建的临时 HOME（xiyou_export_home_*，在系统临时目录），跑完删掉；不碰真实玩家存档。
签名只做 codesign --verify（只读）；不签名、不公证、不上传，不动钥匙串（派单 AS 第 3 条）。
退出码：全过 0，有失败 1，导出或解包出错 2。
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PROJECT = ROOT / '01_Godot工程'
GODOT = HERE / 'godot'
PRESET = 'macOS 验收'
SCENES = ['xiyou_mac_export', 'xiyou_flow']
TIMEOUT = {'xiyou_mac_export': 180, 'xiyou_flow': 900}
RESULT = re.compile(r'^TEST_RESULT=(\{.*\})\s*$', re.M)
FAIL = re.compile(r'^FAIL .*$', re.M)


def parse_result(log: str):
    """包内测试的输出：最后一行 TEST_RESULT 的 passed／total，加所有 FAIL 行。没有 TEST_RESULT 返回 None。"""
    found = RESULT.findall(log)
    if not found:
        return None
    try:
        data = json.loads(found[-1])
    except json.JSONDecodeError:
        return None
    return {'passed': int(data.get('passed', 0)), 'total': int(data.get('total', 0)), 'fails': FAIL.findall(log)[:20]}


def find_app(folder: Path):
    apps = sorted(folder.glob('*.app'))
    if not apps:
        return None, None
    exe_dir = apps[0] / 'Contents' / 'MacOS'
    exes = sorted(p for p in exe_dir.iterdir() if p.is_file() and os.access(p, os.X_OK)) if exe_dir.is_dir() else []
    return apps[0], (exes[0] if exes else None)


def run(cmd, log_path: Path, timeout: int, env=None, cwd=None):
    t0 = time.time()
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace',
                           timeout=timeout, env=env, cwd=cwd)
        out, code = p.stdout, p.returncode
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b'').decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or '')
        out += f'\n[导出冒烟] 超时 {timeout} 秒，已停\n'
        code = 124
    log_path.write_text(out, encoding='utf-8')
    return code, out, round(time.time() - t0, 1)


def smoke_scene(exe: Path, scene: str, out_dir: Path) -> dict:
    home = Path(tempfile.mkdtemp(prefix='xiyou_export_home_'))
    env = dict(os.environ, HOME=str(home))
    env.pop('XIYOU_TEST_FAST_FORWARD', None)
    args = [str(exe), '--headless', '--', '--verify-export']
    if scene != 'xiyou_mac_export':
        args.append('--verify-scene=' + scene)
    try:
        code, log, secs = run(args, out_dir / f'{scene}.log', TIMEOUT.get(scene, 600), env=env, cwd=str(home))
    finally:
        shutil.rmtree(home, ignore_errors=True)
    res = parse_result(log)
    ok = code == 0 and res is not None and res['total'] > 0 and res['passed'] == res['total']
    return {'scene': scene, 'ok': ok, 'exit': code, 'seconds': secs, 'result': res}


def report(out_dir: Path, info: dict) -> Path:
    lines = ['# Mac 导出冒烟报告', '',
             f'- 时间：{info["time"]}；预设：{info["preset"]}；包：`{info["zip"]}`',
             f'- 工程提交：{info.get("commit", "?")}；Godot：{info.get("godot", "?")}',
             f'- 架构：{info.get("archs", "?")}；签名检查（codesign --verify，只读）：{info.get("codesign", "?")}',
             f'- 结论：**{"全部通过" if info["ok"] else "有失败"}**'] + ([f'- 留下的验收包（--keep）：`{info["keptApp"]}`'] if info.get('keptApp') else []) + ['',
             '| 项目 | 结果 | 断言 | 用时（秒） | 退出码 |', '| --- | --- | --- | --- | --- |']
    for r in info['scenes']:
        res = r['result']
        lines.append(f'| {r["scene"]} | {"通过" if r["ok"] else "失败"} | {f"{res["passed"]}/{res["total"]}" if res else "没有 TEST_RESULT"} | {r["seconds"]} | {r["exit"]} |')
    for r in info['scenes']:
        if r['result'] and r['result']['fails']:
            lines += ['', f'## {r["scene"]} 失败项', ''] + [f'- `{f}`' for f in r['result']['fails']]
    lines += ['', '各项完整输出在同目录 `<场景>.log`；导出日志 `导出.log`。',
              '没覆盖的（要 Kyo 实机）：主观听音、Intel 实机、Developer ID 签名与公证、首次打开的 Gatekeeper，见 `00_项目管理/Mac实机验收清单.md`。']
    p = out_dir / '报告.md'
    p.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (out_dir / '结果.json').write_text(json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return p


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--zip', help='不导出，冒烟这个现成的包')
    ap.add_argument('--out', help='报告目录')
    ap.add_argument('--keep', action='store_true', help='留下解开的 .app 与导出的 zip')
    ap.add_argument('--scenes', default=','.join(SCENES))
    a = ap.parse_args(argv)
    stamp = time.strftime('%Y%m%d_%H%M%S')
    out_dir = Path(a.out) if a.out else ROOT / '04_验证' / '本地结果' / '导出冒烟' / stamp
    out_dir.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='xiyou_export_smoke_'))
    info = {'time': stamp, 'preset': PRESET, 'scenes': [], 'ok': False}
    try:
        info['commit'] = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=ROOT, capture_output=True, text=True).stdout.strip()
        info['godot'] = subprocess.run([str(GODOT), '--version'], capture_output=True, text=True).stdout.strip().splitlines()[-1:] or ['?']
        info['godot'] = info['godot'][0]
        if a.zip:
            zip_path = Path(a.zip).resolve()
        else:
            zip_path = work / '再刷重制_验收.zip'
            print(f'== 导出「{PRESET}」（约 2～5 分钟）')
            code, _, secs = run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-debug', PRESET, str(zip_path)],
                                out_dir / '导出.log', 1800)
            if code != 0 or not zip_path.is_file():
                print(f'✗ 导出失败（退出码 {code}），见 {out_dir / "导出.log"}')
                return 2
            print(f'  导出完成 {secs} 秒，{zip_path.stat().st_size // (1 << 20)} MB')
        info['zip'] = str(zip_path)
        app_dir = work / 'app'
        app_dir.mkdir()
        if subprocess.run(['ditto', '-x', '-k', str(zip_path), str(app_dir)]).returncode != 0:
            print('✗ 解包失败')
            return 2
        app, exe = find_app(app_dir)
        if exe is None:
            print('✗ 包里找不到 .app 或可执行文件')
            return 2
        info['archs'] = subprocess.run(['lipo', '-archs', str(exe)], capture_output=True, text=True).stdout.strip() or '?'
        cs = subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], capture_output=True, text=True)
        info['codesign'] = '通过（ad-hoc）' if cs.returncode == 0 else '不通过：' + (cs.stderr.strip().splitlines() or ['?'])[-1]
        for scene in [s.strip() for s in a.scenes.split(',') if s.strip()]:
            print(f'== 包内跑 {scene}')
            r = smoke_scene(exe, scene, out_dir)
            info['scenes'].append(r)
            res = r['result']
            print(f'  {"✓" if r["ok"] else "✗"} {scene} {f"{res["passed"]}/{res["total"]}" if res else "没有 TEST_RESULT"}，{r["seconds"]} 秒')
        info['ok'] = bool(info['scenes']) and all(r['ok'] for r in info['scenes']) and cs.returncode == 0
        if a.keep:
            kept = out_dir / app.name
            shutil.move(str(app), kept)
            info['keptApp'] = str(kept)
            if not a.zip:
                shutil.move(str(zip_path), out_dir / zip_path.name)
            print(f'  留下 {kept}')
        p = report(out_dir, info)
        print(f'{"✓ 导出冒烟全部通过" if info["ok"] else "✗ 导出冒烟有失败"}；报告 {p}')
        return 0 if info['ok'] else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
