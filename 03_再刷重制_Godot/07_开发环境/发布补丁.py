#!/usr/bin/env python3
"""发布补丁（自动更新第③批，cc 2026-11-11）：导出补丁、写版本清单、签名，备好两个发版仓库的本地提交。**不推送**。

  python3 发布补丁.py --base <底包.pck> --base-code <号>      相对这个底包导出当前工程的累计补丁，写清单并签名（只到输出目录）
  python3 发布补丁.py --base <发行目录 devNNN_三平台发行>       同上，底包取目录里 windows/*.pck，号取目录名
  python3 发布补丁.py --full-only                              不出补丁，只把清单的最新版本改成当前开发编号（刚发了新整包时用）
      --note "一句说明"（可多次）｜--notes-file <发行说明.txt>   玩家看的更新说明（每行一条；不要带内部编号、路径、掉率）
      --min-base <号>          低于这个号的底包提示去换整包（默认沿用清单原值）
      --revoke <号>（可多次）   撤回某个补丁版本（装了它的客户端下次启动退回）
      --drop-base <号>（可多次） 清单里不再给这个底包发补丁
      --out <目录>             输出目录（默认 05_发布/补丁/dev<号>/，不入 Git）
      --stage                  把补丁和清单提交到两个发版仓库的本机副本（先提交包、再提交清单，清单里的包地址固定到包提交）
      --repos <gitee副本> <github副本>   发版仓库副本的位置（默认 ~/Documents/DSH/小小鱼/发版/zaishuayiba-updates-{gitee,github}）
      --key <私钥.pem>         签名私钥（默认 ~/Library/Application Support/KYO/发版密钥/godot_update_private.pem；也认环境变量 XIYOU_UPDATE_KEY）
      --dry-run                只打印会做什么

清单格式见 core/update_check.gd 头注释（schema 1）。做的检查：
  - 私钥对应的公钥等于游戏里内嵌的公钥（XUpdateCheck.PUBLIC_KEY），签完用公钥再验一次；
  - 「Windows 发行」「安卓 发行」「macOS 发行」三个预设各导一次补丁，三份逐字节相同才发（一个补丁三端通用）；
  - 补丁超过 30 MB 报错（Gitee 放不下大文件，该发新底包了；--allow-big 放行）；
  - 清单的最新编号不能比原来的小；同一底包的补丁编号不能比原来的小。
--stage 之后要做的（工具只打印、不执行）：Kyo 回「推」后，两个仓库各 `git push`，等一两分钟，再跑
  `python3 发布补丁.py --verify-online` 回读各源的清单和补丁核对签名与 SHA（Gitee 刚推完可能先返回一页占位文字）。
公开游戏仓库不放任何包；输出目录 05_发布/补丁/ 已在 .gitignore。
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

HERE = Path(__file__).resolve().parent
REMAKE = HERE.parent
PROJECT = REMAKE / '01_Godot工程'
GODOT = Path(os.environ.get('XIYOU_GODOT') or HERE / 'godot')
PRESETS = ('Windows 发行', '安卓 发行', 'macOS 发行')
DEFAULT_KEY = Path.home() / 'Library/Application Support/KYO/发版密钥/godot_update_private.pem'
DEFAULT_REPOS = [Path.home() / 'Documents/DSH/小小鱼/发版' / n for n in ('zaishuayiba-updates-gitee', 'zaishuayiba-updates-github')]
SUBDIR = 'godot'
MAX_PATCH = 30 * 1024 * 1024
SCHEMA = 1
DIR_RE = re.compile(r'^dev(\d+)_三平台发行$')


class Fail(Exception):
    pass


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def current_code() -> int:
    d = json.loads((PROJECT / 'content/build_info.json').read_text(encoding='utf-8'))
    return int(str(d['developmentVersion']).replace('dev.', ''))


def embedded_public_key() -> str:
    src = (PROJECT / 'core/update_check.gd').read_text(encoding='utf-8')
    m = re.search(r'-----BEGIN PUBLIC KEY-----.*?-----END PUBLIC KEY-----', src, re.S)
    if not m:
        raise Fail('core/update_check.gd 里找不到内嵌公钥')
    return m.group(0).strip()


def public_of(key: Path) -> str:
    p = subprocess.run(['openssl', 'pkey', '-in', str(key), '-pubout'], capture_output=True, text=True)
    if p.returncode != 0:
        raise Fail(f'读不了私钥 {key}：{p.stderr.strip()[:200]}')
    return p.stdout.strip()


def sign(key: Path, data: Path, sig: Path) -> None:
    p = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(key), '-out', str(sig), str(data)], capture_output=True, text=True)
    if p.returncode != 0:
        raise Fail(f'签名失败：{p.stderr.strip()[:200]}')


def verify(pub_pem: str, data: Path, sig: Path) -> bool:
    with tempfile.NamedTemporaryFile('w', suffix='.pem', delete=False) as f:
        f.write(pub_pem + '\n')
    try:
        p = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', f.name, '-signature', str(sig), str(data)], capture_output=True, text=True)
        return p.returncode == 0
    finally:
        os.unlink(f.name)


def resolve_base(arg: str, code):
    p = Path(arg).expanduser().resolve()
    if p.is_dir():
        m = DIR_RE.match(p.name)
        pcks = sorted((p / 'windows').glob('*.pck'))
        if not pcks:
            raise Fail(f'{p} 里没有 windows/*.pck')
        return pcks[0], (code if code else (int(m.group(1)) if m else None))
    if not p.is_file():
        raise Fail(f'底包不存在：{p}')
    return p, code


def export_patch(base: Path, out: Path, dry: bool) -> Path:
    """三个预设各导一次，逐字节相同才算数。返回补丁路径。"""
    tmp = out / '_export'
    tmp.mkdir(parents=True, exist_ok=True)
    shas = {}
    for preset in PRESETS:
        dst = tmp / (preset.split(' ')[0] + '.pck')
        if dry:
            print(f'  [dry-run] godot --export-patch "{preset}" {dst} --patches {base}')
            continue
        p = subprocess.run([str(GODOT), '--headless', '--path', str(PROJECT), '--export-patch', preset, str(dst), '--patches', str(base)],
                           capture_output=True, text=True)
        if '没有要导出的文件或更改' in p.stdout + p.stderr or 'No files or changes to export' in p.stdout + p.stderr:
            raise Fail('当前工程相对这个底包没有任何改动，没有补丁可发')
        if p.returncode != 0 or not dst.exists():
            raise Fail(f'「{preset}」补丁导出失败：{(p.stdout + p.stderr)[-800:]}')
        shas[preset] = sha256(dst)
    if dry:
        return tmp / 'Windows.pck'
    if len(set(shas.values())) != 1:
        raise Fail('三个预设导出的补丁不一样，不能当通用补丁发：' + json.dumps(shas, ensure_ascii=False))
    return tmp / 'Windows.pck'


def read_notes(a) -> list:
    notes = list(a.note or [])
    if a.notes_file:
        for line in Path(a.notes_file).read_text(encoding='utf-8').splitlines():
            line = line.strip().lstrip('-·* ').strip()
            if line and not line.startswith('#'):
                notes.append(line)
    bad = [n for n in notes if re.search(r'dev\.\d+|O-\d+|\.gd\b|/|掉率|掉落率', n)]
    if bad:
        raise Fail('更新说明里有内部编号、路径或掉率，改掉再发：' + '；'.join(bad))
    return notes


def build_manifest(old: dict, code: int, date: str, notes: list, base_code, patch_entry, a) -> dict:
    m = {'schema': SCHEMA, 'latest': {}, 'bases': {}, 'min_base': 0, 'revoked': []}
    if old:
        if int(old.get('schema', 0)) != SCHEMA:
            raise Fail('现有清单的 schema 不认识，先人工看一下')
        m['bases'] = dict(old.get('bases') or {})
        m['min_base'] = int(old.get('min_base', 0))
        m['revoked'] = [int(x) for x in old.get('revoked') or []]
        old_code = int((old.get('latest') or {}).get('code', 0))
        if code < old_code:
            raise Fail(f'清单里的最新编号是 {old_code}，不能发更小的 {code}')
    m['latest'] = {'version': f'0.{code}', 'code': code, 'date': date, 'notes': notes}
    if patch_entry is not None:
        prev = ((m['bases'].get(str(base_code)) or {}).get('patch') or {})
        if int(prev.get('code', 0)) > patch_entry['code']:
            raise Fail(f'底包 {base_code} 已有更新的补丁 {prev["code"]}')
        m['bases'][str(base_code)] = {'patch': patch_entry}
    for b in a.drop_base or []:
        m['bases'].pop(str(b), None)
    if a.min_base is not None:
        m['min_base'] = a.min_base
    for r in a.revoke or []:
        if r not in m['revoked']:
            m['revoked'].append(r)
    m['revoked'].sort()
    return m


def write_channel(out: Path, manifest: dict, key: Path, pub: str) -> None:
    cj, cs = out / 'channel.json', out / 'channel.sig'
    cj.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    sign(key, cj, cs)
    if not verify(pub, cj, cs):
        raise Fail('签完用公钥验不过')


def git(repo: Path, *args) -> str:
    p = subprocess.run(['git', '-C', str(repo), *args], capture_output=True, text=True)
    if p.returncode != 0:
        raise Fail(f'git {" ".join(args)}（{repo.name}）失败：{p.stderr.strip()[:300]}')
    return p.stdout.strip()


def remote_slug(repo: Path):
    """发版仓库副本的远端 → (站点, 'owner/name')。"""
    url = git(repo, 'remote', 'get-url', 'origin')
    m = re.search(r'(gitee\.com|github\.com)[:/]([^/]+/[^/.]+)', url)
    if not m:
        raise Fail(f'{repo} 的远端不是 Gitee 或 GitHub：{url}')
    return m.group(1), m.group(2)


def package_urls(repos: list, commits: dict, name: str) -> list:
    """照 MOD 的顺序：Gitee raw 为主，再是 GitHub 仓库经 jsDelivr 各域名、githack、raw；全部固定到包提交。"""
    urls = []
    for repo in repos:
        site, slug = remote_slug(repo)
        c = commits[repo]
        if site == 'gitee.com':
            urls.append(f'https://gitee.com/{slug}/raw/{c}/{SUBDIR}/{name}')
    for repo in repos:
        site, slug = remote_slug(repo)
        c = commits[repo]
        if site == 'github.com':
            for host in ('cdn', 'gcore', 'fastly', 'testingcf'):
                urls.append(f'https://{host}.jsdelivr.net/gh/{slug}@{c}/{SUBDIR}/{name}')
            urls.append(f'https://rawcdn.githack.com/{slug}/{c}/{SUBDIR}/{name}')
            urls.append(f'https://raw.githubusercontent.com/{slug}/{c}/{SUBDIR}/{name}')
    return urls


def check_repo_ready(repo: Path) -> None:
    if not (repo / '.git').exists():
        raise Fail(f'发版仓库副本不在：{repo}')
    if git(repo, 'status', '--porcelain'):
        raise Fail(f'{repo.name} 有没提交的改动，先处理')


def verify_online(repos: list, pub: str) -> int:
    bad = 0
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        seen = []
        for repo in repos:
            site, slug = remote_slug(repo)
            bases = ([f'https://gitee.com/{slug}/raw/main/{SUBDIR}'] if site == 'gitee.com' else
                     [f'https://raw.githubusercontent.com/{slug}/main/{SUBDIR}', f'https://cdn.jsdelivr.net/gh/{slug}@main/{SUBDIR}'])
            for b in bases:
                try:
                    cj, cs = td / 'c.json', td / 'c.sig'
                    cj.write_bytes(urllib.request.urlopen(b + '/channel.json', timeout=20).read())
                    cs.write_bytes(urllib.request.urlopen(b + '/channel.sig', timeout=20).read())
                    ok = verify(pub, cj, cs)
                    m = json.loads(cj.read_text(encoding='utf-8')) if ok else {}
                    print(f'  {"✓" if ok else "✗"} 清单 {b}：{"验签通过，最新 " + m["latest"]["version"] if ok else "验签不过或不是清单"}')
                    bad += 0 if ok else 1
                    if ok:
                        seen.append(m)
                except Exception as e:  # noqa: BLE001
                    print(f'  ✗ 清单 {b}：读不到（{str(e)[:80]}）')
                    bad += 1
        if seen:
            m = max(seen, key=lambda x: x['latest']['code'])
            for base, ent in (m.get('bases') or {}).items():
                p = ent['patch']
                for u in p['urls']:
                    try:
                        data = urllib.request.urlopen(u, timeout=120).read()
                        ok = len(data) == p['size'] and hashlib.sha256(data).hexdigest() == p['sha256']
                        print(f'  {"✓" if ok else "✗"} 补丁（底包 {base}）{u[:70]}…：{"字节数与 SHA 一致" if ok else f"不一致（{len(data)} 字节）"}')
                        bad += 0 if ok else 1
                    except Exception as e:  # noqa: BLE001
                        print(f'  ✗ 补丁（底包 {base}）{u[:70]}…：读不到（{str(e)[:60]}）')
                        bad += 1
    print('✓ 线上各源都对' if bad == 0 else f'✗ {bad} 处不对（jsDelivr @main 的清单缓存最长约 12 小时，Gitee 刚推完先等一两分钟）')
    return 0 if bad == 0 else 1


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--base')
    ap.add_argument('--base-code', type=int)
    ap.add_argument('--full-only', action='store_true')
    ap.add_argument('--note', action='append')
    ap.add_argument('--notes-file')
    ap.add_argument('--min-base', type=int)
    ap.add_argument('--revoke', type=int, action='append')
    ap.add_argument('--drop-base', type=int, action='append')
    ap.add_argument('--out')
    ap.add_argument('--stage', action='store_true')
    ap.add_argument('--repos', nargs=2)
    ap.add_argument('--key')
    ap.add_argument('--date')
    ap.add_argument('--allow-big', action='store_true')
    ap.add_argument('--verify-online', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args(argv)
    try:
        repos = [Path(p).expanduser() for p in a.repos] if a.repos else DEFAULT_REPOS
        embedded = embedded_public_key()
        if a.verify_online:
            return verify_online(repos, embedded)
        if not a.base and not a.full_only:
            ap.error('要给 --base，或用 --full-only')
        key = Path(a.key or os.environ.get('XIYOU_UPDATE_KEY') or DEFAULT_KEY).expanduser()
        pub = public_of(key)
        if ''.join(pub.split()) != ''.join(embedded.split()):
            raise Fail('私钥对应的公钥和游戏里内嵌的不是同一把（core/update_check.gd 的 PUBLIC_KEY）')
        code = current_code()
        date = a.date or subprocess.run(['date', '+%F'], capture_output=True, text=True).stdout.strip()
        notes = read_notes(a)
        out = Path(a.out).expanduser() if a.out else REMAKE / '05_发布' / '补丁' / f'dev{code}'
        out.mkdir(parents=True, exist_ok=True)
        print(f'· 当前开发编号 {code}（玩家看到 0.{code}），输出 {out}')

        base_code, patch_file, entry = None, None, None
        if not a.full_only:
            base, base_code = resolve_base(a.base, a.base_code)
            if not base_code:
                raise Fail('不知道底包的开发编号：给 --base-code，或把 --base 指到 devNNN_三平台发行 目录')
            if base_code >= code:
                raise Fail(f'底包编号 {base_code} 不比当前 {code} 小，没有可发的补丁')
            print(f'· 底包 {base}（dev.{base_code}，{base.stat().st_size / 1e6:.1f} MB）')
            exported = export_patch(base, out, a.dry_run)
            name = f'patch_{base_code}_{code}.pck'
            if not a.dry_run:
                patch_file = out / name
                shutil.copy2(exported, patch_file)
                shutil.rmtree(out / '_export', ignore_errors=True)
                size = patch_file.stat().st_size
                print(f'· 补丁 {name}：{size / 1e6:.2f} MB，三个预设导出一致')
                if size > MAX_PATCH and not a.allow_big:
                    raise Fail(f'补丁 {size / 1e6:.1f} MB 超过 30 MB：该发新底包了（硬要发加 --allow-big）')
                entry = {'code': code, 'size': size, 'sha256': sha256(patch_file), 'urls': []}

        if a.stage and not a.dry_run:
            for r in repos:
                check_repo_ready(r)
        old = {}
        old_path = repos[0] / SUBDIR / 'channel.json'
        if old_path.exists():
            old = json.loads(old_path.read_text(encoding='utf-8'))
        if a.dry_run:
            print('  [dry-run] 写清单、签名' + ('、提交到两个发版仓库副本（不推送）' if a.stage else ''))
            return 0

        commits = {}
        if a.stage and entry is not None:
            for r in repos:
                (r / SUBDIR).mkdir(exist_ok=True)
                for stale in (r / SUBDIR).glob(f'patch_{base_code}_*.pck'):
                    git(r, 'rm', '-q', '--ignore-unmatch', str(stale.relative_to(r)))  # 同一底包的旧补丁从 main 上拿掉（历史里还在，旧清单的地址固定到提交仍可读）
                    stale.unlink(missing_ok=True)
                shutil.copy2(patch_file, r / SUBDIR / patch_file.name)
                git(r, 'add', f'{SUBDIR}/{patch_file.name}')
                git(r, 'commit', '-q', '-m', f'重制版 0.{code} 补丁（底包 0.{base_code}）')
                commits[r] = git(r, 'rev-parse', 'HEAD')
            entry['urls'] = package_urls(repos, commits, patch_file.name)
        elif entry is not None:
            entry['urls'] = [f'https://example.invalid/{SUBDIR}/{patch_file.name}']
            print('  （没加 --stage：清单里的补丁地址是占位的，只能本地看，不能发）')

        manifest = build_manifest(old, code, date, notes, base_code, entry, a)
        write_channel(out, manifest, key, pub)
        print(f'· 清单 channel.json、channel.sig 已写并验签：最新 0.{code}，有补丁的底包 {sorted(manifest["bases"])}，'
              f'min_base {manifest["min_base"]}，撤回 {manifest["revoked"]}')
        if a.stage:
            for r in repos:
                (r / SUBDIR).mkdir(exist_ok=True)
                shutil.copy2(out / 'channel.json', r / SUBDIR / 'channel.json')
                shutil.copy2(out / 'channel.sig', r / SUBDIR / 'channel.sig')
                git(r, 'add', f'{SUBDIR}/channel.json', f'{SUBDIR}/channel.sig')
                git(r, 'commit', '-q', '-m', f'重制版清单指向 0.{code}')
                print(f'· {r.name}：已在本机提交（包 {commits.get(r, "无")[:8]}、清单 {git(r, "rev-parse", "HEAD")[:8]}），没有推送')
            print('下一步（等 Kyo 回「推」）：')
            for r in repos:
                print(f'  git -C "{r}" push origin main')
            print(f'  然后等一两分钟：python3 {Path(__file__).name} --verify-online')
        return 0
    except Fail as e:
        print(f'✗ {e}')
        return 1


if __name__ == '__main__':
    sys.exit(main())
