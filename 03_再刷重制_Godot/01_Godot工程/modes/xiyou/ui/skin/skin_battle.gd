class_name XSkinBattle
extends RefCounted
## 【cc·天启篇·未经审查】新界面 2A／2B：战斗指令环、战技／物品列表、目标提示（2A），右侧队伍条、行动顺序、首领血弧＋状态胶囊、
## 我方状态详情（2B）的接线（XBattleScene 只在这里问开关）。
## 只在 XUiSkin.on() 时走新组件；关着时 XBattleScene 照旧建 XBattleList，代码一行不变。
## 全是只读：不改战斗计算、行动顺序和随机数（能不能用、费用、冷却都读 XBattleLogic 现成的结果）。

## 目标范围（RPG Maker scope 0～11）
const SCOPE_TEXT := {
	0: "", 1: "敌方单体", 2: "敌方全体", 3: "敌方随机 1 个", 4: "敌方随机 2 个", 5: "敌方随机 3 个", 6: "敌方随机 4 个",
	7: "我方单体", 8: "我方全体", 9: "我方单体（倒下的）", 10: "我方全体（倒下的）", 11: "自己",
}

static func on() -> bool:
	return XUiSkin.on()


## 收口批（CORE_V2）：战斗里旧说明卡（XHelpCard）挪到行动顺序条上面——卡底不低于行动条顶（XSkinOTBBar.POS.y）再空 12，
## 太高就贴屏幕上沿 8；横向不动。pos、size 是 ui 坐标（不含 _origin）。
static func help_card_pos(pos: Vector2, size: Vector2) -> Vector2:
	var limit: float = XSkinOTBBar.POS.y - 12.0
	if pos.y + size.y > limit:
		pos.y = maxf(8.0, limit - size.y)
	return pos


## 图标贴图：转到 XUiSkin.icon（1A 修白块的缓存，已进 main）
static func icon(index: int) -> Texture2D:
	return XUiSkin.icon(index)


## 指令窗：开着新皮肤时是指令环，关着是原 XBattleList（同 XBattleList.create）
static func command(parent: Control, opts: Array, width: float, a: XActor) -> XBattleList:
	if not on():
		return XBattleList.create(parent, opts, width, "center")
	return XSkinBattleRing.create_ring(parent, opts, a.display_name() if a != null else "")


## 技能／物品列表：rows 是 XBattleScene._list_entry 的结果（开着新皮肤时先过 decorate_all）；关着是原 XBattleList
static func list(parent: Control, rows: Array, width: float, items: bool, a: XActor, title := "") -> XBattleList:
	if not on():
		return XBattleList.create(parent, rows, width)
	if title == "":
		title = "物品" if items else "技能"
	return XSkinBattleSkillList.create_list(parent, rows, title, header_text(a, items))


## 每行补上「不能用的原因」「目标」「用完剩多少」（在 XActor.read_begin／read_end 之间调，都是只读）
static func decorate_all(logic: XBattleLogic, a: XActor, entries: Array, rows: Array, items: bool) -> Array:
	var out := []
	for i in rows.size():
		out.append(decorate(logic, a, entries[i], rows[i], items))
	return out


## 列表右上：技能列表写行动者现有 MP、TP；物品不写
static func header_text(a: XActor, items: bool) -> String:
	if items or a == null:
		return ""
	return "MP %s　TP %s" % [XMenu._group(floori(a.mp)), XMenu._group(floori(a.tp))]


## 一行补上新列表要的字段：reason（不能用才有）、skin_costs（[{text, color, icon}]）、target、left
static func decorate(logic: XBattleLogic, a: XActor, e: Dictionary, row: Dictionary, items: bool) -> Dictionary:
	var r := row.duplicate()
	var enabled := bool(row.get("enabled", true))
	r.reason = "" if enabled else reason(logic, a, e, items)
	r.skin_costs = skin_costs(logic, a, e, row, items)
	r.target = target_text(a, e)
	r.left = left_text(logic, a, e, items)
	r.desc = desc_text(e)
	return r


