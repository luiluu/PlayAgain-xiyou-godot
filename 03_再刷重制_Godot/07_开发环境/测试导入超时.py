#!/usr/bin/env python3
"""导入超时.py 与 新建工作树.sh --补齐 的整轮重导入分支（cc 平台 DZ 2026-11-06）。离线，几秒。"""
import importlib.util
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('导入超时', HERE / '导入超时.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


def project(root: Path, n: int, have: int, extra_path_keys=False):
    (root / 'img').mkdir(parents=True)
    imported = root / '.godot' / 'imported'
    imported.mkdir(parents=True)
    for i in range(n):
        key = 'path.s3tc' if extra_path_keys and i % 2 else 'path'
        (root / 'img' / f'a{i}.png.import').write_text(
            f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n{key}="res://.godot/imported/a{i}.png-x.ctex"\n', encoding='utf-8')
        if i < have:
            (imported / f'a{i}.png-x.ctex').write_bytes(b'x')
    # 不是贴图的 .import、.godot 里的 .import 不算
    (root / 'img' / 'b.ogg.import').write_text('path="res://.godot/imported/b.ogg-x.oggvorbisstr"\n', encoding='utf-8')
    (imported / 'stale.png.import').write_text('path="res://.godot/imported/zz.ctex"\n', encoding='utf-8')


class ClassifyTests(unittest.TestCase):
    def test_complete_cache_is_normal(self):
        with tempfile.TemporaryDirectory() as d:
            project(Path(d), 10, 10)
            self.assertEqual(M.classify(Path(d)), ('normal', 0, 10))

    def test_few_missing_is_normal(self):
        with tempfile.TemporaryDirectory() as d:
            project(Path(d), 10, 8)
            self.assertEqual(M.classify(Path(d)), ('normal', 2, 10))

    def test_ctex_deleted_is_full(self):
        with tempfile.TemporaryDirectory() as d:
            project(Path(d), 10, 2, extra_path_keys=True)
            self.assertEqual(M.classify(Path(d)), ('full', 8, 10))

    def test_no_imported_dir_is_full(self):
        with tempfile.TemporaryDirectory() as d:
            project(Path(d), 4, 4)
            for f in (Path(d) / '.godot' / 'imported').iterdir():
                f.unlink()
            self.assertEqual(M.classify(Path(d))[0], 'full')

    def test_gdignore_dir_not_counted(self):
        # 安卓构建模板 android/build 带 .gdignore，里面自带的 icon.svg.import 不归 Godot 导入（平台 release450 发现出包被它挡住）
        with tempfile.TemporaryDirectory() as d:
            project(Path(d), 4, 4)
            tpl = Path(d) / 'android' / 'build' / 'src' / 'assets'
            tpl.mkdir(parents=True)
            (Path(d) / 'android' / 'build' / '.gdignore').write_text('', encoding='utf-8')
            (tpl / 'icon.svg.import').write_text('path="res://.godot/imported/icon.svg-x.ctex"\n', encoding='utf-8')
            self.assertEqual(M.classify(Path(d)), ('normal', 0, 4))

    def test_cli_prints_one_line(self):
        import subprocess, sys
        with tempfile.TemporaryDirectory() as d:
            project(Path(d), 3, 0)
            out = subprocess.run([sys.executable, str(HERE / '导入超时.py'), d], capture_output=True, text=True)
            self.assertEqual((out.returncode, out.stdout.strip()), (0, 'full 3 3'))


class ScriptWiringTests(unittest.TestCase):
    """新建工作树.sh 的导入一步：整轮走长任务、不带 300 秒上限；普通补齐照旧 alarm 300。"""
    def test_import_step(self):
        text = (HERE / '新建工作树.sh').read_text(encoding='utf-8')
        step = text[text.index('print "== godot --import"'):text.index('补跑事件状态探针.py')]
        full, normal = step.split('  else\n', 1)
        self.assertIn('导入超时.py', full)
        self.assertIn('长任务.py" start', full)
        self.assertIn('长任务.py" wait', full)
        self.assertNotIn('alarm', full)
        self.assertIn("alarm 300", normal)


if __name__ == '__main__':
    unittest.main()
