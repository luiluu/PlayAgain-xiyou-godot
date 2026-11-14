class_name XTianqiSect
extends RefCounted
## 【cc·天启篇·未经审查】天启篇教派连带内容重做（私密仓 重制设定/天启篇_教派连带内容重做方案_v0.2.md，Kyo 2026-11-14 拍板）。
## 本模块是各实现包共用的骨架：事件隐藏、页条件改写、拦截、货架改写、掉落改写、开局补发都收在这里。
## 只认天启篇存档（XTianqi.active），原版档不变；不改 generated 原数据，全是运行时拦截；名字台词不带教派字样。
##
## ## 骨架接口（后面每个包照这个加，别另起一套）
## 每个包在本文件里各占一段（下面「==== 乙 ====」这类标题）：段里放本包的常量与函数，开关一个 `static var <包名> := true`。
## 公共入口函数里每个包留了一个槽位（槽位之间隔着注释行，并行加行不冲突）：
## - hides(map_id, event_id)            整件事件不出（挂点 MVEvent._find_page，和 XTianqiTrim.hides 并列）
## - page_blocked(s, cond)              某一页的出现条件改写（挂点 MVEvent._meets）：返回 true＝这一页当不满足
## - intercepts(s, map_id, event_id)    要接管的事件 → run_event(host, s, map_id, event_id)（挂点 XMapScene.run_event 一处）
## - shop_goods(s, map_id, event_id, goods)  指令 302 的货单改写（挂点 MVInterpreter 302）
## - drop_rows(s, enemy_id, rows)       掉落行改写（挂点 XBattleLogic.drop_chances 末尾）；行可带 count（一次掉几个）
## - opening_commands()                开局补发的事件指令（挂点 XTianqi.opening_commands；开局一定是天启篇，不看状态）
##
## 回退开关（O 号由总装合并时编）：JIA（包甲）；乙、丙、丁一、己、庚、辛、壬 各一个，建段时再加。
##
## ==== 包甲：清理与骨架（本段）====
## - 大厅两位使者（Map004 EV016、EV035）不出。EV016 原来的实际用处是白送「控制器:副本协会」1340 和「指路灯:牛马关」386，
##   这两件改在开局直接给；EV035 只是上限说明牌，天启篇没有对应内容，下架。
## - 教派页全不出：开关 2301／2302／2303／2307／2282／2465 任一个当出现条件的页，在天启篇里一律当不满足
##   （六大试炼 Map005 EV002 等六处、终末之间入口 Map146 EV003、魔塔外围送真材料 Map195 EV008 第 3、5 页都靠它拦住）。
## - 天道研究日志 1960 不出现在任何货单和掉落里；夏娜心魔（敌人 2026）那一行换成人道意志碎片 2530 × 10。

static var JIA := true

const HALL_MAP := 4
## 包甲：大厅两位使者
const JIA_HIDDEN := {4: [16, 35]}
## 开局白送：控制器:副本协会、指路灯:牛马关（原 EV016 的第 2 页）
const JIA_OPENING_ITEMS := [1340, 386]
## 教派、随机、轮回开关（附表）
const JIA_SWITCHES := [2301, 2302, 2303, 2307, 2282, 2465]
## 天道研究日志 → 人道意志碎片
const JOURNAL := 1960
const SHARD := 2530
const SHARD_COUNT := 10


static func on(s) -> bool:
	return s != null and XTianqi.active(s)


# ---- 事件隐藏 ----

## MVEvent._find_page：天启篇整件不出的事件
static func hides(map_id: int, event_id: int) -> bool:
	if JIA and JIA_HIDDEN.has(map_id) and (JIA_HIDDEN[map_id] as Array).has(event_id) and on(XState.current):
		return true
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return false


# ---- 页条件改写 ----

## MVEvent._meets：true＝这一页当不满足。cond 是页的 conditions 字典
static func page_blocked(s, cond: Dictionary) -> bool:
	if JIA and (bool(cond.get("switch1Valid", false)) or bool(cond.get("switch2Valid", false))) and on(s):
		if (bool(cond.switch1Valid) and JIA_SWITCHES.has(int(cond.switch1Id))) or (bool(cond.switch2Valid) and JIA_SWITCHES.has(int(cond.switch2Id))):
			return true
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return false


# ---- 事件拦截 ----

## 要接管的事件（包甲没有）。各包加一行 `or _intercepts_x(...)`，并在 run_event 里加对应分支
static func intercepts(s, map_id: int, event_id: int) -> bool:
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----
	if GENG and _geng_intercepts(s, map_id, event_id):
		return true

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return false


