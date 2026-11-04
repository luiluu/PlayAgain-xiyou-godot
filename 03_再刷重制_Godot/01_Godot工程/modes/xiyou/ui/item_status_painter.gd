class_name XItemStatusPainter
extends RefCounted
## YEP_ItemCore Window_ItemStatus / YEP_ShopMenuCore Window_ShopInfo 的画法（两者相同）：
## 左边 144×144 暗格里放 128 大图标（最近邻放大），右边 4 行×2 列暗格（宽 (内容宽-144)/2、行高 36、字号 20）。
## 物品：「最大生命值 回复 / HP 回复 / 最大魔法值 回复 / MP 回复 / 获得状态 / 移除状态 / 获得增益 / 移除增益」，
##       无值画半透明「---」，百分比项 ×100 加「%」，状态/增益画图标。
## 装备：8 项能力（系统用语），数值「+N」按增减着色，「+0」半透明。
## 参照截图：04_验证/本地结果/原版参照/21～25。

const FACE := 144.0
const ICON_SIZE := 128.0
const LH := 36.0
const FONT := 20
const ICON_BUFF_START := 32
const ICON_DEBUFF_START := 48


static func param_name(i: int) -> String:
	var names: Array = XDB.system().get("terms", {}).get("params", [])
	return str(names[i]) if i < names.size() else ""


static func paint(c: XMVCanvas, item: Dictionary) -> void:
	var col_w := (c.size.x - FACE) / 2.0
	_dark(c, Rect2(0, 0, FACE, FACE))
	for i in range(8):
		_dark(c, _cell(i, col_w))
	if item.is_empty():
		return
	var tex := large_icon(int(item.get("iconIndex", 0)))
	if tex:
		c.draw_texture(tex, Vector2((FACE - ICON_SIZE) / 2.0, (FACE - ICON_SIZE) / 2.0))
	if item.has("itypeId"):
		_item_info(c, item, col_w)
	else:
		_equip_info(c, item, col_w)


static var _large := {}

## 128 大图标：原版关闭平滑（imageSmoothingEnabled = false），这里预先最近邻放大并缓存
static func large_icon(index: int) -> Texture2D:
	if index <= 0:
		return null
	if not _large.has(index) and not XXuanTusuArt.icon_slot(index).is_empty():  # 璇、屠苏 HD 图标
		_large[index] = XXuanTusuArt.icon_texture(index, int(ICON_SIZE))
	if not _large.has(index) and XYunshang.icon_slot(index) >= 0:  # 云裳 HD 图标：128 的图平滑缩放（原版画 Q.bitmap 那张）
		_large[index] = XYunshang.icon_texture(index, int(ICON_SIZE))
	if not _large.has(index) and index == XDemonCrown.ICON:  # 魔冠大图：同样平滑缩放
		_large[index] = XDemonCrown.icon_texture(int(ICON_SIZE))
	if not _large.has(index):
		var t := XUI.icon_texture(index)
		if t == null:
			return null
		var img := t.atlas.get_image().get_region(Rect2i(t.region))
		img.resize(int(ICON_SIZE), int(ICON_SIZE), Image.INTERPOLATE_NEAREST)
		_large[index] = ImageTexture.create_from_image(img)
	return _large[index]


static func _cell(i: int, col_w: float) -> Rect2:
	return Rect2(FACE + (i % 2) * col_w, floori(i / 2.0) * LH, col_w, LH)


## drawDarkRect：底色 19、半透明，四边各内缩 1px
static func _dark(c: XMVCanvas, r: Rect2) -> void:
	c.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Color(XUI.GAUGE_BACK, 160.0 / 255.0))


static func _equip_info(c: XMVCanvas, item: Dictionary, col_w: float) -> void:
	var params: Array = item.get("params", [0, 0, 0, 0, 0, 0, 0, 0])
	for i in range(8):
		var r := _cell(i, col_w)
		var dx := r.position.x + 6
		var dw := r.size.x - 12
		c.text(param_name(i), dx, r.position.y, dw, "left", XUI.SYSTEM, FONT, LH)
		var v := int(params[i])
		var s := ("+" if v >= 0 else "") + XMenu._group(v)
		c.text(s, dx, r.position.y, dw, "right", change_color(v), FONT, LH, XUI.DIM.a if s == "+0" else 1.0)


## Window_Base.paramchangeTextColor
static func change_color(v: float) -> Color:
	if v > 0:
		return XUI.POWER_UP
	if v < 0:
		return XUI.POWER_DOWN
	return XUI.TEXT


static func _item_info(c: XMVCanvas, item: Dictionary, col_w: float) -> void:
	var fmt := "%s 回复"
	var terms: Dictionary = XDB.system().get("terms", {})
	var basic: Array = terms.get("basic", [])
	var hp := str(basic[2]) if basic.size() > 2 else "HP"
	var mp := str(basic[4]) if basic.size() > 4 else "MP"
	var labels := [fmt % param_name(0), fmt % hp, fmt % param_name(1), fmt % mp, "获得状态", "移除状态", "获得增益", "移除增益"]
	for i in range(8):
		var r := _cell(i, col_w)
		var dx := r.position.x + 6
		var dw := r.size.x - 12
		c.text(labels[i], dx, r.position.y, dw, "left", XUI.SYSTEM, FONT, LH)
		if i >= 4:
			var icons := _icons(item, i)
			if not icons.is_empty():
				var x := dx + dw - icons.size() * 32 + 6 - 2
				for ic in icons:
					c.icon(ic, x, r.position.y + 2)
					x += 32
				continue
			c.text("---", dx, r.position.y, dw, "right", XUI.TEXT, FONT, LH, XUI.DIM.a)
			continue
		var eff := _effect(item, 11 if i < 2 else 12)
		var value = null
		if not eff.is_empty():
			value = float(eff.value1) * 100.0 if i % 2 == 0 else float(eff.value2)
		if value == null or is_zero_approx(value):
			c.text("---", dx, r.position.y, dw, "right", XUI.TEXT, FONT, LH, XUI.DIM.a)
		else:
			var s := ("+" if value > 0 else "") + XMenu._group(int(value)) + ("%" if i % 2 == 0 else "")
			c.text(s, dx, r.position.y, dw, "right", XUI.TEXT, FONT, LH)


## YEP getEffect：同一代码取最后一个
static func _effect(item: Dictionary, code: int) -> Dictionary:
	var out := {}
	for e in item.get("effects", []):
		if int(e.code) == code:
			out = e
	return out


static func _icons(item: Dictionary, i: int) -> Array:
	var out := []
	for e in item.get("effects", []):
		var code := int(e.code)
		if (i == 4 and code == 21) or (i == 5 and code == 22):
			var st := XDB.rec("States", int(e.dataId))
			if int(st.get("iconIndex", 0)) != 0:
				out.append(int(st.iconIndex))
		elif i == 6 and code == 31:
			out.append(ICON_BUFF_START + int(e.dataId))
		elif i == 6 and code == 32:
			out.append(ICON_DEBUFF_START + int(e.dataId))
		elif i == 7 and (code == 33 or code == 34):
			out.append((ICON_BUFF_START if code == 33 else ICON_DEBUFF_START) + int(e.dataId))
	return out
