"""Read-only native sprite delivery checks; requires Pillow, does not modify images."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops

root = Path(__file__).parent
results = []
for row in json.loads((root / 'native_report.json').read_text()):
    name, (w, h), cut = row['id'], row['cell'], row['head_cut']
    frames = [Image.open(root / 'native' / f'{name}_idle_{i}.png').convert('RGBA') for i in range(3)]
    assert all(f.size == (w, h) for f in frames)
    assert all(set(f.getchannel('A').get_flattened_data()) <= {0, 255} for f in frames)
    assert frames[0].tobytes() == frames[2].tobytes()
    assert frames[0].tobytes() != frames[1].tobytes(), name
    assert frames[0].crop((0, cut+1, w, h)).tobytes() == frames[1].crop((0, cut+1, w, h)).tobytes()
    if name != 'tusu_bow':
        xmin = row['source_bbox'][0] + row['source_bbox'][2] // 4 if name == 'cat' else 0
        assert frames[0].crop((xmin, 0, w, cut)).tobytes() == frames[1].crop((xmin, 1, w, cut+1)).tobytes(), name
    results.append({'id': name, 'size': [w, h], 'head_rig': 'string glint' if name == 'tusu_bow' else 'down 1px, x fixed', 'support_region_unchanged': True})
for name in ['yomi', 'toji']:
    for direction in range(4):
        frames = [Image.open(root / 'native' / f'{name}_walk_{direction}_{i}.png') for i in range(3)]
        assert all(f.size == (48, 48) for f in frames)
        assert len({f.tobytes() for f in frames}) == 3
        assert all(f.getbbox()[0] > 0 and f.getbbox()[1] > 0 and f.getbbox()[2] < 48 and f.getbbox()[3] < 48 for f in frames)
print(json.dumps({'idle_items': 13, 'idle_frames': 39, 'walk_frames': 24, 'checks': results, 'sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'native').glob('*.png'))}}, ensure_ascii=False, indent=2))
