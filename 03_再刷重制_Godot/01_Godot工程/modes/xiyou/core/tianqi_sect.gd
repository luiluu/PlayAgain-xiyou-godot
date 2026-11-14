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

## ==== 包乙：小小鱼破枷锁 ====
## - 15／20／25 层原来破枷锁的人（Map032 EV007、Map116 EV006、Map147 EV004）和大厅讲抽奖被动上限的人（Map004 EV003）不出。
## - 改由小小鱼在本线三个节点之后各松一重：15 层「原身的回声」（beats 的 echo15，XTianqiLine.run_arrival 末尾）、
##   20 层第二使徒打赢之后（XMapScene.start_battle 末尾，认本线 apostle20 预设的敌群）、25 层「传闻」（rumor25）。四线共用。
## - 每重：全队抽奖被动上限（变量 9）+1，全体角色学「挣脱枷锁·一重／二重／三重」（技能 6178～6180，原版公共事件 1324～1326 的做法）；
##   发过的记在 flags.tianqi.fetters（[1, 2, 3] 里发过的重数），读档不重复发。
## - 三个被动在天启篇改写（XDB.rec 挂点）：去掉伤害结果乘区（开战状态 1001～1003）和全属性，说明只留「抽奖被动上限+1」。
## - 抽奖被动上限的说明改由小小鱼在开局说一句；开局值仍按五档（5／5／10／17／22），三重全破后 8／8／13／20／25。
static var YI := true

const YI_HIDDEN := {4: [3], 32: [7], 116: [6], 147: [4]}
const YI_SKILLS := [6178, 6179, 6180]
const YI_CAP_VAR := 9
## 楼层节点 → 第几重
const YI_BEATS := {"echo15": 1, "rumor25": 3}
const YI_APOSTLE := "apostle20"
const YI_APOSTLE_TIER := 2
const YI_NAMES := ["一重", "二重", "三重"]
const YI_LINES := [
	"这条规矩……我改一下，就一下。",
	"又碰上它了。再松一格，你别声张。",
	"再改就要被发现了。最后一次。",
]
const YI_OPENING_LINE := "抽奖学来的被动，每个人能学几个是有上限的。往上走的路上，这条规矩我找机会替你松一松。"

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
	if YI and YI_HIDDEN.has(map_id) and (YI_HIDDEN[map_id] as Array).has(event_id) and on(XState.current):
		return true
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
	if YI:
		c.append({"code": 101, "indent": 0, "parameters": ["", 0, 0, 2, ""]})
		c.append({"code": 401, "indent": 0, "parameters": ["\\n<%s>%s" % [XTianqi.GUIDE_NAME, YI_OPENING_LINE]]})
	# ---- 槽位：丙 ----

	# ---- 槽位：丁一 ----

	# ---- 槽位：己 ----

	# ---- 槽位：庚 ----

	# ---- 槽位：辛 ----

	# ---- 槽位：壬 ----
	return c


# ==== 包乙：小小鱼破枷锁 ====

## 发过的重数（1～3；存档读回来是浮点，统一成整数）
static func fetters_given(s) -> Array:
	if s == null or not s.flags.get("tianqi") is Dictionary:
		return []
	var v = s.flags.tianqi.get("fetters")
	return (v as Array).map(func(x): return int(x)) if v is Array else []


## 松第 tier 重（1～3）：变量 9 +1、全体角色学对应被动、记进存档；已发过或不该发返回 false
static func grant_fetter(s, tier: int) -> bool:
	if not YI or not on(s) or tier < 1 or tier > YI_SKILLS.size():
		return false
	var given := fetters_given(s)
	if given.has(tier):
		return false
	given.append(tier)
	s.flags.tianqi["fetters"] = given
	s.set_variable(YI_CAP_VAR, int(s.variable(YI_CAP_VAR)) + 1)
	var sid := int(YI_SKILLS[tier - 1])
	for rec in XDB.table("Actors"):  # 原版公共事件 1324～1326：for $dataActors → learnSkill
		if rec == null or str(rec.get("name", "")) == "":
			continue
		var a: XActor = s.actor(int(rec.id))
		if not a.skill_ids.has(sid):
			a.learn_skill(sid)
			a.refresh_passive()
	return true


## 小小鱼说一句、松一重（台词三句四线共用）
static func run_fetter(host, s, tier: int) -> void:
	if not grant_fetter(s, tier):
		return
	if host == null or not host.has_method("show_text"):
		return
	await host.show_text("", 0, [XTianqiLine.line_text([XTianqi.GUIDE_NAME, YI_LINES[tier - 1]])])
	await host.show_text("", 0, ["\\c[2]挣脱枷锁·%s\\c[0]　全队抽奖被动上限+1（现在%d）。" % [YI_NAMES[tier - 1], int(s.variable(YI_CAP_VAR))]])


## XTianqiLine.run_arrival 末尾：本线楼层节点（echo15／rumor25）演完
static func after_beat(host, s, beat: String) -> void:
	if YI and YI_BEATS.has(beat):
		await run_fetter(host, s, int(YI_BEATS[beat]))


## 这一场是不是本线 20 层的使徒（开场打完之后才算）
static func is_apostle20(s, troop_id: int) -> bool:
	var key := XTianqiLine.current(s) if s != null else ""
	if key == "" or not XTianqiLine.opening_done(key, s):
		return false
	return int(XTianqiLine.alien_preset(key, YI_APOSTLE).get("troop", 0)) == troop_id


## XMapScene.start_battle 末尾（不是随机遇敌）：20 层使徒打赢之后
static func after_map_battle(host, s, troop_id: int, result: int) -> void:
	if YI and result == 0 and on(s) and is_apostle20(s, troop_id):
		await run_fetter(host, s, YI_APOSTLE_TIER)


## XDB.rec 的快路径：要改写的技能
static func touches_skill(id: int) -> bool:
	return YI and id >= int(YI_SKILLS[0]) and id <= int(YI_SKILLS[-1])


static var _skill_recs: Dictionary = {}


## 挣脱枷锁三个被动：去掉全属性（passivePBST）、伤害结果乘区（开战状态 StartPushState1001～1003）和对应的两行说明
static func skill_rec(id: int, base: Dictionary) -> Dictionary:
	if base.is_empty() or not touches_skill(id) or not on(XState.current):
		return base
	var hit = _skill_recs.get(id)
	if hit is Array and is_same(hit[0], base):
		return hit[1]
	var r: Dictionary = base.duplicate(true)
	var keep := []
	for line in str(r.get("note", "")).split("\n"):
		if line.begins_with("<passivePBST") or line.begins_with("<StartPushState") or line.contains("伤害结果") or line.contains("全属性"):
			continue
		keep.append(line)
	r.note = "\n".join(keep)
	r.meta = XTianqiSkills.parse_meta(r.note)
	_skill_recs[id] = [base, r]
	return r
