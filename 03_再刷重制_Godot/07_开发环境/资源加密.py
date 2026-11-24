#!/usr/bin/env python3
"""发行包资源加密（T452，cc 2026-11-24；Kyo 11-24「只做2」：只加密发行包，仓库照旧公开，不改 C++）。

三个「发行」预设开 Godot 资源包加密（AES-256，只加密文件、不加密目录：包内文件名单照旧可审计），范围＝ENC_INCLUDE
（脚本、json、场景、资源、cfg、remap）。导出要两样东西，缺一样就不出包：
  1. 密钥：64 位十六进制。放在私密设计仓 ~/Documents/xiyou-design-docs/发行密钥/pck_encryption_key.json（跟存档封存密钥同一处，
     随私密仓推送备份；换电脑 git pull 私密仓即可）；环境变量 XIYOU_PCK_KEY 可换文件位置；GitHub 上另存一份仓库 Secret
     GODOT_SCRIPT_ENCRYPTION_KEY（只给编模板的工作流用）。公开仓里不放：export_presets.cfg、脚本、工作流、文档都只写「从哪取」。
  2. 用同一把密钥编的导出模板：.github/workflows/encrypted-templates.yml 在 GitHub Actions 上编（macOS universal、Windows x86_64、
     安卓 arm64＋android_source.zip），本脚本 templates 子命令触发、前台等完、下载、解密、装到主工作区
     07_开发环境/导出模板/4.7.2.stable_aes/（不进 Git），并把模板 SHA256 与密钥指纹记回私密仓的密钥文件（验收第 9 条）。
日常改脚本、json、图不用重编模板；只有换密钥或升级 Godot 才重编。

  python3 资源加密.py status                 密钥在不在、指纹、模板装没装、模板里是不是这把密钥（不打印密钥）
  python3 资源加密.py templates [--run <号>]  触发工作流（推 ci-templates/<当前分支>）→ gh run watch 前台等 → 下载解密安装 → 校验
  python3 资源加密.py scan <包>…             逐个查发给玩家的产物：该加密的文件都加密了、包外没有明文副本、用密钥解得开
  python3 资源加密.py export-env             打印导出时要加的环境变量名（不打印值）

丢了密钥会怎样：已装的游戏照常玩，存档不受影响（存档封存是另一把密钥）；但新补丁没法再给旧整包用（补丁要用同一把密钥加密），
只能换新密钥、重编模板、出新整包让玩家重下。所以私密仓那份就是备份，别删；换密钥（--rotate 式）也只在出新整包时做。
防误提交：密钥只在仓库外的文件和环境变量里；export_presets.cfg 不写 script_encryption_key（Godot 会把它放进 .godot/export_credentials.cfg，
已 .gitignore）；测试资源加密.py 查预设、本工具、工作流里没有 64 位十六进制串，本机有密钥时再 git grep 整个公开仓不含它。
"""
import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
REMAKE = HERE.parent
ROOT = REMAKE.parent
PROJECT = REMAKE / '01_Godot工程'
ENV_KEY = 'GODOT_SCRIPT_ENCRYPTION_KEY'  # Godot 编辑器导出时读这个环境变量当密钥（不用写进预设）
KEY_FILE = Path(os.environ.get('XIYOU_PCK_KEY') or Path.home() / 'Documents' / 'xiyou-design-docs' / '发行密钥' / 'pck_encryption_key.json')
WORKFLOW = 'encrypted-templates.yml'
RELEASE_PRESETS = ('macOS 发行', 'Windows 发行', '安卓 发行')
# 加密范围（Godot 过滤写法，* 跨目录）：脚本（导出后是 .gdc＋.gd.remap）、json、场景与资源（导出后 .scn/.res）、cfg（类名缓存等）
ENC_INCLUDE = ['*.gd', '*.gdc', '*.json', '*.tscn', '*.scn', '*.tres', '*.res', '*.cfg', '*.remap']
ENC_INCLUDE_TEXT = ', '.join(ENC_INCLUDE)
ENC_SEED = 452452  # 非 0：IV 由内容和种子算出，同样的内容每次导出逐字节一样（一个补丁三端通用，见 发布补丁.py）
TEMPLATE_VERSION = '4.7.2.stable'
TEMPLATE_FILES = {
    'macOS 发行': 'macos.zip',
    'Windows 发行': 'windows_release_x86_64.exe',
    '安卓 发行': 'android_release.apk',
}
ANDROID_SOURCE = 'android_source.zip'
FINGERPRINT_FILE = 'key_fingerprint.txt'
ENCRYPT = True  # 回退开关：False＝发行预设在导出用的工程副本里去掉加密（照旧明文包；模板照样能跑明文包）


