## 【T164·D186】光耀度：属于每一颗宝石（符文镶嵌、宝珠、符文之语），不属于装备。
## 【D190b】同一颗宝石镶在越高级的装备上越光耀：光耀度＝该宝石所加那一列的换算比 ÷ 80 级换算比，80 级＝100%、最高 100%（超 80 级按 80 算，见 XTianqiGear.CAP_80）；
## 宝石那一行写自己的光耀度和实际加成（实际值＝基础值×换算比＝光耀 100% 的值×光耀度），图鉴数字是光耀 100% 时的效果。只做显示：不新增数值、不改任何战斗结果（那 5 件超 80 级特例除外，见交付单）。
## 只认期四总开关 XTianqiBase.PHASE4 且这件装备读表（XTianqiGear.applies）；否则每个函数都返回空，界面逐字节回原样。
const NAME := "光耀"
const NOTE := "数字为光耀100%；装备越高级越光耀"
const PREVIEW_HEAD := "这颗宝石镶在这件装备上："
const LINE_COLOR := "#cfe8ff"


static func active(item) -> bool:
	return XTianqiBase.PHASE4 and item is Dictionary and not item.is_empty() and XTianqiGear.gem_applies(item)


static func _names() -> Array:
	return XDB.system().get("terms", {}).get("params", ["生命", "魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"])


## 这一项的光耀度（0～1）：换算比÷80 级换算比；CAP_80 关着时就是换算比本身（旧口径）
static func power_of(item, i: int) -> float:
	return XTianqiGear.flat_ratio(item, i) / XTianqiGear.full_ratio(i)


## 一项在光耀 100% 时的值：基础值×80 级换算比
static func full_value(v: float, i: int) -> float:
	return v * XTianqiGear.full_ratio(i)


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


## 一颗宝石（基础值八项 base）在这件装备上的行。每列各有自己的光耀度（列不同换算比不同），所以一列一行、不写范围：
## 只加一列 → 一行「红宝石 光耀87%　物理攻击 +11」（name 空就不写名字）；加多列 → 先一行名字，再每列一行「光耀87%　物理攻击 +11」。没有加成返回空
static func gem_lines(item: Dictionary, base: Array, name := "") -> Array:
	var names := _names()
	var cols := touched(base)
	var out := []
	for i in cols:
		out.append("%s%s　%s %s" % [NAME, _pct(power_of(item, i)), str(names[i]), _num(float(base[i]) * XTianqiGear.flat_ratio(item, i))])
	if out.is_empty() or name == "":
		return out
	if cols.size() == 1:
		return [name + " " + str(out[0])]
	return [name] + out


## 这件装备上每颗宝石一项 {name, base}：宝珠孔（有加成的）、符文镶嵌记录、符文之语。随机镶嵌项不算。规则同 XTianqiGear.gem_base（秘宝／读不到模板的只认宝珠）
static func gems(item: Dictionary) -> Array:
	var out := []
	if not active(item):
		return out
	var src: Dictionary = item
	if item.has(XAffixAbsorb.VIEW_FLAG):
		var raw = XAffixAbsorb.real(item)
		if raw is Dictionary and not is_same(raw, item):
			src = raw
	var slots: Array = src.get("augmentSlots", [])
	for n in slots.size():
		var gem := XOrbs.gem_in_slot(src, n)
		if not gem.is_empty():
			out.append({"name": str(gem.get("name", "")), "base": XTianqiGear.orb_slot_fixed(src, n)})
	if XTianqiGear._qiyin_mult(src) != 0.0 or XGear.template(XTianqiGear._kind(src), int(src.get("base", src.get("id", 0)))).is_empty():
		return out
	var history: Array = src.get("upgrades", [])
	for n in history.size():
		var stub: Dictionary = src.duplicate()
		stub["upgrades"] = [history[n]]
		var mat := XDB.rec("Items", int(history[n].get("item", 0)) if history[n] is Dictionary else 0)
		out.append({"name": str(history[n].get("name", mat.get("name", ""))) if history[n] is Dictionary else str(mat.get("name", "")), "base": XTianqiGear.upgrade_fixed(stub, src.get("params", [0, 0, 0, 0, 0, 0, 0, 0])).fixed})
	var rw := XTianqiGear.runeword_params(src)
	if rw.size() >= 8:
		out.append({"name": "符文之语", "base": rw})
	return out


## 装备详情页（说明卡）末尾追加的行：每颗宝石一段。关着、没有宝石返回空数组
static func detail_rows(item: Dictionary) -> Array:
	var rows := []
	for g in gems(item):
		for l in gem_lines(item, g.base, g.name):
			rows.append(["　" + str(l) if str(l).begins_with(NAME) else str(l), int(XHelpCard.P43_SIZE.body), LINE_COLOR, false, 0])
	if rows.is_empty():
		return rows
	return [[" ", int(XHelpCard.P43_SIZE.gap), "#000000", false, 0]] + rows


## 「插槽与镶嵌」页：第 n 个宝珠孔下面的逐项行
static func orb_slot_lines(item: Dictionary, slot: int, size: int) -> Array:
	if not active(item):
		return []
	return _as_rows(gem_lines(item, XTianqiGear.orb_slot_fixed(item, slot)), size)


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
	return _as_rows(gem_lines(item, up.fixed), size)


static func _as_rows(lines: Array, size: int) -> Array:
	return lines.map(func(l): return ["　　" + str(l), size, LINE_COLOR, false, 0])


## 镶嵌时的预览：这颗材料（mode "upgrade"）或宝珠（"augment"，slot 是孔）镶在这件装备上的光耀度和实际加成。没有可显示的返回空。
## 第一行是标题「这颗宝石镶在这件装备上：」，其后是 gem_lines（按待镶这颗自己加成的列算，不读已镶的宝石）
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
		base = XTianqiGear.orb_lines_fixed(XOrbs.parse(rec).attach.get(type, []))
	var out := gem_lines(gear, base)
	if out.is_empty():
		return []
	return [PREVIEW_HEAD] + out


## 说明卡（旧界面）追加的行
static func preview_rows(gear: Dictionary, rec: Dictionary, mode: String, slot := -1) -> Array:
	var lines := preview_lines(gear, rec, mode, slot)
	var size := int(XHelpCard.P43_SIZE.body)
	var rows := []
	for k in lines.size():
		rows.append([str(lines[k]) if k == 0 else "　" + str(lines[k]), size, LINE_COLOR, false, 0])
	return rows


## 新界面详情牌追加一节
static func dress_card(gear: Dictionary, rec: Dictionary, mode: String, slot: int, d: Dictionary) -> void:
	var lines := preview_lines(gear, rec, mode, slot)
	if lines.is_empty():
		return
	var rows := []
	for l in lines.slice(1):   # 小节标题已是「镶在这件装备上」，不再重复标题行
		rows.append({"text": str(l), "color": XUiSkin.TEXT})
	d.sections.append({"title": "镶在这件装备上", "rows": rows})
