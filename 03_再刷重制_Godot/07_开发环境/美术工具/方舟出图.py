#!/usr/bin/env python3
"""火山方舟（Volcengine Ark）出图与出视频命令行工具。

直接调用火山方舟 REST 接口（纯 Python 标准库，无第三方 MCP 依赖）：
- 文生图（txt2img / t2i / 文生图）：POST /api/v3/images/generations（Seedream）
- 图生图（img2img / i2i / 图生图）：POST /api/v3/images/generations（Seedream，--ref 支持多张本地图）
- 图生视频（img2vid / i2v / 图生视频）：POST / GET /api/v3/contents/generations/tasks（Seedance，轮询并下载）
- 抠绿（--green-key）：按需复用同目录 muse转精灵.py 的 key_mask + despill（此时需 Pillow＋numpy）

【开通火山方舟】
1. 登录火山引擎控制台（https://console.volcengine.com/ark），开通「火山方舟」服务。
2. 在「模型广场」或「开通管理」里开通所需模型：
   - 出图：Seedream（如 doubao-seedream-5-5-261028 / doubao-seedream-5-0-pro-260628 / doubao-seedream-4-5-251128）
   - 视频：Seedance（如 doubao-seedance-2-5-260628 / doubao-seedance-2-0-260128 / doubao-seedance-1-5-pro-251215）
   （也可创建自定义推理接入点 ep-xxxx，通过 --model 传入。）
3. 在「API Key 管理」创建 API Key，并在账户内充值按量计费额度。

【存入 macOS 钥匙串】
本工具只从 macOS 钥匙串读取钥匙（service 默认 ark-api-key），不读环境变量或 .env 文件，不写盘、不打印原文。
存入或更新钥匙（终端会提示输入，不会留在命令历史里）：
  security add-generic-password -U -a "$USER" -s ark-api-key -w
验证钥匙是否存在（不打印内容）：
  security find-generic-password -s ark-api-key >/dev/null && echo "已存入"

【费用参考（人民币，具体以方舟控制台实时刊例为准）】
- Seedream 文生图／图生图：约 0.22～0.40 元／张（如 5.0 Lite 约 0.22 元起、5.0 Pro 约 0.30 元起）。
- Seedance 图生视频：按分辨率与时长计费（底层折算 Token），大致折合：
  480p 约 0.46～0.70 元／秒（4 秒约 2～3 元）；
  720p 约 0.99～1.50 元／秒（4 秒约 4～6 元）；
  1080p 约 2.50～3.70 元／秒（4 秒约 10～15 元）。

【常用示例】
  python3 方舟出图.py txt2img --prompt "纯绿底像素风剑客立绘" --out out/role.png --green-key
  python3 方舟出图.py img2img --ref ref1.jpg --ref ref2.png --prompt "拔刀定妆" --out out/m5a.png
  python3 方舟出图.py img2vid --first-frame out/m5a.png --prompt "拔刀挥砍" --duration 4 --out out/m5a.mp4
"""
import argparse
import base64
import importlib.util
import json
import mimetypes
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_BASE_URL = 'https://ark.cn-beijing.volces.com/api/v3'
KEYCHAIN_SERVICE = 'ark-api-key'
DEFAULT_IMAGE_MODEL = 'doubao-seedream-5-5-261028'
DEFAULT_VIDEO_MODEL = 'doubao-seedance-2-5-260628'

# 常用比例到 Seedream 2K 像素尺寸的映射（默认 1:1 = 2048x2048）
SIZE_PRESETS = {
    '1:1': '2048x2048',
    '16:9': '2560x1440',
    '9:16': '1440x2560',
    '4:3': '2304x1728',
    '3:4': '1728x2304',
    '3:2': '2496x1664',
    '2:3': '1664x2496',
}