def main_root() -> Path:
    try:
        common = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', '--path-format=absolute', '--git-common-dir'],
                                capture_output=True, text=True, check=True).stdout.strip()
        return Path(common).parent
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ROOT


def template_dir() -> Path:
    env = os.environ.get('XIYOU_AES_TEMPLATES')
    if env:
        return Path(env)
    return main_root() / '03_再刷重制_Godot' / '07_开发环境' / '导出模板' / f'{TEMPLATE_VERSION}_aes'


# ---- 密钥 ----

def load_key_hex() -> str:
    """密钥（64 位小写十六进制）；环境变量优先，其次私密仓的密钥文件。没有返回空串。"""
    k = os.environ.get(ENV_KEY, '').strip().lower()
    if not k and KEY_FILE.is_file():
        try:
            k = str(json.loads(KEY_FILE.read_text(encoding='utf-8')).get('key', '')).strip().lower()
        except ValueError:
            k = ''
    if len(k) != 64 or any(c not in '0123456789abcdef' for c in k):
        return ''
    return k


def load_key() -> bytes:
    k = load_key_hex()
    return bytes.fromhex(k) if k else b''


def fingerprint(key: bytes) -> str:
    return hashlib.sha256(key).hexdigest()[:16]


def export_env(env: dict = None) -> dict:
    """导出用的环境：带上密钥。没密钥抛错（不许静默出明文包）。"""
    k = load_key_hex()
    if not k:
        raise RuntimeError(f'没有资源加密密钥（{KEY_FILE.name} 不在私密设计仓，也没设环境变量 {ENV_KEY}）')
    out = dict(os.environ if env is None else env)
    out[ENV_KEY] = k
    return out


# ---- 解密（Godot FileAccessEncrypted：md5(16)＋长度(8)＋IV(16)＋AES-256-CFB 数据，补齐到 16 字节）----

def decrypt(data: bytes, key: bytes) -> bytes:
    """解一个加密文件；密钥不对或文件坏了抛 ValueError。"""
    if len(key) != 32:
        raise ValueError('没有密钥')
    if len(data) < 40:
        raise ValueError('太短，不是加密文件')
    md5d = data[:16]
    n, = struct.unpack('<Q', data[16:24])
    iv = data[24:40]
    ds = (n + 15) // 16 * 16
    body = data[40:40 + ds]
    if len(body) != ds:
        raise ValueError('长度不对，不是加密文件')
    p = subprocess.run(['openssl', 'enc', '-d', '-aes-256-cfb', '-K', key.hex(), '-iv', iv.hex(), '-nopad'],
                       input=body, capture_output=True)
    if p.returncode != 0:
        raise ValueError('openssl 解密失败：' + p.stderr.decode(errors='replace')[-200:])
    out = p.stdout[:n]
    if hashlib.md5(out).digest() != md5d:
        raise ValueError('MD5 对不上：密钥不对或文件坏了')
    return out


# ---- 模板 ----

def template_has_key(path: Path, key: bytes) -> bool:
    """模板（或 zip／apk 里的可执行文件、.so、aar）里有没有这 32 字节密钥。Godot 把密钥原样编进 script_encryption_key[32]。"""
    def in_zip(z: zipfile.ZipFile) -> bool:
        for info in z.infolist():
            name = info.filename
            if name.endswith(('.so', '.universal', '.exe')) or 'MacOS/' in name:
                if key in z.read(info):
                    return True
            elif name.endswith(('.aar', '.zip', '.apk')):
                import io
                with zipfile.ZipFile(io.BytesIO(z.read(info))) as inner:
                    if in_zip(inner):
                        return True
        return False
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            return in_zip(z)
    return key in Path(path).read_bytes()


