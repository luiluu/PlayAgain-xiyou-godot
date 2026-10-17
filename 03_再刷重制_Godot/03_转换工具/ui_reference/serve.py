"""原版界面参照服务器（只读）：把正式西游 app.nw 以 GET 提供给浏览器；拒绝 save/ 与任何写请求。"""
import http.server, functools, sys
from pathlib import Path
import urllib.parse
# 截图输出：第二个参数，默认 04_验证/本地结果/原版参照（不入 Git）
SHOTS = __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', '..', '04_验证', '本地结果', '原版参照')
import os
SHIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mac-preload-shim.js')
class H(http.server.SimpleHTTPRequestHandler):
    def allowed(self):
        # 在解码后检查存档与作者钥匙；实际文件必须在来源目录内（防符号链接逸出）。
        import re
        p = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
        segs = p.lower().split('/')
        if any(s in {'..', 'save', 'saves', 'app_userdata', 'application support'} or 'codex_author_key' in s for s in segs):
            return False
        if re.search(r'\.(rpgsave|sav|save)(\.|$)', segs[-1]):
            return False
        actual = Path(self.translate_path(self.path)).resolve()
        if any(s.lower() in {'save', 'saves', 'app_userdata', 'application support'} or 'codex_author_key' in s.lower() for s in actual.parts):
            return False
        return actual.is_relative_to(Path(self.directory).resolve())

    def do_GET(self):
        p = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path).lower()
        if not self.allowed():
            self.send_error(403); return
        if p == '/js/mac-preload.js':
            body = open(SHIM, 'rb').read()
            self.send_response(200); self.send_header('Content-Type', 'application/javascript'); self.send_header('Content-Length', str(len(body))); self.end_headers()
            self.wfile.write(body); return
        return super().do_GET()
    def do_HEAD(self):
        if not self.allowed():
            self.send_error(403); return
        return super().do_HEAD()
    def do_POST(self):
        # 只接受参照截图（PNG）与运行时读数（JSON）：写到截图目录，文件名只允许字母数字下划线
        import re, base64, json
        m = re.fullmatch(r'/__ref_(shot|json)/([A-Za-z0-9_]+)', self.path)
        if not m:
            self.send_error(405); return
        n = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(n).decode()
        if m.group(1) == 'shot':
            open(os.path.join(SHOTS, m.group(2) + '.png'), 'wb').write(base64.b64decode(data.split(',', 1)[1]))
        else:
            json.loads(data)
            open(os.path.join(SHOTS, m.group(2) + '.json'), 'w', encoding='utf-8').write(data)
        self.send_response(200); self.end_headers()
    def do_PUT(self): self.send_error(405)
    do_DELETE = do_PUT
    def log_message(self, *a): pass
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()
if __name__ == '__main__':
    APP = sys.argv[1]
    if len(sys.argv) > 2:
        SHOTS = sys.argv[2]
    os.makedirs(SHOTS, exist_ok=True)
    http.server.ThreadingHTTPServer.request_queue_size = 256
    http.server.ThreadingHTTPServer(('127.0.0.1', 8766), functools.partial(H, directory=APP)).serve_forever()
