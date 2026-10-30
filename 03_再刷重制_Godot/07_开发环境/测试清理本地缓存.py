#!/usr/bin/env python3
"""清理本地缓存.py 回归：只认本地结果下含 project.godot 且够大的目录，默认只列不删，--delete 只删副本本身。"""
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('cache_tool', HERE / '清理本地缓存.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        res = self.root / tool.RESULTS
        self.big = res / 'run1/project-copy'
        self.small = res / 'run2/sample'
        for d, n in [(self.big, 2 * 1024 * 1024), (self.small, 10)]:
            d.mkdir(parents=True)
            (d / 'project.godot').write_text('x')
            (d / 'blob.bin').write_bytes(b'0' * n)
        (res / 'run1/check.log').write_text('log')
        (res / 'run3').mkdir()
        (res / 'run3/result.json').write_text('{}')

    def tearDown(self):
        self.tmp.cleanup()

    def test_lists_only_big_copies_and_keeps_logs(self):
        self.assertEqual(tool.main(['--root', str(self.root), '--min-mb', '1']), 0)
        self.assertTrue(self.big.exists())          # 默认不删
        self.assertEqual(tool.main(['--root', str(self.root), '--min-mb', '1', '--delete']), 0)
        self.assertFalse(self.big.exists())
        self.assertTrue(self.small.exists())        # 小样本不算
        self.assertTrue((self.big.parent / 'check.log').exists())
        self.assertTrue((self.root / tool.RESULTS / 'run3/result.json').exists())

    def test_older_than_filter(self):
        tool.main(['--root', str(self.root), '--min-mb', '1', '--delete', '--older-than-hours', '1'])
        self.assertTrue(self.big.exists())          # 刚建的不删


if __name__ == '__main__':
    r = unittest.main(exit=False)
    print('TEST_RESULT=' + '{"passed": %d, "total": %d}' % (r.result.testsRun - len(r.result.failures) - len(r.result.errors), r.result.testsRun))
    raise SystemExit(0 if r.result.wasSuccessful() else 1)
