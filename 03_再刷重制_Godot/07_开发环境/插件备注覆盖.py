#!/usr/bin/env python3
"""插件备注覆盖（只读）：原版启用插件认的备注标签／插件命令 × 冻结数据里的用量 × 重制有没有读它。

专抓 YEP_X_ExtDoT 那类「按插件名对照查不出」的缺口：`<DoT Formula: …>` 是 meta 键，
不是重制代码里的字面量，只能反过来从数据里的用量往下查。

  python3 插件备注覆盖.py              # markdown 表（数据用量>0 且重制没读 排前面）
  python3 插件备注覆盖.py --json       # 机器可读
  python3 插件备注覆盖.py --all        # 连数据里没用到的标签也列出
  python3 插件备注覆盖.py --no-generated   # 不扫重制生成数据（默认有就扫）

判定（三态）：
  已读   重制工程代码（.gd，不含 tests/）或转换器代码里按标签名出现（词边界、大小写／空格／下划线归一）
  没读   工程、转换器里都找不到，也没有任何子串命中
  拿不准 只在测试／探针里出现、只有子串命中、标签过短（<5 字符）、或读法可能是动态拼名
只读：不写任何文件。
"""
import argparse
import json
import re
import sys
import warnings
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
GODOT_ROOT = HERE.parent
FROZEN = GODOT_ROOT / '02_内容与素材/冻结正式源/app.nw'
PROJECT = GODOT_ROOT / '01_Godot工程'
CONVERTER = GODOT_ROOT / '03_转换工具'
GENERATED_DB = PROJECT / 'modes/xiyou/generated/db'

# 不是备注标签的 HTML／文本控制码
HTML_NOISE = {
    'br', 'b', 'i', 'u', 'p', 'a', 'div', 'span', 'img', 'font', 'li', 'ul', 'ol', 'tr', 'td', 'table',
    'script', 'style', 'html', 'body', 'head', 'canvas', 'input', 'button', 'select', 'option', 'center',
}


# ---------------------------------------------------------------- 归一
def norm_plain(s):
    """标签名归一：小写、去空白／下划线／连字符，数字串→#。"""
    s = s.lower()
    s = re.sub(r'[\s_\-　]+', '', s)
    s = re.sub(r'\d+', '#', s)
    return s


def norm_doc(s):
    """帮助文档里的占位（Item n Cost、Item x Cost）→ #。"""
    s = re.sub(r'(?<![A-Za-z])[nxy](?![A-Za-z])', '#', s.strip(), flags=re.I)
    return norm_plain(s)


# ---------------------------------------------------------------- 插件源码抽取
def strip_js_comments(src):
    """去掉 JS 注释，返回 (代码, 块注释列表)。字符串／正则里的 // 不处理得太细，够用即可。"""
    blocks = re.findall(r'/\*.*?\*/', src, flags=re.S)
    code = re.sub(r'/\*.*?\*/', ' ', src, flags=re.S)
    code = re.sub(r'(?m)^\s*//.*$', '', code)
    code = re.sub(r'(?m)(?<=[;{}),\s])//[^\'"`\n]*$', '', code)
    return code, blocks


def _split_alts(body):
    out, depth, cur = [], 0, ''
    for ch in body:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == '|' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    out.append(cur)
    return out


def tokenize_tag(s, i=0):
    """从 s[i] 起把正则／字符串里的标签名展开成候选名列表（(?:A|B) 展开、捕获组→#/*）。"""
    results = ['']
    n = len(s)
    while i < n:
        ch = s[i]
        if ch == '(' and s[i:i + 3] == '(?:':
            depth, j = 1, i + 3
            while j < n and depth:
                if s[j] == '(':
                    depth += 1
                elif s[j] == ')':
                    depth -= 1
                j += 1
            body = s[i + 3:j - 1]
            alts = []
            for a in _split_alts(body):
                alts.extend(tokenize_tag(a)[0] or [''])
            alts = alts[:20] or ['']
            results = [r + a for r in results for a in alts][:60]
            i = j
            if i < n and s[i] in '?*+':
                i += 1
            continue
        if ch == '(':
            depth, j = 1, i + 1
            while j < n and depth:
                if s[j] == '(':
                    depth += 1
                elif s[j] == ')':
                    depth -= 1
                j += 1
            grp = s[i + 1:j - 1]
            ph = '#' if re.search(r'\\d', grp) else '*'
            results = [r + ph for r in results]
            i = j
            if i < n and s[i] in '?*+':
                i += 1
            continue
        if ch == '\\':
            nx = s[i + 1] if i + 1 < n else ''
            if nx == 's' or nx == ' ':
                results = [r + ' ' for r in results]
                i += 2
                if i < n and s[i] in '*+?':
                    i += 1
                continue
            if nx == '/':
                i += 2
                continue
            if nx == 'd':
                results = [r + '#' for r in results]
                i += 2
                if i < n and s[i] in '*+?':
                    i += 1
                continue
            break
        if ch == '[':
            if s[i:i + 3] == '[ ]':
                results = [r + ' ' for r in results]
                i += 3
                if i < n and s[i] in '*+?':
                    i += 1
                continue
            break
        if ch in ':>\'"`.*+?{}^$|)/<=,;':
            break
        results = [r + ch for r in results]
        i += 1
    return results, i


