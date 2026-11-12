class_name XTianqiGear
extends RefCounted
## 天启篇第③步：装备栏（数值重构方案第八节第 9 条，Kyo 2026-11-08 14:36／14:39／14:42／14:43；神器栏 Kyo 2026-11-11 00:23）。
## 只在天启篇存档生效（XTianqi.active：flags.tianqi 规则版本），原版开局建的档、测试直接建的状态照原版 19 栏。
##
## 13 个栏位，排列（Kyo 14:42 采纳）：武器、副手｜头部、盔甲、护手、腰带、裤子、鞋子｜项链、戒指｜法宝、坐骑｜神器。
## - 戒指只有 1 个（原版本来就只有一个戒指类型 10）。
## - 删掉宝物 11、护符 12、灵兽 14、圣器 15、宝宝 18、形态 19：不显示、不能装；身上已有的卸回背包，开局自带的（天虎令、长崎爽世、椎名立希）直接不装。
## - 神器（Kyo 11-11 加的第 13 栏）：放独特物件，沿用原神武的装备类型 17，只认 ARTIFACTS 白名单；原神武里不在名单上的（黎明—破晓、禁锢之皇冕）不能装。
##   法宝因此只剩通用、专属两类（专属靠 <req_actors> 挡别人，原有判定）。
## - 坐骑：难度适应 1691 开战封印坐骑（特性 54 → 16）不再沿用（方案第八节第 9 条）；1691 对圣器、宝宝、形态的封印随栏位删除失效。
##
## 删除栏位上的软绑定（删除栏位角色专属物清单 v0.1，Kyo 11-11 00:04「根据你的建议来」）：
## - 茉蕾：觉醒（1752）时学「嘤雄」（沿用 6242 究极嘤雄的技能号，动作序列里 _skills.includes(6242) 那 3 段只算一次），
##   入队学「强化·嘤嘤嘤」2797（只留一档）。
## - 宇智波·鼬：入队学「通灵·乌鸦」7475，天启篇里补成生效的被动，不要求装备乌鸦。
## - 小龙人加段、渡鸦旧档配方、开局自带装：不迁移（栏位删了自然失效）。
## 两个被动的增伤是占位（SOFT_PASSIVES 里的 rate），档位数值那一步按标准线重标；嘤雄改名和说明都只在天启篇的技能视图里换，原版数据不动。

## 开关（O-266）：true＝天启篇存档按 13 栏；false＝天启篇存档也照原版 19 栏（含软绑定被动、坐骑封印）。
static var ENABLED := true

const MOUNT := 16
const ARTIFACT := 17
const ARTIFACT_NAME := "神器"
## 天启篇栏位排列（装备类型号）；装备数组照旧 19 格、按原槽位存（存档格式不变），这里只决定显示哪些、按什么顺序。
const ORDER := [1, 2, 3, 4, 6, 8, 5, 7, 9, 10, 13, 16, 17]
## 神器栏白名单（Armors 编号）：五件成长物（心之钢、杰作利维坦、狂妄、杰作无我、"头顶"）＋三件玩家纪念物（仙道模式两版、神魔战纹、游戏王的嘴炮）。
## 纪念物效果到设计神器时重做；成长物的成长上限在档位数值那一步加。
const ARTIFACTS := [7900, 7901, 7902, 7903, 7940, 4279, 5198, 4536, 4538]

const MOLEI := 7
const MOLEI_AWAKEN := 1752
const ITACHI := 91
## 天启篇给的技能：角色 → [[技能, 学会时机（0＝入队，否则学会该技能时）], …]
const GRANTS := {MOLEI: [[2797, 0], [6242, MOLEI_AWAKEN]], ITACHI: [[7475, 0]]}
## 软绑定被动在天启篇的技能视图（占位数值：Kyo 数值规则，整数、不带 4）
const SOFT_PASSIVES := {
	6242: {"name": "嘤雄", "skills": [3518, 4774, 4775], "rate": 100,
		"text": "茉蕾的“一袋米扛几楼”和“一桶油喝几斤”额外增加三段伤害，伤害+%d%%",
		"desc": "嘤嘤怪的力量已经化为茉蕾自己的本事。"},
	7475: {"name": "", "skills": [7465, 7466, 7467, 7471, 7472, 7473], "rate": 100,
		"text": "独特技能增伤+%d%%", "desc": ""},
}


static func on(s: XState = null) -> bool:
	if not ENABLED:
		return false
	return XTianqi.active(s if s != null else XState.current)


## 这个装备类型的栏位在天启篇还在
static func open_type(etype: int) -> bool:
	return not on() or ORDER.has(etype)


