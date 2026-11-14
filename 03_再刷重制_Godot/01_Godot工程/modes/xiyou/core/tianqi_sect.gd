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
static func intercepts(_s, _map_id: int, _event_id: int) -> bool:
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return false


## XMapScene.run_event 接管后调用（host 是地图场景）；各包在 match 里加自己的分支
static func run_event(_host, _s, _map_id: int, _event_id: int) -> void:
	# ---- 槽位：乙 ----

	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

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


# ==== 包壬：入队等级同步 ====
## 通关抽到的新角色入队时，等级同步成「当前上场队员（上场 4 人＋助力位）的平均等级（四舍五入）」，不超过本层等级上限（XState.max_level，
## 各层守层者打完才抬）；经验同步到该级。只管 XTianqi.take_draw 的通关抽角色，开局阵容不动；只升不降。回退开关 REN（O-待定）。
static var REN := true


## 入队前算：上场队员平均等级（四舍五入）；没人上场（空队）返回 0
static func ren_target(s: XState) -> int:
	var total := 0
	var n := 0
	for a in s.battle_members():
		total += a._level()
		n += 1
	var h: XActor = s.helper()
	if h != null:
		total += h._level()
		n += 1
	if n == 0:
		return 0
	return mini((total * 2 + n) / (n * 2), s.max_level())


## XTianqi.take_draw 入队后调：把新角色同步到 target（入队前算的平均）；返回同步后的等级，没动返回 0
static func ren_sync(s: XState, id: int, target: int) -> int:
	if not REN or not on(s) or target <= 0 or not s.party.has(id):
		return 0
	var a: XActor = s.actor(id)
	if a._level() >= target:
		return 0
	a.change_level_mv(target)
	return a._level()

