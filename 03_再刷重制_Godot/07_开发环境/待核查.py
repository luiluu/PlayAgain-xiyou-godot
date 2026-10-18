#!/usr/bin/env python3
"""由提交尾注生成「待交叉核查」清单：带 `核查: 待Codex|待Claude` 的提交，减去变更记录（当前卷与分卷）里核查条目已覆盖的。

用法：待核查.py [--root 路径] [--json] [--limit N]
  默认打印分批清单；检查.sh 调用它，批数（不计只改文档、登记的批）超过 N（默认 10）时提示停派新车道。

覆盖规则（核查者只能销对方的提交：Codex 的核查条目只销 `核查: 待Codex` 的提交，反之亦然）：
  - 核查条目 = 标题形如 `## 日期 【Claude…】核查 …` 或 `【Codex…】核查 …` 的一段（含正文）。
  - 段里写到的提交号（7 位以上）销该提交；写到合并提交号、分支名或开发编号（dev.NNN、dev.A～B、dev.A／B）时销整批。
  - 分支名与开发编号只销核查当天及以前的批，避免早先的核查盖住同一分支后来的合并。
批的划分：main 第一父链上的每个 `合并 <分支>` 合并提交连同它带进来的分支提交、紧随其后的同分支「收尾／登记」提交算一批，其余提交各自一批。
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LOG = '00_项目管理/变更记录.md'
VOLUMES = '00_项目管理/变更记录卷'
TRAILER = re.compile(r'^核查[:：]\s*待(Codex|Claude)\s*$', re.M)
EXECUTOR = re.compile(r'^执行者[:：]\s*(.+?)\s*$', re.M)
REVIEW = re.compile(r'^## (\d{4}-\d{2}-\d{2}) 【(Claude|Codex)[^】]*】\s*核查', re.M)
ENTRY = re.compile(r'^## \d{4}-\d{2}-\d{2}\b', re.M)
HASH = re.compile(r'(?<![0-9A-Za-z])[0-9a-f]{7,40}(?![0-9A-Za-z])')  # 纯数字的提交号（如 7432182）也算
BRANCH = re.compile(r'(?:claude|codex)/[A-Za-z0-9_\-.]*[A-Za-z0-9_\-]')
DEV = re.compile(r'dev\.(\d{3})((?:\s*[～~至到\-]\s*(?:dev\.)?\d{3})?)((?:[／/]\s*(?:dev\.)?\d{3}|、\d{3})*)')
MERGE = re.compile(r'^(?:合并|并入)\s+((?:claude|codex)/[^\s（(]+)')
DOC_ONLY = re.compile(r'^(?:00_项目管理/|AGENTS\.md$|CLAUDE\.md$|README[^/]*\.md$)|\.md$')


def git(root, *args):
    return subprocess.run(['git', '-C', str(root), '-c', 'core.quotePath=false', *args],
                          capture_output=True, text=True, check=True).stdout


def dev_numbers(text):
    out = set()
    for m in DEV.finditer(text):
        a = int(m.group(1))
        out.add(a)
        if m.group(2):
            b = int(re.findall(r'\d{3}', m.group(2))[-1])
            if a <= b <= a + 50:
                out.update(range(a, b + 1))
        out.update(int(x) for x in re.findall(r'\d{3}', m.group(3)))
    return out


def reviews(root):
    """[(日期, 核查者, 正文)]，取自分卷与当前卷。"""
    texts = [p.read_text() for p in sorted((root / VOLUMES).glob('变更记录_*.md'))] if (root / VOLUMES).is_dir() else []
    if (root / LOG).is_file():
        texts.append((root / LOG).read_text())
    out = []
    for text in texts:
        starts = [m.start() for m in ENTRY.finditer(text)] + [len(text)]
        for s, e in zip(starts, starts[1:]):
            m = REVIEW.match(text, s)
            if m:
                out.append((m.group(1), m.group(2), text[s:e]))
    return out


def commits(root):
    """main 第一父链（旧→新），每个提交：号、日期、标题、尾注、改动文件、所属批。"""
    fmt = '%H%x1f%P%x1f%ad%x1f%s%x1f%B%x1e'
    raw = git(root, 'log', '--first-parent', '--reverse', '--date=short', '--format=' + fmt, 'HEAD')
    batches, by_branch, rows = [], {}, []
    for rec in raw.split('\x1e'):
        if not rec.strip():
            continue
        sha, parents, date, subject, body = rec.strip('\n').split('\x1f')
        parents = parents.split()
        m = MERGE.match(subject)
        branch = m.group(1) if m else None
        if len(parents) > 1:
            batch = {'label': subject, 'branch': branch, 'date': date, 'commits': [], 'merge': sha}
            batches.append(batch)
            if branch:
                by_branch[branch] = batch
            side = git(root, 'log', '--reverse', '--date=short', '--format=' + fmt, f'{parents[0]}..{parents[1]}')
            for srec in side.split('\x1e'):
                if srec.strip():
                    s_sha, s_par, s_date, s_subj, s_body = srec.strip('\n').split('\x1f')
                    batch['commits'].append(row(root, s_sha, s_date, s_subj, s_body, s_par.split()))
        elif branch in by_branch:
            batch = by_branch[branch]
        else:
            batch = {'label': subject, 'branch': None, 'date': date, 'commits': [], 'merge': None}
            batches.append(batch)
        batch['commits'].append(row(root, sha, date, subject, body, parents))
    return batches


def row(root, sha, date, subject, body, parents):
    found = TRAILER.findall(body)
    executor = EXECUTOR.findall(body)
    return {'sha': sha, 'parent': parents[0] if parents else None, 'date': date, 'subject': subject,
            'need': found[-1] if found else None, 'executor': executor[-1] if executor else '', 'dev': dev_numbers(subject)}


def changed_files(root, c):
    """只给还没核查的批算改动文件（每个提交一次 git diff），清单长了也快。"""
    if not c['parent']:
        return []
    return [f for f in git(root, 'diff', '--name-only', '--no-renames', c['parent'], c['sha']).split('\n') if f]


def pending(root):
    batches = commits(root)
    revs = reviews(root)
    for b in batches:
        b['dev'] = set().union(*(c['dev'] for c in b['commits']))
    for date, who, text in revs:
        hashes = HASH.findall(text)
        branches = set(BRANCH.findall(text))
        devs = dev_numbers(text)
        for b in batches:
            whole = b['merge'] and any(b['merge'].startswith(h) for h in hashes) or b['date'] <= date and (
                b['branch'] and b['branch'] in branches or b['dev'] & devs)
            for c in b['commits']:
                if c['need'] == who and (whole or any(c['sha'].startswith(h) for h in hashes)):
                    c['reviewed'] = True
    out = []
    for b in batches:
        left = [c for c in b['commits'] if c['need'] and not c.get('reviewed')]
        if not left:
            continue
        files = {f for c in b['commits'] for f in changed_files(root, c)}
        out.append({'label': b['label'], 'date': b['date'], 'need': sorted({c['need'] for c in left}),
                    'commits': [c['sha'][:7] for c in left],
                    'executor': '、'.join(dict.fromkeys(c['executor'] for c in left if c['executor'])),
                    'docOnly': bool(files) and all(DOC_ONLY.search(f) for f in files)})
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--root', type=Path, default=ROOT)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--limit', type=int, default=10)
    a = ap.parse_args(argv)
    items = pending(a.root)
    if a.json:
        print(json.dumps(items, ensure_ascii=False, indent=1))
        return 0
    counted = [i for i in items if not i['docOnly']]
    for need in ['Codex', 'Claude']:
        group = [i for i in counted if need in i['need']]
        docs = [i for i in items if i['docOnly'] and need in i['need']]
        if not group and not docs:
            continue
        print(f'  待{need}核查 {len(group)} 批' + (f'，另有只改文档、登记的 {len(docs)} 批（只看结论与编号）' if docs else '') + '：')
        for i in group:
            shown = ' '.join(i['commits']) if len(i['commits']) <= 4 else f"{len(i['commits'])} 个提交 {i['commits'][0]}…{i['commits'][-1]}"
            print(f"    {i['date']} {i['label'][:48]}｜{shown}｜{i['executor']}")
        if docs:
            print('    文档：' + ' '.join(c for i in docs for c in i['commits']))
    print(f'  待交叉核查共 {len(items)} 批，计入上限 {len(counted)} 批（只改文档、登记的不计；按提交尾注减去变更记录核查条目）')
    if len(counted) > a.limit:
        print(f'  ⚠ 待交叉核查 {len(counted)} 批，超过 {a.limit} 批上限：停派新车道、停新功能，先启动 Codex（沙僧）核查')
    return 0


if __name__ == '__main__':
    sys.exit(main())
