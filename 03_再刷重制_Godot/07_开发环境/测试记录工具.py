#!/usr/bin/env python3
"""变更记录分卷与待核查清单回归；Git 操作仅在临时资料库中进行。"""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
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

    def test_audit_trailer_and_reviewer_line(self):
        # Kyo 10-30：Codex 不再核查，尾注 `核查: 待审查`；审查条目（标题带审查，或有「核查者: Claude（审查）」行）销一切待核查尾注，旧写法照计
        r = self.repo
        r.put('03_再刷重制_Godot/d.py', 'x')
        audit = r.commit('审查线程的新提交', '审查', 'Claude（哪吒）')
        r.put('03_再刷重制_Godot/e.py', 'x')
        r.commit('另一条新提交', '审查', 'Claude（哪吒）')
        items = self.labels()
        self.assertEqual(items['审查线程的新提交']['need'], ['审查'])
        self.assertIn('合并 claude/lane', items)        # 旧的 待Codex 照样计入
        r.put(LOG, f'# 变更记录\n\n## 2099-01-01 【Claude·审查】核查 {audit}：通过\n')
        items = self.labels()
        self.assertNotIn('审查线程的新提交', items)
        self.assertIn('另一条新提交', items)             # 只销范围里写到的
        # 标题不带审查，靠「核查者」行
        r.put(LOG, '# 变更记录\n\n## 2099-01-01 【Claude·哪吒】核查 claude/lane\n\n- 核查者: Claude（审查）\n')
        self.assertNotIn('合并 claude/lane', self.labels())   # 审查条目也销旧的 待Codex
        # 普通 Claude 核查条目不能销待审查之外的 待Codex
        r.put(LOG, '# 变更记录\n\n## 2099-01-01 【Claude·哪吒】核查 claude/lane\n')
        self.assertIn('合并 claude/lane', self.labels())

    def test_no_review_trailer_is_not_counted(self):
        # 审查线程自己的分支合并写 `核查: 无`，不进待核查清单
        r = self.repo
        r.put('03_再刷重制_Godot/f.py', 'x')
        r.git('add', '-A')
        r.git('commit', '-q', '-m', '审查线程自己的合并\n\n执行者: Claude（唐僧）\n核查: 无\n')
        self.assertNotIn('审查线程自己的合并', self.labels())

    def test_cc_names_are_recognized_like_claude(self):
        # Kyo 10-31 把 claude 改叫 cc：分支 cc/…、执行者 cc（…）、条目【cc·…】核查、核查者 cc（审查）都照旧销账
        r = self.repo
        r.put('03_再刷重制_Godot/h.py', 'x')
        r.commit('cc 的提交', '审查', 'cc（哪吒）')
        r.git('checkout', '-q', '-b', 'cc/lane2')
        r.put('03_再刷重制_Godot/i.py', 'x')
        r.commit('分支上的提交', '审查', 'cc（悟空）')
        r.git('checkout', '-q', 'main')
        r.git('merge', '-q', '--no-ff', '-m', '合并 cc/lane2', 'cc/lane2')
        items = self.labels()
        self.assertEqual(items['cc 的提交']['executor'], 'cc（哪吒）')
        self.assertIn('合并 cc/lane2', items)
        r.put(LOG, '# 变更记录\n\n## 2099-01-01 【cc·审查】核查 cc/lane2：通过\n')
        items = self.labels()
        self.assertNotIn('合并 cc/lane2', items)                    # 分支名 cc/… 能销整批
        self.assertIn('cc 的提交', items)
        r.put(LOG, '# 变更记录\n\n## 2099-01-01 【cc·哪吒】核查 claude/lane\n\n- 核查者: cc（审查）\n')
        self.assertNotIn('合并 claude/lane', self.labels())     # 核查者行写 cc（审查）也认，且仍销旧的 claude/ 分支

    def test_tiers_by_files_limit_counts_only_tier_a(self):
        """Kyo 10-30：待核查按甲／乙／丙三档，上限只算甲档。一批的档＝所改文件里最高的；规则表见 待核查分档.json；
        有文件却没有规则匹配的按甲并列出；没有改动文件的批算丙。"""
        r = self.repo
        P = '03_再刷重制_Godot/'
        cases = [('甲-战斗核心', {P + '01_Godot工程/modes/xiyou/core/actor.gd': 'x'}),
                 ('甲-存档', {P + '01_Godot工程/modes/xiyou/ui/save_page.gd': 'x'}),
                 ('甲-新优化', {P + '00_设计/优化登记.md': 'x'}),
                 ('乙-楼层内容', {P + '03_转换工具/xiyou_slice.json': '{}', P + '01_Godot工程/tests/xiyou_floor.gd': 'x'}),
                 ('丙-工具文档', {P + '07_开发环境/工具.py': 'x', '00_项目管理/交接板.md': 'x'}),
                 ('混合取最高', {P + '07_开发环境/工具2.py': 'x', P + '01_Godot工程/tests/t2.gd': 'x', P + '01_Godot工程/modes/xiyou/battle/b.gd.uid': 'x'}),
                 ('拿不准按甲', {P + '01_Godot工程/modes/xiyou/entry.gd': 'x'}),
                 ('乙-界面', {P + '01_Godot工程/modes/xiyou/ui/shop.gd': 'x'})]
        for name, files in cases:
            for path, text in files.items():
                r.put(path, text)
            r.commit(name, '审查', 'Claude（哪吒）')
        r.commit('空提交', '审查', 'Claude（哪吒）')
        items = self.labels()
        got = {n: items[n]['tier'] for n, _ in cases + [('空提交', 0)]}
        self.assertEqual(got, {'甲-战斗核心': '甲', '甲-存档': '甲', '甲-新优化': '甲', '乙-楼层内容': '乙', '丙-工具文档': '丙',
                               '混合取最高': '甲', '拿不准按甲': '甲', '乙-界面': '乙', '空提交': '丙'})
        self.assertEqual(items['拿不准按甲']['unsure'], [P + '01_Godot工程/modes/xiyou/entry.gd'])
        self.assertEqual(items['拿不准按甲']['sureTier'], '丙')
        self.assertEqual(items['甲-战斗核心']['unsure'], [])
        n = {t: sum(1 for i in items.values() if i['tier'] == t) for t in '甲乙丙'}
        out = subprocess.run([sys.executable, str(HERE / '待核查.py'), '--root', str(r.root), '--limit', str(n['甲'] - 1)], capture_output=True, text=True).stdout
        guess = sum(1 for i in items.values() if i['tier'] == '甲' and i['sureTier'] != '甲')   # 夹具里原有的批也可能有拿不准的文件
        self.assertEqual(items['拿不准按甲']['sureTier'] != '甲', True)
        self.assertIn(f"甲 {n['甲']} 批（其中 {guess} 批只因有文件拿不准才算甲）、乙 {n['乙']} 批、丙 {n['丙']} 批", out)
        self.assertIn(f"计入 {n['甲']} 批", out)
        self.assertIn('拿不准归哪档', out)
        self.assertIn(f"⚠ 待交叉核查甲档 {n['甲']} 批，超过 {n['甲'] - 1} 批上限", out)
        out = subprocess.run([sys.executable, str(HERE / '待核查.py'), '--root', str(r.root), '--limit', str(n['甲'])], capture_output=True, text=True).stdout
        self.assertNotIn('超过', out)                                            # 乙、丙再多也不触发

    def test_dev_numbers(self):
        self.assertEqual(review.dev_numbers('dev.081／083／085、dev.086～088'), {81, 83, 85, 86, 87, 88})


if __name__ == '__main__':
    unittest.main()
