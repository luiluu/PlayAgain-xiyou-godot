#!/usr/bin/env python3
"""只读系统页成对截图服务（八戒_63）：沿用 serve.py 守卫，独立端口/输出目录，追加 review_system_pages.js。

用法：python3 review_system_pages.py <冻结 app.nw> <输出目录> [--port 8769]；
再用 node review_system_pages.cjs <输出目录> 驱动无头 Chrome 逐页重放、截图与取数。"""
import argparse
import functools
import hashlib
import json
from pathlib import Path
import signal
import serve

INPUTS = ["index.html", "js/plugins.js", "js/rpg_scenes.js", "js/rpg_windows.js", "js/rpg_οbjects.js",
          "js/plugins/hc.js", "js/plugins/CP_MagicWeapon.js", "js/plugins/Star_PetSystem.js",
          "js/plugins/Star_PetUpLevel.js", "js/plugins/Star_PetSynthesis.js",
          "js/codex/runtime/installNativeRaceRuntime.js", "js/codex/runtime/installNativeYunshangRuntime.js",
          "js/codex/runtime/installNativeBindingChargeRuntime.js",
          "js/codex/runtime/installAlienationWorkshop.js", "js/codex/runtime/installAlienationAffixes.js",
          "js/codex/runtime/installGamePanelTheme.js", "js/codex/runtime/installCombatPowerRuntime.js",
          "js/plugins/AB_EnemyBook.js", "js/plugins/Star_EquipInlayBook.js", "js/plugins/Star_EquipmentMosaic.js", "js/plugins/PH_Warehouse.js", "js/plugins/Star_ActorWarehouse.js", "js/plugins/EliteEnemy.js", "js/plugins/EnemyNameColorByDifficulty.js"]


def identity(source):
    return {p: hashlib.sha256((source / p).read_bytes()).hexdigest() for p in INPUTS}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--port", type=int, default=8769)
    args = parser.parse_args()
    source = args.source.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    serve.SHOTS = str(args.out.resolve())
    before = identity(source)
    (args.out / "source_before.json").write_text(json.dumps(before, indent=2) + "\n")

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
    print(f"只读原版参照 127.0.0.1:{args.port}；?item_list_ref=1&sys_review=1", flush=True)
    # 后台启动时 SIGINT 被忽略：SIGINT／SIGTERM 都走收尾（写 source_after 并核对身份）
    def stop(*_):
        raise KeyboardInterrupt
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        after = identity(source)
        (args.out / "source_after.json").write_text(json.dumps(after, indent=2) + "\n")
        if after != before:
            raise RuntimeError("参照来源身份发生变化")


if __name__ == "__main__":
    main()
