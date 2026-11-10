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

## 开关（O-待定·天启篇装备栏）：true＝天启篇存档按 13 栏；false＝天启篇存档也照原版 19 栏（含软绑定被动、坐骑封印）。
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
	return etype != ARTIFACT or ARTIFACTS.has(int(item.get("base", item.get("id", 0))))


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
