#!/usr/bin/env python3
"""玩家资料包（T008 期一，cc 2026-11-16）：给群答疑的小小鱼导出「玩家在游戏里看得到的」公开资料。

依据：私密设计仓 协作交接/小小鱼玩家运营方案_v0.2.md 文末「给实现车道的契约（期一）」F1～F6、C1～C7，
C5 按 小A 复核第三节两处 P1 改（只认发行分支／标签尖端；临时 worktree＋克隆 generated＋发行空壳 tree --src）。

  python3 玩家资料包.py                 读线上清单 → 定位发行提交 → 脱敏树 → 无头取字 → 出包 → 七项自检 → 原子切「当前」
  python3 玩家资料包.py --dry-run       全部照做，但只写到工作目录，不碰出口
  python3 玩家资料包.py --ref <提交或分支>   手工补跑：不按线上补丁号反查，直接用这个提交（会写进 自检.json）
  python3 玩家资料包.py --out <目录>    出口（默认 ~/Documents/DSH/小小鱼/game/玩家资料包）
      --major auto|true|false      版本.json 的 major_content（默认 auto：版本号中间那段比上一版变了为 true；没有上一版为 false）
      --from-dump <取字.json>       测试／反例用：跳过建树和 Godot，直接用上次留下的取字结果（会写进 自检.json）
      --inject 禁词|数字id|空目录|隐藏掉率  反例用（期一验收证据 4；隐藏掉率是 X12 期二加的）：往待检的包里塞一条坏东西，自检必须失败、不切「当前」
      --keep-work                  留下工作目录（脱敏树、取字结果）方便核对
      --channel-file <json>        测试用：清单不读线上，读本地文件（会写进 自检.json，且不算线上核过）

出口布局（契约 2.1）：<出口>/当前 -> v<版本>/（软链，原子切换），每版一个目录，留最近十版。
本脚本只写出口目录；工作目录在 04_验证/本地结果/玩家资料包/（不入 Git），结束删掉 git worktree。
红线：包里不出现数字 id、note、公式、隐藏掉率（游戏文本里没印给玩家看的掉率，X12）、天启篇新增名字；自检七项任一不过：不切「当前」、退出码非 0。
"""
import argparse
import datetime as dt
import hashlib
import importlib.util
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
REPO = REMAKE.parent
PROJECT_REL = '03_再刷重制_Godot/01_Godot工程'
DEFAULT_OUT = Path.home() / 'Documents/DSH/小小鱼/game/玩家资料包'
MD_DIR = REMAKE / '05_发布/玩家资料包'
MD_FILES = ('更新记录.md', '和旧西游的不同.md', '常见问答.md')
WORK_ROOT = REMAKE / '04_验证/本地结果/玩家资料包'
DUMP_GD = HERE / '玩家资料包_取字.gd'
KEEP_VERSIONS = 10
GAME = '再刷一把：天启篇'
GODOT_TIMEOUT = 900

# 数据类：文件名（沿用旧 data 文件名）→ public_id 的种类前缀（沿用她 game-kb.cjs 的 kind 键）
KINDS = {'Actors': 'actor', 'Classes': 'class', 'Skills': 'skill', 'Items': 'item',
         'Weapons': 'weapon', 'Armors': 'armor', 'States': 'state', 'Enemies': 'enemy'}
ROW_FIELDS = {'public_id', 'name', 'nickname', 'description', 'price', 'params', 'open_in_current_version', 'acquire_hint'}
BANNED_FIELDS = {'id', 'note', 'damage', 'dropItems', 'effects', 'traits', 'meta', 'formula'}
VERSION_FIELDS = {'game', 'version', 'patch', 'release_base', 'legacy_popup_version', 'published_at', 'major_content',
                  'tianqi_open', 'highlights', 'source_commit'}
VERSION_REQUIRED = VERSION_FIELDS - {'legacy_popup_version'}
EVENT_FIELDS = {'id', 'kind', 'title', 'source', 'text'}
CHECKS = ('①字段白名单', '②禁词零命中', '③内部数字编号零命中', '④版本对得上', '⑤条数不掉一成', '⑥public_id类内唯一', '⑦写入路径在出口内')

# 契约 C6 固定词表：从 发行内容审计.py（DENY 路径）与 发行空壳.py（SUSPECT_NAME、SUSPECT_HEAD、EXTRA）汇总的天启篇专名
FIXED_WORDS = {
    'tianqi': '发行内容审计.DENY tianqi_data／content/tianqi／ui/tianqi；发行空壳.SUSPECT_NAME',
    'gojo': '发行内容审计.DENY content/gojo；发行空壳.SUSPECT_NAME、EXTRA XGojo',
    'qiyin': '发行空壳.SUSPECT_NAME',
    'horsem': '发行空壳.SUSPECT_NAME',
    'rift_alien': '发行内容审计.DENY modes/xiyou/rift_alien.json',
    '五条悟': '发行空壳.EXTRA XGojo（五条悟 180，只进天启篇）',
    '七印': '发行空壳.SUSPECT_NAME qiyin（七印祭坛）',
    '四骑士': '发行空壳.SUSPECT_NAME horsem（天启四骑士）',
    '天启骑士': '同上',
    '天启篇专属': '发行空壳.SUSPECT_HEAD',
    '只在天启篇': '发行空壳.SUSPECT_HEAD',
}


class Fail(Exception):
    pass


def log(msg: str) -> None:
    print(msg, flush=True)


def sh(args, cwd=None, check=True, **kw) -> str:
    r = subprocess.run(args, cwd=cwd, capture_output=True, text=True, **kw)
    if check and r.returncode:
        raise Fail(f'命令失败：{" ".join(map(str, args))}\n{r.stderr.strip()[:800]}')
    return r.stdout


def git(*args, cwd=REPO, check=True) -> str:
    return sh(['git', *args], cwd=cwd, check=check)


def main_worktree() -> Path:
    return Path(git('rev-parse', '--path-format=absolute', '--git-common-dir').strip()).parent