PENDING_STATUSES = {'queued', 'running', 'pending', 'processing', 'submitted', 'created'}
SUCCESS_STATUSES = {'succeeded', 'completed', 'success'}
FAILED_STATUSES = {'failed', 'cancelled', 'canceled', 'expired', 'error'}

EXPIRED_HINT_KEYWORDS = (
    'expired',
    'signaturedoesnotmatch',
    'accessdenied',
    'request has expired',
    'url expired',
    'link expired',
)

HERE = Path(__file__).resolve().parent
MUSE_SCRIPT = HERE / 'muse转精灵.py'

_BEARER_RE = re.compile(r'(Bearer\s+)([^\s"\',;]+)', re.IGNORECASE)
_QUERY_SECRET_RE = re.compile(
    r'([?&](?:api_key|apikey|token|x-tos-signature|signature|x-tos-security-token)=)([^&\s"\']+)',
    re.IGNORECASE,
)


class ArkToolError(RuntimeError):
    """工具可预期错误（带明确退出码）。"""

    def __init__(self, message, exit_code=1):
        super().__init__(message)
        self.exit_code = exit_code


# ---------- 钥匙串与打码 ----------

def redact_secret(text, secret=''):
    """脱敏文本中的 API Key、Bearer 令牌与 URL 签名参数。"""
    if text is None:
        return ''
    out = str(text)
    if secret:
        out = out.replace(secret, '***REDACTED***')
    out = _BEARER_RE.sub(r'\1***REDACTED***', out)
    out = _QUERY_SECRET_RE.sub(r'\1***REDACTED***', out)
    return out


def read_api_key(service=KEYCHAIN_SERVICE):
    """只从 macOS 钥匙串读取 API Key，不读环境变量或本地文件。"""
    cmd = ['security', 'find-generic-password', '-s', service, '-w']
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError as exc:
        raise ArkToolError(
            f'当前系统未找到 macOS 钥匙串命令 `security`（无法读取 "{service}"）。本工具仅支持从 macOS 钥匙串取钥匙。',
            exit_code=2,
        ) from exc

    key = (proc.stdout or '').strip()
    if proc.returncode != 0 or not key:
        raise ArkToolError(
            f'未在 macOS 钥匙串找到服务名 "{service}" 的火山方舟 API Key。\n'
            f'请先运行以下命令存入钥匙串（按提示输入 API Key，不会落盘）：\n'
            f'  security add-generic-password -U -a "$USER" -s {service} -w',
            exit_code=2,
        )
    return key


# ---------- 输入处理 ----------

def detect_image_mime(data, path):
    """优先按文件头魔数判断图片 MIME，退回扩展名。"""
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'image/png'
    if data.startswith(b'\xff\xd8\xff'):
        return 'image/jpeg'
    if len(data) >= 12 and data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return 'image/webp'
    if data.startswith((b'GIF87a', b'GIF89a')):
        return 'image/gif'
    guessed, _ = mimetypes.guess_type(str(path))
    if guessed and guessed.startswith('image/'):
        return guessed
    return 'image/png'


def load_image_input(spec):
    """本地图片转 Base64 Data URI；若已是 URL 或 Data URI 则原样返回。"""
    if spec.startswith(('http://', 'https://', 'data:image/')):
        return spec
    path = Path(spec).expanduser()
    if not path.is_file():
        raise ArkToolError(f'找不到参考图文件：{path}', exit_code=2)
    data = path.read_bytes()
    if not data:
        raise ArkToolError(f'参考图文件为空：{path}', exit_code=2)
    mime = detect_image_mime(data, path)
    b64 = base64.b64encode(data).decode('ascii')
    return f'data:{mime};base64,{b64}'


def resolve_prompt(prompt, prompt_file):
    if prompt and prompt_file:
        raise ArkToolError('--prompt 与 --prompt-file 不能同时使用。', exit_code=2)
    if prompt_file:
        p = Path(prompt_file).expanduser()
        if not p.is_file():
            raise ArkToolError(f'找不到提示词文件：{p}', exit_code=2)
        text = p.read_text(encoding='utf-8').strip()
    else:
        text = (prompt or '').strip()
    if not text:
        raise ArkToolError('提示词不能为空，请传 --prompt 或 --prompt-file。', exit_code=2)
    return text


