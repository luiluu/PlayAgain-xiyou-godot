extends RefCounted
## 虚拟玩家快进（T238，Kyo 11-19 D225 丙A「他不用真的去一把把刷」）：挂机练级、刷副本首领不开战斗画面，按游戏自己的结算函数直接发奖。
## 只在测试侧，游戏本体不改。
##
## - 一场战斗的结算（settle）：照这场的敌群建 XBattleLogic（同正式战斗的 setup），不打，直接调 rewards() → grant() → end_battle(0)。
##   经验、金钱、掉落（含天启篇通用掉落、挂机屏蔽掉落）、法宝经验、真气／烙印、阅历和号卷的金钱修正都走这一套，跟带画面打赢一场发的一样；
##   不一样的只有：敌人倒下的顺序和本场掷的随机数（掉落按游戏自己的随机流掷，不是复制实打那一场的结果）、我方不掉血、不耗道具。
## - 胜负闸（sample）：结算之前先用无画面的战斗逻辑把这一敌群真打一场（自动战斗，40 回合，打在存档的复制品上、不动真存档）。
##   打不赢就不结算——跟实打一样「这层刷不动」。同一队伍强度对同一敌群只量一次（缓存键：敌群、出战的人和等级、装备件数）。
## - 挂机练级（grind）：照这张楼层图的遇敌表按权重抽敌群，挂机开着结算（挂机屏蔽掉落照游戏的设定），一场一场发。
## - 副本首领（dungeon）：用游戏自己的事件解释器（MVInterpreter，宿主是测试替身）真跑副本入口那一页（扣符文、选档、进门变量）、
##   首领那一页（开战 → 本模块的 settle 判胜 → 档位开关、肝帝积分、CE1439 抽奖券与熟练度、神秘珠、种族补给）、
##   领奖那一页（宝箱 CE849～851 等、按变量 94 的档、传回楼层、重置副本）。和实打差的只有路上的小怪（不打、不发它们的掉落）。

const EventCompare := preload("res://tests/xiyou_event_compare.gd")
const TIER_SWITCHES := [1561, 1660]
const SAMPLE_TURNS := 40

var bot: Node                      # 虚拟玩家（拿它的随机数、日志、往树上挂替身）
var rng: RandomNumberGenerator
var sample_cache := {}             # 缓存键 → 量出来赢没赢
var samples := 0                   # 量了几场（无画面真打）
var sample_losses := 0
var settled := 0                   # 快进结算了几场（练级＋副本首领）
var grind_battles := 0
var dungeon_runs := 0
var dungeon_kings := 0             # 其中选到「王者难度」的几次
var log_lines: Array = []
var msec := 0                      # 快进一共花了多少毫秒（墙钟）


func _init(owner: Node, r: RandomNumberGenerator) -> void:
	bot = owner
	rng = r


func _note(msg: String) -> void:
	log_lines.append(msg)
	if bot != null and bot.has_method("_log"):
		bot._log("快进：" + msg)


# ---------------------------------------------------------------- 结算一场

## 一场按打赢结算（同 XBattleScene._victory 的 rewards → grant → end_battle(0)）。返回 {exp, gold, drops}
func settle(st: XState, troop: int) -> Dictionary:
	var logic := XBattleLogic.new()
	logic.setup(troop, st)
	var r := logic.rewards()
	logic.grant(r)
	logic.end_battle(0)
	XHangUp.after_battle(st)
	settled += 1
	return {"exp": int(r.exp), "gold": int(r.gold), "drops": (r.drops as Array).size()}


