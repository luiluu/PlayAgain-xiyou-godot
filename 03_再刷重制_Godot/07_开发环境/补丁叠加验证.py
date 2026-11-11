#!/usr/bin/env python3
"""补丁叠加验证（自动更新第 0 批，cc 2026-11-11）：在真工程上确认「补丁包放用户目录、启动时叠加载入」能替换脚本、数据、图。

  python3 补丁叠加验证.py               导出底包 → 临时改四处 → 导出补丁 → 还原改动 → 用 macOS 发行模板当替身跑六次
  python3 补丁叠加验证.py --preset "安卓 发行"   换一个导出预设做底包和补丁（默认「Windows 发行」）
  python3 补丁叠加验证.py --keep        留下工作目录（底包、补丁、日志）
  python3 补丁叠加验证.py --out <目录>   工作目录（默认系统临时目录下新建）

做法：
  1. `--export-pack` 导出底包 base.pck（不出 exe／apk，只要数据包）。
  2. 临时改工程（先存原字节，最后无论成败都按原字节还原、删掉新增文件）：
       core/game_app.gd       _ready 开头加一行打印（已有脚本被替换；它是排在 BootPatch 后面的自动加载）
       core/_patch_probe.gd   新增带 class_name 的脚本，game_app 里按类名调用（补丁里新增全局类）
       content/build_info.json 开发编号改成 dev.9999（数据）
       modes/xiyou/ui/game_over_null.png 左上角一个像素改色（图，重新导入）
  3. `--export-patch … --patches base.pck` 导出补丁 patch.pck，记体积。
  4. macOS 发行模板改名放在 base.pck 旁边（发行模板不认 --main-pack），临时 HOME 里跑：
       a 不放补丁            → 进标题，没有探针行
       b 登记补丁            → BOOT_PATCH loaded=true，探针行四项都是补丁里的值，照常进标题
       c 登记的 SHA 不对      → BOOT_PATCH reason=校验不符，没有探针行，照常进标题
       d 补丁文件截断一半     → 同上
       e 新装的补丁（未确认）  → 载入、进标题，跑起来后登记变成已确认
       f 已连续两次没起来      → 启动前自动退回、不载入，留下退回提示
它量的是引擎读包与载入顺序；Windows／安卓真系统上 user:// 的位置和文件读写不在这里（走云端 export-smoke 或实机）。
退出码 0＝六次都符合预期。
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent / '01_Godot工程'
GODOT = Path(os.environ.get('XIYOU_GODOT') or HERE / 'godot')
USER_DIR = 'Library/Application Support/KYO/再刷重制'
ENTRY = 'ENTRY_SCENE=res://modes/xiyou/entry.tscn'
PROBE_GD = '''class_name XPatchProbe
extends RefCounted
static func version() -> String:
	return "new_class"
'''
PROBE_LINE = ('\tprint("PATCH_PROBE script=patched class=", XPatchProbe.version(), " data=", '
              'JSON.parse_string(FileAccess.get_file_as_string("res://content/build_info.json")).developmentVersion, '
              '" img=", (load("res://modes/xiyou/ui/game_over_null.png") as Texture2D).get_image().get_pixel(0, 0).to_html(false))\n')
EXPECT_PROBE = 'PATCH_PROBE script=patched class=new_class data=dev.9999 img=123456'


def godot(*args, timeout=3600):
    p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), *args], capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr


def png_set_pixel(path: Path):
    """用 Godot 改一个像素（不引第三方库）。"""
    script = path.parent / '_patch_probe_edit.gd'
    script.write_text('extends SceneTree\nfunc _init():\n\tvar i := Image.load_from_file("%s")\n\ti.convert(Image.FORMAT_RGBA8)\n'
                      '\ti.set_pixel(0, 0, Color("#123456"))\n\ti.save_png("%s")\n\tquit()\n' % (path, path), encoding='utf-8')
    try:
        subprocess.run([str(GODOT), '--headless', '-s', str(script)], capture_output=True, text=True, timeout=120, cwd=str(path.parent))
    finally:
        script.unlink(missing_ok=True)
        Path(str(script) + '.uid').unlink(missing_ok=True)


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def run_game(exe: Path, work: Path, tag: str, setup, after=None):
    home = work / f'home_{tag}'
    upd = home / USER_DIR / 'updates'
    upd.mkdir(parents=True)
    setup(upd)
    p = subprocess.run([str(exe), '--headless', '--quit-after', '600', '--', '--report-entry'], capture_output=True, text=True,
                       timeout=600, env=dict(os.environ, HOME=str(home)), cwd=str(home))
    out = p.stdout + p.stderr
    (work / f'run_{tag}.log').write_text(out, encoding='utf-8')
    if after:
        out = (out, after(upd))
    shutil.rmtree(home, ignore_errors=True)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--preset', default='Windows 发行')
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--out')
    a = ap.parse_args()
    work = Path(a.out) if a.out else Path(tempfile.mkdtemp(prefix='xiyou_patch_probe_'))
    work.mkdir(parents=True, exist_ok=True)
    base, patch = work / 'game.pck', work / 'patch.pck'
    problems = []

    print(f'· 工作目录 {work}')
    rc, out = godot('--export-pack', a.preset, str(base))
    if rc != 0 or not base.exists():
        print(out[-2000:])
        print('✗ 底包导出失败')
        return 1
    print(f'· 底包 {base.stat().st_size / 1e6:.1f} MB（预设「{a.preset}」）')

    ga, bi, icon = PROJECT / 'core/game_app.gd', PROJECT / 'content/build_info.json', PROJECT / 'modes/xiyou/ui/game_over_null.png'
    probe = PROJECT / 'core/_patch_probe.gd'
    backup = {p: p.read_bytes() for p in (ga, bi, icon)}
    try:
        src = ga.read_text(encoding='utf-8')
        anchor = 'func _ready() -> void:\n'
        assert src.count(anchor) == 1, 'game_app.gd 里 _ready 定位不到'
        ga.write_text(src.replace(anchor, anchor + PROBE_LINE), encoding='utf-8')
        probe.write_text(PROBE_GD, encoding='utf-8')
        d = json.loads(bi.read_text(encoding='utf-8'))
        d['developmentVersion'] = 'dev.9999'
        bi.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        png_set_pixel(icon)
        godot('--import')
        rc, out = godot('--export-patch', a.preset, str(patch), '--patches', str(base))
    finally:
        for p, b in backup.items():
            p.write_bytes(b)
        for p in (probe, Path(str(probe) + '.uid')):
            p.unlink(missing_ok=True)
        godot('--import')
    if rc != 0 or not patch.exists():
        print(out[-2000:])
        print('✗ 补丁导出失败')
        return 1
    print(f'· 补丁 {patch.stat().st_size / 1e3:.1f} KB（改了 1 个脚本、加 1 个脚本、1 个 JSON、1 张图）')

    sys.path.insert(0, str(HERE))
    import 发行入口冒烟 as entry_smoke
    exe = entry_smoke.release_runner(work, base)  # macOS 发行模板改成和底包同名、放在旁边
    if exe is None:
        return 1

    base_code = int(str(json.loads(backup[bi].decode('utf-8'))['developmentVersion']).replace('dev.', ''))
    good = {'file': 'patch.pck', 'sha256': sha(patch), 'size': patch.stat().st_size, 'base': base_code, 'code': 9999}

    def put(state, cut=False):
        def f(upd: Path):
            if state is None:
                return
            data = patch.read_bytes()
            (upd / 'patch.pck').write_bytes(data[:len(data) // 2] if cut else data)
            (upd / 'active.json').write_text(json.dumps(state), encoding='utf-8')
        return f

    def check(tag, name, ok):
        print(f'  {"✓" if ok else "✗"} {tag} {name}')
        if not ok:
            problems.append(f'{tag} {name}')

    o = run_game(exe, work, 'a', put(None))
    check('a 不放补丁', '进标题', ENTRY in o)
    check('a 不放补丁', '没有探针行、没有 BOOT_PATCH 行', 'PATCH_PROBE' not in o and 'BOOT_PATCH' not in o)
    o = run_game(exe, work, 'b', put(good))
    check('b 登记补丁', 'BOOT_PATCH loaded=true', 'BOOT_PATCH loaded=true' in o)
    check('b 登记补丁', '脚本、新全局类、数据、图都是补丁里的', EXPECT_PROBE in o)
    check('b 登记补丁', '进标题', ENTRY in o)
    check('b 登记补丁', '没有 ERROR', 'ERROR' not in o)
    o = run_game(exe, work, 'c', put(dict(good, sha256='0' * 64)))
    check('c SHA 不对', '不载入（校验不符）、照常进标题', 'reason=校验不符' in o and 'PATCH_PROBE' not in o and ENTRY in o)
    bad = dict(good)
    bad.pop('size')
    o = run_game(exe, work, 'd', put(bad, cut=True))
    check('d 文件截断', '不载入（校验不符）、照常进标题', 'reason=校验不符' in o and 'PATCH_PROBE' not in o and ENTRY in o)

    # e 新装的补丁（confirmed=false）：跑起来后载入器自己确认，登记变成 confirmed=true、计数清零
    def read_state(upd: Path):
        return json.loads((upd / 'active.json').read_text(encoding='utf-8')) if (upd / 'active.json').exists() else None
    o, st = run_game(exe, work, 'e', put(dict(good, confirmed=False, boots=0, prev=None)), after=read_state)
    check('e 新装未确认', '载入并进标题', 'BOOT_PATCH loaded=true' in o and ENTRY in o)
    check('e 新装未确认', '跑起来后登记变成已确认', bool(st) and st.get('confirmed') is True and st.get('boots') == 0)
    # f 已经连续两次没起来（boots=2、未确认）：这次启动前自动退回，不载入补丁，留下提示
    def read_all(upd: Path):
        return (read_state(upd), (upd / 'rolled_back.json').exists())
    o, (st, noted) = run_game(exe, work, 'f', put(dict(good, confirmed=False, boots=2, prev=None)), after=read_all)
    check('f 两次没起来', '自动退回：不载入补丁、照常进标题', 'PATCH_PROBE' not in o and 'BOOT_PATCH loaded=true' not in o and ENTRY in o)
    check('f 两次没起来', '登记删掉、留下退回提示', st is None and noted)

    if problems:
        print(f'✗ {len(problems)} 项不符，日志留在 {work}')
        return 1
    print('✓ 补丁叠加载入：六次运行都符合预期')
    if not a.keep and not a.out:
        shutil.rmtree(work, ignore_errors=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
