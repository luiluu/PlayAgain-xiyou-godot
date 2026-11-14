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
## 回退开关（O 号由总装合并时编）：JIA（包甲）；BING（包丙，O-445）；乙、丁一、己、庚、辛、壬 各一个，建段时再加。
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


# ==== 包丙：老钱小钱（O-445）====
## - 大厅放贷人 Map004 EV038、EV039 换成老钱、小钱（各借各的，变量 850／849 不动）；教派禁借页已被包甲拦住。
## - 18 层讨债战（Map046 EV001 判 850／849）：敌群 747、766 换成老钱／小钱各带两个打手，台词改写。
## - 物品 1958 → 老钱的账本、1961 → 小钱的账本；贪财商人 Map192 EV006 加「收账本」换止戈（1959）／天怒（1962）各一次，台词改写。
## - 水栽培 Map187 EV105、EV106 在天启篇不出。
static var BING := true

const BING_HIDDEN := {187: [105, 106]}
const BING_LOAN_AMOUNT := 1800
const BING_REPAY_AMOUNT := 2400
const BING_POINT_VAR := 206
const BING_TOP_FLOOR_VAR := 20
const BING_GATE_VAR := 14
const BING_LAO_VAR := 850
const BING_XIAO_VAR := 849
const BING_LAO_LEDGER := 1958
const BING_XIAO_LEDGER := 1961
const BING_ZHIGE_BOOK := 1959
const BING_TIANNU_BOOK := 1962
const BING_LAO_ENEMY := 871
const BING_XIAO_ENEMY := 892
const BING_LAO_THUG := 9038
const BING_XIAO_THUG := 9039
const BING_LAO_TROOP := 747
const BING_XIAO_TROOP := 766
const BING_GREEDY_SHOP_ITEMS := [2452, 2453, 2454, 2455, 2456, 1920, 1953, 1954, 1955, 1062, 1063, 1064, 1065, 1066, 1067, 1069]


static func _bing_on(s) -> bool:
	return BING and on(s)


static func _bing_flag(s) -> Dictionary:
	var tq: Dictionary = s.flags.tianqi
	if not (tq.get("sect_bing") is Dictionary):
		tq["sect_bing"] = {}
	return tq.sect_bing


static func _bing_loan_meta(event_id: int) -> Dictionary:
	if event_id == 38:
		return {
			"event_id": 38,
			"name": "老钱",
			"face": "People1",
			"face_index": 6,
			"var_id": BING_LAO_VAR,
			"intro": "\\n<老钱>嘿嘿，天平那摊子忙不过来，我在这儿顺手放点小贷。你要是缺用，可以找我借1800肝帝积分，不过一定要在18层过关前还我2400肝帝积分！",
			"no_courage": "\\n<老钱>连胆气都没有，这种买卖可做不成，算了。",
			"repaid_ok": "\\n<老钱>不错不错，你果然是言而有信之人！",
			"short_money": "\\n<老钱>钱都不够，还想糊弄我？",
			"remind": "\\n<老钱>记得赶紧把钱还了！别拖延，不然有你好瞧的！",
			"done_talk": "\\n<老钱>做买卖讲究一个和气生财，有空常来光顾。",
		}
	return {
		"event_id": 39,
		"name": "小钱",
		"face": "People1",
		"face_index": 2,
		"var_id": BING_XIAO_VAR,
		"intro": "\\n<小钱>攀登这座塔也太难了，不如跟老爷子一块儿放点贷款赚外快。我这里有些肝帝积分，你要是需要，可以找我借1800肝帝积分，不过一定要在18层过关前还我2400肝帝积分！",
		"no_courage": "\\n<小钱>你还是没有那份胆量，这单生意不做了。",
		"repaid_ok": "\\n<小钱>有借有还，再借不难！",
		"short_money": "\\n<小钱>这些钱不够啊，你可别糊弄我！",
		"remind": "\\n<小钱>记得还钱，不然我可是要动真格了！",
		"done_talk": "\\n<小钱>有什么事吗？",
	}