def extract_code_tags(code):
    """代码里的 `<标签…` 正则／字符串，返回 {归一名: 原始写法示例}。"""
    tags = {}
    for m in re.finditer(r'<', code):
        p = m.start()
        prev = code[p - 1] if p else ' '
        if not (prev in '/\'"`^(|*+ \t' ):
            continue
        j = p + 1
        if j >= len(code) or code[j] in ' =<\n\t':
            continue
        if code[j:j + 2] == '\\/':
            j += 2
        elif code[j] == '/':
            j += 1
        line_end = code.find('\n', j)
        seg = code[j:line_end if line_end >= 0 else len(code)][:160]
        names, _ = tokenize_tag(seg)
        for nm in names:
            nm = nm.strip()
            if len(nm) < 2 or not re.search(r'[A-Za-z一-鿿]', nm):
                continue
            key = norm_plain(nm)
            if key in HTML_NOISE or len(key) < 2:
                continue
            tags.setdefault(key, nm)
    return tags


def extract_meta_keys(code):
    keys = {}
    for m in re.finditer(r'\bmeta\.([A-Za-z_]\w*)', code):
        keys.setdefault(norm_plain(m.group(1)), m.group(1))
    for m in re.finditer(r'\bmeta\[\s*([\'"])(.+?)\1\s*\]', code):
        keys.setdefault(norm_plain(m.group(2)), m.group(2))
    return {k: v for k, v in keys.items() if k not in ('tolowercase', 'length', 'hasownproperty')}


def extract_doc_tags(blocks):
    tags = {}
    for b in blocks:
        for m in re.finditer(r'<(/?)([^<>:\n*]{2,50}?)\s*(?::[^<>\n]*)?>', b):
            nm = m.group(2).strip()
            if not re.search(r'[A-Za-z一-鿿]', nm) or ' ' in nm.strip() and len(nm) > 40:
                continue
            key = norm_doc(nm)
            if key in HTML_NOISE or len(key) < 2:
                continue
            tags.setdefault(key, nm)
    return tags


def extract_commands(code, doc_blocks=()):
    cmds = {}
    if 'pluginCommand' not in code and 'registerCommand' not in code:
        return cmds
    for m in re.finditer(r'\b(?:command|cmd|com|c)\s*===?\s*([\'"])(.+?)\1', code, flags=re.I):
        cmds.setdefault(re.sub(r'\s+', '', m.group(2)).lower(), m.group(2))
    for m in re.finditer(r'\bcase\s+([\'"])([^\'"]{2,40})\1\s*:', code):
        cmds.setdefault(re.sub(r'\s+', '', m.group(2)).lower(), m.group(2))
    for m in re.finditer(r'\b(?:command|cmd)\.match\(\s*/\^?\s*([A-Za-z一-鿿][\w一-鿿 ]{1,40}?)(?:[\\/\s(\[$])', code):
        cmds.setdefault(re.sub(r'\s+', '', m.group(1)).lower(), m.group(1))
    for m in re.finditer(r'registerCommand\([^,]+,\s*([\'"])(.+?)\1', code):
        cmds.setdefault(re.sub(r'\s+', '', m.group(2)).lower(), m.group(2))
    return cmds


