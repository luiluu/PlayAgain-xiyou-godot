#!/usr/bin/env python3
"""待审菜单的内存重放与截图。沿用 serve.H 的来源/存档守卫，仅写指定证据目录。"""
import argparse
import functools
import hashlib
import json
from pathlib import Path
import serve


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source', type=Path)
    ap.add_argument('out', type=Path)
    ap.add_argument('--port', type=int, default=8788)
    args = ap.parse_args()
    source = args.source.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    serve.SHOTS = str(args.out.resolve())
    fixtures = Path(__file__).resolve().parents[2] / '01_Godot工程/tests/fixtures'
    config = {n: json.loads((fixtures / (n + '_oracle.json')).read_text()) for n in ['crafting', 'pet', 'pet_synth']}
    inputs = ['index.html', 'js/plugins.js', 'js/plugins/hc.js', 'js/plugins/CP_MagicWeapon.js',
              'js/plugins/Star_PetSystem.js', 'js/plugins/Star_PetSynthesis.js', 'js/plugins/Star_PetUpLevel.js',
              'js/codex/runtime/installNativeRaceRuntime.js', 'data/Recipes.txt', 'data/Enemies.json']
    identity = lambda: {p: hashlib.sha256((source / p).read_bytes()).hexdigest() for p in inputs}
    before = identity()
    (args.out / 'source_before.json').write_text(json.dumps(before, indent=2) + '\n')

    class Handler(serve.H):
        def do_GET(self):
            if self.path.split('?', 1)[0] == '/js/mac-preload.js' and self.allowed():
                body = (Path(serve.SHIM).read_bytes() + b'\nwindow.__reviewMenuConfig=' +
                        json.dumps(config, ensure_ascii=False).encode() + b';\n' + Path(__file__).with_suffix('.js').read_bytes())
                self.send_response(200)
                self.send_header('Content-Type', 'application/javascript; charset=utf-8')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            super().do_GET()

    serve.http.server.ThreadingHTTPServer.request_queue_size = 256
    server = serve.http.server.ThreadingHTTPServer(('127.0.0.1', args.port), functools.partial(Handler, directory=str(source)))
    print(f'待审菜单只读参照：http://127.0.0.1:{args.port}/index.html?battle_ref=1&pending_review=1', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        after = identity()
        (args.out / 'source_after.json').write_text(json.dumps(after, indent=2) + '\n')
        if after != before:
            raise RuntimeError('参照来源身份改变')


if __name__ == '__main__':
    main()
