"""T127 provisional triage and private comparison pages; not an acceptance gate.
Uses observed alpha-band metrics with explicit provisional tolerances. Never edits art.
"""
import argparse,hashlib,html,json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from motion_reference import ACTIONS,frames,measure

KEYS=[0,4,6,7,9,13,17]
FONT='/System/Library/Fonts/STHeiti Medium.ttc'

def load_frames(p,m):
    if p.is_file():return frames(Image.open(p),m)
    files=sorted(p.glob(f'{p.name}{m}_*.png'),key=lambda f:int(f.stem.rsplit('_',1)[1]))
    return [Image.open(f).convert('RGBA') for f in files]

def vector(r):
    if 'bands' not in r:return None
    vals=[]
    for k in ['head_band','left_hand_band','right_hand_band','whole']:
        v=r['bands'][k]['span_xy']
        if v is None:return None
        vals.extend(v)
    vals.append(r['sole_span_xy'][1])
    return vals


def compare(r,refs):
    v=vector(r)
    if v is None:return {'status':'缺测','reason':'空帧或分区无像素，需人工锚点','severity':0}
    attempts=[]
    labels=['头区左右','头区上下','左手区左右','左手区上下','右手区左右','右手区上下','整体左右','整体上下','脚底上下']
    baselines=[vector(ref) for name,ref in refs]
    for name,ref in refs:
        b=vector(ref)
        problems=[];score=0;worst=''
        for i,(label,x,y) in enumerate(zip(labels,v,b)):
            # Reference-to-reference difference calibrates tolerance, never mixes axes between refs.
            margin=abs(baselines[0][i]-baselines[1][i])+max(.5,min(baselines[0][i],baselines[1][i])*.25)
            ratio=abs(x-y)/margin
            if ratio>score:
                score=ratio;worst=f'{label}{"偏多" if x>y else "偏少"} {x:.2f}px，参照 {y:.2f}px'
            if ratio>1:problems.append(f'{label}{"偏多" if x>y else "偏少"}{x:.2f}/{y:.2f}')
        attempts.append((score,name,problems,worst))
    score,name,problems,worst=min(attempts)
    return {'status':'初判偏离' if score>1 else '初判接近','reference':name,'reason':'；'.join(problems) if problems else '分区跨度接近，仍须锚点/语义审样','short_reason':worst,'severity':score,'attempts':attempts}


