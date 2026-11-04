extends Node
## dsPassiveSkill SvPngFd（角色战斗立绘放大）守卫（bailong-visual1）。参照 oracle/svpng.json（mv_oracle/svpng_probe.cjs 量冻结正式源）：
## 全库带 SvPngFd 的：防具 8 件（2937、4279、5198、5200~5203、8017）、状态 1120、敌人 850／938（敌人备注没人读）；
## 多件取装备顺序里最后一件（不取最大）；只在开战时算一次；放大的是身体，影子不放大。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _worn(a: XActor, ids: Array) -> void:
	a.equips.fill(null)
	a.state_ids.clear()
	a.skill_ids.clear()
	var slots := a.equip_slots()
	for id in ids:
		var item: Dictionary = XDB.rec("Armors", int(id)).duplicate(true)
		item["kind"] = "armor"
		a.equips[slots.find(int(item.etypeId))] = item


func _run() -> void:
	var ref = XDB.load_json("oracle/svpng.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	# 全库谁带标签（重制数据与原版一致）
	var census: Dictionary = cases.census.observed
	for table in ["Skills", "Items", "Weapons", "Armors", "States", "Actors", "Classes", "Enemies"]:
		var ours := []
		for o in XDB.table(table):
			if o is Dictionary and o.get("meta", {}).has("SvPngFd"):
				ours.append(int(o.id))
		# 重制切片里没有的条目（如防具 8017「特殊[变大]」）不算
		var want := (census[table.to_lower()] as Array).map(func(x): return int(x.id)).filter(func(id): return not XDB.rec(table, id).is_empty())
		check("census." + table, ours == want, [ours, want])
	check("census.armors_8_state_1", census.armors.size() == 8 and census.states.size() == 1)
	var s := XState.new_game_blank()
	s.party.assign([1])
	var a := s.actor(1)
	var obs: Dictionary = cases.scale.observed
	_worn(a, [])
	check("scale.base", XSvPngFd.scale(a) == float(obs.base.cache), XSvPngFd.scale(a))
	for r in obs.armors:
		if XDB.rec("Armors", int(r.id)).is_empty():
			continue
		_worn(a, [int(r.id)])
		check("scale.armor_%d" % int(r.id), XSvPngFd.scale(a) == float(r.cache), [XSvPngFd.scale(a), r.cache])
	_worn(a, [])
	a.add_state(int(obs.state.id))
	check("scale.state_1120", XSvPngFd.scale(a) == float(obs.state.cache), [XSvPngFd.scale(a), obs.state.cache])
	# 多件：装备顺序里最后一件生效（4279＝3 在 5200＝2 前 → 2；2937＝2 在 5203＝5 前 → 5），不取最大
	_worn(a, [4279, 5200])
	check("scale.combo_last_wins", XSvPngFd.scale(a) == float(obs.combo.cache) and obs.combo.cache == 2, [XSvPngFd.scale(a), obs.combo])
	_worn(a, [2937, 5203])
	check("scale.combo2_last_wins", XSvPngFd.scale(a) == float(obs.combo2.cache) and obs.combo2.cache == 5, [XSvPngFd.scale(a), obs.combo2])
	# 开战后换装／加状态不刷新（原版 refreshPassiveCache 只在 Scene_Battle.start 调）：画面节点建好后倍数不变
	_worn(a, [5203])
	var sp := XBattlerSprite.new()
	add_child(sp)
	sp.setup(a, 1.0)
	check("sprite.fd_5", sp.fd == 5.0, sp.fd)
	var base_scale := sp.body_scale
	_worn(a, [])
	check("sprite.frozen", sp.fd == 5.0 and sp.body_scale == base_scale, [sp.fd, sp.body_scale])
	var plain := XBattlerSprite.new()
	add_child(plain)
	plain.setup(a, 1.0)
	check("sprite.scales_body", is_equal_approx(base_scale / plain.body_scale, 5.0), [base_scale, plain.body_scale])
	check("sprite.mid_battle_unequip_oracle", int(obs.unequipMidBattle.after) == int(obs.unequipMidBattle.before) and int(obs.stateMidBattle.cache) == 1, [obs.unequipMidBattle, obs.stateMidBattle])
	_finish()


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
