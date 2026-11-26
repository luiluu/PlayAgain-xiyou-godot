#!/usr/bin/env python3
"""天启篇漏项扫描.py 单元测试（T524）。"""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("leak_scan", HERE / "天启篇漏项扫描.py")
SCAN = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(SCAN)


class TestLeakScanner(unittest.TestCase):
    def test_class_a_detects_residual_and_duplicate(self) -> None:
        skills = {
            1: {"id": 1, "name": "测试漏删", "note": "<SkillPass10:200%>"},
            2: {"id": 2, "name": "测试同名冲突", "note": "<ConsumeReduceZj: 75%>"},
            3: {"id": 3, "name": "测试已清", "note": "<SkillPass10:200%>"},
        }
        armors = {
            10: {"id": 10, "name": "测试装备", "note": "<passiveHarmRi:999%>\n<passiveCrHarmRi:999%>"},
        }
        states = {
            20: {"id": 20, "name": "测试状态", "note": "<passiveHarmRe01:2500>"},
        }
        eff_sr = {
            "skills": {
                "1": {"actor": 1, "name": "测试漏删"},
                "2": {"actor": 1, "name": "测试同名冲突", "note_add": "<ConsumeReduceZj: 20%>"},
                "3": {"actor": 1, "name": "测试已清", "note_remove": ["SkillPass\\d+"]},
            },
            "gear": {
                "armor:10": {"name": "测试装备"},
            },
            "states": {
                "20": {"name": "测试状态"},
            },
        }
        res = SCAN.scan_class_a(eff_sr, {}, skills, states, armors, {}, min_pct=50.0)
        unex_ids = {(r["section"], r["id"]) for r in res["residuals"] if r["status"] == "unexempted"}
        self.assertEqual(unex_ids, {("skills", "1"), ("skills", "2"), ("gear", "armor:10"), ("states", "20")})
        self.assertEqual(len(res["duplicates"]), 1)
        self.assertEqual(res["duplicates"][0]["id"], "2")

    def test_class_b_detects_ce_taught_unreworked_skill(self) -> None:
        skills = {
            100: {"id": 100, "name": "起始技能", "stypeId": 1, "effects": [{"code": 44, "dataId": 1}], "note": ""},
            101: {"id": 101, "name": "隐藏超蓝", "stypeId": 1, "effects": [{"code": 21, "dataId": 50}], "note": ""},
        }
        states = {
            50: {"id": 50, "name": "超蓝", "traits": [{"code": 21, "dataId": 2, "value": 6.0}], "note": ""},
        }
        actors = {10: {"id": 10, "name": "测试角色", "classId": 1, "traits": []}}
        classes = {1: {"id": 1, "learnings": [{"level": 1, "skillId": 100}], "traits": []}}
        ces = {
            1: {
                "id": 1,
                "name": "升级链",
                "list": [{"code": 318, "indent": 0, "parameters": [0, 10, 0, 101]}],
            }
        }
        eff_sr = {
            "tiers": {"强者": [10], "不开放": []},
            "skills": {"100": {"actor": 10, "name": "起始技能"}},
            "states": {},
            "learn": {},
        }
        res = SCAN.scan_class_b(eff_sr, {}, {}, {}, skills, states, actors, classes, ces)
        self.assertEqual(res["group_count"], 1)
        self.assertEqual(res["high_risk_groups"], 1)
        self.assertEqual(res["groups"][0]["taught"][0]["id"], 101)

    def _b_fixture(self):
        skills = {
            100: {"id": 100, "name": "起始技能", "stypeId": 1, "effects": [{"code": 44, "dataId": 1}], "note": ""},
            101: {"id": 101, "name": "高危招", "stypeId": 1, "effects": [], "note": "<SkillPass5:300%>"},
            102: {"id": 102, "name": "被删的入口", "stypeId": 1, "effects": [{"code": 44, "dataId": 3}, {"code": 44, "dataId": 4}], "note": ""},
            103: {"id": 103, "name": "功法", "stypeId": 4, "effects": [], "note": "<SkillPass5:300%>"},
            104: {"id": 104, "name": "号卷", "stypeId": 4, "effects": [], "note": "<SkillPass5:300%>"},
        }
        actors = {10: {"id": 10, "name": "测试角色", "classId": 1, "traits": []}}
        classes = {1: {"id": 1, "learnings": [{"level": 1, "skillId": 100}], "traits": []}}
        learn = lambda sid: {"code": 318, "indent": 0, "parameters": [0, 10, 0, sid]}
        ces = {
            # 1：起始技能调用，再 117 调 2
            1: {"id": 1, "name": "入口", "trigger": 0, "list": [{"code": 117, "indent": 0, "parameters": [2]}]},
            # 2：只经公共事件 1 到达（117 传递）
            2: {"id": 2, "name": "子事件", "trigger": 0, "list": [learn(101)]},
            # 3：调用方只有被删掉的 102 → 不可达，进 dropped
            3: {"id": 3, "name": "删掉的分支", "trigger": 0, "list": [learn(101)]},
            # 4：102 被删，但地图事件也调 → 仍可达
            4: {"id": 4, "name": "地图也调", "trigger": 0, "list": [learn(101)]},
            # 5：全队学、脚本变量目标学 → 人工核对
            5: {"id": 5, "name": "全队", "trigger": 0, "list": [
                {"code": 318, "indent": 0, "parameters": [0, 0, 0, 101]},
                {"code": 355, "indent": 0, "parameters": ["var actor = $gameActors.actor($gameVariables.value(9));"]},
                {"code": 655, "indent": 0, "parameters": ["actor.learnSkill(101);"]},
            ]},
            # 6：脚本写死角色 10 → 归到角色组；功法、号卷已改写不报
            6: {"id": 6, "name": "脚本写死", "trigger": 0, "list": [
                {"code": 355, "indent": 0, "parameters": ["var a = $gameActors.actor(10);"]},
                {"code": 655, "indent": 0, "parameters": ["a.learnSkill(101); a.learnSkill(103); a.learnSkill(104);"]},
            ]},
        }
        maps = {7: {"events": [None, {"id": 1, "pages": [{"list": [{"code": 117, "indent": 0, "parameters": [4]}, {"code": 117, "indent": 0, "parameters": [5]}, {"code": 117, "indent": 0, "parameters": [6]}]}]}]}}
        eff_sr = {
            "tiers": {"强者": [10], "不开放": []},
            "skills": {"100": {"actor": 10}, "102": {"actor": 10, "effects_remove": [[44, 3], [44, 4]]}},
            "states": {},
            "learn": {},
        }
        sb = {"skills": {"103": {"skill": 103}}}
        trumpet = {"scrolls": [{"skill": 104}]}
        return SCAN.scan_class_b(eff_sr, {}, sb, trumpet, skills, {}, actors, classes, ces, {}, {}, maps)

    def test_class_b_ce_transitive_and_dropped(self) -> None:
        res = self._b_fixture()
        by_ce = {g["ce_id"]: g for g in res["groups"]}
        self.assertIn(2, by_ce)
        self.assertEqual(by_ce[2]["reach"], "reachable")
        self.assertEqual(by_ce[2]["trigger_kind"], "via_common_event")
        self.assertIn(4, by_ce)  # 被删的技能调过，但地图也调：不能丢
        self.assertEqual(by_ce[4]["reach"], "reachable")
        self.assertNotIn(3, by_ce)
        self.assertEqual([g["ce_id"] for g in res["dropped"]], [3])  # 略过的也列出来

    def test_class_b_script_party_variable_go_manual(self) -> None:
        res = self._b_fixture()
        manual = {(m["ce_id"], m["target"]) for m in res["manual"]}
        self.assertIn((5, "318 全队"), manual)
        self.assertTrue(any(ce == 5 and t.startswith("脚本") for ce, t in manual))
        by_ce = {g["ce_id"]: g for g in res["groups"]}
        self.assertIn(6, by_ce)  # 脚本写死角色号 → 归到角色
        self.assertEqual([t["id"] for t in by_ce[6]["taught"]], [101])  # 功法（secret_books.skills）、号卷（trumpet.scrolls[].skill）已改写不报

    def test_class_a_atkst_benign_only_when_state_reworked(self) -> None:
        skills = {
            1: {"id": 1, "name": "附加已改写", "note": "<passiveATKST1519:100%>"},
            2: {"id": 2, "name": "附加没改写", "note": "<passiveATKST20:100%>"},
        }
        eff_sr = {"skills": {"1": {"actor": 1}, "2": {"actor": 1}}, "states": {"1519": {"name": "封弊"}}}
        res = SCAN.scan_class_a(eff_sr, {}, skills, {}, {}, {}, min_pct=50.0)
        st = {r["id"]: r["status"] for r in res["residuals"]}
        self.assertEqual(st, {"1": "benign", "2": "unexempted"})

    def _ext_fixture(self):
        """小o R2 复核的 8 条扩展夹具（原样移植）。"""
        skills = {k: {"id": k, "note": "<SkillPass5:300%>", "effects": []} for k in range(100, 107)}
        skills[100]["effects"] = [{"code": 44, "dataId": k} for k in (1, 5, 9)]
        setup = {
            "tiers": {"强者": [10], "不开放": [11]},
            "skills": {"100": {"actor": 10, "effects_remove": [[44, 5], [44, 9]], "effects_add": [{"code": 44, "dataId": 9}]}},
        }
        actors = {k: {"id": k, "classId": 1} for k in (10, 11)}
        classes = {1: {"learnings": [{"level": 1, "skillId": 100}]}}

        def cmd(c, *p):
            return {"code": c, "indent": 0, "parameters": list(p)}

        ces = {
            1: [cmd(117, 5), cmd(117, 2), cmd(117, 6), cmd(117, 7), cmd(117, 8)],
            2: [cmd(318, 0, 10, 0, 101)],
            3: [cmd(318, 0, 0, 0, 101)],
            4: [cmd(318, 1, 9, 0, 101)],
            5: [cmd(318, 0, 10, 0, 101)],
            6: [cmd(355, "var a = $gameActors.actor(10);"), cmd(655, "a.learnSkill(101); a.learnSkill(103); a.learnSkill(104);")],
            7: [cmd(355, "var actor = $gameActors.actor(11); var actor = $gameActors.actor($gameParty._targetActorId);"), cmd(655, "actor.learnSkill(101);")],
            8: [cmd(355, "var actor = $gameActors.actor($gameParty._targetActorId); var k = 101;"), cmd(655, "actor.learnSkill(k);")],
            9: [cmd(318, 0, 10, 0, 101)],
            10: [cmd(117, 11)],
            11: [cmd(318, 0, 10, 0, 101)],
            12: [cmd(318, 0, 10, 0, 101)],
            13: [cmd(318, 0, 10, 0, 101)],
        }
        ces = {k: {"id": k, "list": v} for k, v in ces.items()}
        items = {19: {"effects": [{"code": 44, "dataId": 12}]}}
        troops = {1: {"pages": [{"list": [cmd(355, "$gameTemp.reserveCommonEvent(13);")]}]}}
        return SCAN.scan_class_b(
            setup, {}, {"skills": {"103": {"skill": 103}}}, {"scrolls": [{"skill": 104}]},
            skills, {}, actors, classes, ces, items, troops, {},
        )

    def test_class_b_extended_fixtures_xiaoo_r2(self) -> None:
        actual = self._ext_fixture()
        groups = {g["ce_id"]: g for g in actual["groups"]}
        manual_ces = {g["ce_id"] for g in actual["manual"]}
        with self.subTest("117 普通及被删直接入口且另有活父事件"):
            self.assertTrue({2, 5} <= set(groups))
        with self.subTest("318 全队、变量目标"):
            self.assertTrue({3, 4} <= manual_ces)
        with self.subTest("脚本固定、功法与号卷过滤"):
            self.assertEqual([t["id"] for t in groups[6]["taught"]], [101])
        with self.subTest("物品根、敌群脚本调用根"):
            self.assertTrue({12, 13} <= set(groups))
        with self.subTest("混合目标至少列人工核对"):
            self.assertIn(7, manual_ces)
            self.assertNotIn(7, groups)
        with self.subTest("技能号变量至少列人工核对"):
            self.assertIn(8, manual_ces)
        with self.subTest("先删后加同一效果仍然可达"):
            self.assertEqual(groups[9]["reach"], "reachable")
        with self.subTest("没有查到入口的父事件只标未证实"):
            self.assertEqual(groups[11]["reach"], "parent_unconfirmed")
            self.assertIn((10, 11, "parent_unconfirmed"), actual["no_caller"])
        with self.subTest("什么都不静默丢"):
            self.assertEqual(actual["dropped"], [])

    def test_class_b_cycle_and_unresolvable_expr_go_manual(self) -> None:
        skills = {
            100: {"id": 100, "note": "", "effects": [{"code": 44, "dataId": 3}]},
            101: {"id": 101, "note": "<SkillPass5:300%>", "effects": []},
            102: {"id": 102, "note": "<CodexTestTag>", "effects": []},
        }
        actors = {10: {"id": 10, "classId": 1}}
        classes = {1: {"learnings": [{"level": 1, "skillId": 100}]}}

        def cmd(c, *p):
            return {"code": c, "indent": 0, "parameters": list(p)}

        ces = {
            # 1、2 互调成环、外面没人调：不能判 dropped
            1: [cmd(117, 2), cmd(318, 0, 10, 0, 101)],
            2: [cmd(117, 1)],
            # 3：起始技能调；脚本里技能号是函数返回值 → 追不到；按备注标签 filter 出来的 → 还原成 102
            3: [
                cmd(355, "var a = $gameActors.actor(10); a.learnSkill(pick());"),
                cmd(355, "var hh=$dataSkills.filter(function(s){return s&&/<CodexTestTag>/.test(s.note);})[0];"),
                cmd(655, "for(var j=1;j<$dataActors.length;j++){$gameActors.actor(j).learnSkill(hh.id);}"),
            ],
        }
        ces = {k: {"id": k, "list": v} for k, v in ces.items()}
        eff_sr = {"tiers": {"强者": [10], "不开放": []}, "skills": {"100": {"actor": 10}}}
        res = SCAN.scan_class_b(eff_sr, {}, {}, {}, skills, {}, actors, classes, ces, {}, {}, {})
        groups = {g["ce_id"]: g for g in res["groups"]}
        self.assertEqual(groups[1]["reach"], "parent_unconfirmed")
        self.assertEqual(res["dropped"], [])
        m3 = [m for m in res["manual"] if m["ce_id"] == 3]
        taught = {(t["id"], t["dynamic_expr"]) for m in m3 for t in m["taught"]}
        self.assertIn((None, "pick()"), taught)  # 追不到也列出来
        self.assertIn((102, "hh.id"), taught)  # 洪荒补强同款写法能还原
        self.assertTrue(all(m["reach"] == "reachable" for m in m3))

    def test_real_repo_ce1445_honghuang_listed(self) -> None:
        import contextlib
        import io
        import json

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            SCAN.main(["--json"])
        res = json.loads(buf.getvalue())
        ids = {t["id"] for m in res["class_b"]["manual"] if m["ce_id"] == 1445 for t in m["taught"]}
        self.assertIn(10300, ids)  # learnSkill(hh.id)＝洪荒压制，不能漏

    def test_real_repo_strict_passes(self) -> None:
        rc = SCAN.main(["--strict", "--json"])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