## 包丙纯逻辑：借贷状态查询 / 借钱 / 还钱（供对话与测试共用）
static func bing_borrow(s, event_id: int) -> Dictionary:
	if not _bing_on(s) or not (event_id in [38, 39]):
		return {"ok": false}
	var m := _bing_loan_meta(event_id)
	if int(s.variable(BING_GATE_VAR)) == 0:
		s.set_self_switch(HALL_MAP, event_id, "A", true)
		return {"ok": false, "reason": "gate"}
	if int(s.variable(BING_TOP_FLOOR_VAR)) >= 19:
		s.set_self_switch(HALL_MAP, event_id, "C", true)
		return {"ok": false, "reason": "floor"}
	s.set_variable(BING_POINT_VAR, int(s.variable(BING_POINT_VAR)) + BING_LOAN_AMOUNT)
	s.set_variable(int(m.var_id), 1)
	s.set_self_switch(HALL_MAP, event_id, "B", true)
	return {"ok": true, "amount": BING_LOAN_AMOUNT}


static func bing_repay(s, event_id: int) -> Dictionary:
	if not _bing_on(s) or not (event_id in [38, 39]):
		return {"ok": false}
	var m := _bing_loan_meta(event_id)
	if int(s.variable(BING_TOP_FLOOR_VAR)) >= 19:
		s.set_self_switch(HALL_MAP, event_id, "C", true)
		return {"ok": false, "reason": "floor"}
	var pts := int(s.variable(BING_POINT_VAR))
	if pts < BING_REPAY_AMOUNT:
		return {"ok": false, "reason": "short"}
	s.set_variable(BING_POINT_VAR, pts - BING_REPAY_AMOUNT)
	s.set_variable(int(m.var_id), 0)
	s.set_self_switch(HALL_MAP, event_id, "C", true)
	return {"ok": true, "amount": BING_REPAY_AMOUNT}


## 包丙纯逻辑：贪财商人收账本兑换（who = "lao" | "xiao"）
static func bing_can_exchange(s, who: String) -> bool:
	if not _bing_on(s):
		return false
	var fl := _bing_flag(s)
	if who == "lao":
		return not bool(fl.get("zhige", false)) and s.item_count(BING_LAO_LEDGER) > 0
	if who == "xiao":
		return not bool(fl.get("tiannu", false)) and s.item_count(BING_XIAO_LEDGER) > 0
	return false


static func bing_exchange_ledger(s, who: String) -> Dictionary:
	if not bing_can_exchange(s, who):
		return {"ok": false}
	var fl := _bing_flag(s)
	if who == "lao":
		s.gain_item(BING_LAO_LEDGER, -1)
		s.gain_item(BING_ZHIGE_BOOK, 1)
		fl["zhige"] = true
		return {"ok": true, "lost": BING_LAO_LEDGER, "gained": BING_ZHIGE_BOOK, "label": "被动书:止戈"}
	s.gain_item(BING_XIAO_LEDGER, -1)
	s.gain_item(BING_TIANNU_BOOK, 1)
	fl["tiannu"] = true
	return {"ok": true, "lost": BING_XIAO_LEDGER, "gained": BING_TIANNU_BOOK, "label": "被动书:天怒"}


static func _bing_run_loan(host, s, event_id: int) -> void:
	var m := _bing_loan_meta(event_id)
	var face: String = m.face
	var fidx: int = int(m.face_index)
	if s.self_switch(HALL_MAP, event_id, "C"):
		await host.show_text(face, fidx, [m.done_talk])
		return
	if s.self_switch(HALL_MAP, event_id, "A"):
		await host.show_text(face, fidx, [m.no_courage])
		return
	if s.self_switch(HALL_MAP, event_id, "B"):
		if int(s.variable(BING_TOP_FLOOR_VAR)) >= 19:
			s.set_self_switch(HALL_MAP, event_id, "C", true)
			await host.show_text(face, fidx, [m.done_talk])
			return
		var ch: int = await host.show_text_with_choices(face, fidx, ["\\n<%s>欠债还钱，天经地义！" % m.name], ["还钱", "先不还钱"], 1)
		if ch == 0:
			var res := bing_repay(s, event_id)
			if bool(res.get("ok", false)):
				XToast.show_text("你失去了2400肝帝积分！")
				await host.show_text(face, fidx, [m.repaid_ok])
			elif str(res.get("reason", "")) == "floor":
				await host.show_text(face, fidx, [m.done_talk])
			else:
				await host.show_text(face, fidx, [m.short_money])
		else:
			await host.show_text(face, fidx, [m.remind])
		return
	# 默认第一页
	if int(s.variable(BING_GATE_VAR)) == 0:
		s.set_self_switch(HALL_MAP, event_id, "A", true)
		await host.show_text(face, fidx, [m.no_courage])
		return
	if int(s.variable(BING_TOP_FLOOR_VAR)) >= 19:
		s.set_self_switch(HALL_MAP, event_id, "C", true)
		await host.show_text(face, fidx, [m.done_talk])
		return
	var pick: int = await host.show_text_with_choices(face, fidx, [m.intro], ["借钱", "感到怀疑，离开"], -1)
	if pick == 0:
		var res := bing_borrow(s, event_id)
		if bool(res.get("ok", false)):
			XToast.show_text("你获得了1800肝帝积分！")


