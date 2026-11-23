#!/usr/bin/env python3
"""方舟出图.py 的假服务器单测：覆盖文生图、图生图（多图）、图生视频（成功/失败/超时/URL 过期）、钥匙串安全与抠绿复用。"""
import base64
import contextlib
import http.server
import importlib.util
import io
import json
import os
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
SCRIPT = HERE / '方舟出图.py'


def load_ark_module():
    spec = importlib.util.spec_from_file_location('ark_media_cli', SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ark = load_ark_module()

# 1x1 最小合法 PNG 和最小 JPEG 头字节（用于无 Pillow 时的纯标准库单测）
TINY_PNG = base64.b64decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC'
)
TINY_JPG = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xd9'
FAKE_MP4 = b'\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isomFAKEVIDEO'
TEST_KEY = 'ark-secret-test-key-9876543210'


class FakeArkState:
    def __init__(self):
        self.requests = []
        self.download_headers = []
        self.image_bytes = TINY_PNG
        self.video_bytes = FAKE_MP4
        self.image_mode = 'url'          # url | b64 | expired_url | leak_error
        self.video_plan = ['queued', 'running', 'succeeded']
        self.video_dl_status = 200
        self.task_counter = 0
        self.task_polls = {}
        self.fail_error = {'code': 'ModelError', 'message': f'敏感报错回显 Bearer {TEST_KEY}'}


def start_fake_server(state):
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            return

        def _send_json(self, code, obj):
            data = json.dumps(obj, ensure_ascii=False).encode('utf-8')
            self.send_response(code)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _send_bytes(self, code, data, ctype='application/octet-stream'):
            self.send_response(code)
            self.send_header('Content-Type', ctype)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            length = int(self.headers.get('Content-Length', '0'))
            raw = self.rfile.read(length)
            body = json.loads(raw.decode('utf-8')) if raw else {}
            state.requests.append({
                'method': 'POST',
                'path': self.path,
                'auth': self.headers.get('Authorization'),
                'body': body,
            })

            host = f'http://127.0.0.1:{self.server.server_address[1]}'
            if self.path == '/api/v3/images/generations':
                if state.image_mode == 'leak_error':
                    self._send_json(401, {
                        'error': {
                            'code': 'InvalidAPIKey',
                            'message': f'bad token {TEST_KEY} from header Bearer {TEST_KEY}',
                        }
                    })
                    return
                if state.image_mode == 'b64':
                    self._send_json(200, {
                        'model': body.get('model'),
                        'data': [{'b64_json': base64.b64encode(state.image_bytes).decode('ascii'), 'size': body.get('size')}],
                        'usage': {'generated_images': 1, 'output_tokens': 1234},
                    })
                    return
                dl_path = '/files/expired.png' if state.image_mode == 'expired_url' else '/files/out.png'
                self._send_json(200, {
                    'model': body.get('model'),
                    'data': [{'url': f'{host}{dl_path}?X-Tos-Signature=sig123', 'size': body.get('size')}],
                    'usage': {'generated_images': 1, 'total_tokens': 2000},
                })
                return

            if self.path == '/api/v3/contents/generations/tasks':
                state.task_counter += 1
                tid = f'cgt-fake-{state.task_counter}'
                state.task_polls[tid] = 0
                self._send_json(200, {'id': tid, 'status': 'queued'})
                return

            self._send_json(404, {'error': {'code': 'NotFound', 'message': self.path}})

        def do_GET(self):
            host = f'http://127.0.0.1:{self.server.server_address[1]}'
            if self.path.startswith('/files/'):
                state.download_headers.append(dict(self.headers))
                if self.path.startswith('/files/expired.png'):
                    self._send_bytes(403, b'<Error><Code>AccessDenied</Code><Message>Request has expired</Message></Error>', 'application/xml')
                    return
                if self.path.startswith('/files/out.png'):
                    self._send_bytes(200, state.image_bytes, 'image/png')
                    return
                if self.path.startswith('/files/out.mp4'):
                    if state.video_dl_status != 200:
                        self._send_bytes(state.video_dl_status, b'URL expired', 'text/plain')
                    else:
                        self._send_bytes(200, state.video_bytes, 'video/mp4')
                    return
                self._send_bytes(404, b'Not Found', 'text/plain')
                return

            state.requests.append({
                'method': 'GET',
                'path': self.path,
                'auth': self.headers.get('Authorization'),
                'body': None,
            })
            prefix = '/api/v3/contents/generations/tasks/'
            if self.path.startswith(prefix):
                tid = self.path[len(prefix):]
                idx = state.task_polls.get(tid, 0)
                state.task_polls[tid] = idx + 1
                plan = state.video_plan
                st = plan[min(idx, len(plan) - 1)]
                resp = {'id': tid, 'model': ark.DEFAULT_VIDEO_MODEL, 'status': st}
                if st == 'succeeded':
                    resp['content'] = {'video_url': f'{host}/files/out.mp4?X-Tos-Signature=vidsig'}
                    resp['usage'] = {'completion_tokens': 88000, 'total_tokens': 88000}
                elif st == 'failed':
                    resp['error'] = state.fail_error
                self._send_json(200, resp)
                return

            self._send_json(404, {'error': {'code': 'NotFound', 'message': self.path}})

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f'http://127.0.0.1:{server.server_address[1]}/api/v3'
    return server, base_url