def resolve_size(size_str):
    raw = (size_str or '1:1').strip()
    return SIZE_PRESETS.get(raw, raw)


# ---------- 火山方舟 HTTP 客户端 ----------

class ArkClient:
    """火山方舟 REST 客户端（纯 urllib，报错自动打码）。"""

    def __init__(self, api_key, base_url=DEFAULT_BASE_URL, http_timeout=120.0):
        self._api_key = api_key
        self.base_url = base_url.rstrip('/')
        self.http_timeout = float(http_timeout)

    def _safe(self, text):
        return redact_secret(text, self._api_key)

    def request_json(self, method, path, payload=None):
        url = f'{self.base_url}/{path.lstrip("/")}'
        body = None
        headers = {
            'Authorization': f'Bearer {self._api_key}',
            'Accept': 'application/json',
        }
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
            headers['Content-Type'] = 'application/json'

        req = urllib.request.Request(url, data=body, headers=headers, method=method.upper())
        try:
            with urllib.request.urlopen(req, timeout=self.http_timeout) as resp:
                raw = resp.read().decode('utf-8', errors='replace')
        except urllib.error.HTTPError as exc:
            err_body = ''
            try:
                err_body = exc.read().decode('utf-8', errors='replace')
            except Exception:
                err_body = ''
            detail = self._extract_error_detail(err_body)
            raise ArkToolError(
                f'方舟接口返回 HTTP {exc.code}（{method.upper()} {path}）：{self._safe(detail)}'
            ) from exc
        except urllib.error.URLError as exc:
            raise ArkToolError(
                f'连接方舟接口失败（{method.upper()} {path}）：{self._safe(exc.reason)}'
            ) from exc
        except TimeoutError as exc:
            raise ArkToolError(
                f'请求方舟接口超时（{method.upper()} {path}，超时 {self.http_timeout:g}s）。'
            ) from exc

        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            snippet = self._safe(raw[:300])
            raise ArkToolError(f'方舟接口返回了非 JSON 内容：{snippet}') from exc

    def _extract_error_detail(self, raw_body):
        if not raw_body:
            return '无响应正文'
        try:
            obj = json.loads(raw_body)
            err = obj.get('error')
            if isinstance(err, dict):
                code = err.get('code') or ''
                msg = err.get('message') or ''
                if code or msg:
                    return f'{code}: {msg}'.strip(': ')
            if isinstance(obj.get('message'), str):
                return obj['message']
        except Exception:
            pass
        return raw_body.strip()[:400]

    def download_file(self, url, dest_path, timeout=None):
        """下载结果图片／视频（不携带 Authorization 头，避免密钥外泄到对象存储）。"""
        dest = Path(dest_path)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dl_timeout = self.http_timeout if timeout is None else float(timeout)
        req = urllib.request.Request(url, headers={'User-Agent': 'ark-media-cli/1.0'}, method='GET')
        tmp_path = None
        try:
            with urllib.request.urlopen(req, timeout=dl_timeout) as resp:
                with tempfile.NamedTemporaryFile(dir=dest.parent, prefix='.ark_dl_', delete=False) as tf:
                    tmp_path = Path(tf.name)
                    while True:
                        chunk = resp.read(65536)
                        if not chunk:
                            break
                        tf.write(chunk)
            if tmp_path.stat().st_size == 0:
                raise ArkToolError(f'下载的文件为空（URL：{self._safe(url)}）。')
            tmp_path.replace(dest)
            tmp_path = None
            return dest
        except urllib.error.HTTPError as exc:
            err_body = ''
            try:
                err_body = exc.read().decode('utf-8', errors='replace')
            except Exception:
                err_body = ''
            lower_body = err_body.lower()
            is_expired = exc.code in (403, 404, 410) or any(k in lower_body for k in EXPIRED_HINT_KEYWORDS)
            safe_url = self._safe(url)
            safe_detail = self._safe(err_body.strip()[:240])
            if is_expired:
                raise ArkToolError(
                    f'下载结果失败（HTTP {exc.code}），下载链接可能已过期或失效（方舟临时链接通常 24 小时后过期）。'
                    f'URL：{safe_url}' + (f'；详情：{safe_detail}' if safe_detail else '')
                ) from exc
            raise ArkToolError(
                f'下载结果失败（HTTP {exc.code}），URL：{safe_url}' + (f'；详情：{safe_detail}' if safe_detail else '')
            ) from exc
        except urllib.error.URLError as exc:
            raise ArkToolError(f'下载结果网络失败：{self._safe(exc.reason)}') from exc
        except TimeoutError as exc:
            raise ArkToolError(f'下载结果超时（{dl_timeout:g}s）。') from exc
        finally:
            if tmp_path is not None and tmp_path.exists():
                tmp_path.unlink(missing_ok=True)