def load_mod(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


# ---------------------------------------------------------------- C5 线上清单

def online_channel(repos=None) -> dict:
    """读线上各源的 channel.json＋sig，用游戏内嵌公钥验签（发布补丁.py --verify-online 同一套），取 latest.code 最大的那份。"""
    bp = load_mod('发布补丁', HERE / '发布补丁.py')
    pub = bp.embedded_public_key()
    repos = repos or bp.DEFAULT_REPOS
    seen = []
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        for repo in repos:
            site, slug = bp.remote_slug(repo)
            bases = ([f'https://gitee.com/{slug}/raw/main/{bp.SUBDIR}'] if site == 'gitee.com' else
                     [f'https://raw.githubusercontent.com/{slug}/main/{bp.SUBDIR}'])
            for b in bases:
                try:
                    cj, cs = td / 'c.json', td / 'c.sig'
                    raw = urllib.request.urlopen(b + '/channel.json', timeout=20).read()
                    cj.write_bytes(raw)
                    cs.write_bytes(urllib.request.urlopen(b + '/channel.sig', timeout=20).read())
                    if bp.verify(pub, cj, cs):
                        m = json.loads(raw.decode('utf-8'))
                        seen.append({'src': b, 'channel': m, 'sha256': hashlib.sha256(raw).hexdigest(), 'repo': str(repo)})
                        log(f'  ✓ 线上清单 {b}：验签通过，最新 {m["latest"]["version"]}（{m["latest"]["code"]}）')
                    else:
                        log(f'  ✗ 线上清单 {b}：验签不过')
                except Exception as e:  # noqa: BLE001
                    log(f'  ✗ 线上清单 {b}：读不到（{str(e)[:80]}）')
    if not seen:
        raise Fail('线上清单一份都没读到／验签都不过：不出包')
    codes = {s['channel']['latest']['code'] for s in seen}
    if len(codes) > 1:
        log(f'  ⚠ 各源最新号不一致 {sorted(codes)}（CDN 缓存），取最大')
    return max(seen, key=lambda s: s['channel']['latest']['code'])


# ---------------------------------------------------------------- C5 定位发行提交

RELEASE_REF_PATTERNS = ('refs/heads/cc/v*', 'refs/heads/release/*', 'refs/tags/release/*',
                        'refs/remotes/origin/cc/v*', 'refs/remotes/origin/release/*')


def release_refs(cwd=REPO) -> list:
    """发行分支／标签尖端：[(ref, commit)]。标签解到提交。"""
    out = git('for-each-ref', '--format=%(refname) %(objectname) %(*objectname)', *RELEASE_REF_PATTERNS, cwd=cwd)
    refs = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        ref, obj = parts[0], (parts[2] if len(parts) > 2 and parts[2] else parts[1])
        # cc/v* 只认 cc/v 后面跟数字的（cc/v00200），别把 cc/vp-paths 之类的车道分支算进来
        short = ref.split('/', 2)[2] if ref.startswith('refs/heads/') else ref
        if re.search(r'(^|/)cc/v', short) and not re.search(r'cc/v\d', short):
            continue
        refs.append((ref, obj))
    return refs


def build_info_at(commit: str, cwd=REPO) -> dict:
    try:
        return json.loads(git('show', f'{commit}:{PROJECT_REL}/content/build_info.json', cwd=cwd))
    except (Fail, json.JSONDecodeError):
        return {}


def major_of(v: str) -> str:
    return str(v).lstrip('v').split('.', 1)[0]


def locate(patch: int, channel_version: str, cwd=REPO) -> dict:
    """契约 C5（小A 复核 P1 改）：只在发行分支／标签尖端里找 build_info developmentVersion == dev.<patch>、releaseVersion 非空、
    且发行名大版本与线上清单版本前缀一致的提交；同一提交多个 ref 算一个。找不到或多个：失败，不猜。"""
    hits = {}
    tried = []
    for ref, commit in release_refs(cwd):
        bi = build_info_at(commit, cwd)
        dv, rv = str(bi.get('developmentVersion', '')), bi.get('releaseVersion')
        ok = dv == f'dev.{patch}' and isinstance(rv, str) and rv.strip() != '' and major_of(rv) == major_of(channel_version)
        tried.append(f'{ref}@{commit[:9]} {dv} {rv!r}{" ←" if ok else ""}')
        if ok:
            hits.setdefault(commit, []).append(ref)
    if not hits:
        raise Fail(f'发行分支／标签尖端里没有 dev.{patch} 且有发行名的提交（看了 {len(tried)} 个）：\n  ' + '\n  '.join(tried))
    if len(hits) > 1:
        raise Fail(f'dev.{patch} 对上了 {len(hits)} 个不同提交，不猜：' + '；'.join(f'{c[:9]}（{", ".join(r)}）' for c, r in hits.items()))
    commit, refs = next(iter(hits.items()))
    return {'commit': commit, 'refs': refs, 'build_info': build_info_at(commit, cwd), 'tried': tried}


def base_build_info(base_code: int, cwd=REPO) -> dict:
    """老底包（清单 bases 的号）的 build_info：同样只在发行尖端里找 dev.<底包号>，唯一才用。"""
    hits = {}
    for ref, commit in release_refs(cwd):
        bi = build_info_at(commit, cwd)
        if str(bi.get('developmentVersion', '')) == f'dev.{base_code}' and isinstance(bi.get('releaseVersion'), str):
            hits.setdefault(json.dumps(bi, sort_keys=True), []).append(ref)
    return json.loads(next(iter(hits))) if len(hits) == 1 else {}


# ---------------------------------------------------------------- 脱敏树

def worktree_heads() -> dict:
    """git worktree list：提交 → [路径]"""
    out = {}
    cur = None
    for line in git('worktree', 'list', '--porcelain').splitlines():
        if line.startswith('worktree '):
            cur = Path(line[9:])
        elif line.startswith('HEAD ') and cur:
            out.setdefault(line[5:], []).append(cur)
    return out


def generated_source(commit: str) -> tuple:
    """该提交的 generated 从哪儿克隆：优先 HEAD 就在这个提交、且有 generated/db 的工作树；没有就用主工作区的（记下来）。"""
    for p in worktree_heads().get(commit, []):
        g = p / PROJECT_REL / 'modes/xiyou/generated'
        if (g / 'db/Skills.json').is_file():
            return p / PROJECT_REL, '同提交工作树'
    m = main_worktree() / PROJECT_REL
    if (m / 'modes/xiyou/generated/db/Skills.json').is_file():
        return m, '主工作区（该提交没有现成工作树；转换产物按正式源 v0.62.12 生成，与提交无关时一致）'
    raise Fail('找不到可克隆的 generated（主工作区也没有）：先在主工作区补齐')


def clone(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if subprocess.run(['cp', '-cR', str(src), str(dst)]).returncode:
        shutil.copytree(src, dst, symlinks=True)


def release_excludes(project: Path) -> list:
    cfg = project / 'export_presets.cfg'
    cur, out = None, []
    for line in cfg.read_text(encoding='utf-8').splitlines():
        m = re.match(r'^name="(.*)"$', line)
        if m:
            cur = m.group(1)
        m = re.match(r'^exclude_filter="(.*)"$', line)
        if m and cur == 'Windows 发行':
            out = [x.strip() for x in m.group(1).split(',') if x.strip()]
    return out


def prune_tree(tree: Path, excludes: list) -> int:
    """照发行预设的 exclude_filter 删掉不进包的文件（tests/ 留着：取字场景要用测试环境隔离）。"""
    import fnmatch
    n = 0
    pats = [p.lower() for p in excludes if not p.startswith('tests/')]
    for p in sorted(tree.rglob('*'), reverse=True):
        if not p.is_file() or '.godot' in p.parts:
            continue
        rel = str(p.relative_to(tree)).lower()
        if any(fnmatch.fnmatchcase(rel, x) for x in pats):
            p.unlink()
            n += 1
    return n


def godot_bin() -> Path:
    if os.environ.get('XIYOU_GODOT'):
        return Path(os.environ['XIYOU_GODOT'])
    # 07_开发环境/godot 是包一层的脚本，指向同目录的 当前Godot.app（工作树里常没补齐）：要 app 也在才算
    for d in (HERE, main_worktree() / '03_再刷重制_Godot/07_开发环境'):
        if (d / 'godot').exists() and (d / '当前Godot.app').exists():
            return d / 'godot'
    raise Fail('找不到 godot（07_开发环境/godot 或 XIYOU_GODOT）')


def make_sanitized_tree(commit: str, work: Path) -> dict:
    src_wt = work / 'src'
    git('worktree', 'add', '--detach', str(src_wt), commit)
    proj = src_wt / PROJECT_REL
    gsrc, how = generated_source(commit)
    clone(gsrc / 'modes/xiyou/generated', proj / 'modes/xiyou/generated')
    if (gsrc / '.godot').is_dir():
        clone(gsrc / '.godot', proj / '.godot')
    tree = work / 'tree'
    sk = load_mod('发行空壳', HERE / '发行空壳.py')
    sk.make_tree(tree, proj)
    left = sk.is_stub_tree(tree)
    if left:
        raise Fail('发行空壳没换全：' + '、'.join(left))
    pruned = prune_tree(tree, release_excludes(tree))
    return {'src_worktree': str(src_wt), 'tree': str(tree), 'generated_from': str(gsrc), 'generated_how': how,
            'pruned_files': pruned, 'stubbed': len(sk.targets(tree))}


def run_dump(tree: Path, out_json: Path, patch: int, legacy: tuple) -> dict:
    d = tree / '_xxy_pubpack'
    d.mkdir(exist_ok=True)
    shutil.copyfile(DUMP_GD, d / 'dump.gd')
    (d / 'dump.tscn').write_text('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://_xxy_pubpack/dump.gd" id="1"]\n\n'
                                 '[node name="XxyPubpack" type="Node"]\nscript = ExtResource("1")\n', encoding='utf-8')
    args = [str(godot_bin()), '--headless', '--audio-driver', 'Dummy', '--path', str(tree), 'res://_xxy_pubpack/dump.tscn', '--',
            str(out_json), str(patch)]
    if legacy:
        args += [str(legacy[0]), str(legacy[1])]
    r = subprocess.run(args, capture_output=True, text=True, timeout=GODOT_TIMEOUT)
    (out_json.parent / 'godot_取字.log').write_text(r.stdout + '\n--- stderr ---\n' + r.stderr, encoding='utf-8')
    if r.returncode or not out_json.is_file():
        raise Fail(f'无头取字失败（退出码 {r.returncode}），日志 {out_json.parent / "godot_取字.log"}：{r.stderr.strip()[-600:]}')
    d = json.loads(out_json.read_text(encoding='utf-8'))
    if not d.get('ok'):
        raise Fail('取字结果不完整')
    return d


# ---------------------------------------------------------------- 出包内容

NAME_OK = re.compile(r'[\u4e00-\u9fffA-Za-z0-9]')
# 数据库编辑器里的分组标题（「------15层副本扩充」「----------------10」）：游戏里不显示，不出
EDITOR_DIVIDER = re.compile(r'^[-=＝—_~*#─]{2,}')
# 开发用的测试条目（「测试物理100暴击」「测试武器1」）：敌人不剥（木桩之类玩家打得到）
DEV_TEST = re.compile(r'^测试')


# 掉率（X12，Kyo 11-16 定「放宽」，取代 X2「剥」与 T008 严口径）：玩家在游戏里看得到的掉率数字原样留，只防隐藏掉率表。
# 判定法：说明卡（取字脚本 XHelpCard／状态详情的输出）、事件对白（401/405 显示文字）、线上清单更新说明（游戏「更新」页显示）
# 就是玩家看得到的文本，原样出包、不再改字；内部掉落表（dropItems、note、公式、天启篇掉落表）本来就不进包（字段白名单①＋禁字段）。
# 自检②兜底（小A 第二道核 P1 后改严）：包里每一行（json 解码后的字符串值逐行、md 逐行）只要 is_rate_line 认出是掉率句，
# 就必须**整行**等于本次取字抓到的某一行玩家可见文本（行级精确集合，不做子串）；唯一例外是事件块被 3000 字截断时的最后一行，
# 可以是某行可见文本的前缀。未开放条目（open_in_current_version false）的说明只给它自己那一行放行，不进跨文件白名单。
RATE_NUM = re.compile(r'(?<![\d.])\d+(?:\.\d+)?\s*[%％‰]'
                      r'|(?<![\d.])\d+\s*/\s*\d+(?![\d.])'
                      r'|[千万百]分之\s*[\d零〇一二两三四五六七八九十百千万]+'
                      r'|(?<![\d.])\d+(?:\.\d+)?\s*成(?![功就为员本长立年绩分份])')
RATE_KEY = re.compile(r'掉|爆|产出|出率|出货|概率|几率|机率|机会|判定|抽')
BONUS = re.compile(r'[+＋]\s*(?:' + RATE_NUM.pattern + r')')  # 只去明确的「+N%」加成写法；「提高／增加 N%」不豁免（宁可多认）


def is_rate_line(line: str) -> bool:
    """掉率样式的行：去掉 +N% 加成写法后，同时有掉率样式的数（N%、N‰、N/M、千分之N、N成）和掉率词。
    认多了不要紧（玩家可见文本整行放行），认少了才是外泄，所以宁严勿宽。"""
    t = BONUS.sub('', str(line))
    return bool(RATE_KEY.search(t) and RATE_NUM.search(t))


class Visible:
    """本次取字抓到的玩家可见文本，按行（去首尾空白）存成集合；只在内存里，不进包。
    lines：跨文件放行；rows[(数据文件名, public_id)]：未开放条目自己的说明，只放行它自己。"""

    def __init__(self, texts=()):
        self.lines, self.rows = set(), {}
        for t in texts:
            self.add(t)

    def clear(self):
        self.lines.clear()
        self.rows.clear()

    def add(self, text, row=None):
        ls = {x.strip() for x in str(text).split('\n') if x.strip()}
        if row is None:
            self.lines |= ls
        else:
            self.rows.setdefault(row, set()).update(ls)

    def extend(self, texts):
        for t in texts:
            self.add(t)


VISIBLE = Visible()


def keep_visible(text: str, row=None) -> str:
    """玩家看得到的文本原样返回，并记进 VISIBLE（未开放条目记在它自己的 row 下）。"""
    text = str(text)
    VISIBLE.add(text, row)
    return text


def public_id(kind: str, name: str) -> str:
    return f'{kind}-' + hashlib.sha256(f'{kind}|{name}'.encode('utf-8')).hexdigest()[:10]


def build_rows(dump: dict) -> tuple:
    """取字结果 → 数据/<类>.json 的行（剥掉内部 id）；返回 (表, 排除计数)。"""
    tables, excluded = {}, {}
    for fname, kind in KINDS.items():
        rows, seen, ex = [], {}, 0
        for r in dump['kinds'].get(fname, []):
            name = str(r.get('name', '')).strip()
            if not name or not NAME_OK.search(name) or EDITOR_DIVIDER.match(name) or (fname != 'Enemies' and DEV_TEST.match(name)):
                ex += 1
                continue
            pid = public_id(kind, name)
            seen[pid] = seen.get(pid, 0) + 1
            if seen[pid] > 1:
                pid = f'{pid}-{seen[pid]}'
            is_open = bool(r.get('open', True))
            vrow = None if is_open else (fname, pid)
            row = {'public_id': pid, 'name': keep_visible(name, vrow)}  # 名字、称号玩家也看得到（「厄临星爆 30%」这类技能名）
            if r.get('nickname'):
                row['nickname'] = keep_visible(r['nickname'], vrow)
            row['description'] = keep_visible(r.get('description', ''), vrow)
            if int(r.get('price', 0) or 0) > 0 and '价格' in row['description']:
                row['price'] = int(r['price'])
            if fname in ('Weapons', 'Armors') and isinstance(r.get('params'), list):
                row['params'] = [int(x) for x in r['params']]
            row['open_in_current_version'] = is_open
            rows.append(row)
        tables[fname] = rows
        excluded[fname] = ex
    return tables, excluded


TEXT_CODE = re.compile(r'\\[A-Za-z]+\[[^\]]*\]|\\[{}!.|><^$]|\x1b')


NAME_BOX = re.compile(r'\\n<([^>]*)>')
# 游戏里求值后才显示的脚本（\evalText<<$dataArmors.length…>>）、YEP 排版标签（<WordWrap>、<br>）：玩家看到的是结果或什么也不是，脚本原文不进包
EVAL_TEXT = re.compile(r'\\eval\w*<<.*?>>', re.S)
ALPHA_TAG = re.compile(r'</?[A-Za-z][A-Za-z0-9_ :=.\-]*>')


def _plain(t: str) -> str:
    t = EVAL_TEXT.sub('', str(t))
    t = NAME_BOX.sub(r'\1：', t)  # 对话名字框 \n<名字>
    t = ALPHA_TAG.sub('', t)
    return TEXT_CODE.sub('', t).strip()


def build_events(tree: Path, dump: dict) -> list:
    """契约 C3：地图事件与公共事件的对白＋事件给的物品名；不写坐标、开关、变量号。
    id 的哈希输入沿用 kb-index.cjs 现算法（文件名:事件号），只在这里用，不落进 text/title。"""
    gen = tree / 'modes/xiyou/generated'
    names = {}
    for fname, label in (('Items', '物品'), ('Weapons', '武器'), ('Armors', '护甲')):
        names[fname] = {int(r['id']): (label, _plain(r['name'])) for r in dump['kinds'].get(fname, [])
                        if r.get('open', True) and NAME_OK.search(str(r.get('name', '')))}
    code_kind = {126: 'Items', 127: 'Weapons', 128: 'Armors'}
    files = sorted((gen / 'maps').glob('Map*.json'), key=lambda p: int(re.sub(r'\D', '', p.stem) or 0))
    files.append(gen / 'db/CommonEvents.json')
    out = []
    for f in files:
        if not f.is_file():
            continue
        data = json.loads(f.read_text(encoding='utf-8'))
        common = f.name == 'CommonEvents.json'
        place = '公共事件' if common else (_plain(data.get('displayName', '')) or '地图')
        events = data if common else (data.get('events') or [])
        for n, ev in enumerate(events):
            if not ev:
                continue
            pages = ev.get('pages') if isinstance(ev.get('pages'), list) else [{'list': ev.get('list') or []}]
            texts, refs = [], []
            for pg in pages:
                for c in (pg or {}).get('list') or []:
                    if not isinstance(c, dict) or not isinstance(c.get('parameters'), list):
                        continue
                    if c.get('code') in (401, 405):
                        line = _plain(c['parameters'][0] if c['parameters'] else '')
                        if line and line not in texts:
                            texts.append(line)
                    if c.get('code') in code_kind and len(c['parameters']) >= 2 and c['parameters'][1] == 0:
                        hit = names[code_kind[c['code']]].get(int(c['parameters'][0] or 0))
                        if hit and f'[{hit[0]}] {hit[1]}' not in refs:
                            refs.append(f'[{hit[0]}] {hit[1]}')
            if not texts and not refs:
                continue
            texts = [keep_visible(t) for t in texts]  # 对白原样留（X12）
            ref_line = [f'事件给的物品/武器/护甲：{"、".join(refs)}'] if refs else []
            VISIBLE.extend(ref_line)  # 已开放物品名拼的一行，名字玩家都看得到
            body = '\n'.join(texts + ref_line)[:EVENT_CAP]
            eid = ev.get('id', n) if isinstance(ev, dict) else n
            ref = hashlib.sha256(f'{f.name}:{eid}'.encode('utf-8')).hexdigest()[:12]
            first = texts[0][:48] if texts else '事件'
            VISIBLE.add(f'{place} · {first}')  # 标题＝地图名＋首句前 48 字，两段都是玩家看得到的
            out.append({'id': f'事件:{ref}', 'kind': 'event', 'title': f'{place} · {first}', 'source': '事件.jsonl', 'text': body})
    return out


# ---------------------------------------------------------------- C6 禁词表

def forbidden_words(tree: Path, cwd=REPO) -> tuple:
    """返回 (词表, 来源说明)。来源：main 的 tianqi_data/*.json 全部 name、发行空壳替换的类名、固定词表；
    减去在正式源 v0.62.12 转换产物（generated/db、maps 原文）里本来就有的词（那是原版公开名，不是天启篇新增），且至少两个字。"""
    names = set()
    files = [x for x in git('ls-tree', '-r', '--name-only', 'main', f'{PROJECT_REL}/modes/xiyou/tianqi_data/', cwd=cwd).splitlines() if x.endswith('.json')]

    def walk(x):
        if isinstance(x, dict):
            for k, v in x.items():
                if k == 'name' and isinstance(v, str) and v.strip():
                    names.add(v.strip())
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)
    for f in files:
        try:
            walk(json.loads(git('show', f'main:{f}', cwd=cwd)))
        except (Fail, json.JSONDecodeError):
            pass
    sk = load_mod('发行空壳', HERE / '发行空壳.py')
    classes = set(sk.targets(tree).keys()) | set(sk.targets(sk.PROJECT).keys())  # 发行提交里的＋本仓当前的天启篇类名
    gen = tree / 'modes/xiyou/generated'
    corpus = ''.join(p.read_text(encoding='utf-8', errors='replace') for p in list((gen / 'db').glob('*.json')) + list((gen / 'maps').glob('*.json')))
    words, dropped_orig, dropped_short = set(), 0, 0
    for w in names:
        if len(w) < 2:
            dropped_short += 1
        elif w in corpus:
            dropped_orig += 1
        else:
            words.add(w)
    fixed_dropped = [w for w in FIXED_WORDS if w.lower() in corpus.lower()]
    words |= {w for w in FIXED_WORDS if w not in fixed_dropped}
    words |= classes
    src = {'tianqi_data_files': len(files), 'tianqi_data_names': len(names), 'dropped_in_original': dropped_orig,
           'dropped_single_char': dropped_short, 'stub_classes': len(classes), 'fixed_words': len(FIXED_WORDS),
           'fixed_dropped_in_original': fixed_dropped, 'total': len(words),
           'from': '天启篇数值表（main）全部 name；发行空壳替换的类名；固定词表（来源见交付单）'}  # 自检.json 在她能读的目录里：不写工程路径
    return words, src


# ---------------------------------------------------------------- C7 自检

ID_PATTERNS = [re.compile(r'（ID'), re.compile(r'\bID\s*[:：]?\s*\d'), re.compile(r'数据:[a-z]+:\d+\b')]


def pkg_files(root: Path) -> list:
    return sorted(p for p in root.rglob('*') if p.is_file() and p.name != '自检.json')


def check_fields(root: Path) -> list:
    bad = []
    for fname in KINDS:
        p = root / '数据' / f'{fname}.json'
        if not p.is_file():
            bad.append(f'缺 数据/{fname}.json')
            continue
        rows = json.loads(p.read_text(encoding='utf-8'))
        if not isinstance(rows, list):
            bad.append(f'数据/{fname}.json 不是数组')
            continue
        for i, r in enumerate(rows):
            extra = set(r) - ROW_FIELDS
            if extra or 'public_id' not in r:
                bad.append(f'数据/{fname}.json 第 {i} 行：{"多了 " + ",".join(sorted(extra)) if extra else "没有 public_id"}')
    for p in sorted((root / '数据').glob('*')) if (root / '数据').is_dir() else []:
        if p.name.removesuffix('.json') not in KINDS:
            bad.append(f'数据/ 里多了 {p.name}')
    vp = root / '版本.json'
    if vp.is_file():
        v = json.loads(vp.read_text(encoding='utf-8'))
        if set(v) - VERSION_FIELDS or VERSION_REQUIRED - set(v):
            bad.append(f'版本.json 字段不对：多 {sorted(set(v) - VERSION_FIELDS)} 缺 {sorted(VERSION_REQUIRED - set(v))}')
    else:
        bad.append('缺 版本.json')
    ep = root / '事件.jsonl'
    if ep.is_file():
        for i, line in enumerate(ep.read_text(encoding='utf-8').splitlines()):
            if line.strip() and set(json.loads(line)) != EVENT_FIELDS:
                bad.append(f'事件.jsonl 第 {i + 1} 行字段不对')
                break
    else:
        bad.append('缺 事件.jsonl')
    # 禁字段在任何 json 里出现都算（嵌套也查）
    for p in pkg_files(root):
        if p.suffix not in ('.json', '.jsonl'):
            continue
        for line in (p.read_text(encoding='utf-8').splitlines() if p.suffix == '.jsonl' else [p.read_text(encoding='utf-8')]):
            if not line.strip():
                continue
            keys = set()

            def walk(x):
                if isinstance(x, dict):
                    keys.update(x)
                    for v in x.values():
                        walk(v)
                elif isinstance(x, list):
                    for v in x:
                        walk(v)
            walk(json.loads(line))
            hit = (keys & BANNED_FIELDS) - ({'id'} if p.name == '事件.jsonl' else set())
            if hit:
                bad.append(f'{p.relative_to(root)} 有禁字段 {sorted(hit)}')
                break
    return bad


EVENT_CAP = 3000


def _pkg_items(p: Path) -> list:
    """包里一个文件的全部文本行，返回 [(行, 未开放条目键或 None, 是否截断尾行)]：json／jsonl 取所有字符串值（解掉转义，
    \\uXXXX 也解）再按换行拆；md 按行。数据文件里 open_in_current_version 为 false 的行带上 (文件名, public_id)。"""
    t = p.read_text(encoding='utf-8', errors='replace')
    if p.suffix not in ('.json', '.jsonl'):
        return [(x, None, False) for x in t.split('\n')]
    out = []

    def walk(x, row, key=None):
        if isinstance(x, str):
            ls = x.split('\n')
            cut = p.name == '事件.jsonl' and key == 'text' and len(x) >= EVENT_CAP
            out.extend((ln, row, cut and i == len(ls) - 1) for i, ln in enumerate(ls))
        elif isinstance(x, dict):
            r = row
            if p.parent.name == '数据' and x.get('open_in_current_version') is False:
                r = (p.stem, x.get('public_id'))
            for k, v in x.items():
                walk(v, r, k)
        elif isinstance(x, list):
            for v in x:
                walk(v, row)
    try:
        docs = [json.loads(x) for x in t.splitlines() if x.strip()] if p.suffix == '.jsonl' else [json.loads(t)]
    except ValueError:
        return [(x, None, False) for x in t.split('\n')]  # 坏 json 也照行查，宁可多报
    for d in docs:
        walk(d, None)
    return out


def _pkg_lines(p: Path) -> list:
    return [x for x, _, _ in _pkg_items(p)]


def rate_lines(root: Path) -> list:
    """包里实际有的掉率句（出处＋原文），给工作目录日志和 自检.json 计数用。"""
    return [{'where': str(p.relative_to(root)), 'line': ln.strip()}
            for p in pkg_files(root) for ln, _, _ in _pkg_items(p) if is_rate_line(ln)]


def check_forbidden(root: Path, words: set, visible=None) -> list:
    """禁词零命中（查解码后的文本，另查原文兜住键名）；掉率句（X12）必须整行等于玩家可见文本的一行，否则算隐藏掉率。"""
    bad = []
    vis = visible if isinstance(visible, Visible) else Visible(visible or ())
    for p in pkg_files(root):
        for ln, row, cut in _pkg_items(p):
            s = ln.strip()
            if not is_rate_line(s):
                continue
            allowed = vis.rows.get(row, set()) if row else vis.lines
            if s in allowed or (cut and row is None and any(v.startswith(s) for v in vis.lines)):
                continue
            bad.append(f'{p.relative_to(root)}：玩家文本里没有的掉率「{s[:60]}」')
    lw = [(w, w.lower()) for w in words]
    for p in pkg_files(root):
        raw = p.read_text(encoding='utf-8', errors='replace')
        if p.name == '版本.json':
            raw = raw.replace('"tianqi_open"', '')  # 契约 C1 规定的字段名，不是包内容
        t = ('\n'.join(_pkg_lines(p)) + '\n' + raw).lower()  # 解码后（防 \\uXXXX 绕过）＋原文（键名）
        for w, l in lw:
            if l in t:
                bad.append(f'{p.relative_to(root)}：{w}')
    return bad


def check_ids(root: Path) -> list:
    bad = []
    for p in sorted((root / '数据').glob('*.json')) if (root / '数据').is_dir() else []:
        for i, r in enumerate(json.loads(p.read_text(encoding='utf-8'))):
            if 'id' in r:
                bad.append(f'数据/{p.name} 第 {i} 行有 id')
                break
    for p in pkg_files(root):
        t = p.read_text(encoding='utf-8', errors='replace')
        for rx in ID_PATTERNS:
            m = rx.search(t)
            if m:
                bad.append(f'{p.relative_to(root)}：「{t[max(0, m.start() - 10):m.end() + 6]}」')
    return bad


def check_version(root: Path, dump_ver: dict, channel: dict, located_bi: dict) -> list:
    bad = []
    v = json.loads((root / '版本.json').read_text(encoding='utf-8')) if (root / '版本.json').is_file() else {}
    code = int(channel['latest']['code'])
    if not dump_ver.get('label') or dump_ver.get('label') != dump_ver.get('of_patch'):
        bad.append(f'右下角 {dump_ver.get("label")!r} 与补丁号算出的 {dump_ver.get("of_patch")!r} 不一致')
    if v.get('version') != dump_ver.get('label'):
        bad.append(f'版本.json version {v.get("version")!r} 不是游戏算出的 {dump_ver.get("label")!r}')
    if str(v.get('patch')) != str(code):
        bad.append(f'版本.json patch {v.get("patch")!r} 不是线上 {code}')
    if located_bi and str(located_bi.get('developmentVersion')) != f'dev.{code}':
        bad.append(f'导出提交的 build_info 是 {located_bi.get("developmentVersion")}，线上是 {code}')
    return bad


def check_counts(counts: dict, prev: dict) -> list:
    bad = [f'{k} 0 条' for k in KINDS if int(counts.get(k, 0)) <= 0]
    bad += ['事件 0 条'] if int(counts.get('事件', 0)) <= 0 else []
    for k, n in (prev or {}).items():
        if int(n) > 0 and int(counts.get(k, 0)) < int(n) * 0.9:
            bad.append(f'{k} {counts.get(k, 0)} 条，上一版 {n}，掉了一成以上')
    return bad


def check_unique(root: Path) -> list:
    bad = []
    for p in sorted((root / '数据').glob('*.json')) if (root / '数据').is_dir() else []:
        ids = [r.get('public_id') for r in json.loads(p.read_text(encoding='utf-8'))]
        dup = {x for x in ids if ids.count(x) > 1}
        if dup:
            bad.append(f'数据/{p.name} public_id 重复：{sorted(dup)[:5]}')
    return bad


def check_paths(written: list, out: Path) -> list:
    base = out.resolve()
    return [str(p) for p in written if not (Path(p).resolve() == base or base in Path(p).resolve().parents)]


def self_check(root: Path, words: set, dump_ver: dict, channel: dict, located_bi: dict, counts: dict, prev_counts: dict,
               written: list, out: Path, planned: list = (), stage_root: Path = None, visible=None) -> dict:
    """written：本次实际写下的文件，须在 stage_root（默认 out）内；planned：之后要建／改的出口路径（版本目录、当前），须在 out 内；
    visible：玩家可见文本（取字结果），掉率句只认这里面出现过的。"""
    res = {
        CHECKS[0]: check_fields(root),
        CHECKS[1]: check_forbidden(root, words, visible),
        CHECKS[2]: check_ids(root),
        CHECKS[3]: check_version(root, dump_ver, channel, located_bi),
        CHECKS[4]: check_counts(counts, prev_counts),
        CHECKS[5]: check_unique(root),
        CHECKS[6]: check_paths(written, stage_root or out) + check_paths(list(planned), out),
    }
    return {k: {'ok': not v, 'problems': v[:30], 'problem_count': len(v)} for k, v in res.items()}


def file_hashes(root: Path) -> dict:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in pkg_files(root)}


