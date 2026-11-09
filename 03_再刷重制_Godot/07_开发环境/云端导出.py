#!/usr/bin/env python3
"""云端导出冒烟的准备（cc BW 2026-11-06）：GitHub Actions「导出冒烟」工作流（.github/workflows/export-smoke.yml）在 Linux 上用。
  python3 云端导出.py gen-ref --branch <分支>     用哪份转换产物（同 云端选测.py：分支自己的，没有就 main 的）→ GITHUB_OUTPUT ref
  python3 云端导出.py templates                  官方导出模板 tpz 下载、按 环境登记.json 的 SHA512／SHA256 校验，只解出要用的几个模板
                                                 （Windows 调试、安卓调试、Linux 调试＝包内检查用）→ GITHUB_OUTPUT dir
  python3 云端导出.py presets --templates <目录>  把 export_presets.cfg 里「Windows 验收」「安卓 验收」的模板路径改到 <目录>（只改 CI 的检出副本）
  python3 云端导出.py keystore                   生成一次性的安卓「调试」keystore（keytool），写进 GITHUB_ENV 的
                                                 GODOT_ANDROID_KEYSTORE_DEBUG_*；不碰发行 keystore，也不放任何发行签名材料
  python3 云端导出.py android-build --templates <目录>
                                                 安卓 Gradle 构建（cc 平台 android-bgidle1 2026-11-09）：把 android_source.zip 装成工程的
                                                 android/build（同编辑器「安装 Android 构建模板」），再用模板自带的 gradlew 编出后台挂机插件
                                                 addons/xiyou_export/android/xiyou_bgidle.aar（要 JDK 17、Android SDK 与外网下 Gradle 依赖）
要用的模板与安卓工具版本登记在 环境登记.json 的 cloudExport 段。
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PROJECT = ROOT / '01_Godot工程'
REGISTRY = HERE / '环境登记.json'
spec = importlib.util.spec_from_file_location('cloud', HERE / '云端选测.py')
cloud = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cloud)


def registry() -> dict:
    return json.loads(REGISTRY.read_text(encoding='utf-8'))


def cloud_export() -> dict:
    return registry()['cloudExport']


def tpz_entry(reg: dict) -> dict:
    for d in reg.get('downloads', []):
        if str(d.get('url', '')).endswith('_export_templates.tpz'):
            return d
    raise SystemExit('环境登记.json 里没有导出模板 tpz 的下载记录')


def digests(path: Path):
    h256, h512 = hashlib.sha256(), hashlib.sha512()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 22), b''):
            h256.update(chunk)
            h512.update(chunk)
    return h256.hexdigest(), h512.hexdigest()


def cmd_templates(a) -> int:
    reg = registry()
    conf = reg['cloudExport']
    ver = reg['templateVersion']
    dest = Path(a.dest or Path.home() / '.cache/xiyou-templates' / ver)
    want = conf['templates']
    if all((dest / n).is_file() for n in want):
        cloud.log('导出模板已在缓存：%s' % dest)
        cloud.gh_output(dir=str(dest))
        return 0
    entry = tpz_entry(reg)
    dest.mkdir(parents=True, exist_ok=True)
    tpz = dest / 'templates.tpz'
    try:
        cloud.download(entry['url'], tpz)
    except SystemExit:
        if not entry.get('mirror_url'):
            raise
        cloud.download(entry['mirror_url'], tpz)
    s256, s512 = digests(tpz)
    if s512 != entry['sha512'] or s256 != entry['sha256']:
        tpz.unlink()
        raise SystemExit('导出模板 tpz 校验不符：sha256 %s／sha512 %s…（登记 %s／%s…）' % (s256, s512[:16], entry['sha256'], entry['sha512'][:16]))
    cloud.log('导出模板 tpz 校验通过（SHA256 %s，与登记一致）' % s256[:16])
    with zipfile.ZipFile(tpz) as z:
        for n in want:
            with z.open('templates/' + n) as src, open(dest / n, 'wb') as out:
                for chunk in iter(lambda: src.read(1 << 22), b''):
                    out.write(chunk)
            os.chmod(dest / n, 0o755)
    tpz.unlink()
    (dest / 'version.txt').write_text(ver + '\n')
    cloud.gh_output(dir=str(dest))
    return 0


def rewrite_presets(text: str, templates: Path, presets: dict) -> str:
    """把指定预设的 custom_template/debug|release 换成 templates 下的同名文件；其余原样。"""
    sections = re.split(r'(?m)^(?=\[preset\.)', text)
    names = {}
    for sec in sections:
        m = re.match(r'\[preset\.(\d+)\]\n', sec)
        if m:
            n = re.search(r'(?m)^name="([^"]*)"', sec)
            names[m.group(1)] = n.group(1) if n else ''
    out = []
    for sec in sections:
        m = re.match(r'\[preset\.(\d+)\.options\]\n', sec)
        if m and names.get(m.group(1)) in presets:
            files = presets[names[m.group(1)]]
            for kind in ('debug', 'release'):
                if kind in files:
                    sec = re.sub(r'(?m)^custom_template/%s=".*"$' % kind,
                                 'custom_template/%s="%s"' % (kind, (templates / files[kind]).as_posix()), sec)
        out.append(sec)
    return ''.join(out)


def cmd_presets(a) -> int:
    cfg = PROJECT / 'export_presets.cfg'
    before = cfg.read_text(encoding='utf-8')
    after = rewrite_presets(before, Path(a.templates), cloud_export()['presets'])
    cfg.write_text(after, encoding='utf-8')
    cloud.log('export_presets.cfg：%d 处模板路径改到 %s（只改 CI 检出副本）' % (
        sum(1 for x, y in zip(before.splitlines(), after.splitlines()) if x != y), a.templates))
    return 0


def cmd_keystore(a) -> int:
    path = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'xiyou-debug.keystore'
    password = secrets.token_hex(12)  # 一次性，只活在这次运行里
    if path.exists():
        path.unlink()
    java = os.environ.get('JAVA_HOME')
    keytool = str(Path(java) / 'bin' / 'keytool') if java else 'keytool'
    subprocess.run([keytool, '-genkeypair', '-v', '-keystore', str(path), '-storepass', password, '-keypass', password,
                    '-alias', 'androiddebugkey', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '3',
                    '-dname', 'CN=Android Debug,O=Android,C=US'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    env = os.environ.get('GITHUB_ENV')
    lines = 'GODOT_ANDROID_KEYSTORE_DEBUG_PATH=%s\nGODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey\nGODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=%s\n' % (path, password)
    if env:
        print('::add-mask::' + password)
        with open(env, 'a') as f:
            f.write(lines)
    cloud.log('调试 keystore 已生成（3 天有效、一次性密码）：%s' % path)
    return 0


def cmd_gen_ref(a) -> int:
    ref, commit = cloud.generated_ref(a.branch)
    if not ref:
        raise SystemExit('origin 上没有 refs/ci/generated/%s，也没有 main 的产物：先在 Mac 上 云端选测.py upload' % a.branch)
    cloud.log('转换产物：%s（%s）' % (ref, commit[:10]))
    cloud.gh_output(ref=ref, commit=commit)
    return 0


BGIDLE_SRC = PROJECT / 'addons' / 'xiyou_export' / 'android_src'
BGIDLE_AAR = PROJECT / 'addons' / 'xiyou_export' / 'android' / 'xiyou_bgidle.aar'


def install_build_template(source_zip: Path, project: Path, version: str) -> Path:
    """同编辑器「项目 → 安装 Android 构建模板」：解到 res://android/build，写 .build_version 与 .gdignore。返回 build 目录。"""
    import shutil
    android = project / 'android'
    build = android / 'build'
    if build.exists():
        shutil.rmtree(build)
    build.mkdir(parents=True)
    with zipfile.ZipFile(source_zip) as z:
        z.extractall(build)
    (android / '.build_version').write_text(version, encoding='utf-8')
    (build / '.gdignore').write_text('', encoding='utf-8')
    gradlew = build / 'gradlew'
    if gradlew.exists():
        os.chmod(gradlew, 0o755)
    return build