# ---------- 复用 muse转精灵.py 抠绿 ----------

def load_muse_module():
    """按需加载同目录 muse转精灵.py，复用其 key_mask / despill / read_video。"""
    if not MUSE_SCRIPT.is_file():
        raise ArkToolError(f'找不到抠绿依赖脚本：{MUSE_SCRIPT}', exit_code=2)
    try:
        spec = importlib.util.spec_from_file_location('muse_to_sprite', MUSE_SCRIPT)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod
    except ModuleNotFoundError as exc:
        raise ArkToolError(
            f'--green-key 需要复用 muse转精灵.py，但当前 Python 缺少依赖（{exc.name}）。\n'
            '请先准备带 Pillow 和 numpy 的环境，例如：\n'
            '  python3 -m venv /tmp/ark-venv && /tmp/ark-venv/bin/pip install pillow numpy\n'
            '或先去掉 --green-key 仅下载原图。',
            exit_code=2,
        ) from exc


def build_key_cfg(muse, overrides=None):
    cfg = dict(muse.DEFAULTS)
    for k, v in (overrides or {}).items():
        if v is not None:
            cfg[k] = v
    return cfg


def green_key_rgb_array(muse, rgb_u8, cfg):
    """复用 muse转精灵.py 的 key_mask + despill 生成 RGBA numpy 数组。"""
    import numpy as np

    fg = muse.key_mask(rgb_u8, cfg)
    despilled = muse.despill(rgb_u8, fg, cfg['despill_band'])
    rgba = np.zeros(rgb_u8.shape[:2] + (4,), dtype=np.uint8)
    rgba[fg, :3] = np.clip(np.rint(despilled[fg]), 0, 255).astype(np.uint8)
    rgba[fg, 3] = 255
    return rgba, fg


def apply_green_key_image(raw_path, out_path, key_overrides=None):
    """读取原绿底图，调用 muse转精灵.py 抠绿并输出透明 PNG。"""
    muse = load_muse_module()
    import numpy as np
    from PIL import Image

    cfg = build_key_cfg(muse, key_overrides)
    rgb = np.asarray(Image.open(raw_path).convert('RGB'))
    rgba, fg = green_key_rgb_array(muse, rgb, cfg)
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, 'RGBA').save(out, format='PNG')
    fg_ratio = float(fg.mean()) if fg.size else 0.0
    return {'out': str(out), 'fg_ratio': round(fg_ratio, 4), 'key_cfg': {
        'key_threshold': cfg['key_threshold'],
        'erode': cfg['erode'],
        'despill_band': cfg['despill_band'],
    }}


