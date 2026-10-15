class_name XStatusPage
extends XActorPage
## JAH_StatusMenuCore 三页；展示值直接取当前 Godot 战斗规则。
## 页窗上方是战力条（XPowerStrip，installCombatPowerRuntime）；本页布局尚未按正式版逐像素复现，战力条跟着页窗的位置走。
var page := 0
var power_strip: XPowerStrip

func rebuild() -> void:
	super.rebuild()
	var vs := get_viewport_rect().size
	var top := VBoxContainer.new()
	window_at(Rect2(0, 0, vs.x, 280)).add_child(top)
	selector(top)
	var tabs := HBoxContainer.new()
	top.add_child(tabs)
	for i in range(4):
		var b := XUI.button(["状态", "加成与抗性", "掌握", "套装"][i], 40)
		var idx := i
		b.pressed.connect(func(): page = idx; rebuild())
		if page == i:
			b.add_theme_stylebox_override("normal", XUI.cursor_style(0.5))
		tabs.add_child(b)
	var back := XUI.button("返回", 40)
	back.pressed.connect(func(): closed.emit())
	tabs.add_child(back)
	actor_summary(top, true)
	# 战力条（XPowerStrip）占页窗原位置的上 36，页窗下移；关掉战力时没有
	var page_rect := Rect2(0, 280, vs.x, vs.y - 280)
	power_strip = XPowerStrip.make(content, actor(), page_rect.position.y, vs.x)
	if power_strip != null:
		page_rect = page_rect.grow_side(SIDE_TOP, -XPowerStrip.HEIGHT)
	var body := scroll_column(window_at(page_rect))
	match page:
		0: _params(body)
		1: _resistances(body)
		2: _mastery(body)
		3: _suits(body)
	(tabs.get_child(page) as Button).grab_focus.call_deferred()

func _params(parent: Control) -> void:
	var a := actor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	parent.add_child(row)
	var params := XDB.plugin("JAH_StatusMenuCore")
	for col in range(2):
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(list)
		for i in range(col * 13 + 1, col * 13 + 14):
			var symbol := str(params.get("Parameter %d Symbol" % i, ""))
			if symbol == "":
				var blank := Control.new()
				blank.custom_minimum_size.y = 36
				list.add_child(blank)
				continue
			var val := float(a.get(symbol))
			pair(list, str(params.get("Parameter %d Name" % i, symbol)), "%d%%" % roundi(val * 100) if str(params.get("Parameter %d as %%" % i, "true")) == "true" else str(int(val)))
	var equips := VBoxContainer.new()
	equips.custom_minimum_size.x = 360
	row.add_child(equips)
	equips.add_child(XUI.label("装备", 22, XUI.SYSTEM))
	for i in range(a.equips.size()):
		var e = a.equips[i]
		if e == null or e.is_empty():
			continue
		var l := XUI.label("%s  %s" % [XDB.system().equipTypes[i + 1], XQuality.list_name(e)], 20, XGear.color(e))
		l.tooltip_text = XText.plain(str(e.get("description", "")))
		equips.add_child(l)

