"""Reproducible nearest-neighbour / palette / alpha / baseline processing.
Usage: python postprocess.py raw.png
Requires Pillow. Never modifies the raw image or templates.
"""
from pathlib import Path
import sys
from PIL import Image

HERE = Path(__file__).resolve().parent

def process(source):
    raw = Image.open(source).convert('RGBA').resize((192, 320), Image.Resampling.NEAREST)
    alpha = raw.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
    rgb = raw.convert('RGB').quantize(colors=32, method=Image.Quantize.MEDIANCUT).convert('RGBA')
    rgb.putalpha(alpha)
    walk = Image.new('RGBA', (144, 192))
    idle = Image.new('RGBA', (192, 64))
    template_walk = Image.open(HERE / 'template_walk.png').convert('RGBA')
    template_sv = Image.open(HERE / 'template_battle.png').convert('RGBA')
    shifts = []
    for row in range(5):
        for col in range(3):
            cell = rgb.crop((col*64, row*64, col*64+64, row*64+64))
            if row < 4:
                cell = cell.crop((8,16,56,64))
                ref = template_walk.crop((col*48,row*48,col*48+48,row*48+48))
            else:
                ref = template_sv.crop((col*64,64,col*64+64,128))
            bb, rb = cell.getbbox(), ref.getbbox()
            if not bb or not rb:
                raise ValueError(f'Empty frame {row}/{col}')
            dy = rb[3]-bb[3]
            aligned = Image.new('RGBA',cell.size)
            if bb[1]+dy < 0:
                raise ValueError('Baseline alignment would clip head')
            aligned.paste(cell,(0,dy))
            shifts.append((row,col,dy))
            target = walk if row < 4 else idle
            target.paste(aligned,(col*cell.width, row*48 if row<4 else 0))
    walk.save(HERE/'Guyu_Walk.png')
    idle.save(HERE/'Guyu_Wait.png')
    import json
    (HERE/'baseline_shifts.json').write_text(json.dumps(shifts))

if __name__ == '__main__':
    process(sys.argv[1])
