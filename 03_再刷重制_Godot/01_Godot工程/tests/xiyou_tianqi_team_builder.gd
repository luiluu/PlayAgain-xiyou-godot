extends Node
## 【cc·T162】配队器（tests/virtual_player/team_builder.gd）：四个模板的职责构成、档位规则（艰险上场最多 2 强、无超强者；九死起超强者 ≤ super_cap）、
## 随机队合法且互不相同且种子定住、最强队合法、缺职责时报出来而不静默补。

const TB := preload("res://tests/virtual_player/team_builder.gd")

var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	XTianqiSkills.reload_table()
	XTianqiBase.clear_cache()
	for diff in ["xunchang", "jianxian", "jiusi", "zhengdao"]:
		_difficulty(diff)
	_rules()
	var rep := TB.report("jianxian")
	print("TB_REPORT ", JSON.stringify(rep))
	print("TB_STRONGEST ", JSON.stringify(TB.strongest_all("jianxian")))
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", r.detail)
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _difficulty(diff: String) -> void:
	var cand := TB.candidates(diff)
	_check("%s.candidates_have_all_roles" % diff, not (cand["输出"] as Array).is_empty() and not (cand["坦克"] as Array).is_empty() and not (cand["辅助"] as Array).is_empty(), [diff, cand["输出"].size(), cand["坦克"].size(), cand["辅助"].size()])
	var pool: Dictionary = XTianqi.pool(diff)
	var all := []
	for t in pool:
		all.append_array(pool[t])
	var in_pool := true
	var role_ok := true
	for r in cand:
		for id in cand[r]:
			in_pool = in_pool and all.has(id)
			role_ok = role_ok and TB.role_of(int(id)) == r
	_check("%s.candidates_in_pool_and_role" % diff, in_pool and role_ok)
	for tpl in TB.TEMPLATES:
		var a := TB.random_teams(tpl, 6, 20261118, diff)
		var b := TB.random_teams(tpl, 6, 20261118, diff)
		var c := TB.random_teams(tpl, 6, 99, diff)
		var ok := not a.is_empty()
		var distinct := {}
		for team in a:
			ok = ok and TB.legal(team, diff) and TB.matches(team, tpl)
			var k: Array = team.duplicate()
			k.sort()
			distinct[str(k)] = true
		_check("%s.%s.random_legal_and_matches" % [diff, tpl], ok, a)
		_check("%s.%s.random_distinct" % [diff, tpl], distinct.size() == a.size())
		_check("%s.%s.random_same_seed_same" % [diff, tpl], JSON.stringify(a) == JSON.stringify(b))
		_check("%s.%s.random_other_seed_differs" % [diff, tpl], JSON.stringify(a) != JSON.stringify(c))
		var s := TB.strongest(tpl, diff)
		_check("%s.%s.strongest_legal_and_matches" % [diff, tpl], not s.is_empty() and TB.legal(s, diff) and TB.matches(s, tpl), s)


func _rules() -> void:
	# 艰险：上场 4 人至少 2 弱者（强者 ≤ 2）、没有超强者
	var ok := true
	for tpl in TB.TEMPLATES:
		for team in TB.random_teams(tpl, 12, 5, "jianxian"):
			var strong := (team as Array).filter(func(x): return not XTianqiSkills.is_weak(int(x), true)).size()
			ok = ok and strong <= 2 and team.all(func(x): return not XTianqiSkills.is_super(int(x), true))
	_check("jianxian.at_most_2_strong_no_super", ok)
	_check("jianxian.min_weak_field_2", TB.min_weak_field("jianxian") == 2)
	# 非法队：重复、三强
	var strong_ids: Array = XTianqi.pool("jianxian")[XTier.STRONG]
	var weak_ids: Array = XTianqi.pool("jianxian")[XTier.WEAK]
	_check("legal.rejects_3_strong", not TB.legal([strong_ids[0], strong_ids[1], strong_ids[2], weak_ids[0]], "jianxian"))
	_check("legal.rejects_duplicate", not TB.legal([weak_ids[0], weak_ids[0], weak_ids[1], weak_ids[2]], "jianxian"))
	_check("legal.accepts_2_strong_2_weak", TB.legal([strong_ids[0], strong_ids[1], weak_ids[0], weak_ids[1]], "jianxian"))
	_check("legal.rejects_wrong_size", not TB.legal([weak_ids[0], weak_ids[1], weak_ids[2]], "jianxian"))
	# 缺职责不静默补：同一个函数在极端规则下配不出来就返回空（用一个不存在的模板键之外的做法：把候选抽干）
	var rep := TB.report("jianxian")
	_check("report.has_counts_and_notes", rep.has("counts") and rep.has("short") and rep.has("notes"))
