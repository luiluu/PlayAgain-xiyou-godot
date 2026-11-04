class_name XTestMode
extends RefCounted
## 设置页「测试模式」「GM 工具」（原版 installTestModeRuntime v1.4.0 的移植，只在 Kyo 本机解锁）。
##
## 解锁：只认本机一个文件 user://modes/xiyou/test_mode_unlock（user:// 在工程之外，不进 Git、不进导出包；
## 内容随意，有这个文件就算解锁，仓库里不放任何密钥或密码）。没有这个文件时设置页两项照旧留灰，
## 下面所有功能都返回「关」，GM 工具场景也打不开。原版靠作者密钥文件／联网密码验证，这里不移植。
## 开关状态（打开了没有）存在同目录 test_mode_state，只有解锁时才读写。
##
## 测试模式打开时（原版同）：
## - 战斗经验 ×10（Game_Troop.expTotal）；
## - 角色用过的技能（战斗中付过费的）使用后直接升到当前上限（难度变量 8／变量 13、异化借用／拟态再夹角色等级）；
## - 普通（非 Boss）敌人掉的装备：词缀掷骰几率 ×35、60% 取可选词缀里品质最高的一组，最多 4 个词缀，
##   词缀只来自装备原配置的可选行；已有 13 档以上品质的词缀不会被后面的普通词缀盖掉。
## GM 工具（设置里「GM 工具」，要先开测试模式并已进入游戏）：加物品／装备、加金币、加经验、全队恢复、
## 肝帝积分／人道碎片／天道币／逆天币的增加或设为。会直接写进存档，和原版一样。
## 没移植：主菜单上的「GM 工具」入口、战斗外菜单用技能的熟练度训练、「待提交反馈」（要原版服务器）。

const UNLOCK_PATH := "user://modes/xiyou/test_mode_unlock"
const STATE_PATH := "user://modes/xiyou/test_mode_state"
const EXP_RATE := 10
const MAX_AFFIXES := 4
const AFFIX_RATE := 35.0

## 测试用：非空时替代上面两个路径
static var unlock_override := ""
static var state_override := ""
## 掉落装备词缀加速的作用深度（> 0 时 XGear.roll_item 走加速分支）
static var boost_depth := 0
static var _on := false
static var _on_loaded_from := "<unloaded>"


static func unlock_path() -> String:
	return unlock_override if unlock_override != "" else UNLOCK_PATH


static func state_path() -> String:
	return state_override if state_override != "" else STATE_PATH


static func unlocked() -> bool:
	return FileAccess.file_exists(unlock_path())


static func _load_state() -> void:
	var p := state_path()
	if p == _on_loaded_from:
		return
	_on_loaded_from = p
	_on = FileAccess.file_exists(p) and FileAccess.get_file_as_string(p).strip_edges() == "1"


static func enabled() -> bool:
	if not unlocked():
		return false
	_load_state()
	return _on


static func set_enabled(v: bool) -> void:
	if not unlocked():
		return
	_load_state()
	_on = v
	DirAccess.make_dir_recursive_absolute(state_path().get_base_dir())
	var f := FileAccess.open(state_path(), FileAccess.WRITE)
	if f != null:
		f.store_string("1" if v else "0")
		f.close()


## T.canOpen：已开测试模式、有存档在手
static func can_open(s: XState) -> bool:
	return enabled() and s != null


static func exp_rate() -> int:
	return EXP_RATE if enabled() else 1


# ---- 技能熟练度（使用后升满当前上限）----
static func mastery_cap(b: XActor, skill_id: int) -> int:
	var cap := XSkillMastery.max_level(skill_id)
	if cap <= 0:
		return 0
	var s := XState.current
	if s != null:
		var limit := int(s.variable(8))
		if limit > 0 and (int(s.variable(13)) == 1 or (b.actor_id == 172 and skill_id >= 10229 and skill_id <= 10238)):
			cap = mini(cap, limit)
	var d := XAlienation.for_actor(b)
	if not d.is_empty():
		if str(d.affix) == "faceless":
			for p in d.config.get("pairs", []):
				if int(p.get("skillId", 0)) == skill_id and s != null:
					var owner := s.actor(int(p.get("ownerId", 0)))
					return maxi(0, mini(mini(cap, b.level), mini(owner.level, XSkillMastery.level(owner, skill_id))))
		elif str(d.affix) == "mimic" and (d.get("observed", []) as Array).has(skill_id):
			cap = mini(cap, b.level)
	return maxi(0, cap)


## onAllActionsEnd 之前取一份这次付过费的技能（没开测试模式、不是角色返回空）
static func used_skills(b) -> Array:
	if not b is XActor or not enabled():
		return []
	var out := []
	for id in b.action_mastery:
		if not out.has(int(id)):
			out.append(int(id))
	return out


