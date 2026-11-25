class_name XTianqiBrandRealm
extends RefCounted
## 【cc·T514·未经审查】天启篇七境的境底＋境支（T013 3A；设计仓库《原版养成线重做方案 v0.3》第三节第 5 条、第五节第 1～3 条甲；
## 《天启篇_烙印 v0.6》第四节第 5 条：D129 迎劫境底攻换生命、九条带攻境支去攻、D145 四条换伤支）。数在 brand.json 的 realm 段。
## 只在天启篇、烙印开着（XTianqiBrand.on）时算；西游档、开关关着每个入口都是「没有」（倍率 1、加 0）。
## 境按立到的境（XTianqiBrand.realm，打赢心魔才升）算，不按烙印值；境支每境（不染～逆命）一条，存在 zhenqi.brand_branch {"境号": 支 key}。
## 没选过的境按第一条算（老档口径：默认第一支），第一次选免费；之后换支花钱、一次换一境，只在方桌大厅（不在副本、里副本里；can_change）。
## 道法（3C）和境支联动（3B）不在本卡：联动只在表里写给人看。
##
## | 入口 | 干什么 | 谁调 |
## |---|---|---|
## | param_rate(角色, i) | 境底主属性、生命＋境支两项属性，同一条线里相加：1 ＋ Σ% | XActor.param_rate |
## | dealt_mult(角色) | 换伤支伤害那一半：1 ＋ 3% × 选了几条（和烙印并在 K 那一项） | XTianqiBase.k_actor_mult |
## | taken_add(角色) | 承伤池：铸骨 −5%、真形再 −5%、换伤支每条 +3%（和破防同池相加） | XTianqiBrand.taken_mult |
## | state_rate(角色, 状态)／debuff_rate(角色) | 不染：被上有害状态、能力减益 10% 不中（和异常抵抗相乘） | BattleLogic.state_rate／add_debuff_effect、XTianqiElementEffects |
## | heal(角色, 量) | 砥柱：战斗里生命低于一半时受到的回复 +15%（各线削减之后） | XTianqiBrand.heal |
## | big_hit(角色, 伤害) | 迎劫：一下超过最大生命一半的部分少受三成 | BattleLogic.execute_hp_damage（各保命之前） |
## | note_hit／after_hit | 逆命：每场一次，挨打真掉了血、掉到三成以下还活着，这一击结算完后独立回复最大生命 20% | execute_hp_damage 记；apply、horseman_strike 末尾结算 |

## O-671（T514）：false＝回退：境底、境支一律不算，闭关菜单不出「分支」
static var ENABLED := true

const PARAM := {"mhp": 0, "mmp": 1, "atk": 2, "def": 3, "mat": 4, "mdf": 5, "agi": 6, "luk": 7}
const PARAM_CN := ["生命", "魔法", "物攻", "物防", "魔攻", "魔防", "敏捷", "幸运"]
const KEY := "brand_branch"
const RALLY := "realm_rally"
const RALLY_HIT := "realm_rally_hit"
## 玩家可见文字（已过小A 文字审，T514 核报告第四节定稿）。D174：不用「境」作总称，说七段原名＋「分支」
const TEXT_MENU := "加深分支（已选 %d/%d）"
const TEXT_HEAD := ["\\C[6]%s\\C[0] 的加深分支", "每段可选一条分支，属性即刻生效；首次免费，改选消耗%s。"]
const TEXT_PICK_HEAD := "\\C[6]%s\\C[0]「%s」分支：现为「%s」%s"
const TEXT_UNPICKED := "（未选，默认首项）"
const TEXT_COST_FREE := "本次选择免费。"
const TEXT_COST_PAID := "改选需消耗 %d %s。"
const TEXT_DONE := "%s 的「%s」分支已定为「%s」。"
const TEXT_POOR := "%s不足（需要 %d）。"
const TEXT_TRADE := "伤害 +%d%%、承伤 +%d%%"
const TEXT_PARAM := "%s +%d%%"
const TEXT_HALL_ONLY := "仅限在大厅闭关处更换分支。"


static func on(s = null) -> bool:
	return ENABLED and XTianqiBrand.on(s)


static func data() -> Dictionary:
	var d = XTianqiBrand.data().get("realm", {})
	return d if d is Dictionary else {}


