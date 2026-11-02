extends Node
## 【cc·八戒·未经审查】技能熟练度期一（XSkillMastery）：与 mv_oracle/skill_mastery_probe.cjs 的冻结 v0.28 参照
## （tests/fixtures/skill_mastery_oracle.json，真实 BattleManager）逐例比。
## - table：全部技能的熟练度上限、升级所需次数（等级 1／2／5）、伤害公式（1000，等级 0／1／3）；
## - gain.*：每次行动后的等级、本级已用次数、本级所需次数、升级动画（普攻、魔法、自定义次数公式、治疗、防御（上限 0），
##   变量 13／8 夹等级；敌人也涨）；gain.menu：不在战斗不记；
## - damage.*：熟练度 0／1／3 级同一行动的扣血，比 1 级、3 级对 0 级的比值（绝对值另有与本期无关的伤害链差，只打印）；治疗不受影响；
## - save：存档往返；旧档没有熟练度字段读回 0 级。
## - 期二 notice.*：技能升级通告（同帧合并、只报角色、关掉设置／读档／标题不报、最多 3 条）；power：熟练度进战力（缓存照原版不因熟练度失效）。
const FIXTURE := "res://tests/fixtures/skill_mastery_oracle.json"
## - 期三（tests/fixtures/skill_mastery3_oracle.json，mv_oracle/skill_mastery3_probe.cjs）：渡鸦运行时设定、包装后等级、费用、涨熟练度；
##   宿傩来源技能；饿狼借主拳（O-145 o_garou_borrow）与进阶继承；异化无面／百相取 min（O-146 o_alien_object）；通告读包装后的等级。
const FIXTURE3 := "res://tests/fixtures/skill_mastery3_oracle.json"
const RAVEN := 167
const SUKUNA := 172
const GAROU := 173
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
		var d := XSkillMastery.data(id)
		var got := [float(XSkillMastery.max_level(id))]
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


## 期二：通告行只比 actorId、skillId、from、to（名字另比）
func _rows(list: Array) -> Array:
	return list.map(func(r): return [int(r.actorId), int(r.skillId), int(r.from), int(r.to), str(r.skillName)])


func _flush_notices() -> Array:
	XSkillNotice._flush()
	var out := XSkillNotice.dispatched.duplicate()
	XSkillNotice.dispatched.clear()
	return out


func _notice_battle(c: Dictionary) -> void:
	var r := _battle()
	var logic: XBattleLogic = r[0]
	var a: XActor = r[1]
	XSkillNotice.dispatched.clear()
	var steps: Array = c.observed.steps
	for i in steps.size():
		if i < 13:
			_act(logic, a, 1, logic.enemies[0])
		else:
			for k in 7:
				_act(logic, logic.enemies[0], 1, a)
		var got := _rows(_flush_notices())
		check("%s.%d" % [c.id, i], got == _rows(steps[i]), [got, steps[i]])
	XSkillNotice.clear()


func _notice_set(c: Dictionary) -> void:
	var s := XState.new_game(2, 1, [])
	XState.current = s
	var a := s.actor(1)
	XSkillNotice.dispatched.clear()
	var o: Dictionary = c.observed
	XSkillMastery.set_level(a, 9, 2)
	XSkillMastery.set_level(a, 9, 4)
	XSkillMastery.set_level(a, 1, 1)
	var merged := _rows(_flush_notices())
	check("notice.set.merged", merged == _rows(o.merged), [merged, o.merged])
	check("notice.set.names", (o.merged as Array).all(func(r): return str(r.actorName) == a.display_name()), o.merged)
	XSkillMastery.set_level(a, 9, 1)
	check("notice.set.down", _rows(_flush_notices()) == _rows(o.down))
	var was := XConfig.notice_on("skillLevel")
	XConfig._values.codexSkillLevelNotice = false
	XSkillMastery.set_level(a, 9, 3)
	check("notice.set.config", _rows(_flush_notices()) == _rows(o.config))
	XConfig._values.codexSkillLevelNotice = was
	var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check("notice.set.load", _rows(_flush_notices()) == _rows(o.load) and XSkillMastery.level(loaded.actor(1), 9) == int(o.levels.s9))
	# 敌人不报（参照 notice.battle 末项）；标题画面（没有 XState.current）不报
	XState.current = null
	XSkillMastery.set_level(a, 9, 5)
	check("notice.title", _flush_notices().is_empty())
	XState.current = loaded
	# 画面：最多 3 条同时显示，其余排队
	for id in [1, 9, 3, 4, 5]:
		XSkillMastery.set_level(loaded.actor(1), id, 6)
	XSkillNotice._flush()
	check("notice.max_visible", XSkillNotice.shown.size() == 3 and XSkillNotice.queue.size() == 2, [XSkillNotice.shown.size(), XSkillNotice.queue.size()])
	var box: Control = XSkillNotice.shown[0]
	check("notice.layout", is_equal_approx(box.position.x + box.size.x, 1280 - 16) and is_equal_approx(box.position.y, 16) and is_equal_approx(box.size.x, 380), [box.position, box.size])
	XSkillNotice.clear()
	XSkillNotice.dispatched.clear()


