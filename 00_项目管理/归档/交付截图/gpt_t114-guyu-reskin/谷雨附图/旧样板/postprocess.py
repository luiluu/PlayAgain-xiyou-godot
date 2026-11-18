"""Five equal-cell raw strips -> native grids, nearest neighbour + 32 colors.
Coordinator authorized template bbox height and baseline matching. Pillow required.
No frame synthesis, mirroring or animation phase replacement.
"""
from pathlib import Path
from PIL import Image
import json
HERE=Path(__file__).resolve().parent
NAMES=['down','left','right','up','wait']
def process():
    wr=Image.open(HERE/'template_walk.png').convert('RGBA')
    sr=Image.open(HERE/'template_battle.png').convert('RGBA')
    cells=[];records=[]
    for row,name in enumerate(NAMES):
        raw=Image.open(HERE/f'raw_{name}.png').convert('RGBA');size=48 if row<4 else 64
        for col in range(3):
            c=raw.crop((round(col*raw.width/3),0,round((col+1)*raw.width/3),raw.height))
            # Model sometimes bakes a white matte despite transparent request.
            # Remove only near-neutral bright pixels connected to cell border.
            from collections import deque
            px=c.load();seen=set();q=deque()
            for xx in range(c.width):q.extend([(xx,0),(xx,c.height-1)])
            for yy in range(c.height):q.extend([(0,yy),(c.width-1,yy)])
            while q:
                xx,yy=q.popleft()
                if (xx,yy) in seen or not (0<=xx<c.width and 0<=yy<c.height):continue
                seen.add((xx,yy));r,g,b,a=px[xx,yy]
                if a<128 or (min(r,g,b)>180 and max(r,g,b)-min(r,g,b)<12):
                    px[xx,yy]=(0,0,0,0)
                    q.extend([(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)])
            c.putalpha(c.getchannel('A').point(lambda a:255 if a>=128 else 0))
            ref=wr.crop((col*48,row*48,col*48+48,row*48+48)) if row<4 else sr.crop((col*64,64,col*64+64,128))
            bb,rb=c.getbbox(),ref.getbbox()
            if not bb or not rb:raise ValueError(f'Empty {name}/{col}')
            c=c.crop(bb);height=rb[3]-rb[1];width=round(c.width*height/c.height)
            if width>size-2:raise ValueError(f'{name}/{col} too wide: {width}')
            c=c.resize((width,height),Image.Resampling.NEAREST)
            x=max(1,min(size-width-1,round((rb[0]+rb[2]-width)/2)));y=rb[3]-height
            out=Image.new('RGBA',(size,size));out.paste(c,(x,y));cells.append(out)
            records.append(dict(direction=name,frame=col,template_bbox=rb,raw_bbox=bb,output_bbox=out.getbbox(),baseline=rb[3]-1))
    board=Image.new('RGBA',(64*15,64))
    for i,c in enumerate(cells):board.paste(c,(i*64,0))
    alpha=board.getchannel('A');board=board.convert('RGB').quantize(colors=32,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGBA');board.putalpha(alpha)
    walk,idle=Image.new('RGBA',(144,192)),Image.new('RGBA',(192,64))
    for i in range(15):
        size=48 if i<12 else 64;c=board.crop((i*64,0,i*64+size,size))
        if i<12:walk.paste(c,((i%3)*48,(i//3)*48))
        else:idle.paste(c,((i-12)*64,0))
    walk.save(HERE/'Guyu_Walk.png');idle.save(HERE/'Guyu_Wait.png')
    (HERE/'alignment.json').write_text(json.dumps(records,indent=2))
if __name__=='__main__':process()