def load_plugin_sources():
    """返回 [(来源名, 路径, 是否启用)]。"""
    out = []
    pj = FROZEN / 'js/plugins.js'
    s = pj.read_text(encoding='utf8')
    plugins = json.loads(s[s.index('['):s.rindex(']') + 1])
    for p in plugins:
        f = FROZEN / 'js/plugins' / (p['name'] + '.js')
        if f.exists():
            out.append((p['name'], f, bool(p.get('status'))))
    mods = FROZEN / 'js/codex/modules.json'
    enabled = set()
    if mods.exists():
        enabled = {Path(x).name for x in json.loads(mods.read_text(encoding='utf8')).get('modules', [])}
    for f in sorted((FROZEN / 'js/codex/runtime').glob('install*.js')):
        out.append(('codex/' + f.stem, f, f.name in enabled))
    return out


def collect_plugin_tags():
    """{归一标签: {'raw':..., 'plugins': set, 'kind': 'tag'|'meta'|'doc'|'cmd', 'doc_only': bool}}"""
    tags = {}
    cmds = {}
    for name, f, enabled in load_plugin_sources():
        if not enabled:
            continue
        src = f.read_text(encoding='utf8', errors='replace')
        code, blocks = strip_js_comments(src)
        for key, raw in extract_code_tags(code).items():
            t = tags.setdefault(key, {'raw': raw, 'plugins': set(), 'in_code': False, 'in_doc': False, 'in_meta': False})
            t['plugins'].add(name)
            t['in_code'] = True
        for key, raw in extract_meta_keys(code).items():
            t = tags.setdefault(key, {'raw': raw, 'plugins': set(), 'in_code': False, 'in_doc': False, 'in_meta': False})
            t['plugins'].add(name)
            t['in_meta'] = True
        for key, raw in extract_doc_tags(blocks).items():
            t = tags.setdefault(key, {'raw': raw, 'plugins': set(), 'in_code': False, 'in_doc': False, 'in_meta': False})
            t['plugins'].add(name)
            t['in_doc'] = True
        for key, raw in extract_commands(code).items():
            c = cmds.setdefault(key, {'raw': raw, 'plugins': set()})
            c['plugins'].add(name)
    return tags, cmds


# ---------------------------------------------------------------- 冻结数据用量
TAG_IN_NOTE = re.compile(r'<(/?)([^<>:\n]{1,60}?)\s*(?::[^\n]*?)?>')


class Usage:
    def __init__(self):
        self.count = Counter()           # 标签 -> 条数
        self.by_kind = defaultdict(Counter)   # 标签 -> {数据类: 条数}
        self.examples = defaultdict(list)     # 标签 -> [id…]
        self.sample = {}                      # 标签 -> 一条完整原文（<标签: 值>），给重制的通用正则试匹配

    def add(self, key, kind, ident):
        self.count[key] += 1
        self.by_kind[key][kind] += 1
        if len(self.examples[key]) < 3 and ident not in self.examples[key]:
            self.examples[key].append(ident)


SAMPLES = {}   # 归一标签 -> 原文样本（全局，扫描时顺手记）


def note_tags(text):
    seen = set()
    for m in TAG_IN_NOTE.finditer(text):
        k = norm_plain(m.group(2))
        if k:
            seen.add(k)
            if k not in SAMPLES and not m.group(1):
                sample = m.group(0)[:160]
                if ':' not in m.group(0):   # 块标签：带上收尾标签，通用的「块」正则才对得上
                    close = text.find('</' + m.group(2).strip() + '>', m.end())
                    if close >= 0:
                        sample = text[m.start():close + len(m.group(2)) + 3][:2000]
                SAMPLES[k] = sample
    return seen


