"""Build offline full sheet only after all six rows passed alpha-span alignment."""
from pathlib import Path
from PIL import Image
import subprocess, sys
P = Path(__file__).resolve().parent
subprocess.run([sys.executable, str(P/'assemble_rows.py')], check=True)
out = Image.new('RGBA', (576, 384))
for row in range(6):
    out.paste(Image.open(P/f'preview_row{row}.png'), (0, row*64))
out.save(P/'Guyu_Battle_candidate.png')
out.resize((1728,1152), Image.Resampling.NEAREST).save(P/'Guyu_Battle_candidate_3x.png')
print('offline candidate: 54 cells; game integration and animation review pending')