static func train(b, used: Array) -> void:
	for id in used:
		var cap := mastery_cap(b, int(id))
		if cap > 0 and XSkillMastery.level(b, int(id)) < cap:
			XSkillMastery.set_level(b, int(id), cap)


# ---- 掉落装备词缀加速 ----
## 对一件装备模板掷词缀（替代 XGear.roll_item 里按预掷池的那一段）；用 randf，和原版 Math.random 一样不进预掷池
static func roll_affixes(item: Dictionary, rows: Array, table: String) -> void:
	var pending := []
	for row in rows:
		var weight := 0.0
		for c in row.choices:
			if float(c.chance) > 0.0 and (c.ids as Array).any(func(n): return not XDB.rec(table, int(n)).is_empty()):
				weight += float(c.chance)
		pending.append({"row": row, "weight": weight})
	var ordered := []
	while not pending.is_empty():
		var total := 0.0
		for e in pending:
			total += float(e.weight)
		var at := 0
		if total > 0.0:
			var pick := randf() * total
			while at < pending.size() - 1:
				pick -= float(pending[at].weight)
				if pick < 0.0:
					break
				at += 1
		ordered.append(pending[at].row)
		pending.remove_at(at)
	var count := 0
	var highest := XGear.quality(item)
	for row in ordered:
		if count >= MAX_AFFIXES:
			break
		var groups := []
		var total := 0.0
		for c in row.choices:
			var ids: Array = (c.ids as Array).filter(func(n): return not XDB.rec(table, int(n)).is_empty())
			if float(c.chance) > 0.0 and not ids.is_empty():
				groups.append({"chance": float(c.chance), "ids": ids})
				total += float(c.chance)
		if groups.is_empty() or randf() * 100.0 >= minf(100.0, total * AFFIX_RATE):
			continue
		var pool: Array = []
		if randf() < 0.6:
			var all := []
			for g in groups:
				for n in g.ids:
					if not all.has(int(n)):
						all.append(int(n))
			var top := 0
			for n in all:
				top = maxi(top, XGear.quality(XDB.rec(table, n)))
			pool = all.filter(func(n): return XGear.quality(XDB.rec(table, n)) == top)
		else:
			var pick := randf() * total
			for g in groups:
				pick -= float(g.chance)
				if pick < 0.0:
					pool = g.ids
					break
			if pool.is_empty():
				pool = groups[groups.size() - 1].ids
		var affix_id := int(pool[mini(floori(randf() * pool.size()), pool.size() - 1)])
		count += 1
		XGear.combine(item, XDB.rec(table, affix_id), str(row.kind))
		item.affixIds.append({"table": table, "id": affix_id, "kind": row.kind})
		var current := XGear.quality(item)
		highest = maxi(highest, current)
		if highest >= 13 and current < highest:
			item.meta["quality"] = str(highest)
			item.meta["ici"] = str(highest)
			item.note = str(item.note) + "\n<quality:%d>\n<ici:%d>\n" % [highest, highest]


# ---- GM 工具 ----
const KINDS := {"items": "Items", "weapons": "Weapons", "armors": "Armors"}
## [键, 名字, 变量号, 物品号, 计数变量号]
const RESOURCES := [["points", "肝帝积分", 206, 0, 0], ["fragments", "人道碎片", 0, 2530, 1478],
	["heaven", "天道币", 0, 2451, 0], ["rebel", "逆天币", 0, 1919, 0]]


static func _guard(s: XState) -> String:
	return "" if can_open(s) else "请在地图中开启测试模式后使用 GM 工具。"


static func _is_equipment(rec: Dictionary) -> bool:
	return int(rec.get("wtypeId", 0)) > 0 or int(rec.get("atypeId", 0)) > 0


## 搜索：query 是纯数字按编号，否则按名字子串；去掉空名和「----」分隔行
static func catalog(kind: String, query: String) -> Array:
	var out := []
	if not KINDS.has(kind):
		return out
	var q := query.strip_edges().to_lower()
	var t: Array = XDB.table(KINDS[kind])
	for i in range(1, t.size()):
		var rec = t[i]
		if rec == null or not rec is Dictionary:
			continue
		var name := str(rec.get("name", "")).strip_edges()
		if name == "" or RegEx.create_from_string("^[-—＝=]+").search(name) != null or int(rec.get("baseItemId", 0)) != 0:
			continue
		if kind != "items" and not _is_equipment(rec):
			continue
		if q != "" and not ((int(q) == i) if q.is_valid_int() else name.to_lower().contains(q)):
			continue
		out.append(rec)
	return out


static func _check_int(n: float, max_value: int, min_value := 1) -> int:
	if n != floorf(n) or n < min_value or n > max_value:
		return -1
	return int(n)


