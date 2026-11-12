class_name XTianqiSummit
extends RefCounted
## 【cc·天启篇·未经审查】31～36 层重做（天启篇_31至36层重做方案 v0.2；四线剧情与关卡设计稿 v0.4 第 3.1、3.2、6、7 节）。
## 台词、地图、鸿钧数值都在 tianqi_data/summit.json（只读）。只在天启篇，西游照原版（Kyo 11-08 已确认）。
##
## - 31～33 层照原版：大厅的门（Map004 EV036）按变量 20 送到 148、156、157，旧守层者女娲、伏羲、鸿蒙老祖不动。
## - 门的上限 34 → 36：变量 20 ≥ 34 时由本模块接管大厅的门（run_door），按层跑 run_floor：
##   34 太清天（借 158 换色）守层者鸿钧（借鸿蒙老祖外观，能力值乘 rate），赢了变量 20 → 35；
##   35 玉清天（借 157 换色）本线天启的影子（各线的 run_shadow），赢了变量 20 → 36；
##   36 天外天（新图做好前借 158）本线骑士决战（各线的 run_final，结局、可轮回在那边记），赢了接洪荒通关奖励。
##   每层一进图先说两句、问上不上；不上、输了、打完都回大厅（这几层没有地图上的事件，流程一次走完）。
## - 旧 34 层「决战：天外天」（Map158）在天启篇里：随机遇敌拿掉（no_encounter），决战事件（EV001，洪荒奖励／6213）不跑。
## - 洪荒通关奖励和 6213 挪到 36 层：开关 2483 开着才有；「没打鸿钧」改成「没打过本档 34 层鸿钧」；天启篇默认不学 6213（XTianqi.NO_HEAVEN_GAZE）。
## - 再挑战（大厅 EV062）：打过 34～36 层后，先问要不要再见鸿钧／影子／骑士（只打，不改层数、不记通关），选「别的事」照原事件。
##
## 各线的 35、36 层由线模块给（line_module）：现在有战争线 XTianqiWarLine、饥荒线 XTianqiFamineLine；别的线做好后在 line_module 里加一行。
## 开关 ENABLED（false＝回到原版：门上限 34、158 照旧有随机遇敌和决战事件）；只认天启篇存档且选了线，
## 发行构建里还要 XTianqi.RELEASE_OPEN（现在 false），所以发行版、原版档都不受影响。

const PATH := "res://modes/xiyou/tianqi_data/summit.json"
const FLOOR_VAR := 20

## 开关：false＝31～36 层重做一概不出（门上限照原版 34）
static var ENABLED := true

static var _data: Dictionary = {}
## 下一场是 34 层鸿钧（BattleLogic.setup 里换名字和能力值）
static var _pending := ""
## 正在跑的层（34～36；地图名用，跑完清零）
static var _at := 0


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiSummit: 读不到 " + PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("XTianqiSummit: JSON 解析失败 " + PATH)
	return _data


static func reload() -> void:
	_data = {}


## 表里设计数值含数字 4 的（豁免键是层号、地图号、敌群号、坐标等）
static func nice_number_violations() -> Array:
	var out := []
	XTianqiHorsemen._scan(data(), "", data().get("nice_number_exempt", []), out)
	return out


# ---- 开关与进度 ----

## 天启篇存档、发行构建里天启篇已开放、选了线
static func allowed(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and s != null and XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) \
		and XTianqi.line_of(s) != ""


static func progress(s: XState) -> Dictionary:
	if not s.flags.tianqi.get("summit") is Dictionary:
		s.flags.tianqi["summit"] = {}
	return s.flags.tianqi["summit"]


static func top() -> int:
	return int(data().get("top", 36))


static func from_floor() -> int:
	return int(data().get("from", 34))


static func floor_info(n: int) -> Dictionary:
	var v = data().get("floors", {}).get(str(n))
	return v if v is Dictionary else {}


## 本档 34 层鸿钧打过了
static func hongjun_beaten(s: XState) -> bool:
	return bool(progress(s).get("hongjun", false))