def cmd_android_build(a) -> int:
    import shutil
    import tempfile
    reg = registry()
    source = Path(a.templates) / 'android_source.zip'
    if not source.is_file():
        raise SystemExit('模板目录里没有 android_source.zip：环境登记.json cloudExport.templates 要列上它')
    build = install_build_template(source, PROJECT, reg['templateVersion'])
    cloud.log('Android 构建模板已装到 %s（%s）' % (build.relative_to(ROOT), reg['templateVersion']))
    godot_aar = build / 'libs' / 'release' / 'godot-lib.template_release.aar'
    tmp = Path(tempfile.mkdtemp(prefix='xiyou-godotlib-'))
    with zipfile.ZipFile(godot_aar) as z:
        jar = tmp / 'godot-lib-classes.jar'
        with z.open('classes.jar') as src, open(jar, 'wb') as out:
            shutil.copyfileobj(src, out)
    cmd = [str(build / 'gradlew'), '-p', str(BGIDLE_SRC), '--no-daemon', '--stacktrace', 'assembleRelease', '-PgodotJar=%s' % jar]
    cloud.log('编后台挂机插件：' + ' '.join(cmd))
    r = subprocess.run(cmd)
    if r.returncode != 0:
        raise SystemExit('后台挂机插件 Gradle 构建失败（退出码 %d）' % r.returncode)
    outs = sorted((BGIDLE_SRC / 'build' / 'outputs' / 'aar').glob('*release*.aar'))
    if not outs:
        raise SystemExit('Gradle 跑完了但没找到 release aar')
    BGIDLE_AAR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(outs[-1], BGIDLE_AAR)
    cloud.log('后台挂机插件：%s（%d KB）' % (BGIDLE_AAR.relative_to(ROOT), BGIDLE_AAR.stat().st_size // 1024))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('templates')
    p.add_argument('--dest')
    p.set_defaults(fn=cmd_templates)
    p = sub.add_parser('presets')
    p.add_argument('--templates', required=True)
    p.set_defaults(fn=cmd_presets)
    p = sub.add_parser('keystore')
    p.set_defaults(fn=cmd_keystore)
    p = sub.add_parser('android-build')
    p.add_argument('--templates', required=True)
    p.set_defaults(fn=cmd_android_build)
    p = sub.add_parser('gen-ref')
    p.add_argument('--branch', required=True)
    p.set_defaults(fn=cmd_gen_ref)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == '__main__':
    sys.exit(main())
