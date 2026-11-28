extends Node
## T585 西游档徐凤年（152）剑一～剑九、九阶基因锁收口专项（XXufeng.LOCK_FIX，Kyo 11-27 事项 95）：
## 1) 开：9996 去掉经验 −100%（passiveSPBST9）与空公共事件 1705、场合「永不」、卡面写已解开、删「使用:撕裂基因锁」；
##    9995 剑九不改（Kyo 11-27 留给新卡做主动战技），开关开着也保持原样；
##    剑一～剑八场合「永不」、删卡面「伤害:xxx」，开战附伤 2530～2537、元素增伤与穿透照旧；
## 2) 老档：60 级卡住的徐凤年存档 to_dict → as_reloaded → from_dict 读回后经验倍率恢复，打一场 Troop 胜利结算真拿到经验；
##    另有 9996 已不在技能表里的档读回不报错、照样拿经验；
## 3) 关（LOCK_FIX = false）回到 T440 口径：9996 −100%、菜单可点、60 级打一场拿不到经验；
## 4) 天启篇零改动：开关开／关天启篇 9987～9996 记录逐项相等；共享原表 XDB.table 不被改。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var was_rel := XImportedBalance.RELEASE_XUFENG
	var was_xf := XXufeng.REWORK
	var was_fix := XXufeng.LOCK_FIX
	var was_p4 := XTianqiBase.PHASE4
	var was_j9 := XXufeng.JIAN9
	XXufeng.JIAN9 = false  # T586 把剑一～剑三、剑九做成主动战技；本专项守 T585 口径（剑九不动、八剑纯被动）
	XMessageBox.auto = true
	XImportedBalance.RELEASE_XUFENG = true
	XXufeng.REWORK = true

	XXufeng.LOCK_FIX = true
	XXufeng.clear_cache()
	_check_data_on()
	_check_old_save(true)
	_check_save_without_9996()

	XXufeng.LOCK_FIX = false
	XXufeng.clear_cache()
	_check_data_off()
	_check_old_save(false)

	_check_tianqi_untouched()

	XImportedBalance.RELEASE_XUFENG = was_rel
	XXufeng.REWORK = was_xf
	XXufeng.LOCK_FIX = was_fix
	XXufeng.JIAN9 = was_j9
	XXufeng.clear_cache()
	XTianqiBase.PHASE4 = was_p4
	XTianqiSkills.reload_table()
	XState.current = null
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)


func _make_xiyou_state(lv: int) -> XState:
	var s := XState.new_game_blank()
	s.random_master = XRandomStream.hex64(20261127)
	s.set_switch(2494, true)
	s.set_variable(20, 30)
	s.actor_max_level = 99  # 正式档读档带 actorMaxLevel；不设时取插件参数，60 级已顶上限，测不到经验锁
	XState.current = s
	s.add_actor(152)
	for i in 5:
		s.set_battle_slot(i, 152 if i == 0 else 0)
	var a: XActor = s.actor(152)
	a.change_level(lv)
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	return s


func _card(sk: Dictionary) -> String:
	return "\n".join(PackedStringArray(XHelpCard.content(sk, "skill").map(func(r): return XHelpCard.plain(str(r[0])).replace("\\lock[1]", ""))))


func _has_effect(sk: Dictionary, data_id: int) -> bool:
	for e in sk.get("effects", []):
		if int(e.get("code", 0)) == 44 and int(e.get("dataId", 0)) == data_id:
			return true
	return false


func _check_data_on() -> void:
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)
	var raw9996: Dictionary = XDB.table("Skills")[9996]
	var raw9995: Dictionary = XDB.table("Skills")[9995]
	var raw9987: Dictionary = XDB.table("Skills")[9987]
	var sk := XDB.rec("Skills", 9996)
	var card := _card(sk)
	check("on.9996.data", int(sk.occasion) == 3 and not sk.meta.has("passiveSPBST9") and not str(sk.note).contains("passiveSPBST9")
		and not _has_effect(sk, 1705), [sk.occasion, sk.meta.keys(), sk.effects])
	check("on.9996.card", card.contains("基因锁已解开") and not card.contains("-100%") and not card.contains("撕裂"), card)
	check("on.9996.exr", is_equal_approx(a.exr, 1.0) or a.exr > 0.5, a.exr)
	var s9 := XDB.rec("Skills", 9995)
	var c9 := _card(s9)
	check("on.9995.untouched", not XXufeng.touches("Skills", 9995) and int(s9.occasion) == 2 and _has_effect(s9, 1704)
		and s9.meta.has("StartPushState2538") and c9.contains("领悟剑气"), [s9.occasion, s9.effects, c9])
	for sid in range(9987, 9995):
		var sw := XDB.rec("Skills", sid)
		var cw := _card(sw)
		var cfg: Array = XXufeng.SWORDS[sid]
		check("on.sword.%d" % sid, int(sw.occasion) == 3
			and sw.meta.has("StartPushState%d" % (2530 + sid - 9987))
			and str(sw.meta.get("passiveELUP01", "")) == "%d%%" % cfg[0]
			and str(sw.meta.get("DepassiveHarmRe01", "")).strip_edges() == "%d%%" % cfg[1]
			and not str(sw.note).contains("伤害:%d" % cfg[2])
			and not cw.contains("伤害:") and not cw.contains("伤害：%d" % cfg[2])
			and cw.contains("物理/寒冰伤害+%d%% 无视敌人物理/寒冰抗性+%d%%" % [cfg[0], cfg[1]]),
			[sw.occasion, cw])
	# 开战附伤状态照旧挂（D272 平衡不动）
	var logic := XBattleLogic.new()
	logic.setup(70, s, XBattleRandom.create(str(s.random_master)))
	check("on.battle_states", a.is_state_affected(2530) and a.is_state_affected(2537) and a.is_state_affected(2538), a.state_ids)
	logic.end_battle(0)
	# 共享原表不被改
	check("on.table_pure", int(raw9996.occasion) == 2 and str(raw9996.meta.get("passiveSPBST9", "")) == "-100%" and _has_effect(raw9996, 1705)
		and int(raw9995.occasion) == 2 and _has_effect(raw9995, 1704)
		and int(raw9987.occasion) == 1 and str(raw9987.note).contains("伤害:5000000"),
		[raw9996.occasion, raw9995.occasion, raw9987.occasion])


