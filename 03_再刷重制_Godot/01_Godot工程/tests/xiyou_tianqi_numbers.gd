extends Node
## 天启篇第三批（XTianqiCombat、XTianqi）：五档难度与档位数值接进游戏。
## 一、敌人：五档都以原版普通（3）为基准，mhp 乘敌人血量、atk／mat 乘敌人攻击，其余照基准；原版档、开关关掉照原版难度。
## 二、我方：档位出伤、我方伤害、上场弱者协力、助力位光环（出伤）；档位承伤、协力承伤（承伤）；敌人打敌人、原版档恒 1；真实伤害结算按这个比例变。
## 三、开局：五档都走原版普通分支（UNIFIED_LEGACY），关掉回到各借各的；超强者上限、至少弱者、候选池只认数值表。
## 四、一线生机与天道注视：天启篇不学，原版档照学，开关回退。
## 五、选线：通关 5 层后出（开关默认开）；只有做好内容的线能选、不能再换、原版档不收；开关关掉不出。

## 大厅对话的替身宿主：文字直接过，选项依次取 answers（取完选最后一个）
class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	func show_text(_f: String, _i: int, _lines: Array) -> void:
		pass
	func show_text_with_choices(_f: String, _i: int, _lines: Array, options: Array, _cancel: int) -> int:
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _near(a: float, b: float, eps := 1e-6) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