## 说明栏第一行：技能／物品说明的第一句（T096，同样稿「凝聚圣光之力打击敌人。」；去掉 MV 转义码，只取第一行）
static func desc_text(e: Dictionary) -> String:
	var lines := Array(XMVText.plain(str(e.get("description", ""))).split("\n", false)).map(func(x): return str(x).strip_edges()).filter(func(x): return x != "")
	if lines.is_empty():
		return ""
	# 技能说明第一行多是分类小标签（「特技」「被动」「战技」「本命·增强·…」，短）：有第二行就取第二行
	if lines.size() > 1 and str(lines[0]).length() <= 10:
		return str(lines[1])
	return str(lines[0])


## ---- T096：旧说明卡收起 ----
## 新界面开着时，战技／物品列表旁的旧说明卡（XHelpCard：品质、伤害公式、武器限制……）默认收起，一句话说明进列表底部说明栏；
## 按「详情」（键盘 Y、手柄 Y、点列表标题旁的「详情」）展开／再收起，本场战斗内记住。
## HELP_COLLAPSE＝false：照旧一直显示旧说明卡（可回退）。
static var HELP_COLLAPSE := true
static var help_open := false


## XBattleScene._help 问：这次要不要显示旧说明卡
static func help_card_shown() -> bool:
	return not (on() and HELP_COLLAPSE) or help_open


## 不能用的原因（只在用不了时调）：照 XBattleLogic.can_use 的先后，认得出的写具体原因，其余写「现在不能用」
static func reason(logic: XBattleLogic, a: XActor, e: Dictionary, items: bool) -> String:
	if a == null or logic == null:
		return "现在不能用"
	if items:
		return "现在不能用"
	var id := int(e.get("id", 0))
	var wu := ceili(float(a.warmups.get(id, 0)))
	if wu > 0:
		return "预热 %d 回合" % wu
	var cd := ceili(float(a.cooldowns.get(id, 0)))
	if cd > 0:
		return "冷却 %d 回合" % cd
	if XTianqiQiyinEffects.silenced(logic, a) and not a.is_attack(e) and id != XBattleLogic.GUARD_SKILL:
		return "沉默中"
	if int(e.get("stypeId", 0)) > 0 and a.traits_set(XBattler.TRAIT_STYPE_SEAL).has(int(e.stypeId)):
		return "被封印"
	if a.traits_set(XBattler.TRAIT_SKILL_SEAL).has(id):
		return "被封印"
	if not logic.can_pay_items(a, e):
		return "物品不够"
	if not XBattleLogic.can_pay_hp(a, e):
		return "生命不够"
	var c := logic.skill_cost(a, e)
	if a.tp < float(c.tp):
		return "TP 不够"
	var mp = XAlienBattle.glutton_mp(a)
	if (a.mp if mp == null else float(mp)) < float(c.mp):
		return "MP 不够"
	return "现在不能用"


## 右侧消耗：TP／MP／生命写成「TP 5」（窄体数字、按资源上色）；物品数量、物品费用、自定义费用、元素徽记照原行的字和图标
static func skin_costs(logic: XBattleLogic, a: XActor, e: Dictionary, row: Dictionary, items: bool) -> Array:
	var out := []
	if items:
		for c in row.get("costs", []):
			out.append({"text": str(c.get("text", "")), "color": XUiSkin.GOLD_LIGHT, "icon": int(c.get("icon", 0))})
		return out
	var c := logic.skill_cost(a, e) if a != null and logic != null else {"tp": 0, "mp": 0}
	if int(c.tp) > 0:
		out.append({"text": "TP %s" % XMenu._group(int(c.tp)), "color": XUiSkin.TP})
	if int(c.mp) > 0:
		out.append({"text": "MP %s" % XMenu._group(int(c.mp)), "color": XUiSkin.MP})
	var hp := XBattleLogic.skill_hp_cost(a, e) if a != null else 0
	if hp > 0:
		out.append({"text": "生命 %s" % XMenu._group(hp), "color": XUiSkin.HP})
	# 原行里别的段（物品费用、自定义费用、元素徽记）：TP／MP／HP 图标与冷却、预热之外的照搬
	for k in row.get("costs", []):
		var ic := int(k.get("icon", 0))
		if ic in [1268, 1269, 1266, 1045]:
			continue
		out.append({"text": str(k.get("text", "")), "color": XUiSkin.TEXT_2, "icon": ic})
	return out


