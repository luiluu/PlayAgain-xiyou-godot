class_name XAdvance
extends RefCounted
## 角色进阶（Star_ActorAdvanced 的 Scene_ActorAdvanced；兑换大厅奉神老妪 Map132 EV6「进阶」）。界面在 XActorAdvancedScene。
## 照冻结 v0.28 原版（tests/fixtures/actor_advanced_oracle.json）：
## - 进阶表：插件参数「Advanced i」（i=1～1000，空项跳过）。一行＝某角色从第 AdvancedActNum 次进到下一次的需求与效果：
##   需求等级、金钱、物品 [[ID, 数量]…]；学会技能、遗忘技能；AdvancedActNumMaX 只用来显示。
##   installNativeEconomyRuntime.normalizeAdvanceCosts：物品 184～187 换成 188（魂灯），同 ID 合并数量。
##   （installNativeRavenRuntime 给渡鸦 167 补的 5 行不做：渡鸦不在切片。）
## - 进阶次数：原版 Game_Actor._AdvancedNum（随角色进存档），重制存 XState.actor_advance（角色 ID → 次数，存档键 actorAdvance；
##   旧档没有为空＝全 0）。别的模块读进阶次数一律用 rank()。
## - 进阶（onConfirmOk）：先遗忘、再学会技能，次数 +1，扣金钱、扣物品。基础插件不改职业、能力与外观；
##   能力变化全来自学会的被动技能（如 1240 超越极限I），由 XActor 的被动解析计算。
## O-094（可回退）：SHOW_MISSING——原版条件不足只提示「进阶条件未达成」，重制在后面列出缺的项；
##   MAX_BUZZER——已达最大时在名单按确定原版没有反馈（只有确定音），重制放蜂鸣。

const FAIL_TEXT := "进阶条件未达成"
const DONE_TEXT := "进阶完成"
const MAX_ROWS := 1000

## O-094 开关：false 时照原版只提示「进阶条件未达成」
static var SHOW_MISSING := true
## O-094 开关：false 时已满确定照原版放确定音
static var MAX_BUZZER := true
static var _rows: Array = []


## DataManager.Star_GetAdvancedOpt ＋ 经济货币合并
static func rows() -> Array:
	if _rows.is_empty():
		var p := XDB.plugin("Star_ActorAdvanced")
		for i in range(1, MAX_ROWS + 1):
			var raw := str(p.get("Advanced %d" % i, ""))
			var d = JSON.parse_string(raw) if raw.strip_edges() != "" else null
			if d is Dictionary:
				_rows.append({"id": i, "actor": _int(d.get("AdvancedActId")), "num": _int(d.get("AdvancedActNum")),
					"max": _int(d.get("AdvancedActNumMaX")), "level": _int(d.get("AdvancedActLevel")), "gold": _int(d.get("AdvancedGold")),
					"items": _merge_costs(_list(d.get("AdvancedItem"))), "learn": _list(d.get("AdvancedSkiId")).map(func(v): return _int(v)),
					"forget": _list(d.get("AdvancedForId")).map(func(v): return _int(v))})
	return _rows


static func _int(v) -> int:
	var t := str(v).strip_edges()
	return int(float(t)) if t.is_valid_float() else 0


## 参数里的数组是 JS 字面量（eval）。冻结源有两条不是合法 JSON：末尾逗号「[1244,5846,]」（JS 忽略），
## 逗号表达式「[[2793,1]],[[180,1]]」（JS 取最后一个，即只要 180×1）。照 eval：去掉 ] 前的逗号，整体包一层数组取最后一项
static func _list(v) -> Array:
	var t := str(v).strip_edges()
	if t == "":
		return []
	t = RegEx.create_from_string(",\\s*\\]").sub(t, "]", true)
	var d = JSON.parse_string("[" + t + "]")
	return d.back() if d is Array and not d.is_empty() and d.back() is Array else []


