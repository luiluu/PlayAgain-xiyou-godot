"""T161 offline candidates: uniform scale per prop, binary alpha only; no runtime publish."""
from pathlib import Path
from PIL import Image,ImageDraw
import json, statistics, argparse
P=Path(__file__).resolve().parent
ROOT=P.parents[2]
OLD=ROOT/'03_再刷重制_Godot/02_内容与素材/冻结正式源/app.nw/img/sv_actors/sv'
parser=argparse.ArgumentParser()
parser.add_argument("--names",nargs="+",default=["book","hammer","shield","sword"])
args=parser.parse_args()
report={}
board=Image.new('RGB',(576,4*400),'#607080')
for ni,name in enumerate(args.names):
    src=P/('raw_book_full_attempt3.png' if name=='book' else f'raw_{name}_full.png')
    raw=Image.open(src).convert('RGBA')
    alpha=raw.getchannel('A'); hist=alpha.histogram()
    raw.putalpha(alpha.point(lambda a:255 if a>=128 else 0))
    approved=Image.open(P/f'{name}_gold_row0_64.png').convert('RGBA')
    occupied=[y for y in range(raw.height) if sum(v>=128 for v in raw.getchannel('A').crop((0,y,raw.width,y+1)).get_flattened_data())>20]
    spans=[]
    for y in occupied:
        if not spans or y>spans[-1][1]+1: spans.append([y,y])
        else: spans[-1][1]=y
    assert len(spans)==6,(name,spans)
    bands=[0]+[(spans[i][1]+spans[i+1][0])//2 for i in range(5)]+[raw.height]
    cells=[]; refs=[]
    for row in range(6):
        for col in range(9):
            q=raw.crop((round(col*raw.width/9),bands[row],round((col+1)*raw.width/9),bands[row+1]))
            bb=q.getbbox()
            if bb is None: raise ValueError((name,row,col,'empty'))
            if bb[0]==0 or bb[1]==0 or bb[2]==q.width or bb[3]==q.height: raise ValueError((name,row,col,'touches cell'))
            cells.append(q.crop(bb))
            motion=(col//3)*6+row
            ref=Image.open(OLD/f'Codex_Tusu_{name}_v1/Codex_Tusu_{name}_v1{motion}_{col%3}.png').convert('RGBA').resize((64,64),Image.Resampling.NEAREST)
            refs.append(ref.getbbox())
    # Calibrate from approved first action, then never change scale across frames.
    factors=[]
    for col in range(3):
        bb=approved.crop((col*64,0,(col+1)*64,64)).getbbox()
        factors.append(min((bb[2]-bb[0])/cells[col].width,(bb[3]-bb[1])/cells[col].height))
    scale=statistics.median(factors)
    sheet=Image.new('RGBA',(576,384));frames=[]
    for i,q in enumerate(cells):
        wh=(round(q.width*scale),round(q.height*scale))
        if max(wh)>62: raise ValueError((name,i,wh,'cannot fit with uniform scale'))
        q=q.resize(wh,Image.Resampling.NEAREST)
        bb=refs[i]; x=round((bb[0]+bb[2]-q.width)/2); y=round((bb[1]+bb[3]-q.height)/2)
        x=max(1,min(63-q.width,x));y=max(1,min(63-q.height,y))
        sheet.alpha_composite(q,((i%9)*64+x,(i//9)*64+y))
        frames.append({'row':i//9,'col':i%9,'size':wh,'pos':[x,y]})
    sheet.save(P/f'{name}_full_candidate_64.png')
    board.paste(sheet,(0,ni*400+16),sheet)
    report[name]={'source':src.name,'scale':scale,'alpha_zero_fraction':hist[0]/(raw.width*raw.height),'frames':frames}
board.save(P/'weapons_full_candidates_native.png')
(P/'weapons_full_candidates.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(f'{len(report)*54} cells assembled; each prop uses one uniform scale; candidates only')
