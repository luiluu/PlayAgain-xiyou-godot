class_name XTianqiTrim
extends RefCounted
## 【cc·天启篇·未经审查】天启篇里关掉、改读档位表的原版难度挂钩（天启篇设计总览 v0.2 第四、五节；审查线开工单甲、乙两组）。
## 只认天启篇存档（XTianqi.active），原版档不变。各项一个开关，设 false 回到改之前。
##
## - O-405 LAODA：大厅牢妲（Map004 EV062）在天启篇只剩「挑战强大的守层者」：打过的 34～36 层（XTianqiSummit 再挑战）、
##   30～33 层守层者、兑换商店。难度 debuff 开关、选择怪物难度属性、花积分开启都不出（原版进菜单时还会关掉全部难度开关，含洪荒 2483）。
## - O-406 ROSTER：破阵·投影的强者／超强者名单改读天启篇档位表（XTianqiSkills.ids），说明换成天启篇的出伤加成与各档超强者上限。
## - O-407 DIFF_NAME：地图左下的难度名（XMapHud.difficulty_text）、难度变化提示（XDifficultyNotice）显示五档档名。
## - O-408 HIDE_AFFIX_RATE：修行·详细页末尾的「高阶词条概率」一段不显示（XAffixRate.detail_rows）。
## - O-410 NO_HONGHUANG：洪荒通关奖励取消（XTianqiSummit._honghuang 不跑）；大厅 EV065 洪荒女皇、EV066 兑换大厅传送、
##   EV068 强者的礼物不出现；混元星河剑 4555、黎明—破晓 5199、技能书免疫转换 1991 不上架；仙道模式 5198 并进人族首领 EV054 的神武页。
## - O-412 ROUTE_TABLE：真气路线系数、流萤残核掉率、星爆书概率、开局抽奖被动上限（变量 9）读 balance_table 的 routes（按吸收的旧路线映射）。
## 另两项开关在各自模块：O-409 XTianqiAffixRoll.SKIP_HIGH_ROWS、O-411 XTianqiCombat.DUNGEON_TIER。

static var LAODA := true
static var ROSTER := true
static var DIFF_NAME := true
static var HIDE_AFFIX_RATE := true
static var NO_HONGHUANG := true
static var ROUTE_TABLE := true

const HALL_MAP := 4
const LAODA_EVENT := 62
## 30～33 层守层者敌群（原 EV062「挑战强大的守层者」）
const GUARDIAN_TROOPS := {30: 466, 31: 467, 32: 468, 33: 469}
const EXCHANGE_SHOP := [0, 1060, 0, 0, false]
const HONGHUANG_EVENTS := [65, 66, 68]
## 不上架：[类型, 编号]（0 物品、1 武器、2 防具）
const NO_SALE := [[2, 4555], [2, 5199], [0, 1991]]
const SHOP_EVENT := 54
## 人族首领神武页的第一件（这一页才并进仙道模式）
const DIVINE_PAGE_FIRST := 4279
const XIANDAO := [2, 5198, 0, 0]


static func on(s) -> bool:
	return s != null and XTianqi.active(s)


static func _key(s: XState) -> String:
	return str(s.flags.tianqi.get("difficulty", ""))


# ---- 难度名（O-407） ----

## 本档档名，在副本里后面接副本档（「九死·王者」）；不是天启篇存档或开关关着为空
static func difficulty_name(s) -> String:
	if not DIFF_NAME or not on(s):
		return ""
	var name := str(XTianqi.difficulty(_key(s)).get("name", ""))
	if XDungeon.inside(s):
		var t := XTianqiBalance.dungeon_tier(int(s.variable(XDungeon.VAR_TIER)))
		if not t.is_empty():
			name += "·" + str(t.get("name", ""))
	return name


# ---- 修行页（O-408） ----

static func hide_affix_rate(s) -> bool:
	return HIDE_AFFIX_RATE and on(s)


# ---- 路线系数（O-412） ----

## 本档的路线系数一行；不是天启篇存档、开关关着或表里没有为空
static func route(s) -> Dictionary:
	if not ROUTE_TABLE or not on(s):
		return {}
	return XTianqiBalance.route(_key(s))