## 胜负闸：在存档的复制品上用无画面战斗逻辑把这一敌群自动打一场，赢了返回 true
func sample(st: XState, troop: int) -> bool:
	var key := _sample_key(st, troop)
	if sample_cache.has(key):
		return bool(sample_cache[key])
	var copy := XState.from_dict(st.to_dict())
	XState._become_current(copy)
	for a in copy.members():
		a.recover_all()
	var won := false
	var logic := XBattleLogic.new()
	logic.setup(troop, copy)
	logic.auto = true
	_drain(logic, logic.troop_events())
	for r in SAMPLE_TURNS:
		logic.start_turn()
		logic.take_turn_start_logs()
		var count := 0
		var first := true
		while count < 120:
			var u := logic.next_subject()
			_drain(logic, logic.troop_events(u if first else null))
			first = false
			if u == null or logic.is_over():
				break
			count += 1
			var cmd := logic.decide(u)
			logic.act(u, cmd[0], cmd[1])
			if logic.is_over():
				break
		if logic.is_over():
			break
		logic.end_turn()
		_drain(logic, logic.troop_events(null, true))
		if logic.is_over():
			break
	won = logic.is_won() and not logic.is_lost()
	logic.end_battle(0 if won else 2)
	XState._become_current(st)
	samples += 1
	if not won:
		sample_losses += 1
	sample_cache[key] = won
	_note("样本 敌群 %d：%s" % [troop, "赢" if won else "没打赢"])
	return won


func _sample_key(st: XState, troop: int) -> String:
	var parts := [str(troop), str(int(st.variable(20)))]
	for a in st.battle_members():
		parts.append("%d:%d:%d" % [a.actor_id, a.level, a.equips.filter(func(e): return e is Dictionary and not e.is_empty()).size()])
	return ",".join(parts)


static func _drain(logic: XBattleLogic, logs: Array) -> void:
	var guard := 0
	while logic.is_event_waiting() and guard < 50:
		guard += 1
		var last: Dictionary = logs[-1] if not logs.is_empty() and logs[-1] is Dictionary else {}
		logs = logic.resume_event(int(last.get("token", 0)), 0)


# ---------------------------------------------------------------- 挂机练级

## 这张图的遇敌表（[{troopId, weight}]）
static func encounters(map_id: int) -> Array:
	var out := []
	for e in XDB.map(map_id).get("encounterList", []):
		if e is Dictionary and int(e.get("troopId", 0)) > 0 and int(e.get("weight", 0)) > 0:
			out.append({"troop": int(e.troopId), "weight": int(e.weight)})
	return out


func _pick(list: Array) -> int:
	var total := 0
	for e in list:
		total += int(e.weight)
	var r := rng.randi_range(1, maxi(1, total))
	for e in list:
		r -= int(e.weight)
		if r <= 0:
			return int(e.troop)
	return int(list[-1].troop)


## 挂机练级快进：最多 n 场；until_cap＝出战的人都到等级上限就停。返回 {battles, stop, exp, gold, drops}
func grind(st: XState, map_id: int, n: int, until_cap: bool) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var list := encounters(map_id)
	var out := {"battles": 0, "stop": "", "exp": 0, "gold": 0, "drops": 0}
	if list.is_empty():
		out.stop = "地图 %d 没有遇敌" % map_id
		return out
	# 挂机开着结算：挂机屏蔽掉落、挂机里的规则照游戏（结算完还原）
	var was := [st.hang_up_active, st.hang_up_origin]
	st.hang_up_active = true
	if st.hang_up_origin.x < 0:
		st.hang_up_origin = Vector2i(st.x, st.y)
	for i in n:
		if until_cap and st.battle_members().all(func(a): return a.level >= a.max_level()):
			out.stop = "出战的人都到等级上限"
			break
		var troop := _pick(list)
		if not sample(st, troop):
			out.stop = "敌群 %d 样本没打赢" % troop
			break
		var r := settle(st, troop)
		out.battles += 1
		out.exp += int(r.exp)
		out.gold += int(r.gold)
		out.drops += int(r.drops)
	st.hang_up_active = was[0]
	st.hang_up_origin = was[1]
	grind_battles += int(out.battles)
	msec += Time.get_ticks_msec() - t0
	_note("挂机练级 %d 场（%s）经验 %d 金钱 %d 掉落 %d 件" % [out.battles, out.stop if out.stop != "" else "练满", out.exp, out.gold, out.drops])
	return out


# ---------------------------------------------------------------- 副本首领

