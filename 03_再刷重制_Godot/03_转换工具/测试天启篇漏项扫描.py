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

    def _r3_fixture(self):
        """小o R3 复核的 3 个新失败：嵌套技能参数、技能变量重赋值、变量形式的公共事件调用。"""
        skills = {
            100: {"id": 100, "note": "", "effects": [{"code": 44, "dataId": 1}, {"code": 44, "dataId": 2}]},
            101: {"id": 101, "note": "<SkillPass5:300%>", "effects": []},
            102: {"id": 102, "note": "<SkillPass5:300%>", "effects": []},
            103: {"id": 103, "note": "", "effects": [{"code": 44, "dataId": 3}]},
        }
        actors = {10: {"id": 10, "classId": 1}}
        classes = {1: {"learnings": [{"level": 1, "skillId": 100}]}}

        def cmd(c, *p):
            return {"code": c, "indent": 0, "parameters": list(p)}

        ces = {
            # 1：参数套两层括号，旧正则整句匹配不到 → 静默漏
            1: [cmd(355, "var a = $gameActors.actor(10);"), cmd(655, "a.learnSkill(Number(String(101)));")],
            # 2：k 先赋 101 再 += 1（实际学 102），旧逻辑只认一次赋值 → 报成 101、漏 102
            2: [cmd(355, "var a = $gameActors.actor(10); var k = 101; k += 1;"), cmd(655, "a.learnSkill(k);")],
            # 3：调用方只有被删的 103，但地图脚本用变量调公共事件 → 不能证实删掉
            3: [cmd(318, 0, 10, 0, 101)],
        }
        ces = {k: {"id": k, "list": v} for k, v in ces.items()}
        maps = {7: {"events": [None, {"id": 1, "pages": [{"list": [
            cmd(355, "$gameTemp.reserveCommonEvent($gameVariables.value(5));"),
        ]}]}]}}
        eff_sr = {
            "tiers": {"强者": [10], "不开放": []},
            "skills": {"100": {"actor": 10}, "103": {"actor": 10, "effects_remove": [[44, 3]]}},
        }
        return SCAN.scan_class_b(eff_sr, {}, {}, {}, skills, {}, actors, classes, ces, {}, {}, maps)

    def test_class_b_xiaoo_r3_fixtures(self) -> None:
        res = self._r3_fixture()
        groups = {g["ce_id"]: g for g in res["groups"]}
        manual = [m for m in res["manual"]]
        with self.subTest("嵌套技能参数不漏"):
            listed = {(t["id"], t["dynamic_expr"]) for m in manual if m["ce_id"] == 1 for t in m["taught"]}
            listed |= {(t["id"], "") for t in groups.get(1, {}).get("taught", [])}
            self.assertTrue(listed, "CE1 的 learnSkill(Number(String(101))) 一条都没报")
            self.assertTrue(any(i in (101, None) for i, _ in listed))
        with self.subTest("技能变量重赋值不报成首次赋值"):
            t2 = [t for m in manual if m["ce_id"] == 2 for t in m["taught"]]
            self.assertTrue(t2, "CE2 没进人工核对")
            self.assertEqual([(t["id"], t["dynamic_expr"]) for t in t2], [(None, "k")])
            self.assertNotIn(2, groups)
        with self.subTest("变量形式的公共事件调用 → 不判删掉"):
            self.assertEqual(res["dropped"], [])
            self.assertIn(3, groups)
            self.assertEqual(groups[3]["reach"], "dynamic_call_possible")
            self.assertIn((10, 3, "dynamic_call_possible"), res["no_caller"])

    def test_script_helpers_loop_var_and_comment(self) -> None:
        loop = "var a=$gameActors.actor(10); for (var k = 101; k <= 103; k++) { a.learnSkill(k); }"
        self.assertIsNone(SCAN._resolve_script_skill("k", loop, {}))
        self.assertEqual(SCAN._resolve_script_skill("k", "var k = 101; a.learnSkill(k);", {}), 101)
        self.assertIsNone(SCAN._resolve_script_skill("hh.id", "var hh=$dataSkills[101]; hh=$dataSkills[102];", {}))
        block = SCAN._script_blocks([{"code": 355, "parameters": ["// 用 learnSkill 函数学会技能"]}, {"code": 655, "parameters": ["a.learnSkill(Math.max(1, f(101)));"]}])
        self.assertEqual(SCAN._call_args(block[0], SCAN.LEARN_TOKEN_RE), [("Math.max(1, f(101))", "learnSkill(Math.max(1, f(101)));")])

    def test_class_c_all_five_channels_and_reworked_filter(self) -> None:
        skills = {
            201: {"id": 201, "name": "特性招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 20"}, "effects": [], "note": ""},
            202: {"id": 202, "name": "共享学招", "stypeId": 2, "damage": {"type": 1, "formula": "a.mat * 20 + a.mhp"}, "effects": [], "note": ""},
            203: {"id": 203, "name": "替普攻招", "stypeId": 2, "damage": {"type": 1, "formula": "a.mat * 27"}, "effects": [], "note": ""},
            204: {"id": 204, "name": "解放招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 15"}, "effects": [], "note": ""},
            205: {"id": 205, "name": "法宝领悟招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
            206: {"id": 206, "name": "已改写招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 30"}, "effects": [], "note": ""},
            207: {"id": 207, "name": "通用书已改", "stypeId": 2, "damage": {"type": 1, "formula": "a.mat * 30"}, "effects": [], "note": ""},
        }
        weapons = {
            1: {"id": 1, "name": "武器A", "traits": [{"code": 43, "dataId": 201}], "note": "<Replace Attack: 203>\n<Weapon Unleash: +10%>"},
            2: {"id": 2, "name": "武器B", "traits": [{"code": 43, "dataId": 206}], "note": "<Weapon Unleash 50%: 204>\n<Replace Attack: 207>"},
        }
        armors = {
            10: {"id": 10, "name": "防具A", "traits": [], "note": "<ShareLearnSkill:202>\n<Magic Weapon Learn Skill 205: 10, 99>"},
        }
        eff_sr = {"tiers": {"不开放": []}, "skills": {"206": {"name": "已改写招"}}, "gear": {}, "states": {}}
        gb = {"skills": {"207": {"name": "通用书已改"}}, "states": {}}
        res = SCAN.scan_class_c(eff_sr, gb, {}, {}, skills, {}, weapons, armors)
        by_id = {it["id"]: it for it in res["items"]}
        self.assertEqual(set(by_id), {201, 202, 203, 204, 205})
        self.assertEqual(res["high_risk_count"], 5)
        self.assertEqual(by_id[201]["channels"], ["trait_43"])
        self.assertEqual(by_id[202]["channels"], ["share_learn"])
        self.assertEqual(by_id[203]["channels"], ["replace_attack"])
        self.assertEqual(by_id[204]["channels"], ["weapon_unleash"])
        self.assertEqual(by_id[205]["channels"], ["magic_weapon_learn"])
        self.assertEqual(res["manual_count"], 0)
        self.assertEqual(res["dropped_count"], 0)

    def test_class_c_gear_edit_dropped_readd_and_hidden_actor(self) -> None:
        skills = {
            301: {"id": 301, "name": "被移除特性招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
            302: {"id": 302, "name": "先删后加招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
            303: {"id": 303, "name": "被移除替普攻", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
            304: {"id": 304, "name": "不开放专属招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
            305: {"id": 305, "name": "混合专属招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
        }
        weapons = {
            1: {"id": 1, "name": "改写武器", "traits": [{"code": 43, "dataId": 301}, {"code": 43, "dataId": 302}], "note": "<Replace Attack: 303>"},
            2: {"id": 2, "name": "不开放武器", "traits": [], "note": "<req_actors: 99>\n<Replace Attack: 304>"},
            3: {"id": 3, "name": "混合武器", "traits": [], "note": "<req_actors: 10, 99>\n<Replace Attack: 305>"},
        }
        eff_sr = {
            "tiers": {"强者": [10], "不开放": [99]},
            "skills": {},
            "states": {},
            "gear": {
                "weapon:1": {
                    "traits_remove": [[43, 301], [43, 302]],
                    "traits_set": [{"code": 43, "dataId": 302, "value": 1}],
                    "note_remove": ["Replace Attack"],
                },
            },
        }
        res = SCAN.scan_class_c(eff_sr, {}, {}, {}, skills, {}, weapons, {})
        active_ids = {it["id"] for it in res["items"]}
        self.assertEqual(active_ids, {302, 305})
        dropped_keys = {(d["gear"], d["skill"]["id"], d["reason"]) for d in res["dropped"]}
        self.assertEqual(
            dropped_keys,
            {
                ("weapon:1", 301, "removed_by_skill_rework_gear"),
                ("weapon:1", 303, "removed_by_skill_rework_gear"),
                ("weapon:2", 304, "hidden_actor_only"),
            },
        )

    def test_class_c_unparseable_and_unknown_tags_go_manual(self) -> None:
        skills = {
            401: {"id": 401, "name": "普通未改招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 10"}, "effects": [], "note": ""},
        }
        weapons = {
            1: {
                "id": 1,
                "name": "奇异武器",
                "traits": [],
                "note": "<ShareLearnSkill: dynVar>\n<Replace Attack: 某技能名>\n<Weapon Unleash 50%: pick()>\n<Magic Weapon Learn Skill X: 1, 10>",
            },
            2: {
                "id": 2,
                "name": "动态专属武器",
                "traits": [],
                "note": "<req_actors: actorVar>\n<Replace Attack: 401>",
            },
        }
        armors = {
            10: {"id": 10, "name": "未知标签装", "traits": [], "note": "<learningSkill00:7770>"},
        }
        res = SCAN.scan_class_c({"tiers": {"不开放": [99]}, "skills": {}, "gear": {}, "states": {}}, {}, {}, {}, skills, {}, weapons, armors)
        channels = {(m["gear"], m["channel"]) for m in res["manual"]}
        self.assertEqual(
            channels,
            {
                ("weapon:1", "share_learn"),
                ("weapon:1", "replace_attack"),
                ("weapon:1", "weapon_unleash"),
                ("weapon:1", "magic_weapon_learn"),
                ("weapon:2", "req_actors"),
                ("armor:10", "unknown_learn_tag"),
            },
        )
        # req_actors 解析不了的武器不能静默判 dropped，招式 401 必须保留在 items
        self.assertEqual({it["id"] for it in res["items"]}, {401})
        self.assertEqual(res["dropped"], [])

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
        # T541 C 类：3624/1968/3549/995 补改写后不再出现在未改写装备招清单；未知标签 armor:5180 进 manual
        c_ids = {it["id"] for it in res["class_c"]["items"]}
        for fixed_id in (3624, 1968, 3549, 995):
            self.assertNotIn(fixed_id, c_ids)
        # T549 批 1／批 2：3650 雷行（weapon:1613 徘徊）、替换普攻 12、武器触发 127、套装伤害主动 485 都已改写，不再出现
        for fixed_id in (3650, 12, 127, 485, 3647, 6243):
            self.assertNotIn(fixed_id, c_ids)
        c_manual = {(m["gear"], m["channel"]) for m in res["class_c"]["manual"]}
        self.assertIn(("armor:5180", "unknown_learn_tag"), c_manual)
        # T549：第 6 通道（套装给技能）真库扫得到；剩下的条目逐条都有登记理由、没有未登记的
        chans = {ch for it in res["class_c"]["items"] for ch in it["channels"]}
        self.assertIn("suit_skill", chans)
        self.assertEqual(res["class_c"]["unexempted_count"], 0)
        self.assertTrue(all(it["exempt"] for it in res["class_c"]["items"]))
        # 天启篇有原版模板的套装（勇士 9 等）多件档 skills 记 dropped，不算漏项
        self.assertTrue(any(d["reason"] == "suit_template_replaced" for d in res["class_c"]["dropped"]))

    def test_class_c_suit_channel_and_registry(self) -> None:
        skills = {
            501: {"id": 501, "name": "套装招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 20"}, "effects": [], "note": ""},
            502: {"id": 502, "name": "模板套多件档招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 20"}, "effects": [], "note": ""},
            503: {"id": 503, "name": "模板套一件档招", "stypeId": 1, "damage": {"type": 1, "formula": "a.atk * 20"}, "effects": [], "note": ""},
        }
        suits = {
            7: {"id": 7, "name": "无模板套", "bonuses": [{"requirePieces": 3, "skills": [501]}]},
            8: {"id": 8, "name": "有模板套", "bonuses": [{"requirePieces": 1, "skills": [503]}, {"requirePieces": 2, "skills": [502]}]},
            9: {"id": 9, "name": "坏数据套", "bonuses": [{"requirePieces": 2, "skills": ["x"]}]},
        }
        eff_sr = {"tiers": {"不开放": []}, "skills": {}, "gear": {}, "states": {}}
        res = SCAN.scan_class_c(eff_sr, {}, {}, {}, skills, {}, {}, {}, suits, {"suits": {"8": {"kind": "atk_final"}}})
        by_id = {it["id"]: it for it in res["items"]}
        self.assertEqual(set(by_id), {501, 503})
        self.assertEqual(by_id[501]["channels"], ["suit_skill"])
        self.assertEqual([d["skill"]["id"] for d in res["dropped"]], [502])
        self.assertEqual(res["dropped"][0]["reason"], "suit_template_replaced")
        self.assertEqual([m["channel"] for m in res["manual"]], ["suit_skill"])
        # 501／503 不在登记表里 → 未登记 2 招＋坏数据 1 条
        self.assertEqual(res["unexempted_count"], 3)
        old = dict(SCAN.CLASS_C_EXEMPT)
        try:
            SCAN.CLASS_C_EXEMPT.update({501: "夹具", 503: "夹具"})
            res2 = SCAN.scan_class_c(eff_sr, {}, {}, {}, skills, {}, {}, {}, suits, {"suits": {"8": {}}})
            self.assertEqual(res2["unexempted_count"], 1)
        finally:
            SCAN.CLASS_C_EXEMPT.clear()
            SCAN.CLASS_C_EXEMPT.update(old)

    def test_real_repo_strict_passes(self) -> None:
        rc = SCAN.main(["--strict", "--json"])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
