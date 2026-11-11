#!/usr/bin/env python3
"""生成更新清单（cc pro-update-manifest，2026-11-11）：比较新旧两个版本目录，写出补丁文件清单并签名。

  python3 生成更新清单.py --old <旧版本目录> --new <新版本目录> --key <私钥.pem> --out <输出目录>
  python3 生成更新清单.py --verify <输出目录>/patch_manifest.json --pubkey <公钥.pem> [--new <新版本目录>]

输出（都在 --out 下）：
  patch_manifest.json   补丁文件列表（新增、改动的文件：路径、字节数、SHA-256）、删掉的文件、版本号、底包号、最低基线版本
  patch_manifest.sig    对 patch_manifest.json 原始字节的 SHA256withRSA 签名（与 channel.sig 同一算法，openssl 出）
  patch_files.txt       只列要进补丁的文件路径，一行一个（给人看、给导出补丁核对用）

版本目录：一个版本的工程目录（或解开的包内容），里面有 content/build_info.json 就从它读开发编号；没有时用
--old-code／--new-code 给。旧目录就是这个补丁要叠上去的底包。

最低基线版本 min_base：低于它的底包不能装这个补丁、要去下整包。默认等于旧目录的编号；可用 --min-base 调低
（更老的底包另有自己的补丁时），不能高于旧目录的编号。另外两道门：
  - 旧目录里要有补丁载入器（core/boot_patch.gd，或导出后的 .gdc／.remap）；没有的（dev384 那种）装不了补丁，
    首个可打补丁的基线是合并自动更新之后出的下一个整包。
  - --first-patchable <号>：已知首个可打补丁整包的编号时给上，min_base 和旧目录编号都不能低于它。

私钥只用 --key 传入（也认环境变量 XIYOU_UPDATE_KEY），没有默认位置；私钥放在本仓库里会被拒绝。签完立即用私钥对应的
公钥验一次。新目录里有 core/update_check.gd 时，再核对私钥对应的公钥等于游戏内嵌的那把（--skip-embedded-check 跳过，
只在用临时密钥试的时候用）。--unsigned 只出清单不签名（预览用，不能发）。

默认排除 .git/、.godot/、__pycache__/、.DS_Store、Thumbs.db；--exclude <通配>（可多次，按相对路径匹配，目录写 名字/）
再加。符号链接一律拒绝。路径统一成 NFC（Mac 上的中文文件名是 NFD，不统一会被当成改名）。

本工具不联网、不推送、不碰发版仓库，也不导出 .pck。玩家客户端读的是 发布补丁.py 写的 channel.json；
本清单是那一步之前的「这次补丁到底改了哪些文件」，用来核对导出的补丁、存档和交叉核查。使用说明见
05_发布/更新清单生成说明.md。
"""
import argparse
import datetime
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unicodedata

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
SCHEMA = 1
KIND = 'xiyou-patch-files'
MANIFEST = 'patch_manifest.json'
SIG = 'patch_manifest.sig'
FILES_TXT = 'patch_files.txt'
BUILD_INFO = 'content/build_info.json'
LOADER = ('core/boot_patch.gd', 'core/boot_patch.gdc', 'core/boot_patch.gd.remap')
DEFAULT_EXCLUDES = ('.git/', '.godot/', '__pycache__/', '.DS_Store', 'Thumbs.db')


class Fail(Exception):
    pass


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def norm(rel: str) -> str:
    return unicodedata.normalize('NFC', rel)


def excluded(rel: str, patterns) -> bool:
    parts = rel.split('/')
    for pat in patterns:
        if pat.endswith('/'):
            name = pat[:-1]
            if any(fnmatch.fnmatchcase(p, name) for p in parts[:-1]) or fnmatch.fnmatchcase(rel, name + '/*'):
                return True
        elif fnmatch.fnmatchcase(rel, pat) or fnmatch.fnmatchcase(parts[-1], pat):
            return True
    return False


def scan(root: Path, patterns) -> dict:
    """{NFC 相对路径: 绝对路径}。符号链接、NFC 后撞名都报错。"""
    if not root.is_dir():
        raise Fail(f'不是目录：{root}')
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        d = Path(dirpath)
        for name in list(dirnames):
            if (d / name).is_symlink():
                raise Fail(f'{root} 里有符号链接（目录）：{(d / name).relative_to(root)}')
        dirnames.sort()
        for name in sorted(filenames):
            p = d / name
            rel = norm(p.relative_to(root).as_posix())
            if excluded(rel, patterns):
                continue
            if p.is_symlink():
                raise Fail(f'{root} 里有符号链接：{rel}')
            if rel in out:
                raise Fail(f'{root} 里有两个文件名统一成 NFC 后相同：{rel}')
            out[rel] = p
        dirnames[:] = [n for n in dirnames if not excluded(norm((d / n).relative_to(root).as_posix()) + '/x', patterns)]
    return out


