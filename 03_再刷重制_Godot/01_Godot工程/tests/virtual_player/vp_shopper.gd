extends RefCounted
## 直接买入（T272 第四棒，Kyo：「逛店一层 800 来步」）：不走路、不开商店画面，用游戏自己的事件解释器跑 NPC 当前页，
## 选项按关键词一个个点开（同 virtual_player._shop_choice 的词表），遇到「商店处理」就在没挂上树的 XShop 上调 Growth.shop 买入
## （买哪些、买多少同走路逛店，只差不画画面、不走路）。NPC 的当前页里有什么、条件怎么分，全由解释器照游戏本来的写法走。
## 回退：虚拟玩家 --vp-walk-shop（回到走路逛店）。

const Growth := preload("res://tests/virtual_player/vp_growth.gd")
const EventCompare := preload("res://tests/xiyou_event_compare.gd")
const FastForward := preload("res://tests/virtual_player/vp_fastforward.gd")
const FABAO_POINTS := 213          # 法宝积分变量
const WORDS := ["购买", "兑换", "功法", "神武", "法宝", "索要礼物"]

var visits := 0                    # 跑了几位 NPC
var shops := 0                     # 开了几家店
var bought := 0
var msec := 0
var log_lines: Array = []
var uses: Array = []               # 买来要用的 {id, actor, n}
var skipped: Array = []            # 解释器没翻译的命令（排查用）


class ShopHost:
	extends EventCompare.EventHost
	var st: XState
	var advance := true
	var res := {"lines": [], "uses": [], "bought": 0}
	var shops := 0
	var tries := {}                # "选项组|序号" → 点过几次

	func show_message(msg: Dictionary) -> int:
		if not msg.has("choices"):
			return 0
		var ch: Array = msg.choices
		var k := "/".join(ch.map(func(c): return str(c)))
		for i in ch.size():
			var t := str(ch[i])
			var key := "%s#%d" % [k, i]
			if int(tries.get(key, 0)) >= 1 or t.contains("抽奖") or not WORDS.any(func(w): return t.contains(w)):
				continue
			tries[key] = int(tries.get(key, 0)) + 1
			return i
		for i in ch.size():
			for w in ["离开", "返回", "取消", "算了", "否"]:
				if str(ch[i]).contains(w):
					return i
		return ch.size() - 1

	func toast(_t: String) -> void:
		pass

	func open_shop(goods: Array, purchase_only: bool) -> void:
		goods = XShopStock.prepare_policy(goods)
		var stock_group := XShopStock.open(st)
		if XItemMarks.shop_orb_only(goods):
			XShopStock.close_policy()
			return
		var shop := XShop.new()
		shop.setup(goods, purchase_only, stock_group)
		var r: Dictionary = Growth.shop(shop, st, Growth.advance_needs(st) if advance else {})
		shop._exit_tree()   # T298：没挂上树直接 free 不走 _exit_tree，免费期间改的 XBabyAllActors.free_open 会留着
		shop.free()
		XShopStock.close_policy()
		shops += 1
		res.bought += int(r.bought)
		res.lines.append_array(r.lines)
		res.uses.append_array(r.uses)


## 在这张图上把每位当前页开着店的 NPC 都「买」一遍。skip：这一次不用去的事件号（Callable(事件) → bool）。返回买入结果
func run(map: XMapScene, st: XState, advance: bool, skip: Callable) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var out := {"lines": [], "uses": [], "bought": 0, "per_event": {}}
	for x in map.events:
		if x.erased or x.page.is_empty() or not x.page.get("list", []).any(func(c): return int(c.code) == 302):
			continue
		if skip.is_valid() and bool(skip.call(x)):
			continue
		var host := ShopHost.new()
		host.st = st
		host.advance = advance
		var interp := MVInterpreter.new(host, map.map_id, x.event_id, (x.page.get("list", []) as Array).duplicate(true))
		await interp.run()
		for s in interp.skipped:
			if not skipped.has(s):
				skipped.append(s)
		visits += 1
		shops += host.shops
		out.bought += int(host.res.bought)
		out.per_event[x.event_id] = {"shops": host.shops, "bought": int(host.res.bought)}
		out.lines.append_array(host.res.lines)
		out.uses.append_array(host.res.uses)
		host.free()
	bought += int(out.bought)
	msec += Time.get_ticks_msec() - t0
	return out


## 不在那张图上也能买（T272）：按地图数据里的事件当前页（开关、变量照存档判）把每位开着店的 NPC 跑一遍，
## 顺手领一次性的礼物页（给法宝积分那种：变量 213 加数）。兑换大厅（132）用它，免得为买法宝、魂灯、头颅换血脉走一趟传送。
func run_map(map_id: int, st: XState, advance: bool) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	# T298（T272 核查 P2-1）：库存、来源记账都认存档里的当前地图；人没在那张图上时临时切过去，买完还原
	# （否则兑换大厅的不朽法宝店漏 4001，来源记成「商店 4」）
	var keep_map := st.map_id
	st.map_id = map_id
	var out := {"lines": [], "uses": [], "bought": 0, "gifts": 0}
	for ev in XDB.map(map_id).get("events", []):
		if not ev is Dictionary:
			continue
		var pg := FastForward.page_of(map_id, ev)
		var list: Array = pg.get("list", [])
		var is_shop := list.any(func(c): return int(c.code) == 302)
		var is_gift := list.any(func(c): return int(c.code) == 122 and int(c.parameters[0]) == FABAO_POINTS and int(c.parameters[2]) == 1)
		if not is_shop and not is_gift:
			continue
		var host := ShopHost.new()
		host.st = st
		host.advance = advance
		var interp := MVInterpreter.new(host, map_id, int(ev.id), list.duplicate(true))
		await interp.run()
		for sk in interp.skipped:
			if not skipped.has(sk):
				skipped.append(sk)
		visits += 1
		shops += host.shops
		if is_gift:
			out.gifts += 1
		out.bought += int(host.res.bought)
		out.lines.append_array(host.res.lines)
		out.uses.append_array(host.res.uses)
		host.free()
	st.map_id = keep_map
	bought += int(out.bought)
	msec += Time.get_ticks_msec() - t0
	return out