## 本档 36 层打完了（本线骑士倒下）
static func top_cleared(s: XState) -> bool:
	return bool(progress(s).get("cleared", false))


## 各线的 35、36 层：线模块要有 run_shadow(host, s)、run_final(host, s)（返回战斗结果，0 胜，-1 没打）；
## 新线做好后在这里和 _run_line 的 match 里各加一行
static func line_module(key: String):
	match key:
		XTianqiWarLine.KEY:
			return XTianqiWarLine if XTianqiWarLine.ENABLED else null
		XTianqiFamineLine.KEY:
			return XTianqiFamineLine if XTianqiFamineLine.ENABLED else null
	return null


# ---- 等级上限（天启篇：30 层 75、33 层 80、35 层后 81） ----

## 天启篇存档（不看选没选线）、发行构建里天启篇已开放
static func level_cap_on(s: XState) -> bool:
	return ENABLED and s != null and XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


## 本档现在能开到的最高等级（按已通关的层：变量 20 − 1）
static func level_cap(s: XState) -> int:
	var lc: Dictionary = data().get("level_cap", {})
	var cap := int(lc.get("base", 75))
	var cleared := int(s.variable(FLOOR_VAR)) - 1
	for st in lc.get("steps", []):
		if cleared >= int(st.after_floor):
			cap = maxi(cap, int(st.cap))
	return cap


## 插件指令 maxlevel equal N（各层守层者打完）：天启篇里 N 超过 base 的截到 level_cap；原版档、29 层及以下照原样
static func clamp_max_level(s: XState, n: int) -> int:
	if not level_cap_on(s) or n <= int(data().get("level_cap", {}).get("base", 75)):
		return n
	return mini(n, level_cap(s))


# ---- 台词 ----

static func scene(key: String) -> Array:
	var v = data().get("scenes", {}).get(key)
	return v if v is Array else []


static func say(host, key: String) -> void:
	for row in scene(key):
		await host.show_text("", 0, [XTianqiWarLine.line_text(row)])


# ---- 地图场景挂钩 ----

## 地图场景要启动一个事件前：本模块接不接（门在 34 层以上、158 的决战事件、打过 34 层后的再挑战）
static func intercepts(s: XState, map_id: int, event_id: int) -> bool:
	if not allowed(s):
		return false
	if _is(map_id, event_id, "door"):
		return int(s.variable(FLOOR_VAR)) >= from_floor()
	if _is(map_id, event_id, "relic"):
		return true
	if _is(map_id, event_id, "rechallenge"):
		return not rechallenge_options(s).is_empty()
	return false


static func _is(map_id: int, event_id: int, key: String) -> bool:
	var d: Dictionary = data().get(key, {})
	return map_id == int(d.get("map", -1)) and event_id == int(d.get("event", -1))


## 接管事件；返回 false＝照原事件跑（再挑战里选了「别的事」）
static func run_event(host, s: XState, map_id: int, event_id: int) -> bool:
	if _is(map_id, event_id, "door"):
		await run_door(host, s)
		return true
	if _is(map_id, event_id, "relic"):
		return true  # 旧 34 层的决战事件（洪荒奖励／6213）挪到 36 层，这里不跑
	if _is(map_id, event_id, "rechallenge"):
		return await run_rechallenge(host, s)
	return false


## 天启篇里旧 34 层（158）不随机遇敌（31～36 层重做方案第 3 节）
static func no_encounter(s: XState, map_id: int) -> bool:
	return allowed(s) and map_id == int(floor_info(top()).get("map", -1))


## 地图名：正在跑 34～36 层时用新层名（借来的图原名是「决战：天外天」「33层 清净天」）
static func map_name(s: XState, map_id: int, original: String) -> String:
	if _at > 0 and allowed(s) and int(floor_info(_at).get("map", -1)) == map_id:
		return "%d层 %s" % [_at, str(floor_info(_at).get("name", ""))]
	return original


# ---- 门 ----

