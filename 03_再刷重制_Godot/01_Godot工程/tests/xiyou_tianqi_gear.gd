extends Node
## 天启篇装备栏（XTianqiGear，第③步）：
## 一、栏位：天启篇存档 13 栏、按天启篇排列，类型 17 叫神器；装备数组仍 19 格（存档格式不变）；原版档照旧 19 栏。
## 二、能不能穿：删除栏位的装备不能穿、身上的卸回背包；神器只认白名单；坐骑不受难度适应 1691 封印；开局自带的删除栏位装备直接不装。
## 三、软绑定：茉蕾入队学强化·嘤嘤嘤、觉醒学嘤雄（+3 段那条技能号、技能视图改名生效）；鼬入队学通灵·乌鸦并生效。原版档不受影响。
## 四、界面：装备页只列 13 栏、光标按显示行走、神器栏能装白名单；状态页装备列按天启篇排列。
## 五、开关 XTianqiGear.ENABLED=false：天启篇存档也回到原版 19 栏与原规则。

var results: Array = []


func _ready() -> void:
	if has_meta("runner"):
		_run.call_deferred()
		return
	var runner := Node.new()
	runner.set_script(get_script())
	runner.set_meta("runner", true)
	get_tree().root.add_child.call_deferred(runner)


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _run() -> void:
	XMessageBox.auto = true
	_slots()
	_wear()
	_soft_bound()
	await _ui()
	_switch()
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 天启篇状态（与 XTianqi.start_new_game 写的规则版本一样，不跑开局）
func _tianqi_state() -> XState:
	var s := XState.new_game_blank()
	s.flags["tianqi"] = {"rules": XTianqi.RULES_VERSION, "difficulty": "jiusi", "lineup": []}
	return s


func _types(a: XActor) -> Array:
	var slots := a.equip_slots()
	return XTianqiGear.view(a).map(func(i): return int(slots[i]))


func _slot_of(a: XActor, etype: int) -> int:
	return a.equip_slots().find(etype)


func _slots() -> void:
	var old := XState.new_game_blank()
	var oa := old.actor(1)
	_check("legacy_view_19", XTianqiGear.view(oa) == range(19) and XTianqiGear.type_name(17) == "神武", XTianqiGear.view(oa))
	var s := _tianqi_state()
	var a := s.actor(1)
	_check("on", XTianqiGear.on() and XTianqiGear.on(s) and not XTianqiGear.on(old))
	_check("view_13_order", _types(a) == [1, 2, 3, 4, 6, 8, 5, 7, 9, 10, 13, 16, 17], _types(a))
	_check("equips_still_19", a.equips.size() == 19 and a.equip_slots().size() == 19, a.equips.size())
	_check("artifact_name", XTianqiGear.type_name(17) == "神器" and XTianqiGear.type_name(13) == "法宝" and XTianqiGear.type_name(16) == "坐骑")
	var names := XTianqiGear.view(a).map(func(i): return XTianqiGear.type_name(int(a.equip_slots()[i])))
	_check("view_names", names == ["武器", "副手", "头部", "盔甲", "护手", "腰带", "裤子", "鞋子", "项链", "戒指", "法宝", "坐骑", "神器"], names)
	var closed := [11, 12, 14, 15, 18, 19].filter(func(t): return XEquipment.can_change(a, _slot_of(a, t)))
	_check("deleted_slots_closed", closed.is_empty(), closed)
	_check("kept_slots_open", [3, 13, 16, 17].all(func(t): return XEquipment.can_change(a, _slot_of(a, t))))
	_check("quality_tag", XQuality.label(XGear.template("armor", 7900), "armor").contains("神器"), XQuality.label(XGear.template("armor", 7900), "armor"))


func _wear() -> void:
	var s := _tianqi_state()
	var a := s.actor(1)
	a.change_level(80)
	var art := XGear.template("armor", 7900)       # 心之钢：神器白名单
	var dawn := XGear.template("armor", 4540)      # 黎明—破晓：原神武，不在白名单
	var treasure := XGear.template("armor", 3582)  # 屈服的嘤嘤怪：灵兽（删除栏位）
	_check("allows", XTianqiGear.allows(art) and not XTianqiGear.allows(dawn) and not XTianqiGear.allows(treasure)
		and XTianqiGear.allows(XGear.template("armor", 4472)) and XTianqiGear.allows(XGear.template("weapon", 1)))
	s.gear.append(art)
	s.gear.append(dawn)
	var slot17 := _slot_of(a, 17)
	_check("artifact_fits", XEquipment.fits(a, slot17, art) and not XEquipment.fits(a, slot17, dawn))
	_check("artifact_equip", XEquipment.change(s, a, slot17, art) and is_same(a.equips[slot17], art) and not s.gear.has(art))
	_check("dawn_refused", not XEquipment.change(s, a, slot17, dawn) and s.gear.has(dawn))
	# 删除栏位上已经穿着的（例如旧规则下得到的）：刷新时卸回背包
	var slot14 := _slot_of(a, 14)
	a.equips[slot14] = treasure
	a.release_to_party()
	_check("deleted_slot_released", a.equips[slot14] == null and s.gear.has(treasure))
	# 坐骑：难度适应 1691 的封印天启篇不算；原版照封
	var horse := XGear.template("armor", 4472)
	s.gear.append(horse)
	a.add_state(1691)
	var slot16 := _slot_of(a, 16)
	_check("mount_not_sealed", a.state_ids.has(1691) and XEquipment.can_change(a, slot16) and XEquipment.change(s, a, slot16, horse), a.state_ids)
	var old := XState.new_game_blank()
	var oa := old.actor(1)
	oa.add_state(1691)
	_check("legacy_mount_sealed", oa.state_ids.has(1691) and not XEquipment.can_change(oa, _slot_of(oa, 16)))
	_check("legacy_dawn_ok", XTianqiGear.allows(XGear.template("armor", 4540)) and XTianqiGear.allows(XGear.template("armor", 3582)))
	# 开局自带删除栏位装备的角色（天虎令：灵兽、宝宝、形态）：天启篇直接不装、不进背包
	var s2 := _tianqi_state()
	var tiger := s2.actor(104)
	var worn := tiger.equips.filter(func(e): return e is Dictionary and not e.is_empty()).map(func(e): return int(e.etypeId))
	_check("opening_gear_dropped", [14, 18, 19].all(func(t): return not worn.has(t)) and s2.gear.is_empty(), [worn, s2.gear.size()])
	var old_tiger := XState.new_game_blank().actor(104)
	var old_worn := old_tiger.equips.filter(func(e): return e is Dictionary and not e.is_empty()).map(func(e): return int(e.etypeId))
	_check("legacy_opening_gear", old_worn.has(19), old_worn)


