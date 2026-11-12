class_name XTianqiWarLine
extends RefCounted
## 【cc·天启篇·未经审查】战争线（莉co）的关卡流程、事件和对话（四线剧情与关卡设计稿 v0.4 第 2、4.2、5.1、5.7、9.1 节）。
## 台词、地点、敌群、异化数值都在 tianqi_data/war_line.json（只读）。
##
## 流程（存档 flags.tianqi.war = {stage, seen, survived, cleared}）：
## - 选线：通关 5 层回大厅、抽完角色后，小小鱼在方桌主持选线（XTianqi.run_line_choice）；选了战争线就接着跑本线开场。
## - 开场三节（stage 0→3）：选定后接着跑；输了回大厅，之后走大厅的门（去 6 层的那扇）就从输的那一节接着打：
##   1「异兆」大厅时空漩涡 → 六层哥布林部族：侵染·战狂的火焰哥布林，教火花；
##   2「蔓延」部族深处：节末精英蚀骨·战意「巨棒」帕斯诺夫；打完天上出现扔炸弹的小身影；
##   3「天外裂」天外天（新图做好前借 158）：战争骑士生存战（XTianqiHorsemen 的 survival，撑过 6 回合；输了剧情照走，记 survived）。
##   打完回大厅，6 层的门打开（没选线或开场没打完时大厅的门不放人去 6 层，XTianqi.door_blocked）。
## - 楼层节点：10、20、30 层守层者开战前骑士的声音，守层者变成使徒（固定战意／号令官／烟火师，XTianqiWarAlien）；
##   15 层黑暗废墟「原身的回声」、25 层上行天「另外三位的传闻」：第一次到这张图时小小鱼和旁白说一次。
## - 35 层影子（run_shadow）、36 层决战与结局（run_final）：流程和战斗都做了，但 31～36 层还没重做（门上限 34、没有 35／36 层的图），
##   地图上还没有入口，先由测试和以后的 36 层事件调。
##
## 开关 ENABLED（false＝战争线一概不出：选线里不能选、开场和楼层节点都不跑、使徒不异化）；只认天启篇存档且这一档选了战争线，
## 发行构建里还要 XTianqi.RELEASE_OPEN（现在 false），所以发行版、原版档、别的线都不受影响。

const PATH := "res://modes/xiyou/tianqi_data/war_line.json"
const KEY := "war"
const STAGE_DONE := 3

## 开关：false＝战争线一概不出
static var ENABLED := true

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiWarLine: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiWarLine: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


## 表里设计数值含数字 4 的（豁免键是层号、地图号、敌群号、坐标、回合数）
static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


# ---- 开关与进度 ----

## 天启篇存档、发行构建里天启篇已开放（不看选没选线）
static func open_for(s: XState) -> bool:
	return ENABLED and XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