def gif(groups,path):
    width=360;height=170;ims=[]
    for k in range(4):
        canvas=Image.new('RGB',(width,height),(35,40,48));d=ImageDraw.Draw(canvas)
        for i,(name,fs) in enumerate(groups):
            d.text((i*120+3,2),name,font=ImageFont.truetype(FONT,12),fill='white')
            if not fs:
                d.text((i*120+3,35),'无独立帧',font=ImageFont.truetype(FONT,12),fill='#ffaaaa');continue
            f=fs[([0,1,2,1][k] if len(fs)==3 else k%len(fs))]
            scale=min(112/f.width,145/f.height)
            f=f.resize((max(1,round(f.width*scale)),max(1,round(f.height*scale))),Image.Resampling.NEAREST)
            canvas.paste(f,(i*120+(120-f.width)//2,height-f.height),f)
        ims.append(canvas)
    ims[0].save(path,save_all=True,append_images=ims[1:],duration=150,loop=0)


def main(a):
    out=a.out;out.mkdir(parents=True,exist_ok=True)
    manifest=json.loads(a.manifest.read_text());rows=[]
    # T124 08/20 and 09/21 are the same body, keep canonical entries 08/09.
    manifest=[r for r in manifest if r['number'] not in [1,2,6,11,20,21,24]]
    manifest.append(dict(number=26,name='哈基米',source='modes/xiyou/generated/img/sv_actors/CatSwordSaint_SV_v3.png'))
    refs={k:json.loads((out/k/'battle/metrics.json').read_text())['results'] for k in ['gouxiaoyao','reid']}
    actors=json.loads((a.project/'modes/xiyou/generated/db/Actors.json').read_text())
    mapping={1:None,2:168,3:172,4:170,5:179,6:179,7:171,8:176,9:177,10:169,11:174,12:173,13:173,14:175,15:176,16:176,17:176,18:176,19:176,22:173,23:172,24:168,25:174,26:178}
    walks={1:'content/gojo/$Codex_Gojo_Walk.png',2:'content/mira/img/characters/$Codex_Mira_Walk_Final.png',3:'content/sukuna/img/characters/$Codex_Sukuna_Walk.png',25:'content/yunshang_v2/u2/$Yunshang_u2.png'}
    gojo=Image.open(a.project/'content/gojo/Codex_Gojo_SV.png').convert('RGBA')
    g=frames(gojo,0)[1];gb=g.getbbox();gh=gb[3]-gb[1]
    for entry in manifest:
        n=entry['number']
        if n==25:entry['name']='云裳·u2现行'
        dest=out/f'actor_{n:02}';dest.mkdir(exist_ok=True)
        source=a.project/entry['source']
        rs={};sections=[]
        for motion in KEYS:
            fs=load_frames(source,motion)
            r=measure(fs) if fs else {'status':'missing'}
            verdict=compare(r,[(k,refs[k][motion]) for k in refs]);rs[ACTIONS[motion]]=dict(metrics=r,verdict=verdict,frame_count=len(fs))
            groups=[(entry['name'],fs)]+[(title,load_frames(a.project/f'modes/xiyou/generated/img/sv_actors/{asset}.png',motion)) for title,asset in [('狗逍遥','gxysv2'),('里德','Actor11_1')]]
            file=f'battle_{motion:02}.gif';gif(groups,dest/file)
            sections.append(f'<h3>{ACTIONS[motion]} · {verdict["status"]}</h3><img src="{file}"><p>{html.escape(verdict["reason"])}</p>')
        actor=actors[mapping[n]] if mapping[n] else None
        walkrel=walks.get(n,'modes/xiyou/generated/img/characters/'+actor['characterName']+'.png' if actor else '')
        walk=a.project/walkrel; wr={}
        for direction,label in enumerate(['down','left','right','up']):
            fs=frames(Image.open(walk),direction,'walk',-1 if walk.name.startswith('$') else actor['characterIndex']) if walk.is_file() else []
            r=measure(fs) if fs else {'status':'missing'}
            refms=[(key,json.loads((out/key/'walk/metrics.json').read_text())['results'][direction]) for key in refs]
            verdict=compare(r,refms);wr[label]=dict(metrics=r,verdict=verdict)
            groups=[(entry['name'],fs)]
            for title,key,file,index in [('狗逍遥','gouxiaoyao','PF_3',6),('里德','reid','Actor11',0)]:groups.append((title,frames(Image.open(a.project/f'modes/xiyou/generated/img/characters/{file}.png'),direction,'walk',index)))
            gif(groups,dest/f'walk_{direction}.gif');sections.append(f'<h3>行走 {label} · {verdict["status"]}</h3><img src="walk_{direction}.gif"><p>{html.escape(verdict["reason"])}</p>')
        fs=load_frames(source,0);f=fs[min(1,len(fs)-1)] if fs else None;b=f.getbbox() if f else None
        proportion={'status':'待人工头部锚点','gojo_height_px':gh,'height_px':b[3]-b[1] if b else None,'cell':f.size if f else None,'height_occupancy':round((b[3]-b[1])/f.height,3) if b else None,'sole_y':b[3]-1 if b else None,'head_body_ratio':None,'note':'外接框含武器发饰；不以半格分区伪造头身比。非人形/武器形态需特殊体型审批。'}
        if n in [8,9,14,26]:idle='代码定帧：运行时wait第0帧，待机偏少；建议放开循环前先修帧/落脚。'
        else:idle=rs['walk']['verdict']['reason']
        bad=[label for label,r in rs.items() if r['verdict']['status']!='初判接近'];wb=[label for label,r in wr.items() if r['verdict']['status']!='初判接近']
        advice='先人工标头/手/双脚复核 '+','.join(bad)+'；确认后改帧，别用整帧左右平移制造呼吸。' if bad else '关键动作分区接近，补人工锚点确认语义与比例。'
        if n in [8,9,14,26]:advice=idle+advice
        row=dict(number=n,name=entry['name'],source=entry['source'],walk_source=walkrel,source_scope='T124登记素材；行走暂按本体共用，形态接线待复核',battle=rs,walk=wr,proportion=proportion,idle_note=idle,repair=advice)
        rows.append(row)
        content=f'<h1>{entry["name"]}</h1><p>初判，不能据此宣布合格。按每动作对任一参照整套指标匹配，未拼包络。动图150ms仅观察，逐帧资源展示原动作全部可用帧的前4个。</p><h2>比例 vs 五条悟</h2><pre>{html.escape(json.dumps(proportion,ensure_ascii=False,indent=2))}</pre><h2>动作 vs 狗逍遥／里德</h2><p>{html.escape(idle)}</p>'+''.join(sections)+f'<h2>修复建议</h2><p>{html.escape(advice)}</p>'
        (dest/'index.html').write_text(page(content))
    action_names={'walk':'待机','damage':'受击','thrust':'刺','swing':'挥','skill':'技能','victory':'胜利','dead':'倒地'}
    for r in rows:
        issues=[]
        for key,x in r['battle'].items():
            v=x['verdict']
            if v.get('severity',0)>1:issues.append((v['severity'],action_names[key]+': '+v['short_reason']))
        for key,x in r['walk'].items():
            v=x['verdict']
            if v.get('severity',0)>1:issues.append((v['severity'],'行走'+key+': '+v['short_reason']))
        if r['number'] in [8,9,14,26]:issues.append((999,'待机代码定帧：没有呼吸循环，修帧后放开wait循环'))
        issues.sort(reverse=True)
        r['top_issues']=[text for score,text in issues[:3]]
        score=max((value for value,text in issues),default=0)
        r['overall']='要修' if score>2 else '轻微' if score>1 else '好'
        r['max_severity']=score
    rows.sort(key=lambda r:(-r['max_severity'],r['number']))
    (out/'triage.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    summary=['<h1>T127 新角色动作初判</h1><p>范围：Actors 169～179（11角色，含形态共19组），不含米拉、渡鸦、五条悟、萨姆及旧云裳。五条悟只作比例基准。门槛=两参照同指标差值+max(0.5px,较小参照25%)，保证两参照互比通过。每动作仍匹配一位参照完整向量，不拼指标包络。“好”仅代表自动初判接近；比例、形态行走接线和人体锚点待核。</p>']
    table=[]
    for r in rows:
        details='；'.join(r['top_issues']) or '动作跨度接近参照，待人工确认语义'
        line=f'{r["name"]}：{r["overall"]}；{details}'
        summary.append(f'<article><h2><a href="actor_{r["number"]:02}/index.html">{r["name"]} · {r["overall"]}</a></h2><p>{html.escape(details)}</p></article>');table.append(line)
    (out/'总表.html').write_text(page(''.join(summary)))
    font=ImageFont.truetype(FONT,13);image=Image.new('RGB',(390,110+len(rows)*133),(245,246,249));d=ImageDraw.Draw(image)
    d.text((8,8),'T127 新角色动作总评（自动初判）',font=font,fill='black');d.text((8,30),'Actors169～179 · 11角色/19组 · 人工复核待续',font=font,fill='black');d.text((8,52),'仅列最严重≤3项；人体锚点/比例仍待核',font=font,fill='black')
    for i,r in enumerate(rows):
        y=90+i*133;color='#b42318' if r['overall']=='要修' else '#b54708' if r['overall']=='轻微' else '#177245'
        d.text((8,y),r['name']+' · '+r['overall'],font=font,fill=color)
        for j,text in enumerate(r['top_issues']):
            # Wrap by rendered width, not byte count.
            parts=['']
            for char in text:
                if d.textlength(parts[-1]+char,font=font)>372:parts.append('')
                parts[-1]+=char
            for k,line in enumerate(parts[:2]):d.text((8,y+22+j*34+k*15),line,font=font,fill='#344054')
    image.quantize(colors=80).save(out/'手机初判总表.png',optimize=True)
    assert (out/'手机初判总表.png').stat().st_size<=400000
    print('rows',len(rows),'mobile bytes',(out/'手机初判总表.png').stat().st_size)
    print('\n'.join(table))


def page(content):return '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><style>body{font:16px sans-serif;margin:12px;max-width:760px;background:#f5f6f9;color:#182230}img{max-width:100%;image-rendering:pixelated}pre{white-space:pre-wrap}article{border-top:1px solid #999}a{color:#175cd3}</style>'+content

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--project',type=Path,required=True);p.add_argument('--manifest',type=Path,required=True);p.add_argument('--out',type=Path,required=True);main(p.parse_args())
