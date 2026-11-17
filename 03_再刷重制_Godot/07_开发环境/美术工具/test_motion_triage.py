import unittest
from motion_triage import compare

def metric(values):
    return {'bands':{k:{'span_xy':values[i:i+2]} for k,i in [('head_band',0),('left_hand_band',2),('right_hand_band',4),('whole',6)]},'sole_span_xy':[0,values[8]]}

class TriageTests(unittest.TestCase):
    def test_references_pass_each_other(self):
        a=metric([0,1,0,0,0,0,0,1,0]);b=metric([8,2,3,2,4,1,7,6,2]);refs=[('a',a),('b',b)]
        for ref in [a,b]:self.assertEqual(compare(ref,refs)['status'],'初判接近')
    def test_large_idle_horizontal_drift_is_repair(self):
        a=metric([.13,1.06,.1,0,.1,0,.1,1,0]);b=metric([.05,1.18,.2,0,.2,0,.1,1,0])
        c=metric([1.9,1.18,.2,0,.2,0,.1,1,0])
        self.assertGreater(compare(c,[('a',a),('b',b)])['severity'],2)
    def test_no_axis_envelope(self):
        a=metric([0,8,0,0,0,0,0,0,0]);b=metric([8,0,0,0,0,0,0,0,0])
        r=compare(metric([0,0,0,0,0,0,0,0,0]),[('a',a),('b',b)])
        self.assertIn(r['reference'],['a','b'])
        self.assertEqual(len(r['attempts']),2)
        # Each attempt keeps one whole reference; no per-axis source selection.
        self.assertGreater(r['severity'],0)

if __name__=='__main__':unittest.main()