def template_problems(key: bytes = None, need=('macOS 发行', 'Windows 发行', '安卓 发行')) -> list:
    """导出前查：密钥在、模板装了、模板里编的就是这把密钥。返回问题（空＝可以导）。"""
    key = load_key() if key is None else key
    if not key:
        return [f'没有资源加密密钥（{KEY_FILE.name} 不在私密设计仓，也没设环境变量 {ENV_KEY}）：先 git pull 私密设计仓']
    d = template_dir()
    out = []
    fp = d / FINGERPRINT_FILE
    if not fp.is_file():
        return [f'加密导出模板没装（{d}）：先跑 资源加密.py templates']
    if fp.read_text(encoding='utf-8').strip() != fingerprint(key):
        out.append(f'加密导出模板是另一把密钥编的（指纹 {fp.read_text(encoding="utf-8").strip()}，当前密钥 {fingerprint(key)}）：重跑 资源加密.py templates')
    files = [TEMPLATE_FILES[p] for p in need] + ([ANDROID_SOURCE] if '安卓 发行' in need else [])
    for f in files:
        p = d / f
        if not p.is_file():
            out.append(f'缺加密导出模板 {f}')
        elif not out and not template_has_key(p, key):
            out.append(f'加密导出模板 {f} 里找不到这把密钥（不是用它编的）')
    return out


def _run(cmd, **kw):
    print('  $ ' + ' '.join(str(c) for c in cmd))
    return subprocess.run(cmd, **kw)


