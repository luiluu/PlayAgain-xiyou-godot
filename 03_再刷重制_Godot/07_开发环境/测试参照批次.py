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
        write(self.main / 'sync_stamp.json', {'outputsDigest': 'main-out'})
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'old-out'})  # 首次补齐克隆来的旧戳；再补齐不刷新它

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
        self.assertEqual((batch['sliceConfigSHA256'], batch['laneOutputsDigest']), ('new-slice', 'old-out'))
        r = self.run_tool('check', self.lane)
        self.assertEqual(r.returncode, 3)
        self.assertIn('不同批', r.stdout)
        self.assertIn('git merge main', r.stdout)

    def test_self_synced_lane_is_silent(self):
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'lane-slice'})
        self.run_tool('record', self.lane, self.main)
        write(self.lane / 'sync_stamp.json', {'outputsDigest': 'lane-out'})  # 本树跑过 同步正式西游.py
        self.assertEqual(self.run_tool('check', self.lane).returncode, 0)

    def test_stale_lane_stamp_still_warns(self):
        # 真实情形：本树的戳是早先补齐带来的旧戳，与主工作区现在的不同，但本树并没有自己同步过
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'old-slice'})
        self.run_tool('record', self.lane, self.main)
        self.assertEqual(self.run_tool('check', self.lane).returncode, 3)

    def test_no_record_is_silent(self):
        write(self.lane / 'manifest.json', {'sliceConfigSHA256': 'anything'})
        r = self.run_tool('check', self.lane)
        self.assertEqual((r.returncode, r.stdout), (0, ''))

    def test_main_without_fingerprint_records_nothing(self):
        write(self.main / 'manifest.json', {})
        r = self.run_tool('record', self.lane, self.main)
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.lane / 'oracle_batch.json').exists())

    def test_bad_usage(self):
        self.assertEqual(self.run_tool('check').returncode, 64)


class WiringTests(unittest.TestCase):
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

    def test_check_script_warns_without_failing(self):
        text = (HERE / '检查.sh').read_text(encoding='utf-8')
        self.assertIn('参照批次.py" check "$PROJECT/modes/xiyou/generated" || true', text)


if __name__ == '__main__':
    unittest.main(verbosity=1)
