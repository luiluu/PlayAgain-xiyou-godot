class_name XAlienWorkshop
extends Control
## 异化工坊（主菜单「异化工坊」→ CodexAlienation.openWorkshop；正式 installAlienationWorkshop）。原版不是 MV 窗口，是盖在菜单上的
## 网页叠加层 #alien-workshop（暗底 #070912e8，居中面板宽 1080、底 #151325、边 #72618d 圆角 12、内边距 22，字 17px）。
## 这里先按原版 render() 搭出同样的节点树（build：标签、class、文字、按钮可否点），再照它的 CSS 摆成 Godot 控件；
## 测试直接比对节点树（tests/xiyou_alien_workshop，参照 alien_workshop_probe.cjs 的 jsdom 读数）。
## 页：标题＋返回；能量与异化石＋合成；有待选重抽时只显示两张选择卡；否则左列表右详情（重抽、分解与确认、配置异化），
## 没有异化装备时右侧是获取说明；最后是可展开的「最近异化掉落」。Esc 关闭。规则在 XAlienation。
## 「配置异化」（期二）在详情下方展开「战前技能配置」：使用角色，再按词条给绑定队友／作用技能／借用武器／替换原生技能／两组借入技能；
## 原版是网页下拉框，这里用 OptionButton（节点树里是 select，记选项与当前值）。保存成功或取消就收起，保存失败留在原处并显示错误。
## 外观（八戒_63 成对截图补）：原版另有 installGamePanelTheme 盖在工坊自带 CSS 上，实际画面是「游戏窗口」主题（与 XWebPanel 同一套）：
## 暗底黑 0.5；面板底 #16161f、Window 皮肤边框 12px、内边距 16/20（面板 x100 宽 1080，内容 x132 宽 1016）；正文 18 号白字黑描边、行高 1.6；
## h1 28／h2 22 粗体白、h3 18 粗体系统色；标题区下 1px 分隔线（下内距 10、下距 12）；资源条金字、黑 0.3 底、金 0.45 边、内距 12/14（下距 15）；
## 说明 #c9ced8；收益 #98e598、代价 #ff8f86；按钮 17 号、黑 0.28 底、白 0.4 边、圆角 6、内距 9/12、高 47.2，
## 合成／重抽／采用新／保存配置／确认类加青边（gp-primary），分解类红字红边（gp-danger），不可点整体 0.4；
## 列表宽 33%（右 1px 分隔线、右内距 14），与详情间距 20；分解确认框暗红底红边；配置框黑 0.25 底、白 0.22 边、无内距。
## 相邻按钮原版另有 margin-left 7（button+button）：操作行间距 8+7＝15、确认框里两键同一行间隔 7，照画；
## 列表里第 2 个起也被右推 7 并撑出横向滚动条——O-087 不照搬，列表按钮左对齐、不出横向滚动条。

signal closed

const BACKDROP := Color(0, 0, 0, 0.5)
const PANE := Color("16161f")
const TEXT := XWebPanel.TEXT
const NOTE := XWebPanel.MUTED
const GOOD := Color("98e598")
const BAD := Color("ff8f86")
const PRIMARY := Color(160 / 255.0, 230 / 255.0, 235 / 255.0, 0.14)
const SUMMARY_BACK := Color(0, 0, 0, 0.3)
const SUMMARY_EDGE := Color(1, 211 / 255.0, 115 / 255.0, 0.45)
const SECTION_BACK := Color(0, 0, 0, 0.25)
const CONFIRM_BACK := Color(80 / 255.0, 20 / 255.0, 20 / 255.0, 0.45)
const FIELDSET_EDGE := Color("665572")
const ERROR := Color("ffb5ba")
const ERROR_BACK := Color("512934")
const SIZES := {"h1": 28, "h2": 22, "h3": 18}
const BODY_SIZE := 18
const BUTTON_SIZE := 17
const BUTTON_H := 47.19                    # 17×1.6 ＋ 内距 9×2 ＋ 边 1×2
const PANE_W := 1080.0
const PANE_BORDER := 12.0
const PANE_PAD := Vector2(20, 16)
const LIST_W := 1016.0 * 0.33              # .alien-list width:33%（含右内距 14 与 1px 线）
const PRIMARY_RE := "采用新|保存配置|合成|能量 →|应用到|使用1颗|开始抽取|确认"
const DANGER_RE := "确认分解|分解为"
## 优化 O-087：false（默认）列表按钮左对齐、不出横向滚动条；true 照原版 button+button 把第 2 个起右推 7，宽仍 100%，撑出横向滚动条
static var list_indent_quirk := false
const PARAM_NAMES := ["生命", "法力", "物攻", "物防", "魔攻", "魔防", "速度", "幸运"]

