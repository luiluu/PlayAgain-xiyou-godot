"""tried.py：把 event_presets.json 在 git 里全部历史版本出现过的 (页, 预设) 并成 $SA_WORK/tried.json（cases 格式）。四期做法。"""
import json, os, subprocess
from pathlib import Path
F = Path(__file__).resolve().parent.parent / 'event_presets.json'
R = subprocess.run(['git', '-C', str(F.parent), 'rev-parse', '--show-toplevel'], capture_output=True, text=True).stdout.strip()
rel = str(F.relative_to(R))
W = Path(os.environ.get('SA_WORK', '.'))
hs = subprocess.run(['git', '-C', R, 'log', '--all', '--format=%H', '--', rel], capture_output=True, text=True).stdout.split()
seen, out = set(), []
for h in hs:
    p = subprocess.run(['git', '-C', R, 'show', f'{h}:{rel}'], capture_output=True, text=True)
    if p.returncode:
        continue
    try:
        cs = json.loads(p.stdout)['cases']
    except Exception:
        continue
    for c in cs:
        k = (c['base'], json.dumps(c['preset'], sort_keys=True))
        if k not in seen:
            seen.add(k)
            out.append({'base': c['base'], 'tag': c.get('tag', ''), 'preset': c['preset']})
print('历史版本', len(hs), '出现过的 (页,预设)', len(out))
(W / 'tried.json').write_text(json.dumps({'cases': out}, ensure_ascii=False))