## 目标：读异化投影后的范围（选目标时也按投影走）
static func target_text(a: XActor, e: Dictionary) -> String:
	var sk := XAlienBattle.project(a, e) if a != null else e
	return str(SCOPE_TEXT.get(int(sk.get("scope", 0)), ""))


## 用完剩多少：技能写用完剩的 TP／MP／生命；会消耗的物品写用完剩几个
static func left_text(logic: XBattleLogic, a: XActor, e: Dictionary, items: bool) -> String:
	if a == null or logic == null:
		return ""
	if items:
		if not bool(e.get("consumable", true)):
			return ""
		return "用完剩 ×%s" % XMenu._group(maxi(0, logic.state.item_count(int(e.get("id", 0))) - 1))
	var c := logic.skill_cost(a, e)
	var parts := []
	if int(c.tp) > 0:
		parts.append("TP %s" % XMenu._group(floori(a.tp) - int(c.tp)))
	if int(c.mp) > 0:
		parts.append("MP %s" % XMenu._group(floori(a.mp) - int(c.mp)))
	var hp := XBattleLogic.skill_hp_cost(a, e)
	if hp > 0:
		parts.append("生命 %s" % XMenu._group(floori(a.hp) - hp))
	if parts.is_empty():
		return ""
	return "用完剩 " + "、".join(parts)


## 目标提示：开着新皮肤时在选中的目标头上挂提示（名字＋范围），null 收起；关着什么也不做
static func target_hint(scene: XBattleScene, b, skill: Dictionary, group: Array) -> void:
	if not on():
		return
	var hint: XSkinTargetHint = scene.get_meta("skin_target_hint") if scene.has_meta("skin_target_hint") else null
	if hint != null and not is_instance_valid(hint):
		hint = null
	if b == null:
		if hint != null:
			hint.visible = false
		return
	if hint == null:
		hint = XSkinTargetHint.new()
		scene.ui.add_child(hint)
		scene.set_meta("skin_target_hint", hint)
	var s: XBattlerSprite = scene.sprites.get(b)
	if s == null:
		hint.visible = false
		return
	var scope := target_text(scene._active, skill) if not skill.is_empty() else ""
	var name := str(b.display_name())
	var sub := scope
	if group.size() > 1:
		sub = "%s · %d 个" % [scope, group.size()] if scope != "" else "%d 个" % group.size()
	scene.ui.move_child(hint, -1)
	hint.show_for(name, sub, scene._origin + s.position, s.height(), b is XEnemy)


## ---- 2B：右侧队伍条、行动顺序、首领血弧与状态、我方状态详情 ----
## 开关关着时每个都给原来的类（同 XBattleScene 原来的 new()），一行不变。

## 右侧一名角色的状态行：开着是 XSkinSideStatus（队伍紧凑条的一行），关着是原 XSideStatus
static func side_status() -> XSideStatus:
	return XSkinSideStatus.new() if on() else XSideStatus.new()


## 队伍紧凑条的面板底（开着新皮肤时加在各行前面）；关着不加，返回 null
static func side_backdrop(holder: Control, count: int) -> Control:
	if not on():
		return null
	var back := XSkinSideStatus.Back.new()
	holder.add_child(back)
	back.count = count
	return back


## 行动顺序条
static func otb() -> XOTBBar:
	return XSkinOTBBar.new() if on() else XOTBBar.new()