# ---------------------------------------------------------------- 出口

def previous(out: Path) -> tuple:
    """上一版（当前）：(目录, 自检) 或 (None, {})。"""
    cur = out / '当前'
    if not cur.is_symlink() and not cur.exists():
        return None, {}
    d = cur.resolve()
    sj = d / '自检.json'
    return d, (json.loads(sj.read_text(encoding='utf-8')) if sj.is_file() else {})


def tamper_problems(prev_dir: Path, prev_check: dict) -> list:
    """写前比对上一版 自检.json 记的文件清单与哈希（契约 2.1：对不上就报警不覆盖）。"""
    if prev_dir is None:
        return []
    want = prev_check.get('files') or {}
    if not want:
        return [f'上一版 {prev_dir.name} 没有 自检.json 的文件清单']
    got = file_hashes(prev_dir)
    bad = [f'{k} 被改过' for k, h in want.items() if got.get(k) != h]
    bad += [f'{k} 是多出来的' for k in got if k not in want]
    return bad


def switch_current(out: Path, vdir_name: str) -> None:
    tmp = out / f'.当前.tmp{os.getpid()}'
    if tmp.is_symlink() or tmp.exists():
        tmp.unlink()
    os.symlink(vdir_name, tmp)
    os.replace(tmp, out / '当前')