def read_code(root: Path, given):
    if given is not None:
        return int(given)
    bi = root / BUILD_INFO
    if not bi.is_file():
        raise Fail(f'{root} 里没有 {BUILD_INFO}，用 --old-code／--new-code 给编号')
    v = str(json.loads(bi.read_text(encoding='utf-8')).get('developmentVersion', ''))
    m = re.fullmatch(r'(?:dev\.)?(\d+)', v)
    if not m:
        raise Fail(f'{bi} 的 developmentVersion 读不出编号：{v!r}')
    return int(m.group(1))


def has_loader(root: Path) -> bool:
    return any((root / p).is_file() for p in LOADER)


def inside_repo(p: Path) -> bool:
    try:
        p.resolve().relative_to(REPO.resolve())
        return True
    except ValueError:
        return False


def openssl(*args, text=True):
    return subprocess.run(['openssl', *args], capture_output=True, text=text)


def public_of(key: Path) -> str:
    p = openssl('pkey', '-in', str(key), '-pubout')
    if p.returncode != 0:
        raise Fail(f'读不了私钥 {key}：{p.stderr.strip()[:200]}')
    return p.stdout.strip()


def pub_from_file(pem: Path) -> str:
    p = openssl('pkey', '-pubin', '-in', str(pem), '-pubout')
    if p.returncode != 0:
        raise Fail(f'读不了公钥 {pem}：{p.stderr.strip()[:200]}')
    return p.stdout.strip()


def sign(key: Path, data: Path, sig: Path) -> None:
    p = openssl('dgst', '-sha256', '-sign', str(key), '-out', str(sig), str(data))
    if p.returncode != 0:
        raise Fail(f'签名失败：{p.stderr.strip()[:200]}')


def verify_sig(pub_pem: str, data: Path, sig: Path) -> bool:
    with tempfile.NamedTemporaryFile('w', suffix='.pem', delete=False) as f:
        f.write(pub_pem + '\n')
    try:
        return openssl('dgst', '-sha256', '-verify', f.name, '-signature', str(sig), str(data)).returncode == 0
    finally:
        os.unlink(f.name)


def embedded_public_key(root: Path):
    src = root / 'core/update_check.gd'
    if not src.is_file():
        return None
    m = re.search(r'-----BEGIN PUBLIC KEY-----.*?-----END PUBLIC KEY-----', src.read_text(encoding='utf-8'), re.S)
    return m.group(0).strip() if m else None


def same_key(a: str, b: str) -> bool:
    return ''.join(a.split()) == ''.join(b.split())


def diff(old: dict, new: dict):
    files, removed = [], []
    for rel in sorted(new):
        p = new[rel]
        h = sha256(p)
        if rel not in old:
            change = 'added'
        elif old[rel].stat().st_size != p.stat().st_size or sha256(old[rel]) != h:
            change = 'modified'
        else:
            continue
        files.append({'path': rel, 'change': change, 'size': p.stat().st_size, 'sha256': h})
    removed = sorted(set(old) - set(new))
    return files, removed


def build(a) -> dict:
    old_root, new_root = Path(a.old).expanduser(), Path(a.new).expanduser()
    if old_root.resolve() == new_root.resolve():
        raise Fail('--old 和 --new 是同一个目录')
    old_code, new_code = read_code(old_root, a.old_code), read_code(new_root, a.new_code)
    if new_code <= old_code:
        raise Fail(f'新版本编号 {new_code} 不比旧版本 {old_code} 大')
    if not has_loader(old_root) and not a.allow_no_loader:
        raise Fail(f'旧版本目录（{old_code}）里没有补丁载入器 core/boot_patch.gd：这个底包装不了补丁。'
                   '首个可打补丁的基线是合并自动更新之后出的下一个整包')
    min_base = old_code if a.min_base is None else a.min_base
    if min_base > old_code:
        raise Fail(f'最低基线 {min_base} 高于这个补丁的底包 {old_code}：底包自己都装不上')
    if a.first_patchable is not None:
        for what, v in (('旧版本编号', old_code), ('最低基线', min_base)):
            if v < a.first_patchable:
                raise Fail(f'{what} {v} 低于首个可打补丁的整包 {a.first_patchable}')
    patterns = list(DEFAULT_EXCLUDES) + list(a.exclude or [])
    files, removed = diff(scan(old_root, patterns), scan(new_root, patterns))
    if not files and not removed:
        raise Fail('新旧两个目录没有差别，没有补丁可出')
    return {
        'schema': SCHEMA,
        'kind': KIND,
        'version': f'0.{new_code}',
        'code': new_code,
        'base_code': old_code,
        'min_base': min_base,
        'date': a.date or datetime.date.today().isoformat(),
        'files': files,
        'removed': removed,
        'total': {'files': len(files), 'bytes': sum(f['size'] for f in files), 'removed': len(removed)},
        'excludes': patterns,
    }


