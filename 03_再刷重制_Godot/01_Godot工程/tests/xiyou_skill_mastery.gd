extends Node
## 【cc·八戒·未经审查】技能熟练度期一（XSkillMastery）：与 mv_oracle/skill_mastery_probe.cjs 的冻结 v0.28 参照
## （tests/fixtures/skill_mastery_oracle.json，真实 BattleManager）逐例比。
## - table：全部技能的熟练度上限、升级所需次数（等级 1／2／5）、伤害公式（1000，等级 0／1／3）；
## - gain.*：每次行动后的等级、本级已用次数、本级所需次数、升级动画（普攻、魔法、自定义次数公式、治疗、防御（上限 0），
##   变量 13／8 夹等级；敌人也涨）；gain.menu：不在战斗不记；
## - damage.*：熟练度 0／1／3 级同一行动的扣血，比 1 级、3 级对 0 级的比值（绝对值另有与本期无关的伤害链差，只打印）；治疗不受影响；
## - save：存档往返；旧档没有熟练度字段读回 0 级。
const FIXTURE := "res://tests/fixtures/skill_mastery_oracle.json"
## 渡鸦 10122～10139、10170 的熟练度设定由 installNativeRavenRuntime 运行时改写（上限 8／0、次数 8＋4×等级、每级 8%），归期三，这里先跳过
const RAVEN_PENDING := [10122, 10123, 10124, 10125, 10126, 10127, 10128, 10129, 10130, 10131, 10132, 10133, 10134, 10135, 10136, 10137, 10138, 10139, 10170]
## 参照里 7940 号的名字是运行时补上的（数据库为空名、无伤害），重制不算进 count
const RUNTIME_NAMED := [7940]
const BIG := 1e9
var results := []


class FixedStream extends XRandomStream:
	var value := 0.5
	func _take(kind: String, _reason: String, _event_key: String):
		draws += 1
		return value if kind == "float" else 2147483648


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok and results.filter(func(r): return not r.passed).size() <= 30:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _ready() -> void:
	_run.call_deferred()


## 同参照 battle()：新局、队伍只有 1 号（生命加 BIG）、敌群 3 每只生命加 BIG；vars：[[编号, 值]]
func _battle(vars := []) -> Array:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [])
	XState.current = s
	for v in vars:
		s.set_variable(int(v[0]), float(v[1]))
	var a := s.actor(1)
	a.add_param(0, BIG)
	a.refresh_passive()
	var rand := XBattleRandom.create("0000000000000001")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	for e in logic.enemies:
		var p: Array = (e.data().params as Array).map(func(x): return float(x))
		p[0] += BIG
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
		e.recover_all()
	for b in logic.actors:
		b.param_mark_dirty()
		b.param_refresh()
		b.recover_all()
	return [logic, a]


func _act(logic: XBattleLogic, u: XBattler, skill_id: int, target: XBattler) -> Array:
	u.mp = u.mmp
	u.tp = 100.0
	return logic.act(u, XDB.rec("Skills", skill_id), target)


func _snap(b: XBattler, id: int) -> Array:
	return [XSkillMastery.level(b, id), XSkillMastery.uses(b, id), snappedf(XSkillMastery.usage_max(b, id), 1e-6)]


func _want(o: Dictionary) -> Array:
	return [int(o.level), float(o.uses), snappedf(float(o.max), 1e-6)]


func _hp_values(logs: Array) -> Array:
	var out := []
	for l in logs:
		if l.get("type") == "hit" and not bool(l.get("missed", false)) and not bool(l.get("evaded", false)):
			out.append(float(l.hp))
	return out


func _table(c: Dictionary) -> void:
	var o: Dictionary = c.observed
	var t: Array = XDB.table("Skills")
	var count := 0
	var bad := []
	for id in range(1, t.size()):
		var rec = t[id]
		if rec == null or str(rec.get("name", "")) == "":
			continue
		count += 1
		if RAVEN_PENDING.has(id):
			continue
		var d := XSkillMastery.data(id)
		var got := [float(d.max)]
		for lv in [1, 2, 5]:
			got.append(snappedf(XSkillMastery.eval(str(d.exp), 0.0, lv), 1e-6))
		for lv in [0, 1, 3]:
			got.append(snappedf(XSkillMastery.eval(str(d.damage), 1000.0, lv), 1e-6))
		var want: Array = (o.rows.get(str(id), o.default) as Array).map(func(v): return snappedf(float(v), 1e-6))
		if got != want:
			bad.append([id, got, want])
	check("table.count", count + RUNTIME_NAMED.size() == int(o.count), [count, o.count])
	check("table.rows", bad.is_empty(), bad.slice(0, 5))