def prune_versions(out: Path, keep_name: str) -> list:
    vs = sorted((p for p in out.iterdir() if p.is_dir() and not p.is_symlink() and p.name.startswith('v')), key=lambda p: p.stat().st_mtime)
    gone = []
    while len(vs) > KEEP_VERSIONS:
        p = vs.pop(0)
        if p.name != keep_name:
            shutil.rmtree(p)
            gone.append(p.name)
    return gone


def write_json(p: Path, obj, written: list) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    written.append(str(p))


def assemble(stage: Path, tables: dict, events: list, version: dict, written: list) -> dict:
    for fname, rows in tables.items():
        write_json(stage / '数据' / f'{fname}.json', rows, written)
    ep = stage / '事件.jsonl'
    ep.write_text(''.join(json.dumps(e, ensure_ascii=False) + '\n' for e in events), encoding='utf-8')
    written.append(str(ep))
    write_json(stage / '版本.json', version, written)
    for m in MD_FILES:
        src = MD_DIR / m
        dst = stage / m
        dst.write_text(src.read_text(encoding='utf-8') if src.is_file() else f'# {m[:-3]}\n\n（待补）\n', encoding='utf-8')
        written.append(str(dst))
    counts = {k: len(v) for k, v in tables.items()}
    counts['事件'] = len(events)
    return counts


