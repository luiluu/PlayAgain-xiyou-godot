class_name XItemRow
extends RefCounted
## Window_ItemList.drawItem 的一行（物品页列表、升级材料列表共用；运行时绘制记录见 界面风格.md）：
## 行矩形宽减文字边距 6；图标 (2, y+2)，名字从 x 36 起、宽 = 行宽 − 「×0,000」宽 − 36，品质色（ItemQuality）；
## 未看过的物品在图标上叠 newIcon（Galv_NewItemIndication）；右侧字号 20 右对齐：物品「×数量」，
## 独立装备「背包序号/9,999」（YEP Carry Format「%1/%2」，序号 = 在背包同类装备里的位置），在队员身上时写队员名字。

const LH := 36.0
const QTY_FONT := 20
const CARRY_MAX := 9999


static func number_width(c: XMVCanvas) -> float:
	return c.text_width("×0,000", XUI.FONT_SIZE)


static func paint(c: XMVCanvas, rec: Dictionary, y: float, right_text: String, alpha := 1.0, is_new := false) -> void:
	var w := c.size.x - 6.0
	c.icon(int(rec.get("iconIndex", 0)), 2, y + 2, alpha)
	c.text(XQuality.list_name(rec), 36, y, w - number_width(c) - 36, "left", XGear.color(rec), XUI.FONT_SIZE, LH, alpha)
	if is_new:
		var tex := new_icon()
		if tex:
			c.draw_texture(tex, Vector2(2, y + 2), Color(1, 1, 1, alpha))
	if right_text != "":
		c.text(right_text, 0, y, w, "right", XUI.TEXT, QTY_FONT, LH, alpha)


static var _new_icon: Texture2D

static func new_icon() -> Texture2D:
	if _new_icon == null:
		var p := XDB.img_path("system", "newIcon")
		if p != "":
			_new_icon = load(p)
	return _new_icon


## 右侧文字：物品「×数量」；装备在背包里写「序号/9,999」，在队员身上写队员名字
static func right_text(entry: Dictionary) -> String:
	if entry.get("owner") != null:
		return (entry.owner as XActor).display_name()
	if entry.rec.has("instanceId"):
		return "%s/%s" % [XMenu._group(int(entry.get("carry", 0))), XMenu._group(CARRY_MAX)]
	return "×" + XMenu._group(int(entry.get("count", 0)))
