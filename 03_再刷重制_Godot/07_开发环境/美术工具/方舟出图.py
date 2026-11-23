#!/usr/bin/env python3
"""火山方舟（Volcengine Ark）出图与出视频命令行工具。

直接调用火山方舟 REST 接口（纯 Python 标准库，无第三方 MCP 依赖）：
- 文生图（txt2img / t2i / 文生图）：POST /api/v3/images/generations（Seedream）
- 图生图（img2img / i2i / 图生图）：POST /api/v3/images/generations（Seedream，--ref 支持多张本地图）
- 图生视频（img2vid / i2v / 图生视频）：POST / GET /api/v3/contents/generations/tasks（Seedance，轮询并下载；--first-frame 与 --ref 互斥）
- 视频续取（fetch / resume / 续取）：GET /api/v3/contents/generations/tasks/{task_id}（续轮询并下载，避免超时/断网重复扣费）
- 抠绿（--green-key）：按需复用同目录 muse转精灵.py 的 key_mask + despill（此时需 Pillow＋numpy）

【安全与格式校验】
- 钥匙只从 macOS 钥匙串读取，不读环境变量或 .env，不落盘，日志/报错/meta 自动打码。
- --base-url 仅放行 https://ark.cn-beijing.volces.com 与本地单测地址（127.0.0.1 / localhost），其余一律拒绝。
- 鉴权请求拒绝自动跟随 30x 重定向且使用 unredirected Authorization 头，防止密钥随跳转外泄。
- 不抠绿出图会按文件头魔数校验与 --out 扩展名是否一致（Seedream 5.x 自动请求对应 output_format）；不符时自动转格式（Pillow 或 macOS sips），无法转换则报错且不写入伪 PNG。

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
  python3 方舟出图.py fetch --task-id cgt-xxxx --out out/m5a.mp4
"""
import argparse
import base64
import http.client
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
ALLOWED_PROD_HOSTS = {'ark.cn-beijing.volces.com'}
ALLOWED_LOCAL_HOSTS = {'127.0.0.1', 'localhost'}
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