## 栏位名：天启篇里类型 17 叫神器
static func type_name(etype: int) -> String:
	if etype == ARTIFACT and on():
		return ARTIFACT_NAME
	var types: Array = XDB.system().get("equipTypes", [])
	return str(types[etype]) if etype >= 0 and etype < types.size() else ""


## 显示用的槽位（槽位序号的列表，按天启篇排列；不是天启篇就是 0..n-1）
static func view(a: XActor) -> Array:
	var slots := a.equip_slots()
	var out := []
	if not on():
		for i in range(slots.size()):
			out.append(i)
		return out
	var base := []  # 槽位序号 → 原装备类型（双持时第 2 格类型变成 1，排列仍按副手位置）
	for i in range(slots.size()):
		base.append(i + 1)
	if XCat.own(a):
		base = base.filter(func(t): return t != 2)
	for t in ORDER:
		var i := base.find(t)
		if i >= 0 and i < slots.size():
			out.append(i)
	return out


## 天启篇里这件装备能不能穿（只看栏位与神器白名单；角色、等级等照 can_equip 原判定）
static func allows(item: Dictionary) -> bool:
	if not on() or item.is_empty() or str(item.get("kind", "")) == "weapon":
		return true
	var etype := int(item.get("etypeId", 0))
	if not ORDER.has(etype):
		return false
	return etype != ARTIFACT or ARTIFACTS.has(int(item.get("base", item.get("id", 0)))) or XTianqiRewards.is_relic(item) \
		or str(XTianqiQiyinEffects.mark_of(item).get("kind", "")) == "artifact"  # 骑士遗物、七印神器


## 特性 54 的封印在天启篇不算的：坐骑（难度适应 1691 的封印不再沿用）
static func seal_ignored(etype: int) -> bool:
	return etype == MOUNT and on()


## 角色建好时（XActor.setup 末尾）：天启篇给的入队技能
static func on_setup(a: XActor) -> void:
	if not on():
		return
	for g in GRANTS.get(a.actor_id, []):
		if int(g[1]) == 0 or a.skill_ids.has(int(g[1])):
			a.learn_skill(int(g[0]))


## learn_skill 之后：学会觉醒等时机技能时给对应的技能
static func learned(a: XActor, id: int) -> void:
	if not on():
		return
	for g in GRANTS.get(a.actor_id, []):
		if int(g[1]) == id and not a.skill_ids.has(int(g[0])):
			a.learn_skill(int(g[0]))


## 技能视图（XActor._skill_records）：天启篇里软绑定被动换成生效的版本
static func skill_view(s: Dictionary) -> Dictionary:
	var id := int(s.get("id", 0))
	if not SOFT_PASSIVES.has(id) or not on():
		return s
	var p: Dictionary = SOFT_PASSIVES[id]
	if _views.has(id) and is_same(_views[id][0], s):
		return _views[id][1]
	var v := s.duplicate(true)
	if str(p.name) != "":
		v.name = p.name
	if str(p.desc) != "":
		v.description = "被动\n" + str(p.desc)
	var meta: Dictionary = v.get("meta", {}).duplicate()
	for sid in p.skills:
		meta["SkillPass%04d" % int(sid)] = "%d%%" % int(p.rate)
	v.meta = meta
	# 说明卡读备注里的 <pos=APs text=…>：换成天启篇的效果行
	var note := _APS.sub(str(v.get("note", "")), "", true)
	v.note = note + "<pos=APs text=\\c[1]效果:%s size=18 color=rgba(255,255,255,1) line=false align=0> " % (str(p.text) % int(p.rate))
	_views[id] = [s, v]
	return v

static var _views := {}
static var _APS := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]效果:[^>]*>")


# ==== 第二批（交接单「装备栏下一批」，Max 发、Kyo 11-08 规则）：删除栏位物品清理、坐骑管速度先手、神器成长上限 ====
## 三件事都只在天启篇存档生效（on() 为真），原版档、原版对照不变；各一个开关，默认开。
## 数值（坐骑表、神器上限、重抽等级段）在 tianqi_data/gear_table.json，都是占位（draft），不带 4（天启篇数据校验.py 查）。