def scan_json_tree(obj, stem, ids, tag_usage, cmd_lines, tag_filter):
    """递归：note 字段、事件注释(108/408)、插件命令(356/357)。"""
    if isinstance(obj, dict):
        if isinstance(obj.get('id'), int) and len(ids) < 3:
            ids = ids + [obj['id']]
        idtxt = '/'.join(str(i) for i in ids)
        ident = f'{stem}#{idtxt}' if idtxt else stem
        kind = 'Map' if stem.startswith('Map') and stem[3:].isdigit() else stem
        note = obj.get('note')
        if isinstance(note, str) and note:
            for k in note_tags(note):
                tag_usage.add(k, kind + '.note', ident)
        code = obj.get('code')
        params = obj.get('parameters')
        if code in (108, 408) and isinstance(params, list) and params and isinstance(params[0], str):
            for k in note_tags(params[0]):
                tag_usage.add(k, kind + '.注释', ident)
        elif code == 356 and isinstance(params, list) and params and isinstance(params[0], str):
            cmd_lines.append((params[0], kind, ident))
        elif code == 357 and isinstance(params, list) and len(params) > 1 and isinstance(params[1], str):
            cmd_lines.append((params[1], kind, ident))
        for v in obj.values():
            if isinstance(v, (dict, list)):
                scan_json_tree(v, stem, ids, tag_usage, cmd_lines, tag_filter)
    elif isinstance(obj, list):
        for v in obj:
            if isinstance(v, (dict, list)):
                scan_json_tree(v, stem, ids, tag_usage, cmd_lines, tag_filter)


def scan_frozen_data(data_dir):
    tag_usage = Usage()
    cmd_lines = []
    for f in sorted(data_dir.glob('*.json')):
        try:
            obj = json.loads(f.read_text(encoding='utf8'))
        except Exception:
            continue
        scan_json_tree(obj, f.stem, [], tag_usage, cmd_lines, None)
    return tag_usage, cmd_lines


def scan_generated(db_dir):
    """重制生成数据里还保留着哪些标签（note 里）。{标签: 条数}"""
    if not db_dir.is_dir():
        return None
    u = Usage()
    for f in sorted(db_dir.glob('*.json')):
        try:
            obj = json.loads(f.read_text(encoding='utf8'))
        except Exception:
            continue
        scan_json_tree(obj, f.stem, [], u, [], None)
    return u.count


# ---------------------------------------------------------------- 重制代码语料
def strip_hash_comments(text, line_comment='#'):
    out = []
    for line in text.split('\n'):
        s = line.lstrip()
        if s.startswith(line_comment):
            continue
        # 行尾注释：避开字符串
        q = None
        cut = None
        i = 0
        while i < len(line):
            ch = line[i]
            if q:
                if ch == '\\':
                    i += 1
                elif ch == q:
                    q = None
            elif ch in '"\'':
                q = ch
            elif ch == line_comment:
                cut = i
                break
            i += 1
        out.append(line[:cut] if cut is not None else line)
    return '\n'.join(out)


def read_corpus():
    """{'gd': str, 'conv': str, 'test': str}：工程代码、转换器代码、测试／探针。"""
    gd, conv, test = [], [], []
    for f in PROJECT.rglob('*.gd'):
        try:
            rel = f.relative_to(PROJECT)
        except ValueError:
            continue
        text = strip_hash_comments(f.read_text(encoding='utf8', errors='replace'))
        (test if rel.parts[0] == 'tests' else gd).append(text)
    for ext in ('*.py', '*.cjs', '*.js'):
        for f in CONVERTER.rglob(ext):
            rel = f.relative_to(CONVERTER).parts
            if rel[0] in ('ui_reference', 'mv_oracle', '预检') or '.sandbox' in rel or 'node_modules' in rel:
                if rel[0] == 'mv_oracle' and '.sandbox' not in rel and 'node_modules' not in rel:
                    test.append(f.read_text(encoding='utf8', errors='replace'))
                continue
            text = f.read_text(encoding='utf8', errors='replace')
            if ext == '*.py':
                text = strip_hash_comments(text)
            conv.append(text)
    # 重制数据驱动配置（切片清单）也算转换器输入
    sl = CONVERTER / 'xiyou_slice.json'
    return {k: '\n'.join(v) for k, v in (('gd', gd), ('conv', conv), ('test', test))}


STR_LIT = re.compile(r'''(?<![A-Za-z0-9_])r?"((?:[^"\\\n]|\\.)*<(?:[^"\\\n]|\\.)*)"|(?<![A-Za-z0-9_])r?'((?:[^'\\\n]|\\.)*<(?:[^'\\\n]|\\.)*)\'''')
DECOYS = ['<ZzQxNoSuchTag: 1>', '<Foo Bar>', '<abc>', '<>', '<x: y>']


