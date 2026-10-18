#!/usr/bin/env python3
"""在临时项目与模拟 Godot 中验证导入失败传播；不联网、不装依赖。"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


class CloudImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='xiyou_cloud_import_')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env_dir = self.root / '07_开发环境'
        self.env_dir.mkdir()
        self.script = self.env_dir / '云端准备.sh'
        shutil.copy2(HERE / self.script.name, self.script)
        (self.env_dir / '环境登记.json').write_text(json.dumps({'version': 'fixture'}))
        self.project = self.root / '01_Godot工程'
        generated = self.project / 'modes/xiyou/generated'
        generated.mkdir(parents=True)
        (generated / 'manifest.json').write_text('{}')
        self.cache = self.project / '.godot'
        (self.cache / 'imported').mkdir(parents=True)  # 已有半成品也不能跳过导入
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name, text in {'zsh': 'exit 0', 'nproc': 'echo 2',
                           'timeout': 'shift\nexec "$@"'}.items():
            self.executable(self.bin / name, text)
        godot = self.root / '.cache/xiyou-godot/fixture/Godot_vfixture-stable_linux.x86_64'
        godot.parent.mkdir(parents=True)
        self.executable(godot, '''
if [ "$2" = "--version" ]; then exit 0; fi
echo import >> "$FIXTURE_CALLS"
if [ "$FIXTURE_MODE" = "script_error" ]; then
  echo 'SCRIPT ERROR: fixture parse error'
  exit 0
fi
if [ "$FIXTURE_MODE" = "engine_error" ]; then
  echo 'ERROR: fixture import error'
  exit 0
fi
if [ "$FIXTURE_MODE" = "timeout" ]; then exit 124; fi
echo 'fixture import complete'
exit 0
''')

    @staticmethod
    def executable(path, text):
        path.write_text('#!/bin/sh\n' + text + '\n')
        path.chmod(0o755)

    def run_script(self, mode):
        env = dict(os.environ, HOME=str(self.root), PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                   FIXTURE_MODE=mode, FIXTURE_CALLS=str(self.root / 'calls'))
        return subprocess.run(['bash', str(self.script)], env=env, capture_output=True, text=True,
                              errors='backslashreplace')

    def test_timeout_is_failure_and_next_run_retries(self):
        failed = self.run_script('timeout')
        self.assertEqual(failed.returncode, 124, failed)
        self.assertNotIn('export GODOT=', failed.stdout)
        self.assertTrue((self.cache / 'cloud-import.log').is_file())
        success = self.run_script('ok')
        self.assertEqual(success.returncode, 0, success)
        self.assertIn('export GODOT=', success.stdout)
        self.assertEqual((self.root / 'calls').read_text().splitlines(), ['import', 'import'])

    def test_script_error_with_zero_exit_is_failure(self):
        failed = self.run_script('script_error')
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn('SCRIPT ERROR', failed.stderr)
        self.assertNotIn('export GODOT=', failed.stdout)

    def test_engine_error_with_zero_exit_is_failure(self):
        failed = self.run_script('engine_error')
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn('ERROR:', failed.stderr)
        self.assertNotIn('export GODOT=', failed.stdout)


if __name__ == '__main__':
    unittest.main()
