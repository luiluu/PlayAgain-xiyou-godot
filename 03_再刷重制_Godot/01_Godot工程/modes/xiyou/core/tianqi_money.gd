class_name XTianqiMoney
extends RefCounted
## 【cc·金钱重构·未经审查】天启篇金钱重构（私密设计仓库 重制设定/天启篇_金钱重构方案_v0.2，Kyo 11-14「全可以，按你的建议来，
## 9的话根据难度调整」）。规则表 tianqi_data/money_table.json（数是草案）。只认天启篇存档（XTianqi.active），西游本体不变。
##
## 钱只买「服务和确定的结果」。新增消耗都按「场钱」标价：本档最高到达层（变量 20）一场随机遇敌的平均金钱 × 难度奖励倍率
## （XTianqiBalance.reward_mult，和掉落共用）；再乘各档价格倍数（寻常 0.6～证道 1.7）。算出的价钱取两位有效数字、避开 4（nice）。
## - INCOME：战斗金钱的全队加成（被动 passiveGRUP、套装、词条阅历、金钱翻倍）相加后递减（同掉落：合计×200÷(合计＋200)），
##   乘难度奖励倍率；原版难度被动（「普通难度」等）不算，牢妲改的难度号金钱倍率不算。battle_logic.rewards 末尾调 battle_gold。
## - SELL：装备卖价按品质（0.1～2 场钱），不看原价；物品照旧（XItemMarks.selling_price 调 sell_price）。
## - REFORGE：重铸价（XTianqiReforge 读 reforge_price／lock_price）：3 场钱 × 阶系数，同一件每次 ×1.3、封顶 10 倍，锁一条洗其余总价 ×3。
## - ADVANCE：进阶四阶 10 万／30 万／60 万／100 万（XAdvance.row 读 advance_gold），一次性的，不乘价格倍数。
## - TRAINING：修炼重做，八项各 10 级、全队共享、每 3 层开 1 级，每级加本体基础值 1%（占位）；原表 65 项不用（XTraining 读这里）。
## - SCALE：天平，大厅原「动保协会成员」（Map004 EV043，宠物商店，天启篇宠物全隐藏）换成天平：麦（每场开战全队回满）、
##   油（承伤 −10%）、酒（出伤 ＋10%），只管当前这一层；一层最多买 3 次、第 n 次价格 ×2^(n−1)；饥荒线贵五成。
## 存档：flags.tianqi.money {"training": {"能力编号": 等级}, "scale": {"floor": 层, "goods": [..], "buys": 次数}}；装备上记重铸次数 tq_reforges。
##
## 开关（O-404）：ENABLED＝false 全部回到之前；各分项单独设 false 回到之前那一项。

static var ENABLED := true
static var INCOME := true
static var SELL := true
static var REFORGE := true
static var ADVANCE := true
static var TRAINING := true
static var SCALE := true