## 这一档走战争线、能跑本线内容
static func allowed(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return open_for(s) and XTianqi.line_of(s) == KEY


static func progress(s: XState) -> Dictionary:
	if not s.flags.tianqi.get(KEY) is Dictionary:
		s.flags.tianqi[KEY] = {"stage": 0, "seen": []}
	return s.flags.tianqi[KEY]


static func stage(s: XState) -> int:
	return int(progress(s).get("stage", 0)) if allowed(s) else 0


static func opening_done(s: XState) -> bool:
	return allowed(s) and stage(s) >= STAGE_DONE


## 大厅里该接着跑开场
static func due(s: XState) -> bool:
	return allowed(s) and stage(s) < STAGE_DONE


static func _seen(s: XState, beat: String) -> bool:
	return progress(s).get("seen", []).has(beat)


static func _mark_seen(s: XState, beat: String) -> void:
	var p := progress(s)
	var seen: Array = p.get("seen", [])
	if not seen.has(beat):
		seen.append(beat)
	p["seen"] = seen


# ---- 台词 ----

static func scene(key: String) -> Array:
	var v = data().get("scenes", {}).get(key)
	return v if v is Array else []


## 一行台词 → 消息窗的行（说话的人放名字框，旁白没有名字框）
static func line_text(row: Array) -> String:
	var who := str(row[0])
	return ("\\n<%s>%s" % [who, str(row[1])]) if who != "" else str(row[1])


static func say(host, key: String) -> void:
	for row in scene(key):
		await host.show_text("", 0, [line_text(row)])


static func _pos(key: String) -> Array:
	return data().get("pos", {}).get(key, [0, 0, 0])


static func _map(key: String) -> int:
	return int(data().get("maps", {}).get(key, 0))


static func _go(host, map_key: String, pos_key: String) -> void:
	var p := _pos(pos_key)
	await host.transfer(_map(map_key), int(p[0]), int(p[1]), int(p[2]))


# ---- 开场三节 ----

## 选定战争线之后（XTianqi.run_line_choice 里）：方桌留下本线颜色、小小鱼说话
static func on_chosen(host) -> void:
	await say(host, "choose")


## 选线之后、或走大厅的门时接着跑开场；输了回大厅停下
static func run_due(host, s: XState) -> void:
	while due(s):
		var st := stage(s)
		var ok := false
		match st:
			0:
				ok = await _run_omen(host, s)
			1:
				ok = await _run_spread(host, s)
			2:
				ok = await _run_rift(host, s)
		if not ok:
			return


## 第 1 节「异兆」：漩涡 → 六层，侵染·战狂的火焰哥布林，教火花
static func _run_omen(host, s: XState) -> bool:
	await say(host, "omen_before")
	await _go(host, "tribe", "tribe_gate")
	await say(host, "omen_arrive")
	if not await _fight(host, s, "omen"):
		return false
	await say(host, "omen_win")
	progress(s)["stage"] = 1
	return true


## 第 2 节「蔓延」：部族深处，蚀骨·战意的部族首领
static func _run_spread(host, s: XState) -> bool:
	await _go(host, "tribe", "tribe_deep")
	await say(host, "spread_before")
	if not await _fight(host, s, "spread"):
		return false
	await say(host, "spread_win")
	progress(s)["stage"] = 2
	return true


## 第 3 节「天外裂」：天外天生存战，输赢剧情都往下走；打完回大厅，6 层的门开
static func _run_rift(host, s: XState) -> bool:
	await _go(host, "tianwai", "tianwai")
	await say(host, "rift_before")
	var won := false
	if XTianqiHorsemen.prepare(KEY, s, "survival"):
		var r: int = await host.start_battle(int(data().shell_troop), false, true)
		won = r == 0
	progress(s)["survived"] = won
	await say(host, "rift_survived" if won else "rift_lost")
	await say(host, "rift_after")
	progress(s)["stage"] = STAGE_DONE
	await _go(host, "hall", "hall")
	await say(host, "rift_home")
	return true


## 开场的一场异化战：允许失败；输了回大厅（全员 1 血由战斗收场处理）
static func _fight(host, s: XState, preset: String) -> bool:
	if not XTianqiWarAlien.prepare(preset, s):
		return false
	var r: int = await host.start_battle(int(XTianqiWarAlien.preset(preset).troop), false, true)
	if r == 0:
		return true
	await say(host, "lose_retry")
	await _go(host, "hall", "hall")
	return false


# ---- 楼层节点 ----

## 大门（大厅 EV036）：没选线、或战争线开场还没打完时，不放人去 6 层及以上（XTianqi.door_blocked 调）
static func door_blocked(s: XState) -> bool:
	if not open_for(s) or not XTianqi.LINE_EVENT_OPEN or int(s.variable(20)) < int(data().door.floor):
		return false
	var line := XTianqi.line_of(s)
	if line == "":
		return true
	return line == KEY and not opening_done(s)


## 地图场景开战前（XMapScene.start_battle 开头）：10／20／30 层守层者变成使徒，先放骑士的声音
static func before_battle(host, s: XState, troop_id: int) -> void:
	if not opening_done(s):
		return
	for key in ["apostle10", "apostle20", "apostle30"]:
		var p := XTianqiWarAlien.preset(key)
		if int(p.get("troop", 0)) == troop_id:
			await say(host, key)
			XTianqiWarAlien.prepare(key, s)
			return


## 到了一张图（不忙时调一次）：15 层原身的回声、25 层传闻，各说一次
static func arrival_beat(s: XState, map_id: int) -> String:
	if not opening_done(s):
		return ""
	if map_id == _map("ruins") and not _seen(s, "echo15"):
		return "echo15"
	if map_id == _map("upper") and not _seen(s, "rumor25"):
		return "rumor25"
	return ""


static func run_arrival(host, s: XState, map_id: int) -> void:
	var beat := arrival_beat(s, map_id)
	if beat == "":
		return
	_mark_seen(s, beat)
	await say(host, beat)


## 地图场景要启动一个事件前：是不是大厅去楼层的那扇门
static func is_door(map_id: int, event_id: int) -> bool:
	return map_id == int(data().door.map) and event_id == int(data().door.event)


## 走大厅的门：战争线开场没打完就接着打；没选线就挡住（小小鱼提示先去方桌）。返回 true＝这次不走原来的门事件
static func run_door(host, s: XState) -> bool:
	if not door_blocked(s):
		return false
	if due(s):
		await run_due(host, s)
	else:
		await host.show_text("", 0, [line_text(["小小鱼", "先去方桌那里看看。"])])
	return true


# ---- 35、36 层（31～36 层重做之后接地图） ----

## 35 层「天启的影子」：每回合一招（弱化的焰浪轰击、噼啪三响），带本线终焉兵临。返回战斗结果（0 胜）
static func run_shadow(host, s: XState) -> int:
	if not opening_done(s):
		return -1
	await say(host, "shadow_before")
	if not XTianqiHorsemen.prepare(KEY, s, "shadow"):
		return -1
	return await host.start_battle(int(data().shell_troop), false, true)


## 36 层决战：战争骑士本体（XTianqiHorsemen 的 body），赢了放结局、记通关和可轮回
static func run_final(host, s: XState) -> int:
	if not opening_done(s):
		return -1
	await say(host, "final_before")
	if not XTianqiHorsemen.prepare(KEY, s, "body"):
		return -1
	var r: int = await host.start_battle(int(data().shell_troop), false, true)
	if r == 0:
		await say(host, "final_win")
		progress(s)["cleared"] = true
		s.flags.tianqi["reincarnate"] = true
	else:
		await say(host, "final_lost")
	return r