def recount(stage: Path) -> dict:
    counts = {}
    for fname in KINDS:
        p = stage / '数据' / f'{fname}.json'
        try:
            counts[fname] = len(json.loads(p.read_text(encoding='utf-8')))
        except (OSError, json.JSONDecodeError):
            counts[fname] = 0
    ep = stage / '事件.jsonl'
    counts['事件'] = sum(1 for x in ep.read_text(encoding='utf-8').splitlines() if x.strip()) if ep.is_file() else 0
    return counts


def inject(stage: Path, what: str, words: set) -> str:
    """反例（验收证据 4）：往待检的包里塞坏东西。"""
    if what == '禁词':
        w = sorted(x for x in words if re.fullmatch(r'[\u4e00-\u9fff·]{3,8}', x))[0]
        p = stage / '数据/Items.json'
        rows = json.loads(p.read_text(encoding='utf-8'))
        rows.append({'public_id': public_id('item', w), 'name': w, 'description': '', 'open_in_current_version': True})
        p.write_text(json.dumps(rows, ensure_ascii=False), encoding='utf-8')
        return f'数据/Items.json 加一行，名字是禁词「{w}」'
    if what == '数字id':
        p = stage / '数据/Skills.json'
        rows = json.loads(p.read_text(encoding='utf-8'))
        rows[0]['id'] = 123
        p.write_text(json.dumps(rows, ensure_ascii=False), encoding='utf-8')
        return '数据/Skills.json 第 0 行加 "id": 123'
    if what == '空目录':
        for p in (stage / '数据').glob('*.json'):
            p.unlink()
        return '数据/ 清空成空目录'
    if what == '隐藏掉率':
        p = stage / '数据/Items.json'
        rows = json.loads(p.read_text(encoding='utf-8'))
        rows[0]['description'] = str(rows[0].get('description', '')) + '\n' + HIDDEN_RATE_PROBE
        p.write_text(json.dumps(rows, ensure_ascii=False), encoding='utf-8')
        return f'数据/Items.json 第 0 行说明末尾加一句游戏文本里没有的掉率「{HIDDEN_RATE_PROBE}」'
    raise Fail(f'--inject 只认 禁词／数字id／空目录／隐藏掉率：{what}')


