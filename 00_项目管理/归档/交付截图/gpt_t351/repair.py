"""T351: restore only erased opaque crotch pixels above the split boot shafts.
Usage: python repair.py SOURCE PRE_T122 OUTPUT; python repair.py --validate BEFORE AFTER
Requires Pillow. No generated colours or interpolation.
"""
import sys,json
from PIL import Image,ImageDraw
if sys.argv[1]=='--validate':
 b,a=map(lambda p:Image.open(p).convert('RGBA'),sys.argv[2:])
 changed=[]
 for y in range(384):
  for x in range(576):
   if b.getpixel((x,y))!=a.getpixel((x,y)):
    assert x//64<3 and 21<=x%64<=32 and 51<=y<=53
    assert b.getpixel((x,y))[3]==0 and a.getpixel((x,y))[3]==255
    changed.append([x,y])
 for i in range(54):
  x,y=i%9*64,i//9*64
  assert b.crop((x,y,x+64,y+64)).getbbox()==a.crop((x,y,x+64,y+64)).getbbox()
 assert set(a.getchannel("A").getdata()) == {0,255}
 assert list(a.crop((0,60,576,61)).getdata())==list(b.crop((0,60,576,61)).getdata())
 print('PASS: 54 bounds, upper body/tail/sole unchanged; restored pixels',len(changed))
else:
 b,o=map(lambda p:Image.open(p).convert('RGBA'),sys.argv[1:3]);a=b.copy()
 for f in range(3):
  for y in range(51,54):
   for x in range(21,33):
    p=(64*f+x,y)
    if not b.getpixel(p)[3] and o.getpixel(p)[3]:a.putpixel(p,o.getpixel(p))
 a.save(sys.argv[3])