## 大厅的门，变量 20 ≥ 34：问去不去，去就跑这一层
static func run_door(host, s: XState) -> void:
	var n := mini(int(s.variable(FLOOR_VAR)), top())
	if n >= top() and top_cleared(s):
		await say(host, "door_top")
		return
	var head := str(scene("door")[0][1]) % n
	var i: int = await host.show_text_with_choices("", 0, [head], ["进入该层", "离开"], 1)
	if i != 0:
		return
	await run_floor(host, s, n)


## 跑一层（34～36）：换图换色、说两句、问上不上；打完（不论输赢）回大厅。返回战斗结果（0 胜，-1 没打）
static func run_floor(host, s: XState, n: int) -> int:
	var info := floor_info(n)
	if info.is_empty():
		return -1
	var p: Array = info.get("pos", [0, 0, 0])
	_at = n
	await host.transfer(int(info.map), int(p[0]), int(p[1]), int(p[2]))
	s.screen.start_tint(info.get("tone", [0, 0, 0, 0]), 0)
	await say(host, "arrive%d" % n)
	var r := -1
	var go: int = await host.show_text_with_choices("", 0, [XTianqiWarLine.line_text(scene("ask")[0])], ["挑战", "返回大厅"], 1)
	if go == 0:
		match str(info.get("boss", "")):
			"hongjun":
				r = await _run_hongjun(host, s)
			"shadow":
				r = await _run_line(host, s, "run_shadow")
				if r == 0:
					_advance(s, n)
					s.actor_max_level = maxi(s.max_level(), level_cap(s))  # 打完 35 层等级上限开到 81
					for row in scene("shadow_win"):
						await host.show_text("", 0, [XTianqiWarLine.line_text([row[0], str(row[1]).replace("%d", str(s.max_level()))])])
			"final":
				r = await _run_line(host, s, "run_final")
		if r == 0:
			_advance(s, n)
			if n == top():
				await _honghuang(host, s)
		elif r > 0:
			await say(host, "lost")
	await _home(host, s)
	return r


static func _run_hongjun(host, s: XState) -> int:
	await say(host, "hongjun_before")
	var r := await fight_hongjun(host, s)
	if r == 0:
		progress(s)["hongjun"] = true
		await say(host, "hongjun_win")
	else:
		await say(host, "hongjun_lost")
	return r


## 34 层鸿钧一战（不改进度）；再挑战也走这里
static func fight_hongjun(host, s: XState) -> int:
	prepare_hongjun(s)
	return await host.start_battle(int(data().hongjun.troop), false, true)


## 本线 35、36 层（线模块的 run_shadow／run_final）；线还没做好就说一句
static func _run_line(host, s: XState, fn: String) -> int:
	var r := -1
	match XTianqi.line_of(s) if line_module(XTianqi.line_of(s)) != null else "":
		XTianqiWarLine.KEY:
			if fn == "run_shadow":
				r = await XTianqiWarLine.run_shadow(host, s)
			else:
				r = await XTianqiWarLine.run_final(host, s)
		XTianqiFamineLine.KEY:
			if fn == "run_shadow":
				r = await XTianqiFamineLine.run_shadow(host, s)
			else:
				r = await XTianqiFamineLine.run_final(host, s)
	if r < 0:
		await say(host, "not_ready")
	return r


static func _advance(s: XState, n: int) -> void:
	if n >= top():
		progress(s)["cleared"] = true
	elif int(s.variable(FLOOR_VAR)) <= n:
		s.set_variable(FLOOR_VAR, n + 1)


static func _home(host, s: XState) -> void:
	_at = 0
	s.screen.start_tint([0, 0, 0, 0], 0)
	await host.transfer(XTianqi.HALL_MAP, XTianqi.HALL_POS.x, XTianqi.HALL_POS.y, XTianqi.HALL_POS.z)