## XMapScene.run_event 接管后调用（host 是地图场景）；各包在 match 里加自己的分支
static func run_event(host, s, map_id: int, event_id: int) -> void:
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----
	if GENG and _geng_intercepts(s, map_id, event_id):
		await _geng_run_event(host, s, map_id, event_id)
		return

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return


# ---- 货架改写 ----

## 指令 302 的货单：[[类型, 编号, 价格类型, 价格, 是否用积分?], …]（类型 0 物品、1 武器、2 防具）
static func shop_goods(s, map_id: int, event_id: int, goods: Array) -> Array:
	var out := goods
	if JIA and on(s):
		out = out.filter(func(g): return not (int(g[0]) == 0 and int(g[1]) == JOURNAL))  # 天道研究日志下架
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return out


# ---- 掉落改写 ----

## XBattleLogic.drop_chances 末尾：rows 是 [{kind, id, chance, extra, sig?, count?}]；返回改写后的行
static func drop_rows(s, enemy_id: int, rows: Array) -> Array:
	var out := rows
	if JIA and on(s):
		out = []
		for r in rows:
			if int(r.kind) == 1 and int(r.id) == JOURNAL:
				if enemy_id == 2026:  # 夏娜心魔：换成人道意志碎片
					var row: Dictionary = (r as Dictionary).duplicate()
					row.id = SHARD
					row["count"] = SHARD_COUNT
					out.append(row)
				continue  # 其余敌人（天道研究员）里的研究日志直接去掉
			out.append(r)
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return out


# ---- 开局补发 ----

## 追加到 XTianqi.opening_commands 的事件指令（开局指令格式）
static func opening_commands() -> Array:
	var c := []
	if JIA:
		for id in JIA_OPENING_ITEMS:
			c.append({"code": 126, "indent": 0, "parameters": [int(id), 0, 0, 1]})
		c.append({"code": 101, "indent": 0, "parameters": ["", 0, 0, 2, ""]})
		c.append({"code": 401, "indent": 0, "parameters": ["\\n<%s>先收好这两样：一个是去副本协会的传送阵控制器，一个是牛马关的指路灯。塔里的事，多问问身边的人。" % XTianqi.GUIDE_NAME]})
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return c


## ==== 包庚：传承与武运（O-待定）====
## - 魔塔外围五位传承 NPC（Map195 EV016～020）：天启篇默认开放（按原 sw1:2303 线，轮回页不选），台词「他必须不被两派所束缚」改写。
## - 15／20／25 层传承人（Map032 EV008、Map116 EV007、Map147 EV005）：默认开放，第 2 页关闭条件放宽到变量 20 >= 31（30 层前都能补），提示台词改写。
## - 城隍庙（Map189 EV021）：未领过武运时照随机页（第 2 页）走，去掉「随机模式下」字样及「忘掉强者压制 6216、学强者压制·削弱 6241」两步；领过后照第 4 页走。

static var GENG := true

const GENG_OUTSKIRTS := {195: [16, 17, 18, 19, 20]}
const GENG_INHERITORS := {32: 8, 116: 7, 147: 5}
const GENG_CHENGHUANG_MAP := 189
const GENG_CHENGHUANG_EV := 21
const GENG_FLOOR_VAR := 20
const GENG_CLOSE_FLOOR := 31
const GENG_STRIP_SKILLS := [6216, 6241]


static func _geng_is_target(map_id: int, event_id: int) -> bool:
	if GENG_OUTSKIRTS.has(map_id) and (GENG_OUTSKIRTS[map_id] as Array).has(event_id):
		return true
	if GENG_INHERITORS.get(map_id, -1) == event_id:
		return true
	return map_id == GENG_CHENGHUANG_MAP and event_id == GENG_CHENGHUANG_EV


static func _geng_intercepts(s, map_id: int, event_id: int) -> bool:
	if not on(s) or not _geng_is_target(map_id, event_id):
		return false
	if map_id == GENG_CHENGHUANG_MAP and event_id == GENG_CHENGHUANG_EV:
		return not s.self_switch(map_id, event_id, "A")
	return true


