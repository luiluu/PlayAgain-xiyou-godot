"""原版界面参照服务器（只读）：把正式西游 app.nw 以 GET 提供给浏览器；拒绝 save/ 与任何写请求。"""
import http.server, functools, sys
APP = sys.argv[1]
# 截图输出：第二个参数，默认 04_验证/本地结果/原版参照（不入 Git）
SHOTS = sys.argv[2] if len(sys.argv) > 2 else __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), '..', '..', '04_验证', '本地结果', '原版参照')
import os
SHIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mac-preload-shim.js')
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        p = self.path.split('?')[0].lower()
        import urllib.parse; segs = urllib.parse.unquote(p).split('/')
        if p.startswith('/save') or '..' in segs:
            self.send_error(403); return
        if p == '/js/mac-preload.js':
            body = open(SHIM, 'rb').read()
            self.send_response(200); self.send_header('Content-Type', 'application/javascript'); self.send_header('Content-Length', str(len(body))); self.end_headers()
            self.wfile.write(body); return
        return super().do_GET()
    def do_HEAD(self): self.do_GET()
    def do_POST(self):
        # 只接受参照截图：写到本脚本旁的 shots/，文件名只允许字母数字下划线
        import re, base64
        m = re.fullmatch(r'/__ref_shot/([A-Za-z0-9_]+)', self.path)
        if not m:
            self.send_error(405); return
        n = int(self.headers.get('Content-Length', 0))
        data = self.rfile.read(n).decode()
        png = base64.b64decode(data.split(',', 1)[1])
        out = os.path.join(SHOTS, m.group(1) + '.png')
        open(out, 'wb').write(png)
        self.send_response(200); self.end_headers()
    def do_PUT(self): self.send_error(405)
    do_DELETE = do_PUT
    def log_message(self, *a): pass
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()
http.server.ThreadingHTTPServer.request_queue_size = 256
http.server.ThreadingHTTPServer(('127.0.0.1', 8766), functools.partial(H, directory=APP)).serve_forever()
