class_name XDeadContent
extends RefCounted
## 【cc·悟空·未经审查】死内容做活的数据补丁（Kyo 11-05「死内容做活」，总装按授权定做法）。XDB 读进地图／公共事件时就地改，
## 开关关掉后 clear_cache() 清缓存（别叫 reload：那是 Script.reload，会把静态变量重置回默认）即回原版数据。每条一个开关、一个 O 号（见 00_设计/优化登记.md）。
##
## O-待定 一护卍解（Map213 住轮天外 EV2）：冻结 v0.28 里这事件引用的编号全失效——条件角色 109（现在是「牢大」，一护是 148）、
## 敌群 962 无成员、奖励物品 2852 与武器 807 是空白条目，变量 1309／1311 无处写入。原作者重排编号后没回来改，原本挑战谁、给什么无从还原，
## 下面是按名字与现有数据的猜测重接：
## - 招募 CE2508（伙伴号角：黑崎一护）加完 148 后置变量 1309＝1（同 CE1653 招绯红蔷薇置 1318 的写法）；
## - 第 1 页：条件角色 109→148、不再要变量 1309（旧档里早招了一护的也能碰到），页首补置 1309＝1；页内「一护在队」判断 109→148；
##   打的敌群 962→733【首领】清风（同属 29 层：Map212 太上老君藏身处的首领，敌人能力与经验和 29 层守层者相当，敌群事件只有开场一次状态＋强制技能，没有开关副作用）；
##   胜后物品 2852→武器 71「斩月-II」，并置 1311＝1（第 2 页「你还没获得斩月-II？」的判断）；
## - 第 2、3 页：武器 807→72「卍解-斩月-II」（第 2 页给、第 3 页「简单的刷孔」判有无并重置）。
## 开关 ICHIGO_BANKAI＝false 回原版。
##
## O-待定 魔法领域魔攻（CE2478）：说明「全员获得奈叶等级×1% 的全属性加成」，CE 里七项给全队、魔攻 1783 只给奈叶（313 [0,108,0,1783]）；
## 改成全队（[0,0,0,1783]）。开关 DOMAIN_ALL_MATK＝false 回原版。领域本身能不能触发见 XNanoha.DOMAIN_LIVE。

static var ICHIGO_BANKAI := true
static var DOMAIN_ALL_MATK := true

const ICHIGO := 148
const ICHIGO_TROOP := 733
const ZANGETSU_II := 71
const BANKAI_ZANGETSU_II := 72


## 清掉 XDB 里受影响的缓存，下次读按当前开关重新打补丁
static func clear_cache() -> void:
	XDB._tables.erase("map:213")
	XDB._tables.erase("CommonEvents")


static func patch_map(map_id: int, data) -> void:
	if map_id == 213 and ICHIGO_BANKAI and data is Dictionary:
		_patch_ichigo_event(data)


static func patch_common_events(t) -> void:
	if not (t is Array):
		return
	if ICHIGO_BANKAI and t.size() > 2508 and t[2508] is Dictionary:
		var list: Array = t[2508].get("list", [])
		var i := list.find_custom(func(c): return int(c.code) == 129 and int(c.parameters[0]) == ICHIGO)
		if i >= 0:
			list.insert(i + 1, _set_var(1309, int(list[i].indent)))
	if DOMAIN_ALL_MATK and t.size() > 2478 and t[2478] is Dictionary:
		for c in t[2478].get("list", []):
			if int(c.code) == 313 and int(c.parameters[1]) == XNanoha.ACTOR and int(c.parameters[3]) == 1783:
				c.parameters[1] = 0


static func _set_var(id: int, indent: int) -> Dictionary:
	return {"code": 122, "indent": indent, "parameters": [id, id, 0, 0, 1]}


static func _patch_ichigo_event(m: Dictionary) -> void:
	var ev = null
	for e in m.get("events", []):
		if e is Dictionary and int(e.get("id", 0)) == 2:
			ev = e
	if ev == null or (ev.pages as Array).size() < 3:
		return
	var p0: Dictionary = ev.pages[0]
	if int(p0.conditions.actorId) != 109:
		return  # 来源数据变了就不动
	p0.conditions.actorId = ICHIGO
	p0.conditions.variableValid = false
	var list: Array = p0.list
	for idx in range(list.size() - 1, -1, -1):
		var c: Dictionary = list[idx]
		match int(c.code):
			111:
				if int(c.parameters[0]) == 4 and int(c.parameters[1]) == 109:
					c.parameters[1] = ICHIGO
			301:
				if int(c.parameters[0]) == 0 and int(c.parameters[1]) == 962:
					c.parameters[1] = ICHIGO_TROOP
			126:
				if int(c.parameters[0]) == 2852:
					list[idx] = {"code": 127, "indent": c.indent, "parameters": [ZANGETSU_II, 0, 0, 1, false]}
					list.insert(idx + 1, _set_var(1311, int(c.indent)))
	list.insert(0, _set_var(1309, 0))
	for pi in [1, 2]:
		for c in ev.pages[pi].list:
			if int(c.code) == 127 and int(c.parameters[0]) == 807:
				c.parameters[0] = BANKAI_ZANGETSU_II
			elif int(c.code) == 111 and int(c.parameters[0]) == 9 and int(c.parameters[1]) == 807:
				c.parameters[1] = BANKAI_ZANGETSU_II