def generate(a) -> int:
    if not a.old or not a.new or not a.out:
        raise Fail('要给 --old、--new、--out')
    key = None
    if not a.unsigned:
        k = a.key or os.environ.get('XIYOU_UPDATE_KEY')
        if not k:
            raise Fail('要用 --key 给签名私钥路径（或设 XIYOU_UPDATE_KEY）；只想预览加 --unsigned')
        key = Path(k).expanduser()
        if inside_repo(key):
            raise Fail(f'私钥 {key} 在游戏仓库里面：私钥只能放仓库外，挪走后再签')
        if not key.is_file():
            raise Fail(f'私钥不存在：{key}')
    out = Path(a.out).expanduser()
    if inside_repo(out):
        ig = subprocess.run(['git', '-C', str(REPO), 'check-ignore', '-q', str(out.resolve() / MANIFEST)])
        if ig.returncode != 0:
            raise Fail(f'输出目录 {out} 在仓库里且没被 .gitignore 忽略，换到仓库外或 05_发布/补丁/ 下')
    manifest = build(a)
    pub = None
    if key:
        pub = public_of(key)
        emb = embedded_public_key(Path(a.new).expanduser())
        if emb and not a.skip_embedded_check and not same_key(pub, emb):
            raise Fail('私钥对应的公钥和新版本里内嵌的（core/update_check.gd 的 PUBLIC_KEY）不是同一把')
    out.mkdir(parents=True, exist_ok=True)
    mj = out / MANIFEST
    mj.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    (out / FILES_TXT).write_text(''.join(f['path'] + '\n' for f in manifest['files']), encoding='utf-8')
    sig = out / SIG
    if key:
        sign(key, mj, sig)
        if not verify_sig(pub, mj, sig):
            raise Fail('签完用公钥验不过')
    elif sig.exists():
        sig.unlink()  # 不留上一次的旧签名，免得它和新清单配不上还被当真
    t = manifest['total']
    print(f'· 0.{manifest["base_code"]} → {manifest["version"]}：补丁 {t["files"]} 个文件（{t["bytes"] / 1e6:.2f} MB），'
          f'删掉 {t["removed"]} 个；最低基线 {manifest["min_base"]}')
    print(f'· 写了 {mj}' + (f'、{sig.name}（已验签）' if key else '（没签名，只能预览，不能发）') + f'、{FILES_TXT}')
    return 0


def verify_cmd(a) -> int:
    mj = Path(a.verify).expanduser()
    sig = mj.with_name(SIG)
    if not a.pubkey:
        raise Fail('--verify 要配 --pubkey <公钥.pem>')
    if not sig.is_file():
        raise Fail(f'没有签名文件 {sig}')
    if not verify_sig(pub_from_file(Path(a.pubkey).expanduser()), mj, sig):
        print('✗ 验签不过')
        return 1
    m = json.loads(mj.read_text(encoding='utf-8'))
    if m.get('schema') != SCHEMA or m.get('kind') != KIND:
        raise Fail('验签过了，但不是认识的补丁文件清单')
    print(f'✓ 验签通过：{m["version"]}，底包 {m["base_code"]}，最低基线 {m["min_base"]}，{len(m["files"])} 个文件')
    if a.new:
        root, bad = Path(a.new).expanduser(), 0
        for f in m['files']:
            p = root / f['path']
            if not p.is_file() or p.stat().st_size != f['size'] or sha256(p) != f['sha256']:
                print(f'  ✗ {f["path"]} 和清单不符')
                bad += 1
        for rel in m['removed']:
            if (root / rel).exists():
                print(f'  ✗ {rel} 清单说已删，目录里还在')
                bad += 1
        print('✓ 新版本目录与清单一致' if bad == 0 else f'✗ {bad} 处不符')
        return 0 if bad == 0 else 1
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description='比较新旧版本目录，写补丁文件清单并签名')
    ap.add_argument('--old', help='旧版本（底包）目录')
    ap.add_argument('--new', help='新版本目录')
    ap.add_argument('--out', help='输出目录（放仓库外，或仓库里被忽略的 05_发布/补丁/ 下）')
    ap.add_argument('--key', help='签名私钥 .pem 路径（仓库外；也认环境变量 XIYOU_UPDATE_KEY）')
    ap.add_argument('--unsigned', action='store_true', help='只出清单不签名（预览）')
    ap.add_argument('--old-code', type=int, help='旧版本开发编号（目录里没有 build_info.json 时）')
    ap.add_argument('--new-code', type=int, help='新版本开发编号')
    ap.add_argument('--min-base', type=int, help='最低基线版本（默认等于旧版本编号）')
    ap.add_argument('--first-patchable', type=int, help='首个可打补丁整包的编号（知道了就给上）')
    ap.add_argument('--allow-no-loader', action='store_true', help='旧目录没有补丁载入器也照出（只给测试或解开的非工程目录用）')
    ap.add_argument('--exclude', action='append', help='再排除的相对路径通配，目录写 名字/（可多次）')
    ap.add_argument('--skip-embedded-check', action='store_true', help='不核对内嵌公钥（只在用临时密钥试的时候）')
    ap.add_argument('--date', help='清单日期（默认今天）')
    ap.add_argument('--verify', help='验一份已出的清单：给 patch_manifest.json 路径')
    ap.add_argument('--pubkey', help='--verify 用的公钥 .pem')
    a = ap.parse_args(argv)
    try:
        return verify_cmd(a) if a.verify else generate(a)
    except Fail as e:
        print(f'✗ {e}')
        return 1


if __name__ == '__main__':
    sys.exit(main())
