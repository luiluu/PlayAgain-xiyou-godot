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

    def test_real_repo_strict_passes(self) -> None:
        rc = SCAN.main(["--strict", "--json"])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
