class_name XTianqiGuardianGift
extends RefCounted
## 【cc·天启篇·未经审查】天启篇去见面礼（T236，Kyo 11-19「224甲」）。只认天启篇存档（XTianqi.active），西游档原样。
## 原版 13～30 层守层者（18 张图，GUARDIANS）第 0 页有「缴纳见面礼」：交了把变量 842 设 1；打赢后只有 842＝0（没交）才给宝珠、
## 把这一层的首胜标记（861～878，原版现成的变量）置 1，第 1 页（独立开关 A）「向守层者索要礼物」看这个标记开压箱底店。
## 天启篇改成：
## - 第 0 页选单去掉「缴纳见面礼」那一项和它的分支（取消键原版指着它，改指「离开」）；后面的「见面礼选择」标签段没人跳进去，留着不动。
## - 打赢后判断 842 之前先把 842 清零：每层第一次打赢必给宝珠（数量照原版不交礼那次）、必置首胜标记 → 压箱底店必开。
##   第 0 页打赢就开独立开关 A，之后走第 1 页、没有再打一次的入口，所以一层只给一次；店开了以后常驻（照原版，标记不清零）。
## - 旧天启篇存档补发（BACKFILL）：已交礼打赢的层（开关 A 开着、首胜标记还是 0），第 1 页开口时按原版那段补给宝珠、置标记，
##   之后和新档一样；标记置 1 后不会再补。已交礼还没打的层：礼钱不退，打赢照样给。
## 不改 generated 原数据，XDB.map 读图时改缓存里的副本；换档改了天启篇口径时 XTextFix.sync_mode 清地图缓存重读。
## 守层者开场的领域（Troops 第 1 回合页看 842）不归这里管（T229）。31～33 层原版没有见面礼，不在名单里。
## - 第 1 页开店台词「送礼文化积怨已久……」换成小A 定的句子（SHOP_NEW），后半「我这里有些压箱底的宝贝。给你看看。」不动。
## 回退开关 ENABLED：false 回到原版（有见面礼）；BACKFILL：false 不给旧档补发。专项 xiyou_tianqi_guardian_gift 两个都设过回退值。

static var ENABLED := true
static var BACKFILL := true

const GIFT_CHOICE := "缴纳见面礼"
const LEAVE_CHOICE := "离开"
const GIFT_VAR := 842
const SHOP_OLD := "送礼文化积怨已久，你的到来也许会让现状有所改变吧。"
const SHOP_NEW := "能在这一层堂堂正正胜过我，你的实力倒也配得上这份认可。"
## 地图号 → 守层者事件号（13～30 层）
const GUARDIANS := {
	64: 1, 30: 8, 32: 1, 33: 3, 45: 1, 46: 1, 47: 13,
	116: 1, 117: 1, 119: 13, 118: 3, 120: 1, 147: 1, 155: 1, 182: 1, 145: 1, 144: 1, 146: 1,
}


static func on() -> bool:
	return ENABLED and XState.current != null and XTianqi.active(XState.current)


## XDB.map 读图时调
static func patch_map(map_id: int, data) -> void:
	if not GUARDIANS.has(map_id) or not (data is Dictionary) or not on():
		return
	var events: Array = data.get("events", [])
	var ev_id: int = GUARDIANS[map_id]
	if events.size() <= ev_id or not (events[ev_id] is Dictionary):
		return
	var pages: Array = events[ev_id].get("pages", [])
	if pages.is_empty():
		return
	var p0: Array = pages[0].get("list", [])
	_drop_gift_choice(p0)
	var reward := _force_reward(p0)
	var pa = _shop_page(pages)
	if pa == null:
		return
	_retext_shop(pa.get("list", []))
	if BACKFILL and not reward.is_empty():
		_add_backfill(pa.get("list", []), reward)


## 开店台词（小A T236 P2-1）：天启篇没有送礼了，原句的前提不在；只换句子本身，名字框前缀「\\n<守层者名>」留着
static func _retext_shop(list: Array) -> void:
	for c in list:
		if int(c.get("code", 0)) == 401 and c.parameters.size() > 0 and str(c.parameters[0]).contains(SHOP_OLD):
			var p: Array = c.parameters.duplicate()
			p[0] = str(p[0]).replace(SHOP_OLD, SHOP_NEW)
			c.parameters = p