func _power(c: Dictionary) -> void:
	# 同 xiyou_power：设置写到测试目录、战力开着、装备随机取 0.5、新局照 new_game_blank
	XSave.dir_override = "user://test_xiyou_skill_mastery"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XConfig.set_flag("codexPowerEnabled", true)
	XGear.force_roll = 0.5
	var s := XState.new_game_blank()
	var a := s.actor(1)
	a.change_level_mv(30)
	a.recover_all()
	var before := float(XPower.actor(a, true).total)
	XSkillMastery.set_level(a, 1, 3)
	var cached := float(XPower.actor(a).total)
	var forced := float(XPower.actor(a, true).total)
	var o: Dictionary = c.observed
	print("INFO power 重制 ", [before, cached, forced], " 原版 ", [o.before, o.cached, o.forced])
	check("power.before", is_equal_approx(before, float(o.before)), [before, o.before])
	check("power.cached", is_equal_approx(cached, float(o.cached)), [cached, o.cached])
	check("power.forced", is_equal_approx(forced, float(o.forced)), [forced, o.forced])


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
			"notice.battle":
				_notice_battle(c)
			"notice.set":
				_notice_set(c)
			"power":
				_power(c)
			_:
				if kind == "gain":
					_gain(c)
				elif kind == "damage":
					_damage(c)
	check("covers_all", seen.keys().size() == 6, seen.keys())
	_run3()
	_level_text()
	finish()



## 技能窗「LV.n」：drawSkillMasteryLevel 用 Yanfly.Util.toGroup，正式版 toLocaleString('en')（审查第 22 期 P3-2）
func _level_text() -> void:
	var got := [1, 6, 999, 1000, 12345, 100000].map(func(v): return XSkillScene.mastery_level_text(v))
	check("ui.level_text_group", got == ["1", "6", "999", "1,000", "12,345", "100,000"], got)

# ---- 期三 ----
func _run3() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE3))
	if not check("oracle3_present", ref is Dictionary and ref.has("cases")):
		return
	var seen := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		if not c.errors.is_empty():
			continue
		seen[c.id] = true
		match c.id:
			"raven.data": _raven_data(c)
			"raven.level": _raven_level(c)
			"raven.cost": _raven_cost(c)
			"raven.gain": _raven_gain(c)
			"sukuna.level": _sukuna_level(c)
			"sukuna.gain": _sukuna_gain(c)
			"sukuna.gain37": _sukuna_gain37(c)
			"garou.borrow": _garou_borrow(c)
			"garou.advance": _garou_advance(c)
			"alien.faceless": _alien_faceless(c)
			"alien.mimic": _alien_mimic(c)
			"notice": _notice3(c)
	check("covers_all3", seen.size() == 12, seen.keys())
	_toji_armory()
	_yunshang_derived()


class TojiStream extends XRandomStream:
	func _take(kind: String, reason: String, _event_key: String):
		draws += 1
		if kind == "float" and reason.begins_with("toji_"):
			return 0.3  # 武器库 50% 掷中、挑第一把
		return 0.5 if kind == "float" else 2147483648