static func _bing_run_greedy_merchant(host, s) -> void:
	if int(s.variable(BING_GATE_VAR)) != 1:
		await host.show_text("People14", 2, ["\\n<贪财的商人>额……看起来你好像没什么钱的样子……"])
		return
	var ch: int = await host.show_text_with_choices(
		"People14", 2,
		["\\n<贪财的商人>管他谁是谁的账，我根本不在乎好吧，赚钱才是最重要的！"],
		["购买物品", "收账本", "离开"], 2
	)
	if ch == 0:
		var goods := []
		for gid in BING_GREEDY_SHOP_ITEMS:
			goods.append([0, int(gid), 0, 0, false])
		if XTianqi.active(s) and XTianqi.NO_RECRUIT:
			goods = goods.filter(func(g): return int(g[0]) != 0 or not XTianqi.horn_blocked(s, XDB.rec("Items", int(g[1]))))
		goods = XTianqiTrim.shop_goods(s, 192, 6, goods)
		goods = shop_goods(s, 192, 6, goods)
		goods = XTianqiTrumpet.shop_goods(s, goods)
		XShopStock.set_context(192, 6)
		await host.open_shop(goods, false)
		XShopStock.shop_context = {}
	elif ch == 1:
		var can_lao := bing_can_exchange(s, "lao")
		var can_xiao := bing_can_exchange(s, "xiao")
		if not can_lao and not can_xiao:
			await host.show_text("People14", 2, ["\\n<贪财的商人>我只收老钱的账本和小钱的账本，各换一次。你手上没有能换的账本啊。"])
			return
		var opts := []
		var keys := []
		if can_lao:
			opts.append("用「老钱的账本」换「被动书:止戈」")
			keys.append("lao")
		if can_xiao:
			opts.append("用「小钱的账本」换「被动书:天怒」")
			keys.append("xiao")
		opts.append("取消")
		var pick: int = await host.show_text_with_choices("People14", 2, ["\\n<贪财的商人>哟，真有账本？拿来我看看，每家只收一次！"], opts, opts.size() - 1)
		if pick >= 0 and pick < keys.size():
			var res := bing_exchange_ledger(s, str(keys[pick]))
			if bool(res.get("ok", false)):
				XToast.show_text("你获得了%s！" % str(res.label))
				await host.show_text("People14", 2, ["\\n<贪财的商人>好账本配好书，痛快！"])
	else:
		await host.show_text("People14", 2, ["\\n<贪财的商人>多来光顾啊！"])


## 包丙：18 层讨债战台词改写（MVEventCore 101 调）
static func rewrite_message(s, map_id: int, event_id: int, msg: Dictionary) -> Dictionary:
	if not _bing_on(s) or map_id != 46 or event_id != 1:
		return msg
	var joined := "\n".join(msg.get("lines", []))
	if joined.contains("天道使者"):
		msg["face"] = "People1"
		msg["index"] = 6
		msg["lines"] = ["\\n<老钱>嘿嘿，你居然打过了深渊骑士！不过你欠我的积分还没还，可别想就这么走了，兄弟们上！"]
	elif joined.contains("求道者") and joined.contains("动真格"):
		msg["face"] = "People1"
		msg["index"] = 2
		msg["lines"] = ["\\n<小钱>我早就说过不还钱我会动真格的，给我上！"]
	return msg


## 包丙：数据库记录按天启篇存档动态改写（XDB.rec 调）
static func has_item(s, id: int) -> bool:
	return _bing_on(s) and (id == BING_LAO_LEDGER or id == BING_XIAO_LEDGER)


static func item_rec(id: int, base: Dictionary) -> Dictionary:
	var d := base.duplicate()
	if id == BING_LAO_LEDGER:
		d["name"] = "老钱的账本"
		d["description"] = "物品\n老钱随身带着的放贷账本，上面记着一笔笔陈年旧账，似乎贪财的商人愿意用好东西收它。"
	elif id == BING_XIAO_LEDGER:
		d["name"] = "小钱的账本"
		d["description"] = "物品\n小钱记账用的小册子，字迹工整得吓人，似乎贪财的商人愿意用好东西换它。"
	return d