def apply_green_key_video(video_path, key_overrides=None):
    """复用 muse转精灵.py 逐帧抠绿视频，输出透明 PNG 序列目录。"""
    muse = load_muse_module()
    from PIL import Image

    cfg = build_key_cfg(muse, key_overrides)
    frames, fps = muse.read_video(video_path)
    out_dir = Path(video_path).with_name(Path(video_path).stem + '_keyed')
    out_dir.mkdir(parents=True, exist_ok=True)
    for idx, frame in enumerate(frames):
        rgba, _ = green_key_rgb_array(muse, frame, cfg)
        Image.fromarray(rgba, 'RGBA').save(out_dir / f'frame_{idx:04d}.png', format='PNG')
    return {'frames_dir': str(out_dir), 'frames': len(frames), 'fps': fps}


# ---------- 核心业务流程 ----------

def _raw_path_for(out_path):
    p = Path(out_path)
    suffix = p.suffix or '.png'
    return p.with_name(f'{p.stem}_raw{suffix}')


def _write_meta(meta_out, meta, secret):
    if not meta_out:
        return
    p = Path(meta_out)
    p.parent.mkdir(parents=True, exist_ok=True)
    text = redact_secret(json.dumps(meta, ensure_ascii=False, indent=2), secret)
    p.write_text(text + '\n', encoding='utf-8')


def run_image_generation(
    client,
    *,
    model,
    prompt,
    size='1:1',
    watermark=False,
    refs=None,
    seed=None,
    response_format='url',
    out_path,
    green_key=False,
    key_overrides=None,
    keep_raw=True,
    meta_out=None,
):
    resolved_size = resolve_size(size)
    payload = {
        'model': model,
        'prompt': prompt,
        'size': resolved_size,
        'watermark': bool(watermark),
        'response_format': response_format,
    }
    if seed is not None:
        payload['seed'] = int(seed)
    if refs:
        encoded = [load_image_input(r) for r in refs]
        payload['image'] = encoded[0] if len(encoded) == 1 else encoded

    resp = client.request_json('POST', 'images/generations', payload)
    items = resp.get('data') or []
    if not isinstance(items, list) or not items:
        raise ArkToolError('方舟出图返回里缺少 data 结果项。')
    item = items[0]
    if not isinstance(item, dict):
        raise ArkToolError('方舟出图返回的 data[0] 格式异常。')

    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp_raw = None
    if green_key:
        if keep_raw:
            save_raw_to = _raw_path_for(out)
        else:
            tf = tempfile.NamedTemporaryFile(dir=out.parent, prefix='.ark_raw_', suffix='.png', delete=False)
            tf.close()
            tmp_raw = Path(tf.name)
            save_raw_to = tmp_raw
    else:
        save_raw_to = out

    try:
        if item.get('b64_json'):
            raw_bytes = base64.b64decode(item['b64_json'])
            save_raw_to.write_bytes(raw_bytes)
        elif item.get('url'):
            client.download_file(item['url'], save_raw_to)
        else:
            raise ArkToolError('方舟出图返回既没有 url 也没有 b64_json。')

        key_info = None
        if green_key:
            key_info = apply_green_key_image(save_raw_to, out, key_overrides=key_overrides)
    finally:
        if tmp_raw is not None and tmp_raw.exists():
            tmp_raw.unlink(missing_ok=True)

    result = {
        'mode': 'img2img' if refs else 'txt2img',
        'model': resp.get('model') or model,
        'size': item.get('size') or resolved_size,
        'watermark': bool(watermark),
        'refs_count': len(refs or []),
        'out': str(out),
        'raw_out': str(save_raw_to) if (green_key and keep_raw) else None,
        'green_key': key_info,
        'usage': resp.get('usage') or {},
    }
    _write_meta(meta_out, result, client._api_key)
    return result