const PATH := "res://modes/xiyou/tianqi_data/money_table.json"
const SCALE_MAP := 4
const SCALE_EVENT := 43
const GOODS := ["wheat", "oil", "wine"]
const GOODS_NAME := {"wheat": "麦", "oil": "油", "wine": "酒"}
const PARAM_NAMES := ["最大生命", "最大魔法", "物理攻击", "物理防御", "魔法攻击", "魔法防御", "敏捷", "幸运"]

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		if XDataFile.missing(PATH):  # 发行包里没有（没发行的内容）
			return {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func reload() -> void:
	_data = {}


static func on(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and XTianqi.active(s) and not data().is_empty()


static func _sec(key: String) -> Dictionary:
	var v = data().get(key, {})
	return v if v is Dictionary else {}


static func money(s: XState) -> Dictionary:
	var tq: Dictionary = s.flags.tianqi
	if not (tq.get("money") is Dictionary):
		tq["money"] = {}
	return tq.money


# ---- 场钱与价格 ----

## 最高到达层（变量 20，至少 1）
static func top_floor(s: XState) -> int:
	return maxi(1, int(s.variable(20)))


## 这一层的场钱表值（没乘难度奖励倍率）
static func field_base(floor_no: int) -> float:
	var t: Array = _sec("field_gold").get("by_floor", [])
	if t.is_empty():
		return 0.0
	return float(t[clampi(floor_no, 1, t.size()) - 1])


## 场钱：本档最高到达层一场随机遇敌的平均金钱 × 难度奖励倍率
static func field_money(s: XState) -> float:
	return field_base(top_floor(s)) * XTianqiBalance.reward_mult(s)


static func difficulty_key(s: XState) -> String:
	return str(s.flags.tianqi.get("difficulty", "")) if XTianqi.active(s) else ""


## 各档价格倍数
static func price_mult(s: XState) -> float:
	return float(_sec("price_mult").get(difficulty_key(s), 1.0))


## 标价：units 场钱 × 价格倍数，取整到两位有效数字、避开 4
static func price(s: XState, units: float) -> int:
	return nice(units * field_money(s) * price_mult(s))


## 两位有效数字（四舍五入），有 4 的那位往上进一（4→5）；小于 10 的取整
static func nice(x: float) -> int:
	if x <= 0.0:
		return 0
	if x < 10.0:
		var n := maxi(1, roundi(x))
		return 5 if n == 4 else n
	var e := 0
	var m := x
	while m >= 100.0:
		m /= 10.0
		e += 1
	var mi := roundi(m)
	if mi >= 100:
		mi = 10
		e += 1
	if mi / 10 == 4:
		mi = 50
	elif mi % 10 == 4:
		mi += 1
	return mi * int(pow(10.0, e))


# ---- 收入 ----

## 全队金钱加成合计（百分数，没递减）。members 是上场＋助力位
static func income_bonus(members: Array, s: XState) -> float:
	var inc := _sec("income")
	var ignore: Array = inc.get("ignore_skills", []).map(func(x): return int(x))
	var total := 0.0
	for a in members:
		if not (a is XActor):
			continue
		for sk in a.skills():
			var m: Dictionary = sk.get("meta", {})
			if m.has("passiveGRUP") and not ignore.has(int(sk.get("id", 0))):
				total += XActor._num(m["passiveGRUP"])
		total += XEquipSuits.value(a, "bResult", 1, false)
		total += (XEquipSuits.value(a, "bResult", 1, true) - 1.0) * 100.0
	total += XTianqiAffixBattle.party_sum(members, "exp_gold")  # 词条「阅历」
	if s != null and s.party_ability(4):
		total += float(inc.get("party_gold_double", 100))
	return total


## 递减后的有效加成（百分数）：合计×k÷(合计＋k)；负数不递减、不低于 negative_floor
static func effective(total: float) -> float:
	var inc := _sec("income")
	if total <= 0.0:
		return maxf(total, float(inc.get("negative_floor", -90)))
	var k := float(inc.get("k", 200))
	return total * k / (total + k)


## battle_logic.rewards 末尾：按天启篇规则重算 out.gold（原版算出 0 的照旧 0，如神兵试炼）
static func battle_gold(logic, out: Dictionary) -> void:
	if not INCOME or not on(logic.state) or int(out.get("gold", 0)) <= 0:
		return
	var base := 0.0
	for e in logic.enemies:
		if e.hidden:
			continue
		base += float(e.gold_reward())
	var members: Array = XTianqiAffixBattle._reward_members(logic)
	var mult := (1.0 + effective(income_bonus(members, logic.state)) / 100.0) * XTianqiBalance.reward_mult(logic.state)
	out.gold = int(floorf(base * mult)) * 5


# ---- 卖价 ----

## 天启篇装备卖价（按品质）；不归这里管的返回 -1（照旧）
static func sell_price(rec: Dictionary, s: XState = null) -> int:
	if s == null:
		s = XState.current
	if not SELL or s == null or not on(s) or not XItemMarks.is_gear(rec):
		return -1
	return sell_price_grade(s, XFabaoFeed.grade_of(rec))


## 品质档 grade（0 普通～6 神话）的装备卖价；不归这里管的返回 -1。掉落线挂机折钱（XTianqiDrop._auto_sell）也调它
static func sell_price_grade(s: XState, grade: int) -> int:
	if not SELL or s == null or not on(s):
		return -1
	var t: Array = _sec("sell").get("by_grade", [])
	if t.is_empty():
		return -1
	return nice(float(t[clampi(grade, 0, t.size() - 1)]) * field_money(s))


# ---- 重铸 ----

static func reforge_on(s: XState) -> bool:
	return REFORGE and on(s)


## 同一件装备重铸过几次后的涨价倍数：(1＋step)^次数，封顶 cap
static func reforge_escalation(item: Dictionary) -> float:
	var r := _sec("reforge")
	return minf(float(r.get("cap", 10)), pow(1.0 + float(r.get("step", 0.3)), int(item.get("tq_reforges", 0))))


## 一条（阶 tier）的起步价，场钱单位
static func _line_units(tier: int) -> float:
	var r := _sec("reforge")
	var coef: Array = r.get("tier_coef", [1])
	return float(r.get("base", 3)) * float(coef[clampi(tier - 1, 0, coef.size() - 1)])


## 重铸一条的价钱
static func reforge_price(s: XState, item: Dictionary, entry: Dictionary) -> int:
	return price(s, _line_units(int(entry.get("tier", 1))) * reforge_escalation(item))


## 锁住第 keep 条、洗其余各条的价钱：其余各条起步价之和 × 涨价倍数 × lock_mult
static func lock_price(s: XState, item: Dictionary, keep: int) -> int:
	var list: Array = item.get("tianqi_affixes", [])
	var units := 0.0
	for i in list.size():
		if i != keep:
			units += _line_units(int(list[i].get("tier", 1)))
	return price(s, units * reforge_escalation(item) * float(_sec("reforge").get("lock_mult", 3)))


static func count_reforge(item: Dictionary) -> void:
	item["tq_reforges"] = int(item.get("tq_reforges", 0)) + 1


# ---- 进阶 ----

## 天启篇第 num 阶（0 起）的进阶金钱；不归这里管返回 -1
static func advance_gold(s: XState, num: int) -> int:
	if not ADVANCE or not on(s):
		return -1
	var g: Array = _sec("advance").get("gold", [])
	return int(g[clampi(num, 0, g.size() - 1)]) if not g.is_empty() else -1


# ---- 修炼 ----

static func training_on(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return TRAINING and s != null and on(s)


static func training_levels() -> int:
	return int(_sec("training").get("levels", 10))


## 现在开放到几级：最高到达层 ÷ 每级层数
static func training_open(s: XState) -> int:
	return mini(training_levels(), top_floor(s) / maxi(1, int(_sec("training").get("floors_per_level", 3))))


static func training_level(s: XState, param: int) -> int:
	var t = money(s).get("training", {})
	return int(t.get(str(param), 0)) if t is Dictionary else 0


## 练第 lv 级（1 起）的价钱
static func training_price(s: XState, lv: int) -> int:
	var t := _sec("training")
	return price(s, float(t.get("first", 30)) * pow(1.0 + float(t.get("step", 0.3)), lv - 1))


## 修炼一级：返回提示文字
static func train(s: XState, param: int) -> String:
	var lv := training_level(s, param)
	if lv >= training_levels():
		return "等级已满"
	if lv >= training_open(s):
		return "本层只开放到 %d 级（每 %d 层开 1 级）" % [training_open(s), int(_sec("training").get("floors_per_level", 3))]
	var cost := training_price(s, lv + 1)
	if int(s.gold) < cost:
		return str(XDB.system().get("currencyUnit", "")) + "不足"
	var m := money(s)
	if not (m.get("training") is Dictionary):
		m["training"] = {}
	m.training[str(param)] = lv + 1
	s.gain_gold(-cost)
	return "修炼成功"


## 修炼给这名角色第 i 项能力加的值：基础值 × 每级比例 × 等级（全队共享）
static func training_bonus(a: XActor, i: int) -> float:
	var s := XState.current
	if i < 0 or i >= 8 or not training_on(s):
		return 0.0
	var lv := training_level(s, i)
	if lv <= 0:
		return 0.0
	return floorf(a.param_base_direct(i) * float(_sec("training").get("pct_per_level", 0.01)) * lv)


# ---- 天平 ----

static func scale_on(s: XState) -> bool:
	return SCALE and s != null and on(s)


## 本层的天平记录（最高到达层变了就清掉）
static func scale_state(s: XState) -> Dictionary:
	var m := money(s)
	var sc = m.get("scale")
	if not (sc is Dictionary) or int(sc.get("floor", 0)) != top_floor(s):
		sc = {"floor": top_floor(s), "goods": [], "buys": 0}
		m["scale"] = sc
	return sc


static func has_good(s: XState, good: String) -> bool:
	if not scale_on(s):
		return false
	var sc = money(s).get("scale")
	return sc is Dictionary and int(sc.get("floor", 0)) == top_floor(s) and (sc.get("goods", []) as Array).has(good)


## 下一次买的价钱
static func scale_price(s: XState) -> int:
	var t := _sec("scale")
	var n := int(scale_state(s).get("buys", 0))
	var units := float(t.get("price", 30)) * pow(2.0, n)
	if XTianqi.line_of(s) == "famine":
		units *= float(t.get("famine_mult", 1.5))
	return price(s, units)


## 买一样：返回 {ok} 或 {error}
static func buy_good(s: XState, good: String) -> Dictionary:
	if not scale_on(s) or not GOODS.has(good):
		return {"error": "现在不能买"}
	var sc := scale_state(s)
	if (sc.goods as Array).has(good):
		return {"error": "这一层已经买过%s了" % GOODS_NAME[good]}
	if int(sc.buys) >= int(_sec("scale").get("max_buys", 3)):
		return {"error": "这一层买不了更多了"}
	var cost := scale_price(s)
	if int(s.gold) < cost:
		return {"error": "%s不足（要 %d）" % [str(XDB.system().get("currencyUnit", "")), cost]}
	s.gain_gold(-cost)
	(sc.goods as Array).append(good)
	sc.buys = int(sc.buys) + 1
	return {"ok": good, "cost": cost}


## 油：承伤倍率；酒：出伤倍率（XTianqiCombat 乘进去）
static func scale_taken_mult(s: XState) -> float:
	return 1.0 - float(_sec("scale").get("oil", 0.1)) if has_good(s, "oil") else 1.0


static func scale_dealt_mult(s: XState) -> float:
	return 1.0 + float(_sec("scale").get("wine", 0.1)) if has_good(s, "wine") else 1.0


## 麦：开战前全队（活着的）回满生命、魔法。battle_logic.setup 调
static func battle_setup(logic, s: XState) -> void:
	if not has_good(s, "wheat"):
		return
	for a in logic.actors:
		if a != null and a.is_alive():
			a.hp = a.mhp
			a.mp = a.mmp


static func intercepts(s: XState, map_id: int, event_id: int) -> bool:
	return scale_on(s) and map_id == SCALE_MAP and event_id == SCALE_EVENT


## 天平对话（大厅 EV043）
static func run_scale(host, s: XState) -> void:
	await host.show_text("", 0, ["\\n<天平>一钱银子买一升麦子，三升大麦；油和酒不可糟蹋。"])
	while true:
		var sc := scale_state(s)
		var labels := []
		for g in GOODS:
			labels.append(_good_label(s, g, sc))
		labels.append("离开")
		var head := "第 %d 层　已买 %d／%d　下一样 %d%s　身上 %d" % [top_floor(s), int(sc.buys), int(_sec("scale").get("max_buys", 3)),
			scale_price(s), str(XDB.system().get("currencyUnit", "")), int(s.gold)]
		var i: int = await host.show_text_with_choices("", 0, [head], labels, labels.size() - 1)
		if i < 0 or i >= GOODS.size():
			break
		var r := buy_good(s, GOODS[i])
		await host.show_text("", 0, [str(r.error) if r.has("error") else "买下了%s，只管这一层。" % GOODS_NAME[GOODS[i]]])


static func _good_label(s: XState, g: String, sc: Dictionary) -> String:
	var t := _sec("scale")
	var desc: String = {"wheat": "每场开战全队回满", "oil": "全队承伤 −%d%%" % roundi(float(t.get("oil", 0.1)) * 100),
		"wine": "全队出伤 ＋%d%%" % roundi(float(t.get("wine", 0.1)) * 100)}[g]
	return "%s：%s%s" % [GOODS_NAME[g], desc, "（已买）" if (sc.goods as Array).has(g) else ""]