HIDDEN_RATE_PROBE = '反例：深渊首领每场掉落概率7.25%（隐藏掉率表）'


# ---------------------------------------------------------------- 主流程

def run(a) -> int:
    out = Path(a.out).expanduser()
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S')
    work = WORK_ROOT / f'{stamp}_{os.getpid()}'
    work.mkdir(parents=True, exist_ok=True)
    src_wt = None
    rc = 1
    try:
        log('== C5 线上清单')
        if a.channel_file:
            ch = {'src': f'本地文件 {a.channel_file}（测试，不算线上核过）', 'channel': json.loads(Path(a.channel_file).read_text(encoding='utf-8')), 'sha256': ''}
            log(f'  ⚠ {ch["src"]}')
        else:
            ch = online_channel()
        channel = ch['channel']
        patch = int(channel['latest']['code'])
        log(f'  线上补丁号 {patch}（清单版本 {channel["latest"]["version"]}，{ch["src"]}）')
        log('== C5 定位发行提交')
        if a.ref:
            commit = git('rev-parse', f'{a.ref}^{{commit}}').strip()
            loc = {'commit': commit, 'refs': [f'--ref {a.ref}'], 'build_info': build_info_at(commit), 'tried': []}
        else:
            loc = locate(patch, channel['latest']['version'])
        log(f'  {patch} → 提交 {loc["commit"]}（{", ".join(loc["refs"])}）build_info {json.dumps(loc["build_info"], ensure_ascii=False)}')
        bases = sorted(int(x) for x in (channel.get('bases') or {}))
        release_base = bases[-1] if bases else None
        legacy = None
        if release_base:
            bbi = base_build_info(release_base)
            if bbi.get('releaseVersion'):
                legacy = (str(bbi['releaseVersion']).lstrip('v'), int(bbi.get('releaseBase') or release_base))
        if a.from_dump:
            dump = json.loads(Path(a.from_dump).read_text(encoding='utf-8'))
            tree_info = json.loads((Path(a.from_dump).parent / '脱敏树.json').read_text(encoding='utf-8'))
            tree = Path(tree_info['tree'])
            log(f'  ⚠ --from-dump {a.from_dump}：不重建树、不跑 Godot（脱敏树 {tree}）')
        else:
            log('== 脱敏树')
            tree_info = make_sanitized_tree(loc['commit'], work)
            src_wt = tree_info['src_worktree']
            tree = Path(tree_info['tree'])
            (work / '脱敏树.json').write_text(json.dumps(tree_info, ensure_ascii=False, indent=1), encoding='utf-8')
            log(f'  脱敏树 {tree}（generated 来自 {tree_info["generated_how"]} {tree_info["generated_from"]}；空壳 {tree_info["stubbed"]} 个；按发行预设删 {tree_info["pruned_files"]} 个文件）')
            log('== 无头取字')
            dump = run_dump(tree, work / '取字.json', patch, legacy)
        ver = dump['version']
        log(f'  右下角 {ver.get("label")}；补丁号算出 {ver.get("of_patch")}；老底包弹窗 {ver.get("legacy_popup", "—")}；发行门 {dump.get("release")}')
        VISIBLE.clear()
        tables, excluded = build_rows(dump)
        events = build_events(tree, dump)
        words, wsrc = forbidden_words(tree)
        prev_dir, prev_check = previous(out)
        prev_ver = None
        if prev_dir is not None and (prev_dir / '版本.json').is_file():
            prev_ver = json.loads((prev_dir / '版本.json').read_text(encoding='utf-8')).get('version')
        if a.major == 'auto':
            mid = lambda v: (str(v).lstrip('v').split('.') + ['', ''])[1]  # noqa: E731
            major = bool(prev_ver) and mid(prev_ver) != mid(ver.get('label'))
        else:
            major = a.major == 'true'
        published = channel['latest'].get('date', '')
        try:
            repo = Path(ch.get('repo') or '')
            if repo.is_dir() and hashlib.sha256((repo / 'godot/channel.json').read_bytes()).hexdigest() == ch.get('sha256'):
                published = git('log', '-1', '--format=%cd', '--date=format:%Y-%m-%d %H:%M', '--', 'godot/channel.json', cwd=repo).strip() or published
        except Exception:  # noqa: BLE001
            pass
        if len(published) == 10:
            published += ' 00:00'
        version = {'game': GAME, 'version': ver.get('label', ''), 'patch': str(patch),
                   'release_base': str(release_base) if release_base else '', }
        if ver.get('legacy_popup'):
            version['legacy_popup_version'] = ver['legacy_popup']
        version.update({'published_at': published, 'major_content': major, 'tianqi_open': False,
                        'highlights': [str(x) for x in channel['latest'].get('notes') or []], 'source_commit': loc['commit']})
        VISIBLE.extend(version['highlights'])  # 线上清单的更新说明游戏「更新」页照原文显示，玩家看得到
        vname = 'v' + str(ver.get('label', '')).lstrip('v')
        stage = (work / 'stage' / vname) if a.dry_run else (out / f'.stage-{vname}-{os.getpid()}')
        if stage.exists():
            shutil.rmtree(stage)
        written = []
        counts = assemble(stage, tables, events, version, written)
        kept = rate_lines(stage)  # 截断后实际进包的掉率句（注入之前）
        (work / '掉率原样留.json').write_text(json.dumps(kept, ensure_ascii=False, indent=1), encoding='utf-8')
        log(f'  包里玩家看得到的掉率句原样留 {len(kept)} 行（X12；出处见 {work / "掉率原样留.json"}，不进包）')
        injected = inject(stage, a.inject, words) if a.inject else None
        if injected:
            log(f'  ⚠ 反例注入：{injected}')
        counts = recount(stage)  # 按待检目录里真有的重数（注入、写坏都算进去）
        checks = self_check(stage, words, ver, channel, loc['build_info'], counts, (prev_check or {}).get('counts') or {},
                            written, out, [str(out / vname), str(out / '当前')], stage.parent if a.dry_run else out, VISIBLE)
        ok = all(c['ok'] for c in checks.values())
        report = {
            'ok': ok, 'checks': checks, 'counts': counts, 'excluded': excluded, 'forbidden': wsrc,
            'source_commit': loc['commit'], 'source_refs': loc['refs'], 'used_ref': a.ref or None,
            'from_dump': a.from_dump or None, 'injected': injected, 'channel_source': ch['src'],
            'channel_sha256': ch.get('sha256', ''), 'generated_from': tree_info.get('generated_how'),
            'major_basis': f'上一版 {prev_ver}' if prev_ver else ('命令行 --major' if a.major != 'auto' else '没有上一版，默认 false'),
            'release_gate': dump.get('release'), 'dry_run': a.dry_run, 'drop_rate_lines_kept_visible': len(kept),
            'generated_at': dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'files': file_hashes(stage),
        }
        write_json(stage / '自检.json', report, written)
        log('== 自检')
        for k, c in checks.items():
            log(f'  {"✓" if c["ok"] else "✗"} {k}' + ('' if c['ok'] else f'：{c["problem_count"]} 处，如 {c["problems"][:3]}'))
        if not ok:
            log(f'✗ 自检没过：不切「当前」（待检目录 {stage}）')
            if not a.dry_run:
                shutil.rmtree(stage, ignore_errors=True)
                log('  待检目录已删')
            return 1
        if a.dry_run:
            log(f'✓ --dry-run：自检通过，包在 {stage}（没写出口）')
            log((stage / '自检.json').read_text(encoding='utf-8'))
            return 0
        tp = tamper_problems(prev_dir, prev_check)
        if tp:
            shutil.rmtree(stage, ignore_errors=True)
            raise Fail('上一版目录和它 自检.json 记的文件对不上（有人在出口里写过），报警不覆盖：' + '；'.join(tp[:8]))
        final = out / vname
        if final.exists():
            old = out / f'.old-{vname}-{os.getpid()}'
            os.replace(final, old)
            os.replace(stage, final)
            switch_current(out, vname)
            shutil.rmtree(old)
        else:
            os.replace(stage, final)
            switch_current(out, vname)
        gone = prune_versions(out, vname)
        log(f'✓ 出包 {final}；当前 → {vname}' + (f'；清掉旧版 {gone}' if gone else ''))
        log((final / '自检.json').read_text(encoding='utf-8'))
        rc = 0
        return 0
    finally:
        if src_wt:
            git('worktree', 'remove', '--force', src_wt, check=False)
        if not a.keep_work and not a.dry_run and rc == 0:
            shutil.rmtree(work, ignore_errors=True)
        else:
            log(f'  工作目录留着：{work}')


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description='玩家资料包（小小鱼）')
    ap.add_argument('--ref')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--out', default=str(DEFAULT_OUT))
    ap.add_argument('--major', choices=('auto', 'true', 'false'), default='auto')
    ap.add_argument('--from-dump')
    ap.add_argument('--inject', choices=('禁词', '数字id', '空目录', '隐藏掉率'))
    ap.add_argument('--keep-work', action='store_true')
    ap.add_argument('--channel-file')
    a = ap.parse_args(argv)
    try:
        return run(a)
    except Fail as e:
        log(f'✗ {e}')
        return 1


if __name__ == '__main__':
    sys.exit(main())