def extract_video_url(task_resp):
    """兼容多种返回布局提取视频下载 URL。"""
    content = task_resp.get('content')
    if isinstance(content, dict):
        if content.get('video_url'):
            return content['video_url']
        if isinstance(content.get('video'), dict) and content['video'].get('url'):
            return content['video']['url']
    elif isinstance(content, list):
        for entry in content:
            if not isinstance(entry, dict):
                continue
            if entry.get('video_url'):
                return entry['video_url']
            if entry.get('type') == 'video_url' and isinstance(entry.get('video_url'), dict):
                if entry['video_url'].get('url'):
                    return entry['video_url']['url']
    if task_resp.get('video_url'):
        return task_resp['video_url']
    return None


def run_video_generation(
    client,
    *,
    model,
    prompt,
    first_frame,
    last_frame=None,
    refs=None,
    ratio='1:1',
    duration=4,
    resolution='720p',
    watermark=False,
    seed=None,
    generate_audio=None,
    return_last_frame=False,
    poll_interval=5.0,
    timeout=600.0,
    out_path,
    green_key=False,
    key_overrides=None,
    meta_out=None,
    sleep_fn=time.sleep,
    clock_fn=time.monotonic,
):
    content = []
    if prompt:
        content.append({'type': 'text', 'text': prompt})
    content.append({
        'type': 'image_url',
        'image_url': {'url': load_image_input(first_frame)},
        'role': 'first_frame',
    })
    if last_frame:
        content.append({
            'type': 'image_url',
            'image_url': {'url': load_image_input(last_frame)},
            'role': 'last_frame',
        })
    for r in (refs or []):
        content.append({
            'type': 'image_url',
            'image_url': {'url': load_image_input(r)},
            'role': 'reference_image',
        })

    payload = {
        'model': model,
        'content': content,
        'ratio': ratio,
        'duration': int(duration),
        'resolution': resolution,
        'watermark': bool(watermark),
    }
    if seed is not None:
        payload['seed'] = int(seed)
    if generate_audio is not None:
        payload['generate_audio'] = bool(generate_audio)
    if return_last_frame:
        payload['return_last_frame'] = True

    created = client.request_json('POST', 'contents/generations/tasks', payload)
    task_id = created.get('id') or created.get('task_id')
    if not task_id:
        raise ArkToolError('方舟建视频任务未返回任务 id。')

    print(f'已建视频任务 {task_id}，开始轮询（间隔 {poll_interval:g}s，超时 {timeout:g}s）…', file=sys.stderr)
    start_ts = clock_fn()
    deadline = start_ts + float(timeout)
    last_status = created.get('status') or 'queued'
    polls = 0
    final_resp = None

    while True:
        polls += 1
        task_resp = client.request_json('GET', f'contents/generations/tasks/{urllib.parse.quote(str(task_id), safe="")}')
        status = str(task_resp.get('status') or '').lower()
        last_status = status or last_status
        elapsed = clock_fn() - start_ts

        if status in SUCCESS_STATUSES:
            final_resp = task_resp
            break
        if status in FAILED_STATUSES:
            err = task_resp.get('error')
            if isinstance(err, dict):
                detail = f'{err.get("code", "")}: {err.get("message", "")}'.strip(': ')
            else:
                detail = str(err or '未知错误')
            raise ArkToolError(
                f'视频任务失败（id={task_id}，status={status}）：{redact_secret(detail, client._api_key)}'
            )
        if status and status not in PENDING_STATUSES:
            raise ArkToolError(f'视频任务返回未知状态（id={task_id}，status={status}）。')

        remaining = deadline - clock_fn()
        if remaining <= 0:
            raise ArkToolError(
                f'等待视频任务超时（id={task_id}，已等 {elapsed:.1f}s，最后状态 {last_status}）。'
            )
        print(f'  [{elapsed:.1f}s] 任务 {task_id} 状态：{last_status}', file=sys.stderr)
        sleep_fn(min(float(poll_interval), max(0.0, remaining)))

    video_url = extract_video_url(final_resp)
    if not video_url:
        raise ArkToolError(f'视频任务 {task_id} 已成功，但返回中缺少 video_url。')

    out = Path(out_path)
    client.download_file(video_url, out)

    key_info = None
    if green_key:
        key_info = apply_green_key_video(out, key_overrides=key_overrides)

    result = {
        'mode': 'img2vid',
        'task_id': task_id,
        'model': final_resp.get('model') or model,
        'ratio': ratio,
        'duration': int(duration),
        'resolution': resolution,
        'watermark': bool(watermark),
        'polls': polls,
        'elapsed_sec': round(clock_fn() - start_ts, 2),
        'out': str(out),
        'green_key': key_info,
        'usage': final_resp.get('usage') or {},
    }
    _write_meta(meta_out, result, client._api_key)
    return result


