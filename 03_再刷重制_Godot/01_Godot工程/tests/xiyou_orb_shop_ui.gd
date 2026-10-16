extends Node
## 宝珠坊界面（XOrbShop＋XChoiceWindow）：按正式 orb_shop_probe.cjs 记录的 7 条点选路线（行文点选）逐页比对说明与选项、
## 提示、结束时的背包与随机流序号；窗口几何与 ui_reference 读数（tests/fixtures/orb_shop_ui_oracle.json）比对；
## 主菜单「宝珠坊」可选并能打开。窗口模式加 -- --out=<目录> 存对照截图。

var results := []
var out_dir := ""
const ORACLE := "res://modes/xiyou/generated/oracle/orb_shop.json"
const FIXTURE := "res://tests/fixtures/orb_shop_ui_oracle.json"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(2000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


func shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


static func norm(v):
	if v is int or v is float:
		return float(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = norm(v[k])
		return out
	return v


func _state(seed: int, v20: int, items: Dictionary, returns := {}, inbox := {}) -> XState:
	var s := XState.new_game_blank()
	s.items = {}
	s.orb_seed = seed
	s.orb_state = {"n": {}, "returns": returns.duplicate(), "inbox": inbox.duplicate(), "recent": []}
	s.set_variable(20, v20)
	for id in items:
		s.gain_item(int(id), int(items[id]))
	return s


func _pick(shop: XOrbShop, label: String) -> bool:
	var i := shop.choice.rows.find_custom(func(r): return str(r.label) == label)
	if i < 0:
		return false
	shop.choice.index = i
	shop.choice.ok()
	return true


const FLOWS := {
	"home-empty": [11, 1, {}, {}, {}],
	"identify": [11, 15, {3029: 12, 3027: 1, 2531: 40}, {}, {}],
	"identify-result-detail": [12, 15, {3031: 2}, {}, {}],
	"buy": [13, 15, {2531: 120}, {}, {}],
	"dismantle": [14, 3, {2951: 6, 56: 1, 2000: 2}, {}, {}],
	"returns": [15, 3, {2947: 9999}, {"item 2947": 2, "item 56": 1}, {}],
	"home-inbox": [16, 30, {3030: 3, 2531: 7}, {}, {"3031": 2}],
}

const STEPS := {
	"home-empty": ["鉴定神秘珠", "尚无未鉴定神秘珠", "残片换神秘珠", "残片不足（每枚 11）", "分解宝珠", "尚无可分解的背包宝珠", "楼层与品质分布", "1～6层：神秘珠·尘封", "返回分布表", "<", "套装图谱与当前配装", "焚雷：烈焰／雷霆／灵慧", "查看当前队伍此套装", "返回套装列表", "<", "返回"],
	"identify": ["鉴定神秘珠", "神秘珠·玄藏 ×12", "鉴定 5 枚", "确认鉴定 5 枚", "<", "神秘珠·玄藏 ×7", "鉴定 7 枚", "取消", "<", "<", "<"],
	"identify-result-detail": ["鉴定神秘珠", "神秘珠·太初 ×2", "鉴定 1 枚", "确认鉴定 1 枚", "!first"],
	"buy": ["残片换神秘珠", "兑换 1 枚（33 残片）", "确认兑换 1 枚", "<", "兑换 2 枚（66 残片）", "取消", "返回"],
	"dismantle": ["分解宝珠", "宝珠·锋刃·归真 ×6", "分解 5 颗 → 155 残片", "确认分解 5 颗", "<", "宝珠:黑荆棘 ×2", "分解 2 颗 → 6 残片", "取消", "返回", "<", "<"],
	"returns": ["领取暂存宝珠（2颗）", "宝珠·锋刃·凝砂 ×2", "领取这一种", "再次领取", "返回宝珠坊", "返回"],
	"home-inbox": ["返回"],
}


func _run() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(ORACLE)) if FileAccess.file_exists(ORACLE) else null
	if check("oracle_loaded", d is Dictionary and d.get("pages", []).size() == 7, ORACLE):
		for p in d.pages:
			await _flow(p)
	await _geometry()
	await _menu_entry()
	# 选择窗的确定/取消音效还在播：先停掉再退出，免得退出时报资源未释放
	# 退出前把音效播放器与缓存的音频都放掉（满负载时延迟播放的确定/取消音还在，会报资源未释放）
	for pl in XSound._players:
		if is_instance_valid(pl):
			pl.stop()
			pl.stream = null
			pl.queue_free()
	XSound._players.clear()
	XSound._cache.clear()
	await frames(6)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


func _flow(p: Dictionary) -> void:
	var name := str(p.name)
	var f: Array = FLOWS[name]
	var s := _state(f[0], f[1], f[2], f[3], f[4])
	var toast0 := XToast.shown.size()
	var shop := XOrbShop.new()
	var closed := [false]
	shop.closed.connect(func(): closed[0] = true)
	add_child(shop)
	await frames()
	var missing := ""
	for step in STEPS[name]:
		if step == "<":
			shop.choice.cancel()
		elif step == "!first":
			var i := shop.choice.rows.find_custom(func(r): return not r.get("back", false))
			shop.choice.index = i
			shop.choice.ok()
		elif not _pick(shop, step):
			missing = step
			break
	var want: Array = p.screens.filter(func(x): return not x.has("popped"))
	var popped: bool = p.screens.any(func(x): return x.has("popped"))
	var bad := []
	for i in range(maxi(want.size(), shop.log.size())):
		var g = shop.log[i] if i < shop.log.size() else null
		var w = want[i] if i < want.size() else null
		if norm(g) != norm(w):
			bad.append([i, g, w])
			break
	check("pages_" + name, missing == "" and bad.is_empty(), [missing, bad])
	check("closed_" + name, closed[0] == popped)
	var bag := {}
	for k in s.items:
		if int(s.items[k]) > 0:
			bag[str(k)] = float(s.items[k])
	check("after_" + name, bag == norm(p.bag) and norm(s.orb_state.n) == norm(p.rng.n) and XToast.shown.slice(toast0) == p.toasts,
		[bag, p.bag, s.orb_state.n, XToast.shown.slice(toast0), p.toasts])
	shop.queue_free()
	await frames()


func _geometry() -> void:
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) if FileAccess.file_exists(FIXTURE) else null
	if not check("fixture_loaded", fx is Dictionary, FIXTURE):
		return
	var s := _state(11, 15, {3029: 12, 3027: 1, 2531: 40})
	var shop := XOrbShop.new()
	add_child(shop)
	await frames()
	var w := shop.choice.win
	check("home_rect", [w.position.x, w.position.y, w.size.x, w.size.y] == norm(fx.home.rect) and shop.choice.info_height() == float(fx.home.infoH), [w.position, w.size])
	await shot("orb_shop_home")
	_pick(shop, "鉴定神秘珠")
	await frames()
	check("menu_rect", [w.position.x, w.position.y, w.size.x, w.size.y] == norm(fx.menu.rect) and shop.choice.page_rows() == int(fx.menu.pageRows), [w.position, w.size, shop.choice.page_rows()])
	_pick(shop, "神秘珠·玄藏 ×12")
	await frames()
	check("detail_rect", [w.position.x, w.position.y, w.size.x, w.size.y] == norm(fx.detail.rect) and shop.choice.info_height() == float(fx.detail.infoH), [w.position, w.size])
	await shot("orb_shop_identify_detail")
	shop.queue_free()
	await frames()


func _menu_entry() -> void:
	var cmd: Array = XMenu.COMMANDS.filter(func(c): return c[1] == "orbs")
	check("menu_orbs_enabled", cmd.size() == 1 and cmd[0][2] == true)