## 返回 {ok, text, n}
static func give_item(s: XState, kind: String, id: int, count: float) -> Dictionary:
	var g := _guard(s)
	if g != "":
		return {"ok": false, "text": g}
	var found := catalog(kind, str(id))
	if found.is_empty():
		return {"ok": false, "text": "没有找到可添加的物品。"}
	var rec: Dictionary = found[0]
	var eq := _is_equipment(rec)
	var n := _check_int(count, 99 if eq else 9999)
	if n < 0:
		return {"ok": false, "text": "请输入 1～%d 的整数。" % (99 if eq else 9999)}
	var before := _owned(s, kind, id)
	if kind == "items":
		s.gain_item(id, n)
	else:
		s.gain_gear("weapon" if kind == "weapons" else "armor", id, n)
	var got := maxi(0, _owned(s, kind, id) - before)
	return {"ok": true, "n": got, "text": "已添加 %s ×%d%s" % [rec.name, got, "" if got > 0 else "（背包已达到上限）"]}


## 原版数的是整个类别的持有量总和；这里数这一个的持有量，结果同样是「这次多了几件」
static func _owned(s: XState, kind: String, id: int) -> int:
	if kind == "items":
		return s.item_count(id)
	var k := "weapon" if kind == "weapons" else "armor"
	return s.gear.filter(func(e): return e.kind == k and int(e.base) == id).size()


static func give_gold(s: XState, n: float) -> Dictionary:
	var g := _guard(s)
	if g != "":
		return {"ok": false, "text": g}
	var v := _check_int(n, 999999999)
	if v < 0:
		return {"ok": false, "text": "请输入 1～999999999 的整数。"}
	var old := s.gold
	s.gain_gold(v)
	return {"ok": true, "n": s.gold - old, "text": "已增加金币 %d，当前金币 %d。" % [s.gold - old, s.gold]}


## actor_id 0＝全队
static func give_exp(s: XState, actor_id: int, n: float) -> Dictionary:
	var g := _guard(s)
	if g != "":
		return {"ok": false, "text": g}
	var v := _check_int(n, 999999999)
	if v < 0:
		return {"ok": false, "text": "请输入 1～999999999 的整数。"}
	var members := s.members().filter(func(a): return actor_id == 0 or a.actor_id == actor_id)
	if members.is_empty():
		return {"ok": false, "text": "请先选择队伍中的角色。"}
	for a in members:
		# changeExp(currentExp + n, false)：直接加经验值，不乘经验率、不弹升级提示
		a.exp_total += v
		while a.level < a.max_level() and a.exp_total >= a.exp_for_level(a.level + 1):
			a._level_up()
		a.refresh_passive()
	return {"ok": true, "n": members.size(), "text": "已为 %d 名角色增加 %d 经验。" % [members.size(), v]}


static func recover(s: XState) -> Dictionary:
	var g := _guard(s)
	if g != "":
		return {"ok": false, "text": g}
	for a in s.members():
		a.recover_all()
	return {"ok": true, "text": "全队生命、魔法已恢复，阵亡角色已复活。"}


static func resource_amount(s: XState, key: String) -> int:
	for r in RESOURCES:
		if r[0] == key:
			return s.variable(int(r[2])) if int(r[2]) > 0 else s.item_count(int(r[3]))
	return 0


## mode: "add" 增加（1～999999999）｜"set" 设为（0～999999999）
static func change_resource(s: XState, key: String, n: float, mode: String) -> Dictionary:
	var g := _guard(s)
	if g != "":
		return {"ok": false, "text": g}
	var r: Array = []
	for x in RESOURCES:
		if x[0] == key:
			r = x
	if r.is_empty():
		return {"ok": false, "text": "请选择有效的资源。"}
	if mode != "add" and mode != "set":
		return {"ok": false, "text": "请选择增加或设为。"}
	var lo := 0 if mode == "set" else 1
	var v := _check_int(n, 999999999, lo)
	if v < 0:
		return {"ok": false, "text": "请输入 %d～999999999 的整数。" % lo}
	var before := resource_amount(s, key)
	var target := v if mode == "set" else before + v
	if int(r[2]) > 0:
		s.set_variable(int(r[2]), mini(999999999, target))
	else:
		target = mini(9999, target)
		s.gain_item(int(r[3]), target - before)
		if int(r[4]) > 0:
			s.set_variable(int(r[4]), s.item_count(int(r[3])))
	var after := resource_amount(s, key)
	return {"ok": true, "before": before, "after": after, "change": after - before,
		"text": "%s：%d → %d（变化 %s%d）。" % [r[1], before, after, "+" if after - before >= 0 else "", after - before]}
