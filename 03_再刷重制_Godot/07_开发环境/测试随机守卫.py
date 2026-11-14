#!/usr/bin/env python3
"""随机守卫.py 的回归：全局 randf／randi／randomize／shuffle／pick_random／fresh_seed、没定种子的 RandomNumberGenerator 都报；
注了「# 表现」「# 随机守卫：理由」的、带「.」的流方法、注释和字符串里的、函数定义、真工程现状不报。"""
import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('guard', HERE / '随机守卫.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class GuardTests(unittest.TestCase):
    def errs(self, code):
        return guard.check_text(code, 'x.gd')

    def test_reports_global(self):
        for line in ['\tvar r := randf()', '\tvar i := randi() % 3', '\tvar k = randi_range(0, 2)', '\trandomize()', '\tseed(5)',
                     '\tvar f = randf_range(0.0, 1.0)', '\tvar g = randfn(0.0, 1.0)', '\trng.randomize()',
                     '\tarr.shuffle()', '\tvar p = arr.pick_random()', '\tvar h := XRandomStream.fresh_seed()']:
            self.assertEqual(len(self.errs(line)), 1, line)

    def test_unseeded_rng(self):
        self.assertEqual(len(self.errs('\tvar rng := RandomNumberGenerator.new()\n\tvar x := rng.randf()')), 1)
        self.assertEqual(self.errs('\tvar rng := RandomNumberGenerator.new()\n\trng.seed = 3'), [])
        # 中间先做与发生器无关的事（抽奖流先取存档字段）不算
        self.assertEqual(self.errs('\tvar rng := RandomNumberGenerator.new()\n\tvar saved := s.x\n\tif a:\n\t\trng.seed = 1\n\telse:\n\t\trng.seed = 2'), [])

    def test_allowed(self):
        for line in ['\tvar r := randf()  # 表现', '\tvar r := randf()  # 随机守卫：开关关时的旧路', '\tvar r := st.next_float("k")',
                     '\tvar r := rng.randf()', '\t# randf() 只在注释里', '\tvar t := "randf() 在字符串里"', 'static func seed(s) -> int:',
                     '\tvar n := XRandomStream.derive(a, "b")', '\tvar my_randf := 1']:
            self.assertEqual(self.errs(line), [], line)

    # 返修（ag 甲档 P2-1）：放行只认真正的行尾注释；.seed = 按分支判断
    def test_allow_only_real_comment(self):
        self.assertEqual(len(self.errs('\tvar r := randf(); var t := "# 表现"')), 1)
        self.assertEqual(len(self.errs("\tvar r := randf(); var t := '# 随机守卫：假'")), 1)
        self.assertEqual(self.errs('\tvar r := randf(); var t := "# x"  # 表现'), [])

    def test_seed_per_branch(self):
        one_branch = '\tvar rng := RandomNumberGenerator.new()\n\tif ok:\n\t\trng.seed = 3\n\tvar x := rng.randf()'
        self.assertEqual(len(self.errs(one_branch)), 1)
        no_seed_else = ('\tvar rng := RandomNumberGenerator.new()\n\tif ok:\n\t\trng.seed = 3\n\telse:\n\t\tpass\n'
                        '\tvar x := rng.randf()')
        self.assertEqual(len(self.errs(no_seed_else)), 1)
        both = ('\tvar rng := RandomNumberGenerator.new()\n\tif ok:\n\t\trng.seed = 3\n\telif b:\n\t\trng.seed = 4\n'
                '\telse:\n\t\trng.randomize()  # 随机守卫：开关关时的旧路\n\tvar x := rng.randf()')
        self.assertEqual(self.errs(both), [])
        loop = '\tvar rng := RandomNumberGenerator.new()\n\tfor k in 4:\n\t\trng.seed = k\n\t\tvar x := rng.randf()'
        self.assertEqual(self.errs(loop), [])
        late = '\tvar rng := RandomNumberGenerator.new()\n\tvar x := rng.randf()\n\trng.seed = 3'
        self.assertEqual(len(self.errs(late)), 1)

    # 返修（ag 甲档 P2-2）：.new() 后紧跟注了「# 表现」的 randomize 不误报；三引号多行字符串里的 randf() 不误报
    def test_new_then_annotated_randomize(self):
        self.assertEqual(self.errs('\tvar rng := RandomNumberGenerator.new()\n\trng.randomize()  # 表现\n\tvar x := rng.randf()'), [])

    def test_triple_quoted(self):
        self.assertEqual(self.errs('\tvar doc := """说明：\n不要用 randf() 或 arr.shuffle()\n"""\n\tvar y := 1'), [])
        self.assertEqual(self.errs("\tvar doc := '''\nrandi()\n'''"), [])
        self.assertEqual(len(self.errs('\tvar doc := """一行"""\n\tvar r := randf()')), 1)

    def test_scope(self):
        fs = guard.files()
        self.assertIn('modes/xiyou/core/tianqi_random.gd', fs)
        self.assertIn('modes/xiyou/core/tianqi_save.gd', fs)
        self.assertIn('modes/xiyou/core/gojo.gd', fs)
        self.assertIn('modes/xiyou/core/lottery_rework.gd', fs)

    def test_project_clean(self):
        self.assertEqual(guard.check(), [])


if __name__ == '__main__':
    unittest.main()
