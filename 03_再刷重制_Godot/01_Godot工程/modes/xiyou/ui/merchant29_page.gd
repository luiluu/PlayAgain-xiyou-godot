class_name XMerchant29Page
extends Control
## 【cc·八戒·未经审查】深渊／不朽商人界面（installAbyssMerchantRuntime 的 Scene_Merchant29 merchant 模式；XAbyssMerchant.open_current 打开）。
## 页面与文字照原版：
## - 首页：标题「深渊商人　路线名」「战利品点 N　剩余抽取 n 次」；查看本副本完整装备池、抽取武器／防具／饰品（该分组池空时不能选）、离开。
## - 装备池：标题「路线名　完整装备池（n件）」「先选分组时，该分组内每件基础装备等概率。」；每行「名字　分组」，取消回首页。
## - 抽取：标题「分组抽奖　路线名」「同一分组内基础装备等概率，必出本档指定类别1条。」；三行「30点　必出1条Mod特效」等（点数够且次数没用完才能选），
##   抽到提示「获得 名字（类别）」并刷新本页；出错提示原版的错误文字。取消回首页。
## 期一（DG）只做到这里：用 XYunChoicesWindow 单列加标题行，原版左列表＋右侧装备详情的两栏布局、详情翻页、专武·特效吸取（openAbsorb）、
## 路线预览（openPreview）还没移植，见交付单 cc_bajie-newsrc4.md。
signal closed

var win: XYunChoicesWindow
var _ok: Callable
var _cancel: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	home()


func choose(rows: Array, ok: Callable, cancel: Callable, info := []) -> void:
	if win and is_instance_valid(win):
		win.queue_free()
	win = XYunChoicesWindow.for_rows(self, rows, info)
	_ok = ok
	_cancel = cancel
	var w := win
	w.chosen.connect(func(i): if w == win: _ok.call(w.entries[i]))
	w.cancelled.connect(func(): if w == win: _cancel.call())


static func _run_of() -> Dictionary:
	var r = XAbyssMerchant.run(XState.current)
	return r if r != null else {}


static func home_info(s: XState) -> Array:
	var cur := _run_of()
	var who: Dictionary = cur.get("identity", {})
	var c := XAbyssMerchant.config()
	return ["%s　%s" % [str(who.get("kind", "")), str(XAbyssMerchant.route(int(s.map_id)).get("name", ""))],
		"战利品点 %d　剩余抽取 %d 次" % [XAbyssMerchant.balance(s, str(who.get("key", ""))), int(c.get("visitLimit", 0)) - int(cur.get("used", 0))]]


static func home_rows(s: XState) -> Array:
	return [{"text": "查看本副本完整装备池", "go": "pool"},
		{"text": "抽取武器", "go": "武器", "enabled": not XAbyssMerchant.pool(s, "武器").is_empty()},
		{"text": "抽取防具", "go": "防具", "enabled": not XAbyssMerchant.pool(s, "防具").is_empty()},
		{"text": "抽取饰品", "go": "饰品", "enabled": not XAbyssMerchant.pool(s, "饰品").is_empty()},
		{"text": "离开", "go": "leave"}]


func home() -> void:
	var s := XState.current
	choose(home_rows(s), _home_pick, _close, home_info(s))


func _home_pick(r: Dictionary) -> void:
	var go := str(r.go)
	if go == "pool":
		preview()
	elif go == "leave":
		_close()
	else:
		tiers(go)


static func pool_rows(map_id: int) -> Array:
	return (XAbyssMerchant.route(map_id).get("pool", []) as Array).map(func(d):
		return {"text": "%s　%s" % [str(XAbyssMerchant.item(d).get("name", "")), XAbyssMerchant.group(d)]})


func preview() -> void:
	var s := XState.current
	var r := XAbyssMerchant.route(int(s.map_id))
	choose(pool_rows(int(s.map_id)), func(_r): pass, home,
		["%s　完整装备池（%d件）" % [str(r.get("name", "")), (r.get("pool", []) as Array).size()], "先选分组时，该分组内每件基础装备等概率。"])


static func tier_rows(s: XState) -> Array:
	var cur := _run_of()
	var c := XAbyssMerchant.config()
	var key := str(cur.get("identity", {}).get("key", ""))
	var rows := []
	for tier in XAbyssMerchant.LABELS.size():
		var cost := int(c.costs[tier])
		rows.append({"text": "%d点　必出1条%s" % [cost, XAbyssMerchant.LABELS[tier]], "tier": tier,
			"enabled": XAbyssMerchant.balance(s, key) >= cost and int(cur.get("used", 0)) < int(c.get("visitLimit", 0))})
	return rows


func tiers(g: String) -> void:
	var s := XState.current
	choose(tier_rows(s), func(r):
		var got = XAbyssMerchant.draw(s, int(r.tier), g)
		if got is String:
			XToast.show_text(got, true)
		else:
			XToast.show_text("获得 %s（%s）" % [str(got.name), XAbyssMerchant.LABELS[int(r.tier)]], true)
		tiers(g), home,
		["%s抽奖　%s" % [g, str(XAbyssMerchant.route(int(s.map_id)).get("name", ""))], "同一分组内基础装备等概率，必出本档指定类别1条。"])


func _close() -> void:
	closed.emit()