func _state(key: String, lineup: Array) -> XState:
	var s := XTianqi.start_new_game(3, key, lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	XState.current = s
	return s


func _plain_state(lineup: Array) -> XState:
	var s := XState.new_game_blank()
	for id in lineup:
		s.add_actor(int(id))
	XState.current = s
	return s


func _run() -> void:
	XMessageBox.auto = true
	seed(20261111)
	_enemy_rates()
	_damage_mult()
	_damage_end_to_end()
	_opening()
	await _heaven_gaze()
	await _lines()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _enemy_rates() -> void:
	var w := _ids(XTier.WEAK)
	var base := XEnemy.difficulty_rates(XTianqi.NUMERIC_LEGACY)
	for key in XTianqiBalance.difficulty_keys():
		var s := _state(key, w.slice(0, 5))
		var row := XTianqiBalance.difficulty(key)
		var got := XTianqiCombat.enemy_rates(int(XTianqi.difficulty(key).legacy))
		var want := base.duplicate()
		want[0] = float(base[0]) * float(row.enemy_hp)
		want[2] = float(base[2]) * float(row.enemy_atk)
		want[4] = float(base[4]) * float(row.enemy_atk)
		_check("enemy_rates_" + key, range(8).all(func(i): return _near(float(got[i]), float(want[i]))), [got, want])
		XTianqiCombat.ENABLED = false
		var off := XTianqiCombat.enemy_rates(4, s)
		XTianqiCombat.ENABLED = true
		_check("enemy_rates_off_" + key, off == XEnemy.difficulty_rates(4), off)
		# 审查 79 P3-1：基准跟本档开局借的原版难度走。只关 UNIFIED_LEGACY 时各档借各自的原版难度，敌人倍率也跟着变
		_check("enemy_base_unified_" + key, XTianqiCombat.base_legacy(s) == XTianqi.NUMERIC_LEGACY, XTianqiCombat.base_legacy(s))
		XTianqi.UNIFIED_LEGACY = false
		var own := int(XTianqi.difficulty(key).legacy)
		var split := XTianqiCombat.enemy_rates(5, s)
		var split_base := XEnemy.difficulty_rates(own)
		XTianqi.UNIFIED_LEGACY = true
		var split_want := split_base.duplicate()
		split_want[0] = float(split_base[0]) * float(row.enemy_hp)
		split_want[2] = float(split_base[2]) * float(row.enemy_atk)
		split_want[4] = float(split_base[4]) * float(row.enemy_atk)
		_check("enemy_rates_split_" + key, range(8).all(func(i): return _near(float(split[i]), float(split_want[i]))), [own, split, split_want])
	# 同一只敌人：炼狱血量是九死的 2.0/1.5 倍，攻击 1.5/1.25 倍，防御不变
	var eid := 1
	_state("jiusi", w.slice(0, 5))
	var e1 := XEnemy.new().setup(eid, 4, 100.0)
	_state("lianyu", w.slice(0, 5))
	var e2 := XEnemy.new().setup(eid, 4, 100.0)
	var hp_ratio: float = XTianqiBalance.difficulty("lianyu").enemy_hp / XTianqiBalance.difficulty("jiusi").enemy_hp
	var atk_ratio: float = XTianqiBalance.difficulty("lianyu").enemy_atk / XTianqiBalance.difficulty("jiusi").enemy_atk
	_check("enemy_setup_hp", e1.param(0) > 0 and absf(e2.param(0) - e1.param(0) * hp_ratio) <= 1.0 + 1e-3 * e2.param(0), [e1.param(0), e2.param(0)])
	_check("enemy_setup_atk", e1.param(2) > 0 and absf(e2.param(2) - e1.param(2) * atk_ratio) <= 1.0 + 1e-3 * e2.param(2), [e1.param(2), e2.param(2)])
	_check("enemy_setup_def_same", _near(e2.param(3), e1.param(3)), [e1.param(3), e2.param(3)])
	# 原版档：传进来的难度照原版
	_plain_state(w.slice(0, 5))
	_check("enemy_rates_plain", XTianqiCombat.enemy_rates(5) == XEnemy.difficulty_rates(5))


func _damage_mult() -> void:
	var w := _ids(XTier.WEAK)
	var st := _ids(XTier.STRONG)
	var sup := _ids(XTier.SUPER)
	# 九死：上场 弱 弱 强 超，助力位弱者
	var lineup := [w[0], w[1], st[0], sup[0], w[2]]
	var s := _state("jiusi", lineup)
	_check("fixture_slots", s.battle_slots.slice(0, 5) == lineup, s.battle_slots)
	_check("field_weak", XTianqiCombat.field_weak_count(s) == 2 and XTianqiCombat.has_helper(s))
	var row := XTianqiBalance.difficulty("jiusi")
	var assist := XTianqiBalance.assist_bonus(2)
	var aura := 1.0 + XTianqiBalance.assist_slot_aura()
	var enemy := XEnemy.new().setup(1, 4, 100.0)
	for id in lineup.slice(0, 4):
		var a := s.actor(id)
		var want := XTianqiBalance.tier_damage_mult(XTier.tier_of(id)) * float(row.party_damage) * (1.0 + float(assist.damage_dealt)) * aura
		_check("dealt_%d" % id, _near(XTianqiCombat.damage_mult(a, enemy), want), [XTianqiCombat.damage_mult(a, enemy), want])
		var taken := XTianqiBalance.tier_taken_mult(XTier.tier_of(id)) * (1.0 + float(assist.damage_taken))
		_check("taken_%d" % id, _near(XTianqiCombat.damage_mult(enemy, a), taken), [XTianqiCombat.damage_mult(enemy, a), taken])
	_check("dealt_strong_gt_weak", XTianqiCombat.damage_mult(s.actor(st[0]), enemy) > XTianqiCombat.damage_mult(s.actor(w[0]), enemy))
	_check("taken_super_lt_weak", XTianqiCombat.damage_mult(enemy, s.actor(sup[0])) < XTianqiCombat.damage_mult(enemy, s.actor(w[0])))
	_check("enemy_to_enemy_one", XTianqiCombat.damage_mult(enemy, enemy) == 1.0)
	# 助力位空着：没有光环
	s.battle_slots[XTianqi.HELPER_SLOT] = 0
	var no_aura := XTianqiBalance.tier_damage_mult(XTier.WEAK) * float(row.party_damage) * (1.0 + float(assist.damage_dealt))
	_check("no_helper_no_aura", _near(XTianqiCombat.damage_mult(s.actor(w[0]), enemy), no_aura), XTianqiCombat.damage_mult(s.actor(w[0]), enemy))
	s.battle_slots[XTianqi.HELPER_SLOT] = w[2]
	# 助力位的弱者不算协力：把上场的弱者换成助力位外的强者，协力少一份
	XTianqiCombat.ENABLED = false
	_check("switch_off_one", XTianqiCombat.damage_mult(s.actor(st[0]), enemy) == 1.0 and XTianqiCombat.damage_mult(enemy, s.actor(sup[0])) == 1.0)
	XTianqiCombat.ENABLED = true
	var p := _plain_state(lineup)
	_check("plain_one", XTianqiCombat.damage_mult(p.actor(st[0]), enemy) == 1.0 and XTianqiCombat.damage_mult(enemy, p.actor(sup[0])) == 1.0)


## 真实伤害结算：同一下攻击，开关开／关的比值等于天启篇倍率
func _damage_end_to_end() -> void:
	var w := _ids(XTier.WEAK)
	var st := _ids(XTier.STRONG)
	var s := _state("jianxian", [st[0], w[0], w[1], w[2], w[3]])
	var a := s.actor(st[0])
	a.recover_all()
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	var item := XDB.rec("Skills", 1)
	var opts := {"critical": false, "variance": false}
	var on := float(XDamage.calculate(item, a, enemy, opts).value)
	XTianqiCombat.ENABLED = false
	var off := float(XDamage.calculate(item, a, enemy, opts).value)
	XTianqiCombat.ENABLED = true
	var mult := XTianqiCombat.damage_mult(a, enemy)
	_check("calc_dealt_ratio", off > 0.0 and absf(on - off * mult) <= 1.0 + 1e-6 * on, [on, off, mult])
	var back := float(XDamage.calculate(item, enemy, a, opts).value)
	XTianqiCombat.ENABLED = false
	var back_off := float(XDamage.calculate(item, enemy, a, opts).value)
	XTianqiCombat.ENABLED = true
	var tmult := XTianqiCombat.damage_mult(enemy, a)
	_check("calc_taken_ratio", back_off > 0.0 and absf(back - back_off * tmult) <= 1.0 + 1e-6 * back, [back, back_off, tmult])


func _opening() -> void:
	var w := _ids(XTier.WEAK)
	for key in XTianqiBalance.difficulty_keys():
		var c := XTianqi.opening_commands(1, key, w.slice(0, 5))
		_check("opening_legacy3_" + key, c.any(func(x): return int(x.code) == 356 and str(x.parameters[0]) == "Difficulty SetID 3")
			and not c.any(func(x): return int(x.code) == 356 and str(x.parameters[0]) != "Difficulty SetID 3" and str(x.parameters[0]).begins_with("Difficulty SetID")))
		var d := XTianqi.difficulty(key)
		var row := XTianqiBalance.difficulty(key)
		_check("roster_from_table_" + key, int(d.super_cap) == int(row.super_cap) and int(d.min_weak) == int(row.min_weak) and d.pool == row.pool, [d, row])
	XTianqi.UNIFIED_LEGACY = false
	var c2 := XTianqi.opening_commands(1, "lianyu", w.slice(0, 5))
	XTianqi.UNIFIED_LEGACY = true
	_check("opening_switch_off", c2.any(func(x): return int(x.code) == 356 and str(x.parameters[0]) == "Difficulty SetID 5"))
	_check("pool_xunchang_no_super", XTianqi.pool("xunchang")[XTier.SUPER].is_empty() and not XTianqi.pool("jiusi")[XTier.SUPER].is_empty())


func _heaven_gaze() -> void:
	var w := _ids(XTier.WEAK)
	var st := _ids(XTier.STRONG)
	var s := _state("jianxian", [w[0], st[0], w[1], w[2], w[3]])
	await MVScript.run("CodexHeavenGaze.apply(true);", MVInterpreter.new(self, 0, 0, []))
	_check("gaze_tianqi_skipped", not s.actor(w[0]).skill_ids.has(6212) and not s.actor(st[0]).skill_ids.has(6213))
	XTianqi.NO_HEAVEN_GAZE = false
	await MVScript.run("CodexHeavenGaze.apply(true);", MVInterpreter.new(self, 0, 0, []))
	XTianqi.NO_HEAVEN_GAZE = true
	_check("gaze_switch_off", s.actor(w[0]).skill_ids.has(6212) and s.actor(st[0]).skill_ids.has(6213))
	var p := _plain_state([w[0], st[0]])
	await MVScript.run("CodexHeavenGaze.apply(true);", MVInterpreter.new(self, 0, 0, []))
	_check("gaze_plain", p.actor(w[0]).skill_ids.has(6212) and p.actor(st[0]).skill_ids.has(6213))


func _lines() -> void:
	var w := _ids(XTier.WEAK)
	var s := _state("jianxian", w.slice(0, 5))
	# 战争线做好后选线默认打开（cc/pro-tianqi-war）；第一次通关 5 层（变量 20＝6）才出
	_check("line_open_default", XTianqi.LINE_EVENT_OPEN and not XTianqi.line_ready(s) and XTianqi.line_of(s) == "")
	s.set_variable(20, 6)
	_check("line_ready_floor5", XTianqi.line_ready(s))
	var host := FakeHost.new()
	host.answers = [XTianqi.LINES.size()]  # 再想想
	await XTianqi.run_line_choice(host, s)
	_check("line_later", XTianqi.line_of(s) == "" and host.asked.size() == 1 and host.asked[0].size() == XTianqi.LINES.size() + 1, host.asked)
	# 内容没做好的线（死亡；瘟疫线 cc 瘟疫线车道做好了）：卡片照看，选不了，回到列表；再想想
	XTianqiDeathLine.ENABLED = false  # 四条线都接上了，借关掉死亡线来模拟「没做好」
	host.answers = [1]
	await XTianqi.run_line_choice(host, s)
	_check("line_unplayable", XTianqi.line_of(s) == "" and host.asked.size() == 3 and not XTianqi.choose_line(s, "death"), host.asked.size())
	XTianqiDeathLine.ENABLED = true
	_check("line_chosen", XTianqi.choose_line(s, "war") and XTianqi.line_of(s) == "war" and not XTianqi.line_ready(s), XTianqi.line_of(s))
	_check("line_no_change", not XTianqi.choose_line(s, "plague") and XTianqi.line_of(s) == "war")
	_check("line_unknown", not XTianqi.choose_line(s, "nope"))
	var saved := XState.from_dict(s.to_dict())
	_check("line_saved", XTianqi.line_of(saved) == "war")
	var p := _plain_state(w.slice(0, 5))
	p.set_variable(20, 6)
	_check("line_plain", not XTianqi.line_ready(p) and not XTianqi.choose_line(p, "war"))
	XTianqi.LINE_EVENT_OPEN = false
	var s2 := _state("jianxian", w.slice(0, 5))
	s2.set_variable(20, 6)
	_check("line_switch_off", not XTianqi.line_ready(s2))
	XTianqi.LINE_EVENT_OPEN = true
