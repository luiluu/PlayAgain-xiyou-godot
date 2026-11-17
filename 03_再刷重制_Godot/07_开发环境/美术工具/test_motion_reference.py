import unittest
from PIL import Image
from motion_reference import frames,measure

class MotionReferenceTests(unittest.TestCase):
    def test_mv_column_blocks(self):
        im=Image.new('RGBA',(90,60))
        for m in range(18):
            for k in range(3):
                im.paste((m+1,k+1,0,255),((m//6*3+k)*10,m%6*10,(m//6*3+k+1)*10,(m%6+1)*10))
        for m in range(18):
            self.assertEqual([f.getpixel((0,0))[:2] for f in frames(im,m)],[(m+1,k+1) for k in range(3)])
    def test_walk_character_six(self):
        im=Image.new('RGBA',(120,80));im.paste((9,0,0,255),(60,60,90,70))
        self.assertEqual(frames(im,2,'walk',6)[0].getpixel((0,0)),(9,0,0,255))
    def test_known_translation(self):
        fs=[]
        for dx,dy in [(0,0),(1,1),(0,0)]:
            f=Image.new('RGBA',(16,16));f.paste('white',(3+dx,2+dy,6+dx,5+dy));fs.append(f)
        r=measure(fs)
        self.assertEqual(r['bands']['head_band']['span_xy'],[1,1])
        self.assertEqual(r['sole_span_xy'],[1,1])
    def test_empty_is_not_pass(self):
        self.assertEqual(measure([Image.new('RGBA',(16,16))]*3)['status'],'empty')

if __name__=='__main__':unittest.main()