## 选中的异化装备 uid：原版是工坊模块的变量，关掉再开、读档后都还记着（uid 对上才生效）
static var selected := ""
var confirming := false
## 配置页：是否展开、打开时的已存配置（原版 configure 打开时取一次）、各下拉框当前值（null＝没选中）
var cfg_open := false
var cfg_saved := {}
var cfg_vals := {}
var error_text := ""
var recent_open := false
var root: Control
## 列表按钮的选中样式：原版只在整页重画（render）时按当时的 selected 定；展开配置、分解确认、换下拉框、出错都只是局部改动，不重画列表
var shown_selected := ""
## 最近一次 render 的节点树（屏上显示的就是它；测试读它、按它点按钮）
var tree: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	var back := ColorRect.new()
	back.color = BACKDROP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	render()


func s() -> XState:
	return XState.current


func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## ---- 节点树（原版 render 的 DOM） ----

static func el(tag: String, text = null, cls := "", children := []) -> Dictionary:
	var n := {"tag": tag, "children": children}
	if text != null:
		n.text = str(text)
	if cls != "":
		n.class = cls
	return n


static func btn(text: String, on: Callable, disabled := false, cls := "") -> Dictionary:
	var n := el("button", text, cls)
	n.disabled = disabled
	n.on = on
	return n