## 甚尔武器库（参照没量，照 installNativeTojiRuntime:461 读）：掷中时 _actionMastery 推 10211，随 onAllActionsEnd 计一次
func _toji_armory() -> void:
	var s := _new()
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	s.actor(171).change_level_mv(55)
	s.actor_advance[171] = 1
	XToji.repair(s.actor(171))
	s.add_actor(171)
	var a := s.actor(171)
	a.add_param(0, BIG)
	a.refresh_passive()
	var rand := XBattleRandom.create("0000000000000171")
	rand.rule = TojiStream.new()
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
	a.param_refresh()
	a.recover_all()
	_act(logic, a, 10216, logic.enemies[0])
	check("toji.armory_counted", XSkillMastery.uses(a, 10211) == 1.0 and XSkillMastery.uses(a, 10216) == 1.0 and a.action_mastery.is_empty(),
		[XSkillMastery.uses(a, 10211), XSkillMastery.uses(a, 10216)])
	XSkillMastery.set_level(a, 10211, 3)
	check("toji.armory_level", a.skillMasteryLevelOf(10211) == 3)


## 云裳派生伤害（nativeDamage 里 _yunMasteryLevel 换掉这个派生技能自己的等级）：符针用种针时的等级
func _yunshang_derived() -> void:
	var s := _new()
	var a := s.actor(1)
	var rec := XDB.rec("Skills", XYunshang.NEEDLE)
	var plain := XSkillMastery.damage(rec, a, 1000.0)
	XYunshang.derived_frame = {"mastery": 3, "mastery_skill": XYunshang.NEEDLE}
	var lifted := XSkillMastery.damage(rec, a, 1000.0)
	XYunshang.derived_frame = {"mastery": 3, "mastery_skill": 1}
	var other := XSkillMastery.damage(rec, a, 1000.0)
	XYunshang.derived_frame = {}
	var want := XSkillMastery.eval(str(XSkillMastery.data(XYunshang.NEEDLE).damage), 1000.0, 3)
	check("yunshang.derived_mastery", plain == XSkillMastery.eval(str(XSkillMastery.data(XYunshang.NEEDLE).damage), 1000.0, 0) and lifted == want and other == plain, [plain, lifted, want, other])


func _new(party := []) -> XState:
	var s := XState.new_game(int(XDB.plugin("Vitsuno_Difficulty").get("Init Difficulty ID", 2)), 1, [])
	s.actor_max_level = 99
	XState.current = s
	if not party.is_empty():
		s.party.clear()
		s.battle_slots.clear()
		s.switches[2494] = true  # 超强者（渡鸦、宿傩）入队要挑战开关；参照 $gameParty.addActor 不经这道拦截
		for id in party:
			s.add_actor(int(id))
	return s


## 同参照 battle(ids, vars)：队伍 ids、生命加 BIG；敌群 3 每只生命加 BIG
func _battle_party(ids: Array, vars := []) -> XBattleLogic:
	var s := _new(ids)
	for v in vars:
		s.set_variable(int(v[0]), float(v[1]))
	for id in ids:
		s.actor(int(id)).add_param(0, BIG)
		s.actor(int(id)).refresh_passive()
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
	return logic


func _n(v) -> float:
	return snappedf(float(v), 1e-6)


func _raven_data(c: Dictionary) -> void:
	var s := _new()
	for v8 in c.observed:
		s.set_variable(8, float(v8))
		var bad := []
		for id in range(10122, 10140):
			var d := XSkillMastery.data(id)
			var got := [_n(XSkillMastery.max_level(id)), _n(XSkillMastery.eval(str(d.exp), 0.0, 1)), _n(XSkillMastery.eval(str(d.exp), 0.0, 3)),
				_n(XSkillMastery.eval(str(d.damage), 1000.0, 3)), _n(XSkillMastery.eval(str(d.mp), 100.0, 3)), _n(XSkillMastery.eval(str(d.tp), 100.0, 3)),
				_n(XSkillMastery.eval(str(d.hp), 100.0, 3)), _n(XSkillMastery.eval(str(d.cooldown), 5.0, 3))]
			var want: Array = (c.observed[v8][str(id)] as Array).map(func(x): return _n(x))
			if got != want:
				bad.append([id, got, want])
		check("raven.data.v%s" % v8, bad.is_empty(), bad.slice(0, 3))