static func _base(r: int) -> Dictionary:
	var b: Array = data().get("base", [])
	return b[r] if r >= 0 and r < b.size() and b[r] is Dictionary else {}


## 第 r 境（1 不染～6 逆命）的全部支（含 hidden）
static func all_branches(r: int) -> Array:
	var name := XTianqiBrand.stage_name(r)
	for row in data().get("branches", []):
		if str(row.get("realm", "")) == name and r > 0:
			return row.get("list", [])
	return []


## 摆出来能选的支（hidden 的本线支 3B 前不摆）
static func branches(r: int) -> Array:
	return all_branches(r).filter(func(b): return not bool(b.get("hidden", false)))


static func _find(r: int, key: String) -> Dictionary:
	for b in all_branches(r):
		if str(b.get("key", "")) == key:
			return b
	return {}


static func _store(a) -> Dictionary:
	var v = a.zhenqi.get(KEY) if a is XActor else null
	return v if v is Dictionary else {}


## 这一境选过没有（没选过的第一次选免费）
static func picked(a, r: int) -> bool:
	return _store(a).has(str(r)) and not _find(r, str(_store(a)[str(r)])).is_empty()


## 这一境生效的支：选过的；没选过按第一条
static func branch_of(a, r: int) -> Dictionary:
	if picked(a, r):
		return _find(r, str(_store(a)[str(r)]))
	var list := branches(r)
	return list[0] if not list.is_empty() else {}


## 立到的各境生效的支（不染起）
static func active_branches(a) -> Array:
	var out := []
	for r in range(1, XTianqiBrand.realm(a) + 1):
		var b := branch_of(a, r)
		if not b.is_empty():
			out.append(b)
	return out


# ---- 属性 ----

## 境底＋境支给第 i 项属性的倍率（这条线里相加）
static func param_rate(a, i: int) -> float:
	if not a is XActor or i < 0 or i > 7 or not on():
		return 1.0
	var pct := 0
	var r := XTianqiBrand.realm(a)
	for k in range(0, r + 1):
		var p = _base(k).get("params", {})
		if p is Dictionary:
			for key in p:
				if int(PARAM.get(str(key), -1)) == i:
					pct += int(p[key])
	var each := int(data().get("branch_pct", 3))
	for b in active_branches(a):
		for key in b.get("params", []):
			if int(PARAM.get(str(key), -1)) == i:
				pct += each
	return 1.0 + pct / 100.0


static func _trade_row(name: String) -> Dictionary:
	for t in XTianqiBrand.data().get("trade", {}).get("branches", []):
		if str(t.get("key", "")) == name:
			return t
	return {}


## 选了的换伤支（trade）的行
static func trades(a) -> Array:
	var out := []
	for b in active_branches(a):
		if bool(b.get("trade", false)):
			var t := _trade_row(str(b.get("name", "")))
			if not t.is_empty():
				out.append(t)
	return out


## 伤害那一半：1 ＋ Σ damage（并进 K 那一项）
static func dealt_mult(a, s = null) -> float:
	if not a is XActor or not on(s) or is_same(a, XTianqiBrand._plain_hit):  # 抽自己、六亲不认那一下：同烙印加成按 1（T514 核 P3-1）
		return 1.0
	var m := 1.0
	for t in trades(a):
		m += float(t.get("damage", 0.0))
	return m


## 承伤池加项：境底 taken（整数百分）＋ 换伤支 taken
static func taken_add(a) -> float:
	if not a is XActor or not on():
		return 0.0
	var add := 0.0
	for k in range(0, XTianqiBrand.realm(a) + 1):
		add += int(_base(k).get("taken", 0)) / 100.0
	for t in trades(a):
		add += float(t.get("taken", 0.0))
	return add


## 第 k 境的境底某一条效果（立到 k 才有）；没有返回空
static func _effect(a, key: String) -> Dictionary:
	if not a is XActor or not on():
		return {}
	for k in range(0, XTianqiBrand.realm(a) + 1):
		var b := _base(k)
		if b.has(key):
			return {"value": b[key], "realm": k}
	return {}


## 不染：被上有害状态（不含战斗不能）的几率乘数
static func state_rate(b, id: int) -> float:
	if id == 1 or not XSmartAI.harmful_state(id):
		return 1.0
	return debuff_rate(b)