static func num(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


func build() -> Array:
	var st := s()
	var cfg := XAlienation.config()
	var energy := st.item_count(XAlienation.energy_id())
	var stones := st.item_count(XAlienation.stone_id())
	var lg := XAlienation.ledger(st)
	var pane := []
	pane.append(el("div", null, "alien-heading", [el("h1", "异化工坊"), btn("返回", close)]))
	pane.append(el("div", null, "alien-summary", [el("span", "异化能量 %d　异化石 %d" % [energy, stones]),
		btn("20点能量 → 1颗异化石", _act.bind(func(): return XAlienation.craft(st, 1)), lg.pending != null or energy < 20)]))
	var err := el("p", error_text, "alien-error")
	if error_text == "":
		err.hidden = true
	pane.append(err)
	if lg.pending != null:
		var p: Dictionary = lg.pending
		var i = XAlienation.pending_item(st)
		pane.append(el("h2", "选择本次重抽结果"))
		pane.append(el("p", "异化石已经消耗。两种选择均不返还材料，关闭界面会保留本次待选结果。"))
		if i == null:
			err.text = "待选装备不可用，请保留当前存档以便检查。"
			err.erase("hidden")
			return [el("div", null, "alien-pane", pane)]
		pane.append(el("h3", i.name))
		var cards := []
		for x in [[p.old, "保留旧异化", false], [p.next, "采用新异化", true]]:
			var f := XAlienation.affix(str(x[0]))
			cards.append(el("section", null, "", [el("h2", f.name), el("p", "收益：" + str(f.benefit), "alien-benefit"),
				el("p", "代价：" + str(f.cost), "alien-cost"), btn(x[1], _act.bind(XAlienation.resolve.bind(st, x[2])))]))
		pane.append(el("div", null, "alien-choices", cards))
		return [el("div", null, "alien-pane", pane)]
	pane.append(el("p", "普通装备不能使用异化石。每名角色最多穿戴一件异化装备；需配置的词条请先配置再穿戴。", "alien-note"))
	var list := []
	var detail := []
	var all := XAlienation.owned(st).filter(func(e): return not XAlienation.mark(e).is_empty())
	if all.is_empty():
		list.append(el("p", "尚未获得异化装备。"))
		var maps := []
		for id in cfg.get("mobMaps", []):
			var info := XDB.rec("MapInfos", int(id))
			if not info.is_empty() and str(info.get("name", "")) != "":
				maps.append(str(info.name))
		var guide := [el("h2", "如何获得异化装备")]
		for t in ["在" + "、".join(PackedStringArray(maps)) + "的小怪战斗中，每场有1%机会出现紫色的异化敌人。" if not maps.is_empty() else "",
				"部分Boss每场最多有1%机会异化，奖励来自该Boss装备池的强力异化装备。",
				"击败异化敌人并赢得战斗，必定掉落一件异化装备；逃跑或失败不会掉落。",
				"重复的异化装备可以分解为异化能量（小怪装备1点、Boss装备5点），%d点合成1颗异化石，用来重抽已有异化装备的词条。" % int(cfg.energyCost)]:
			if t != "":
				guide.append(el("p", t))
		detail.append(el("div", null, "alien-guide", guide))
	for i in all:
		var uid := str(XAlienation.mark(i).uid)
		list.append(btn(str(i.name) + ("　[锁定]" if XAlienation.locked(i) else ""), _select.bind(uid), false, "selected" if uid == shown_selected else ""))
	var picked = all.filter(func(e): return str(XAlienation.mark(e).uid) == selected)
	var item = picked[0] if not picked.is_empty() else (all[0] if not all.is_empty() else null)
	if item != null:
		selected = str(XAlienation.mark(item).uid)
		detail.append(el("h2", item.name))
		for t in XAlienation.details(st, item):
			detail.append(el("p", t, "alien-benefit" if t.begins_with("收益：") else ("alien-cost" if t.begins_with("代价：") else "")))
		detail.append(el("p", "品质、普通词条、强化、镶嵌和独立成长全部保留。"))
		var stats := []
		for n in 8:
			var v := float(item.get("params", [0, 0, 0, 0, 0, 0, 0, 0])[n])
			if v != 0:
				stats.append(PARAM_NAMES[n] + ("+" if v > 0 else "") + num(v))
		detail.append(el("p", "装备属性：" + "　".join(PackedStringArray(stats)), "alien-note"))
		var eligible := XAlienation.can_operate(st, item)
		if not eligible:
			detail.append(el("p", "操作前请卸下装备、解除锁定与绑定。"))
		var boss := str(XAlienation.mark(item).origin) == "boss"
		var actions := [btn("使用1颗异化石重抽", _act.bind(XAlienation.reroll.bind(st, item)), not eligible or stones < 1),
			btn("分解为%d点能量" % (5 if boss else 1), _confirm, not eligible)]
		if XAlienation.needs_configuration(item):
			actions.append(btn("配置异化", _open_config.bind(item), not eligible))
		detail.append(el("div", null, "alien-actions", actions))
		if confirming:
			detail.append(el("section", null, "alien-confirm", [el("h3", "确认分解 " + str(item.name)),
				el("p", "整件装备及其普通词条、强化、宝石、经验和成长将全部销毁。分解不会保留异化词条。"),
				btn("确认分解", _dismantle.bind(item)), btn("取消", _cancel_confirm)]))
		if cfg_open:
			detail.append(_config_section(st, item))
	pane.append(el("div", null, "alien-body", [el("div", null, "alien-list", list), el("div", null, "alien-detail", detail)]))
	var recent: Array = lg.recent
	if not recent.is_empty():
		var rows := [btn("最近异化掉落（%d）" % recent.size(), _toggle_recent, false, "summary")]
		rows[0].tag = "summary"
		for r in recent.slice(0, 10):
			rows.append(el("p", str(r.name) + "　" + ("Boss" if str(r.origin) == "boss" else "小怪")))
		pane.append(el("details", null, "", rows))
	return [el("div", null, "alien-pane", pane)]


## 与参照 dump 同口径的展平：深度、标签、class、文字、按钮可否点、hidden；带文字的节点不再往下走
static func flatten(nodes: Array, depth := 0, out := []) -> Array:
	for n in nodes:
		var row := {"tag": n.tag, "depth": depth}
		if n.has("class") and n.class != "summary":
			row.class = n.class
		if n.has("text"):
			row.text = n.text
		if n.tag == "select":
			row.options = n.options.map(func(o): return str(o.label))
			var hit: Array = n.options.filter(func(o): return n.value != null and str(o.value) == str(n.value))
			row.value = str(hit[0].label) if not hit.is_empty() else null
		if n.tag == "button":
			row.disabled = bool(n.get("disabled", false))
		if n.get("hidden", false):
			row.hidden = true
		out.append(row)
		if not n.has("text") or n.tag == "label":
			flatten(n.get("children", []), depth + 1, out)
	return out


## ---- 操作 ----

func _act(fn: Callable) -> void:
	var r: Dictionary = fn.call()
	error_text = str(r.error) if r.has("error") else ""
	if not r.has("error"):
		cfg_open = false
	render(r.has("error"))


func _select(uid: String) -> void:
	selected = uid
	confirming = false
	cfg_open = false
	render()


func _confirm() -> void:
	confirming = true
	render(true)


func _cancel_confirm() -> void:
	confirming = false
	cfg_open = false
	render()


func _dismantle(item: Dictionary) -> void:
	var r := XAlienation.dismantle(s(), item)
	if r.has("error"):
		error_text = str(r.error)
	else:
		error_text = ""
		selected = ""
		confirming = false
		cfg_open = false
	render(r.has("error"))


func _toggle_recent() -> void:
	recent_open = not recent_open
	render(true)


## 测试用：按按钮文字点（参照路线的写法）；@n 点列表第 n 项
func click(label: String) -> bool:
	var found := _find(tree, label)
	if found.is_empty() or bool(found.get("disabled", false)):
		return false
	found.on.call()
	return true


func _find(nodes: Array, label: String, list_index := [-1]) -> Dictionary:
	for n in nodes:
		if label.begins_with("@") and n.get("class", "") == "alien-list":
			var buttons: Array = n.children.filter(func(c): return c.tag == "button")
			var k := int(label.substr(1))
			return buttons[k] if k < buttons.size() else {}
		if not label.begins_with("@") and n.tag in ["button", "summary"] and n.get("text", "") == label:
			return n
		if not n.has("text"):
			var r := _find(n.children, label)
			if not r.is_empty():
				return r
	return {}


## ---- 配置异化（原版 configure） ----

static func _opt(value, label: String) -> Dictionary:
	return {"value": value, "label": label}


## 原版 select(parent,label,entries,value)：没给值选第一项；给的值不在选项里就什么都不选
static func _initial(options: Array, value):
	if value == null:
		return options[0].value if not options.is_empty() else null
	for o in options:
		if str(o.value) == str(value):
			return o.value
	return null


## Number(select.value)：没选中是 0
static func _num(v) -> int:
	return int(v) if v != null and str(v).is_valid_int() else 0


func _actor_options(st: XState) -> Array:
	return XAlienation.actors(st).map(func(a): return _opt(a.actor_id, a.display_name()))


func _field_kind(item: Dictionary) -> String:
	var k := str(XAlienation.mark(item).affix)
	if Array(XAlienation.config().boundKeys).has(k):
		return "bound"
	if Array(XAlienation.config().skillKeys).has(k):
		return "skill"
	if k in ["swallow", "mimic"]:
		return k
	return "faceless"


func _cfg_actor(st: XState) -> XActor:
	var id := _num(cfg_vals.get("actor"))
	return st.actor(id) if st.party.has(id) else null


func _skill_options(st: XState, item: Dictionary, actor: XActor) -> Array:
	var pool := "silence" if str(XAlienation.mark(item).affix) == "silence" else "attack"
	return XAlienation.original_active(actor).filter(func(sk): return XAlienation._in(pool, int(sk.id))).map(func(sk): return _opt(int(sk.id), str(sk.name)))


func _donor_options(st: XState, item: Dictionary) -> Array:
	var out := []
	for e in XAlienation.owned(st):
		if str(e.kind) == "weapon" and XAlienation.mark(e).is_empty() and not XAlienation.locked(e) and not XAlienation.reserved(st, e, item) and not XAlienation.effect_ghost(e).is_empty():
			out.append(_opt(str(e.instanceId), str(e.name)))
	return out


func _own_options(actor: XActor) -> Array:
	return XAlienation.original_active(actor).map(func(sk): return _opt(int(sk.id), str(sk.name)))


func _source_options(st: XState, actor: XActor) -> Array:
	return XAlienation.actors(st).filter(func(a): return a != actor).map(func(a): return _opt(a.actor_id, a.display_name()))


func _borrow_options(st: XState, actor: XActor, source) -> Array:
	var owner: XActor = st.actor(_num(source)) if _num(source) > 0 else null
	if owner == null or actor == null:
		return []
	return XAlienation.native_skills(owner).filter(func(sk): return owner.skill_ids.has(int(sk.id)) and XAlienation.borrowable(sk) and not actor.skill_ids.has(int(sk.id))).map(func(sk): return _opt(int(sk.id), str(sk.name)))


## fill()：按打开时的已存配置给各字段设初值（换使用角色时重来）
func _fill(st: XState, item: Dictionary) -> void:
	var c := cfg_saved
	var actor := _cfg_actor(st)
	if actor == null:
		cfg_vals.rows = []
		return
	match _field_kind(item):
		"bound":
			cfg_vals.partner = _initial(XAlienation.binding_options(st, actor, str(XAlienation.mark(item).affix)).map(func(a): return _opt(a.actor_id, a.display_name())), c.get("partnerId"))
		"skill":
			cfg_vals.skill = _initial(_skill_options(st, item, actor), c.get("skillId"))
		"swallow":
			cfg_vals.donor = _initial(_donor_options(st, item), c.get("donorId"))
		"mimic":
			cfg_vals.replace = _initial(_own_options(actor), c.get("replace"))
		_:
			var rows := []
			for n in 2:
				var pairs: Array = c.get("pairs", [])
				var p: Dictionary = pairs[n] if n < pairs.size() else {}
				var row := {"initial": p.get("skillId")}
				row.replace = _initial([_opt(0, "不配置")] + _own_options(actor), p.get("replaceId", 0) if p.get("replaceId", 0) else 0)
				row.source = _initial(_source_options(st, actor), p.get("ownerId"))
				row.skill = _initial(_borrow_options(st, actor, row.source), row.initial)
				rows.append(row)
			cfg_vals.rows = rows


func _open_config(item: Dictionary) -> void:
	var st := s()
	cfg_open = true
	cfg_saved = XAlienation.mark(item).get("config", {}).duplicate(true)
	var actors := _actor_options(st)
	cfg_vals = {"actor": _initial(actors, cfg_saved.get("actorId") if cfg_saved.get("actorId", 0) else (actors[0].value if not actors.is_empty() else null))}
	_fill(st, item)
	render(true)


func _select_node(label: String, options: Array, value, key: String) -> Dictionary:
	return el("label", label, "", [{"tag": "select", "options": options, "value": value, "key": key, "children": []}])


func _config_section(st: XState, item: Dictionary) -> Dictionary:
	var actor := _cfg_actor(st)
	var kids := [el("h3", "战前技能配置"), _select_node("使用角色", _actor_options(st), cfg_vals.get("actor"), "actor")]
	var fields := []
	var k := str(XAlienation.mark(item).affix)
	if actor != null:
		match _field_kind(item):
			"bound":
				fields.append(_select_node("绑定队友", XAlienation.binding_options(st, actor, k).map(func(a): return _opt(a.actor_id, a.display_name())), cfg_vals.get("partner"), "partner"))
				fields.append(el("p", "绑定对象需存活并出战，且不能被其他生命或夺舍关系重复占用。"))
				fields.append(btn("保存配置", _save_config.bind(item)))
				fields.append(btn("解除配置", _clear_config.bind(item)))
			"skill":
				fields.append(_select_node("作用技能", _skill_options(st, item, actor), cfg_vals.get("skill"), "skill"))
				fields.append(btn("保存配置", _save_config.bind(item)))
			"swallow":
				fields.append(_select_node("借用武器", _donor_options(st, item), cfg_vals.get("donor"), "donor"))
				fields.append(el("p", "仅借用登记特性；供体保留但被占用，战斗中关闭衣服栏。解除配置可释放供体。"))
				fields.append(btn("保存配置", _save_config.bind(item)))
				fields.append(btn("解除配置", _clear_config.bind(item)))
			"mimic":
				fields.append(_select_node("替换原生技能", _own_options(actor), cfg_vals.get("replace"), "replace"))
				fields.append(btn("保存配置", _save_config.bind(item)))
				fields.append(el("p", "每场战斗重新观察敌人；最多记录3项，只有一个仿形槽。"))
			_:
				for n in 2:
					var row: Dictionary = cfg_vals.rows[n]
					fields.append(el("fieldset", null, "", [el("legend", "借入技能 %d%s" % [n + 1, "（可留空）" if n else ""]),
						_select_node("替换原生技能", [_opt(0, "不配置")] + _own_options(actor), row.replace, "row%d.replace" % n),
						_select_node("来源角色", _source_options(st, actor), row.source, "row%d.source" % n),
						el("div", null, "", [_select_node("借入技能", _borrow_options(st, actor, row.source), row.skill, "row%d.skill" % n)])]))
				fields.append(btn("保存配置", _save_config.bind(item)))
	kids.append(el("div", null, "", fields))
	kids.append(btn("取消", _close_config))
	return el("section", null, "alien-config", kids)


## 下拉框换了值（actor 换人就重填各字段；来源角色换了就重填那一组的借入技能）
func set_value(key: String, value) -> void:
	var st := s()
	var item = _selected_item(st)
	if key.begins_with("row"):
		var n := int(key.substr(3, 1))
		var f := key.get_slice(".", 1)
		cfg_vals.rows[n][f] = value
		if f == "source":
			cfg_vals.rows[n].skill = _initial(_borrow_options(st, _cfg_actor(st), value), cfg_vals.rows[n].initial)
	else:
		cfg_vals[key] = value
		if key == "actor" and item != null:
			_fill(st, item)
	render(true)


func _selected_item(st: XState):
	var hit := XAlienation.owned(st).filter(func(e): return str(XAlienation.mark(e).get("uid", "")) == selected)
	return hit[0] if not hit.is_empty() else null


func _save_config(item: Dictionary) -> void:
	var st := s()
	var c := {"actorId": _num(cfg_vals.get("actor"))}
	match _field_kind(item):
		"bound":
			c.partnerId = _num(cfg_vals.get("partner"))
		"skill":
			c.skillId = _num(cfg_vals.get("skill"))
		"swallow":
			c.donorId = str(cfg_vals.get("donor")) if cfg_vals.get("donor") != null else ""
		"mimic":
			c.replace = _num(cfg_vals.get("replace"))
		_:
			c.pairs = cfg_vals.get("rows", []).filter(func(r): return _num(r.replace) > 0).map(func(r): return {"replaceId": _num(r.replace), "ownerId": _num(r.source), "skillId": _num(r.skill)})
	var r := XAlienation.configure(st, item, c)
	if r.has("error"):
		error_text = str(r.error)
	else:
		error_text = ""
		cfg_open = false
	render(r.has("error"))


func _clear_config(item: Dictionary) -> void:
	var r := XAlienation.clear_configuration(s(), item)
	if r.has("error"):
		error_text = str(r.error)
	else:
		error_text = ""
		cfg_open = false
	render(r.has("error"))


func _close_config() -> void:
	cfg_open = false
	error_text = ""
	render()


## 测试用：按标签找下拉框（"借入技能 2/来源角色" 先找那一组），选第 index 项
func choose_option(spec: String, index: int) -> bool:
	var scope := tree
	var label := spec
	if spec.contains("/"):
		var legend := spec.get_slice("/", 0)
		label = spec.get_slice("/", 1)
		var sets := _collect(tree, func(n): return n.tag == "fieldset" and str(n.children[0].text).begins_with(legend))
		if sets.is_empty():
			return false
		scope = [sets[0]]
	var labels := _collect(scope, func(n): return n.tag == "label" and str(n.get("text", "")) == label)
	if labels.is_empty():
		return false
	var sel: Dictionary = labels[0].children[0]
	if index < 0 or index >= sel.options.size():
		return false
	set_value(str(sel.key), sel.options[index].value)
	return true


static func _collect(nodes: Array, pred: Callable, out := []) -> Array:
	for n in nodes:
		if pred.call(n):
			out.append(n)
		_collect(n.get("children", []), pred, out)
	return out


## ---- 摆放（照原版 CSS） ----

func render(partial := false) -> void:
	if not partial:
		shown_selected = selected
	var nodes := build()
	tree = nodes
	if root != null:
		root.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 18
	center.offset_top = 18
	center.offset_right = -18
	center.offset_bottom = -18
	add_child(center)
	root = center
	var pane: Dictionary = nodes[0]
	var panel := PanelContainer.new()
	var frame := PaneFrame.new()
	frame.set_content_margin(SIDE_LEFT, PANE_BORDER + PANE_PAD.x)
	frame.set_content_margin(SIDE_RIGHT, PANE_BORDER + PANE_PAD.x)
	frame.set_content_margin(SIDE_TOP, PANE_BORDER + PANE_PAD.y)
	frame.set_content_margin(SIDE_BOTTOM, PANE_BORDER + PANE_PAD.y)
	panel.add_theme_stylebox_override("panel", frame)
	panel.custom_minimum_size = Vector2(minf(PANE_W, size.x - 36.0), 0)
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.follow_focus = true  # 键盘移到下方的配置项时跟着滚
	_scrollbar(scroll)
	panel.add_child(scroll)
	var box := _vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for n in pane.children:
		var c := _make(n)
		if c != null:
			# 标题区下距 12、资源条下距 15（其余段落 10＝行距）
			var extra: int = {"alien-heading": 2, "alien-summary": 5}.get(str(n.get("class", "")), 0)
			if extra > 0:
				var m := MarginContainer.new()
				m.add_theme_constant_override("margin_bottom", extra)
				m.add_child(c)
				c = m
			box.add_child(c)
	# 高度最多 94%（主题 max-height:94vh，超出滚动）
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	scroll.custom_minimum_size.y = minf(box.get_combined_minimum_size().y, size.y * 0.94 - (PANE_BORDER + PANE_PAD.y) * 2)
	var first := _first_button(box)
	if first != null:
		# 原版重画后不聚焦任何按钮，焦点框只在键盘操作后画（:focus-visible）。这里仍把焦点放在第一个按钮，方向键可直接走，
		# 但先不画框（hide_focus），键盘移动焦点后才显示
		first.grab_focus(true)
	# 原版重画后停在顶部（键盘焦点跟随只在之后移动时滚）
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = 0


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and not c.disabled and c.text != "返回":
			return c
		var r := _first_button(c)
		if r != null:
			return r
	return null


## 面板：底 #16161f（圆角 8、阴影 0 10 40 黑 0.65）＋ border-image：Window 皮肤 (96,0,96,96) 切 24 画进 12px 边，中间不画
class PaneFrame extends StyleBox:
	func _draw(ci: RID, rect: Rect2) -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = PANE
		bg.set_corner_radius_all(8)
		bg.shadow_color = Color(0, 0, 0, 0.65)
		bg.shadow_size = 20
		bg.shadow_offset = Vector2(0, 10)
		bg.draw(ci, rect)
		var skin := XUI.skin()
		if skin == null:
			return
		var s := 24.0
		var b := PANE_BORDER
		var xs := [[0.0, s, rect.position.x, b], [s, 48.0, rect.position.x + b, rect.size.x - b * 2], [72.0, s, rect.end.x - b, b]]
		var ys := [[0.0, s, rect.position.y, b], [s, 48.0, rect.position.y + b, rect.size.y - b * 2], [72.0, s, rect.end.y - b, b]]
		for xi in range(3):
			for yi in range(3):
				if xi == 1 and yi == 1:
					continue
				var x: Array = xs[xi]
				var y: Array = ys[yi]
				RenderingServer.canvas_item_add_texture_rect_region(ci, Rect2(x[2], y[2], x[3], y[3]), skin.get_rid(), Rect2(96 + x[0], y[0], x[1], y[1]))


## 滚动条 8 宽、白 0.35 圆角 4，轨道透明
static func _scrollbar(sc: ScrollContainer) -> void:
	var grab := XWebPanel._box(Color(1, 1, 1, 0.35), Color(0, 0, 0, 0), 4, 0, Vector2(4, 0))
	var bar := sc.get_v_scroll_bar()
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(k, grab)
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())