func _raven_level(c: Dictionary) -> void:
	var s := _new()
	s.set_variable(8, 5)
	for id in [RAVEN, 1]:
		var a := s.actor(id)
		a.mastery_levels[10122] = 12
		a.mastery_levels[10127] = 3
		var w: Dictionary = c.observed[str(id)]
		var got := [a.skillMasteryLevel(10122), a.skillMasteryLevelOf(10122), XSkillMastery.is_maxed(a, 10122), a.skillMasteryLevel(10127), _n(XSkillMastery.rate(a, 10122))]
		check("raven.level.%d" % id, got == [int(w.num), int(w.obj), bool(w.maxed), int(w.other), _n(w.rate)], [got, w])


func _raven_cost(c: Dictionary) -> void:
	var s := _new()
	s.set_variable(8, 20)
	var a := s.actor(RAVEN)
	a.change_level_mv(60)
	a.recover_all()
	var logic := XBattleLogic.new()
	logic.state = s
	check("raven.cost.mmp", int(a.mmp) == int(c.observed.mmp), [a.mmp, c.observed.mmp])
	for lv in c.observed.out:
		var bad := []
		for id in range(10122, 10128):
			XSkillMastery.set_level(a, id, int(lv))
			var cost := logic.skill_cost(a, XDB.rec("Skills", id))
			var got := [a.skillMasteryLevel(id), int(cost.mp), int(cost.tp)]
			var want: Array = (c.observed.out[lv][str(id)] as Array).map(func(x): return int(x))
			if got != want:
				bad.append([id, got, want])
		check("raven.cost.lv%s" % lv, bad.is_empty(), bad)


func _raven_gain(c: Dictionary) -> void:
	var logic := _battle_party([RAVEN], [[8, 2]])
	var a := logic.state.actor(RAVEN)
	var steps: Array = c.observed.steps
	var bad := []
	for i in steps.size():
		var logs := _act(logic, a, 10122, logic.enemies[0])
		var ups := logs.filter(func(l): return l.get("type") == "mastery_up").size()
		var w: Dictionary = steps[i]
		var got := [XSkillMastery.level(a, 10122), int(XSkillMastery.uses(a, 10122)), a.skillMasteryLevel(10122), ups]
		if got != [int(w.level), int(w.uses), int(w.lv), int(w.anims)]:
			bad.append([i, got, w])
	check("raven.gain", bad.is_empty(), bad.slice(0, 3))


func _sukuna_level(c: Dictionary) -> void:
	for v8 in c.observed:
		var s := _new()
		s.set_variable(8, float(v8))
		for id in [SUKUNA, 1]:
			var a := s.actor(id)
			a.mastery_levels.merge({10229: 4, 10234: 9, 10231: 2}, true)
			var bad := []
			var w: Dictionary = c.observed[v8][str(id)]
			for sid in w:
				var got := [a.skillMasteryLevel(int(sid)), a.skillMasteryLevelOf(int(sid)), XSkillMastery.is_maxed(a, int(sid))]
				if got != [int(w[sid][0]), int(w[sid][1]), bool(w[sid][2])]:
					bad.append([sid, got, w[sid]])
			check("sukuna.level.v%s.%d" % [v8, id], bad.is_empty(), bad)


func _sukuna_gain(c: Dictionary) -> void:
	var logic := _battle_party([SUKUNA])
	var a := logic.state.actor(SUKUNA)
	var steps: Array = c.observed.steps
	var bad := []
	for i in steps.size():
		a.action_mastery.assign([10234] if i % 2 else [10234, 10229])
		var logs := []
		logic._mastery_end(a, logs)
		var w: Dictionary = steps[i]
		var got := [XSkillMastery.level(a, 10234), int(XSkillMastery.uses(a, 10234)), XSkillMastery.level(a, 10229), int(XSkillMastery.uses(a, 10229)),
			a.skillMasteryLevel(10234), logs.size()]
		if got != [int(w.s34.level), int(w.s34.uses), int(w.s29.level), int(w.s29.uses), int(w.lv34), int(w.anims)]:
			bad.append([i, got, w])
	check("sukuna.gain", bad.is_empty(), bad.slice(0, 3))