## MVEvent.refresh 挂点：为包庚接管的事件提供改写后的页，不改变 MVEvent._find_page() 对教派开关页的拦截
static func page_override(s, map_id: int, event_id: int, pages: Array) -> Dictionary:
	if not GENG or not on(s) or not _geng_is_target(map_id, event_id):
		return {}
	if map_id == GENG_CHENGHUANG_MAP and event_id == GENG_CHENGHUANG_EV:
		if s.self_switch(map_id, event_id, "A") or pages.size() < 2:
			return {}
		return {"index": 101, "page": _geng_rewrite_chenghuang_page(pages[1])}
	if GENG_INHERITORS.get(map_id, -1) == event_id:
		if pages.size() >= 2 and s.variable(GENG_FLOOR_VAR) >= GENG_CLOSE_FLOOR:
			return {"index": 101, "page": pages[1]}
		if pages.size() >= 1:
			return {"index": 100, "page": _geng_rewrite_inheritor_page(pages[0])}
		return {}
	# 魔塔外围五位传承 NPC：只在 sw1:2303 线（pages[0..3] 中满足 switch1Id == 2303 的页）里从高到低匹配，忽略 sw1:2303 本身
	for i in range(pages.size() - 1, -1, -1):
		var p: Dictionary = pages[i]
		var c: Dictionary = p.get("conditions", {})
		if not bool(c.get("switch1Valid", false)) or int(c.get("switch1Id", 0)) != 2303:
			continue
		if _geng_meets_except_sw1(s, map_id, event_id, c):
			return {"index": 100 + i, "page": _geng_rewrite_outskirts_page(p)}
	return {}


static func _geng_meets_except_sw1(s, map_id: int, event_id: int, c: Dictionary) -> bool:
	if bool(c.get("switch2Valid", false)) and not s.switch(int(c.switch2Id)):
		return false
	if bool(c.get("variableValid", false)) and s.variable(int(c.variableId)) < float(c.variableValue):
		return false
	if bool(c.get("selfSwitchValid", false)) and not s.self_switch(map_id, event_id, str(c.selfSwitchCh)):
		return false
	if bool(c.get("itemValid", false)) and s.item_count(int(c.itemId)) <= 0:
		return false
	if bool(c.get("actorValid", false)) and not s.party.has(int(c.actorId)):
		return false
	return true


static func _geng_rewrite_outskirts_page(page: Dictionary) -> Dictionary:
	var p := page.duplicate(true)
	var out := []
	for cmd in p.get("list", []):
		var d: Dictionary = (cmd as Dictionary).duplicate(true)
		if int(d.get("code", 0)) == 401:
			var params: Array = d.get("parameters", [])
			if params.size() > 0:
				params[0] = str(params[0]).replace("他必须不被两派所束缚，", "他必须不被世俗所束缚，")
				d["parameters"] = params
		out.append(d)
	p["list"] = out
	return p


static func _geng_rewrite_inheritor_page(page: Dictionary) -> Dictionary:
	var p := page.duplicate(true)
	var out := []
	for cmd in p.get("list", []):
		var d: Dictionary = (cmd as Dictionary).duplicate(true)
		if int(d.get("code", 0)) == 401:
			var params: Array = d.get("parameters", [])
			if params.size() > 0:
				params[0] = str(params[0]).replace(
					"除此之外，一旦通过该层守护者，传承自动关闭，你无法重新获得",
					"踏上第 31 层前都可回来补领传承，登上 31 层后自动关闭"
				)
				d["parameters"] = params
		out.append(d)
	p["list"] = out
	return p


static func _geng_rewrite_chenghuang_page(page: Dictionary) -> Dictionary:
	var p := page.duplicate(true)
	var out := []
	for cmd in p.get("list", []):
		var code := int(cmd.get("code", 0))
		var params: Array = cmd.get("parameters", [])
		if code == 318 and params.size() >= 4 and GENG_STRIP_SKILLS.has(int(params[3])):
			continue  # 天启篇无损学先天武运：去掉「忘掉强者压制 6216、学强者压制·削弱 6241」
		var d: Dictionary = (cmd as Dictionary).duplicate(true)
		if code == 102 and params.size() > 0 and params[0] is Array:
			var choices: Array = (params[0] as Array).duplicate()
			for idx in choices.size():
				choices[idx] = str(choices[idx]).replace("随机模式下，", "")
			params = params.duplicate()
			params[0] = choices
			d["parameters"] = params
		elif code == 402 and params.size() >= 2:
			params = params.duplicate()
			params[1] = str(params[1]).replace("随机模式下，", "")
			d["parameters"] = params
		out.append(d)
	p["list"] = out
	return p


static func _geng_run_event(host, s, map_id: int, event_id: int) -> void:
	for ev in XDB.map(map_id).get("events", []):
		if ev != null and int(ev.id) == event_id:
			var ov := page_override(s, map_id, event_id, ev.get("pages", []))
			if ov.is_empty():
				return
			var cmds: Array = ov.page.get("list", [])
			if cmds.is_empty():
				return
			var interp := MVInterpreter.new(host, map_id, event_id, cmds)
			await interp.run()
			return
