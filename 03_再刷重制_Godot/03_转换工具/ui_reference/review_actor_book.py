#!/usr/bin/env python3
"""只读人物图鉴截图与取数夹具；沿用 serve.py 守卫，使用独立端口/输出目录。"""
import argparse
import functools
import hashlib
import json
from pathlib import Path
import serve


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    source = args.source.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    serve.SHOTS = str(args.out.resolve())
    inputs = ["index.html", "js/plugins.js", "js/rpg_sprites.js", "js/rpg_windows.js", "js/rpg_οbjects.js",
              "js/plugins/Star_ActorsBook.js", "js/plugins/Codex_ActorBookSkillDetails.js",
              "js/plugins/Star_ActorAdvanced.js", "data/Actors.json", "data/Classes.json", "data/Skills.json"]
    identity = {p: hashlib.sha256((source / p).read_bytes()).hexdigest() for p in inputs}
    (args.out / "source_before.json").write_text(json.dumps(identity, indent=2) + "\n")

    class Handler(serve.H):
        def do_GET(self):
            if self.path.split("?", 1)[0] == "/js/mac-preload.js" and self.allowed():
                body = Path(serve.SHIM).read_bytes() + b"\n" + Path(__file__).with_suffix(".js").read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "application/javascript")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            super().do_GET()

    serve.http.server.ThreadingHTTPServer.request_queue_size = 256
    server = serve.http.server.ThreadingHTTPServer(
        ("127.0.0.1", args.port), functools.partial(Handler, directory=str(source)))
    print(f"只读原版参照 127.0.0.1:{args.port}；?battle_ref=1&actor_book_review=1", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        after = {p: hashlib.sha256((source / p).read_bytes()).hexdigest() for p in inputs}
        (args.out / "source_after.json").write_text(json.dumps(after, indent=2) + "\n")
        if after != identity:
            raise RuntimeError("参照来源身份发生变化")


if __name__ == "__main__":
    main()