## 10237 读 10231 的等级：自己练到升级（原始 0→1），包装后不变，不放动画
func _sukuna_gain37(c: Dictionary) -> void:
	var logic := _battle_party([SUKUNA])
	var a := logic.state.actor(SUKUNA)
	a.mastery_levels[10231] = 2
	var steps: Array = c.observed.steps
	var bad := []
	for i in steps.size():
		a.action_mastery.assign([10237])
		var logs := []
		logic._mastery_end(a, logs)
		var w: Dictionary = steps[i]
		var got := [XSkillMastery.level(a, 10237), int(XSkillMastery.uses(a, 10237)), a.skillMasteryLevel(10237), logs.size()]
		if got != [int(w.s37.level), int(w.s37.uses), int(w.lv37), int(w.anims)]:
			bad.append([i, got, w])
	check("sukuna.gain37", bad.is_empty(), bad.slice(0, 3))


func _garou_borrow(c: Dictionary) -> void:
	var s := _new()
	s.actor_advance[GAROU] = 2
	var a := s.actor(GAROU)
	a.change_level_mv(60)
	XGarou.sync(a)
	var o: Dictionary = c.observed
	var main: int = XGarou.MAIN[XGarou.stage(a)]
	check("garou.borrow.main", main == int(o.main), [main, o.main])
	XSkillMastery.set_level(a, main, 3)
	XGarou.mastery_source = main
	# 修好（默认）：角色读到 Game_BattlerBase 那一层（借主拳）；回退：照原版角色读自己的（被渡鸦装的 Game_Actor 包装挡住）
	check("garou.borrow.fixed", a.skillMasteryLevel(10262) == int(o.base) and a.skillMasteryLevelOf(10262) == int(o.base), a.skillMasteryLevel(10262))
	XSkillMastery.o_garou_borrow = false
	check("garou.borrow.original", a.skillMasteryLevel(10262) == int(o.actor) and a.skillMasteryLevelOf(10262) == int(o.actorObj), a.skillMasteryLevel(10262))
	XSkillMastery.o_garou_borrow = true
	XGarou.mastery_source = 0
	check("garou.borrow.after", a.skillMasteryLevel(10262) == int(o.after))


func _garou_advance(c: Dictionary) -> void:
	var s := _new()
	s.actor_advance[GAROU] = 0
	s.actor(GAROU).change_level_mv(20)
	XGarou.sync(s.actor(GAROU))
	check("garou.advance.recruit", XGarou.recruit(s))
	var a := s.actor(GAROU)
	XSkillNotice.dispatched.clear()
	var steps: Array = c.observed.steps
	for st in 6:
		var next: Dictionary = XGarou.STAGES[st + 1]
		a.change_level_mv(int(next.level))
		s.garou["breakthroughs"] = float(next.breakthroughs)
		if st == 5:
			s.gain_item(XGarou.CATALYST, 1)
		for id in range(10250, 10262):
			if a.skill_ids.has(id) and not a.mastery_levels.has(id):
				XSkillMastery.set_level(a, id, id - 10248 + st)
				XSkillMastery.set_uses(a, id, 5 if id == 10256 else 2)
		if a.skill_ids.has(10256):
			a.mastery_uses[10256] = 7
		_flush_notices()
		var result := XGarou.advance(s, a, st)
		var lv := {}
		for id in range(10250, 10262):
			if a.mastery_levels.has(id):
				lv[str(id)] = [int(a.mastery_levels[id]), int(a.mastery_uses.get(id, 0))]
		var w: Dictionary = steps[st]
		var want := {}
		for k in w.lv:
			want[k] = (w.lv[k] as Array).map(func(x): return int(x))
		check("garou.advance.s%d" % (st + 1), bool(result.ok) and XGarou.stage(a) == int(w.stage) and lv == want, [result, lv, want])
		check("garou.advance.s%d.quiet" % (st + 1), _flush_notices().is_empty())  # _garouAdvancing：继承不报通告


