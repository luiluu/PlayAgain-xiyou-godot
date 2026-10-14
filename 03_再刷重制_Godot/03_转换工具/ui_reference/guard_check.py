"""仅用临时假文档验证参照服务；不读取正式应用或真实存档。"""
import functools
import http.client
import http.server
import json
from pathlib import Path
import tempfile
import threading
from serve import H


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='xiyou-http-guard-') as temp:
        root = Path(temp) / 'source'
        root.mkdir()
        (root / 'data').mkdir()
        (root / 'data' / 'ok.json').write_text('{}')
        (root / 'save').mkdir()
        (root / 'save' / 'slot.rpgsave').write_text('fake-save')
        (root / 'codex_author_key.json').write_text('fake-key')
        outside = Path(temp) / 'outside'
        outside.mkdir()
        (outside / 'fake.txt').write_text('fake')
        (root / 'alias').symlink_to(outside, target_is_directory=True)
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(H, directory=str(root)))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for method in ['GET', 'HEAD']:
                for url, status in [('/data/ok.json', 200), ('/save/slot.rpgsave', 403), ('/%73ave/slot.rpgsave', 403),
                                    ('/SAVE/slot.rpgsave', 403), ('/codex_author_key.json', 403), ('/alias/fake.txt', 403)]:
                    connection = http.client.HTTPConnection(*server.server_address)
                    connection.request(method, url)
                    response = connection.getresponse()
                    results.append({'name': method+' '+url, 'passed': response.status == status})
                    response.read()
                    connection.close()
        finally:
            server.shutdown()
            server.server_close()
    passed = sum(r['passed'] for r in results)
    print('TEST_RESULT='+json.dumps({'passed': passed, 'total': len(results), 'failures': [r for r in results if not r['passed']]}))
    return 0 if passed == len(results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
