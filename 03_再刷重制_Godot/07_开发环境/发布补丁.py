#!/usr/bin/env python3
"""发布补丁（自动更新第③批，cc 2026-11-11）：导出补丁、写版本清单、签名，备好两个发版仓库的本地提交。**不推送**。

  python3 发布补丁.py --base <底包.pck> --base-code <号>      相对这个底包导出当前工程的累计补丁，写清单并签名（只到输出目录）
  python3 发布补丁.py --base <发行目录 devNNN_三平台发行>       同上，底包取目录里 windows/*.pck，号取目录名
  python3 发布补丁.py --full-only                              不出补丁，只把清单的最新版本改成当前开发编号（刚发了新整包时用）
      --note "一句说明"（可多次）｜--notes-file <发行说明.txt>   玩家看的更新说明（每行一条；不要带内部编号、路径、掉率）
      --min-base <号>          低于这个号的底包提示去换整包（默认沿用清单原值）
      --revoke <号>（可多次）   撤回某个补丁版本（装了它的客户端下次启动退回）
      --drop-base <号>（可多次） 清单里不再给这个底包发补丁
      --min-playable <号>｜latest｜0   强制更新（Kyo 11-14）：运行的开发编号低于它的客户端进标题前被拦住、必须更新
                               （latest＝本次发布的编号，所有旧版都强制；0＝取消强制）。不给就沿用清单原值（默认不改）。
                               不能比本次发布的编号大。只有装了强制更新逻辑的客户端认它，更老的客户端照旧只看红点。
      --download-url <https 地址>｜none   强制更新框「手动下载」打开的页面（不给就沿用原值；none 或空串＝去掉，客户端改指 QQ 群）
                               新设 min_playable 且没给本参数、清单里也没有时默认填 Gitee 发行版页面（DEFAULT_DOWNLOAD_URL，Kyo 11-14）；
                               显式传 --download-url none（或空串）允许搭配 --min-playable 留空指 QQ 群（Kyo 11-24，T457）
      --out <目录>             输出目录（默认 05_发布/补丁/dev<号>/，不入 Git）
      --stage                  把补丁和清单提交到两个发版仓库的本机副本（先提交包、再提交清单，清单里的包地址固定到包提交）
      --old-tree <目录>        底包对应的工程目录：顺带调 生成更新清单.py 比对它和当前工程，写签名的补丁文件清单
                               （patch_<底>_<新>.files.json／.files.sig），--stage 时和补丁同一提交进发版仓库。
                               --stage 出补丁时必须给；确实没有底包目录时加 --no-files-manifest 跳过
      --repos <gitee副本> <github副本>   发版仓库副本的位置（默认 ~/Documents/DSH/小小鱼/发版/zaishuayiba-updates-{gitee,github}）
      --key <私钥.pem>         签名私钥（默认 ~/Library/Application Support/KYO/发版密钥/godot_update_private_20261125.pem；也认环境变量 XIYOU_UPDATE_KEY）
      --dry-run                只打印会做什么
      --no-player-pack         --verify-online 通过后不出小小鱼的玩家资料包（默认出，见 PLAYER_PACK_AFTER_VERIFY）

清单格式见 core/update_check.gd 头注释（schema 1）。做的检查：
  - 私钥对应的公钥等于游戏里内嵌的公钥（XUpdateCheck.PUBLIC_KEY），签完用公钥再验一次；
  - 「Windows 发行」「安卓 发行」「macOS 发行」三个预设各导一次补丁，三份逐字节相同才发（一个补丁三端通用）；
  - 资源加密（T452）：导出时带私密设计仓的资源加密密钥（资源加密.py），补丁和整包同一把密钥、同样只加密文件；
    预设里的 seed 让加密 IV 由内容算出，三端仍逐字节相同；导完 资源加密.py scan 查该加密的都加密了、抽查解得开；
    底包是加密包时编辑器也要这把密钥才读得了底包（没有密钥直接停，不出明文补丁）。回退：资源加密.ENCRYPT＝False（导出副本里关加密）；
  - 存档密钥（T489）：底包带发行存档密钥时，导出用的工程里注入同一把（发行出包.inject_save_key）；补丁目录里不许有删除条目
    （Godot 把「底包有、工程里没有」的文件记成删除，0.04.01 因此删了密钥、玩家存档全部看不见），确要删加 --allow-removal <路径>；
  - 存档门禁（T489）：导完用底包目录里的真 mac 包＋这份补丁，读发行密钥封存的 .ksv 档必须进得了地图（save_gate，约 1～2 分钟）；
    --base 给的不是 devNNN_三平台发行 目录、或本机不是 Mac 时跑不了，要 --skip-save-gate "<理由>"；
  - 补丁超过 30 MB 报错（Gitee 放不下大文件，该发新底包了；--allow-big 放行）；
  - 清单的最新编号不能比原来的小；同一底包的补丁编号不能比原来的小。
--stage 之后要做的（工具只打印、不执行）：Kyo 回「推」后，两个仓库各 `git push`，等一两分钟，再跑
  `python3 发布补丁.py --verify-online` 回读各源的清单和补丁核对签名与 SHA（Gitee 刚推完可能先返回一页占位文字）。
公开游戏仓库不放任何包；输出目录 05_发布/补丁/ 已在 .gitignore。
补丁文件清单（Kyo 11-11「接」）：排除项照「Windows 发行」预设的 exclude_filter，用的是同一把 --key；它的底包编号必须等于 --base 的编号。
客户端不读它，存着给核对与交叉核查用；格式见 05_发布/更新清单生成说明.md。
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
import importlib.util

HERE = Path(__file__).resolve().parent
REMAKE = HERE.parent
PROJECT = REMAKE / '01_Godot工程'
GODOT = Path(os.environ.get('XIYOU_GODOT') or HERE / 'godot')
PRESETS = ('Windows 发行', '安卓 发行', 'macOS 发行')
DEFAULT_KEY = Path.home() / 'Library/Application Support/KYO/发版密钥/godot_update_private_20261125.pem'
DEFAULT_REPOS = [Path.home() / 'Documents/DSH/小小鱼/发版' / n for n in ('zaishuayiba-updates-gitee', 'zaishuayiba-updates-github')]
SUBDIR = 'godot2'
# 强制更新的手动下载页默认值（Kyo 11-14 定：Gitee 更新仓的发行版页面）。只写进清单，客户端不写死
# 第三方 GitHub 加速代理（T153，Kyo 11-17 提）：只当镜像，补丁照旧比 SHA-256；哪天挂了把它置空，就不再写进补丁地址、也不再在线核它。
GH_PROXY = 'https://gh-proxy.com/'
DEFAULT_DOWNLOAD_URL = 'https://gitee.com/kyoluu/play-again_-xiyou_-kyo/releases'
MAX_PATCH = 30 * 1024 * 1024
SCHEMA = 1
DIR_RE = re.compile(r'^dev(\d+)_三平台发行$')
NEW_TREE = PROJECT  # 补丁文件清单的新版本目录（测试换成假目录）
FILES_PRESET = 'Windows 发行'
# 玩家资料包（T008 期一，cc 11-16）：--verify-online 核过线上清单与补丁后，接着跑 玩家资料包.py 给小小鱼出公开资料（玩家真能下到了才出）。
# 回退＝改成 False（或单次加 --no-player-pack）。资料包失败只报警，不改 --verify-online 的退出码（线上核对本身是对的）。
PLAYER_PACK_AFTER_VERIFY = True


def release_excludes() -> list:
    """「Windows 发行」预设的 exclude_filter，补丁文件清单照它排除（不进包的文件不该算进补丁）。"""
    cfg = PROJECT / 'export_presets.cfg'
    if not cfg.is_file():
        return []
    cur = None
    for line in cfg.read_text(encoding='utf-8').splitlines():
        m = re.match(r'^name="(.*)"$', line)
        if m:
            cur = m.group(1)
        m = re.match(r'^exclude_filter="(.*)"$', line)
        if m and cur == FILES_PRESET:
            return [x.strip() for x in m.group(1).split(',') if x.strip()]
    return []


def files_manifest(old_tree: Path, key: Path, code: int, base_code: int, out: Path, date: str) -> tuple:
    """调 生成更新清单.py 写签名的补丁文件清单，返回 (json, sig) 路径。"""
    spec = importlib.util.spec_from_file_location('生成更新清单', HERE / '生成更新清单.py')
    g = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(g)
    argv = ['--old', str(old_tree), '--new', str(NEW_TREE), '--new-code', str(code), '--key', str(key), '--out', str(out), '--date', date]
    for x in release_excludes():
        argv += ['--exclude', x]
    if g.main(argv) != 0:
        raise Fail('补丁文件清单没生成（见上一行）')
    mj = out / g.MANIFEST
    got = json.loads(mj.read_text(encoding='utf-8'))['base_code']
    if got != base_code:
        raise Fail(f'--old-tree 的编号是 {got}，和底包 {base_code} 对不上：给的不是这个底包的工程目录')
    return mj, out / g.SIG


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


KEY_DIR_NAME = '发版密钥'
FORBIDDEN_SIG_SUFFIXES = frozenset({'.pem', '.key', '.keystore', '.p12', '.pfx', '.jks'})


def sign(*, key: Path, data: Path, sig: Path) -> None:
    """对 data 做 SHA-256 RSA 签名写到 sig（强制关键字参数＋路径守卫＋原子替换，防止误覆写私钥）。"""
    key = Path(key).expanduser()
    data = Path(data).expanduser()
    sig = Path(sig).expanduser()
    k_res = key.resolve(strict=False)
    d_res = data.resolve(strict=False)
    s_res = sig.resolve(strict=False)
    if s_res.suffix.lower() in FORBIDDEN_SIG_SUFFIXES or sig.suffix.lower() in FORBIDDEN_SIG_SUFFIXES:
        raise Fail(f'拒绝把签名输出到密钥后缀文件：{sig}')
    if any(part == KEY_DIR_NAME for part in (*sig.parts, *s_res.parts)):
        raise Fail(f'拒绝把签名输出到发版密钥目录：{sig}')
    try:
        s_res.relative_to(DEFAULT_KEY.parent.resolve(strict=False))
        raise Fail(f'拒绝把签名输出到发版密钥目录：{sig}')
    except ValueError:
        pass
    if s_res == k_res or s_res == d_res:
        raise Fail(f'拒绝签名输出覆盖私钥或待签文件：{sig}')
    if not key.is_file() or key.stat().st_size <= 0:
        raise Fail(f'私钥文件不存在或为空：{key}')
    head = key.read_bytes()[:64]
    if b'-----BEGIN' not in head or b'PRIVATE KEY-----' not in head:
        raise Fail(f'私钥文件格式不对（不是 PEM 私钥）：{key}')
    if not data.is_file() or data.stat().st_size <= 0:
        raise Fail(f'待签名文件不存在或为空：{data}')
    if b'PRIVATE KEY-----' in data.read_bytes()[:64]:
        raise Fail(f'待签名文件疑似私钥，拒绝签名：{data}')
    sig.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix='.sig_', suffix='.tmp', dir=str(sig.parent))
    os.close(fd)
    tmp = Path(tmp_name)
    try:
        p = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(key), '-out', str(tmp), str(data)],
                           capture_output=True, text=True)
        if p.returncode != 0 or tmp.stat().st_size <= 0:
            raise Fail(f'签名失败：{p.stderr.strip()[:200]}')
        os.chmod(tmp, 0o644)
        os.replace(tmp, sig)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


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
    src = PROJECT
    if not dry and not REAL_SCRIPTS:  # 发行空壳（11-13）：天启篇脚本换成空壳的工程克隆里导补丁
        spec = importlib.util.spec_from_file_location('发行空壳', HERE / '发行空壳.py')
        sk = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(sk)
        src = out / '_空壳工程'
        if src.exists():
            shutil.rmtree(src)
        sk.make_tree(src)
        if sk.is_stub_tree(src):
            raise Fail('发行空壳没换全：' + '、'.join(sk.is_stub_tree(src)))
        if not NO_STUB_SMOKE:  # T150：导出前在空壳树里前台开战冒烟（约 40 秒），崩了就拦
            print('· 空壳树开战冒烟（xiyou_battle＋xiyou_battle_ui）')
            probs = sk.smoke_battle(src, GODOT, out / '日志')
            if probs:
                shutil.rmtree(src, ignore_errors=True)
                raise Fail('；'.join(probs) + f'（日志在 {out / "日志"}；明知故发加 --no-stub-smoke）')
    injected = None
    try:
        if not dry:
            injected = inject_save_key(src, base)  # T489：底包带存档密钥就同样注入，不然 --export-patch 把它记成删除
        _export_presets(base, tmp, dry, shas, src)
    finally:
        if injected is not None and src == PROJECT:
            injected.unlink(missing_ok=True)  # 真脚本回退直接用工程导：导完删掉，不留在工作区（.gitignore 了）
        if src != PROJECT:
            shutil.rmtree(src, ignore_errors=True)
    return _check_patch(tmp, dry, shas)


# T489（v0.04.01 存档「不见」事故，cc 11-25）：发行存档密钥只在出整包时注入（发行出包.py inject_save_key、不进仓库）。
# 补丁导出用 --patches 底包做差异，Godot 4.4 起把「底包有、这次工程里没有」的文件记成删除（PACK_FILE_REMOVAL）——
# 0.04.01 就这样把 content/save_seal_key.json 删了：发行版没了密钥就不封存，玩家的 .ksv 存档在读档页全变空。
# 现在：底包里有密钥就在导出用的工程里注入同一把（与整包同一个来源、同样先查格式），导完补丁里不能有任何删除条目。
INJECT_SAVE_KEY = True  # 回退开关：False＝补丁流程不注入密钥（底包带密钥时删除门禁会拦下，不会再悄悄删）
ALLOWED_REMOVALS = set()  # 确实要在补丁里删掉的底包文件（res:// 之后的路径）；单次放行用 --allow-removal <路径>
PCK_FILE_REMOVAL = 2


def _rel_mod():
    spec = importlib.util.spec_from_file_location('发行出包', HERE / '发行出包.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def pck_dir(path: Path) -> dict:
    """补丁或底包 pck 的目录：名字 → (偏移, 字节数, 标志)。"""
    enc = _enc_mod()
    with open(path, 'rb') as f:
        return enc.pck_entries(f, enc.pck_base(f, path))


def base_has_save_key(base: Path) -> bool:
    if not Path(base).is_file():
        return False  # 测试夹具的假底包路径；真出包时 resolve_base 已确认底包存在
    return _rel_mod().SAVE_KEY_DEST in pck_dir(base)


def inject_save_key(src: Path, base: Path):
    """底包带存档密钥时往 src 工程注入同一把（复用 发行出包.inject_save_key 的格式检查和读回比对）；返回写进去的文件，没注入返回 None。"""
    if not INJECT_SAVE_KEY or not base_has_save_key(base):
        return None
    rel = _rel_mod()
    bad = rel.inject_save_key(src)
    if bad:
        raise Fail('补丁要带的存档密钥：' + bad)
    return src / rel.SAVE_KEY_DEST


def removal_problems(patch: Path, allowed=None) -> list:
    """补丁里的删除条目（白名单以外的）。底包里的任何文件被删都可能让玩家的东西「消失」，默认一律不发。"""
    ok = ALLOWED_REMOVALS | set(allowed or ())
    return [f'补丁会删掉底包里的 {n}（不是有意删就是导出工程缺了它；确要删加 --allow-removal {n}）'
            for n, (_o, _s, fl) in sorted(pck_dir(patch).items()) if fl & PCK_FILE_REMOVAL and n not in ok]


ALLOW_REMOVAL = []
SKIP_SAVE_GATE = ''  # --skip-save-gate "<理由>"：确实跑不了存档门禁（不是 Mac、底包目录里没有 mac 包）时写明理由跳过


def save_gate(base_dir: Path, patch: Path, base_code: int, logs: Path) -> list:
    """T489 出包门禁：用真底包的 mac 包＋这份补丁，读发行密钥封存的 .ksv 档要能进地图。返回问题（空＝通过）。
    做法（临时 HOME，全程无头静音）：工程造明文旧档 → 底包自己读一次（封存成 .ksv，就是 v0.04 玩家手里的样子）→ 删掉明文 →
    补丁登记进 updates/（已确认）→ 再读档：要 BOOT_PATCH loaded=true、第一下确认后不是新开局、最后进地图、封存记号 .sealed_v1 还在。"""
    import tempfile
    if sys.platform != 'darwin':
        return ['本机不是 Mac，跑不了补丁存档门禁（确实跑不了加 --skip-save-gate "<理由>"）']
    rel = _rel_mod()
    zipf = base_dir / rel.MAC_ZIP
    if not zipf.is_file():
        return [f'底包目录 {base_dir} 里没有 {rel.MAC_ZIP}，跑不了补丁存档门禁（--base 给 devNNN_三平台发行 目录；确实没有加 --skip-save-gate "<理由>"）']
    logs.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='xiyou_patch_save_gate_'))
    try:
        if subprocess.run(['ditto', '-x', '-k', str(zipf), str(work / 'app')]).returncode:
            return [f'解不开 {zipf.name}']
        exes = [x for x in sorted((work / 'app').glob('*.app/Contents/MacOS/*')) if x.is_file() and os.access(x, os.X_OK)]
        if not exes:
            return [f'{zipf.name} 里没有可执行文件']
        home = work / 'home'
        root = home / 'Library' / 'Application Support' / rel.release_user_dir()
        save_dir = root / 'modes' / 'xiyou'
        bad = rel.make_old_save(work / 'old_save', logs)
        if bad:
            return ['存档门禁：' + bad]
        save_dir.mkdir(parents=True)
        shutil.copy2(work / 'old_save' / 'save_1.json', save_dir / 'save_1.json')
        print('· 存档门禁：底包读一次旧档，封存成发行密钥的 .ksv')
        rc, text = rel._run_app(exes[0], home, rel.RUN_LOAD_KEYS, logs / '存档门禁_底包封存.log')
        ok, note = rel.judge_run('底包封存', rc, text, first_not_map=True)
        if not ok or not (save_dir / 'save_1.ksv').is_file() or not (save_dir / '.sealed_v1').is_file():
            return [f'存档门禁：底包没把旧档封存成 .ksv（{note}；日志 {logs / "存档门禁_底包封存.log"}）——底包本身不封存就测不了']
        (save_dir / 'save_1.json').unlink()
        upd = root / 'updates'
        upd.mkdir(parents=True)
        shutil.copy2(patch, upd / patch.name)
        (upd / 'active.json').write_text(json.dumps({'file': patch.name, 'sha256': sha256(patch), 'size': patch.stat().st_size, 'base': base_code,
                                                     'code': current_code(), 'confirmed': True, 'boots': 0, 'prev': None}), encoding='utf-8')
        print('· 存档门禁：装上补丁再读这份 .ksv')
        rc, text = rel._run_app(exes[0], home, rel.RUN_LOAD_KEYS, logs / '存档门禁_补丁读档.log')
        ok, note = rel.judge_run('补丁读档', rc, text, first_not_map=True)
        probs = []
        if 'BOOT_PATCH loaded=true' not in text:
            line = next((l for l in text.splitlines() if 'BOOT_PATCH' in l), '没有 BOOT_PATCH 行')
            probs.append(f'存档门禁：补丁没载入（{line.strip()[:120]}）')
        if not ok:
            probs.append(f'存档门禁：装补丁后读不到发行密钥封存的存档（{note}）——玩家会看到存档「不见了」')
        if not (save_dir / '.sealed_v1').is_file():
            probs.append('存档门禁：装补丁后封存记号 .sealed_v1 被删（游戏没了存档密钥、退回明文模式，.ksv 全看不见）')
        if probs:
            probs[-1] += f'（日志 {logs / "存档门禁_补丁读档.log"}）'
        return probs
    finally:
        shutil.rmtree(work, ignore_errors=True)


REAL_SCRIPTS = False  # 回退开关：True＝补丁照旧带天启篇真脚本
NO_STUB_SMOKE = False  # 回退开关：True＝导出前不跑空壳树开战冒烟（--no-stub-smoke）


def _enc_mod():
    spec = importlib.util.spec_from_file_location('资源加密', HERE / '资源加密.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def _export_env(src: Path):
    """T452：导补丁的环境（带资源加密密钥）。回退（ENCRYPT＝False）时在导出副本里关加密；没密钥抛 Fail。"""
    enc = _enc_mod()
    if not enc.ENCRYPT:
        if src == PROJECT:
            raise Fail('资源加密回退（ENCRYPT＝False）不能配真脚本回退（会改工作区的 export_presets.cfg）')
        enc.strip_encryption(src / 'export_presets.cfg')
        return None
    try:
        return enc.export_env()
    except RuntimeError as e:
        raise Fail(str(e)) from e


def base_encrypted(base: Path) -> bool:
    """底包里有没有加密文件（T452 之后的整包都有；之前的旧整包一个也没有）。"""
    enc = _enc_mod()
    with open(base, 'rb') as f:
        return any(fl & 1 for _o, _s, fl in enc.pck_entries(f, enc.pck_base(f, base)).values())


def _export_presets(base: Path, tmp: Path, dry: bool, shas: dict, src: Path) -> None:
    env = None if dry else _export_env(src)
    if env is not None and not base_encrypted(base):
        # 旧整包的程序里没有密钥，读不了加密补丁（装上就进不了游戏）：旧整包的玩家只能换新整包，不给它出加密补丁
        raise Fail(f'底包 {base.name} 是加密前的旧整包，读不了加密补丁：不给旧整包出补丁（玩家看到「要换新的安装包」）；'
                   '要给旧整包玩家补东西只能出新整包。确认要出明文补丁就把 资源加密.ENCRYPT 改 False')
    for preset in PRESETS:
        dst = tmp / (preset.split(' ')[0] + '.pck')
        if dry:
            print(f'  [dry-run] godot --export-patch "{preset}" {dst} --patches {base}')
            continue
        p = subprocess.run([str(GODOT), '--headless', '--audio-driver', 'Dummy', '--path', str(src), '--export-patch', preset, str(dst), '--patches', str(base)],
                           capture_output=True, text=True, env=env)
        if '没有要导出的文件或更改' in p.stdout + p.stderr or 'No files or changes to export' in p.stdout + p.stderr:
            raise Fail('当前工程相对这个底包没有任何改动，没有补丁可发')
        if p.returncode != 0 or not dst.exists():
            raise Fail(f'「{preset}」补丁导出失败：{(p.stdout + p.stderr)[-800:]}')
        shas[preset] = sha256(dst)


def _check_patch(tmp: Path, dry: bool, shas: dict) -> Path:
    if dry:
        return tmp / 'Windows.pck'
    if len(set(shas.values())) != 1:
        raise Fail('三个预设导出的补丁不一样，不能当通用补丁发：' + json.dumps(shas, ensure_ascii=False))
    gone = removal_problems(tmp / 'Windows.pck', ALLOW_REMOVAL)  # T489：先查删除条目（存档密钥被删就是这里该拦）
    if gone:
        raise Fail(f'补丁有 {len(gone)} 个删除条目，不能发：' + '；'.join(gone[:10]))
    # 发行内容审计（11-13 漩涡异化设计稿随 0.475 补丁外泄后加）：补丁里不许有没发行的内容
    spec = importlib.util.spec_from_file_location('发行内容审计', HERE / '发行内容审计.py')
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    bad = m.audit(tmp / 'Windows.pck', [] if REAL_SCRIPTS else None)  # 回退带真脚本时只查没发行的文件（11-14）
    enc = _enc_mod()
    if enc.ENCRYPT:
        bad += enc.scan(tmp / 'Windows.pck')  # T452：补丁里该加密的都加密了
    if bad:
        raise Fail(f'补丁有 {len(bad)} 个问题，不能发：' + '、'.join(bad[:10]) + '（没发行的文件看 export_presets.cfg 发行预设的 exclude_filter，天启篇真脚本看 发行空壳.py 的 EXTRA）')
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
    ver_str = (getattr(a, 'version', None) or '').strip().lstrip('vV') or f'0.{code}'
    m['latest'] = {'version': ver_str, 'code': code, 'date': date, 'notes': notes}
    if patch_entry is not None:
        prev = ((m['bases'].get(str(base_code)) or {}).get('patch') or {})
        if int(prev.get('code', 0)) > patch_entry['code']:
            raise Fail(f'底包 {base_code} 已有更新的补丁 {prev["code"]}')
        m['bases'][str(base_code)] = {'patch': patch_entry}
    for b in a.drop_base or []:
        m['bases'].pop(str(b), None)
    if a.min_base is not None:
        m['min_base'] = a.min_base
    for k in ('min_playable', 'download_url'):  # 强制更新的两项：默认沿用原值
        if old and k in old:
            m[k] = old[k]
    if a.min_playable is not None:
        try:
            mp = code if a.min_playable == 'latest' else int(str(a.min_playable).replace('dev.', ''))
        except ValueError:
            raise Fail(f'--min-playable 要给开发编号（如 580）、latest 或 0，不认 {a.min_playable}')
        if mp > code:
            raise Fail(f'--min-playable {mp} 比本次发布的编号 {code} 还大：玩家装到最新也过不了，会一直卡在更新框')
        if mp > 0:
            m['min_playable'] = mp
        else:
            m.pop('min_playable', None)
    had_min_playable = bool(old and old.get('min_playable'))
    clear_download_url = a.download_url is not None and a.download_url.strip() in ('', 'none')
    if a.download_url is not None:
        if clear_download_url:
            m.pop('download_url', None)
        elif not a.download_url.startswith('https://'):
            raise Fail('--download-url 要 https:// 开头（客户端不认别的）')
        else:
            m['download_url'] = a.download_url
    if m.get('min_playable') and not str(m.get('download_url', '')).startswith('https://'):
        if clear_download_url or had_min_playable:
            m.pop('download_url', None)
            print('· 强制更新不设手动下载页（download_url 留空，客户端改指 QQ 群）')
        else:
            m['download_url'] = DEFAULT_DOWNLOAD_URL  # Kyo 11-14：新设强制更新且没给下载页时默认填 Gitee 发行版页面
            print(f'· 强制更新没给下载页，默认用 {DEFAULT_DOWNLOAD_URL}')
    for r in a.revoke or []:
        if r not in m['revoked']:
            m['revoked'].append(r)
    m['revoked'].sort()
    return m


def write_channel(out: Path, manifest: dict, key: Path, pub: str) -> None:
    cj, cs = out / 'channel.json', out / 'channel.sig'
    cj.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    sign(key=key, data=cj, sig=cs)
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
    """照 MOD 的顺序：Gitee raw 为主，再是 GitHub raw 经 gh-proxy（T153，第三方代理，GH_PROXY 置空就不写）、
    GitHub 仓库经 jsDelivr 各域名、raw；全部固定到包提交。
    githack 已去掉（Kyo 2026-11-13「删掉备用源」：0.01.09 上线时返回 403）。"""
    urls = []
    for repo in repos:
        site, slug = remote_slug(repo)
        c = commits[repo]
        if site == 'gitee.com':
            urls.append(f'https://gitee.com/{slug}/raw/{c}/{SUBDIR}/{name}')
    for repo in repos:
        site, slug = remote_slug(repo)
        c = commits[repo]
        if site == 'github.com' and GH_PROXY:
            urls.append(f'{GH_PROXY}https://raw.githubusercontent.com/{slug}/{c}/{SUBDIR}/{name}')
    for repo in repos:
        site, slug = remote_slug(repo)
        c = commits[repo]
        if site == 'github.com':
            for host in ('cdn', 'gcore', 'fastly', 'testingcf'):
                urls.append(f'https://{host}.jsdelivr.net/gh/{slug}@{c}/{SUBDIR}/{name}')
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
                     [f'https://raw.githubusercontent.com/{slug}/main/{SUBDIR}', f'https://cdn.jsdelivr.net/gh/{slug}@main/{SUBDIR}']
                     + ([f'{GH_PROXY}https://raw.githubusercontent.com/{slug}/main/{SUBDIR}'] if GH_PROXY else []))
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
    ap.add_argument('--min-playable')
    ap.add_argument('--download-url')
    ap.add_argument('--out')
    ap.add_argument('--stage', action='store_true')
    ap.add_argument('--repos', nargs=2)
    ap.add_argument('--key')
    ap.add_argument('--version', help='显式指定清单 latest.version（如 0.04.05；默认 0.<code>）')
    ap.add_argument('--date')
    ap.add_argument('--allow-big', action='store_true')
    ap.add_argument('--verify-online', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--old-tree')
    ap.add_argument('--no-files-manifest', action='store_true')
    ap.add_argument('--no-stub-smoke', action='store_true', help='导出前不跑空壳树开战冒烟（默认跑，约 40 秒）')
    ap.add_argument('--no-player-pack', action='store_true')
    ap.add_argument('--allow-removal', action='append', help='放行补丁里删掉底包的这个文件（res:// 之后的路径，可多次；T489）')
    ap.add_argument('--skip-save-gate', help='不跑补丁存档门禁，写明理由（T489；默认在 Mac 上用真底包 mac 包跑）')
    a = ap.parse_args(argv)
    global NO_STUB_SMOKE
    NO_STUB_SMOKE = NO_STUB_SMOKE or a.no_stub_smoke
    ALLOW_REMOVAL[:] = a.allow_removal or []
    global SKIP_SAVE_GATE
    SKIP_SAVE_GATE = (a.skip_save_gate or '').strip()
    try:
        repos = [Path(p).expanduser() for p in a.repos] if a.repos else DEFAULT_REPOS
        embedded = embedded_public_key()
        if a.verify_online:
            rc = verify_online(repos, embedded)
            if rc == 0 and PLAYER_PACK_AFTER_VERIFY and not a.no_player_pack:
                print('== 线上核对通过，出小小鱼的玩家资料包（玩家资料包.py）')
                r = subprocess.run([sys.executable, str(HERE / '玩家资料包.py')])
                if r.returncode:
                    print('⚠ 玩家资料包没出成（上面有原因；「当前」没动）。补跑：python3 玩家资料包.py；不影响本次线上核对结果')
            return rc
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
        ver_label = (getattr(a, 'version', None) or '').strip().lstrip('vV') or f'0.{code}'
        print(f'· 当前开发编号 {code}（玩家看到 {ver_label}），输出 {out}')

        base_code, patch_file, entry = None, None, None
        if not a.full_only:
            base, base_code = resolve_base(a.base, a.base_code)
            if not base_code:
                raise Fail('不知道底包的开发编号：给 --base-code，或把 --base 指到 devNNN_三平台发行 目录')
            if base_code >= code:
                raise Fail(f'底包编号 {base_code} 不比当前 {code} 小，没有可发的补丁')
            if a.stage and not a.old_tree and not a.no_files_manifest:
                raise Fail('--stage 出补丁要给 --old-tree <底包对应的工程目录>，好写补丁文件清单（没有就加 --no-files-manifest）')
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
                if SKIP_SAVE_GATE:
                    print(f'⚠ 跳过补丁存档门禁：{SKIP_SAVE_GATE}')
                else:
                    gate = save_gate(base.parent.parent if base.parent.name == 'windows' else base.parent, patch_file, base_code, out / '日志')
                    if gate:
                        raise Fail('；'.join(gate))
                    print('· 存档门禁通过：真底包＋本补丁读得到发行密钥封存的存档、进了地图')

        files_pair = None
        if patch_file is not None and a.old_tree and not a.no_files_manifest:
            files_pair = files_manifest(Path(a.old_tree).expanduser(), key, code, base_code, out / '文件清单', date)

        if a.stage and not a.dry_run:
            for r in repos:
                check_repo_ready(r)
        old = {}
        old_path = repos[0] / SUBDIR / 'channel.json'
        if old_path.exists():
            old = json.loads(old_path.read_text(encoding='utf-8'))
        build_manifest(old, code, date, notes, base_code, entry, a)  # 先按清单规则试一遍（如强制更新缺下载页），不过就在提交任何东西之前停下
        if a.dry_run:
            print('  [dry-run] ' + ('比对 --old-tree 写补丁文件清单、' if a.old_tree and not a.no_files_manifest and not a.full_only else '')
                  + '写清单、签名' + ('、提交到两个发版仓库副本（不推送）' if a.stage else ''))
            return 0

        commits = {}
        if a.stage and entry is not None:
            for r in repos:
                (r / SUBDIR).mkdir(exist_ok=True)
                for pat in (f'patch_{base_code}_*.pck', f'patch_{base_code}_*.files.json', f'patch_{base_code}_*.files.sig'):
                    for stale in (r / SUBDIR).glob(pat):
                        git(r, 'rm', '-q', '--ignore-unmatch', str(stale.relative_to(r)))  # 同一底包的旧补丁从 main 上拿掉（历史里还在，旧清单的地址固定到提交仍可读）
                        stale.unlink(missing_ok=True)
                shutil.copy2(patch_file, r / SUBDIR / patch_file.name)
                git(r, 'add', f'{SUBDIR}/{patch_file.name}')
                if files_pair:
                    stem = patch_file.name[:-len('.pck')]
                    for src, ext in zip(files_pair, ('.files.json', '.files.sig')):
                        shutil.copy2(src, r / SUBDIR / (stem + ext))
                        git(r, 'add', f'{SUBDIR}/{stem}{ext}')
                git(r, 'commit', '-q', '-m', f'重制版 0.{code} 补丁（底包 0.{base_code}）')
                commits[r] = git(r, 'rev-parse', 'HEAD')
            entry['urls'] = package_urls(repos, commits, patch_file.name)
        elif entry is not None:
            entry['urls'] = [f'https://example.invalid/{SUBDIR}/{patch_file.name}']
            print('  （没加 --stage：清单里的补丁地址是占位的，只能本地看，不能发）')

        manifest = build_manifest(old, code, date, notes, base_code, entry, a)
        write_channel(out, manifest, key, pub)
        print(f'· 清单 channel.json、channel.sig 已写并验签：最新 {manifest["latest"]["version"]}，有补丁的底包 {sorted(manifest["bases"])}，'
              f'min_base {manifest["min_base"]}，撤回 {manifest["revoked"]}，'
              + (f'强制更新：开发编号低于 {manifest["min_playable"]} 的进不了游戏' if manifest.get('min_playable') else '不强制更新'))
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