## normalizeAdvanceCosts：含 184～187 的行，这四种换成 188，同 ID 按首次出现的位置合并数量
static func _merge_costs(raw: Array) -> Array:
	var pairs := raw.filter(func(p): return p is Array and p.size() >= 2).map(func(p): return [_int(p[0]), _int(p[1])])
	if not pairs.any(func(p): return p[0] >= 184 and p[0] <= 187):
		return pairs
	var out := []
	var pos := {}
	for p in pairs:
		var id: int = 188 if p[0] >= 184 and p[0] <= 187 else p[0]
		if pos.has(id):
			out[pos[id]][1] += p[1]
		else:
			pos[id] = out.size()
			out.append([id, p[1]])
	return out


static func rank(s: XState, actor_id: int) -> int:
	return int(s.actor_advance.get(actor_id, 0)) if s != null else 0


## 当前次数对应的那一行（filter(...)[0]）；没有＝已达最大
static func row(s: XState, actor_id: int):
	var n := rank(s, actor_id)
	for r in rows():
		if int(r.actor) == actor_id and int(r.num) == n:
			return r
	return null


## 状态窗「最大进阶次数」：有行用其最大值，否则用当前次数
static func max_text(s: XState, actor_id: int) -> int:
	var r = row(s, actor_id)
	return int(r.max) if r != null else rank(s, actor_id)


## onBottomConfirmOk 的条件：等级、金钱、每种物品够数。返回缺项文字（空＝满足）；没有行返回 ["已满"]
static func missing(s: XState, a: XActor) -> Array:
	if XGarou.own(a):  # 饿狼 onBottomConfirmOk 包装：先查形态条件（等级、累计突破、神之触媒），不满足只给原因
		var why := XGarou.reason(s, a)
		if why != "":
			return [why]
	var r = row(s, a.actor_id)
	if r == null:
		return ["已满"]
	var out := []
	if a.level < int(r.level):
		out.append("等级%d/%d" % [a.level, int(r.level)])
	if s.gold < int(r.gold):
		out.append(str(XDB.system().get("currencyUnit", "")) + "不足")
	for p in r.items:
		var have := s.item_count(int(p[0]))
		if have < int(p[1]):
			out.append("%s %d/%d" % [str(XDB.rec("Items", int(p[0])).get("name", "")), have, int(p[1])])
	return out


## 条件不足的提示（O-094 关掉时照原版）
static func fail_text(lack: Array) -> String:
	return FAIL_TEXT + "：" + "、".join(lack) if SHOW_MISSING and not lack.is_empty() else FAIL_TEXT


## onConfirmOk：遗忘 → 学会 → 次数 +1 → 扣金钱 → 扣物品。不检查条件（界面在底部确定时已查过）；没有行返回 false
static func advance(s: XState, a: XActor) -> bool:
	if XGarou.own(a):  # 饿狼 onConfirmOk 包装：走 G.advance（不扣表里的物品，星空另扣神之触媒）
		return bool(XGarou.advance(s, a, rank(s, a.actor_id)).ok)
	var r = row(s, a.actor_id)
	if r == null:
		return false
	var previous := rank(s, a.actor_id)
	for id in r.forget:
		a.forget_skill(int(id))
	for id in r.learn:
		a.learn_skill(int(id))
	s.actor_advance[a.actor_id] = rank(s, a.actor_id) + 1
	s.gain_gold(-int(r.gold))
	for p in r.items:
		s.gain_item(int(p[0]), -int(p[1]))
	a.refresh_passive()
	XRaven.after_advance(s, a, previous)  # 渡鸦 onConfirmOk 包装：灵魂清零、重排技能、再判铸印
	return true


static func to_save(v: Dictionary) -> Dictionary:
	var out := {}
	for k in v:
		out[str(k)] = int(v[k])
	return out


static func from_save(v) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			if str(k).is_valid_int() and (v[k] is int or v[k] is float) and int(v[k]) > 0:
				out[int(k)] = int(v[k])
	return out
