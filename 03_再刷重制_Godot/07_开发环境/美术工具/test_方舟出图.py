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
# 合法可解码的 1x1 JPEG（供 Pillow 与 macOS sips 实测转 PNG）
VALID_1X1_JPG = base64.b64decode(
    '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaAD'
    'AAQAAAABAAAAAQAAAAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAAQABAwEi'
    'AAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGh'
    'CCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqi'
    'o6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYH'
    'CAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpD'
    'REVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ'
    '2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8P'
    'Dw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/a'
    'AAwDAQACEQMRAD8A+L6KKK/lM/38P//Z'
)
FAKE_MP4 = b'\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isomFAKEVIDEO'
TEST_KEY = 'ark-secret-test-key-9876543210'


class FakeArkState:
    def __init__(self):
        self.requests = []
        self.download_headers = []
        self.image_bytes = TINY_PNG
        self.video_bytes = FAKE_MP4
        self.image_mode = 'auto'         # auto | url | b64 | expired_url | leak_error
        self.image_dl_plan = []          # 可选：模拟 /files/out.png 依次返回 503 / 'drop' / 200
        self.image_dl_attempts = 0
        self.video_plan = ['queued', 'running', 'succeeded']
        self.video_dl_status = 200
        self.task_counter = 0
        self.task_polls = {}
        self.fail_error = {'code': 'ModelError', 'message': f'敏感报错回显 Bearer {TEST_KEY}'}
        self.redirect_status = None      # 若设为 302/307，则 API 端点返回跳转
        self.redirect_location = None


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

        def _maybe_redirect(self):
            if state.redirect_status and state.redirect_location:
                self.send_response(state.redirect_status)
                self.send_header('Location', state.redirect_location)
                self.send_header('Content-Length', '0')
                self.end_headers()
                return True
            return False

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

            if self._maybe_redirect():
                return

            host = f'http://127.0.0.1:{self.server.server_address[1]}'
            if self.path == '/api/plan/v3/images/generations':
                if state.image_mode == 'leak_error':
                    self._send_json(401, {
                        'error': {
                            'code': 'InvalidAPIKey',
                            'message': f'bad token {TEST_KEY} from header Bearer {TEST_KEY}',
                        }
                    })
                    return
                use_b64 = state.image_mode == 'b64' or (
                    state.image_mode == 'auto' and body.get('response_format') == 'b64_json'
                )
                if use_b64:
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

            if self.path == '/api/plan/v3/contents/generations/tasks':
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
                    idx = state.image_dl_attempts
                    state.image_dl_attempts += 1
                    if state.image_dl_plan:
                        step = state.image_dl_plan[min(idx, len(state.image_dl_plan) - 1)]
                        if step == 'drop':
                            self.connection.close()
                            return
                        if isinstance(step, int) and step != 200:
                            self._send_bytes(step, b'transient download error', 'text/plain')
                            return
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
            if self._maybe_redirect():
                return

            prefix = '/api/plan/v3/contents/generations/tasks/'
            if self.path.startswith(prefix):
                tid = self.path[len(prefix):]
                idx = state.task_polls.get(tid, 0)
                state.task_polls[tid] = idx + 1
                plan = state.video_plan
                step = plan[min(idx, len(plan) - 1)]
                if isinstance(step, int):
                    self._send_json(step, {'error': {'code': f'HTTP{step}', 'message': 'transient upstream error'}})
                    return
                if step == 'drop':
                    self.connection.close()
                    return
                resp = {'id': tid, 'model': 'seedance-test', 'status': step}
                if step == 'succeeded':
                    resp['content'] = {'video_url': f'{host}/files/out.mp4?X-Tos-Signature=vidsig'}
                    resp['usage'] = {'completion_tokens': 88000, 'total_tokens': 88000}
                elif step == 'failed':
                    resp['error'] = state.fail_error
                self._send_json(200, resp)
                return

            self._send_json(404, {'error': {'code': 'NotFound', 'message': self.path}})

    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f'http://127.0.0.1:{server.server_address[1]}/api/plan/v3'
    return server, base_url