def cmd_templates(a) -> int:
    key = load_key()
    if not key:
        print(f'✗ 没有密钥：{KEY_FILE}')
        return 1
    repo = ROOT
    run_id = a.run
    if a.from_dir:
        return install(run_id or 'local', key, repo, Path(a.from_dir))
    if not run_id:
        branch = subprocess.run(['git', '-C', str(repo), 'rev-parse', '--abbrev-ref', 'HEAD'], capture_output=True, text=True).stdout.strip()
        head = subprocess.run(['git', '-C', str(repo), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
        ref = f'ci-templates/{branch.split("/")[-1]}'
        remote = a.remote
        if _run(['git', '-C', str(repo), 'push', '-f', remote, f'HEAD:refs/heads/{ref}']).returncode:
            return 1
        import time
        for _ in range(30):
            time.sleep(10)
            r = subprocess.run(['gh', 'run', 'list', '--workflow', WORKFLOW, '--branch', ref, '--limit', '5', '--json', 'databaseId,headSha'],
                               capture_output=True, text=True, cwd=repo)
            runs = [x for x in json.loads(r.stdout or '[]') if x['headSha'] == head]
            if runs:
                run_id = str(runs[0]['databaseId'])
                break
        if not run_id:
            print('✗ 等了 5 分钟没看到工作流运行')
            return 1
    print(f'== 工作流运行 {run_id}：前台等完（约 1～2 小时）')
    w = _run(['gh', 'run', 'watch', run_id, '--exit-status', '--interval', '60'], cwd=repo, stdout=subprocess.DEVNULL)
    if w.returncode:
        print(f'✗ 工作流没全过（gh run view {run_id} --log-failed）')
        return 1
    return install(run_id, key, repo)


def install(run_id: str, key: bytes, repo: Path, from_dir: Path = None) -> int:
    dest = template_dir()
    with tempfile.TemporaryDirectory(prefix='aes_tpl_') as td:
        td = Path(td)
        got = td / 'dl'
        if from_dir:
            got = Path(from_dir)
        elif _run(['gh', 'run', 'download', run_id, '--dir', str(got)], cwd=repo).returncode:
            return 1
        stage = td / 'stage'
        stage.mkdir()
        env = dict(os.environ, K=key.hex())
        for enc in sorted(got.rglob('tpl-*.tar.enc')):
            tar = td / enc.with_suffix('').name
            if subprocess.run(['openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-pass', 'env:K',
                               '-in', str(enc), '-out', str(tar)], env=env).returncode:
                print(f'✗ 解不开 {enc.name}（附件不是这把密钥加密的）')
                return 1
            subprocess.run(['tar', '-xf', str(tar), '-C', str(stage)], check=True)
        for wk in list(got.rglob('macos_wrongkey.zip')):
            shutil.copyfile(wk, stage / wk.name)
        (stage / FINGERPRINT_FILE).write_text(fingerprint(key) + '\n', encoding='utf-8')
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.exists():
            old = dest.with_name(dest.name + '.old')
            shutil.rmtree(old, ignore_errors=True)
            dest.rename(old)
        shutil.copytree(stage, dest)
    bad = template_problems(key)
    if bad:
        print('✗ ' + '；'.join(bad))
        return 1
    record_templates(run_id, key)
    print(f'✓ 加密导出模板已装到 {dest}（密钥指纹 {fingerprint(key)}）')
    return 0


def record_templates(run_id: str, key: bytes) -> None:
    """把模板 SHA256、工作流运行号记回私密仓的密钥文件（密钥与模板版本的对应关系，验收第 9 条）。"""
    if not KEY_FILE.is_file():
        return
    d = json.loads(KEY_FILE.read_text(encoding='utf-8'))
    if d.get('key', '').lower() != key.hex():
        return
    files = {}
    for p in sorted(template_dir().iterdir()):
        if p.is_file() and p.name != FINGERPRINT_FILE:
            files[p.name] = sha256(p)
    d.setdefault('templates', {})[TEMPLATE_VERSION] = {'workflow_run': run_id, 'files': files}
    KEY_FILE.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


# ---- 预设 ----

def preset_sections(text: str) -> dict:
    """export_presets.cfg：预设名 → 段号。"""
    import re
    out = {}
    cur = None
    for line in text.splitlines():
        m = re.match(r'^\[preset\.(\d+)\]$', line)
        if m:
            cur = m.group(1)
        m = re.match(r'^name="(.*)"$', line)
        if m and cur is not None:
            out[m.group(1)] = cur
    return out


def preset_value(text: str, preset: str, key: str, options: bool = False):
    """预设 [preset.N] 段（options＝True 时 [preset.N.options] 段，模板路径、包名等在那里）里 key 的原样值；没有返回 None。"""
    import re
    sec = preset_sections(text).get(preset)
    if sec is None:
        return None
    m = re.search(r'^\[preset\.' + sec + (r'\.options' if options else '') + r'\]\n(.*?)(?=^\[)', text + '\n[', re.M | re.S)
    body = m.group(1) if m else ''
    m = re.search(r'^' + re.escape(key) + r'=(.*)$', body, re.M)
    return m.group(1) if m else None


def strip_encryption(cfg: Path) -> None:
    """回退（ENCRYPT=False）：导出用的工程副本里把发行预设的 encrypt_pck 关掉。只改副本。"""
    import re
    t = cfg.read_text(encoding='utf-8')
    t = re.sub(r'^encrypt_pck=true$', 'encrypt_pck=false', t, flags=re.M)
    cfg.write_text(t, encoding='utf-8')


# ---- 查包：该加密的都加密了、包外没有明文副本 ----

def must_encrypt(path: str) -> bool:
    p = path.removeprefix('res://').lstrip('/')
    return any(fnmatch.fnmatchcase(p.lower(), pat) for pat in ENC_INCLUDE)


def stored_size(size: int, flags: int) -> int:
    """pck 目录记的是原文长度；加密的文件实际占 40 字节头＋补齐到 16 的密文。"""
    return 40 + (size + 15) // 16 * 16 if flags & 1 else size


def pck_entries(f, base: int) -> dict:
    """pck 目录：文件名 → (绝对偏移, 在包里实际占的字节数, 标志)。目录加密的读不了（本项目不加密目录）。"""
    f.seek(base)
    if f.read(4) != b'GDPC':
        raise ValueError('不是 Godot pck')
    ver, _maj, _min, _pat, flags, fbase = struct.unpack('<IIIIIQ', f.read(28))
    if flags & 1:
        raise ValueError('pck 目录加密了，读不了名单')
    if ver >= 3:
        diroff, = struct.unpack('<Q', f.read(8))
        f.seek(base + diroff)
    else:
        f.read(64)
    n, = struct.unpack('<I', f.read(4))
    out = {}
    for _ in range(n):
        ln, = struct.unpack('<I', f.read(4))
        name = f.read(ln).rstrip(b'\0').decode('utf-8', 'replace')
        ofs, size = struct.unpack('<QQ', f.read(16))
        f.read(16)
        fl = struct.unpack('<I', f.read(4))[0] if ver >= 2 else 0
        out[name.removeprefix('res://')] = (base + fbase + ofs if ver >= 2 else ofs, stored_size(size, fl), fl)
    return out


def pck_raw_entries(f, base: int = 0) -> list:
    """pck 目录原样：[(名字, 偏移, 原文长度, md5, 标志)]（安卓 sparsepck 转桌面 pck 用）。"""
    f.seek(base)
    if f.read(4) != b'GDPC':
        raise ValueError('不是 Godot pck')
    ver, _maj, _min, _pat, flags, _fbase = struct.unpack('<IIIIIQ', f.read(28))
    if flags & 1 or ver < 3:
        raise ValueError('只认目录不加密的 v3／v4 pck')
    diroff, = struct.unpack('<Q', f.read(8))
    f.seek(base + diroff)
    n, = struct.unpack('<I', f.read(4))
    out = []
    for _ in range(n):
        ln, = struct.unpack('<I', f.read(4))
        name = f.read(ln).rstrip(b'\0').decode('utf-8')
        ofs, size = struct.unpack('<QQ', f.read(16))
        md5 = f.read(16)
        fl, = struct.unpack('<I', f.read(4))
        out.append((name, ofs, size, md5, fl))
    return out


def zip_name(info: zipfile.ZipInfo) -> str:
    """zip 条目的真名。Godot／Gradle 打的 apk 不设 UTF-8 标志，Python 按 cp437 解中文名会成乱码、对不上资源目录（T452 实测
    movies/幻术世界.json）：没标志时按 UTF-8 重解，解不了才用原样。"""
    n = info.filename
    if info.flag_bits & 0x800:
        return n
    try:
        return n.encode('cp437').decode('utf-8')
    except (UnicodeEncodeError, UnicodeDecodeError):
        return n


def zip_index(z: zipfile.ZipFile) -> dict:
    """真名 → ZipInfo。"""
    return {zip_name(i): i for i in z.infolist()}


# apk 根目录里 Gradle／Kotlin 构建工具自己写的元数据（不是游戏数据），不算包外明文
APK_BUILD_METADATA = {'kotlin-tooling-metadata.json'}


def apk_to_pck(apk: Path, out: Path, ver=(4, 7, 2)) -> int:
    """安卓包 assets/ 按 assets.sparsepck 的目录原样拼成桌面 pck（加密文件保持加密、标志照抄），给 macOS 发行模板当替身跑。
    返回文件数。旧的明文安卓包（没有 sparsepck）不走这里。"""
    import io
    with zipfile.ZipFile(apk) as z:
        ents = pck_raw_entries(io.BytesIO(z.read(SPARSE)))
        idx = zip_index(z)
        with open(out, 'wb') as f:
            hdr = b'GDPC' + struct.pack('<IIIII', 3, *ver, 2)  # 版本 3，PACK_REL_FILEBASE
            f.write(hdr + b'\0' * 16 + b'\0' * 32)
            fbase = f.tell()
            rows = []
            for name, _o, size, md5, fl in ents:
                if fl & 2:
                    continue
                data = z.read(idx['assets/' + name])
                rows.append((name, f.tell() - fbase, size, md5, fl))
                f.write(data)
                f.write(b'\0' * ((-f.tell()) % 32))
            diroff = f.tell()
            f.write(struct.pack('<I', len(rows)))
            for name, ofs, size, md5, fl in rows:
                b = name.encode('utf-8')
                b += b'\0' * ((-len(b)) % 4)
                f.write(struct.pack('<I', len(b)) + b + struct.pack('<QQ', ofs, size) + md5 + struct.pack('<I', fl & ~4))
            f.seek(len(hdr))
            f.write(struct.pack('<QQ', fbase, diroff))
    return len(rows)


def pck_base(f, path) -> int:
    f.seek(0)
    if f.read(4) == b'GDPC':
        return 0
    f.seek(-12, 2)
    size, = struct.unpack('<Q', f.read(8))
    if f.read(4) != b'GDPC':
        raise ValueError(f'{Path(path).name} 里找不到 pck')
    f.seek(-12 - size, 2)
    return f.tell()


SPARSE = 'assets/assets.sparsepck'


def apk_flags(z: zipfile.ZipFile) -> dict:
    """安卓包：assets.sparsepck 目录里的 文件名 → 标志（加密＝1）。没有 sparsepck（旧包）返回空。"""
    if SPARSE not in z.namelist():
        return {}
    import io
    f = io.BytesIO(z.read(SPARSE))
    return {n: fl for n, (_o, _s, fl) in pck_entries(f, 0).items()}


def scan(path: Path, key: bytes = None, sample: int = 20) -> list:
    """一个发给玩家的产物：该加密的文件都加了密、包外没有脚本／json 明文副本、抽 sample 个加密文件用密钥解得开。返回问题。"""
    key = load_key() if key is None else key
    path = Path(path)
    probs = []
    enc_seen = []

    def check_pck(fp, label):
        with open(fp, 'rb') as f:
            ents = pck_entries(f, pck_base(f, fp))
            for n, (ofs, size, fl) in sorted(ents.items()):
                if fl & 2:  # 补丁里的「删除」条目，没有内容
                    continue
                if must_encrypt(n) and not fl & 1:
                    probs.append(f'{label}：{n} 没加密')
                elif fl & 1:
                    enc_seen.append((label, n, fp, ofs, size))

    suf = path.suffix.lower()
    if suf == '.apk':
        with zipfile.ZipFile(path) as z:
            flags = apk_flags(z)
            if not flags:
                probs.append(f'{path.name}：没有 assets.sparsepck（不是 Godot 4.7 安卓包，或没导出数据）')
            for info in z.infolist():
                n = zip_name(info)
                if n.startswith('assets/'):
                    rel = n[len('assets/'):]
                    if n == SPARSE:
                        continue
                    if rel not in flags and must_encrypt(rel):
                        probs.append(f'{path.name}：{n} 在 assets/ 里但不在资源目录里（包外明文副本）')
                    elif must_encrypt(rel) and not flags.get(rel, 0) & 1:
                        probs.append(f'{path.name}：{n} 没加密')
                    elif flags.get(rel, 0) & 1:
                        enc_seen.append((path.name, rel, None, info, info.file_size))
                elif n.lower().endswith(('.gd', '.gdc', '.json', '.tscn', '.tres', '.scn', '.res', '.cfg', '.remap')) and n not in APK_BUILD_METADATA:
                    probs.append(f'{path.name}：{n} 是 assets/ 外的脚本／数据明文')
            n_seen = len(enc_seen)
            picks = enc_seen if n_seen <= sample else [enc_seen[i * n_seen // sample] for i in range(sample)]
            for label, rel, _fp, n, _size in picks:
                _try(probs, label, rel, z.read(n), key)
        return probs
    if suf == '.zip':
        with zipfile.ZipFile(path) as z, tempfile.TemporaryDirectory() as td:
            pcks = 0
            for info in z.infolist():
                n = zip_name(info)
                if n.lower().endswith('.pck') and '__MACOSX' not in n:
                    pcks += 1
                    check_pck(Path(z.extract(info, td)), f'{path.name}:{Path(n).name}')
                elif must_encrypt(n) and not n.endswith(('Info.plist',)):
                    probs.append(f'{path.name}：{n} 是包外明文（zip 里 pck 以外的脚本／数据）')
            if not pcks:
                probs.append(f'{path.name} 里没有 .pck')
            _sample(probs, enc_seen, key, sample)
        return probs
    check_pck(path, path.name)
    _sample(probs, enc_seen, key, sample)
    return probs


def _sample(probs, enc_seen, key, sample):
    n_seen = len(enc_seen)
    picks = enc_seen if n_seen <= sample else [enc_seen[i * n_seen // sample] for i in range(sample)]  # 均匀步长，首尾都覆盖到
    for label, n, fp, ofs, size in picks:
        with open(fp, 'rb') as f:
            f.seek(ofs)
            _try(probs, label, n, f.read(size), key)


def _try(probs, label, n, blob, key):
    if not key:
        probs.append(f'{label}：没有密钥，解不了 {n} 来核对')
        return
    try:
        decrypt(blob, key)
    except ValueError as e:
        probs.append(f'{label}：{n} 用密钥解不开（{e}）')


def cmd_scan(a) -> int:
    key = load_key()
    bad = 0
    for p in a.pkgs:
        v = scan(Path(p), key)
        if v:
            bad += 1
            print(f'✗ {p}：{len(v)} 个问题')
            for x in v[:40]:
                print('   ' + x)
        else:
            print(f'✓ {p}：该加密的都加密了，没有包外明文，抽查解得开')
    return 1 if bad else 0


def cmd_status(_a) -> int:
    key = load_key()
    print(f'密钥：{"有，指纹 " + fingerprint(key) if key else "没有"}（{KEY_FILE}；环境变量 {ENV_KEY} 优先）')
    print(f'模板目录：{template_dir()}')
    bad = template_problems(key)
    print('模板：' + ('✓ 装好了、都是这把密钥编的' if not bad else '✗ ' + '；'.join(bad)))
    return 1 if bad else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    p = sub.add_parser('status')
    p.set_defaults(fn=cmd_status)
    p = sub.add_parser('templates')
    p.add_argument('--run', help='不触发新运行，直接装这个运行号的产物')
    p.add_argument('--remote', default='github')
    p.add_argument('--from-dir', help='已用 gh run download 下好的附件目录（不再下载，配 --run 记运行号）')
    p.set_defaults(fn=cmd_templates)
    p = sub.add_parser('scan')
    p.add_argument('pkgs', nargs='+')
    p.set_defaults(fn=cmd_scan)
    p = sub.add_parser('export-env')
    p.set_defaults(fn=lambda _a: print(ENV_KEY) or 0)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == '__main__':
    sys.exit(main())
