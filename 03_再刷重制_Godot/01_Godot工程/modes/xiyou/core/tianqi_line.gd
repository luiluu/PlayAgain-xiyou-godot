class_name XTianqiLine
extends RefCounted
## 【cc·天启篇·未经审查】四线共用的关卡流程（四线剧情与关卡设计稿 v0.4 第 2～4 节）：进度、门、台词、开场、楼层节点、35／36 层。
## 从战争线（XTianqiWarLine，cc/pro-tianqi-war）抽出来，每条线只给一张表 tianqi_data/<线>_line.json 和本线的异化规则模块。
##
## 每条线的表：
## - maps、pos、door、shell_troop、presets（开场的异化战与 10／20／30 层使徒）、scenes（台词，每行 [说话的人, 文字]）；
## - opening：开场前几节，每节一串步骤 ["say", 台词键]／["go", 地图键, 坐标键]／["fight", 预设键]（fight 输了回大厅、停在这一节）；
##   最后一节固定是「天外裂」生存战（XTianqiHorsemen 的 survival），台词键 rift_before／rift_survived／rift_lost／rift_after／rift_home；
## - beats：第一次到某张图说一次的楼层节点 {节点键: 地图键}（15 层回声、25 层传闻等，开场打完之后才有）。
## 进度存档 flags.tianqi.<线> = {stage, seen, survived, cleared}；stage 0～STAGE_DONE（开场节数＋1）。
##
## 开关：每条线自己的 ENABLED（XTianqiWarLine、XTianqiFamineLine、XTianqiDeathLine）；只认天启篇存档且这一档选了这条线，发行构建里还要 XTianqi.RELEASE_OPEN。

const DATA_DIR := "res://modes/xiyou/tianqi_data/"
## 做好了内容的线（和 XTianqi.LINES 的键一致）
const KEYS := ["war", "famine", "plague", "death"]

static var _data: Dictionary = {}


static func enabled(key: String) -> bool:
	match key:
		"war":
			return XTianqiWarLine.ENABLED
		"famine":
			return XTianqiFamineLine.ENABLED
		"plague":
			return XTianqiPlagueLine.ENABLED
		"death":
			return XTianqiDeathLine.ENABLED
	return false


## 这条线做好了、开着（XTianqi.line_playable）
static func playable(key: String) -> bool:
	return KEYS.has(key) and enabled(key)


static func any_playable() -> bool:
	return KEYS.any(func(k): return playable(k))


static func data(key: String) -> Dictionary:
	if not KEYS.has(key):
		return {}
	if not _data.has(key):
		var path := DATA_DIR + key + "_line.json"
		if XDataFile.missing(path):  # 发行包里没有（没发行的内容，见 发行内容审计.py）
			return {}
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("XTianqiLine: 读不到 " + path)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if not parsed is Dictionary:
			push_error("XTianqiLine: JSON 解析失败 " + path)
			return {}
		_data[key] = parsed
	return _data[key]


static func reload(key := "") -> void:
	if key == "":
		_data = {}
	else:
		_data.erase(key)


## 表里设计数值含数字 4 的（豁免键是层号、地图号、敌群号、坐标、回合数）
static func nice_number_violations(key: String) -> Array:
	var out := []
	var d := data(key)
	XTianqiHorsemen._scan(d, "", d.get("nice_number_exempt", []), out)
	return out


# ---- 异化规则（各线自己的模块） ----

static func alien_preset(key: String, name: String) -> Dictionary:
	var p = data(key).get("presets", {}).get(name)
	return p if p is Dictionary else {}


static func alien_prepare(key: String, name: String, s: XState) -> bool:
	match key:
		"war":
			return XTianqiWarAlien.prepare(name, s)
		"famine":
			return XTianqiFamineAlien.prepare(name, s)
		"plague":
			return XTianqiPlagueAlien.prepare(name, s)
		"death":
			return XTianqiDeathAlien.prepare(name, s)
	return false


