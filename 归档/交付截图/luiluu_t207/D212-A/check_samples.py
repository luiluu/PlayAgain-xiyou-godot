"""Run unchanged sprite checker on native 340x280 single-frame samples.
Each sample is repeated 3 times only to match checker input structure;
this checks image integrity, not animation. Only canvas and baseline config adapt.
"""
from pathlib import Path
from PIL import Image
import json,subprocess,sys
p=Path(__file__).resolve().parent; root=p.parents[3]
tool=root/'03_再刷重制_Godot/07_开发环境/精灵自检.py'
cfg=json.loads(tool.with_name('精灵自检阈值.json').read_text())
cfg['idle_sheet_size']=[1020,280];cfg['idle_baseline']={'bottom':217,'tolerance':0}
cfg['说明']='T207 single-frame dragon geometry adaptation: only canvas and bottom anchor changed; all defect thresholds/severities unchanged. Repeated single image is not animation verification.'
(p/'dragon-native-config.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2))
rc=0
for name in ['14_0','15_0','7_2']:
 src=p/(name+'-native.png')
 if not src.exists():continue
 im=Image.open(src).convert('RGBA');sheet=Image.new('RGBA',(1020,280))
 for i in range(3):sheet.paste(im,(340*i,0))
 f=p/(name+'-check-strip.png');sheet.save(f)
 args=[sys.executable,str(tool),'--name','T207_'+name,'--idle',str(f),'--config',str(p/'dragon-native-config.json'),'--out',str(p/('check-'+name)),'--show-passed']
 r=subprocess.run(args,capture_output=True,text=True);(p/(name+'-check.log')).write_text(r.stdout+r.stderr);print(name,'EXIT',r.returncode);print(r.stdout);rc=max(rc,r.returncode)
sys.exit(rc)