# ---- 强者名单（O-406） ----

## 天启篇的名单：{ids, notes}；不接管为空
static func roster(kind: String, s) -> Dictionary:
	if not ROSTER or not on(s):
		return {}
	var tier := XTier.SUPER if kind == "super" else XTier.STRONG
	var bonus := int(roundf(float(XTianqiBalance.tier(tier).get("damage_dealt", 0.0)) * 100.0))
	var notes := ["天启篇档位：出伤 +%d%%。" % bonus]
	if kind == "super":
		var caps := []
		for d in XTianqi.DIFFICULTIES:
			caps.append("%s %d" % [str(d.name), int(XTianqiBalance.difficulty(str(d.key)).get("super_cap", 0))])
		notes.append("每场上阵上限：" + "，".join(caps) + "。")
		notes.append("多出来的只能当替补。")
	return {"ids": XTianqiSkills.ids(tier), "notes": notes}


# ---- 洪荒（O-410） ----

static func no_honghuang(s) -> bool:
	return NO_HONGHUANG and on(s)


## MVEvent._find_page：天启篇大厅不出洪荒女皇、兑换大厅传送、强者的礼物
static func hides(map_id: int, event_id: int) -> bool:
	return map_id == HALL_MAP and HONGHUANG_EVENTS.has(event_id) and no_honghuang(XState.current)


## 指令 302 的货单：天启篇去掉洪荒女皇独有的三件，人族首领神武页加上仙道模式
static func shop_goods(s, map_id: int, event_id: int, goods: Array) -> Array:
	if not no_honghuang(s):
		return goods
	var out := goods.filter(func(g): return not NO_SALE.any(func(n): return int(g[0]) == int(n[0]) and int(g[1]) == int(n[1])))
	if map_id == HALL_MAP and event_id == SHOP_EVENT and out.any(func(g): return int(g[0]) == 2 and int(g[1]) == DIVINE_PAGE_FIRST) \
			and not out.any(func(g): return int(g[0]) == int(XIANDAO[0]) and int(g[1]) == int(XIANDAO[1])):
		out.append(XIANDAO.duplicate())
	return out


# ---- 牢妲（O-405） ----

static func intercepts(s, map_id: int, event_id: int) -> bool:
	return LAODA and on(s) and map_id == HALL_MAP and event_id == LAODA_EVENT


## 牢妲的选项：[[文字, 动作]]，动作 ["summit", 层] / ["guard", 敌群] / ["shop"]，最后一项「离开」
static func laoda_options(s: XState) -> Array:
	var out := []
	for n in XTianqiSummit.rechallenge_options(s):
		out.append([XTianqiSummit._rechallenge_label(s, int(n)), ["summit", int(n)]])
	for f in [30, 31, 32, 33]:
		out.append(["挑战%d层守层者" % f, ["guard", int(GUARDIAN_TROOPS[f])]])
	out.append(["兑换商店", ["shop"]])
	out.append(["离开", []])
	return out


static func run_laoda(host, s: XState) -> void:
	var opts := laoda_options(s)
	var labels := opts.map(func(o): return str(o[0]))
	var i: int = await host.show_text_with_choices("", 0, ["\\n<牢妲>挑战强大的守层者"], labels, labels.size() - 1)
	if i < 0 or i >= opts.size():
		return
	var act: Array = opts[i][1]
	if act.is_empty():
		return
	match str(act[0]):
		"summit":
			await XTianqiSummit.rechallenge(host, s, int(act[1]))
		"guard":
			if host is XMapScene:
				XAutoSave.battle_checkpoint(host, true)  # 同指令 301：开战前检查点
			var troop := int(act[1])
			var r: int = await host.start_battle(troop, false, true)
			XDungeon.battle_finished(troop, r, s.map_id)
		"shop":
			XShopStock.set_context(HALL_MAP, LAODA_EVENT)
			await host.open_shop(shop_goods(s, HALL_MAP, LAODA_EVENT, [EXCHANGE_SHOP.duplicate()]), bool(EXCHANGE_SHOP[4]))
			XShopStock.shop_context = {}