def run_cli(argv, keychain_rc=0, keychain_out=TEST_KEY):
    fake_proc = subprocess.CompletedProcess(
        args=['security', 'find-generic-password'],
        returncode=keychain_rc,
        stdout=(keychain_out + '\n') if keychain_rc == 0 else '',
        stderr='' if keychain_rc == 0 else 'security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.',
    )
    out_buf, err_buf = io.StringIO(), io.StringIO()
    with mock.patch.object(ark.subprocess, 'run', return_value=fake_proc) as m_run:
        with contextlib.redirect_stdout(out_buf), contextlib.redirect_stderr(err_buf):
            rc = ark.main(argv)
    return rc, out_buf.getvalue(), err_buf.getvalue(), m_run


class ArkMediaCliTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='ark_cli_test_'))
        self.state = FakeArkState()
        self.server, self.base_url = start_fake_server(self.state)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def test_txt2img_defaults_and_download(self):
        out = self.tmp / 't2i.png'
        meta = self.tmp / 'meta.json'
        rc, stdout, stderr, m_run = run_cli([
            'txt2img',
            '--prompt', '纯绿底武侠剑客',
            '--out', str(out),
            '--meta-out', str(meta),
            '--base-url', self.base_url,
        ])
        self.assertEqual(rc, 0, stderr)
        self.assertEqual(out.read_bytes(), TINY_PNG)
        # 验证调用了 security 读取 ark-api-key
        m_run.assert_called_once_with(
            ['security', 'find-generic-password', '-s', 'ark-api-key', '-w'],
            capture_output=True, text=True, check=False,
        )
        req = self.state.requests[0]
        self.assertEqual(req['path'], '/api/v3/images/generations')
        self.assertEqual(req['auth'], f'Bearer {TEST_KEY}')
        self.assertEqual(req['body']['model'], ark.DEFAULT_IMAGE_MODEL)
        self.assertEqual(req['body']['size'], '2048x2048')
        self.assertIs(req['body']['watermark'], False)
        self.assertNotIn('image', req['body'])
        # 下载图片不能带 Authorization 头
        self.assertEqual(len(self.state.download_headers), 1)
        self.assertNotIn('Authorization', self.state.download_headers[0])
        # stdout 与 meta 都不含密钥明文
        self.assertNotIn(TEST_KEY, stdout)
        self.assertNotIn(TEST_KEY, meta.read_text(encoding='utf-8'))
        parsed = json.loads(stdout)
        self.assertEqual(parsed['mode'], 'txt2img')
        self.assertEqual(parsed['usage']['generated_images'], 1)

    def test_txt2img_b64_and_overrides(self):
        self.state.image_mode = 'b64'
        out = self.tmp / 't2i_b64.png'
        rc, stdout, stderr, _ = run_cli([
            '文生图',
            '--prompt', '测试图',
            '--model', 'ep-custom-123',
            '--size', '16:9',
            '--watermark',
            '--seed', '77',
            '--response-format', 'b64_json',
            '--out', str(out),
            '--base-url', self.base_url,
        ])
        self.assertEqual(rc, 0, stderr)
        self.assertEqual(out.read_bytes(), TINY_PNG)
        body = self.state.requests[0]['body']
        self.assertEqual(body['model'], 'ep-custom-123')
        self.assertEqual(body['size'], '2560x1440')
        self.assertIs(body['watermark'], True)
        self.assertEqual(body['seed'], 77)
        self.assertEqual(body['response_format'], 'b64_json')

    def test_img2img_single_and_multi_ref(self):
        ref1 = self.tmp / 'ref1.png'
        ref2 = self.tmp / 'ref2.jpg'
        ref1.write_bytes(TINY_PNG)
        ref2.write_bytes(TINY_JPG)

        # 单图：image 为 Data URI 字符串
        out1 = self.tmp / 'i2i_1.png'
        rc1, _, err1, _ = run_cli([
            'img2img', '--ref', str(ref1), '--prompt', '单图改姿势',
            '--out', str(out1), '--base-url', self.base_url,
        ])
        self.assertEqual(rc1, 0, err1)
        img_single = self.state.requests[-1]['body']['image']
        self.assertIsInstance(img_single, str)
        self.assertTrue(img_single.startswith('data:image/png;base64,'))
        self.assertEqual(base64.b64decode(img_single.split(',', 1)[1]), TINY_PNG)

        # 多图：image 为数组且识别不同 MIME
        out2 = self.tmp / 'i2i_2.png'
        rc2, stdout2, err2, _ = run_cli([
            '图生图', '--ref', str(ref1), '--ref', str(ref2), '--prompt', '双图融合',
            '--out', str(out2), '--base-url', self.base_url,
        ])
        self.assertEqual(rc2, 0, err2)
        imgs = self.state.requests[-1]['body']['image']
        self.assertIsInstance(imgs, list)
        self.assertEqual(len(imgs), 2)
        self.assertTrue(imgs[0].startswith('data:image/png;base64,'))
        self.assertTrue(imgs[1].startswith('data:image/jpeg;base64,'))
        self.assertEqual(json.loads(stdout2)['refs_count'], 2)

    def test_img2vid_poll_and_download(self):
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)
        out = self.tmp / 'clip.mp4'
        rc, stdout, stderr, _ = run_cli([
            'img2vid',
            '--first-frame', str(frame),
            '--prompt', '拔刀挥砍',
            '--poll-interval', '0.01',
            '--timeout', '5',
            '--out', str(out),
            '--base-url', self.base_url,
        ])
        self.assertEqual(rc, 0, stderr)
        self.assertEqual(out.read_bytes(), FAKE_MP4)
        # 校验 POST 建任务参数
        post_req = self.state.requests[0]
        self.assertEqual(post_req['method'], 'POST')
        self.assertEqual(post_req['path'], '/api/v3/contents/generations/tasks')
        body = post_req['body']
        self.assertEqual(body['model'], ark.DEFAULT_VIDEO_MODEL)
        self.assertEqual(body['ratio'], '1:1')
        self.assertEqual(body['duration'], 4)
        self.assertIs(body['watermark'], False)
        roles = [c.get('role') for c in body['content'] if c.get('type') == 'image_url']
        self.assertEqual(roles, ['first_frame'])
        # 校验 3 次轮询 GET（queued -> running -> succeeded）
        get_reqs = [r for r in self.state.requests if r['method'] == 'GET']
        self.assertEqual(len(get_reqs), 3)
        # 下载视频不带 Authorization 头
        self.assertEqual(len(self.state.download_headers), 1)
        self.assertNotIn('Authorization', self.state.download_headers[0])
        parsed = json.loads(stdout)
        self.assertEqual(parsed['mode'], 'img2vid')
        self.assertEqual(parsed['polls'], 3)
        self.assertEqual(parsed['usage']['total_tokens'], 88000)

    def test_img2vid_task_failed_and_secret_redacted(self):
        self.state.video_plan = ['queued', 'failed']
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)
        out = self.tmp / 'fail.mp4'
        rc, _, stderr, _ = run_cli([
            'img2vid', '--first-frame', str(frame), '--prompt', '失败路径',
            '--poll-interval', '0.01', '--timeout', '5',
            '--out', str(out), '--base-url', self.base_url,
        ])
        self.assertNotEqual(rc, 0)
        self.assertIn('视频任务失败', stderr)
        self.assertIn('ModelError', stderr)
        self.assertNotIn(TEST_KEY, stderr)
        self.assertIn('***REDACTED***', stderr)
        self.assertFalse(out.exists())

    def test_img2vid_timeout(self):
        self.state.video_plan = ['running']
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)
        out = self.tmp / 'timeout.mp4'
        rc, _, stderr, _ = run_cli([
            'img2vid', '--first-frame', str(frame), '--prompt', '超时路径',
            '--poll-interval', '0.02', '--timeout', '0.07',
            '--out', str(out), '--base-url', self.base_url,
        ])
        self.assertNotEqual(rc, 0)
        self.assertIn('超时', stderr)
        self.assertIn('cgt-fake-1', stderr)
        self.assertFalse(out.exists())

    def test_expired_image_and_video_urls(self):
        # 图片 URL 过期（403）
        self.state.image_mode = 'expired_url'
        img_out = self.tmp / 'expired.png'
        rc1, _, err1, _ = run_cli([
            'txt2img', '--prompt', '过期图', '--out', str(img_out), '--base-url', self.base_url,
        ])
        self.assertNotEqual(rc1, 0)
        self.assertIn('过期', err1)
        self.assertNotIn('sig123', err1)
        self.assertFalse(img_out.exists())

        # 视频 URL 过期（410）
        self.state.video_plan = ['succeeded']
        self.state.video_dl_status = 410
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)
        vid_out = self.tmp / 'expired.mp4'
        rc2, _, err2, _ = run_cli([
            'img2vid', '--first-frame', str(frame), '--prompt', '过期视频',
            '--poll-interval', '0.01', '--timeout', '5',
            '--out', str(vid_out), '--base-url', self.base_url,
        ])
        self.assertNotEqual(rc2, 0)
        self.assertIn('过期', err2)
        self.assertNotIn('vidsig', err2)
        self.assertFalse(vid_out.exists())

    def test_missing_keychain_ignores_env_var(self):
        out = self.tmp / 'nokey.png'
        with mock.patch.dict(os.environ, {'ARK_API_KEY': 'should-never-be-read'}):
            rc, _, stderr, _ = run_cli(
                ['txt2img', '--prompt', '无钥匙', '--out', str(out), '--base-url', self.base_url],
                keychain_rc=44,
            )
        self.assertEqual(rc, 2)
        self.assertIn('ark-api-key', stderr)
        self.assertIn('security add-generic-password', stderr)
        self.assertEqual(len(self.state.requests), 0)

    def test_http_error_redacts_api_key(self):
        self.state.image_mode = 'leak_error'
        out = self.tmp / 'err.png'
        rc, _, stderr, _ = run_cli([
            'txt2img', '--prompt', '报错脱敏', '--out', str(out), '--base-url', self.base_url,
        ])
        self.assertNotEqual(rc, 0)
        self.assertIn('HTTP 401', stderr)
        self.assertNotIn(TEST_KEY, stderr)
        self.assertIn('***REDACTED***', stderr)

    def test_green_key_hook_and_keep_raw(self):
        """验证 --green-key 钩子调用与保留原图／不保留原图行为（不依赖本机是否装 Pillow）。"""
        out = self.tmp / 'hero.png'
        calls = []

        def fake_key(raw_path, out_path, key_overrides=None):
            calls.append((Path(raw_path), Path(out_path), key_overrides))
            Path(out_path).write_bytes(b'KEYED_PNG')
            return {'out': str(out_path), 'fg_ratio': 0.25}

        with mock.patch.object(ark, 'apply_green_key_image', side_effect=fake_key):
            rc, stdout, stderr, _ = run_cli([
                'txt2img', '--prompt', '绿底角色', '--green-key',
                '--key-threshold', '55', '--erode', '2', '--despill-band', '4',
                '--out', str(out), '--base-url', self.base_url,
            ])
        self.assertEqual(rc, 0, stderr)
        self.assertEqual(len(calls), 1)
        raw_path, out_path, overrides = calls[0]
        self.assertEqual(out_path, out)
        self.assertEqual(raw_path, self.tmp / 'hero_raw.png')
        self.assertEqual(raw_path.read_bytes(), TINY_PNG)
        self.assertEqual(out.read_bytes(), b'KEYED_PNG')
        self.assertEqual(overrides, {'key_threshold': 55, 'erode': 2, 'despill_band': 4})
        self.assertEqual(json.loads(stdout)['raw_out'], str(raw_path))

        # --no-keep-raw 时不残留临时原图
        out2 = self.tmp / 'hero2.png'
        with mock.patch.object(ark, 'apply_green_key_image', side_effect=fake_key):
            rc2, stdout2, stderr2, _ = run_cli([
                'txt2img', '--prompt', '绿底不留原图', '--green-key', '--no-keep-raw',
                '--out', str(out2), '--base-url', self.base_url,
            ])
        self.assertEqual(rc2, 0, stderr2)
        self.assertIsNone(json.loads(stdout2)['raw_out'])
        self.assertFalse((self.tmp / 'hero2_raw.png').exists())

    def test_green_key_real_muse_reuse(self):
        """若当前 Python 装有 Pillow＋numpy，则端到端实测复用 muse转精灵.py 抠绿；否则验证缺依赖提示。"""
        try:
            import numpy as np
            from PIL import Image
            has_deps = True
        except ModuleNotFoundError:
            has_deps = False

        if not has_deps:
            out = self.tmp / 'nodeps.png'
            rc, _, stderr, _ = run_cli([
                'txt2img', '--prompt', '绿底', '--green-key',
                '--out', str(out), '--base-url', self.base_url,
            ])
            self.assertEqual(rc, 2)
            self.assertIn('muse转精灵.py', stderr)
            self.assertIn('pillow', stderr.lower())
            return

        # 合成一张 32x32 纯绿底 + 中央 12x12 红方块 PNG
        img = Image.new('RGB', (32, 32), (0, 250, 10))
        for y in range(10, 22):
            for x in range(10, 22):
                img.putpixel((x, y), (220, 40, 40))
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        self.state.image_bytes = buf.getvalue()

        out = self.tmp / 'keyed_real.png'
        rc, stdout, stderr, _ = run_cli([
            'txt2img', '--prompt', '纯绿底方块', '--green-key',
            '--out', str(out), '--base-url', self.base_url,
        ])
        self.assertEqual(rc, 0, stderr)
        rgba = np.asarray(Image.open(out))
        self.assertEqual(rgba.shape, (32, 32, 4))
        # 四角绿底完全透明
        self.assertEqual(int(rgba[0, 0, 3]), 0)
        self.assertEqual(int(rgba[31, 31, 3]), 0)
        # 中心红方块不透明且保持红色
        self.assertEqual(int(rgba[16, 16, 3]), 255)
        self.assertGreater(int(rgba[16, 16, 0]), 200)
        self.assertTrue((self.tmp / 'keyed_real_raw.png').is_file())


if __name__ == '__main__':
    unittest.main()