EXT_TO_IMAGE_FORMAT = {
    '.png': 'png',
    '.jpg': 'jpeg',
    '.jpeg': 'jpeg',
    '.webp': 'webp',
    '.gif': 'gif',
}
FORMAT_TO_EXT = {
    'png': '.png',
    'jpeg': '.jpg',
    'webp': '.webp',
    'gif': '.gif',
}
IMAGE_FORMAT_TO_MIME = {
    'png': 'image/png',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
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
_SEEDREAM_OUTPUT_FORMAT_RE = re.compile(r'seedream-[5-9]', re.IGNORECASE)


class ArkToolError(RuntimeError):
    """工具可预期错误（带明确退出码与可重试标记）。"""

    def __init__(self, message, exit_code=1, *, http_status=None, retryable=False):
        super().__init__(message)
        self.exit_code = exit_code
        self.http_status = http_status
        self.retryable = bool(retryable)


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


# ---------- 输入处理与校验 ----------

def detect_image_format(data):
    """严格按文件头魔数判断图片格式（不看扩展名）；无法识别返回 None。"""
    if not data:
        return None
    if data.startswith(b'\x89PNG\r\n\x1a\n'):
        return 'png'
    if data.startswith(b'\xff\xd8\xff'):
        return 'jpeg'
    if len(data) >= 12 and data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return 'webp'
    if data.startswith((b'GIF87a', b'GIF89a')):
        return 'gif'
    return None


def detect_image_mime(data, path):
    """优先按文件头魔数判断图片 MIME，退回扩展名。"""
    fmt = detect_image_format(data)
    if fmt:
        return IMAGE_FORMAT_TO_MIME[fmt]
    guessed, _ = mimetypes.guess_type(str(path))
    if guessed and guessed.startswith('image/'):
        return guessed
    return 'image/png'


def validate_base_url(base_url):
    """校验 --base-url：仅放行 https://ark.cn-beijing.volces.com 与本地单测地址（127.0.0.1 / localhost）。"""
    raw = (base_url or '').strip()
    if not raw:
        raise ArkToolError('--base-url 不能为空。', exit_code=2)
    try:
        parsed = urllib.parse.urlsplit(raw)
        port = parsed.port
    except ValueError as exc:
        raise ArkToolError(f'--base-url 格式非法：{raw}', exit_code=2) from exc

    scheme = (parsed.scheme or '').lower()
    host = (parsed.hostname or '').lower()
    if parsed.username is not None or parsed.password is not None:
        raise ArkToolError('--base-url 不允许包含用户名或密码字段。', exit_code=2)
    if parsed.query or parsed.fragment:
        raise ArkToolError('--base-url 不允许包含查询参数或锚点。', exit_code=2)

    if host in ALLOWED_PROD_HOSTS:
        if scheme != 'https' or (port is not None and port != 443):
            raise ArkToolError(
                f'--base-url 指向 {host} 时必须使用 https（默认 443 端口），已拒绝：{raw}',
                exit_code=2,
            )
        return raw.rstrip('/')

    if host in ALLOWED_LOCAL_HOSTS:
        if scheme not in ('http', 'https'):
            raise ArkToolError(f'--base-url 协议不受支持：{raw}', exit_code=2)
        return raw.rstrip('/')

    raise ArkToolError(
        f'为防止 API Key 外泄，--base-url 仅允许 https://ark.cn-beijing.volces.com '
        f'或本地单测地址（127.0.0.1 / localhost），已拒绝：{raw}',
        exit_code=2,
    )


def validate_video_inputs(first_frame, last_frame, refs):
    """校验 img2vid 输入：--first-frame 与 --ref 互斥，--last-frame 需配合 --first-frame。"""
    has_first = bool(first_frame)
    has_last = bool(last_frame)
    has_refs = bool(refs)
    if has_first and has_refs:
        raise ArkToolError(
            'img2vid 的 --first-frame 与 --ref 互斥（方舟接口不支持首帧图生视频与参考图生视频混用），请二选一。',
            exit_code=2,
        )
    if not has_first and not has_refs:
        raise ArkToolError('img2vid 必须提供 --first-frame 或 --ref（二者互斥）。', exit_code=2)
    if has_last and not has_first:
        raise ArkToolError('--last-frame 必须配合 --first-frame 使用，不能单独使用或与 --ref 混用。', exit_code=2)


def model_supports_output_format(model):
    """Seedream 5.x 起支持 output_format（png/jpeg）；4.x 传入会报 400。"""
    return bool(_SEEDREAM_OUTPUT_FORMAT_RE.search(model or ''))


def convert_image_file(src_path, dst_path, target_fmt):
    """尝试把本地图片转为目标格式（优先 Pillow，无 Pillow 时退回 macOS sips）。返回 (成功, 方式或失败原因)。"""
    pil_formats = {'png': 'PNG', 'jpeg': 'JPEG', 'webp': 'WEBP', 'gif': 'GIF'}
    if target_fmt not in pil_formats:
        return False, f'不支持转换到目标格式 {target_fmt}'

    pil_err = None
    try:
        from PIL import Image
        with Image.open(src_path) as im:
            if target_fmt == 'jpeg' and im.mode not in ('RGB', 'L'):
                im = im.convert('RGB')
            im.save(dst_path, format=pil_formats[target_fmt])
        if Path(dst_path).is_file() and detect_image_format(Path(dst_path).read_bytes()[:16]) == target_fmt:
            return True, 'Pillow'
        return False, 'Pillow 转换结果魔数不符'
    except ModuleNotFoundError:
        pil_err = '未安装 Pillow'
    except Exception as exc:
        pil_err = f'Pillow 转换失败：{exc}'

    sips_path = Path('/usr/bin/sips')
    if sips_path.is_file() and target_fmt in ('png', 'jpeg', 'gif'):
        try:
            proc = subprocess.run(
                [str(sips_path), '-s', 'format', target_fmt, str(src_path), '--out', str(dst_path)],
                capture_output=True,
                text=True,
                check=False,
            )
            if proc.returncode == 0 and Path(dst_path).is_file():
                if detect_image_format(Path(dst_path).read_bytes()[:16]) == target_fmt:
                    return True, 'sips'
            sips_msg = (proc.stderr or proc.stdout or '').strip().splitlines()
            detail = sips_msg[-1] if sips_msg else f'退出码 {proc.returncode}'
            return False, f'{pil_err}；sips 转换失败（{detail}）'
        except OSError as exc:
            return False, f'{pil_err}；调用 sips 失败（{exc}）'

    return False, pil_err or '缺少可用图片转换工具'


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

class _NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    """鉴权请求拒绝自动跟随 30x 重定向，防止 API Key 外泄到跳转主机。"""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class ArkClient:
    """火山方舟 REST 客户端（纯 urllib，禁重定向、限域校验、报错自动打码）。"""

    def __init__(self, api_key, base_url=DEFAULT_BASE_URL, http_timeout=120.0):
        self._api_key = api_key
        self.base_url = validate_base_url(base_url)
        self.http_timeout = float(http_timeout)
        self._api_opener = urllib.request.build_opener(_NoRedirectHandler())

    def _safe(self, text):
        return redact_secret(text, self._api_key)

    def request_json(self, method, path, payload=None):
        url = f'{self.base_url}/{path.lstrip("/")}'
        body = None
        headers = {
            'Accept': 'application/json',
        }
        if payload is not None:
            body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
            headers['Content-Type'] = 'application/json'

        req = urllib.request.Request(url, data=body, headers=headers, method=method.upper())
        # 双重防护：既用 unredirected 头避免重定向携带，也用 _NoRedirectHandler 拒绝跟随 30x
        req.add_unredirected_header('Authorization', f'Bearer {self._api_key}')
        try:
            with self._api_opener.open(req, timeout=self.http_timeout) as resp:
                raw = resp.read().decode('utf-8', errors='replace')
        except urllib.error.HTTPError as exc:
            if 300 <= exc.code < 400:
                location = exc.headers.get('Location', '') if exc.headers else ''
                loc_part = f' -> {self._safe(location)}' if location else ''
                raise ArkToolError(
                    f'方舟接口返回重定向 HTTP {exc.code}（{method.upper()} {path}{loc_part}），'
                    f'为防止 API Key 外泄已拒绝自动跟随。',
                    http_status=exc.code,
                    retryable=False,
                ) from exc
            err_body = ''
            try:
                err_body = exc.read().decode('utf-8', errors='replace')
            except Exception:
                err_body = ''
            detail = self._extract_error_detail(err_body)
            is_retryable = exc.code == 429 or 500 <= exc.code < 600
            raise ArkToolError(
                f'方舟接口返回 HTTP {exc.code}（{method.upper()} {path}）：{self._safe(detail)}',
                http_status=exc.code,
                retryable=is_retryable,
            ) from exc
        except urllib.error.URLError as exc:
            raise ArkToolError(
                f'连接方舟接口失败（{method.upper()} {path}）：{self._safe(exc.reason)}',
                retryable=True,
            ) from exc
        except TimeoutError as exc:
            raise ArkToolError(
                f'请求方舟接口超时（{method.upper()} {path}，超时 {self.http_timeout:g}s）。',
                retryable=True,
            ) from exc
        except (http.client.HTTPException, OSError) as exc:
            raise ArkToolError(
                f'请求方舟接口网络异常（{method.upper()} {path}）：{self._safe(exc)}',
                retryable=True,
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
        scheme = (urllib.parse.urlsplit(url).scheme or '').lower()
        if scheme not in ('http', 'https'):
            raise ArkToolError(f'拒绝下载非 http/https 链接（URL：{self._safe(url)}）。')
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

def _raw_path_for(out_path, actual_fmt=None):
    p = Path(out_path)
    if actual_fmt and actual_fmt in FORMAT_TO_EXT:
        suffix = FORMAT_TO_EXT[actual_fmt]
    else:
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
    output_format='auto',
    out_path,
    green_key=False,
    key_overrides=None,
    keep_raw=True,
    meta_out=None,
):
    out = Path(out_path)
    if green_key and out.suffix.lower() in ('.jpg', '.jpeg'):
        raise ArkToolError('--green-key 会输出透明 PNG，请将 --out 扩展名改为 .png。', exit_code=2)

    resolved_size = resolve_size(size)
    payload = {
        'model': model,
        'prompt': prompt,
        'size': resolved_size,
        'watermark': bool(watermark),
        'response_format': response_format,
    }
    req_output_format = None
    if output_format in ('png', 'jpeg'):
        req_output_format = output_format
    elif output_format == 'auto' and model_supports_output_format(model):
        if green_key or out.suffix.lower() == '.png':
            req_output_format = 'png'
        elif out.suffix.lower() in ('.jpg', '.jpeg'):
            req_output_format = 'jpeg'
    if req_output_format:
        payload['output_format'] = req_output_format

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

    out.parent.mkdir(parents=True, exist_ok=True)
    tf = tempfile.NamedTemporaryFile(dir=out.parent, prefix='.ark_img_', suffix='.tmp', delete=False)
    tf.close()
    tmp_dl = Path(tf.name)
    tmp_conv = None
    raw_saved_path = None
    converted_from = None
    final_fmt = None

    try:
        if item.get('b64_json'):
            raw_bytes = base64.b64decode(item['b64_json'])
            if not raw_bytes:
                raise ArkToolError('方舟出图返回的 b64_json 解码为空。')
            tmp_dl.write_bytes(raw_bytes)
        elif item.get('url'):
            client.download_file(item['url'], tmp_dl)
        else:
            raise ArkToolError('方舟出图返回既没有 url 也没有 b64_json。')

        with tmp_dl.open('rb') as fh:
            header = fh.read(16)
        actual_fmt = detect_image_format(header)
        if actual_fmt is None:
            raise ArkToolError(f'接口返回的内容不是可识别的图片格式（未写入 {out}）。')

        key_info = None
        if green_key:
            if keep_raw:
                raw_saved_path = _raw_path_for(out, actual_fmt)
                tmp_dl.replace(raw_saved_path)
                tmp_dl = None
                source_for_key = raw_saved_path
            else:
                source_for_key = tmp_dl
            key_info = apply_green_key_image(source_for_key, out, key_overrides=key_overrides)
            final_fmt = 'png'
        else:
            target_fmt = EXT_TO_IMAGE_FORMAT.get(out.suffix.lower())
            if target_fmt is None or actual_fmt == target_fmt:
                tmp_dl.replace(out)
                tmp_dl = None
                final_fmt = actual_fmt
            else:
                cf = tempfile.NamedTemporaryFile(
                    dir=out.parent,
                    prefix='.ark_conv_',
                    suffix=FORMAT_TO_EXT.get(target_fmt, '.tmp'),
                    delete=False,
                )
                cf.close()
                tmp_conv = Path(cf.name)
                ok, info = convert_image_file(tmp_dl, tmp_conv, target_fmt)
                if ok:
                    tmp_conv.replace(out)
                    tmp_conv = None
                    converted_from = actual_fmt
                    final_fmt = target_fmt
                    print(
                        f'注意：接口实际返回 {actual_fmt} 图片，已通过 {info} 自动转为 {target_fmt} 写入 {out}。',
                        file=sys.stderr,
                    )
                else:
                    actual_ext = FORMAT_TO_EXT.get(actual_fmt, f'.{actual_fmt}')
                    raise ArkToolError(
                        f'图片格式与目标扩展名不符：接口实际返回 {actual_fmt}，但 --out 指定为 {out.suffix}'
                        f'（直接保存伪 {out.suffix} 会导致 Godot 导入失败），且当前环境无法自动转格式（{info}）。'
                        f'请改用 --out {out.with_suffix(actual_ext)} 或安装 Pillow 后重试。'
                    )
    finally:
        if tmp_dl is not None and tmp_dl.exists():
            tmp_dl.unlink(missing_ok=True)
        if tmp_conv is not None and tmp_conv.exists():
            tmp_conv.unlink(missing_ok=True)

    result = {
        'mode': 'img2img' if refs else 'txt2img',
        'model': resp.get('model') or model,
        'size': item.get('size') or resolved_size,
        'watermark': bool(watermark),
        'refs_count': len(refs or []),
        'out': str(out),
        'image_format': final_fmt,
        'converted_from': converted_from,
        'raw_out': str(raw_saved_path) if raw_saved_path else None,
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


def poll_and_download_video_task(
    client,
    *,
    task_id,
    out_path,
    mode='img2vid',
    model='',
    ratio=None,
    duration=None,
    resolution=None,
    watermark=None,
    poll_interval=5.0,
    timeout=600.0,
    poll_retries=3,
    green_key=False,
    key_overrides=None,
    meta_out=None,
    initial_status='queued',
    sleep_fn=time.sleep,
    clock_fn=time.monotonic,
):
    """轮询视频任务直至完成并下载结果；遇 5xx / 网络临时错误按 poll_retries 连续重试。"""
    tid = str(task_id or '').strip()
    if not tid:
        raise ArkToolError('--task-id 不能为空。', exit_code=2)

    max_retries = max(0, int(poll_retries))
    start_ts = clock_fn()
    deadline = start_ts + float(timeout)
    last_status = initial_status or 'queued'
    polls = 0
    consecutive_errors = 0
    retry_errors_total = 0
    final_resp = None
    resume_cmd = f'python3 方舟出图.py fetch --task-id {tid} --out {out_path}'

    while True:
        polls += 1
        try:
            task_resp = client.request_json(
                'GET', f'contents/generations/tasks/{urllib.parse.quote(tid, safe="")}'
            )
            consecutive_errors = 0
        except ArkToolError as exc:
            if not exc.retryable:
                raise
            consecutive_errors += 1
            retry_errors_total += 1
            elapsed = clock_fn() - start_ts
            remaining = deadline - clock_fn()
            if consecutive_errors > max_retries:
                raise ArkToolError(
                    f'轮询视频任务 {tid} 连续 {consecutive_errors} 次遇临时错误（最后错误：{exc}）。\n'
                    f'服务端任务可能仍在运行或已完成，可用以下命令续取结果避免重复扣费：\n  {resume_cmd}'
                ) from exc
            if remaining <= 0:
                raise ArkToolError(
                    f'等待视频任务超时（id={tid}，已等 {elapsed:.1f}s，最后遇临时错误：{exc}）。\n'
                    f'可用以下命令续取结果：\n  {resume_cmd}'
                ) from exc
            print(
                f'  [{elapsed:.1f}s] 任务 {tid} 轮询遇临时错误（第 {consecutive_errors}/{max_retries} 次重试）：{exc}',
                file=sys.stderr,
            )
            sleep_fn(min(float(poll_interval), max(0.0, remaining)))
            continue

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
                f'视频任务失败（id={tid}，status={status}）：{redact_secret(detail, client._api_key)}'
            )
        if status and status not in PENDING_STATUSES:
            raise ArkToolError(f'视频任务返回未知状态（id={tid}，status={status}）。')

        remaining = deadline - clock_fn()
        if remaining <= 0:
            raise ArkToolError(
                f'等待视频任务超时（id={tid}，已等 {elapsed:.1f}s，最后状态 {last_status}）。\n'
                f'可用以下命令续取结果避免重复扣费：\n  {resume_cmd}'
            )
        print(f'  [{elapsed:.1f}s] 任务 {tid} 状态：{last_status}', file=sys.stderr)
        sleep_fn(min(float(poll_interval), max(0.0, remaining)))

    video_url = extract_video_url(final_resp)
    if not video_url:
        raise ArkToolError(f'视频任务 {tid} 已成功，但返回中缺少 video_url。')

    out = Path(out_path)
    client.download_file(video_url, out)

    key_info = None
    if green_key:
        key_info = apply_green_key_video(out, key_overrides=key_overrides)

    result = {
        'mode': mode,
        'task_id': tid,
        'model': final_resp.get('model') or model,
        'polls': polls,
        'poll_retries_used': retry_errors_total,
        'elapsed_sec': round(clock_fn() - start_ts, 2),
        'out': str(out),
        'green_key': key_info,
        'usage': final_resp.get('usage') or {},
    }
    if ratio is not None:
        result['ratio'] = ratio
    if duration is not None:
        result['duration'] = int(duration)
    if resolution is not None:
        result['resolution'] = resolution
    if watermark is not None:
        result['watermark'] = bool(watermark)

    _write_meta(meta_out, result, client._api_key)
    return result


def run_video_generation(
    client,
    *,
    model,
    prompt,
    first_frame=None,
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
    poll_retries=3,
    out_path,
    green_key=False,
    key_overrides=None,
    meta_out=None,
    sleep_fn=time.sleep,
    clock_fn=time.monotonic,
):
    validate_video_inputs(first_frame, last_frame, refs)

    content = []
    if prompt:
        content.append({'type': 'text', 'text': prompt})
    if first_frame:
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
    else:
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
    return poll_and_download_video_task(
        client,
        task_id=task_id,
        out_path=out_path,
        mode='img2vid',
        model=model,
        ratio=ratio,
        duration=duration,
        resolution=resolution,
        watermark=watermark,
        poll_interval=poll_interval,
        timeout=timeout,
        poll_retries=poll_retries,
        green_key=green_key,
        key_overrides=key_overrides,
        meta_out=meta_out,
        initial_status=created.get('status') or 'queued',
        sleep_fn=sleep_fn,
        clock_fn=clock_fn,
    )


def run_video_fetch(
    client,
    *,
    task_id,
    out_path,
    poll_interval=5.0,
    timeout=600.0,
    poll_retries=3,
    green_key=False,
    key_overrides=None,
    meta_out=None,
    sleep_fn=time.sleep,
    clock_fn=time.monotonic,
):
    print(f'开始续取视频任务 {task_id}（间隔 {poll_interval:g}s，超时 {timeout:g}s）…', file=sys.stderr)
    return poll_and_download_video_task(
        client,
        task_id=task_id,
        out_path=out_path,
        mode='fetch',
        poll_interval=poll_interval,
        timeout=timeout,
        poll_retries=poll_retries,
        green_key=green_key,
        key_overrides=key_overrides,
        meta_out=meta_out,
        sleep_fn=sleep_fn,
        clock_fn=clock_fn,
    )


# ---------- 命令行解析 ----------

def _add_runtime_args(p):
    p.add_argument('--out', required=True, help='输出文件路径（图片 .png/.jpg 或视频 .mp4）')
    p.add_argument('--green-key', action='store_true', help='复用 muse转精灵.py 抠绿输出透明图（或透明帧目录）')
    p.add_argument('--key-threshold', type=int, default=None, help='抠绿阈值 g - max(r,b)，默认取 muse转精灵.py（60）')
    p.add_argument('--erode', type=int, default=None, help='前景收缩像素，默认取 muse转精灵.py（1）')
    p.add_argument('--despill-band', type=int, default=None, help='边缘去绿溢色带宽，默认取 muse转精灵.py（3）')
    p.add_argument('--meta-out', default='', help='可选：把本次参数与用量写入 JSON（自动脱敏）')
    p.add_argument(
        '--base-url',
        default=DEFAULT_BASE_URL,
        help=f'方舟接口地址（仅放行 https://ark.cn-beijing.volces.com 与 127.0.0.1/localhost；默认 {DEFAULT_BASE_URL}）',
    )
    p.add_argument('--keychain-service', default=KEYCHAIN_SERVICE, help=f'macOS 钥匙串服务名（默认 {KEYCHAIN_SERVICE}）')
    p.add_argument('--http-timeout', type=float, default=120.0, help='单次 HTTP 请求超时秒数（默认 120）')


def _add_common_args(p):
    p.add_argument('--prompt', default='', help='提示词文本')
    p.add_argument('--prompt-file', default='', help='从 UTF-8 文本文件读取提示词')
    p.add_argument('--model', default='', help='模型 ID 或推理接入点 ID（不填用当前默认模型）')
    p.add_argument('--watermark', action='store_true', help='开启平台水印（默认关闭）')
    p.add_argument('--seed', type=int, default=None, help='随机种子（可选）')
    p.add_argument('--no-keep-raw', action='store_true', help='开启 --green-key 时不保留原始绿底图（默认保留 *_raw）')
    _add_runtime_args(p)


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
    p_t2i.add_argument('--output-format', choices=['auto', 'png', 'jpeg'], default='auto', help='向支持该参数的 Seedream 5.x 模型请求的文件格式（默认 auto：按 --out 扩展名决定）')

    p_i2i = sub.add_parser('img2img', aliases=['i2i', '图生图'], help='图生图（Seedream，--ref 可多张）')
    _add_common_args(p_i2i)
    p_i2i.add_argument('--ref', action='append', required=True, help='本地参考图路径（或 URL），可重复传入多张')
    p_i2i.add_argument('--size', default='1:1', help='尺寸或比例，默认 1:1（映射 2048x2048），也支持 WxH / 2K / 4K')
    p_i2i.add_argument('--response-format', choices=['url', 'b64_json'], default='url', help='返回格式（默认 url）')
    p_i2i.add_argument('--output-format', choices=['auto', 'png', 'jpeg'], default='auto', help='向支持该参数的 Seedream 5.x 模型请求的文件格式（默认 auto：按 --out 扩展名决定）')

    p_i2v = sub.add_parser('img2vid', aliases=['i2v', '图生视频'], help='图生视频（Seedance，建任务后轮询并下载；--first-frame 与 --ref 互斥）')
    _add_common_args(p_i2v)
    p_i2v.add_argument('--first-frame', default='', help='首帧本地图片路径（或 URL）；与 --ref 互斥')
    p_i2v.add_argument('--last-frame', default='', help='可选：尾帧本地图片路径（或 URL），需配合 --first-frame 使用')
    p_i2v.add_argument('--ref', action='append', default=[], help='参考图路径（或 URL），可重复传入；与 --first-frame 互斥')
    p_i2v.add_argument('--ratio', default='1:1', help='视频比例（默认 1:1，如 16:9 / 9:16 / adaptive）')
    p_i2v.add_argument('--duration', type=int, default=4, help='视频时长秒数（默认 4）')
    p_i2v.add_argument('--resolution', default='720p', help='分辨率（默认 720p，如 480p / 720p / 1080p）')
    p_i2v.add_argument('--generate-audio', dest='generate_audio', action='store_true', default=None, help='开启同步音效')
    p_i2v.add_argument('--no-audio', dest='generate_audio', action='store_false', help='关闭同步音效')
    p_i2v.add_argument('--return-last-frame', action='store_true', help='请求服务端返回尾帧')
    p_i2v.add_argument('--poll-interval', type=float, default=5.0, help='轮询间隔秒数（默认 5）')
    p_i2v.add_argument('--timeout', type=float, default=600.0, help='轮询总超时秒数（默认 600）')
    p_i2v.add_argument('--poll-retries', type=int, default=3, help='轮询遇 5xx／网络错误的连续重试次数（默认 3）')

    p_fetch = sub.add_parser('fetch', aliases=['resume', '续取'], help='按 --task-id 续轮询并下载已有视频任务，避免重复扣费')
    p_fetch.add_argument('--task-id', required=True, help='已创建的视频任务 ID（如 cgt-xxxx）')
    p_fetch.add_argument('--poll-interval', type=float, default=5.0, help='轮询间隔秒数（默认 5）')
    p_fetch.add_argument('--timeout', type=float, default=600.0, help='轮询总超时秒数（默认 600）')
    p_fetch.add_argument('--poll-retries', type=int, default=3, help='轮询遇 5xx／网络错误的连续重试次数（默认 3）')
    _add_runtime_args(p_fetch)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        validated_base_url = validate_base_url(args.base_url)
        cmd = args.command
        prompt = None
        if cmd in ('txt2img', 't2i', '文生图', 'img2img', 'i2i', '图生图', 'img2vid', 'i2v', '图生视频'):
            prompt = resolve_prompt(args.prompt, args.prompt_file)
        if cmd in ('img2vid', 'i2v', '图生视频'):
            validate_video_inputs(args.first_frame, args.last_frame, args.ref)
        elif cmd in ('fetch', 'resume', '续取'):
            if not (args.task_id or '').strip():
                raise ArkToolError('--task-id 不能为空。', exit_code=2)

        api_key = read_api_key(args.keychain_service)
        client = ArkClient(api_key=api_key, base_url=validated_base_url, http_timeout=args.http_timeout)
        key_overrides = {
            'key_threshold': args.key_threshold,
            'erode': args.erode,
            'despill_band': args.despill_band,
        }

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
                output_format=args.output_format,
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
                output_format=args.output_format,
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
                first_frame=args.first_frame or None,
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
                poll_retries=args.poll_retries,
                out_path=args.out,
                green_key=args.green_key,
                key_overrides=key_overrides,
                meta_out=args.meta_out or None,
            )
        elif cmd in ('fetch', 'resume', '续取'):
            res = run_video_fetch(
                client,
                task_id=args.task_id,
                out_path=args.out,
                poll_interval=args.poll_interval,
                timeout=args.timeout,
                poll_retries=args.poll_retries,
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
