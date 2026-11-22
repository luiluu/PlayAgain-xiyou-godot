class_name XSkinAlienWorkshop
extends RefCounted
## 【cc·天启篇·未经审查】T367（T254 R8、卡 F）异化工坊套模板页：XAlienWorkshop 新界面在 T361（LAYOUT_V2）之上再补的几件，
## 开关 XAlienWorkshop.LAYOUT_V3（关＝回到 T361 的排法；新皮肤关、西游存档照旧走原版排法）。节点树（build／flatten／click）一行不改。
## - 页名白字（TEXT_HI，同别的模板页），不再旧金；
## - 会毁东西的操作走统一确认弹窗 XSkinConfirm（橙边、光标默认停在「取消」）：分解、取核（原来详情里嵌的确认框改成弹窗，
##   确认状态 confirming／confirming_core 照旧）、重抽（用掉异化石）、净化（词条找不回来）、刻到已有词条的装备上（旧词条被替换）；
## - 空列表：列表区正中一句 TEXT_3 的人话（19 号），右牌照旧放「如何获得」说明（旧页这几句玩家要看，不丢）；
## - 「异化核」「装备重铸」两页：原来的网页下拉框（刻到哪件／重铸哪件）换成左边一列可点的装备，右边牌子放这一节的其余内容；
##   没有可选装备时整页一句空状态。本页只用通用件（XSkinConfirm、XSkinButton、XUiSkin），不改它们。

const EMPTY_FS := 19
const LIST_W := 360.0


## 按钮要不要先弹确认（重抽、净化、刻到有词条的装备）；返回 XSkinConfirm.setup 的字典，空＝不用确认
static func ask_spec(text: String, item_name: String, engrave_replaces := false, target_name := "") -> Dictionary:
	if text.begins_with("使用1颗异化石重抽"):
		return {"title": "用 1 颗异化石重抽？", "body": "%s：异化石马上用掉、不退；抽完在旧词条和新词条里挑一条。" % item_name,
			"buttons": ["重抽", "取消"], "danger": true}
	if text.begins_with("使用1颗异化石净化"):
		return {"title": "净化 %s？" % item_name, "body": "异化词条会被移除、找不回来，退还一部分异化能量；会用掉 1 颗异化石，装备保留。",
			"buttons": ["净化", "取消"], "danger": true}
	if text.begins_with("刻上") and engrave_replaces:
		return {"title": "刻到 %s 上？" % target_name, "body": "这件已有的异化词条会被换掉、找不回来；会用掉 1 颗异化石。",
			"buttons": ["刻上", "取消"], "danger": true}
	return {}


## 详情里的确认框节点（alien-confirm：h3「确认分解 X」、p 后果、确认钮、取消钮）→ 弹窗字典；确认钮的回调另取
static func section_dialog(sec: Dictionary) -> Dictionary:
	var title := ""
	var body := ""
	var yes := ""
	for k in sec.get("children", []):
		match str(k.get("tag", "")):
			"h3":
				title = str(k.get("text", ""))
			"p":
				body = str(k.get("text", ""))
			"button":
				if yes == "" and str(k.get("text", "")) != "取消":
					yes = str(k.get("text", ""))
	if title.begins_with("确认"):
		title = title.substr(2) + "？"
	return {"title": title, "body": body, "buttons": [yes.trim_prefix("确认"), "取消"], "danger": true}


## 确认框节点里「确认…」那枚的回调
static func section_yes(sec: Dictionary) -> Callable:
	for k in sec.get("children", []):
		if str(k.get("tag", "")) == "button" and str(k.get("text", "")) != "取消" and k.has("on"):
			return k.on
	return Callable()


## 空状态：一句人话，19 号 TEXT_3，在给定区域里水平垂直居中
static func empty_label(text: String) -> Label:
	var l := Label.new()
	l.name = "SkinEmpty"
	l.text = text
	var ls := LabelSettings.new()
	ls.font = XUiSkin.font("body")
	ls.font_size = XUiSkin.fs(EMPTY_FS)
	ls.font_color = XUiSkin.TEXT_3
	ls.outline_size = XUiSkin.outline_size()
	ls.outline_color = XUiSkin.outline_color()
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 一节里的下拉框（label＋select）：返回 [label 节点, select 节点]，没有＝[]
static func find_select(sec: Dictionary) -> Array:
	for k in sec.get("children", []):
		if str(k.get("tag", "")) == "label":
			for c in k.get("children", []):
				if str(c.get("tag", "")) == "select":
					return [k, c]
	return []


## 左列表小标题（旧金 17 号，同模板页 list_title）
static func list_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = XUiSkin.font("body")
	ls.font_size = XUiSkin.fs(XUiSkin.FS_AUX_MAX)
	ls.font_color = XUiSkin.GOLD
	ls.outline_size = XUiSkin.outline_size()
	ls.outline_color = XUiSkin.outline_color()
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 下拉框的选项换成一列按钮：当前值画红乙选中条，点一下＝pick.call(value)；名字超宽省略号
static func option_buttons(sel: Dictionary, pick: Callable) -> Array:
	var out := []
	for o in sel.get("options", []):
		var b := Button.new()
		b.text = str(o.label)
		XSkinButton.apply(b, "", XUiSkin.FS_AUX_MAX)
		b.custom_minimum_size.y = 40
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if sel.get("value") != null and str(o.value) == str(sel.value):
			b.add_theme_stylebox_override("normal", XSkinButton.select())
			b.set_meta("current", true)
		var v = o.value
		b.pressed.connect(func(): pick.call(v))
		out.append(b)
	return out