## 不染：减益不中的那一份（能力减益直接用；有害状态经 state_rate）
static func debuff_rate(b) -> float:
	var e := _effect(b, "debuff_resist")
	return 1.0 - int(e.value) / 100.0 if not e.is_empty() else 1.0


## 砥柱：战斗里生命低于 below% 时受到的生命回复 ×(1＋up%)（XTianqiBrand.heal 在各线削减、虚不受补之后调）
static func heal(b, amount: float) -> float:
	if amount <= 0.0:
		return amount
	var e := _effect(b, "low_heal")
	if e.is_empty():
		return amount
	if b.hp * 100.0 < b.mhp * float(e.value.get("below", 50)):
		return floorf(amount * (100.0 + float(e.value.get("up", 15))) / 100.0)
	return amount


## 迎劫：一下打来的生命伤害超过最大生命 over% 的部分少受 cut%（只在战斗里、打到我方角色）
static func big_hit(logic, t, value: float) -> float:
	if value <= 0.0 or XTianqiBrand.fight(logic).is_empty():
		return value
	var e := _effect(t, "big_hit")
	if e.is_empty():
		return value
	var line: float = t.mhp * float(e.value.get("over", 50)) / 100.0
	if value <= line:
		return value
	return value - floorf((value - line) * float(e.value.get("cut", 30)) / 100.0)


## 逆命（T514 核 P1-1 返修）：分两步。execute_hp_damage 里只记「这一下真的掉了血」（note_hit：伤害为正、生命确实减少）；
## 这一击结算完、弹字和扣血统计都定了之后（apply 末尾、horseman_strike 末尾），after_hit 再判：每场一次，
## 人还活着、生命在三成以下，就用独立的回复（logic.gain_hp，走资源回复、照吃各线削减和砥柱）回最大生命 heal%。
## 治疗、护盾全挡、没掉血的一下不记，不会误耗掉这一次；不留那 1 点血。
static func note_hit(logic, t, value: float, hp_before: float) -> void:
	if value <= 0.0 or not t is XActor or float(t.hp) >= hp_before:
		return
	var c := XTianqiBrand.fight(logic)
	if c.is_empty() or _effect(t, "rally").is_empty():
		return
	if not c.has(RALLY_HIT):
		c[RALLY_HIT] = []
	if not c[RALLY_HIT].has(t):
		c[RALLY_HIT].append(t)


static func after_hit(logic) -> void:
	var c := XTianqiBrand.fight(logic)
	if c.is_empty() or c.get(RALLY_HIT, []).is_empty():
		return
	var hit: Array = c[RALLY_HIT]
	c[RALLY_HIT] = []
	if not c.has(RALLY):
		c[RALLY] = {}
	for t in hit:
		var e := _effect(t, "rally")
		if e.is_empty() or c[RALLY].has(t) or not logic.actors.has(t) or not t.is_alive() or t.hp <= 0.0:
			continue
		if t.hp * 100.0 >= t.mhp * float(e.value.get("below", 30)):
			continue
		c[RALLY][t] = true
		logic.gain_hp(t, floorf(t.mhp * float(e.value.get("heal", 20)) / 100.0))


# ---- 换支（闭关菜单）----

## 换支的价：没选过免费；否则 swap_price_units 场钱（跟最高到达层走）
static func price(s: XState, a, r: int) -> int:
	if not picked(a, r):
		return 0
	return XTianqiMoney.price(s, float(data().get("swap_price_units", 10)))


## 能不能在这里改分支：稿「在大厅闭关处花钱换……战斗里、里副本里不能换」（养成线 v0.3 第三节第 5 条）。
## 主菜单「真气」在塔层、副本、里副本也能打开，所以按地点拦：只在方桌大厅、不在副本里（T514 核 P1-2）。
## 只拦「换」：这一段还没选过的第一次选是「破境时当场选」（稿同条），心魔可能在别处打，照放
static func may_choose(s: XState, a, r: int) -> bool:
	return not picked(a, r) or can_change(s)



static func can_change(s: XState) -> bool:
	return s != null and int(s.map_id) == XTianqi.HALL_MAP and not XDungeon.inside(s)