static func has_enemy(s, id: int) -> bool:
	return _bing_on(s) and id in [BING_LAO_ENEMY, BING_XIAO_ENEMY, BING_LAO_THUG, BING_XIAO_THUG]


static func _bing_thug_params(base_params: Array) -> Array:
	var out := []
	for i in base_params.size():
		var v := float(base_params[i])
		if i == 0:
			out.append(int(round(v * 0.3)))
		elif i in [2, 3, 4, 5]:
			out.append(int(round(v * 0.8)))
		else:
			out.append(int(v))
	return out


static var _bing_enemy_cache: Dictionary = {}
static var _bing_enemy_table_ref: Array = []
static var _bing_troop_cache: Dictionary = {}
static var _bing_troop_base_ref: Dictionary = {}


static func enemy_rec(id: int, table: Array) -> Dictionary:
	if not is_same(_bing_enemy_table_ref, table):
		_bing_enemy_cache.clear()
		_bing_enemy_table_ref = table
	if _bing_enemy_cache.has(id):
		return _bing_enemy_cache[id]
	var out := {}
	if id == BING_LAO_ENEMY and id < table.size() and table[id] != null:
		out = (table[id] as Dictionary).duplicate(true)
		out["name"] = "老钱"
		out["note"] = "NoElite\n<EnemyNote>\n天平摊旁的放贷人老钱，欠债不还就会亲自上门讨债。\n</EnemyNote>\n<EnemyRace: 3>\n<hp: 100000000000>\n<Sideview Battler: Enemy_Mage>\n<Breathing Speed: 11>\n<Sideview No Collapse>\n<Sideview Weapon: 0, swing, 1>\n<Sideview Show Shadow>\n<Hide HP Gauge>\nEmerge Motion: 0\n<DontEsc>"
	elif id == BING_XIAO_ENEMY and id < table.size() and table[id] != null:
		out = (table[id] as Dictionary).duplicate(true)
		out["name"] = "小钱"
		out["note"] = "NoElite\n<EnemyNote>\n老钱的儿子小钱，一样放贷收账，讨债从不手软。\n</EnemyNote>\n<EnemyRace: 3>\n<hp: 90000000000>\n<Sideview Battler: Actor12_2>\n<Breathing Speed: 11>\n<Sideview No Collapse>\n<Sideview Weapon: 0, swing, 1>\n<Sideview Show Shadow>\n<Hide HP Gauge>\nEmerge Motion: 0\n<DontEsc>"
	elif id == BING_LAO_THUG and BING_LAO_ENEMY < table.size() and table[BING_LAO_ENEMY] != null:
		out = (table[BING_LAO_ENEMY] as Dictionary).duplicate(true)
		out["id"] = BING_LAO_THUG
		out["name"] = "老钱的打手"
		out["dropItems"] = []
		out["params"] = _bing_thug_params(out.get("params", []))
		out["note"] = "NoElite\n<EnemyNote>\n老钱带出来的讨债打手。\n</EnemyNote>\n<EnemyRace: 3>\n<Sideview Battler: Enemy_Mage>\n<Breathing Speed: 11>\n<Sideview No Collapse>\n<Sideview Weapon: 0, swing, 1>\n<Sideview Show Shadow>\n<Hide HP Gauge>\nEmerge Motion: 0\n<DontEsc>"
	elif id == BING_XIAO_THUG and BING_XIAO_ENEMY < table.size() and table[BING_XIAO_ENEMY] != null:
		out = (table[BING_XIAO_ENEMY] as Dictionary).duplicate(true)
		out["id"] = BING_XIAO_THUG
		out["name"] = "小钱的打手"
		out["dropItems"] = []
		out["params"] = _bing_thug_params(out.get("params", []))
		out["note"] = "NoElite\n<EnemyNote>\n小钱带出来的讨债打手。\n</EnemyNote>\n<EnemyRace: 3>\n<Sideview Battler: Actor12_2>\n<Breathing Speed: 11>\n<Sideview No Collapse>\n<Sideview Weapon: 0, swing, 1>\n<Sideview Show Shadow>\n<Hide HP Gauge>\nEmerge Motion: 0\n<DontEsc>"
	if not out.is_empty():
		_bing_enemy_cache[id] = out
	return out


static func has_troop(s, id: int) -> bool:
	return _bing_on(s) and (id == BING_LAO_TROOP or id == BING_XIAO_TROOP)