def harvest_regexes(texts):
    """重制代码里含 `<` 的字符串常量里，能编译成正则、又不是「匹配任意尖括号」的那些。"""
    pats = {}
    for src in texts:
        for m in STR_LIT.finditer(src):
            lit = m.group(1) if m.group(1) is not None else m.group(2)
            if len(lit) > 300 or not re.search(r'[\[\(\\*+?]', lit) or lit.count('<') == 0 or '>' not in lit:  # 没有收尾 > 的多半是拼接片段或前缀判断，不算
                continue
            cand = {lit}
            if '\\\\' in lit:
                cand.add(lit.replace('\\\\', '\\'))
            for c in cand:
                c = re.sub(r'^\(\?i\)', '', c)
                try:
                    with warnings.catch_warnings():
                        warnings.simplefilter('ignore')
                        rx = re.compile(c, re.I)
                except re.error:
                    continue
                if any(rx.search(d) for d in DECOYS):
                    continue
                pats.setdefault(c, rx)
    return pats


def squash(s):
    return re.sub(r'[\s_\-]+', '', s.lower())


class Corpus:
    def __init__(self, texts):
        self.raw = texts
        self.flat = {k: squash(v) for k, v in texts.items()}
        self.cache = {}

    def find(self, key):
        """key 为归一标签名（可含 # *）。返回 {'gd': 精确, 'conv': 精确, 'test': 精确, 'sub': 子串}"""
        if key in self.cache:
            return self.cache[key]
        parts = [p for p in re.split(r'[#*]+', key) if p]
        res = {'gd': False, 'conv': False, 'test': False, 'sub': False}
        if not parts:
            self.cache[key] = res
            return res
        for k in self.raw:
            if not all(p in self.flat[k] for p in parts):
                continue
            res['sub'] = True
            pieces = [r'[ _\-]?'.join(re.escape(c) for c in p) for p in parts]
            pat = r'(?<![A-Za-z0-9])' + r'.{0,14}'.join(pieces) + r'(?![a-z])'
            if re.search(pat, self.raw[k], flags=re.I):
                res[k] = True
        self.cache[key] = res
        return res


def plugin_pattern(key):
    """插件标签 → 匹配数据标签的正则（# 是数字、* 是任意）。"""
    out = ''
    for ch in key:
        out += r'\d*#|#' if False else ('#' if ch == '#' else ('.+' if ch == '*' else re.escape(ch)))
    return re.compile('^' + out + '$')


def judge(key, res, usage_count):
    L = len(re.sub(r'[#*]', '', key))
    code_hit = res['gd'] or res['conv']
    if code_hit:
        if L < 5:
            return '拿不准', '标签过短，命中可能是子串／变量名'
        where = '工程' if res['gd'] else '转换器'
        return '已读', where
    if res['test']:
        return '拿不准', '仅测试／探针里出现'
    if res['sub']:
        return '拿不准', '只有子串命中（词边界不符，可能被改名或动态拼名）'
    if L < 3:
        return '拿不准', '标签过短'
    return '没读', '工程、转换器、测试里都找不到'


