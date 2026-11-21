#!/usr/bin/env python3
"""精灵自检.py 专项测试（T156）。需要 Pillow；没装就整体跳过（系统 python 常没有，见 美术工具/README.md）。
包含：合成图的单项检查、T141 首轮(bffd65797)／返修2(c5a2e294d) 反向验证（要本仓库里有这两个提交，没有就跳过）、
五条悟／狗逍遥／里德现有图必须退出 0。"""
import importlib.util
import io
import subprocess
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJ = HERE.parent / '01_Godot工程'
try:
    from PIL import Image
    HAVE = True
except ImportError:
    HAVE = False

spec = importlib.util.spec_from_file_location('sprite_check', HERE / '精灵自检.py')


def load():
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def git_blob(commit, path):
    try:
        return subprocess.check_output(['git', 'show', f'{commit}:{path}'], cwd=ROOT, stderr=subprocess.DEVNULL)
    except Exception:
        return None


def fails(mod, rep):
    return {i['id'] for i in rep.fails}


@unittest.skipUnless(HAVE, '需要 Pillow')
class SyntheticTests(unittest.TestCase):
    def setUp(self):
        self.sc = load()
        self.cfg = self.sc.load_cfg(HERE / '精灵自检阈值.json')

    def person(self, shift=0, foot_y=44, dx=0):
        """画一个 48×48 的小人：头、躯干、两条腿（腿位置随 shift 变化）。"""
        im = Image.new('RGBA', (48, 48), (0, 0, 0, 0))
        px = im.load()
        c = (200, 120, 60, 255)
        for y in range(6, 14):
            for x in range(20 + dx, 28 + dx):
                px[x, y] = c
        for y in range(14, 30):
            for x in range(18 + dx, 30 + dx):
                px[x, y] = c
        for y in range(30, foot_y):
            for x in range(19 + shift + dx, 23 + shift + dx):
                px[x, y] = c
            for x in range(26 - shift + dx, 30 - shift + dx):
                px[x, y] = c
        return im

    def sheet(self, frames_by_row):
        im = Image.new('RGBA', (144, 192))
        for r, row in enumerate(frames_by_row):
            for k, f in enumerate(row):
                im.paste(f, (k * 48, r * 48))
        return im

    def run_walk(self, sheet, prof='biped'):
        rep = self.sc.Report()
        self.sc.check_walk(rep, self.cfg, prof, sheet, 't')
        return rep

    def test_good_walk_passes(self):
        row = [self.person(shift=s) for s in (2, 0, -2)]
        rep = self.run_walk(self.sheet([row] * 4))
        self.assertEqual(fails(self.sc, rep), set())

    def test_repeat_gait_fails(self):
        f = self.person(shift=1)
        rep = self.run_walk(self.sheet([[f, f, f]] * 4))
        self.assertIn('gait_repeat', fails(self.sc, rep))

    def test_wrong_size_fails(self):
        rep = self.run_walk(Image.new('RGBA', (150, 192)))
        self.assertIn('native_size', fails(self.sc, rep))

    def test_halftone_alpha_fails(self):
        f = self.person()
        f.putpixel((10, 10), (1, 2, 3, 100))
        rep = self.run_walk(self.sheet([[f, f, f]] * 4))
        self.assertIn('binary_alpha', fails(self.sc, rep))

    def test_isolated_pixel_fails(self):
        row = [self.person(shift=s) for s in (2, 0, -2)]
        row[1].putpixel((5, 5), (255, 0, 0, 255))
        rep = self.run_walk(self.sheet([row] * 4))
        self.assertIn('isolated_px', fails(self.sc, rep))

    def test_edge_pixel_fails(self):
        row = [self.person(shift=s) for s in (2, 0, -2)]
        row[0].putpixel((0, 20), (255, 0, 0, 255))
        rep = self.run_walk(self.sheet([row] * 4))
        self.assertIn('edge_margin', fails(self.sc, rep))

    def test_floating_hoof_fails(self):
        row = [self.person(shift=2, foot_y=44), self.person(shift=0, foot_y=42), self.person(shift=-2, foot_y=44)]
        rep = self.run_walk(self.sheet([row] * 4))
        self.assertIn('walk_sole_span', fails(self.sc, rep))

    def test_waist_shift_fails(self):
        """下半身按固定步距漂移：上身不动、腿+腰带每帧左偏几像素。"""
        rows = []
        for _ in range(4):
            fs = []
            for k in range(3):
                im = Image.new('RGBA', (48, 48))
                up = self.person(shift=2 - 2 * k)
                im.paste(up.crop((0, 0, 48, 24)), (0, 0))
                im.paste(up.crop((0, 24, 48, 48)), (-4 * k, 24), up.crop((0, 24, 48, 48)))
                fs.append(im)
            rows.append(fs)
        rep = self.run_walk(self.sheet(rows))
        self.assertTrue({'waist_shift', 'waist_break'} & fails(self.sc, rep))

    def test_idle_baseline_and_drift(self):
        def idle(foot_bottom, dx):
            im = Image.new('RGBA', (192, 64))
            for k in range(3):
                f = Image.new('RGBA', (64, 64))
                p = f.load()
                for y in range(foot_bottom - 40, foot_bottom):
                    for x in range(20 + dx * k, 32 + dx * k):
                        p[x, y] = (200, 120, 60, 255)
                im.paste(f, (k * 64, 0))
            return im
        rep = self.sc.Report()
        self.sc.check_idle(rep, self.cfg, 'biped', idle(60, 0))
        self.assertIn('idle_baseline', fails(self.sc, rep))
        rep = self.sc.Report()
        self.sc.check_idle(rep, self.cfg, 'biped', idle(64, 0))
        self.assertNotIn('idle_baseline', fails(self.sc, rep))
        rep = self.sc.Report()
        self.sc.check_idle(rep, self.cfg, 'biped', idle(64, 3))
        self.assertTrue([i for i in rep.warns if i['id'] == 'idle_anchor_drift'])