func _alien_item(s: XState, affix: String, config: Dictionary) -> Dictionary:
	XAlienation.force_roll = 0.5
	XGear.force_roll = 0.5
	var item: Dictionary = XAlienation.create(s, "w", 1044, "boss", affix).ok
	XAlienation.mark(item).config = config
	return item


func _alien_setup(affix: String, config: Dictionary) -> XActor:
	var s := _new([1, 8])
	var a := s.actor(1)
	var b := s.actor(8)
	a.change_level_mv(99)
	b.change_level_mv(30)
	b.learn_skill(1924)
	b.learn_skill(1926)
	a.equips[0] = _alien_item(s, affix, config)
	for x in [a, b]:
		x.mastery_levels.merge({1924: 50 if x == a else 10, 1926: 50 if x == a else 10, 9: 50 if x == a else 10}, true)
	return a


func _alien_faceless(c: Dictionary) -> void:
	var a := _alien_setup("faceless", {"actorId": 1, "pairs": [{"ownerId": 8, "skillId": 1924, "replaceId": 160}]})
	var o: Dictionary = c.observed
	var got := [a.skillMasteryLevel(1924), a.skillMasteryLevel(9), XSkillMastery.is_maxed(a, 1924), _n(XSkillMastery.rate(a, 1924))]
	check("alien.faceless.num", got == [int(o.num), int(o.other), bool(o.maxed), _n(o.rate)], [got, o])
	# 传技能对象：修好（默认）也取 min；回退照原版用自己的
	check("alien.faceless.obj_fixed", a.skillMasteryLevelOf(1924) == int(o.num))
	XSkillMastery.o_alien_object = false
	check("alien.faceless.obj_original", a.skillMasteryLevelOf(1924) == int(o.obj) and a.skillMasteryLevel(1924) == int(o.num))
	XSkillMastery.o_alien_object = true


func _alien_mimic(c: Dictionary) -> void:
	var a0 := _alien_setup("mimic", {"actorId": 1, "replace": 160})
	var s := XState.current
	var rand := XBattleRandom.create("0000000000000001")
	rand.rule = FixedStream.new()
	rand.rule.domain = "rule"
	var logic := XBattleLogic.new()
	logic.setup(3, s, rand)
	var a := s.actor(1)
	var d = XAlienBattle.locked(a)
	if not check("alien.mimic.locked", d != null and str(d.affix) == "mimic", d):
		return
	d.observed = [1926]
	d.selected = 1926
	a.change_level_mv(40)
	var o: Dictionary = c.observed
	check("alien.mimic.num", a.skillMasteryLevel(1926) == int(o.num) and a.skillMasteryLevel(9) == int(o.other), [a.skillMasteryLevel(1926), o])
	check("alien.mimic.obj_fixed", a.skillMasteryLevelOf(1926) == int(o.num))
	XSkillMastery.o_alien_object = false
	check("alien.mimic.obj_original", a.skillMasteryLevelOf(1926) == int(o.obj))
	XSkillMastery.o_alien_object = true
	check("alien.mimic.same_actor", a == a0)


func _notice3(c: Dictionary) -> void:
	var s := _new()
	XSkillNotice.dispatched.clear()
	var a := s.actor(SUKUNA)
	a.mastery_levels[10231] = 2
	XSkillMastery.set_level(a, 10234, 5)
	XSkillMastery.set_level(a, 10237, 5)
	XSkillMastery.set_level(a, 10229, 2)
	check("notice3.sukuna", _rows(_flush_notices()) == _rows(c.observed.rows) and XSkillMastery.level(a, 10237) == int(c.observed.s37.level), c.observed.rows)
	var r := s.actor(RAVEN)
	s.set_variable(8, 3)
	r.mastery_levels[10122] = 3
	XSkillMastery.set_level(r, 10122, 5)
	check("notice3.raven_capped", _rows(_flush_notices()) == _rows(c.observed.capped) and XSkillMastery.level(r, 10122) == int(c.observed.raw.level))


func finish() -> void:
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_skill_mastery", "passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