## 选／换：成功返回 ""，否则返回提示
static func choose(s: XState, a, r: int, key: String) -> String:
	if not on(s) or not a is XActor or r < 1 or r > XTianqiBrand.realm(a):
		return "—"
	if not may_choose(s, a, r):
		return TEXT_HALL_ONLY
	var b := _find(r, key)
	if b.is_empty() or bool(b.get("hidden", false)):
		return "—"
	if picked(a, r) and str(_store(a)[str(r)]) == key:
		return ""
	var cost := price(s, a, r)
	if cost > 0 and int(s.gold) < cost:
		return TEXT_POOR % [_unit(), cost]
	if cost > 0:
		s.gain_gold(-cost)
	var d := XZhenqi.data(a)
	if not d.get(KEY) is Dictionary:
		d[KEY] = {}
	d[KEY][str(r)] = key
	a.param_mark_dirty()
	XZhenqi.refresh_rewards(a)
	return ""


static func _unit() -> String:
	return str(XDB.system().get("currencyUnit", ""))


## 一支的属性说明：「魔防+3%、生命+3%」／换伤支「伤害+3%、承伤+3%」
static func describe(b: Dictionary) -> String:
	if bool(b.get("trade", false)):
		var t := _trade_row(str(b.get("name", "")))
		return TEXT_TRADE % [roundi(float(t.get("damage", 0)) * 100), roundi(float(t.get("taken", 0)) * 100)]
	var each := int(data().get("branch_pct", 3))
	return "、".join(Array(b.get("params", [])).map(func(k): return TEXT_PARAM % [PARAM_CN[int(PARAM.get(str(k), 0))], each]))


static func picked_count(a) -> int:
	var n := 0
	for r in range(1, XTianqiBrand.realm(a) + 1):
		if picked(a, r):
			n += 1
	return n


## 闭关菜单：这个人各段的分支一览（立到哪段列到哪段）
static func page(s: XState, a) -> Dictionary:
	var opts := []
	for r in range(1, XTianqiBrand.realm(a) + 1):
		var b := branch_of(a, r)
		opts.append({"label": "「%s」%s%s" % [XTianqiBrand.stage_name(r), str(b.get("name", "")), "" if picked(a, r) else TEXT_UNPICKED],
			"next": {"page": "branch_pick", "id": a.actor_id, "r": r}})
	opts.append({"label": "返回", "next": {"page": "actor", "id": a.actor_id}})
	return {"lines": [TEXT_HEAD[0] % a.display_name(), TEXT_HEAD[1] % _unit()], "options": opts}


## 闭关菜单：某一段的几支（选了就回到一览）
static func pick_page(s: XState, a, r: int) -> Dictionary:
	if not on(s) or r < 1 or r > XTianqiBrand.realm(a):
		return page(s, a)
	var cur := branch_of(a, r)
	var cost := price(s, a, r)
	var opts := []
	var ok := may_choose(s, a, r)
	for b in branches(r):
		var mine := str(b.get("key", "")) == str(cur.get("key", "")) and picked(a, r)
		# 不在大厅：照样列出几支看属性，点了回到本页（不落到 branch_set）
		var nxt := {"page": "branch_set", "id": a.actor_id, "r": r, "k": str(b.get("key", ""))} if ok else {"page": "branch_pick", "id": a.actor_id, "r": r}
		opts.append({"label": "%s：%s%s" % [str(b.get("name", "")), describe(b), "（当前）" if mine else ""], "next": nxt})
	opts.append({"label": "返回", "next": {"page": "branch", "id": a.actor_id}})
	var tail := TEXT_HALL_ONLY if not ok else (TEXT_COST_PAID % [cost, _unit()] if cost > 0 else TEXT_COST_FREE)
	return {"lines": [TEXT_PICK_HEAD % [a.display_name(), XTianqiBrand.stage_name(r), str(cur.get("name", "")), "" if picked(a, r) else TEXT_UNPICKED], tail], "options": opts}


static func set_page(s: XState, a, r: int, key: String) -> Dictionary:
	var msg := choose(s, a, r, key)
	if msg == "":
		return {"lines": [TEXT_DONE % [a.display_name(), XTianqiBrand.stage_name(r), str(_find(r, key).get("name", ""))]], "options": [], "next": {"page": "branch", "id": a.actor_id}}
	return {"lines": [msg], "options": [], "next": {"page": "branch_pick", "id": a.actor_id, "r": r}}