# ---------------------------------------------------------------- 汇总
def build_report(use_generated=True, all_tags=False):
    tags, cmds = collect_plugin_tags()
    usage, cmd_lines = scan_frozen_data(FROZEN / 'data')
    gen = scan_generated(GENERATED_DB) if use_generated else None
    texts = read_corpus()
    corpus = Corpus(texts)
    remake_rx = harvest_regexes([texts['gd'], texts['conv']])

    # 数据标签 → 插件标签（含占位）
    pats = {k: plugin_pattern(k) for k in tags}
    data_hits = defaultdict(lambda: {'count': 0, 'kinds': Counter(), 'examples': []})
    for dk, cnt in usage.count.items():
        for k, pat in pats.items():
            if pat.match(dk):
                h = data_hits[k]
                h['count'] += cnt
                h['kinds'].update(usage.by_kind[dk])
                for e in usage.examples[dk]:
                    if len(h['examples']) < 3 and e not in h['examples']:
                        h['examples'].append(e)
    rows = []
    for k, t in tags.items():
        h = data_hits.get(k)
        if h is None and not all_tags:   # 数据里没用到的不查重制（省时间；--all 才查）
            rows.append({'kind': '备注标签', 'name': t['raw'], 'key': k, 'plugins': sorted(t['plugins']),
                         'doc_only': t['in_doc'] and not t['in_code'] and not t['in_meta'], 'data_count': 0,
                         'data_kinds': {}, 'examples': [], 'generated_count': None, 'verdict': '未用', 'why': '冻结数据里没用到'})
            continue
        res = corpus.find(k)
        verdict, why = judge(k, res, h['count'] if h else 0)
        if verdict != '已读' and h:
            sample = SAMPLES.get(next((dk for dk in usage.count if pats[k].match(dk)), ''), '')
            hit = next((pat for pat, rx in remake_rx.items() if rx.search(sample)), None) if sample else None
            if hit:
                verdict, why = '已读', '通用正则命中：' + hit[:40]
        gen_n = None
        if gen is not None and h:
            gen_n = sum(c for dk, c in gen.items() if pats[k].match(dk))
        rows.append({
            'kind': '备注标签',
            'name': t['raw'], 'key': k, 'plugins': sorted(t['plugins']),
            'doc_only': t['in_doc'] and not t['in_code'] and not t['in_meta'],
            'data_count': h['count'] if h else 0,
            'data_kinds': dict(h['kinds']) if h else {},
            'examples': h['examples'] if h else [],
            'generated_count': gen_n,
            'verdict': verdict, 'why': why,
        })
    # 插件命令
    first_tokens = Counter()
    first_ex = defaultdict(list)
    full_lines = Counter()
    full_ex = defaultdict(list)
    for line, kind, ident in cmd_lines:
        ft = line.strip().split(' ')[0].lower()
        first_tokens[ft] += 1
        if len(first_ex[ft]) < 3:
            first_ex[ft].append(ident)
        nl = re.sub(r'\s+', '', line).lower()
        full_lines[nl] += 1
        if len(full_ex[nl]) < 3:
            full_ex[nl].append(ident)
    for k, c in cmds.items():
        cnt = first_tokens.get(k, 0)
        ex = list(first_ex.get(k, []))
        if cnt == 0:
            for nl, n in full_lines.items():
                if nl.startswith(k):
                    cnt += n
                    ex += full_ex[nl]
            ex = ex[:3]
        if cnt == 0 and not all_tags:
            verdict, why = '未用', '冻结数据里没用到'
        else:
            res = corpus.find(norm_plain(c['raw']))
            verdict, why = judge(norm_plain(c['raw']), res, cnt)
        rows.append({
            'kind': '插件命令', 'name': c['raw'], 'key': k, 'plugins': sorted(c['plugins']),
            'doc_only': False, 'data_count': cnt, 'data_kinds': {}, 'examples': ex[:3],
            'generated_count': None, 'verdict': verdict, 'why': why,
        })
    order = {'没读': 0, '拿不准': 1, '已读': 2, '未用': 3}
    rows.sort(key=lambda r: (0 if r['data_count'] > 0 else 1, order[r['verdict']], -r['data_count'], r['key']))
    return rows


def render_markdown(rows, show_all):
    shown = [r for r in rows if show_all or r['data_count'] > 0]
    lines = ['# 插件备注覆盖', '',
             f'标签／命令共 {len(rows)} 个，数据里有用量的 {sum(1 for r in rows if r["data_count"] > 0)} 个。',
             '', '| 判定 | 类 | 标签／命令 | 插件 | 数据用量 | 数据类 | 举例 | 生成数据 | 说明 |',
             '|---|---|---|---|---|---|---|---|---|']
    for r in shown:
        kinds = '、'.join(f'{k}×{v}' for k, v in sorted(r['data_kinds'].items(), key=lambda kv: -kv[1])[:3])
        pl = '、'.join(r['plugins'][:2]) + ('…' if len(r['plugins']) > 2 else '')
        gen = '-' if r['generated_count'] is None else str(r['generated_count'])
        name = r['name'].replace('|', '\\|') + ('（仅文档）' if r['doc_only'] else '')
        lines.append(f'| {r["verdict"]} | {r["kind"]} | `{name}` | {pl} | {r["data_count"]} | {kinds} | '
                     f'{"、".join(r["examples"])} | {gen} | {r["why"]} |')
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--all', action='store_true', help='数据里没用到的标签也列出')
    ap.add_argument('--no-generated', action='store_true')
    a = ap.parse_args()
    rows = build_report(use_generated=not a.no_generated, all_tags=a.all)
    if a.json:
        print(json.dumps(rows, ensure_ascii=False, indent=1))
    else:
        print(render_markdown(rows, a.all))
    return 0


if __name__ == '__main__':
    sys.exit(main())