## A（O-327）：商店不卖删除栏位的防具；随机掉落抽到的换成同品质、同等级段、保留栏位的装备（重抽一次，池空才不给）。
## false＝回到第一批（商店照卖、掉落照给，只是穿不上）。事件、宝箱直接发放的不归这里管（搬图时处理）。
static var CLEAN_DELETED := true
## B（O-328）：坐骑本体只给敏捷百分比与先制几率（按品质查表），原来身上的特性、属性、开战状态在天启篇不算。
## false＝回到第一批（坐骑照原版数据生效，没有表里的加成）。
static var MOUNT_STATS := true
## C（O-329）：心之钢／杰作利维坦、狂妄／杰作无我的阶数、"头顶"的八项加成，算效果时夹上限；存档里的层数、盛名、成长不截。
## false＝回到第一批（无上限，同原版）。
static var ARTIFACT_CAP := true

const TABLE_PATH := "res://modes/xiyou/tianqi_data/gear_table.json"
static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
		if f == null:
			push_error("XTianqiGear: 读不到 " + TABLE_PATH)
			return {}
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_table = parsed
		else:
			push_error("XTianqiGear: JSON 解析失败 " + TABLE_PATH)
	return _table


## 测试用：清掉缓存，下次重新读文件（反向验证改表后用）
static func reload() -> void:
	_table = {}
	_drop_pool = []


# ---- A. 删除栏位的物品不上架、不掉落 ----

## 这件防具（数据库编号）在天启篇的删除栏位上
static func deleted_armor(id: int) -> bool:
	var r := XDB.rec("Armors", id)
	return not r.is_empty() and not ORDER.has(int(r.get("etypeId", 0)))


## Scene_Shop.prepare 外层（XShopStock.prepare_policy 调）：商品表去掉删除栏位的防具。商品 [种类 0 物品／1 武器／2 防具, 编号, 价格类型, 价格]
static func shop_goods(goods: Array) -> Array:
	if not CLEAN_DELETED or not on():
		return goods
	return goods.filter(func(g): return not (int(g[0]) == 2 and deleted_armor(int(g[1]))))


## 重抽的分组：[品质（七档）, 等级段]
static func drop_group(rec: Dictionary) -> Array:
	var band := maxi(1, int(table().get("drop_reroll", {}).get("level_band", 10)))
	return [XQuality.grade(rec), floori(float(int(rec.get("meta", {}).get("req_level", 0))) / band)]


## 能进重抽池的：保留栏位（不含神器栏）、不是专属（<req_actors>）
static func _reroll_ok(kind: int, rec: Dictionary) -> bool:
	if rec.is_empty() or str(rec.get("name", "")) == "":
		return false
	if XEquipment._req_actors_re.search(str(rec.get("note", ""))) != null:
		return false
	if kind == 2:
		return true
	var etype := int(rec.get("etypeId", 0))
	return ORDER.has(etype) and etype != ARTIFACT


## 全部敌人掉落表里出现过的武器、防具 [种类 2／3, 编号]（掉落种类同 dropItems）：重抽只从「本来就会掉的」里挑，不会掉出任务物、专属物
static var _drop_pool: Array = []
static func drop_pool() -> Array:
	if _drop_pool.is_empty():
		var seen := {}
		var enemies = XDB.table("Enemies")
		for e in (enemies if enemies is Array else []):
			if not e is Dictionary:
				continue
			var rows := []
			for d in e.get("dropItems", []):
				if int(d.get("kind", 0)) in [2, 3] and float(d.get("denominator", 0)) > 0:
					rows.append([int(d.kind), int(d.dataId)])
			for x in XBattleLogic._extra_drops(e):
				if int(x.kind) in [2, 3]:
					rows.append([int(x.kind), int(x.id)])
			for r in rows:
				var key := "%d:%d" % r
				if not seen.has(key):
					seen[key] = true
					_drop_pool.append(r)
		_drop_pool.sort()
	return _drop_pool


## 和 rec（删除栏位的防具）同品质、同等级段的保留栏位装备 [[种类, 编号], …]（编号升序，结果可复现）；pool 给数组时代替掉落表（测试用）
static func reroll_pool(rec: Dictionary, pool = null) -> Array:
	var want := drop_group(rec)
	var out := []
	for r in (pool if pool is Array else drop_pool()):
		var other := XDB.rec("Weapons" if int(r[0]) == 2 else "Armors", int(r[1]))
		if _reroll_ok(int(r[0]), other) and drop_group(other) == want:
			out.append(r)
	return out