## 测试替身宿主：选项按关键词选（要重置先「重置副本」，再「挑战副本」，选档选最高的），战斗交给快进结算
class FFHost:
	extends EventCompare.EventHost
	var ff = null
	var st: XState = null
	var want := "挑战副本"
	var tier_cap := 3
	var picked_tier := -1
	var battles: Array = []
	var toasts: Array = []

	func show_message(msg: Dictionary) -> int:
		if not msg.has("choices"):
			return super.show_message(msg)
		var ch: Array = msg.choices
		var tiers := []
		for i in ch.size():
			if str(ch[i]).ends_with("难度"):
				tiers.append(i)
		var pick := -1
		if not tiers.is_empty():
			pick = tiers[mini(tiers.size() - 1, tier_cap)]
			picked_tier = tiers.find(pick)
			if str(ch[pick]).begins_with("王者"):
				picked_tier = 3
		else:
			for w in [want, "领取", "确定", "是"]:
				for i in ch.size():
					if pick < 0 and str(ch[i]).contains(w):
						pick = i
		if pick < 0:
			pick = int(msg.get("default", 0)) if int(msg.get("default", -1)) >= 0 else 0
		trace.append({"t": "msg", "choices": ch, "pick": pick})
		return pick

	func toast(text: String) -> void:
		toasts.append(text)

	func start_battle(troop_id: int, _can_escape: bool, _can_lose: bool) -> int:
		battles.append(troop_id)
		ff.settle(st, troop_id)
		return 0


## 地图上某个事件的当前页（照 MVEvent._find_page，不建节点）
static func page_of(map_id: int, ev: Dictionary) -> Dictionary:
	var e := MVEvent.new()
	e.map_id = map_id
	e.event_id = int(ev.id)
	e.data = ev
	var i := e._find_page()
	e.free()
	return ev.pages[i] if i >= 0 else {}


## 楼层的副本入口：这张图或隔一道门的图上的入口事件 [地图号, 事件]；没有返回 []
static func find_entry(map_id: int) -> Array:
	var maps := [map_id]
	for ev in XDB.map(map_id).get("events", []):
		if ev is Dictionary:
			for pg in ev.get("pages", []):
				for c in pg.get("list", []):
					if int(c.get("code", 0)) == 201 and int(c.parameters[0]) == 0 and not maps.has(int(c.parameters[1])):
						maps.append(int(c.parameters[1]))
	for m in maps:
		if not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % int(m)):
			continue
		for ev in XDB.map(int(m)).get("events", []):
			if ev is Dictionary:
				for pg in ev.get("pages", []):
					if not XDungeon.entry_spec(pg.get("list", [])).is_empty():
						return [int(m), ev]
	return []


## 副本首领：从副本入口传进去的那张图起，沿「换图」往里找（最多 6 张），按副本档位开关分页并会开战的事件 → [地图号, 事件, 敌群]
static func find_boss(entry_map: int, entry_ev: Dictionary) -> Array:
	var queue := []
	for pg in entry_ev.get("pages", []):
		for t in XDungeon.entry_spec(pg.get("list", [])).get("transfers", []):
			if not queue.has(int(t[0])):
				queue.append(int(t[0]))
	var seen := {entry_map: true}
	var i := 0
	while i < queue.size() and i < 6:
		var m := int(queue[i])
		i += 1
		if seen.has(m) or not FileAccess.file_exists(XDB.BASE + "maps/Map%03d.json" % m):
			continue
		seen[m] = true
		for ev in XDB.map(m).get("events", []):
			if not ev is Dictionary:
				continue
			for pg in ev.get("pages", []):
				var troop := _boss_troop(pg)
				if troop > 0:
					return [m, ev, troop]
		for ev in XDB.map(m).get("events", []):
			if ev is Dictionary:
				for pg in ev.get("pages", []):
					for c in pg.get("list", []):
						if int(c.get("code", 0)) == 201 and int(c.parameters[0]) == 0 and not seen.has(int(c.parameters[1])) and not queue.has(int(c.parameters[1])):
							queue.append(int(c.parameters[1]))
	return []


## 同 virtual_player._dungeon_boss_troop：页条件里有副本档位开关、并且会开战（敌群写死）
static func _boss_troop(pg: Dictionary) -> int:
	var cond: Dictionary = pg.get("conditions", {})
	var tiered := false
	for k in ["switch1", "switch2"]:
		if bool(cond.get(k + "Valid", false)) and int(cond.get(k + "Id", 0)) >= TIER_SWITCHES[0] and int(cond.get(k + "Id", 0)) <= TIER_SWITCHES[1]:
			tiered = true
	if not tiered:
		return 0
	for c in pg.get("list", []):
		if int(c.get("code", 0)) == 301 and int(c.parameters[0]) == 0:
			return int(c.parameters[1])
	return 0


