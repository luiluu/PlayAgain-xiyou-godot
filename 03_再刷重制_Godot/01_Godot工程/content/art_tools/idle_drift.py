"""Read-only idle triage, Pillow required. Native-pixel thresholds; warnings need visual review.
Default: project-local redrawn sheets + generated Codex sheets / custom multi-frame forms.
Also measure T113 Yunshang sample directly from its git branch (never check out/write it).
"""
import argparse,io,itertools,json,subprocess
from pathlib import Path
from PIL import Image
PROJECT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--out',type=Path,required=True)
p.add_argument('--sheet',type=Path,action='append',help='Only measure these MV sheets; repeatable')
p.add_argument('--threshold',type=float,default=1.0)
a=p.parse_args()

def zone(frame,box):
    pts=[(x,y) for y in range(box[1],box[3]) for x in range(box[0],box[2]) if frame.getpixel((x,y))[3]>=128]
    if not pts:return None
    return {'centroid':[sum(x for x,y in pts)/len(pts),sum(y for x,y in pts)/len(pts)],'bbox':[min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1]}

def measure(label,frames,kind):
    w,h=frames[0].size
    assert all(f.size==(w,h) for f in frames),label
    zones={'head':(0,0,w,h//2),'left_hand_band':(0,h//2,w//2,h*3//4),'right_hand_band':(w//2,h//2,w,h*3//4),'sole_contact':(0,h-1,w,h)}
    metrics={};warnings=[]
    for name,box in zones.items():
        zs=[zone(f,(0,f.getbbox()[3]-1,w,f.getbbox()[3])) if name=='sole_contact' else zone(f,box) for f in frames]
        if not all(zs):continue
        spans=[round(max(z['centroid'][axis] for z in zs)-min(z['centroid'][axis] for z in zs),3) for axis in (0,1)]
        bbox_span=max(max(z['bbox'][axis] for z in zs)-min(z['bbox'][axis] for z in zs) for axis in range(4))
        metrics[name]={'centroid_span_xy':spans,'bbox_edge_span':bbox_span}
        if max(*spans,bbox_span)>a.threshold:warnings.append(name)
    bounds=[f.getbbox() for f in frames]
    sole_span=max(b[3] for b in bounds)-min(b[3] for b in bounds)
    if sole_span>a.threshold:warnings.append('sole')
    return {'asset':label,'kind':kind,'frame_count':len(frames),'cell':[w,h],'bounds':bounds,'sole_span':sole_span,'metrics':metrics,'warnings':warnings,'status':'REVIEW' if warnings else 'within_threshold'}

results=[];skipped=[];seen=set()
def sheet(label,im,row=0):
    im=im.convert('RGBA');w,h=im.size
    if w%9 or h%6 or w//9!=h//6:
        skipped.append({'asset':label,'reason':'not square 9x6 MV sheet'});return
    c=w//9
    frames=[im.crop((i*c,row*c,(i+1)*c,(row+1)*c)) for i in range(3)]
    if not all(f.getbbox() for f in frames):
        skipped.append({'asset':label,'reason':'walk cells empty; no silent wait fallback'});return
    results.append(measure(label,frames,'sheet walk' if row==0 else 'sample wait (not wired)'))

if a.sheet:
    for f in a.sheet:sheet(str(f),Image.open(f))
else:
    for f in sorted((PROJECT/'content').rglob('*.png')):
        if ('_SV' in f.name or f.name=='Yunshang.png') and 'evidence' not in str(f) and 'references' not in str(f):
            sheet(str(f.relative_to(PROJECT)),Image.open(f));seen.add(f.name)
    gen=PROJECT/'modes/xiyou/generated/img/sv_actors'
    for f in sorted(gen.glob('*.png')):
        if (f.name.startswith('Codex_') or f.name=='Yunshang.png') and f.name not in seen:
            sheet(str(f.relative_to(PROJECT)),Image.open(f))
    for parent in [gen/'sv',PROJECT/'content/sukuna/img/sv_actors/sv',PROJECT/'content/mira/img/sv_actors/sv']:
        for folder in sorted(parent.glob('*')):
            if not folder.is_dir():continue
            if parent==gen/'sv' and not (folder.name.startswith('Codex_') or folder.name=='garou_human_v2'):continue
            if folder.name in ('Codex_Bound_Transparent_v1','Codex_Sukuna_QFull') and parent==gen/'sv':continue
            fs=[folder/f'{folder.name}0_{i}.png' for i in range(3)]
            fs=[f for f in fs if f.exists()]
            if not fs:skipped.append({'asset':str(folder),'reason':'no motion0 frames'});continue
            results.append(measure(str(folder.relative_to(PROJECT)),[Image.open(f).convert('RGBA') for f in fs],'multi-frame walk (up to first3)'))
    # T113 is not merged; measure exact committed sample, not another worktree's working files.
    ref='gpt/yunshang-v2:03_再刷重制_Godot/01_Godot工程/content/yunshang_v2/Yunshang_SV_sample_u1.png'
    r=subprocess.run(['git','show',ref],cwd=PROJECT,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if r.returncode==0:sheet(ref,Image.open(io.BytesIO(r.stdout)),row=1)
    else:skipped.append({'asset':ref,'reason':'branch unavailable'})
report={'threshold_native_pixels':a.threshold,'note':'Coarse alpha-zone drift triage; hand bands include clothing/tails. REVIEW is not an automatic failure or permission to edit. Single-frame forms have no three-frame animation. Runtime content overrides generated files.','results':results,'skipped':skipped}
a.out.parent.mkdir(parents=True,exist_ok=True)
a.out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
for r in results:print(r['status'],r['asset'],','.join(r['warnings']) or '-',json.dumps(r['metrics'],ensure_ascii=False))
print('TOTAL',len(results),'REVIEW',sum(bool(r['warnings']) for r in results),'SKIPPED',len(skipped))