## 敌人掉落（XBattleLogic.drops_of，屏蔽掉落之前）：删除栏位的防具在同组里重抽一次（roll 每件取一个 0～1 随机数）；池空就不给
static func reroll_drops(drops: Array, roll: Callable, pool = null) -> Array:
	if not CLEAN_DELETED or not on():
		return drops
	var out := []
	for d in drops:
		if int(d.get("kind", 0)) != 3 or not deleted_armor(int(d.id)):
			out.append(d)
			continue
		var cands := reroll_pool(XDB.rec("Armors", int(d.id)), pool)
		if cands.is_empty():
			continue
		var pick: Array = cands[clampi(floori(float(roll.call()) * cands.size()), 0, cands.size() - 1)]
		var nd: Dictionary = d.duplicate()
		nd.kind = int(pick[0])
		nd.id = int(pick[1])
		nd["tianqi_reroll"] = int(d.id)
		out.append(nd)
	return out


# ---- B. 坐骑管速度和先手 ----

static func mount_on() -> bool:
	return MOUNT_STATS and on()


## 这件是天启篇的普通坐骑（坐骑栏的装备；独特坐骑本批不做，以后在表里另列）
static func plain_mount(item) -> bool:
	return item is Dictionary and not item.is_empty() and str(item.get("kind", "")) == "armor" \
		and int(item.get("etypeId", 0)) == MOUNT and mount_on()


## 坐骑按品质（七档 0 普通～6 神话）的一行：{agi, preempt}，都是百分数
static func mount_row(item: Dictionary) -> Dictionary:
	var m: Dictionary = table().get("mount", {})
	var g := clampi(XQuality.grade(item), 0, 6)
	var agi: Array = m.get("agi_pct", [])
	var pre: Array = m.get("preempt_pct", [])
	return {"agi": float(agi[g]) if g < agi.size() else 0.0, "preempt": float(pre[g]) if g < pre.size() else 0.0}


static func mount_of(a) -> Dictionary:
	if a is XActor:
		for e in a.equip_list():
			if plain_mount(e):
				return e
	return {}


## 算能力值、特性用的装备列表（XActor.stat_equips／_param_plus）：普通坐骑原来的特性、属性、开战状态在天启篇不算
static func stat_list(list: Array) -> Array:
	if not mount_on():
		return list
	return list.filter(func(e): return not plain_mount(e))


## Game_Actor.param 包装（专属模块、心钢、狂妄、小猫剑圣之后，云裳夹值之前）：坐骑的敏捷百分比
static func param(a, i: int, v: float) -> float:
	if i != 6 or not mount_on():
		return v
	var m := mount_of(a)
	if m.is_empty():
		return v
	return roundf(v * (1.0 + float(mount_row(m).agi) / 100.0))


## 全队坐骑先制几率（0～1）：上场成员（battle_members，助力位不算）身上坐骑取最高一件，不相加
static func mount_preempt(s: XState) -> float:
	if not mount_on() or s == null:
		return 0.0
	var best := 0.0
	for a in s.battle_members():
		var m := mount_of(a)
		if not m.is_empty():
			best = maxf(best, float(mount_row(m).preempt))
	return best / 100.0


## 随机遇敌的先制率（XBattleLogic.roll_encounter，XPreempt.rates 之后）：加上坐骑先制，加完不超过总上限；
## 原来的先制率已经超过上限的不往下压（上限只管坐骑加出来的部分）。偷袭率不变。
static func apply_preempt(s: XState, rate: Dictionary) -> Dictionary:
	var bonus := mount_preempt(s)
	if bonus <= 0.0:
		return rate
	var cap := float(table().get("mount", {}).get("preempt_cap_pct", 33)) / 100.0
	rate.pre = maxf(float(rate.pre), minf(float(rate.pre) + bonus, cap))
	return rate


# ---- C. 神器成长上限 ----

static func cap_on() -> bool:
	return ARTIFACT_CAP and on()


static func _cap(key: String) -> float:
	return float(table().get("artifact_cap", {}).get(key, 0))


## 心之钢／杰作利维坦的有效阶数
static func heart_stage(n: int) -> int:
	return mini(n, int(_cap("heartsteel_stage"))) if cap_on() and _cap("heartsteel_stage") > 0.0 else n


## 狂妄／杰作无我的有效阶数
static func hubris_stage(n: int) -> int:
	return mini(n, int(_cap("hubris_stage"))) if cap_on() and _cap("hubris_stage") > 0.0 else n


## "头顶"的有效八项加成（百分数）
static func crown_bonus(b: float) -> float:
	return minf(b, _cap("crown_bonus_pct")) if cap_on() and _cap("crown_bonus_pct") > 0.0 else b


## 说明行后缀：成长到了上限（原值 ≥ 上限）时「（已达上限）」；key 是 artifact_cap 里的键
const CAP_TEXT := "（已达上限）"
static func cap_note(key: String, raw: float) -> String:
	return CAP_TEXT if cap_on() and _cap(key) > 0.0 and raw >= _cap(key) else ""
