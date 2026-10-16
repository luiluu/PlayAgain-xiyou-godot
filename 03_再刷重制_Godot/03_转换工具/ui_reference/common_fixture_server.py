"""只读冻结源的共性UI夹具；只绑定回环地址，内存新局，截图写独立输出目录。"""
import argparse
import functools
import http.server
import importlib.util
from pathlib import Path
import urllib.parse

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--port', type=int, default=8794)
ap.add_argument('--out', type=Path, required=True)
a = ap.parse_args()
spec = importlib.util.spec_from_file_location('reference_serve', HERE / 'serve.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
a.out.mkdir(parents=True, exist_ok=True)
module.SHOTS = str(a.out)


class Handler(module.H):
    def do_GET(self):
        request = urllib.parse.urlsplit(self.path).path
        if request == '/js/mac-preload.js' and self.allowed():
            data = (HERE / 'mac-preload-shim.js').read_bytes() + b'\n' + (HERE / 'common-ui-fixture.js').read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'application/javascript')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            super().do_GET()


app = ROOT / '02_内容与素材/冻结正式源/app.nw'
http.server.ThreadingHTTPServer.request_queue_size = 256
http.server.ThreadingHTTPServer(('127.0.0.1', a.port), functools.partial(Handler, directory=str(app))).serve_forever()
