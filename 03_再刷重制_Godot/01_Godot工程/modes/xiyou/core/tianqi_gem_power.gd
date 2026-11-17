class_name XTianqiGemPower
extends RefCounted
## 【T164·D186】光耀度：宝石（符文镶嵌、宝珠）的实际效果＝图鉴里的基础值×装备的「光耀度」，装备等级越高越光耀。
## 光耀度就是期四装备八项里已经在用的换算比（XTianqiGear.flat_ratio），这里只做显示：不新增数值、不改任何战斗结果。
## 只认期四总开关 XTianqiBase.PHASE4 且这件装备读表（XTianqiGear.applies）；否则每个函数都返回空，界面逐字节回原样。
const NAME := "光耀度"
const NOTE := "基础值×光耀度，等级越高越盛；特效不放大"
const COLOR := "#ffe499"
const LINE_COLOR := "#cfe8ff"
## 八项 → 说明里的短名（生命、魔法、物攻、物防、魔攻、魔防、敏捷、幸运），同装备说明卡「属性:」用的术语
const EMPTY_COLS := [0, 2, 3, 6, 7]   # 没有宝石时看五列（生命、物攻、物防、敏捷、幸运），不单取物攻列，免得镶上宝石后头行跳变


static func active(item) -> bool:
	return XTianqiBase.PHASE4 and item is Dictionary and not item.is_empty() and XTianqiGear.applies(item)


static func _names() -> Array:
	return XDB.system().get("terms", {}).get("params", ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"])


static func _pct(r: float) -> String:
	return "%d%%" % roundi(r * 100.0)


static func _num(v: float) -> String:
	return "%+d" % roundi(v)


## 基础值八项里有宝石加成的那几项的下标
static func touched(base: Array) -> Array:
	var out := []
	for i in 8:
		if absf(float(base[i])) > 0.0:
			out.append(i)
	return out


## 光耀度文字：各列换算比不同时给范围（生命、物攻、物防、敏捷、幸运各一列）。只看宝石真正加成的那几项（base 不给就看这件已镶的宝石）；
## 没有宝石看五列
static func power_text(item: Dictionary, base = null) -> String:
	if not active(item):
		return ""
	var idx := touched(base if base is Array else XTianqiGear.gem_base(item))
	if idx.is_empty():
		idx = EMPTY_COLS
	var lo := INF
	var hi := -INF
	for i in idx:
		var r := XTianqiGear.flat_ratio(item, i)
		lo = minf(lo, r)
		hi = maxf(hi, r)
	return _pct(lo) if roundi(lo * 100.0) == roundi(hi * 100.0) else "%s～%s" % [_pct(lo), _pct(hi)]


## 头行：「光耀度：566%」，范围时加「（各项不同）」
static func head_text(item: Dictionary, base = null) -> String:
	var t := power_text(item, base)
	return "%s：%s%s" % [NAME, t, "（各项不同）" if t.contains("～") else ""]


## 一组基础值 → 「物理攻击 +84（+20）」逐项（实际值（基础值））
static func value_lines(item: Dictionary, base: Array) -> Array:
	var names := _names()
	var out := []
	for i in touched(base):
		var r := XTianqiGear.flat_ratio(item, i)
		out.append("%s %s（%s）" % [str(names[i]), _num(float(base[i]) * r), _num(float(base[i]))])
	return out


## 装备详情页（说明卡）末尾追加的行：光耀度＋宝石那几项逐行。关着返回空数组
static func detail_rows(item: Dictionary) -> Array:
	if not active(item):
		return []
	var size := int(XHelpCard.P43_SIZE.body)
	var rows := [[" ", int(XHelpCard.P43_SIZE.gap), "#000000", false, 0],
		[head_text(item), size, COLOR, false, 0]]
	for l in value_lines(item, XTianqiGear.gem_base(item)):
		rows.append(["　" + l, size, LINE_COLOR, false, 0])
	return rows


## 「插槽与镶嵌」页：最前面一行光耀度。关着空
static func socket_head(item: Dictionary, size: int) -> Array:
	if not active(item):
		return []
	return [[head_text(item), size, COLOR, false, 0]]


## 「插槽与镶嵌」页：第 n 个宝珠孔下面的逐项行
static func orb_slot_lines(item: Dictionary, slot: int, size: int) -> Array:
	if not active(item):
		return []
	return _as_rows(value_lines(item, XTianqiGear.orb_slot_fixed(item, slot)), size)


## 「插槽与镶嵌」页：第 n 条符文镶嵌记录下面的逐项行（随机项不算）
static func upgrade_lines(item: Dictionary, n: int, size: int) -> Array:
	if not active(item):
		return []
	var history: Array = item.get("upgrades", [])
	if n < 0 or n >= history.size():
		return []
	var stub: Dictionary = item.duplicate()
	stub["upgrades"] = [history[n]]
	var up := XTianqiGear.upgrade_fixed(stub, item.get("params", [0, 0, 0, 0, 0, 0, 0, 0]))
	return _as_rows(value_lines(item, up.fixed), size)


static func _as_rows(lines: Array, size: int) -> Array:
	return lines.map(func(l): return ["　　" + str(l), size, LINE_COLOR, false, 0])


## 镶嵌时的预览：这件装备镶上材料（mode "upgrade"）或宝珠（"augment"，slot 是孔）后的逐项实际值（基础值）。没有可显示的返回空
static func preview_lines(gear: Dictionary, rec: Dictionary, mode: String, slot := -1) -> Array:
	if not active(gear) or rec.is_empty():
		return []
	var base := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if mode == "upgrade":
		if XGearUpgrade.rule(rec).is_empty():
			return []
		var stub: Dictionary = gear.duplicate()
		stub["upgrades"] = [{"item": int(rec.get("id", 0))}]
		base = XTianqiGear.upgrade_fixed(stub, gear.get("params", base)).fixed
	elif mode == "augment":
		var slots: Array = gear.get("augmentSlots", [])
		var type := str(slots[slot] if slot >= 0 and slot < slots.size() else "").to_upper().strip_edges()
		if type == "":
			return []
		var orb_res := XTianqiGear.orb_lines_fixed(XOrbs.parse(rec).attach.get(type, []))
		base = orb_res
	var out := value_lines(gear, base)
	if out.is_empty():
		return []
	var pt := power_text(gear, base)   # 按正在预览的这件材料／宝珠自己加成的列算，不读已镶的宝石
	return ["%s：%s（%s）" % [NAME, pt, "本件，各项不同" if pt.contains("～") else "本件"]] + out


## 说明卡（旧界面）追加的行
static func preview_rows(gear: Dictionary, rec: Dictionary, mode: String, slot := -1) -> Array:
	var lines := preview_lines(gear, rec, mode, slot)
	var size := int(XHelpCard.P43_SIZE.body)
	var rows := []
	for k in lines.size():
		rows.append([str(lines[k]) if k == 0 else "　" + str(lines[k]), size, COLOR if k == 0 else LINE_COLOR, false, 0])
	return rows


## 新界面详情牌追加一节
static func dress_card(gear: Dictionary, rec: Dictionary, mode: String, slot: int, d: Dictionary) -> void:
	var lines := preview_lines(gear, rec, mode, slot)
	if lines.is_empty():
		return
	var rows := []
	for l in lines:
		rows.append({"text": str(l), "color": XUiSkin.TEXT})
	d.sections.append({"title": "镶在这件装备上", "rows": rows})