func _gain(c: Dictionary) -> void:
	var st: Dictionary = c.setup
	var r := _battle(st.get("vars", []))
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var id := int(st.skill)
	var steps: Array = c.observed.steps
	for i in steps.size():
		var self_target := id == 8 or id == 2
		var logs := _act(logic, a, id, a if self_target else logic.enemies[0])
		var ups := logs.filter(func(l): return l.get("type") == "mastery_up")
		var w: Dictionary = steps[i]
		check("%s.%d" % [c.id, i], _snap(a, id) == _want(w), [_snap(a, id), _want(w)])
		check("%s.%d.anim" % [c.id, i], ups.size() == (w.anims as Array).size() and ups.all(func(l): return int(l.animation) == 742 and l.target == a), ups.size())


func _gain_enemy(c: Dictionary) -> void:
	var r := _battle()
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	var e: XBattler = logic.enemies[0]
	var steps: Array = c.observed.steps
	for i in steps.size():
		var logs := _act(logic, e, 1, a)
		var ups := logs.filter(func(l): return l.get("type") == "mastery_up")
		check("%s.%d" % [c.id, i], _snap(e, 1) == _want(steps[i]), [_snap(e, 1), _want(steps[i])])
		check("%s.%d.anim" % [c.id, i], ups.size() == (steps[i].anims as Array).size())
	check(c.id + ".actor_untouched", XSkillMastery.level(a, 1) == 0 and XSkillMastery.uses(a, 1) == 0.0)


func _damage(c: Dictionary) -> void:
	var id := int(c.setup.skill)
	var got := {}
	for lv in [0, 1, 3]:
		var r := _battle()
		var logic: XBattleLogic = r[0]
		var a: XActor = r[1]
		XSkillMastery.set_level(a, id, lv)
		if id == 8:
			a.hp = 1.0
		got[lv] = _hp_values(_act(logic, a, id, a if id == 8 else logic.enemies[0]))
		var w: Dictionary = c.observed[str(lv)]
		check("%s.%d.after" % [c.id, lv], _snap(a, id) == _want(w.after), [_snap(a, id), _want(w.after)])
	var want := {}
	for lv in [0, 1, 3]:
		want[lv] = (c.observed[str(lv)].log as Array).map(func(v): return float(v))
	print("INFO ", c.id, " 重制 ", got, " 原版 ", want)
	for lv in [1, 3]:
		var ok: bool = got[lv].size() == want[lv].size() and got[0].size() == want[0].size()
		for i in mini(got[lv].size(), want[lv].size()):
			var gr: float = got[lv][i] / got[0][i] if got[0][i] != 0.0 else 1.0
			var wr: float = want[lv][i] / want[0][i] if want[0][i] != 0.0 else 1.0
			# 两边每段都四舍五入：比值的误差上限约 0.5／0 级值×(1＋比值)，两边相加
			var tol: float = 0.5 * (1.0 + absf(wr)) * (1.0 / maxf(1.0, absf(got[0][i])) + 1.0 / maxf(1.0, absf(want[0][i])))
			ok = ok and absf(gr - wr) <= tol
		check("%s.ratio%d" % [c.id, lv], ok, [got, want])


func _save(c: Dictionary) -> void:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [])
	XState.current = s
	var a := s.actor(1)
	XSkillMastery.set_level(a, 1, 4)
	XSkillMastery.set_uses(a, 1, 3)
	XSkillMastery.set_level(a, 9, 2)
	var d := s.to_dict()
	var b := XState.from_dict(JSON.parse_string(JSON.stringify(d))).actor(1)
	check("save.a1", _snap(b, 1) == _want(c.observed.a1), _snap(b, 1))
	check("save.a9", _snap(b, 9) == _want(c.observed.a9), _snap(b, 9))
	# 旧档（没有 masteryLevels／masteryUses）：0 级
	var row: Dictionary = d.actors["1"]
	row.erase("masteryLevels")
	row.erase("masteryUses")
	var old := XState.from_dict(JSON.parse_string(JSON.stringify(d))).actor(1)
	check("save.legacy", old.mastery_levels.is_empty() and XSkillMastery.level(old, 1) == 0 and XSkillMastery.uses(old, 1) == 0.0, old.mastery_levels)
	# 没有熟练度的角色不写这两项
	var fresh := XState.new_game(2, 1, [])
	check("save.omit_empty", not (fresh.to_dict().actors["1"] as Dictionary).has("masteryLevels"))


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("oracle_present", ref is Dictionary and ref.has("cases")):
		return finish()
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		var kind := str(c.id).get_slice(".", 0)
		seen[kind] = true
		match c.id:
			"table":
				_table(c)
			"gain.enemy":
				_gain_enemy(c)
			"gain.menu":
				# 菜单付费不经 XBattleLogic.execute，不记；新角色 0 级
				var s := XState.new_game(2, 1, [])
				XState.current = s
				check("gain.menu", _snap(s.actor(1), 8) == _want(c.observed) and s.actor(1).action_mastery.is_empty())
			"save":
				_save(c)
			_:
				if kind == "gain":
					_gain(c)
				elif kind == "damage":
					_damage(c)
	check("covers_all", seen.keys().size() == 4, seen.keys())
	finish()


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_skill_mastery", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
