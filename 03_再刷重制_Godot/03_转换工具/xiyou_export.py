#!/usr/bin/env python3
"""西游 v0.04 → Godot 数据与素材转换（只读正式应用）。

用法：xiyou_export.py [--app <app.nw>] [--out <输出目录>] [--slice xiyou_slice.json]

输出（默认 01_Godot工程/modes/xiyou/generated/，不入 Git，可随时重生成）：
  db/<表>.json     全部数据库表；每条记录附 meta（与 MV DataManager.extractMetadata 相同规则）
                   技能/物品附 formulaGd（翻译成 Godot Expression 的伤害公式，翻译不了为 null）
  maps/MapNNN.json 切片涉及的地图
  img/…、audio/…   切片实际引用到的素材（原样复制）
  manifest.json    输入/输出 SHA-256、未能处理项
"""
import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

TOOL_VERSION = 1
HERE = Path(__file__).resolve().parent
DEFAULT_APP = Path('/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw')
DEFAULT_OUT = HERE.parent / '01_Godot工程/modes/xiyou/generated'
TABLES = ['Actors', 'Classes', 'Skills', 'Items', 'Weapons', 'Armors', 'Enemies', 'Troops', 'States',
          'Animations', 'CommonEvents', 'Tilesets', 'MapInfos', 'System',
          'CodexDamageElements', 'CodexOrbs', 'CodexRaces']  # 后三张是西游自定义表：伤害元素/克制、法珠、种族
META_RE = re.compile(r'<([^<>:]+)(:?)([^>]*)>')


def sha(b):
    return hashlib.sha256(b).hexdigest()


def extract_meta(note):
    """MV DataManager.extractMetadata：<key:value> → 字符串，<key> → true。"""
    meta = {}
    for m in META_RE.finditer(note or ''):
        meta[m.group(1)] = m.group(3) if m.group(2) == ':' else True
    return meta


# ---- 伤害公式翻译：JS 表达式 → Godot Expression ----
JS_FUNCS = {'Math.max': 'max', 'Math.min': 'min', 'Math.floor': 'floor', 'Math.ceil': 'ceil', 'Math.round': 'round',
            'Math.abs': 'abs', 'Math.pow': 'pow', 'Math.sqrt': 'sqrt', 'Math.random()': 'randf()'}
UNSUPPORTED = re.compile(r'[;{}?]|\bif\b|\bvar\b|\blet\b|\$game|\$data|=>|===|!==|\bfunction\b|\.length|\[\s*\]|\bthis\b')


def translate_formula(js, item_id=0):
    js = (js or '').strip()
    # MV 公式里 user/target 与 a/b 同义；item.id 在转换时就能确定
    js = re.sub(r'\buser\.', 'a.', js)
    js = re.sub(r'\btarget\.', 'b.', js)
    js = re.sub(r'\bitem\.id\b', str(item_id), js)
    if not js:
        return '0', None
    if UNSUPPORTED.search(js):
        return None, 'js_statement_or_game_state'
    gd = js
    for k, v in JS_FUNCS.items():
        gd = gd.replace(k, v)
    if 'Math.' in gd:
        return None, 'unknown_math_function'
    gd = gd.replace('&&', ' and ').replace('||', ' or ')
    gd = re.sub(r'!(?!=)', ' not ', gd)
    # 允许的标识符：a、b、v[…]、数字、属性访问、运算符、上面翻译过的函数
    if re.search(r'[^\w\s\.\+\-\*/%\(\)\[\],<>=!]', gd):
        return None, 'unexpected_character'
    for ident in re.findall(r'(?<![\.\w])([A-Za-z_]\w*)', gd):
        if ident not in ('a', 'b', 'v', 'max', 'min', 'floor', 'ceil', 'round', 'abs', 'pow', 'sqrt', 'randf', 'and', 'or', 'not', 'true', 'false'):
            return None, f'unknown_identifier:{ident}'
    return gd, None


def load_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


