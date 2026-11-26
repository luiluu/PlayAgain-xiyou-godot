extends "res://tests/virtual_player/t445_book_probe.gd"
## T527：角色复量「换伤支全选」那一遍。沿用 T445 炼狱探针（T501 口径），只在建档后把立到的每一境
## 有换伤支（brand.json realm.branches 里 trade=true：锋骨、化刃、劫火、开印）的都选上；不带 --trade=all 时与 T445 逐字相同。
## 只读游戏代码，不改正式数据（--realm-off 只在本进程内存里关 T514 开关做消融）。用法同 t445_book_probe，多 --trade=all、--realm-off、--suit-tpl-off：
##   godot --headless --audio-driver Dummy --path <工程> -s res://tests/test_main_loop.gd \
##     res://tests/virtual_player/t527_trade_probe.tscn -- --tier=all --actors=... --book-build=lianyu --noisy --seed=1 --trade=all --out=<json>

var trade_all := false


func _ready() -> void:
	trade_all = OS.get_cmdline_user_args().has("--trade=all")
	if OS.get_cmdline_user_args().has("--realm-off"):  # 消融：关掉 T514 境底／境支（XTianqiBrandRealm.ENABLED），找 T501 之后峰值上涨的来源
		XTianqiBrandRealm.ENABLED = false
	if OS.get_cmdline_user_args().has("--suit-tpl-off"):  # 消融：关掉 T515 套装模板（XTianqiSuits.TEMPLATE）
		XTianqiSuits.TEMPLATE = false
	super._ready()


func _run() -> void:
	super._run()
	report["trade_all"] = trade_all


func _pick_trades(a: XActor) -> void:
	if not trade_all or a == null:
		return
	var store = a.zhenqi.get(XTianqiBrandRealm.KEY)
	if not store is Dictionary:
		store = {}
	var picked := []
	for r in range(1, XTianqiBrand.realm(a) + 1):
		for b in XTianqiBrandRealm.branches(r):
			if bool(b.get("trade", false)):
				store[str(r)] = str(b.get("key", ""))
				picked.append(str(b.get("name", "")))
				break
	a.zhenqi[XTianqiBrandRealm.KEY] = store
	a.param_mark_dirty()
	a.refresh_passive()
	a.recover_all()
	print("T527_TRADE %d realm=%d picked=%s dealt=%.3f" % [a.actor_id, XTianqiBrand.realm(a), picked, XTianqiBrandRealm.dealt_mult(a)])


func _lianyu_state(id: int) -> XState:
	var s := super._lianyu_state(id)
	_pick_trades(s.actor(id))
	return s


func _lianyu_state_group(ids: Array) -> XState:
	var s := super._lianyu_state_group(ids)
	for aid in ids:
		_pick_trades(s.actor(int(aid)))
	return s
