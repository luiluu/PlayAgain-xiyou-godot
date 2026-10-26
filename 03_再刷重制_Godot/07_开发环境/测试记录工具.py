#!/usr/bin/env python3
"""变更记录分卷与待核查清单回归；Git 操作仅在临时资料库中进行。"""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


volumes = load('log_volumes', HERE / '变更记录分卷.py')
review = load('review_list', HERE / '待核查.py')
LOG = '00_项目管理/变更记录.md'


class Repo:
    def __init__(self, root):
        self.root = root
        self.git('init', '-q', '-b', 'main')
        self.git('config', 'user.email', 't@example.com')
        self.git('config', 'user.name', 't')

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.root), *args], capture_output=True, text=True, check=True).stdout

    def put(self, rel, text):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)

    def commit(self, subject, need=None, executor='Claude（悟空）'):
        self.git('add', '-A')
        body = subject + ('\n\n执行者: %s\n核查: 待%s\n' % (executor, need) if need else '')
        self.git('commit', '-q', '--allow-empty', '-m', body)
        return self.git('rev-parse', '--short=7', 'HEAD').strip()


def entry(date, title, extra=''):
    return f'## {date} 【Claude·未经Codex检验】{title}\n\n- 见[报告](./核查报告_x.md)、[约定](../03_再刷重制_Godot/约定.md#目标){extra}\n'


class VolumeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Repo(Path(self.tmp.name))
        self.text = '# 变更记录\n\n' + '\n'.join(entry(d, t) for d, t in
                                               [('2026-10-12', '甲'), ('2026-10-13', '乙'), ('2026-10-14', '丙'), ('2026-10-14', '丁')])
        self.repo.put(LOG, self.text)
        self.repo.commit('init')

    def tearDown(self):
        self.tmp.cleanup()

    def quiet(self, fn, *args, **kw):
        with contextlib.redirect_stdout(io.StringIO()):
            return fn(*args, **kw)

    def test_split_moves_prefix_and_keeps_links(self):
        name = self.quiet(volumes.split, self.repo.root, '2026-10-14')
        self.assertEqual(name, '变更记录_2026-10-12至2026-10-13.md')
        vol = (self.repo.root / volumes.VOLUMES / name).read_text()
        self.assertIn('](../核查报告_x.md)', vol)
        self.assertIn('](../../03_再刷重制_Godot/约定.md#目标)', vol)
        current = (self.repo.root / LOG).read_text()
        self.assertNotIn('甲', current)
        self.assertIn('丙', current)
        self.assertIn('](变更记录卷/' + name + ')', current)
        self.assertEqual(volumes.check(self.repo.root), [])
        self.repo.commit('split')
        # 第二次分卷：新分卷与索引并存，历史仍连续
        second = self.quiet(volumes.split, self.repo.root, '2026-10-15')
        self.assertTrue(second.startswith('变更记录_2026-10-14'))
        self.assertEqual(volumes.check(self.repo.root), [])
        self.assertEqual((self.repo.root / LOG).read_text().count('变更记录卷/'), 2)

    def test_append_and_last_entry_continuation_pass(self):
        (self.repo.root / LOG).write_text(self.text.rstrip('\n') + '\n- 续写一行\n\n' + entry('2026-10-15', '戊'))
        self.assertEqual(volumes.check(self.repo.root), [])

    def test_rewrite_or_drop_fails(self):
        (self.repo.root / LOG).write_text(self.text.replace('乙', '改'))
        self.assertTrue(volumes.check(self.repo.root))
        (self.repo.root / LOG).write_text(self.text)
        self.quiet(volumes.split, self.repo.root, '2026-10-14')
        self.repo.commit('split')
        vol = next((self.repo.root / volumes.VOLUMES).glob('*.md'))
        vol.write_text(vol.read_text().replace('甲', '改'))
        self.assertTrue(volumes.check(self.repo.root))
        vol.unlink()
        self.assertTrue(volumes.check(self.repo.root))

    def test_split_everything_leaves_no_blank_line_at_eof(self):
        # 唐僧_13 2026-10-26：当前卷整卷移空时末尾多一空行，git diff --check 报错
        name = self.quiet(volumes.split, self.repo.root, '2026-10-20')
        for path in [self.repo.root / LOG, self.repo.root / volumes.VOLUMES / name]:
            text = path.read_text()
            self.assertTrue(text.endswith('\n') and not text.endswith('\n\n'), (path.name, text[-40:]))
        self.repo.git('add', '-A')
        self.assertEqual(subprocess.run(['git', '-C', str(self.repo.root), 'diff', '--cached', '--check'],
                                        capture_output=True, text=True).stdout, '')
        self.assertEqual(volumes.check(self.repo.root), [])

    def test_nothing_to_split(self):
        self.assertIsNone(self.quiet(volumes.split, self.repo.root, '2026-10-01'))


class ReviewListTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        r = self.repo = Repo(Path(self.tmp.name))
        r.put(LOG, '# 变更记录\n')
        r.put('03_再刷重制_Godot/a.gd', '1')
        r.commit('init')
        r.git('checkout', '-q', '-b', 'claude/lane')
        r.put('03_再刷重制_Godot/a.gd', '2')
        self.lane = r.commit('车道功能', 'Codex')
        r.git('checkout', '-q', 'main')
        r.git('merge', '-q', '--no-ff', 'claude/lane', '-m', '合并 claude/lane\n\n执行者: Claude（唐僧）\n核查: 待Codex\n')
        self.merge = r.git('rev-parse', '--short=7', 'HEAD').strip()
        self.tail = r.commit('合并 claude/lane（dev.005）收尾', 'Codex', 'Claude（唐僧）')
        r.put('03_再刷重制_Godot/b.py', 'x')
        self.tool = r.commit('工具改动', 'Codex', 'Claude（唐僧）')
        r.put('00_项目管理/交接板.md', 'x')
        self.doc = r.commit('交接板改动', 'Codex', 'Claude（唐僧）')
        r.put('03_再刷重制_Godot/c.py', 'x')
        self.codex = r.commit('沙僧修复', 'Claude', 'Codex（沙僧）')

    def tearDown(self):
        self.tmp.cleanup()

    def labels(self):
        return {i['label']: i for i in review.pending(self.repo.root)}

    def test_unreviewed_batches_and_doc_flag(self):
        items = self.labels()
        self.assertEqual(sorted(items['合并 claude/lane']['commits']), sorted([self.lane, self.merge, self.tail]))
        self.assertFalse(items['合并 claude/lane']['docOnly'])
        self.assertTrue(items['交接板改动']['docOnly'])
        self.assertEqual(items['沙僧修复']['need'], ['Claude'])
        self.assertNotIn('init', items)

    def test_review_by_branch_dev_and_hash(self):
        self.repo.put(LOG, '# 变更记录\n\n## 2099-01-01 【Codex·沙僧】核查 claude/lane\n\n- 通过\n\n'
                           f'## 2099-01-01 【Codex·沙僧】核查 {self.tool}：通过；{self.codex} 交 Claude\n')
        items = self.labels()
        self.assertNotIn('合并 claude/lane', items)
        self.assertNotIn('工具改动', items)
        self.assertIn('沙僧修复', items, 'Codex 的核查条目不能销 Codex 自己的提交')
        self.repo.put(LOG, '# 变更记录\n\n## 2099-01-01 【Codex·沙僧】核查 dev.003～006\n')
        self.assertNotIn('合并 claude/lane', self.labels())

    def test_only_scope_lines_count(self):
        # 沙僧复现：别的核查条目验证行写「开发编号（dev.005）通过」，不能销 dev.005 整批；证据、结论行里的提交号也不算
        self.repo.put(LOG, '# 变更记录\n\n## 2099-01-01 【Codex·沙僧】核查 c6d964a：提案需改\n\n- 结论：需改\n'
                           f'- 验证：文档段退出码 0，JSON／链接／开发编号（dev.005）通过\n- 证据：claude/lane 的 {self.tool} 只读复现\n')
        items = self.labels()
        self.assertIn('合并 claude/lane', items)
        self.assertIn('工具改动', items)
        # 范围行（核查覆盖、核查 <完整合并号>）照销
        full = self.repo.git('rev-parse', self.merge).strip()
        self.repo.put(LOG, '# 变更记录\n\n## 2099-01-01 【Codex·沙僧】核查晚间批\n\n'
                           f'- 核查 `{full}`（收尾 {self.tail}）：通过\n- 核查覆盖：{self.tool}\n- 验证：dev.009 通过\n')
        items = self.labels()
        self.assertNotIn('合并 claude/lane', items)
        self.assertNotIn('工具改动', items)
        self.assertEqual(review.scope_text('## t\n- 核查结果：dev.001\n- **核查覆盖**：x\n- 范围：y'), '## t\n- **核查覆盖**：x\n- 范围：y')

    def test_fix_heading_and_old_review_do_not_count(self):
        self.repo.put(LOG, '# 变更记录\n\n## 2099-01-01 【Codex·沙僧·未经Claude检验】修复 claude/lane 核查问题\n\n'
                           '## 2000-01-01 【Codex·沙僧】核查 claude/lane\n')
        self.assertIn('合并 claude/lane', self.labels())

    def test_dev_numbers(self):
        self.assertEqual(review.dev_numbers('dev.081／083／085、dev.086～088'), {81, 83, 85, 86, 87, 88})


if __name__ == '__main__':
    unittest.main()