## 洪荒通关奖励（原 158 事件 1 第 2 页）：开关 2483 开着才有；打过本档鸿钧给奖励，没打过照原版学 6213（天启篇默认不学）
static func _honghuang(host, s: XState) -> void:
	var h: Dictionary = data().get("honghuang", {})
	if not s.switch(int(h.switch)) or bool(progress(s).get("honghuang", false)):
		return
	if hongjun_beaten(s):
		var i: int = await host.show_text_with_choices("", 0, [str(scene("honghuang_ask")[0][1])], ["是", "否"], 1)
		if i == 0:
			await say(host, "honghuang_done")
			s.set_variable(int(h.variable), 1)
			progress(s)["honghuang"] = true
		return
	await say(host, "honghuang_skip")
	if not XTianqi.NO_HEAVEN_GAZE:
		for a in s.members():
			a.learn_skill(int(h.skill))


# ---- 再挑战（大厅 EV062） ----

## 打过的 34～36 层守层者（层号）
static func rechallenge_options(s: XState) -> Array:
	var out := []
	if not allowed(s):
		return out
	if hongjun_beaten(s):
		out.append(34)
	if int(s.variable(FLOOR_VAR)) >= 36 and line_module(XTianqi.line_of(s)) != null:
		out.append(35)
	if top_cleared(s) and line_module(XTianqi.line_of(s)) != null:
		out.append(36)
	return out


## 只打，不改层数、不记通关、不给洪荒奖励；骑士的掉落（异化核）等奖励做好后再接（设计稿第 7 节草案）
static func run_rechallenge(host, s: XState) -> bool:
	var opts := rechallenge_options(s)
	var labels := opts.map(func(n): return _rechallenge_label(s, int(n)))
	labels.append("别的事")
	labels.append("离开")
	var i: int = await host.show_text_with_choices("", 0, [XTianqiWarLine.line_text(scene("rechallenge_head")[0])], labels, labels.size() - 1)
	if i == opts.size():
		return false
	if i < 0 or i > opts.size():
		return true
	var n := int(opts[i])
	var line := XTianqi.line_of(s)
	match n:
		34:
			await fight_hongjun(host, s)
		35:
			if XTianqiHorsemen.prepare(line, s, "shadow"):
				await host.start_battle(int(data().shell_troop), false, true)
			else:
				await say(host, "not_ready")
		36:
			if XTianqiHorsemen.prepare(line, s, "body"):
				await host.start_battle(int(data().shell_troop), false, true)
			else:
				await say(host, "not_ready")
	return true


static func _rechallenge_label(s: XState, n: int) -> String:
	match n:
		34:
			return "挑战34层守层者 鸿钧"
		35:
			return "挑战35层 天启的影子"
	return "挑战36层 %s骑士" % str(XTianqi.line_info(XTianqi.line_of(s)).get("name", ""))


# ---- 34 层鸿钧（BattleLogic.setup 挂钩） ----

static func prepare_hongjun(s: XState = null) -> bool:
	_pending = "hongjun" if allowed(s) else ""
	return _pending != ""


static func pending() -> String:
	return _pending


## BattleLogic.setup：敌群成员建完后调。prepare 过就把鸿蒙老祖那只换成鸿钧（名字、能力值 × rate；外观、行动、难度倍率、霸体照旧）
static func setup(logic, s: XState) -> void:
	var key := _pending
	_pending = ""
	if key != "hongjun" or not allowed(s):
		return
	var h: Dictionary = data().get("hongjun", {})
	var rate: Array = h.get("rate", [])
	for e in logic.enemies:
		if int(e.enemy_id) != int(h.enemy) or not e.horseman.is_empty():
			continue
		var rec: Dictionary = XDB.rec("Enemies", int(h.enemy)).duplicate(true)
		var p: Array = rec.get("params", [1, 1, 1, 1, 1, 1, 1, 1]).duplicate()
		for i in mini(p.size(), rate.size()):
			p[i] = roundf(float(p[i]) * float(rate[i]))
		rec.params = p
		rec.name = str(h.name)
		rec.dropItems = []  # 鸿蒙老祖的奖碑等不跟着借（34 层的掉落等奖励车道按设计稿第 6 节给终焉词条）
		e.horseman = {"rec": rec, "knight": false}  # 借骑士战的合成记录口子：XEnemy.data() 读它；_rates（难度倍率）不动
		e.refresh_passive()
		e.recover_all()