@unittest.skipUnless(HAVE, '需要 Pillow')
class Spec128Tests(unittest.TestCase):
    def setUp(self):
        self.sc = load()
        self.cfg = self.sc.load_cfg(HERE / '精灵自检阈值.json')

    def idle(self, bottom=128, height=100):
        from PIL import ImageDraw
        im = Image.new('RGBA', (384, 128))
        for k in range(3):
            ImageDraw.Draw(im).rectangle((k * 128 + 54, bottom-height, k * 128 + 73, bottom-1), fill='white')
        return im

    def test_128_baseline_is_inclusive_row_127(self):
        for bottom in (127, 128):
            rep = self.sc.Report()
            self.sc.check_idle(rep, self.cfg, 'biped', self.idle(bottom))
            self.assertEqual('idle_baseline' in fails(self.sc, rep), bottom != 128)
            self.assertNotIn('native_size', fails(self.sc, rep))
            self.assertTrue(next(i['ok'] for i in rep.items if i['id'] == 'native_height'))

    def test_short_128_warns(self):
        rep = self.sc.Report()
        self.sc.check_idle(rep, self.cfg, 'biped', self.idle(height=50))
        self.assertIn('native_height', {i['id'] for i in rep.warns})

    def test_128_walk_recognized(self):
        im = Image.new('RGBA', (384, 512))
        for r in range(4):
            im.paste(self.idle(), (0, r * 128))
        rep = self.sc.Report()
        self.sc.check_walk(rep, self.cfg, 'biped', im, '128')
        self.assertNotIn('native_size', fails(self.sc, rep))
        self.assertTrue(next(i['ok'] for i in rep.items if i['id'] == 'native_height'))

    def test_legacy_config_unchanged(self):
        self.assertIs(self.sc.sheet_cfg(self.cfg, Image.new('RGBA', (192, 64)), 'idle'), self.cfg)
        self.assertIs(self.sc.sheet_cfg(self.cfg, Image.new('RGBA', (144, 192)), 'walk'), self.cfg)

    def test_128_montage_contains_new_frames(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / 'montage.png'
            self.sc.montage(out, '128', None, self.idle(), None, None, self.sc.Report(), 1)
            im = Image.open(out)
            self.assertIn((255, 255, 255), [c for _, c in im.getcolors(im.width * im.height)])


@unittest.skipUnless(HAVE, '需要 Pillow')
class ReferenceTests(unittest.TestCase):
    """现有参照图必须通过（退出 0）；遗留参照图是抗锯齿的，故 --skip binary_alpha。"""

    def run_cli(self, argv):
        mod = load()
        return mod.main(argv)

    def test_references_pass(self):
        g = PROJ / 'modes/xiyou/generated/img'
        if not (g / 'sv_actors/gxysv2.png').exists():
            self.skipTest('没有 generated 图（需 --补齐）')
        cases = [
            ['--name', 'gouxiaoyao', '--walk', str(g / 'characters/PF_3.png'), '--walk-index', '6', '--idle-sv', str(g / 'sv_actors/gxysv2.png')],
            ['--name', 'reid', '--walk', str(g / 'characters/Actor11.png'), '--walk-index', '0', '--idle-sv', str(g / 'sv_actors/Actor11_1.png')],
            ['--name', 'gojo', '--walk', str(PROJ / 'content/gojo/$Codex_Gojo_Walk.png'), '--idle-sv', str(PROJ / 'content/gojo/Codex_Gojo_SV.png')],
        ]
        for c in cases:
            with self.subTest(c[1]):
                self.assertEqual(self.run_cli(c + ['--skip', 'binary_alpha']), 0)


@unittest.skipUnless(HAVE, '需要 Pillow')
class ReverseValidationTests(unittest.TestCase):
    """T141 首轮／返修2 稿必须被报出小A 当时查到的问题。"""
    D = '03_再刷重制_Godot/01_Godot工程/content/'

    def blobs(self, commit, d, name, walk_name, idle_name):
        w = git_blob(commit, f'{self.D}{d}/{walk_name.format(n=name)}')
        i = git_blob(commit, f'{self.D}{d}/{idle_name.format(n=name)}')
        if not w or not i:
            self.skipTest(f'本仓库没有 {commit}')
        return Image.open(io.BytesIO(w)).convert('RGBA'), Image.open(io.BytesIO(i)).convert('RGBA')

    def rep(self, commit, d, name, walk_name):
        sc = load()
        cfg = sc.load_cfg(HERE / '精灵自检阈值.json')
        w, i = self.blobs(commit, d, name, walk_name, '{n}_Idle.png')
        rep = sc.Report()
        sc.check_walk(rep, cfg, 'quadruped', w, name)
        sc.check_idle(rep, cfg, 'quadruped', i)
        return {x['id'] for x in rep.fails}

    def test_round1_all_fail(self):
        for n in ('bogani', 'brandwalden', 'ruth', 'bichi'):
            f = self.rep('bffd65797', 't141_d177_native', n, '$T141_{n}_Walk.png')
            self.assertIn('idle_baseline', f, n)  # 待机脚底 y=60
        self.assertIn('walk_sole_span', self.rep('bffd65797', 't141_d177_native', 'brandwalden', '$T141_{n}_Walk.png'))  # 蹄底悬高
        self.assertIn('foot_merge', self.rep('bffd65797', 't141_d177_native', 'brandwalden', '$T141_{n}_Walk.png'))  # 内蹄粘连
        self.assertIn('waist_break', self.rep('bffd65797', 't141_d177_native', 'ruth', '$T141_{n}_Walk.png'))

    def test_round2_reports_known_problems(self):
        c = 'c5a2e294d'
        d = 't141_centaur_revision'
        w = '$T141_{n}_Walk.png'
        b = self.rep(c, d, 'brandwalden', w)
        self.assertTrue({'foot_merge', 'isolated_px'} <= b)  # 内蹄粘连、孤立悬空像素
        for n in ('ruth', 'bichi'):
            f = self.rep(c, d, n, w)
            self.assertIn('waist_shift', f, n)  # 下半身错位 3～7px
            self.assertIn('waist_break', f, n)  # 腰部断裂


@unittest.skipUnless(HAVE, '需要 Pillow')
class WaistOuterTrimTests(unittest.TestCase):
    """T172：waist_break 不被飘带/披风等外挂轮廓误报；真断腰仍报；torso_half_frac=0 可回退。"""
    FIX = HERE / '测试夹具/xuan_original_native_144x192.png'

    def setUp(self):
        self.sc = load()
        self.cfg = self.sc.load_cfg(HERE / '精灵自检阈值.json')

    def walk_fails(self, im, cfg=None):
        rep = self.sc.Report()
        self.sc.check_walk(rep, cfg or self.cfg, 'biped', im, 't')
        return [i for i in rep.fails if i['id'] == 'waist_break']

    def test_xuan_original_no_waist_break(self):
        self.assertEqual(self.walk_fails(Image.open(self.FIX).convert('RGBA')), [])

    def test_xuan_original_rollback_switch(self):
        import copy
        cfg = copy.deepcopy(self.cfg)
        cfg['profiles']['biped']['waist']['torso_half_frac'] = 0
        self.assertTrue(self.walk_fails(Image.open(self.FIX).convert('RGBA'), cfg))  # 关掉开关＝旧行为，原版璇 left 误报

    def figure(self, waist_w, cape=0):
        """48×48 小人：头、肩（宽 12）、腰（waist_w）、髋、腿；cape>0 时在肩背后挂一块大披风。"""
        im = Image.new('RGBA', (48, 48))
        px = im.load()
        c = (200, 120, 60, 255)
        def row(y, x0, x1):
            for x in range(x0, x1):
                px[x, y] = c
        for y in range(4, 10): row(y, 20, 28)
        for y in range(10, 22): row(y, 18, 30)
        for y in range(22, 27): row(y, 24 - waist_w // 2, 24 + (waist_w + 1) // 2)
        for y in range(27, 33): row(y, 18, 30)
        for y in range(33, 44):
            row(y, 19, 23); row(y, 26, 30)
        if cape:
            for y in range(10, 36): row(y, 30, 30 + cape)
        return im

    def test_cape_not_misreported(self):
        f = self.figure(waist_w=8, cape=9)
        self.assertEqual(self.walk_fails(self._sheet(f)), [])

    def _sheet(self, f):
        im = Image.new('RGBA', (144, 192))
        for r in range(4):
            for k in range(3):
                im.paste(f, (k * 48, r * 48))
        return im

    def test_real_pinch_still_fails_with_cape(self):
        f = self.figure(waist_w=2, cape=9)  # 腰只剩 2px：真断
        self.assertTrue(self.walk_fails(self._sheet(f)))

    def test_real_pinch_still_fails_without_cape(self):
        self.assertTrue(self.walk_fails(self._sheet(self.figure(waist_w=3))))


if __name__ == '__main__':
    unittest.main()