func _check_data_off() -> void:
	var s := _make_xiyou_state(80)
	var a: XActor = s.actor(152)
	var sk := XDB.rec("Skills", 9996)
	check("off.9996", int(sk.occasion) == 2 and str(sk.meta.get("passiveSPBST9", "")) == "-100%" and _has_effect(sk, 1705), [sk.occasion, sk.meta])
	check("off.exr0", is_zero_approx(a.exr), a.exr)
	var s9 := XDB.rec("Skills", 9995)
	check("off.9995", int(s9.occasion) == 2 and _has_effect(s9, 1704), [s9.occasion, s9.effects])
	var sw := XDB.rec("Skills", 9987)
	check("off.sword", int(sw.occasion) == 1 and str(sw.note).contains("伤害:500000 "), [sw.occasion])


## 打一场 Troop 1（嘤嘤怪，有经验）：敌人全倒、走胜利结算，返回徐凤年拿到的经验
func _win_once(s: XState) -> int:
	var a: XActor = s.actor(152)
	var before := a.exp_total
	var logic := XBattleLogic.new()
	logic.setup(1, s, XBattleRandom.create(str(s.random_master)))
	for e in logic.enemies:
		e.hp = 0
		e.add_new_state(1)
	var r := logic.rewards()
	logic.grant(r)
	logic.end_battle(0)
	return a.exp_total - before


func _check_old_save(fix_on: bool) -> void:
	var tag := "on" if fix_on else "off"
	# 存档时卡在 60 级（经验锁生效时存的档）
	XXufeng.LOCK_FIX = false
	XXufeng.clear_cache()
	var s0 := _make_xiyou_state(60)
	var a0: XActor = s0.actor(152)
	check("%s.save.locked_at_60" % tag, a0.level == 60 and a0.max_level() == 99 and a0.skill_ids.has(9996) and is_zero_approx(a0.exr), [a0.level, a0.exr])
	var data: Dictionary = XSaveSlim.as_reloaded(s0.to_dict())
	XXufeng.LOCK_FIX = fix_on
	XXufeng.clear_cache()
	XState.current = null
	var s := XState.from_dict(data)
	XState.current = s
	var a: XActor = s.actor(152)
	a.param_mark_dirty()
	var got := _win_once(s)
	if fix_on:
		check("on.reload.exr", a.skill_ids.has(9996) and a.exr > 0.5, a.exr)
		check("on.reload.battle_exp", got > 0, got)
		var big := a.gain_exp(a.exp_for_level(62) - a.exp_total)
		check("on.reload.level_up", big > 0 and a.level > 60, [big, a.level])
	else:
		check("off.reload.exr0", is_zero_approx(a.exr), a.exr)
		check("off.reload.battle_no_exp", got == 0 and a.level == 60, [got, a.level])


## 技能表里没有 9996 的档（理论上不会出现：原版 1705 是空事件，没人撕开过；照派单补测）读回不报错、照样拿经验
func _check_save_without_9996() -> void:
	var s0 := _make_xiyou_state(60)
	var a0: XActor = s0.actor(152)
	a0.forget_skill(9996)
	var data: Dictionary = XSaveSlim.as_reloaded(s0.to_dict())
	XState.current = null
	var s := XState.from_dict(data)
	XState.current = s
	var a: XActor = s.actor(152)
	check("no9996.reload", s != null and a != null and not a.skill_ids.has(9996) and a.level == 60 and a.exr > 0.5, [a.skill_ids.has(9996) if a else null])
	check("no9996.battle_exp", _win_once(s) > 0)


func _tq_recs() -> Array:
	var out := []
	for sid in range(9987, 9997):
		out.append(JSON.stringify(XDB.rec("Skills", sid)))
	return out


func _check_tianqi_untouched() -> void:
	XTianqiBase.PHASE4 = true
	XTianqiSkills.reload_table()
	var s := XState.new_game(XTianqi.legacy_of("zhengdao"), 152, [])
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "zhengdao", "lineup": [152]}
	XState.current = s
	XXufeng.LOCK_FIX = true
	XXufeng.clear_cache()
	var on := _tq_recs()
	check("tq.not_dispatched", not XXufeng.xiyou_save_on())
	XXufeng.LOCK_FIX = false
	XXufeng.clear_cache()
	var off := _tq_recs()
	var diff := []
	for i in on.size():
		if on[i] != off[i]:
			diff.append(9987 + i)
	check("tq.records_equal", diff.is_empty(), diff)
	XXufeng.LOCK_FIX = true
	XXufeng.clear_cache()
