#!/usr/bin/env python3
"""推送重试.py 回归：5xx 重试后成功、认证失败／non-fast-forward 不重试、重试用完报原错、环境变量回退，以及两处接线。"""
import io
import os
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import 推送重试 as T  # noqa: E402


class Flaky:
    def __init__(self, errors):
        self.errors, self.calls = list(errors), 0

    def __call__(self):
        self.calls += 1
        if self.errors:
            raise RuntimeError(self.errors.pop(0))
        return 'ok'


class RetryTests(unittest.TestCase):
    def setUp(self):
        self.slept, self.out = [], io.StringIO()
        for k in ('XIYOU_PUSH_RETRY', 'XIYOU_PUSH_RETRY_DELAYS'):
            os.environ.pop(k, None)

    def go(self, run):
        return T.retry_push(run, label='推 x', sleep=self.slept.append, out=self.out)

    def test_two_5xx_then_success(self):
        f = Flaky(['remote rejected ... Internal Server Error', 'fatal error in commit_refs'])
        self.assertEqual(self.go(f), 'ok')
        self.assertEqual((f.calls, self.slept), (3, [10, 30]))
        self.assertEqual(self.out.getvalue().count('[推送重试]'), 2)

    def test_auth_failure_not_retried(self):
        f = Flaky(['fatal: Authentication failed for https://github.com/x'])
        with self.assertRaises(RuntimeError):
            self.go(f)
        self.assertEqual((f.calls, self.slept), (1, []))

    def test_non_fast_forward_not_retried(self):
        f = Flaky(['! [rejected] main -> main (non-fast-forward)'])
        with self.assertRaises(RuntimeError):
            self.go(f)
        self.assertEqual(f.calls, 1)

    def test_exhausted_raises_last_error(self):
        f = Flaky(['RPC failed; HTTP 500'] * 9)
        with self.assertRaisesRegex(RuntimeError, 'HTTP 500'):
            self.go(f)
        self.assertEqual((f.calls, self.slept), (4, [10, 30, 60]))

    def test_transient_patterns(self):
        for t in ('error: RPC failed; HTTP 408 curl 22', 'The requested URL returned error: 502', 'HTTP 503',
                  'remote: Internal Server Error', 'fatal error in commit_refs'):
            self.assertTrue(T.transient(t), t)
        for t in ('Authentication failed', 'non-fast-forward', 'Permission denied', 'refusing to update checked out branch', ''):
            self.assertFalse(T.transient(t), t)

    def test_env_off_and_custom_delays(self):
        os.environ['XIYOU_PUSH_RETRY'] = '0'
        f = Flaky(['Internal Server Error'])
        with self.assertRaises(RuntimeError):
            self.go(f)
        self.assertEqual(f.calls, 1)
        os.environ.pop('XIYOU_PUSH_RETRY')
        os.environ['XIYOU_PUSH_RETRY_DELAYS'] = '1,2'
        self.assertEqual(self.go(Flaky(['HTTP 500', 'HTTP 500'])), 'ok')
        self.assertEqual(self.slept, [1.0, 2.0])
        os.environ.pop('XIYOU_PUSH_RETRY_DELAYS')


class WiringTests(unittest.TestCase):
    def test_pushers_use_retry(self):
        cloud = (HERE / '云端选测.py').read_text(encoding='utf-8')
        self.assertNotIn("git('push'", cloud)
        self.assertIn('retry_push', cloud)
        merge = (HERE / '合并车道.py').read_text(encoding='utf-8')
        self.assertIn("retry_push(lambda: remote_git('push'", merge)


if __name__ == '__main__':
    unittest.main()