def run_cli(argv, keychain_rc=0, keychain_out=TEST_KEY):
    fake_proc = subprocess.CompletedProcess(
        args=['security', 'find-generic-password'],
        returncode=keychain_rc,
        stdout=(keychain_out + '\n') if keychain_rc == 0 else '',
        stderr='' if keychain_rc == 0 else 'security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.',
    )
    real_run = subprocess.run

    def dispatch_run(cmd, *args, **kwargs):
        if cmd and cmd[0] == 'security':
            return fake_proc
        return real_run(cmd, *args, **kwargs)

    out_buf, err_buf = io.StringIO(), io.StringIO()
    with mock.patch.object(ark.subprocess, 'run', side_effect=dispatch_run) as m_run:
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
        self.assertEqual(req['path'], '/api/plan/v3/images/generations')
        self.assertEqual(req['auth'], f'Bearer {TEST_KEY}')
        self.assertEqual(ark.DEFAULT_BASE_URL, 'https://ark.cn-beijing.volces.com/api/plan/v3')
        self.assertEqual(ark.DEFAULT_IMAGE_MODEL, 'doubao-seedream-5.5')
        self.assertEqual(req['body']['model'], 'doubao-seedream-5.5')
        self.assertEqual(req['body']['size'], '2048x2048')
        self.assertEqual(req['body']['response_format'], 'b64_json')
        self.assertIs(req['body']['watermark'], False)
        self.assertNotIn('image', req['body'])
        # 默认 b64_json 直接解码落盘，不触发二次下载
        self.assertEqual(len(self.state.download_headers), 0)
        # stdout 与 meta 都不含密钥明文
        self.assertNotIn(TEST_KEY, stdout)
        self.assertNotIn(TEST_KEY, meta.read_text(encoding='utf-8'))
        parsed = json.loads(stdout)
        self.assertEqual(parsed['mode'], 'txt2img')
        self.assertEqual(parsed['usage']['generated_images'], 1)

        # 显式 --response-format url 走二次下载且不带 Authorization 头
        out_url = self.tmp / 't2i_url.png'
        rc_u, _, err_u, _ = run_cli([
            'txt2img',
            '--prompt', 'URL下载验证',
            '--response-format', 'url',
            '--out', str(out_url),
            '--base-url', self.base_url,
        ])
        self.assertEqual(rc_u, 0, err_u)
        self.assertEqual(out_url.read_bytes(), TINY_PNG)
        self.assertEqual(len(self.state.download_headers), 1)
        self.assertNotIn('Authorization', self.state.download_headers[0])

    def test_url_download_retries_without_regenerating(self):
        """url 模式下载遇 503／断连时仅重试下载，绝不重发图片生成请求。"""
        self.state.image_dl_plan = [503, 'drop', 200]
        out = self.tmp / 'dl_retry.png'
        with mock.patch.object(ark.time, 'sleep', return_value=None):
            rc, _, stderr, _ = run_cli([
                'txt2img',
                '--prompt', '下载重试不重生成',
                '--response-format', 'url',
                '--out', str(out),
                '--base-url', self.base_url,
            ])
        self.assertEqual(rc, 0, stderr)
        self.assertEqual(out.read_bytes(), TINY_PNG)
        post_reqs = [r for r in self.state.requests if r['method'] == 'POST']
        self.assertEqual(len(post_reqs), 1, '下载重试不应重发 POST 生成请求')
        self.assertEqual(self.state.image_dl_attempts, 3)
        self.assertEqual(len(self.state.download_headers), 3)
        for hdrs in self.state.download_headers:
            self.assertNotIn('Authorization', hdrs)
        self.assertIn('仅重试下载', stderr)

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

    def test_video_commands_disabled_by_default(self):
        """Agent Plan 订阅不含 Seedance，img2vid 与 fetch（及所有别名）默认禁用且不读钥匙串、不发网络请求。"""
        self.assertIs(ark.VIDEO_COMMANDS_ENABLED, False)
        self.assertFalse(hasattr(ark, 'DEFAULT_VIDEO_MODEL'))
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)
        out = self.tmp / 'disabled.mp4'

        for cmd in ('img2vid', 'i2v', '图生视频'):
            with self.subTest(cmd=cmd):
                rc, _, stderr, m_run = run_cli([
                    cmd, '--first-frame', str(frame), '--prompt', '禁测',
                    '--out', str(out), '--base-url', self.base_url,
                ])
                self.assertEqual(rc, 2)
                self.assertIn('订阅不含 Seedance，需另购，地址未知', stderr)
                m_run.assert_not_called()
                self.assertEqual(self.state.requests, [])

        for cmd in ('fetch', 'resume', '续取'):
            with self.subTest(cmd=cmd):
                rc, _, stderr, m_run = run_cli([
                    cmd, '--task-id', 'cgt-disabled-1',
                    '--out', str(out), '--base-url', self.base_url,
                ])
                self.assertEqual(rc, 2)
                self.assertIn('订阅不含 Seedance，需另购，地址未知', stderr)
                m_run.assert_not_called()
                self.assertEqual(self.state.requests, [])

        # 直接调用模块函数同样被默认禁用拦截
        client = ark.ArkClient(TEST_KEY, base_url=self.base_url)
        with self.assertRaises(ark.ArkToolError) as ctx1:
            ark.run_video_generation(client, model='seedance-test', prompt='x', first_frame=str(frame), out_path=out)
        self.assertIn('订阅不含 Seedance，需另购，地址未知', str(ctx1.exception))
        with self.assertRaises(ark.ArkToolError) as ctx2:
            ark.run_video_fetch(client, task_id='cgt-1', out_path=out)
        self.assertIn('订阅不含 Seedance，需另购，地址未知', str(ctx2.exception))

    def test_img2vid_poll_and_download(self):
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)
        out = self.tmp / 'clip.mp4'
        with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
            rc, stdout, stderr, _ = run_cli([
                'img2vid',
                '--model', 'seedance-test',
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
        self.assertEqual(post_req['path'], '/api/plan/v3/contents/generations/tasks')
        body = post_req['body']
        self.assertEqual(body['model'], 'seedance-test')
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
        with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
            rc, _, stderr, _ = run_cli([
                'img2vid', '--model', 'seedance-test', '--first-frame', str(frame), '--prompt', '失败路径',
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
        with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
            rc, _, stderr, _ = run_cli([
                'img2vid', '--model', 'seedance-test', '--first-frame', str(frame), '--prompt', '超时路径',
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
        with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
            rc2, _, err2, _ = run_cli([
                'img2vid', '--model', 'seedance-test', '--first-frame', str(frame), '--prompt', '过期视频',
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

    def test_p2_1_redirect_does_not_leak_api_key_to_second_server(self):
        """P2-1 复现与回归：服务端返回 302/307 指向第二台本地服务器时，拒绝跳转且绝不把钥匙发往第二台服务器。"""
        second_hits = []

        class SecondServerHandler(http.server.BaseHTTPRequestHandler):
            def log_message(self, format, *args):
                return

            def _record(self, method):
                second_hits.append({
                    'method': method,
                    'path': self.path,
                    'auth': self.headers.get('Authorization'),
                })
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"stolen": true}')

            def do_GET(self):
                self._record('GET')

            def do_POST(self):
                self._record('POST')

        second_server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), SecondServerHandler)
        threading.Thread(target=second_server.serve_forever, daemon=True).start()
        try:
            port_b = second_server.server_address[1]
            self.state.redirect_status = 302
            self.state.redirect_location = f'http://127.0.0.1:{port_b}/steal?token=secret999'

            out = self.tmp / 'redirected.png'
            rc, _, stderr, _ = run_cli([
                'txt2img', '--prompt', '跳转外泄测试', '--out', str(out), '--base-url', self.base_url,
            ])
            self.assertNotEqual(rc, 0)
            self.assertIn('302', stderr)
            self.assertIn('重定向', stderr)
            self.assertNotIn(TEST_KEY, stderr)
            self.assertNotIn('secret999', stderr)
            self.assertEqual(second_hits, [], f'API Key 随 302 跳转发往了第二台服务器：{second_hits}')
            self.assertFalse(out.exists())

            # 再测 307 跳转在 GET 轮询（fetch）上同样不跟随、不外泄
            self.state.redirect_status = 307
            out_vid = self.tmp / 'redirected.mp4'
            with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
                rc2, _, stderr2, _ = run_cli([
                    'fetch', '--task-id', 'cgt-redirect-1', '--out', str(out_vid), '--base-url', self.base_url,
                ])
            self.assertNotEqual(rc2, 0)
            self.assertIn('307', stderr2)
            self.assertNotIn(TEST_KEY, stderr2)
            self.assertEqual(second_hits, [], f'API Key 随 307 跳转发往了第二台服务器：{second_hits}')
        finally:
            second_server.shutdown()
            second_server.server_close()

    def test_p2_2_base_url_allowlist_and_api_v3_rejected(self):
        """P2-2 与 Agent Plan 防误扣费：仅放行 https://ark.cn-beijing.volces.com/api/plan/v3 前缀与本机单测，/api/v3 一律拒绝且提示额外费用。"""
        port = self.server.server_address[1]
        api_v3_urls = [
            'https://ark.cn-beijing.volces.com/api/v3',
            'https://ark.cn-beijing.volces.com/api/v3/',
            'https://ark.cn-beijing.volces.com/api/v3/images/generations',
            f'http://127.0.0.1:{port}/api/v3',
            f'http://localhost:{port}/api/v3/images/generations',
        ]
        out = self.tmp / 'blocked.png'
        for bad_v3 in api_v3_urls:
            with self.subTest(api_v3=bad_v3):
                rc, _, stderr, m_run = run_cli([
                    'txt2img', '--prompt', '误走v3', '--out', str(out), '--base-url', bad_v3,
                ])
                self.assertEqual(rc, 2, f'预期拒绝 {bad_v3}，实际 rc={rc} stderr={stderr}')
                self.assertIn('额外费用', stderr)
                m_run.assert_not_called()
                with self.assertRaises(ark.ArkToolError) as ctx:
                    ark.ArkClient(TEST_KEY, base_url=bad_v3)
                self.assertIn('额外费用', str(ctx.exception))

        bad_urls = [
            'https://evil.example.com/api/plan/v3',
            'http://evil.example.com/api/plan/v3',
            'http://ark.cn-beijing.volces.com/api/plan/v3',
            'https://ark.cn-beijing.volces.com:8443/api/plan/v3',
            'https://ark.cn-beijing.volces.com.evil.com/api/plan/v3',
            'https://ark.cn-beijing.volces.com@evil.com/api/plan/v3',
            'ftp://127.0.0.1:8080/api/plan/v3',
            'https://ark.cn-beijing.volces.com/api/plan/v3?foo=bar',
            'https://ark.cn-beijing.volces.com',
            'https://ark.cn-beijing.volces.com/api/plan/v2',
            'https://ark.cn-beijing.volces.com/api/plan/v30',
            'https://ark.cn-beijing.volces.com/api/plan/v3/../../v3',
        ]
        for bad in bad_urls:
            with self.subTest(base_url=bad):
                rc, _, stderr, m_run = run_cli([
                    'txt2img', '--prompt', '非法地址', '--out', str(out), '--base-url', bad,
                ])
                self.assertEqual(rc, 2, f'预期拒绝 {bad}，实际 rc={rc} stderr={stderr}')
                self.assertIn('--base-url', stderr)
                m_run.assert_not_called()
                with self.assertRaises(ark.ArkToolError):
                    ark.ArkClient(TEST_KEY, base_url=bad)

        # 合法 Agent Plan 生产前缀通过校验且路径拼接不重复
        self.assertEqual(
            ark.validate_base_url('https://ark.cn-beijing.volces.com/api/plan/v3/'),
            'https://ark.cn-beijing.volces.com/api/plan/v3',
        )
        self.assertEqual(
            ark.ArkClient(TEST_KEY)._build_url('images/generations'),
            'https://ark.cn-beijing.volces.com/api/plan/v3/images/generations',
        )
        self.assertEqual(
            ark.ArkClient(
                TEST_KEY,
                base_url='https://ark.cn-beijing.volces.com/api/plan/v3/images/generations',
            )._build_url('images/generations'),
            'https://ark.cn-beijing.volces.com/api/plan/v3/images/generations',
        )

        # 合法 localhost 本地单测地址可正常走通
        out_ok = self.tmp / 'localhost_ok.png'
        rc_ok, _, err_ok, _ = run_cli([
            'txt2img', '--prompt', 'localhost单测',
            '--out', str(out_ok),
            '--base-url', f'http://localhost:{port}/api/plan/v3',
        ])
        self.assertEqual(rc_ok, 0, err_ok)
        self.assertEqual(out_ok.read_bytes(), TINY_PNG)

    def test_p2_3_fake_png_magic_validation_converts_or_rejects(self):
        """P2-3 复现与回归：接口返回 JPEG 字节但 --out 为 .png 时，自动转为真 PNG 或报错拒写伪 PNG；Seedream 5.x 自动请求 png。"""
        # 1) Seedream 5.x 默认对 .png 自动带 output_format=png；4.x 不带避免 400
        out_5x = self.tmp / 'req5x.png'
        rc0, _, err0, _ = run_cli([
            'txt2img', '--prompt', '5x格式测试', '--out', str(out_5x), '--base-url', self.base_url,
        ])
        self.assertEqual(rc0, 0, err0)
        self.assertEqual(self.state.requests[-1]['body'].get('output_format'), 'png')

        out_4x = self.tmp / 'req4x.png'
        rc4, _, err4, _ = run_cli([
            'txt2img', '--prompt', '4x格式测试', '--model', 'doubao-seedream-4.5',
            '--out', str(out_4x), '--base-url', self.base_url,
        ])
        self.assertEqual(rc4, 0, err4)
        self.assertNotIn('output_format', self.state.requests[-1]['body'])

        # 2) 模拟服务端忽略请求直接返回合法 JPEG 字节，目标为 .png -> 自动转为真 PNG（文件头必须是 PNG 魔数）
        self.state.image_bytes = VALID_1X1_JPG
        out_conv = self.tmp / 'converted.png'
        rc_conv, stdout_conv, stderr_conv, _ = run_cli([
            'txt2img', '--prompt', '伪PNG自动转换', '--out', str(out_conv), '--base-url', self.base_url,
        ])
        self.assertEqual(rc_conv, 0, stderr_conv)
        self.assertTrue(out_conv.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'))
        self.assertIn('自动转为 png', stderr_conv)
        parsed = json.loads(stdout_conv)
        self.assertEqual(parsed['image_format'], 'png')
        self.assertEqual(parsed['converted_from'], 'jpeg')

        # 3) 当转换不可用时，报错且绝不把 JPEG 字节写成伪 .png
        out_reject = self.tmp / 'no_fake.png'
        with mock.patch.object(ark, 'convert_image_file', return_value=(False, '未安装 Pillow')):
            rc_rej, _, stderr_rej, _ = run_cli([
                'txt2img', '--prompt', '伪PNG拒写', '--out', str(out_reject), '--base-url', self.base_url,
            ])
        self.assertNotEqual(rc_rej, 0)
        self.assertIn('格式与目标扩展名不符', stderr_rej)
        self.assertIn('Godot', stderr_rej)
        self.assertFalse(out_reject.exists())

        # 4) 服务端返回非图片内容时报错且不落盘
        self.state.image_bytes = b'<html>not an image</html>'
        out_bad = self.tmp / 'garbage.png'
        rc_bad, _, stderr_bad, _ = run_cli([
            'txt2img', '--prompt', '损坏内容', '--out', str(out_bad), '--base-url', self.base_url,
        ])
        self.assertNotEqual(rc_bad, 0)
        self.assertIn('不是可识别的图片格式', stderr_bad)
        self.assertFalse(out_bad.exists())

    def test_p3_1_poll_retries_and_fetch_resume(self):
        """P3-1：轮询遇 5xx / 断连按 --poll-retries 重试并恢复；重试耗尽后提示 fetch --task-id，续取不重复建任务。"""
        frame = self.tmp / 'first.png'
        frame.write_bytes(TINY_PNG)

        with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
            # 1) 轮询中出现 503、连接断开、502 后成功 -> 自动重试并下载完成
            self.state.video_plan = [503, 'queued', 'drop', 502, 'succeeded']
            out_ok = self.tmp / 'retry_ok.mp4'
            rc_ok, stdout_ok, stderr_ok, _ = run_cli([
                'img2vid', '--model', 'seedance-test', '--first-frame', str(frame), '--prompt', '重试恢复',
                '--poll-interval', '0.01', '--timeout', '5', '--poll-retries', '3',
                '--out', str(out_ok), '--base-url', self.base_url,
            ])
            self.assertEqual(rc_ok, 0, stderr_ok)
            self.assertEqual(out_ok.read_bytes(), FAKE_MP4)
            self.assertIn('临时错误', stderr_ok)
            parsed_ok = json.loads(stdout_ok)
            self.assertEqual(parsed_ok['poll_retries_used'], 3)

            # 2) 连续 503 超过 --poll-retries -> 退出并给出 fetch --task-id 续取命令
            self.state.video_plan = [503, 503, 'running', 'succeeded']
            out_resume = self.tmp / 'resumed.mp4'
            rc_fail, _, stderr_fail, _ = run_cli([
                'img2vid', '--model', 'seedance-test', '--first-frame', str(frame), '--prompt', '重试耗尽后继续取',
                '--poll-interval', '0.01', '--timeout', '5', '--poll-retries', '1',
                '--out', str(out_resume), '--base-url', self.base_url,
            ])
            self.assertNotEqual(rc_fail, 0)
            self.assertIn('fetch --task-id cgt-fake-2', stderr_fail)
            self.assertFalse(out_resume.exists())

            # 3) 用 fetch --task-id 续取同一任务：不再发 POST 建任务，直接 GET 轮询并下载
            posts_before = len([r for r in self.state.requests if r['method'] == 'POST'])
            rc_fetch, stdout_fetch, stderr_fetch, _ = run_cli([
                'fetch', '--task-id', 'cgt-fake-2',
                '--poll-interval', '0.01', '--timeout', '5',
                '--out', str(out_resume), '--base-url', self.base_url,
            ])
            self.assertEqual(rc_fetch, 0, stderr_fetch)
            self.assertEqual(out_resume.read_bytes(), FAKE_MP4)
            posts_after = len([r for r in self.state.requests if r['method'] == 'POST'])
            self.assertEqual(posts_after, posts_before, 'fetch 续取不应新建任务')
            parsed_fetch = json.loads(stdout_fetch)
            self.assertEqual(parsed_fetch['mode'], 'fetch')
            self.assertEqual(parsed_fetch['task_id'], 'cgt-fake-2')

    def test_p3_2_img2vid_first_frame_and_ref_mutually_exclusive(self):
        """P3-2：img2vid 的 --first-frame 与 --ref 互斥，--last-frame 必须配合 --first-frame，单用 --ref 可走参考图生视频。"""
        img1 = self.tmp / 'f1.png'
        img2 = self.tmp / 'f2.png'
        img1.write_bytes(TINY_PNG)
        img2.write_bytes(TINY_PNG)
        out = self.tmp / 'vid.mp4'

        with mock.patch.object(ark, 'VIDEO_COMMANDS_ENABLED', True):
            # 同时传 --first-frame 与 --ref -> 拒绝且不读钥匙串
            rc1, _, err1, m1 = run_cli([
                'img2vid', '--model', 'seedance-test', '--first-frame', str(img1), '--ref', str(img2),
                '--prompt', '混用测试', '--out', str(out), '--base-url', self.base_url,
            ])
            self.assertEqual(rc1, 2)
            self.assertIn('互斥', err1)
            m1.assert_not_called()

            # 二者都不传 -> 拒绝
            rc2, _, err2, m2 = run_cli([
                'img2vid', '--model', 'seedance-test', '--prompt', '缺少图输入', '--out', str(out), '--base-url', self.base_url,
            ])
            self.assertEqual(rc2, 2)
            self.assertIn('--first-frame', err2)
            m2.assert_not_called()

            # --last-frame 与 --ref 混用 -> 拒绝
            rc3, _, err3, m3 = run_cli([
                'img2vid', '--model', 'seedance-test', '--ref', str(img1), '--last-frame', str(img2),
                '--prompt', '尾帧混用', '--out', str(out), '--base-url', self.base_url,
            ])
            self.assertEqual(rc3, 2)
            self.assertIn('--last-frame', err3)
            m3.assert_not_called()

            # 仅传 --ref（多张）-> 正常建任务并发送 reference_image 角色
            self.state.video_plan = ['succeeded']
            rc4, stdout4, err4, _ = run_cli([
                'img2vid', '--model', 'seedance-test', '--ref', str(img1), '--ref', str(img2),
                '--prompt', '参考图生视频', '--poll-interval', '0.01', '--timeout', '5',
                '--out', str(out), '--base-url', self.base_url,
            ])
            self.assertEqual(rc4, 0, err4)
            post_body = [r for r in self.state.requests if r['method'] == 'POST'][-1]['body']
            roles = [c.get('role') for c in post_body['content'] if c.get('type') == 'image_url']
            self.assertEqual(roles, ['reference_image', 'reference_image'])
            self.assertEqual(json.loads(stdout4)['mode'], 'img2vid')


if __name__ == '__main__':
    unittest.main()
