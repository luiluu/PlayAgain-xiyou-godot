"""T127 read-only reference extraction; alpha bands are proxies, not anatomical landmarks.
Outputs private evidence only. Requires Pillow. No source images are modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ACTIONS = ['walk','wait','chant','guard','damage','evade','thrust','swing','missile','skill','spell','item','escape','victory','dying','abnormal','sleep','dead']


def frames(im, motion, kind='battle', index=0):
    if kind == 'battle':
        if im.width % 9 or im.height % 6:
            raise ValueError('Expected 9x6 sheet')
        w,h=im.width//9,im.height//6
        x,y=motion//6*3*w,motion%6*h
    else:
        cols,rows=(3,4) if index < 0 else (12,8)
        if im.width%cols or im.height%rows:
            raise ValueError('Invalid character sheet grid')
        w,h=im.width//cols,im.height//rows
        x,y=(0,motion*h) if index<0 else (index%4*3*w,(index//4*4+motion)*h)
    return [im.crop((x+k*w,y,x+(k+1)*w,y+h)).convert('RGBA') for k in range(3)]


def measure(fs):
    w,h=fs[0].size
    if not all(f.getbbox() for f in fs):
        return {'status':'empty'}
    result={'cell':[w,h],'bounds':[f.getbbox() for f in fs], 'bands':{}}
    for name,box in {'head_band':(0,0,w,h//2),'body_band':(0,h//2,w,h*3//4),'left_hand_band':(0,h//2,w//2,h*3//4),'right_hand_band':(w//2,h//2,w,h*3//4),'whole':(0,0,w,h)}.items():
        points=[]
        for f in fs:
            pts=[(x,y) for y in range(box[1],box[3]) for x in range(box[0],box[2]) if f.getpixel((x,y))[3]>=128]
            points.append([sum(p[k] for p in pts)/len(pts) for k in (0,1)] if pts else None)
        result['bands'][name]={'centroids':points,'span_xy':[round(max(p[k] for p in points)-min(p[k] for p in points),3) for k in (0,1)] if all(points) else None}
    soles=[]
    for f in fs:
        alpha=f.getchannel('A').point(lambda v:255 if v>=128 else 0)
        b=alpha.getbbox()
        if b is None:
            soles.append(None)
        else:
            xs=[x for x in range(w) if alpha.getpixel((x,b[3]-1))]
            soles.append([sum(xs)/len(xs),b[3]-1,min(xs),max(xs)])
    result['sole_contact']=soles
    result['sole_span_xy']=[round(max(p[k] for p in soles)-min(p[k] for p in soles),3) for k in (0,1)] if all(soles) else None
    return result


def extract(source,out,kind,index):
    raw=source.read_bytes()
    import io
    im=Image.open(io.BytesIO(raw)).convert('RGBA')
    out.mkdir(parents=True,exist_ok=True)
    results=[]
    for m,label in enumerate(ACTIONS if kind=='battle' else ['down','left','right','up']):
        fs=frames(im,m,kind,index)
        r=measure(fs);r['motion']=m;r['label']=label;results.append(r)
        strip=Image.new('RGBA',(fs[0].width*3,fs[0].height))
        for k,f in enumerate(fs):strip.paste(f,(k*f.width,0))
        strip.save(out/f'{m:02}_{label}_1x.png')
        strip.resize((strip.width*4,strip.height*4),Image.Resampling.NEAREST).save(out/f'{m:02}_{label}_4x.png')
        seq=[fs[k].resize((fs[k].width*4,fs[k].height*4),Image.Resampling.NEAREST) for k in [0,1,2,1]]
        # Opaque common background avoids GIF disposal artefacts.
        rgb=[]
        for f in seq:
            bg=Image.new('RGB',f.size,(35,40,48));bg.paste(f,mask=f.getchannel('A'));rgb.append(bg)
        rgb[0].save(out/f'{m:02}_{label}.gif',save_all=True,append_images=rgb[1:],duration=150,loop=0)
    (out/'metrics.json').write_text(json.dumps({'source':str(source),'sha256':hashlib.sha256(raw).hexdigest(),'kind':kind,'character_index':index,'note':'Alpha-zone proxies, not anatomical joints; observed spans, not approved thresholds. battle uses MV column-block mapping m//6,m%6. GIF is inspection cadence, not runtime timing.','results':results},ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sheet',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--kind',choices=['battle','walk'],default='battle')
    p.add_argument('--character-index',type=int,default=0,help='0..7 for standard walk sheet; -1 for $ single character')
    a=p.parse_args()
    if not -1<=a.character_index<=7:p.error('character-index must be -1..7')
    extract(a.sheet,a.out,a.kind,a.character_index)