# ---------- 命令行解析 ----------

def _add_common_args(p):
    p.add_argument('--prompt', default='', help='提示词文本')
    p.add_argument('--prompt-file', default='', help='从 UTF-8 文本文件读取提示词')
    p.add_argument('--out', required=True, help='输出文件路径（图片 .png/.jpg 或视频 .mp4）')
    p.add_argument('--model', default='', help='模型 ID 或推理接入点 ID（不填用当前默认模型）')
    p.add_argument('--watermark', action='store_true', help='开启平台水印（默认关闭）')
    p.add_argument('--seed', type=int, default=None, help='随机种子（可选）')
    p.add_argument('--green-key', action='store_true', help='复用 muse转精灵.py 抠绿输出透明图（或透明帧目录）')
    p.add_argument('--key-threshold', type=int, default=None, help='抠绿阈值 g - max(r,b)，默认取 muse转精灵.py（60）')
    p.add_argument('--erode', type=int, default=None, help='前景收缩像素，默认取 muse转精灵.py（1）')
    p.add_argument('--despill-band', type=int, default=None, help='边缘去绿溢色带宽，默认取 muse转精灵.py（3）')
    p.add_argument('--no-keep-raw', action='store_true', help='开启 --green-key 时不保留原始绿底图（默认保留 *_raw）')
    p.add_argument('--meta-out', default='', help='可选：把本次参数与用量写入 JSON（自动脱敏）')
    p.add_argument('--base-url', default=DEFAULT_BASE_URL, help=f'方舟接口地址（默认 {DEFAULT_BASE_URL}）')
    p.add_argument('--keychain-service', default=KEYCHAIN_SERVICE, help=f'macOS 钥匙串服务名（默认 {KEYCHAIN_SERVICE}）')
    p.add_argument('--http-timeout', type=float, default=120.0, help='单次 HTTP 请求超时秒数（默认 120）')