## 首领血条：开着是顶上的大血弧
static func boss_hp() -> XBossHpBar:
	return XSkinBossArc.new() if on() else XBossHpBar.new()


## 首领状态面板：开着是血弧下的一排胶囊＋新皮肤详情；arc 是本场的首领血条（胶囊据此决定摆在弧下还是顶上）
static func boss_panel(arc: XBossHpBar) -> XBossStatusPanel:
	if not on():
		return XBossStatusPanel.new()
	var p := XSkinBossStatus.new()
	p.arc = arc
	return p


## 我方状态详情（点右侧状态格／新皮肤点整行）
static func status_panel(parent: Node, list: Array, who: XBattler) -> XPartyStatusPanel:
	if not on():
		return XPartyStatusPanel.open(parent, list, who)
	var p := XSkinPartyStatusPanel.new()
	p.members = list
	p.index = maxi(0, list.find(who))
	parent.add_child(p)
	return p


## 自动／变速两个按钮：开着新皮肤时换成黑底细线的胶囊（按下、悬停是红乙选中条），挪到挂机快捷界面（左上 20,10,240×74）下面，
## 免得被顶上的首领血弧压住；字和点了做什么都不变。关着什么也不做。
static var TOGGLE_POS := Vector2(20, 84)
## T125 可回退：ROUND_TOGGLES=false 回到 T096 120×46 横条胶囊（「变速 OFF」字样照旧）
static var ROUND_TOGGLES := true


static func toggle_display_lines(raw_text: String) -> PackedStringArray:
	if raw_text.begins_with("自动"):
		return PackedStringArray(["自动", "开" if raw_text.contains("开") else "关"])
	if raw_text.begins_with("变速"):
		if raw_text.contains("二倍"):
			return PackedStringArray(["变速", "×2"])
		if raw_text.contains("三倍"):
			return PackedStringArray(["变速", "×3"])
		if raw_text.contains("四倍"):
			return PackedStringArray(["变速", "×4"])
		return PackedStringArray(["变速", "×1"])
	return PackedStringArray([raw_text, ""])


static func _draw_round_toggle(btn: Button) -> void:
	if not ROUND_TOGGLES or not is_instance_valid(btn):
		return
	var sz := btn.size
	var c := sz / 2.0
	var r := minf(sz.x, sz.y) / 2.0
	var lines := toggle_display_lines(btn.text)
	var active_state := lines[1] == "开" or (lines[1].begins_with("×") and lines[1] != "×1")
	if active_state:
		btn.draw_texture_rect(XUiSkin.glow_texture(), Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false,
			Color(0.85, 0.28, 0.18, 0.28))
		btn.draw_arc(c, r - 3.5, 0.0, TAU, 40, Color(XUiSkin.GOLD, 0.55), 1.1, true)
	else:
		btn.draw_arc(c, r - 3.5, 0.0, TAU, 40, Color(XUiSkin.GOLD, 0.22), 0.9, true)
	var body := XUiSkin.font("body")
	var num := XUiSkin.font("num")
	var fs1 := 13
	var w1 := body.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	var p1 := Vector2(c.x - w1 / 2.0, c.y - 3.0)
	btn.draw_string_outline(body, p1, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, 3, Color(0, 0, 0, 0.75))
	XUiSkin.ds(btn, body, p1, lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(XUiSkin.GOLD_LIGHT if active_state else XUiSkin.TEXT_2))
	if lines[1] != "":
		var is_mul := lines[1].begins_with("×")
		var f2 := num if is_mul else body
		var fs2 := 18 if is_mul else 16
		var w2 := f2.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var p2 := Vector2(c.x - w2 / 2.0, c.y + 16.0)
		var c2 := XUiSkin.GOLD_LIGHT if active_state else XUiSkin.TEXT
		btn.draw_string_outline(f2, p2, lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 3, Color(0, 0, 0, 0.85))
		XUiSkin.ds(btn, f2, p2, lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, c2)