func _vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


## 段落：白字黑描边、行高＝字号×1.6；标题粗体（h1／h2 字距 1）
func _label(text: String, size_px := BODY_SIZE, color := TEXT, bold := false) -> Label:
	var l := XWebPanel._para(text, size_px, color, size_px * 1.6, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


## 按钮：XWebPanel 主题（内距 9/12、高 47.2）；gp-primary 青边浅青底、gp-danger 红字红边；选中项光标色；不可点整体 0.4
func _button(text: String, cls := "", disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	XWebPanel.style_button(b, Vector2(12, 9))
	b.custom_minimum_size.y = BUTTON_H
	var pad := Vector2(12, 9)
	if cls == "selected":
		b.add_theme_stylebox_override("normal", XWebPanel._box(XWebPanel.CURSOR, XWebPanel.CURSOR_EDGE, 6, 1, pad))
	elif RegEx.create_from_string(DANGER_RE).search(text) != null:
		b.add_theme_stylebox_override("normal", XWebPanel._box(XWebPanel.BUTTON_BG, BAD, 6, 1, pad))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			b.add_theme_color_override(k, BAD)
	elif RegEx.create_from_string(PRIMARY_RE).search(text) != null:
		b.add_theme_stylebox_override("normal", XWebPanel._box(PRIMARY, XWebPanel.CURSOR_EDGE, 6, 1, pad))
	if disabled:
		b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
		if not b.has_theme_color_override("font_disabled_color"):
			b.add_theme_color_override("font_disabled_color", TEXT)
		b.modulate.a = 0.4
	return b


## 盒子：底、边、圆角与内距（CSS 内距＋边框）
func _panel(bg: Color, edge: Color, radius: int, pad: Vector2, border := 1) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", XWebPanel._box(bg, edge, radius, border, pad))
	return pc


## 一串子节点：连着的按钮排成一行（行内块，button+button 左距 7），其余各占一行
func _stack(kids: Array, sep := 10) -> VBoxContainer:
	var v := _vbox(sep)
	var row: HBoxContainer = null
	for k in kids:
		var c := _make(k)
		if c == null:
			continue
		if c is Button and str(k.tag) == "button":
			if row == null:
				row = HBoxContainer.new()
				row.add_theme_constant_override("separation", 7)
				v.add_child(row)
			row.add_child(c)
			continue
		row = null
		v.add_child(c)
	return v


func _make(n: Dictionary) -> Control:
	if n.get("hidden", false):
		return null
	var cls := str(n.get("class", ""))
	match str(n.tag):
		"h1", "h2", "h3":
			var t := str(n.text)
			# h3 系统色；「战力 …」「装备战力 …」标题金色（gp-power）
			var col := XWebPanel.GOLD if RegEx.create_from_string("^(?:装备)?战力\\s").search(t) != null else (XWebPanel.SYSTEM if n.tag == "h3" else TEXT)
			return _label(t, SIZES[n.tag], col, true)
		"p", "span":
			if cls == "alien-error":
				var pc := _panel(ERROR_BACK, ERROR_BACK, 0, Vector2(10, 10), 0)
				pc.add_child(_label(str(n.text), BODY_SIZE, ERROR))
				return pc
			var col := TEXT
			match cls:
				"alien-note":
					col = NOTE
				"alien-benefit":
					col = GOOD
				"alien-cost":
					col = BAD
			return _label(str(n.text), BODY_SIZE, col)
		"legend":
			return _label(str(n.text))
		"label":
			var lv := _vbox(5)
			lv.add_child(_label(str(n.text)))
			for k in n.children:
				lv.add_child(_make(k))
			return lv
		"select":
			var ob := OptionButton.new()
			XWebPanel.style_button(ob, Vector2(12, 9))
			ob.add_theme_stylebox_override("normal", XWebPanel._box(XWebPanel.FIELD_BG, XWebPanel.BUTTON_EDGE, 6, 1, Vector2(12, 9)))
			ob.custom_minimum_size.y = BUTTON_H
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pick := -1
			for idx in n.options.size():
				ob.add_item(str(n.options[idx].label), idx)
				if n.value != null and str(n.options[idx].value) == str(n.value):
					pick = idx
			ob.select(pick)
			var opts: Array = n.options
			var key := str(n.key)
			ob.item_selected.connect(func(idx): set_value(key, opts[idx].value))
			return ob
		"button", "summary":
			var b := _button(str(n.text), cls, bool(n.get("disabled", false)))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT if n.tag == "summary" else HORIZONTAL_ALIGNMENT_CENTER
			if n.has("on"):
				b.pressed.connect(n.on)
			return b
	var kids: Array = n.children
	match cls:
		"alien-heading":
			# 标题区：下 1px 分隔线、下内距 10；按钮比标题高，标题竖直居中
			var pc := PanelContainer.new()
			var line := StyleBoxFlat.new()
			line.bg_color = Color(0, 0, 0, 0)
			line.border_color = XWebPanel.LINE
			line.border_width_bottom = 1
			line.content_margin_bottom = 11
			pc.add_theme_stylebox_override("panel", line)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 16)
			for k in kids:
				var c := _make(k)
				if c != null:
					c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					if c is Label:
						c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					h.add_child(c)
			pc.add_child(h)
			return pc
		"alien-summary":
			var pc := _panel(SUMMARY_BACK, SUMMARY_EDGE, 6, Vector2(14, 12))
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 16)
			for k in kids:
				var c := _make(k)
				if c != null:
					c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					if c is Label:
						c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						c.label_settings.font_color = XWebPanel.GOLD
					h.add_child(c)
			pc.add_child(h)
			return pc
		"alien-actions":
			# flex gap 8 ＋ button+button 左距 7
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 15)
			for k in kids:
				var c := _make(k)
				if c != null:
					h.add_child(c)
			return h
		"alien-body", "alien-choices":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 20 if cls == "alien-body" else 18)
			h.custom_minimum_size.y = 260
			for k in kids:
				var c := _make(k)
				if c == null:
					continue
				if str(k.get("class", "")) == "alien-list":
					c.custom_minimum_size.x = LIST_W
				else:
					c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(c)
			return h
		"alien-list":
			# 右 1px 分隔线、右内距 14；最多 430 高，超出竖向滚动（O-087：不照搬第 2 个起右推 7 与横向滚动条）
			var pc := PanelContainer.new()
			var line := StyleBoxFlat.new()
			line.bg_color = Color(0, 0, 0, 0)
			line.border_color = XWebPanel.LINE
			line.border_width_right = 1
			line.content_margin_right = 15
			pc.add_theme_stylebox_override("panel", line)
			var sc := ScrollContainer.new()
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if list_indent_quirk else ScrollContainer.SCROLL_MODE_DISABLED
			sc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			sc.custom_minimum_size.y = minf(430.0, (BUTTON_H + 8) * kids.size())
			_scrollbar(sc)
			var v := _vbox(8)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for k in kids:
				var c := _make(k)
				if c is Button:
					c.alignment = HORIZONTAL_ALIGNMENT_LEFT
					if list_indent_quirk and v.get_child_count() > 0:
						c.custom_minimum_size.x = LIST_W - 15
						var m := MarginContainer.new()
						m.add_theme_constant_override("margin_left", 7)
						m.add_child(c)
						c = m
				if c != null:
					v.add_child(c)
			sc.add_child(v)
			pc.add_child(sc)
			return pc
	var v := _stack(kids.filter(func(k): return not (n.tag == "details" and k.tag != "summary" and not recent_open)))
	if n.tag == "fieldset":
		var fc := _panel(Color(0, 0, 0, 0), FIELDSET_EDGE, 0, Vector2(10, 10))
		fc.add_child(v)
		return fc
	if n.tag == "section":
		var pc: PanelContainer
		match cls:
			"alien-confirm":
				pc = _panel(CONFIRM_BACK, BAD, 6, Vector2(15, 15))
			"alien-config":
				pc = _panel(SECTION_BACK, XWebPanel.LINE, 6, Vector2.ZERO)
			_:
				pc = _panel(SECTION_BACK, XWebPanel.LINE, 6, Vector2(18, 18))
		pc.add_child(v)
		return pc
	return v