## 按段异化（XTianqiSegAlien）：把指定的敌人交给本线异化模块，list 每项 {enemy, tier, kind}
static func alien_apply(key: String, logic, s: XState, list: Array) -> bool:
	match key:
		"war":
			return XTianqiWarAlien.apply(logic, s, "segment", list)
		"famine":
			return XTianqiFamineAlien.apply(logic, s, "segment", list)
		"plague":
			return XTianqiPlagueAlien.apply(logic, s, "segment", list)
		"death":
			return XTianqiDeathAlien.apply(logic, s, "segment", list)
	return false


## 本线异化模块做好了战斗规则的种类（按段异化只从这里面抽）
static func alien_kinds(key: String) -> Array:
	match key:
		"war":
			return XTianqiWarAlien.kinds()
		"famine":
			return XTianqiFamineAlien.kinds()
		"plague":
			return XTianqiPlagueAlien.kinds()
		"death":
			return XTianqiDeathAlien.kinds()
	return []


## 这一场已经有本线预设的异化
static func alien_active(logic) -> bool:
	return XTianqiWarAlien.active(logic) or XTianqiFamineAlien.active(logic) or XTianqiPlagueAlien.active(logic) or XTianqiDeathAlien.active(logic)


# ---- 开关与进度 ----

## 天启篇存档、发行构建里天启篇已开放（不看选没选线）
static func open_for(s: XState) -> bool:
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