## 第 0 页第一个带「缴纳见面礼」的选单：删这一项、删它的分支，后面的分支号往前挪
static func _drop_gift_choice(list: Array) -> void:
	for i in list.size():
		var c: Dictionary = list[i]
		if int(c.get("code", 0)) != 102 or not (c.parameters[0] is Array) or not c.parameters[0].has(GIFT_CHOICE):
			continue
		var p: Array = c.parameters.duplicate()
		var opts: Array = p[0].duplicate()
		var gi := opts.find(GIFT_CHOICE)
		opts.remove_at(gi)
		p[0] = opts
		p[1] = _shift(int(p[1]), gi, opts.find(LEAVE_CHOICE))  # 取消键
		p[2] = _shift(int(p[2]), gi, 0)                          # 默认项
		c.parameters = p
		var ind := int(c.indent)
		var j := i + 1
		while j < list.size():
			var b: Dictionary = list[j]
			var bi := int(b.indent)
			if bi < ind or (bi == ind and int(b.code) == 404):
				break
			if bi == ind and int(b.code) == 402:
				var k := int(b.parameters[0])
				if k == gi:
					var e := j + 1
					while e < list.size() and not (int(list[e].indent) == ind and int(list[e].code) in [402, 403, 404]):
						e += 1
					for _n in e - j:
						list.remove_at(j)
					continue
				if k > gi:
					var bp: Array = b.parameters.duplicate()
					bp[0] = k - 1
					b.parameters = bp
			j += 1
		return


## 指向被删那一项的（取消键、默认项）改指 fallback；在它后面的往前挪一格；负数（禁止取消等）不动
static func _shift(v: int, gi: int, fallback: int) -> int:
	if v == gi:
		return fallback
	return v - 1 if v > gi else v


## 打赢后的「如果 842＝0」前面插一句 842＝0；返回那个分支里的指令（补发照抄），找不到返回 []
static func _force_reward(list: Array) -> Array:
	for i in list.size():
		var c: Dictionary = list[i]
		if int(c.get("code", 0)) != 111:
			continue
		var p: Array = c.parameters
		if p.size() < 5 or int(p[0]) != 1 or int(p[1]) != GIFT_VAR or int(p[2]) != 0 or int(p[3]) != 0 or int(p[4]) != 0:
			continue
		var ind := int(c.indent)
		var body := []
		var j := i + 1
		while j < list.size() and int(list[j].indent) > ind:
			body.append(list[j])
			j += 1
		list.insert(i, {"code": 122, "indent": ind, "parameters": [GIFT_VAR, GIFT_VAR, 0, 0, 0]})
		return body
	return []


## 打赢后的那页：只有独立开关 A 一个条件（模式开关 2302 等那几页原版本来就没有见面礼）
static func _shop_page(pages: Array):
	for i in range(1, pages.size()):
		var cond: Dictionary = pages[i].get("conditions", {})
		if bool(cond.get("selfSwitchValid", false)) and str(cond.get("selfSwitchCh", "")) == "A" \
				and not bool(cond.get("switch1Valid", false)) and not bool(cond.get("switch2Valid", false)) \
				and not bool(cond.get("variableValid", false)):
			return pages[i]
	return null


## 首胜标记：原版那段里给标记变量置 1 的那句
static func flag_var(body: Array) -> int:
	for c in body:
		var p: Array = c.parameters
		if int(c.code) == 122 and p.size() >= 5 and int(p[0]) == int(p[1]) and int(p[2]) == 0 and int(p[3]) == 0 and int(p[4]) == 1:
			return int(p[0])
	return 0


## 第 1 页开头：如果首胜标记＝0，照抄原版那段（给宝珠、提示、置标记）
static func _add_backfill(list: Array, body: Array) -> void:
	var flag := flag_var(body)
	if flag <= 0:
		return
	var base_ind := int(body[0].indent) - 1 if not body.is_empty() else 0
	var add := [{"code": 111, "indent": 0, "parameters": [1, flag, 0, 0, 0]}]
	for c in body:
		add.append({"code": int(c.code), "indent": int(c.indent) - base_ind, "parameters": (c.parameters as Array).duplicate(true)})
	add.append({"code": 412, "indent": 0, "parameters": []})
	for k in add.size():
		list.insert(k, add[k])
