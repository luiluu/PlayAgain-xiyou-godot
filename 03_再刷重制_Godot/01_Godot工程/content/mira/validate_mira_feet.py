from PIL import Image,ImageDraw,ImageChops
from pathlib import Path
import json
root=Path(__file__).resolve().parent/'img/sv_actors'
e=Path(__file__).resolve().parents[4]/'00_项目管理/归档/交付截图/gpt_mira-feet/T122'
b=Image.open(e/'before.png').convert('RGBA');a=Image.open(root/'Codex_Mira_SV_u2.png').convert('RGBA')
def bg(im):
 out=Image.new('RGBA',im.size,'#40404a');out.alpha_composite(im);return out.convert('RGB')
for scale in (1,4):
 c=Image.new('RGB',(576*scale,384*scale*2+24),'#40404a');d=ImageDraw.Draw(c)
 c.paste(bg(b).resize((576*scale,384*scale),Image.Resampling.NEAREST),(0,12));c.paste(bg(a).resize((576*scale,384*scale),Image.Resampling.NEAREST),(0,384*scale+24));d.text((0,0),'BEFORE');d.text((0,384*scale+12),'AFTER');c.save(e/f'comparison_{scale}x.png')
frames=[]
for i in (0,1,2,1):
 im=Image.new('RGB',(512,280),'#40404a');d=ImageDraw.Draw(im);d.text((0,0),'BEFORE');d.text((256,0),'AFTER')
 for k,s in enumerate((b,a)):
  im.paste(bg(s.crop((i*64,0,i*64+64,64))).resize((256,256),Image.Resampling.NEAREST),(k*256,24))
 frames.append(im)
frames[0].save(e/'idle_comparison_4x.gif',save_all=True,append_images=frames[1:],duration=200,loop=0)
report={'size':a.size,'alpha':sorted(set(a.getchannel('A').getdata())),'palette_subset':set(a.getdata())<=set(b.getdata()),'frames':[],'changed_pixels':0}
for y in range(384):
 for x in range(576):
  if a.getpixel((x,y))!=b.getpixel((x,y)):
   assert y in range(51,61) and x//64<3 and x%64 in range(17,36),(x,y)
   report['changed_pixels']+=1
assert report['alpha'] == [0,255] and report['palette_subset']
for frame in range(3):
 assert a.getpixel((frame*64+26,57))[3] == 0
 assert all(a.getpixel((frame*64+x,60))[3] == 0 for x in range(24,29))
 assert all(a.getpixel((frame*64+x,60))[3] == 255 for x in list(range(17,24))+list(range(29,34)))
for i in range(54):
 x=(i%9)*64;y=(i//9)*64
 old=b.crop((x,y,x+64,y+64));new=a.crop((x,y,x+64,y+64))
 assert old.getbbox()==new.getbbox(),i
 report['frames'].append({'cell':[i%9,i//9],'before_bbox':old.getbbox(),'after_bbox':new.getbbox()})
(e/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print('PASS all 54 bboxes, only permitted leg pixels changed',report['changed_pixels'])