## 这一档走这条线、能跑本线内容
static func allowed(key: String, s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return playable(key) and open_for(s) and XTianqi.line_of(s) == key


## 这一档走的、能跑的线（没有为空串）
static func current(s: XState) -> String:
	var key := XTianqi.line_of(s) if s != null else ""
	return key if allowed(key, s) else ""


static func stage_done(key: String) -> int:
	return data(key).get("opening", []).size() + 1


static func progress(key: String, s: XState) -> Dictionary:
	if not s.flags.tianqi.get(key) is Dictionary:
		s.flags.tianqi[key] = {"stage": 0, "seen": []}
	return s.flags.tianqi[key]


static func stage(key: String, s: XState) -> int:
	return int(progress(key, s).get("stage", 0)) if allowed(key, s) else 0


static func opening_done(key: String, s: XState) -> bool:
	return allowed(key, s) and stage(key, s) >= stage_done(key)


## 大厅里该接着跑开场
static func due(key: String, s: XState) -> bool:
	return allowed(key, s) and stage(key, s) < stage_done(key)


static func seen(key: String, s: XState, beat: String) -> bool:
	return progress(key, s).get("seen", []).has(beat)


static func mark_seen(key: String, s: XState, beat: String) -> void:
	var p := progress(key, s)
	var list: Array = p.get("seen", [])
	if not list.has(beat):
		list.append(beat)
	p["seen"] = list


# ---- 台词与移动 ----

static func scene(key: String, name: String) -> Array:
	var v = data(key).get("scenes", {}).get(name)
	return v if v is Array else []


## 一行台词 → 消息窗的行（说话的人放名字框，旁白没有名字框）
static func line_text(row: Array) -> String:
	var who := str(row[0])
	return ("\\n<%s>%s" % [who, str(row[1])]) if who != "" else str(row[1])


static func say(host, key: String, name: String) -> void:
	for row in scene(key, name):
		await host.show_text("", 0, [line_text(row)])


static func map_of(key: String, name: String) -> int:
	return int(data(key).get("maps", {}).get(name, 0))


static func go(host, key: String, map_name: String, pos_name: String) -> void:
	var p: Array = data(key).get("pos", {}).get(pos_name, [0, 0, 0])
	await host.transfer(map_of(key, map_name), int(p[0]), int(p[1]), int(p[2]))


# ---- 开场 ----

## 选定之后（XTianqi.run_line_choice 里）：方桌留下本线颜色、小小鱼说话，接着跑开场
static func on_chosen(host, s: XState, key: String) -> void:
	if not allowed(key, s):
		return
	await say(host, key, "choose")
	await run_due(host, s, key)


## 选线之后、或走大厅的门时接着跑开场；输了回大厅停下
static func run_due(host, s: XState, key: String) -> void:
	var opening: Array = data(key).get("opening", [])
	while due(key, s):
		var st := stage(key, s)
		var ok := false
		if st < opening.size():
			ok = await _run_steps(host, s, key, opening[st])
			if ok:
				progress(key, s)["stage"] = st + 1
		else:
			ok = await _run_rift(host, s, key)
		if not ok:
			return


static func _run_steps(host, s: XState, key: String, steps: Array) -> bool:
	for step in steps:
		match str(step[0]):
			"say":
				await say(host, key, str(step[1]))
			"go":
				await go(host, key, str(step[1]), str(step[2]))
			"fight":
				if not await fight(host, s, key, str(step[1])):
					return false
	return true


## 最后一节「天外裂」：天外天生存战，输赢剧情都往下走；打完回大厅，6 层的门开
static func _run_rift(host, s: XState, key: String) -> bool:
	await go(host, key, "tianwai", "tianwai")
	await say(host, key, "rift_before")
	var won := false
	if XTianqiHorsemen.prepare(key, s, "survival"):
		var r: int = await host.start_battle(int(data(key).shell_troop), false, true)
		won = r == 0
	progress(key, s)["survived"] = won
	await say(host, key, "rift_survived" if won else "rift_lost")
	await XTianqiRewards.after_rift(host, s, key, won)  # 天启篇奖励：第一件净印；撑过的额外奖励
	await say(host, key, "rift_after")
	progress(key, s)["stage"] = stage_done(key)
	await go(host, key, "hall", "hall")
	await say(host, key, "rift_home")
	return true


## 开场的一场异化战：允许失败；输了回大厅（全员 1 血由战斗收场处理）
static func fight(host, s: XState, key: String, preset: String) -> bool:
	if not alien_prepare(key, preset, s):
		return false
	var r: int = await host.start_battle(int(alien_preset(key, preset).troop), false, true)
	if r == 0:
		return true
	await say(host, key, "lose_retry")
	await go(host, key, "hall", "hall")
	return false


# ---- 门与楼层节点（地图场景调，按本档的线分派） ----

## 地图场景要启动一个事件前：是不是大厅去楼层的那扇门（各线的表门都是大厅 EV036）
static func is_door(map_id: int, event_id: int) -> bool:
	for key in KEYS:
		var d: Dictionary = data(key).get("door", {})
		if not d.is_empty():
			return map_id == int(d.map) and event_id == int(d.event)
	return false


static func _door_floor() -> int:
	for key in KEYS:
		var d: Dictionary = data(key).get("door", {})
		if not d.is_empty():
			return int(d.floor)
	return 6


## 大厅的门：已通关 5 层而没选线、或本线开场还没打完时，不放人去 6 层及以上
static func door_blocked(s: XState) -> bool:
	if not open_for(s) or not XTianqi.LINE_EVENT_OPEN or not any_playable() or int(s.variable(20)) < _door_floor():
		return false
	var line := XTianqi.line_of(s)
	if line == "":
		return true
	return allowed(line, s) and not opening_done(line, s)


## 走大厅的门：开场没打完就接着打；没选线就挡住（小小鱼提示先去方桌）。返回 true＝这次不走原来的门事件
static func run_door(host, s: XState) -> bool:
	if not door_blocked(s):
		return false
	var key := current(s)
	if key != "" and due(key, s):
		await run_due(host, s, key)
	else:
		await host.show_text("", 0, [line_text(["小小鱼", "先去方桌那里看看。"])])
	return true


## 地图场景开战前（XMapScene.start_battle 开头）：10／20／30 层守层者变成使徒，先放骑士的声音
static func before_battle(host, s: XState, troop_id: int) -> void:
	var key := current(s)
	if key == "" or not opening_done(key, s):
		return
	for name in ["apostle10", "apostle20", "apostle30"]:
		var p := alien_preset(key, name)
		if int(p.get("troop", 0)) == troop_id:
			await say(host, key, name)
			alien_prepare(key, name, s)
			XTianqiRewards.note_apostle(key, name)  # 天启篇奖励：打赢掉净印（XMapScene.start_battle 末尾发）
			return


## 到了一张图（不忙时调一次）：饥荒线的三层序幕（不分线）、本线的楼层节点，各说一次
static func arrival_beat(s: XState, map_id: int) -> String:
	if s == null:
		return ""
	var pro := XTianqiFamineLine.prologue_beat(s, map_id)
	if pro != "":
		return pro
	var key := current(s)
	if key == "" or not opening_done(key, s):
		return ""
	var beats: Dictionary = data(key).get("beats", {})
	for beat in beats:
		if map_id == map_of(key, str(beats[beat])) and not seen(key, s, str(beat)):
			return str(beat)
	return ""


static func run_arrival(host, s: XState, map_id: int) -> void:
	var beat := arrival_beat(s, map_id)
	if beat == "":
		return
	if beat in ["prologue", "after_clear"]:
		await XTianqiFamineLine.run_prologue(host, s, beat)
		return
	var key := current(s)
	mark_seen(key, s, beat)
	await say(host, key, beat)
	if key == XTianqiFamineLine.KEY:
		await XTianqiFamineLine.after_beat(host, s, beat)
	if key == XTianqiPlagueLine.KEY:
		await XTianqiPlagueLine.after_beat(host, s, beat)
	await XTianqiSect.after_beat(host, s, beat)  # 天启篇教派连带内容包乙：15／25 层节点演完，小小鱼松一重枷锁


# ---- 35、36 层（31～36 层重做之后接地图） ----

## 35 层「天启的影子」。返回战斗结果（0 胜；-1 没开）
static func run_shadow(host, s: XState, key: String) -> int:
	if not opening_done(key, s):
		return -1
	await say(host, key, "shadow_before")
	if not XTianqiHorsemen.prepare(key, s, "shadow"):
		return -1
	var r: int = await host.start_battle(int(data(key).shell_troop), false, true)
	await XTianqiRewards.after_shadow(host, s, key, r)  # 天启篇奖励：半强度遗物、终焉核
	return r


## 36 层决战：本线骑士本体（XTianqiHorsemen 的 body），赢了放结局、记通关和可轮回
static func run_final(host, s: XState, key: String) -> int:
	if not opening_done(key, s):
		return -1
	await say(host, key, "final_before")
	if not XTianqiHorsemen.prepare(key, s, "body"):
		return -1
	XTianqiWeakClear.begin(s)  # 全弱者通关资格：开战时记上场＋助力位
	var r: int = await host.start_battle(int(data(key).shell_troop), false, true)
	if r == 0:
		await say(host, key, "final_win")
		progress(key, s)["cleared"] = true
		var first := not bool(s.flags.tianqi.get("reincarnate", false))
		s.flags.tianqi["reincarnate"] = true
		await XTianqiRewards.after_final(host, s, key, r)  # 天启篇奖励：遗物、徽记、终焉核
		if first and host != null and host.has_method("show_text"):  # 结局结算：本档可轮回（读档界面线名后面标「可轮回」）
			await host.show_text("", 0, ["\\c[2]%s线·终\\c[0]　本档获得了「可轮回」。" % str(XTianqi.line_info(key).get("name", key))])
	else:
		await say(host, key, "final_lost")
	await XTianqiWeakClear.finish(host, s, r)  # 全弱者通关资格：打赢且全弱者就记本档（输了只收场）
	return r