## 跑一页事件（宿主是替身）
func _run_page(host: FFHost, map_id: int, ev: Dictionary) -> bool:
	var pg := page_of(map_id, ev)
	if pg.is_empty():
		return false
	var interp := MVInterpreter.new(host, map_id, int(ev.id), (pg.get("list", []) as Array).duplicate(true))
	await interp.run()
	return true


## 刷一次副本首领（真跑入口页 → 首领页 → 领奖页）。返回 {ok, why, tier, troop, tickets, points}
func dungeon_once(st: XState, floor_map: int, buy_rune: Callable) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var out := {"ok": false, "why": "", "tier": -1, "troop": 0}
	var ent := find_entry(floor_map)
	if ent.is_empty():
		out.why = "地图 %d 一带没有副本入口" % floor_map
		return out
	var boss := find_boss(int(ent[0]), ent[1])
	if boss.is_empty():
		out.why = "副本（入口在地图 %d）里找不到首领" % int(ent[0])
		return out
	out.troop = int(boss[2])
	if not sample(st, int(boss[2])):
		out.why = "副本首领（敌群 %d）样本没打赢" % int(boss[2])
		msec += Time.get_ticks_msec() - t0
		return out
	var spec := {}
	var epg := page_of(int(ent[0]), ent[1])
	spec = XDungeon.entry_spec(epg.get("list", []))
	if spec.is_empty():
		out.why = "副本入口当前页不是入口"
		return out
	if st.item_count(int(spec.rune)) <= 0 and not bool(buy_rune.call(st, int(spec.rune), 5)):
		out.why = "买不起副本符文"
		return out
	var keep := [st.map_id, st.x, st.y, st.direction]
	var tickets0 := st.item_count(XDungeon.TICKET)
	var points0 := int(st.variable(XCasinoBatch.VAR_POINTS))
	var host := FFHost.new()
	host.ff = self
	host.st = st
	bot.add_child(host)
	# 上一次没重置：先「重置副本」
	if int(st.variable(XDungeon.VAR_SEALED)) != 0:
		host.want = "重置副本"
		await _run_page(host, int(ent[0]), ent[1])
	host.want = "挑战副本"
	await _run_page(host, int(ent[0]), ent[1])
	if not XDungeon.inside(st):
		out.why = "入口没进去（%s）" % str(host.trace.slice(-3))
	else:
		out.tier = host.picked_tier
		# 首领那一页（开战→结算）；打完首领事件换到领奖页（宝箱、传回楼层、重置）
		var bmap := int(boss[0])
		st.map_id = bmap
		await _run_page(host, bmap, boss[1])
		if host.battles.is_empty():
			out.why = "首领页没开战（%s）" % str(host.trace.slice(-3))
		else:
			await _run_page(host, bmap, boss[1])
			out.ok = true
		if XDungeon.inside(st):
			# 没走到领奖页的传回：照「逃离」收拾（变量 21／5／6／450、难度、挂机开关），免得卡在副本里
			XDungeon.leave(st)
			st.set_variable(XDungeon.VAR_INSIDE, 0)
			out.why += "；收尾时还在副本里，按逃离收拾"
	st.map_id = int(keep[0])
	st.x = int(keep[1])
	st.y = int(keep[2])
	st.direction = int(keep[3])
	host.queue_free()
	out["tickets"] = st.item_count(XDungeon.TICKET) - tickets0
	out["points"] = int(st.variable(XCasinoBatch.VAR_POINTS)) - points0
	if out.ok:
		dungeon_runs += 1
		if int(out.tier) == 3:
			dungeon_kings += 1
	msec += Time.get_ticks_msec() - t0
	_note("副本首领（敌群 %d，档 %d）：%s 抽奖券 %+d 积分 %+d" % [int(out.troop), int(out.tier), "打倒" if out.ok else out.why, int(out.tickets), int(out.points)])
	return out