static func style_toggles(side: Control, buttons: Array, origin: Vector2) -> void:
	if not on():
		return
	side.position = Vector2(TOGGLE_POS.x, origin.y + TOGGLE_POS.y)   # x 贴屏幕左边（同挂机快捷界面），宽屏不跟 1280 居中（核查返工）
	if XSkin4A.hud_on() and side.is_inside_tree():   # 新界面 4A：挂机胶囊贴安全边距，这两颗跟它左对齐
		side.position.x = XSkin4A.safe_rect(side).position.x
	if not ROUND_TOGGLES:
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(XUiSkin.BG, 0.85)
		normal.border_color = Color(XUiSkin.LINE, 0.6)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(23)
		normal.content_margin_left = 14
		normal.content_margin_right = 14
		for b in buttons:
			var btn := b as Button
			btn.custom_minimum_size = Vector2(120, 46)
			btn.clip_text = false
			btn.add_theme_font_override("font", XUiSkin.font("body"))
			btn.add_theme_font_size_override("font_size", 16)
			btn.add_theme_stylebox_override("normal", normal)
			btn.add_theme_stylebox_override("hover", XUiSkin.select_style_for(XUiSkin.SelState.HOVER if XUiSkin.SELECT_V2 else XUiSkin.SelState.FOCUS))
			btn.add_theme_stylebox_override("pressed", XUiSkin.select_style_for(XUiSkin.SelState.PRESSED if XUiSkin.SELECT_V2 else XUiSkin.SelState.FOCUS))
			for k in ["font_color", "font_hover_color", "font_pressed_color"]:
				btn.add_theme_color_override(k, XUiSkin.TEXT)
			btn.queue_redraw()
		return
	var r_norm := StyleBoxFlat.new()
	r_norm.bg_color = Color(0.065, 0.052, 0.048, 0.72)
	r_norm.border_color = Color(XUiSkin.GOLD, 0.56)
	r_norm.set_border_width_all(1)
	r_norm.set_corner_radius_all(30)
	var r_hover := r_norm.duplicate() as StyleBoxFlat
	r_hover.bg_color = Color(0.24, 0.09, 0.07, 0.82)
	r_hover.border_color = Color(XUiSkin.SEL_LINE, 0.85)
	var r_press := r_norm.duplicate() as StyleBoxFlat
	r_press.bg_color = Color(0.38, 0.11, 0.08, 0.90)
	r_press.border_color = XUiSkin.SEL_LINE
	for b in buttons:
		var btn := b as Button
		btn.custom_minimum_size = Vector2(60, 60)
		btn.clip_text = true
		btn.add_theme_stylebox_override("normal", r_norm)
		btn.add_theme_stylebox_override("hover", r_hover)
		btn.add_theme_stylebox_override("pressed", r_press)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			btn.add_theme_color_override(k, Color(0, 0, 0, 0))
		if not btn.has_meta("skin_round_drawn"):
			btn.set_meta("skin_round_drawn", true)
			btn.draw.connect(_draw_round_toggle.bind(btn))
		btn.queue_redraw()


## ---- T096：换人回合提示 ----
## 轮到我方某人输入指令时：旧金圈从他身上扩开两道、头上弹出「某某 的回合」胶囊（样稿 .horn、.tname），约 0.8 秒后淡掉，
## 交给指令环上方的「某某的行动」。动效关、皮肤关时什么也不做。
static func turn_cue(scene: XBattleScene, a: XActor) -> void:
	if not XSkinBattleMotion.on() or a == null:
		return
	var s: XBattlerSprite = scene.sprites.get(a)
	if s == null:
		return
	var cue := XSkinTurnCue.new()
	cue.who = str(a.display_name())
	cue.feet = scene._origin + s.position
	cue.body_h = s.height()
	scene.ui.add_child(cue)
	scene.ui.move_child(cue, -1)
