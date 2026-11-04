#!/usr/bin/env python3
"""参照批次.py：补齐记批次、检查同批／不同批／本树已自行同步；以及 新建工作树.sh、检查.sh 的接线位置。只用临时目录。"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
TOOL = HERE / '参照批次.py'


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding='utf-8')


class BatchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='xiyou_oracle_batch_')
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.main, self.lane = root / 'main_gen', root / 'lane_gen'
        write(self.main / 'manifest.json', {'sliceConfigSHA256': 'new-slice'})
        write(self.main / 'sync_stamp.json', {'outputsDigest': 'a' * 64})
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'b' * 64})  # 首次补齐克隆来的旧戳；再补齐不刷新它

    def run_tool(self, *args):
        return subprocess.run([sys.executable, str(TOOL), *map(str, args)], capture_output=True, text=True)

    def test_same_batch_is_silent(self):
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'new-slice'})
        self.assertEqual(self.run_tool('record', self.lane, self.main).returncode, 0)
        r = self.run_tool('check', self.lane)
        self.assertEqual((r.returncode, r.stdout), (0, ''))

    def test_older_branch_slice_warns(self):
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'old-slice'})
        self.run_tool('record', self.lane, self.main)
        batch = json.loads((self.lane / 'oracle_batch.json').read_text(encoding='utf-8'))
        self.assertEqual((batch['sliceConfigSHA256'], batch['laneOutputsDigest']), ('new-slice', 'b' * 64))
        r = self.run_tool('check', self.lane)
        self.assertEqual(r.returncode, 3)
        self.assertIn('不同批', r.stdout)
        self.assertIn('git merge main', r.stdout)

    def test_self_synced_lane_is_silent(self):
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'lane-slice'})
        self.run_tool('record', self.lane, self.main)
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'c' * 64})  # 本树跑过 同步正式西游.py
        self.assertEqual(self.run_tool('check', self.lane).returncode, 0)

    def test_stale_lane_stamp_still_warns(self):
        # 真实情形：本树的戳是早先补齐带来的旧戳，与主工作区现在的不同，但本树并没有自己同步过
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'old-slice'})
        self.run_tool('record', self.lane, self.main)
        self.assertEqual(self.run_tool('check', self.lane).returncode, 3)

    def test_missing_or_broken_stamp_is_not_a_sync_proof(self):
        # 沙僧第十五期 P2：记批次后车道戳文件丢了／损坏／缺字段，不能当「自己同步过」而静默
        for how in ['missing', 'garbage', 'no_field', 'not_hex']:
            with self.subTest(how=how):
                write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'old-slice'})
                write(self.lane / 'sync_stamp.json', {'outputsDigest': 'b' * 64})
                self.run_tool('record', self.lane, self.main)
                stamp = self.lane / 'sync_stamp.json'
                if how == 'missing':
                    stamp.unlink()
                elif how == 'garbage':
                    stamp.write_text('{not json')
                elif how == 'no_field':
                    write(stamp, {'other': 1})
                else:
                    write(stamp, {'outputsDigest': 'changed'})
                r = self.run_tool('check', self.lane)
                self.assertEqual(r.returncode, 3, (how, r.stdout))
                self.assertIn('同步戳丢失或损坏', r.stdout)
        # 切片指纹相同时只提示、不失败
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'new-slice'})
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'b' * 64})
        self.run_tool('record', self.lane, self.main)
        (self.lane / 'sync_stamp.json').unlink()
        r = self.run_tool('check', self.lane)
        self.assertEqual(r.returncode, 0)
        self.assertIn('同步戳丢失或损坏', r.stdout)

    def test_lane_never_stamped_is_silent_when_same_batch(self):
        (self.lane / 'sync_stamp.json').unlink()
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'new-slice'})
        self.run_tool('record', self.lane, self.main)
        r = self.run_tool('check', self.lane)
        self.assertEqual((r.returncode, r.stdout), (0, ''))

    def test_partial_refresh_is_flagged_as_mixed(self):
        # 沙僧第十五期 P2：车道的事件参照较新（B）没被复制，主工作区另一份被复制：切片指纹相同也要提示混批
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'new-slice'})
        write(self.main / 'oracle/events.json', {'v': 'A'})
        write(self.main / 'oracle/other.json', {'v': 'new'})
        write(self.lane / 'oracle/events.json', {'v': 'B'})       # 留着本分支较新的版本，没被复制
        write(self.lane / 'oracle/other.json', {'v': 'new'})       # 这份复制过来了
        self.run_tool('record', self.lane, self.main)
        r = self.run_tool('check', self.lane)
        self.assertEqual(r.returncode, 3, r.stdout)
        self.assertIn('events.json', r.stdout)
        self.assertNotIn('other.json', r.stdout)
        # 本树自己同步（有效新戳）后不再提示
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'c' * 64})
        self.assertEqual(self.run_tool('check', self.lane).returncode, 0)

    def test_no_record_is_silent(self):
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'anything'})
        r = self.run_tool('check', self.lane)
        self.assertEqual((r.returncode, r.stdout), (0, ''))

    def test_main_without_fingerprint_records_nothing(self):
        write(self.main / 'manifest.json', {})
        r = self.run_tool('record', self.lane, self.main)
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.lane / 'oracle_batch.json').exists())

    def test_compare_flags_stale_outputs_with_same_slice(self):
        # 并行测试开跑前比对：同一份切片、产物清单却不同＝工作树 generated/ 落后主工作区（yunshang_shop 挂在 HD 图标，哪吒_41）
        write(self.main / 'manifest.json', {'sliceConfigSHA256': 's', 'outputs': {'img/a.png': 'new', 'db/x.json': 'x'}})
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 's', 'outputs': {'img/a.png': 'old', 'db/x.json': 'x'}})
        r = self.run_tool('compare', self.lane, self.main)
        self.assertEqual(r.returncode, 3, r.stdout)
        self.assertIn('img/a.png', r.stdout)
        self.assertIn('--补齐', r.stdout)
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 's', 'outputs': {'img/a.png': 'new', 'db/x.json': 'x'}})
        r = self.run_tool('compare', self.lane, self.main)
        self.assertEqual((r.returncode, r.stdout), (0, ''))

    def test_compare_ignores_lane_with_its_own_slice(self):
        write(self.main / 'manifest.json', {'sliceConfigSHA256': 's', 'outputs': {'a': '1'}})
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'lane-slice', 'outputs': {'a': '2', 'b': '3'}})
        self.assertEqual(self.run_tool('compare', self.lane, self.main).returncode, 0)

    def test_compare_flags_older_oracle_unless_lane_synced(self):
        write(self.main / 'manifest.json', {'sliceConfigSHA256': 's', 'outputs': {}})
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 's', 'outputs': {}})
        write(self.main / 'oracle/p.json', {'v': 2})
        write(self.lane / 'oracle/p.json', {'v': 1})
        self.run_tool('record', self.lane, self.main)
        r = self.run_tool('compare', self.lane, self.main)
        self.assertEqual(r.returncode, 3, r.stdout)
        self.assertIn('p.json', r.stdout)
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'c' * 64})  # 本树自己同步过，参照以本树为准
        self.assertEqual(self.run_tool('compare', self.lane, self.main).returncode, 0)

    def test_compare_missing_manifest_is_silent(self):
        self.assertEqual(self.run_tool('compare', self.lane, self.main / 'nope').returncode, 0)

    def flux_dir(self, phase):
        git_dir = Path(self.temp.name) / 'gitdir'
        if phase:
            write(git_dir / 'lane-merge' / 'state.json', {'branch': 'cc/x', 'phase': phase})
        return git_dir

    def test_flux_blocks_only_while_merge_in_progress(self):
        """tools59：总装合并在 merged～prepared 阶段，主工作区 generated/ 没定稿，退出 4；其它阶段、没有状态文件都放行。"""
        for phase in ('merged', 'synced', 'numbering', 'versioned', 'prepared'):
            r = self.run_tool('flux', self.flux_dir(phase))
            self.assertEqual(r.returncode, 4, phase)
            self.assertIn('cc/x', r.stdout)
        for phase in ('planned', 'committed', None):
            self.assertEqual(self.run_tool('flux', self.flux_dir(phase)).returncode, 0, phase)

    def test_flux_rollback_env(self):
        import os
        env = dict(os.environ, XIYOU_IGNORE_MERGE_FLUX='1')
        r = subprocess.run([sys.executable, str(TOOL), 'flux', str(self.flux_dir('synced'))], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0)

    def test_bad_usage(self):
        self.assertEqual(self.run_tool('check').returncode, 64)


class WiringTests(unittest.TestCase):
    def test_parallel_tests_compare_generated_in_linked_worktree(self):
        text = (HERE / '并行测试.py').read_text(encoding='utf-8')
        self.assertIn("'compare'", text)
        self.assertIn('XIYOU_SKIP_GENERATED_CHECK', text)
        self.assertIn('--skip-generated-check', text)

    def test_new_worktree_records_after_copy_and_checks_after_export(self):
        text = (HERE / '新建工作树.sh').read_text(encoding='utf-8')
        copy = text.index('refresh_oracle "$mgen/oracle" "$gen/oracle"')
        record = text.index('参照批次.py" record "$gen" "$mgen"')
        export = text.index('xiyou_export.py" --out "$gen"')
        check = text.index('参照批次.py" check "$gen" || true')
        self.assertLess(copy, record)
        self.assertLess(record, export)
        self.assertLess(export, check)  # 先按本分支切片重生成 manifest 再比对
        self.assertIn('ORACLE_COPIED=$n', text)  # 一个文件都没复制时不改写已有批次

    def test_flux_wired_into_refresh_and_parallel_tests(self):
        text = (HERE / '新建工作树.sh').read_text(encoding='utf-8')
        self.assertLess(text.index('参照批次.py" flux'), text.index('refresh_oracle "$mgen/oracle" "$gen/oracle"'))
        self.assertIn('flux_rc == 4', text)
        self.assertIn("'flux'", (HERE / '并行测试.py').read_text(encoding='utf-8'))

    def test_check_script_warns_without_failing(self):
        text = (HERE / '检查.sh').read_text(encoding='utf-8')
        self.assertIn('参照批次.py" check "$PROJECT/modes/xiyou/generated" || true', text)


if __name__ == '__main__':
    unittest.main(verbosity=1)