func _soft_bound() -> void:
	var s := _tianqi_state()
	var molei := s.actor(XTianqiGear.MOLEI)
	_check("molei_active_skill", molei.skill_ids.has(2797) and not molei.skill_ids.has(6242), molei.skill_ids)
	molei.learn_skill(XTianqiGear.MOLEI_AWAKEN)
	molei.refresh_passive()  # learn_skill 不刷被动缓存（调用处刷，同原版事件学技能后 refresh）
	_check("molei_awaken_passive", molei.skill_ids.has(6242), molei.skill_ids)
	var view = molei.skills().filter(func(k): return int(k.id) == 6242)
	_check("molei_passive_view", view.size() == 1 and str(view[0].name) == "嘤雄" and str(view[0].note).contains("三段"), view.map(func(k): return k.name))
	var mpass: Dictionary = molei.passive_cache().skillPass
	_check("molei_passive_works", [3518, 4774, 4775].all(func(id): return mpass.has(id) and float(mpass[id].rate) >= 1.0), mpass)
	var itachi := s.actor(XTianqiGear.ITACHI)
	var ipass: Dictionary = itachi.passive_cache().skillPass
	_check("itachi_passive", itachi.skill_ids.has(7475) and [7465, 7466, 7467, 7471, 7472, 7473].all(func(id): return ipass.has(id) and float(ipass[id].rate) >= 1.0), ipass)
	var raw := XDB.rec("Skills", 6242)
	_check("data_untouched", str(raw.name) == "究极嘤雄" and not raw.get("meta", {}).has("SkillPass3518"))
	var old := XState.new_game_blank()
	var om := old.actor(XTianqiGear.MOLEI)
	om.learn_skill(XTianqiGear.MOLEI_AWAKEN)
	var oi := old.actor(XTianqiGear.ITACHI)
	_check("legacy_soft_bound", not om.skill_ids.has(6242) and not om.skill_ids.has(2797) and not oi.skill_ids.has(7475), [om.skill_ids, oi.skill_ids])


func _ui() -> void:
	var s := _tianqi_state()
	s.flags.tianqi.lineup = [1]  # 天启篇 NO_RECRUIT（天启第二批）只放开局阵容入队
	s.add_actor(1)
	var a := s.actor(1)
	a.change_level(80)
	var art := XGear.template("armor", 7901)
	s.gear.append(art)
	var equip := XEquipScene.new()
	add_child(equip)
	await get_tree().process_frame
	_check("ui_rows", equip.slot_view().size() == 13 and equip.slot_name(equip.slot_view().back()) == "神器")
	equip._ok()  # 指令「装备」→ 槽位
	await get_tree().process_frame
	var seen := [equip._slot]
	for i in 12:
		equip._move(1, false)
		seen.append(equip._slot)
	_check("ui_cursor_walks_view", seen == equip.slot_view() and equip._slot_top == 0, seen)
	equip._move(1, true)
	_check("ui_cursor_wraps", equip._slot == 0, equip._slot)
	equip._move(-1, true)
	_check("ui_artifact_row", equip._slot == _slot_of(a, 17) and equip._slot_row() == 12)
	equip._ok()  # 进候选
	await get_tree().process_frame
	var cands: Array = equip.candidates().map(func(e): return e.rec)
	_check("ui_artifact_candidates", equip._mode == "item" and cands.any(func(e): return is_same(e, art)), cands.size())
	equip._item_index = cands.find_custom(func(e): return is_same(e, art))
	equip._ok()
	await get_tree().process_frame
	_check("ui_artifact_equipped", is_same(a.equips[_slot_of(a, 17)], art) and equip._mode == "slot")
	equip.queue_free()
	await get_tree().process_frame
	# 状态页装备列：神器在第 13 行
	var ops := XStatusPage.page_ops(a, 0)
	var rows := ops.filter(func(o): return o[0] == "icon" and float(o[2]) > 800.0)
	_check("status_rows", not rows.is_empty() and rows.size() <= 13, rows.size())


func _switch() -> void:
	var s := _tianqi_state()
	var a := s.actor(1)
	XTianqiGear.ENABLED = false
	_check("switch_off_view", XTianqiGear.view(a) == range(19) and XTianqiGear.type_name(17) == "神武"
		and XTianqiGear.allows(XGear.template("armor", 3582)) and XEquipment.can_change(a, _slot_of(a, 14)))
	var molei := s.actor(XTianqiGear.MOLEI)
	_check("switch_off_soft_bound", not molei.skill_ids.has(2797), molei.skill_ids)
	XTianqiGear.ENABLED = true
	_check("switch_on_again", XTianqiGear.view(a).size() == 13)