class Exporter:
    def __init__(self, app, out, slice_cfg):
        self.app, self.out, self.cfg = app, out, slice_cfg
        self.inputs, self.outputs, self.issues = {}, {}, []
        self.img, self.audio = set(), set()
        self.db = {}

    def read(self, rel):
        p = self.app / rel
        b = p.read_bytes()
        self.inputs[rel] = sha(b)
        return json.loads(b.decode('utf-8'))

    def write_json(self, rel, data):
        p = self.out / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        b = (json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')
        p.write_bytes(b)
        self.outputs[rel] = sha(b)

    # ---- 数据库 ----
    def export_db(self):
        for name in TABLES:
            data = self.read(f'data/{name}.json')
            if isinstance(data, list):
                for rec in data:
                    if isinstance(rec, dict) and 'note' in rec:
                        rec['meta'] = extract_meta(rec['note'])
                    if isinstance(rec, dict) and isinstance(rec.get('damage'), dict):
                        gd, why = translate_formula(rec['damage'].get('formula'), rec.get('id', 0))
                        rec['damage']['formulaGd'] = gd
                        if why and rec['damage'].get('type'):
                            rec['damage']['formulaIssue'] = why
            self.db[name] = data
            self.write_json(f'db/{name}.json', data)

    # ---- 切片引用收集 ----
    def ref_img(self, folder, name):
        if name:
            self.img.add(f'{folder}/{name}')

    def ref_audio(self, folder, obj):
        if isinstance(obj, dict) and obj.get('name'):
            self.audio.add(f'{folder}/{obj["name"]}')

    def walk_commands(self, lst, troops):
        for c in lst:
            code, p = c['code'], c['parameters']
            if code == 101 and p[0]:
                self.ref_img('faces', p[0])
            elif code == 301 and p[0] == 0:
                troops.add(p[1])
            elif code == 322:
                self.ref_img('characters', p[1]); self.ref_img('faces', p[3]); self.ref_img('sv_actors', p[5])
            elif code in (241, 245, 249, 250, 132, 133, 139):
                self.ref_audio({241: 'bgm', 132: 'bgm', 245: 'bgs', 249: 'me', 133: 'me', 139: 'me', 250: 'se'}[code], p[0])
            elif code == 231:
                self.ref_img('pictures', p[1])
            elif code == 117:
                self.common_events.add(p[0])
            elif code == 283:
                self.ref_img('battlebacks1', p[0]); self.ref_img('battlebacks2', p[1])

    def collect_slice(self):
        cfg, db = self.cfg, self.db
        troops, self.common_events = set(cfg.get('troops', [])), set()
        actors = set(cfg['actors'])
        for mid in cfg['maps']:
            rel = f'data/Map{mid:03d}.json'
            m = self.read(rel)
            m['meta'] = extract_meta(m.get('note'))
            self.write_json(f'maps/Map{mid:03d}.json', m)
            ts = db['Tilesets'][m['tilesetId']]
            for n in ts['tilesetNames']:
                self.ref_img('tilesets', n)
            self.ref_audio('bgm', m.get('bgm')); self.ref_audio('bgs', m.get('bgs'))
            self.ref_img('parallaxes', m.get('parallaxName'))
            self.ref_img('battlebacks1', m.get('battleback1Name')); self.ref_img('battlebacks2', m.get('battleback2Name'))
            for enc in m['encounterList']:
                troops.add(enc['troopId'])
            for ev in m['events']:
                if not ev:
                    continue
                for pg in ev['pages']:
                    self.ref_img('characters', pg['image']['characterName'])
                    self.walk_commands(pg['list'], troops)
        seen = set()
        while self.common_events - seen:
            ce = (self.common_events - seen).pop()
            seen.add(ce)
            if 0 < ce < len(db['CommonEvents']) and db['CommonEvents'][ce]:
                self.walk_commands(db['CommonEvents'][ce]['list'], troops)
        self.slice_troops = sorted(troops)
        for aid in actors:
            a = db['Actors'][aid]
            self.ref_img('faces', a['faceName']); self.ref_img('characters', a['characterName']); self.ref_img('sv_actors', a['battlerName'])
        enemies = set()
        for tid in troops:
            t = db['Troops'][tid]
            for mem in t['members']:
                enemies.add(mem['enemyId'])
            for pg in t['pages']:
                self.walk_commands(pg['list'], set())
        skills = set(cfg.get('extraSkills', [1, 2]))
        for aid in actors:
            cls = db['Classes'][db['Actors'][aid]['classId']]
            skills |= {l['skillId'] for l in cls['learnings'] if l['level'] <= cfg.get('maxLevel', 30)}
        for eid in enemies:
            e = db['Enemies'][eid]
            side = e['meta'].get('Sideview Battler')
            if side:
                self.ref_img('sv_actors', side.strip())
            else:
                self.ref_img('sv_enemies' if db['System']['optSideView'] else 'enemies', e['battlerName'])
            skills |= {a['skillId'] for a in e['actions']}
        anims = {db['Skills'][s]['animationId'] for s in skills if 0 < s < len(db['Skills']) and db['Skills'][s]}
        anims |= {int(x) for x in cfg.get('extraAnimations', [])}
        for wid in range(1, min(len(db['Weapons']), cfg.get('weaponScan', 200))):
            w = db['Weapons'][wid]
            if w:
                anims.add(w['animationId'])
        for aid in anims:
            if 0 < aid < len(db['Animations']) and db['Animations'][aid]:
                an = db['Animations'][aid]
                self.ref_img('animations', an['animation1Name']); self.ref_img('animations', an['animation2Name'])
                for t in an['timings']:
                    self.ref_audio('se', t.get('se'))
        sysd = db['System']
        for k in ('battleBgm', 'victoryMe', 'defeatMe', 'gameoverMe', 'titleBgm'):
            folder = 'bgm' if k.endswith('Bgm') else 'me'
            self.ref_audio(folder, sysd.get(k))
        for s in sysd['sounds']:
            self.ref_audio('se', s)
        for name in cfg.get('systemImages', []):
            self.ref_img('system', name)
        self.slice_info = {'maps': cfg['maps'], 'actors': sorted(actors), 'troops': self.slice_troops,
                           'enemies': sorted(enemies), 'skills': sorted(skills), 'animations': sorted(a for a in anims if a > 0),
                           'commonEvents': sorted(seen)}

    def copy_assets(self):
        def find(base, rel, exts):
            for ext in exts:
                p = self.app / base / (rel + ext)
                if p.exists():
                    return p, ext
            return None, None
        for kind, refs, exts in (('img', self.img, ['.png', '.jpg']), ('audio', self.audio, ['.ogg', '.m4a'])):
            for rel in sorted(refs):
                src, ext = find(kind, rel, exts)
                if not src:
                    self.issues.append({'missingAsset': f'{kind}/{rel}'})
                    continue
                dst = self.out / kind / (rel + ext)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                self.outputs[f'{kind}/{rel}{ext}'] = sha(src.read_bytes())

    def run(self):
        if self.out.exists():
            shutil.rmtree(self.out)
        self.out.mkdir(parents=True)
        pkg = load_json(self.app / 'package.json')
        self.export_db()
        self.collect_slice()
        self.copy_assets()
        untranslated = []
        for sid in self.slice_info['skills']:
            s = self.db['Skills'][sid]
            if s and s['damage']['type'] and s['damage']['formulaGd'] is None:
                untranslated.append({'skill': sid, 'name': s['name'], 'formula': s['damage']['formula'], 'why': s['damage'].get('formulaIssue')})
        all_bad = sum(1 for s in self.db['Skills'] if s and s['damage']['type'] and s['damage']['formulaGd'] is None)
        manifest = {'tool': 'xiyou_export.py', 'toolVersion': TOOL_VERSION, 'source': str(self.app),
                    'releaseVersion': pkg.get('releaseVersion'), 'slice': self.slice_info,
                    'formulaUntranslatedInSlice': untranslated, 'formulaUntranslatedAllSkills': all_bad,
                    'issues': self.issues, 'inputs': self.inputs, 'outputs': self.outputs}
        (self.out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n')
        size = sum(p.stat().st_size for p in self.out.rglob('*') if p.is_file())
        print(json.dumps({'releaseVersion': manifest['releaseVersion'], 'outputs': len(self.outputs), 'bytes': size,
                          'img': len(self.img), 'audio': len(self.audio), 'issues': len(self.issues),
                          'untranslatedInSlice': len(untranslated), 'untranslatedAll': all_bad,
                          'slice': {k: (len(v) if isinstance(v, list) else v) for k, v in self.slice_info.items()}}, ensure_ascii=False))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--app', type=Path, default=DEFAULT_APP)
    ap.add_argument('--out', type=Path, default=DEFAULT_OUT)
    ap.add_argument('--slice', type=Path, default=HERE / 'xiyou_slice.json')
    a = ap.parse_args()
    Exporter(a.app.resolve(), a.out.resolve(), load_json(a.slice)).run()


if __name__ == '__main__':
    sys.exit(main())