func _resistances(parent: Control) -> void:
	var a := actor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	parent.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	row.add_child(grid)
	for title in ["元素", "加成", "穿透", "承伤"]:
		grid.add_child(XUI.label(title, 22, XUI.SYSTEM))
	for i in range(1, XDB.system().elements.size()):
		grid.add_child(XUI.label(str(XDB.system().elements[i]), 22, XUI.SYSTEM))
		grid.add_child(XUI.label("%d%%" % roundi(XDamage.element_bonus(a, i) * 100), 22))
		var cache := a.passive_cache()
		var fixed := float(cache.get("penetrateFixed", {}).get(i, 0))
		var percent := float(cache.get("penetratePercent", {}).get(i, 0))
		grid.add_child(XUI.label("%d / %d%%" % [fixed, percent], 22))
		var rate := a.element_rate(i)
		grid.add_child(XUI.label("%d%%" % roundi(rate * 100), 22, XUI.POWER_UP if rate < 1 else (XUI.POWER_DOWN if rate > 1 else XUI.TEXT)))
	var weapons := VBoxContainer.new()
	weapons.custom_minimum_size.x = 220
	row.add_child(weapons)
	weapons.add_child(XUI.label("武器加成", 22, XUI.SYSTEM))
	for i in range(1, XDB.system().weaponTypes.size()):
		pair(weapons, str(XDB.system().weaponTypes[i]), "%d%%" % roundi(float(a.passive_cache().get("SkETypeHarmRi", {}).get(i, 0)) * 100), XUI.TEXT, 110)
	var other := VBoxContainer.new()
	other.custom_minimum_size.x = 270
	row.add_child(other)
	other.add_child(XUI.label("其他加成", 22, XUI.SYSTEM))
	pair(other, "爆伤加成", "%d%%" % roundi((XDamage.critical_multiplier_bonus(a) + float(a.passive_cache().get("critHarmRi", 0))) * 100))
	pair(other, "终伤加成", "%d%%" % roundi(float(a.passive_cache().get("globalHarmRi", 0)) * 100))
	var extra := 0.0
	for t in a.all_traits():
		if int(t.code) == 61:
			extra += float(t.value)
	pair(other, "再次行动", "%d%%" % roundi(extra * 100))
	pair(other, "攻击次数", str(1 + maxi(0, floori(a.traits_sum_all(XBattler.TRAIT_ATTACK_TIMES)))))
	var drop := 0.0
	for member in XState.current.battle_members():
		for value in member.passive_values("passiveIRUP"):
			drop = maxf(drop, XActor._num(value))
	pair(other, "全队掉率", "+%d%%" % roundi(((1+drop/100)*XEquipSuits.reward(XState.current.members(),1,2)-1)*100))
	pair(other, "套装经验", "+%d%%" % roundi((XEquipSuits.reward(XState.current.members(),100,0)/100-1)*100))
	pair(other, "套装金钱", "+%d%%" % roundi((XEquipSuits.reward(XState.current.members(),100,1)/100-1)*100))
	parent.add_child(XUI.label("穿透：固定值 / 百分比；承伤：100% 为正常，越低受到的伤害越少。", 20, XUI.DIM))

func _mastery(parent: Control) -> void:
	parent.add_child(XUI.label("角色可使用", 26, XUI.SYSTEM))
	var a := actor()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 120)
	parent.add_child(row)
	for spec in [["武器", "weaponTypes", 51, "passiveEWPN"], ["防具", "armorTypes", 52, "passiveEARM"]]:
		var col := VBoxContainer.new()
		row.add_child(col)
		col.add_child(XUI.label(spec[0], 26, XUI.SYSTEM))
		var types: Array = XDB.system()[spec[1]]
		for i in range(1, types.size()):
			if a.traits_set(spec[2]).has(i) or not a.passive_values("%s%02d" % [spec[3], i]).is_empty():
				col.add_child(XUI.label(str(types[i]), 24, XUI.MP_COST))

func _suits(parent: Control) -> void:
	var counts := XEquipSuits.counts(actor())
	if counts.is_empty():XGearInfo.text(parent,"当前装备没有套装。",XUI.DIM)
	for id in counts:
		var suit := XDB.rec("EquipSuits",int(id))
		if suit.is_empty():continue
		XGearInfo.text(parent,"%s · 已装备 %d 件"%[suit.name,int(counts[id])],XUI.SYSTEM,26)
		for bonus in suit.bonuses:
			var active := int(counts[id])>=int(bonus.requirePieces)
			XGearInfo.text(parent,"%d 件 %s：%s"%[int(bonus.requirePieces),"已生效" if active else "未激活",XGearInfo.bonus_text(bonus)],XUI.POWER_UP if active else XUI.DIM)
	XGearInfo.text(parent,"满足件数的各档加成同时生效；队伍奖励按全队套装计算。",XUI.DIM,20)