static func troop_rec(id: int, base: Dictionary) -> Dictionary:
	if _bing_troop_cache.has(id) and is_same(_bing_troop_base_ref.get(id), base):
		return _bing_troop_cache[id]
	var d := base.duplicate(true)
	if id == BING_LAO_TROOP:
		d["name"] = "老钱"
		d["members"] = [
			{"enemyId": BING_LAO_ENEMY, "x": 220, "y": 303, "hidden": false},
			{"enemyId": BING_LAO_THUG, "x": 130, "y": 245, "hidden": false},
			{"enemyId": BING_LAO_THUG, "x": 130, "y": 365, "hidden": false},
		]
	elif id == BING_XIAO_TROOP:
		d["name"] = "小钱"
		d["members"] = [
			{"enemyId": BING_XIAO_ENEMY, "x": 220, "y": 322, "hidden": false},
			{"enemyId": BING_XIAO_THUG, "x": 130, "y": 260, "hidden": false},
			{"enemyId": BING_XIAO_THUG, "x": 130, "y": 380, "hidden": false},
		]
	_bing_troop_base_ref[id] = base
	_bing_troop_cache[id] = d
	return d


# ---- 事件隐藏 ----

## MVEvent._find_page：天启篇整件不出的事件
static func hides(map_id: int, event_id: int) -> bool:
	if JIA and JIA_HIDDEN.has(map_id) and (JIA_HIDDEN[map_id] as Array).has(event_id) and on(XState.current):
		return true
	# ---- 槽位：乙 ----
	if YI and YI_HIDDEN.has(map_id) and (YI_HIDDEN[map_id] as Array).has(event_id) and on(XState.current):
		return true
	# ---- 槽位：丙 ----
	if BING and BING_HIDDEN.has(map_id) and (BING_HIDDEN[map_id] as Array).has(event_id) and on(XState.current):
		return true

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
	if _bing_on(_s) and ((_map_id == HALL_MAP and (_event_id == 38 or _event_id == 39)) or (_map_id == 192 and _event_id == 6)):
		return true

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
	if _bing_on(_s):
		if _map_id == HALL_MAP and (_event_id == 38 or _event_id == 39):
			await _bing_run_loan(_host, _s, _event_id)
			return
		if _map_id == 192 and _event_id == 6:
			await _bing_run_greedy_merchant(_host, _s)
			return

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


# ==== 包壬：入队等级同步 ====
## 通关抽到的新角色入队时，等级同步成「当前上场队员（上场 4 人＋助力位）的平均等级（四舍五入）」，不超过本层等级上限（XState.max_level，
## 各层守层者打完才抬）；经验同步到该级。只管 XTianqi.take_draw 的通关抽角色，开局阵容不动；只升不降。回退开关 REN（O-444）。
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
	if grant_fetter(s, tier):
		await say_fetter(host, s, tier)


## 松过第 tier 重之后小小鱼的台词（0＝这次没发，不说）
static func say_fetter(host, s, tier: int) -> void:
	if tier < 1 or tier > YI_LINES.size() or host == null or not host.has_method("show_text"):
		return
	await host.show_text("", 0, [XTianqiLine.line_text([XTianqi.GUIDE_NAME, YI_LINES[tier - 1]])])
	await host.show_text("", 0, ["\\c[2]挣脱枷锁·%s\\c[0]　全队抽奖被动上限+1（现在%d）。" % [YI_NAMES[tier - 1], int(s.variable(YI_CAP_VAR))]])


## XTianqiLine.run_arrival 标记 seen 之前：本线楼层节点（echo15／rumor25）先把这一重发掉，和 seen 同一步落定；
## 返回这次发的重数（没发为 0），演完再交给 after_beat 说台词
static func grant_for_beat(s, beat: String) -> int:
	if YI and YI_BEATS.has(beat) and grant_fetter(s, int(YI_BEATS[beat])):
		return int(YI_BEATS[beat])
	return 0


## XTianqiLine.run_arrival 末尾：节点演完，小小鱼说一句（tier 是 grant_for_beat 的返回）
static func after_beat(host, s, tier: int) -> void:
	await say_fetter(host, s, tier)


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


## ==== 包庚：传承与武运（O-447）====
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


## MVEvent.refresh 挂点：为包庚接管的事件提供改写后的页，走普通 run_event（保留 e.locked 与转向玩家），不改变 MVEvent._find_page() 对教派开关页的拦截
static func page_override(s, map_id: int, event_id: int, pages: Array) -> Dictionary:
	if not GENG or not _geng_is_target(map_id, event_id) or not on(s):
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