def build_parser():
    parser = argparse.ArgumentParser(
        description='火山方舟（Seedream／Seedance）出图与出视频命令行工具。钥匙只从 macOS 钥匙串 ark-api-key 读取。',
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest='command', required=True)

    p_t2i = sub.add_parser('txt2img', aliases=['t2i', '文生图'], help='文生图（Seedream）')
    _add_common_args(p_t2i)
    p_t2i.add_argument('--size', default='1:1', help='尺寸或比例，默认 1:1（映射 2048x2048），也支持 WxH / 2K / 4K')
    p_t2i.add_argument('--response-format', choices=['url', 'b64_json'], default='url', help='返回格式（默认 url）')

    p_i2i = sub.add_parser('img2img', aliases=['i2i', '图生图'], help='图生图（Seedream，--ref 可多张）')
    _add_common_args(p_i2i)
    p_i2i.add_argument('--ref', action='append', required=True, help='本地参考图路径（或 URL），可重复传入多张')
    p_i2i.add_argument('--size', default='1:1', help='尺寸或比例，默认 1:1（映射 2048x2048），也支持 WxH / 2K / 4K')
    p_i2i.add_argument('--response-format', choices=['url', 'b64_json'], default='url', help='返回格式（默认 url）')

    p_i2v = sub.add_parser('img2vid', aliases=['i2v', '图生视频'], help='图生视频（Seedance，建任务后轮询并下载）')
    _add_common_args(p_i2v)
    p_i2v.add_argument('--first-frame', required=True, help='首帧本地图片路径（或 URL）')
    p_i2v.add_argument('--last-frame', default='', help='可选：尾帧本地图片路径（或 URL）')
    p_i2v.add_argument('--ref', action='append', default=[], help='可选：额外参考图，可重复传入')
    p_i2v.add_argument('--ratio', default='1:1', help='视频比例（默认 1:1，如 16:9 / 9:16 / adaptive）')
    p_i2v.add_argument('--duration', type=int, default=4, help='视频时长秒数（默认 4）')
    p_i2v.add_argument('--resolution', default='720p', help='分辨率（默认 720p，如 480p / 720p / 1080p）')
    p_i2v.add_argument('--generate-audio', dest='generate_audio', action='store_true', default=None, help='开启同步音效')
    p_i2v.add_argument('--no-audio', dest='generate_audio', action='store_false', help='关闭同步音效')
    p_i2v.add_argument('--return-last-frame', action='store_true', help='请求服务端返回尾帧')
    p_i2v.add_argument('--poll-interval', type=float, default=5.0, help='轮询间隔秒数（默认 5）')
    p_i2v.add_argument('--timeout', type=float, default=600.0, help='轮询总超时秒数（默认 600）')

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        prompt = resolve_prompt(args.prompt, args.prompt_file)
        api_key = read_api_key(args.keychain_service)
        client = ArkClient(api_key=api_key, base_url=args.base_url, http_timeout=args.http_timeout)
        key_overrides = {
            'key_threshold': args.key_threshold,
            'erode': args.erode,
            'despill_band': args.despill_band,
        }

        cmd = args.command
        if cmd in ('txt2img', 't2i', '文生图'):
            res = run_image_generation(
                client,
                model=args.model or DEFAULT_IMAGE_MODEL,
                prompt=prompt,
                size=args.size,
                watermark=args.watermark,
                refs=None,
                seed=args.seed,
                response_format=args.response_format,
                out_path=args.out,
                green_key=args.green_key,
                key_overrides=key_overrides,
                keep_raw=not args.no_keep_raw,
                meta_out=args.meta_out or None,
            )
        elif cmd in ('img2img', 'i2i', '图生图'):
            res = run_image_generation(
                client,
                model=args.model or DEFAULT_IMAGE_MODEL,
                prompt=prompt,
                size=args.size,
                watermark=args.watermark,
                refs=args.ref,
                seed=args.seed,
                response_format=args.response_format,
                out_path=args.out,
                green_key=args.green_key,
                key_overrides=key_overrides,
                keep_raw=not args.no_keep_raw,
                meta_out=args.meta_out or None,
            )
        elif cmd in ('img2vid', 'i2v', '图生视频'):
            res = run_video_generation(
                client,
                model=args.model or DEFAULT_VIDEO_MODEL,
                prompt=prompt,
                first_frame=args.first_frame,
                last_frame=args.last_frame or None,
                refs=args.ref,
                ratio=args.ratio,
                duration=args.duration,
                resolution=args.resolution,
                watermark=args.watermark,
                seed=args.seed,
                generate_audio=args.generate_audio,
                return_last_frame=args.return_last_frame,
                poll_interval=args.poll_interval,
                timeout=args.timeout,
                out_path=args.out,
                green_key=args.green_key,
                key_overrides=key_overrides,
                meta_out=args.meta_out or None,
            )
        else:
            raise ArkToolError(f'未知子命令：{cmd}', exit_code=2)

        print(redact_secret(json.dumps(res, ensure_ascii=False), api_key))
        return 0
    except ArkToolError as exc:
        print(f'错误：{exc}', file=sys.stderr)
        return exc.exit_code


if __name__ == '__main__':
    sys.exit(main())
