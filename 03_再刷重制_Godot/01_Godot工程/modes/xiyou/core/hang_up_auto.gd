class_name XHangUpAuto
extends RefCounted
## XdRs_HangUp 第二批的四个子页数据与规则（照正式 v0.16 源码与参照工具实测；画面在 ui/hang_up_sub_page.gd）。
## 数据存在 XState.hang_up（随存档），键名沿用原版 $gameParty 字段：
## - ActSkills {角色名+技能ID: 次数}（技能次数页）；ActSkill {角色名+三位顺序号: 技能ID}（技能顺序页写，战斗按回合查）；
##   ActTemp {角色名+三位技能ID+三位副本号: 顺序号}（顺序页的排列；原版是不存档的全局变量，O-020 改为随存档）。
## - RecoveryHMP（自动吃药）：HpV/MpV 阈值、GetHpItems/GetMPItems 开关、GetHpArrItems [[开, 物品ID, "ZL"/"FH"]…]、GetMpArrItems。
## - SellWeapon（自动卖出）：SellQuality 每几场卖一次（0～11，0 不卖）、quality0～15 旧档开关（七档页按组切换）。
## 运行中计数（不存档）：自动卖出的场数 BetterFrequency，开始/停止挂机时归零。
## 角色名用 display_name()（原版 actor._name）；三位数照 Star.NumToThreeNum（≥100 原样）。

## O-020：顺序页的排列随存档；false 时与原版一样只留在本次运行（重开游戏后打开顺序页会重排为 1～N）
const SAVE_ORDER := true
## O-021：吃药/回蓝的循环加上限（原版不可消耗的药会无限循环卡死）；阵亡者不吃回蓝药（原版会把开着的回蓝药全吃光）
const SAFE_RECOVERY := true
const LOOP_CAP := 2000
## O-023：顺序号保持 1～N 且删去旧表残留，次数改动后重建已排过的顺序；false 恢复原版延迟刷新/残留。
const CONSISTENT_ORDER := true

static var _order_temp := {}
static var better_frequency := 0


static func three(n: int) -> String:
	return ("00%d" if n < 10 else "0%d" if n < 100 else "%d") % n if n >= 0 else str(n)


static func data(s: XState, key: String) -> Dictionary:
	if not s.hang_up.get(key) is Dictionary:
		s.hang_up[key] = {}
	return s.hang_up[key]


static func order_temp(s: XState) -> Dictionary:
	return data(s, "ActTemp") if SAVE_ORDER else _order_temp


## 开始/停止挂机（startHangUp / stopHangUp 的 BetterFrequency = 0；startHangUp 初次建 SellWeapon）
static func on_start(s: XState) -> void:
	better_frequency = 0
	if not s.hang_up.get("SellWeapon") is Dictionary:
		s.hang_up["SellWeapon"] = {"SellQuality": 1}


static func on_stop() -> void:
	better_frequency = 0


# ---- 技能次数 / 顺序 ----
## 出战成员（Star_Window_AutomaticCombatAct：_battleMembers 里非 0 的）
static func actors(s: XState) -> Array:
	return s.battle_members()


## Game_Actor.usaBetSkills：攻击、防御，再加能行动时场合为「总是/战斗」、武器类型符合、未封印的技能（TP 视为 100，不影响结果）
static func bet_skills(logic: XBattleLogic, a: XActor) -> Array:
	var out := [XDB.rec("Skills", XBattleLogic.ATTACK_SKILL), XDB.rec("Skills", XBattleLogic.GUARD_SKILL)]
	if not logic.can_move(a):
		return out
	for sk in a.skills():
		if not int(sk.get("occasion", 0)) in [0, 1]:
			continue
		if a.traits_set(XBattler.TRAIT_SKILL_SEAL).has(int(sk.id)) or a.traits_set(XBattler.TRAIT_STYPE_SEAL).has(int(sk.stypeId)):
			continue
		if not wtype_ok(a, sk):
			continue
		out.append(sk)
	return out


## Game_BattlerBase.isSkillWtypeOk：没有武器类型要求，或装着其中一种类型的武器
static func wtype_ok(a: XActor, sk: Dictionary) -> bool:
	return XBattleLogic.wtype_ok(a, sk)


## 技能次数页（Star_Window_AutomaticCombatSkills）：没设过的写 0
static func counts(s: XState, a: XActor, skills: Array) -> Array:
	var t := data(s, "ActSkills")
	var out := []
	for sk in skills:
		var k := a.display_name() + str(int(sk.id))
		if not t.has(k):
			t[k] = 0
		out.append(int(t[k]))
	return out


## 确定/右键头 +1（20 后回 0），左键头 −1（0 后到 20）
static func change_count(s: XState, a: XActor, sk: Dictionary, up: bool) -> void:
	var t := data(s, "ActSkills")
	var k := a.display_name() + str(int(sk.id))
	var v := int(t.get(k, 0))
	t[k] = (v + 1 if v < 20 else 0) if up else (v - 1 if v > 0 else 20)
	if CONSISTENT_ORDER and data(s, "ActSkill").keys().any(func(key): return _schedule_key(str(key), a.display_name())):
		var logic := XBattleLogic.new()
		logic.state = s
		order_list(s, a, bet_skills(logic, a))


## 技能顺序页（Star_Window_AutomaticCombatSkill）：每个技能按次数重复（次数不是数字时当 1 并写回）。
## 返回 {skills: [{skill, copy}], order: [顺序号]}，并照 makeCommandList＋RefmakeCommandList 写回 ActTemp 与 ActSkill。
static func order_list(s: XState, a: XActor, skills: Array) -> Dictionary:
	var t := data(s, "ActSkills")
	var temp := order_temp(s)
	var name := a.display_name()
	var list := []
	for sk in skills:
		var k := name + str(int(sk.id))
		if not (t.get(k) is int or t.get(k) is float):
			t[k] = 1
		for copy in range(maxi(0, int(t[k]))):
			list.append({"skill": sk, "copy": copy})
	var reset := list.any(func(e): return not temp.has(_temp_key(name, e)))
	var order := []
	for i in list.size():
		if reset:
			temp[_temp_key(name, list[i])] = i + 1
		order.append(int(temp[_temp_key(name, list[i])]))
	var st := {"name": name, "skills": list, "order": order, "set": -1}
	renumber(s, st)
	return st


static func _temp_key(name: String, e: Dictionary) -> String:
	return name + three(int(e.skill.id)) + three(int(e.copy))


## RefmakeCommandList：与刚改过的那项（set）同号的其他项改成对方 +1；每项写回 ActTemp，并把「名字+顺序号」指向该技能
static func renumber(s: XState, st: Dictionary) -> void:
	var temp := order_temp(s)
	var table := data(s, "ActSkill")
	var list: Array = st.skills
	var order: Array = st.order
	for i in list.size():
		for j in list.size():
			if i != j and order[i] == order[j] and st.set >= 0 and st.set != i:
				order[i] = order[j] + 1
			temp[_temp_key(st.name, list[i])] = order[i]
			table[st.name + three(int(order[i]))] = int(list[i].skill.id)
	if CONSISTENT_ORDER:
		var indices := range(list.size())
		indices.sort_custom(func(a, b): return order[a] < order[b] if order[a] != order[b] else a < b)
		for i in indices.size():
			order[indices[i]] = i + 1
		for key in table.keys():
			if _schedule_key(str(key), st.name):
				table.erase(key)
		for i in list.size():
			temp[_temp_key(st.name, list[i])] = order[i]
			table[st.name + three(int(order[i]))] = int(list[i].skill.id)


static func _schedule_key(key: String, name: String) -> bool:
	return key.begins_with(name) and key.substr(name.length()).is_valid_int()


## 确定/右键头：顺序号 −1（到 1 为止），其余项按 renumber 让位
static func move_earlier(s: XState, st: Dictionary, i: int) -> void:
	if i < 0 or i >= st.order.size():
		return
	if int(st.order[i]) > 1:
		st.order[i] = int(st.order[i]) - 1
		st.set = i
	renumber(s, st)


## 战斗中轮到 a（第 turn 回合）时按顺序表定下的技能；没有排或用不了返回空（交给自动战斗）。
## Codex_SmartBattleAI.scheduledSkill（能用、且是攻击/防御或学会的技能）后接 XdRs_HangUp 的 makeAction：
## 原始 mpCost/tpCost 不超过当前值才用，否则普通攻击。
static func scheduled_skill(s: XState, logic: XBattleLogic, a: XActor, turn: int) -> Dictionary:
	var v = data(s, "ActSkill").get(a.display_name() + three(turn))
	if v == null or int(v) <= 0:
		return {}
	var id := int(v)
	var sk := XDB.rec("Skills", id)
	if sk.is_empty() or not logic.can_use(a, sk) or not wtype_ok(a, sk):
		return {}
	if id > XBattleLogic.GUARD_SKILL and not a.skills().any(func(x): return int(x.id) == id):
		return {}
	var attack := XDB.rec("Skills", XBattleLogic.ATTACK_SKILL)
	var usable := logic.usable_skills(a)
	var listed := usable.any(func(x): return int(x.id) == id or id == 1 or id == 2)
	if listed and float(sk.get("mpCost", 0)) <= a.mp and float(sk.get("tpCost", 0)) <= a.tp:
		return attack if id == 1 else sk
	return attack


# ---- 自动吃药 ----
static func recovery(s: XState) -> Dictionary:
	return data(s, "RecoveryHMP")


## Star_Window_AutomaticMedication.initialize：阈值缺省 50
static func open_medication(s: XState) -> void:
	var r := recovery(s)
	for k in ["HpV", "MpV"]:
		if not r.get(k):
			r[k] = 50


## 比例：+10 到 100 后回 10
static func change_rate(s: XState, key: String) -> void:
	var r := recovery(s)
	r[key] = int(r[key]) + 10 if int(r[key]) < 100 else 10


## 回血/回蓝药列表（Star_Window_GetHpItems/GetMpItems）：持有物品按 ID 顺序，每个效果 11（或 12）各列一次
static func potion_list(s: XState, mp: bool) -> Array:
	var ids := s.items.keys().map(func(k): return int(k))
	ids.sort()
	var out := []
	for id in ids:
		var it := XDB.rec("Items", id)
		if it.is_empty() or s.item_count(id) <= 0:
			continue
		for e in it.get("effects", []):
			if int(e.code) == (12 if mp else 11):
				out.append({"id": id, "num": s.item_count(id)})
	return out


static func _flags_key(mp: bool) -> String:
	return "GetMPItems" if mp else "GetHpItems"


static func potion_key(id: int) -> String:
	return str(XDB.rec("Items", id).get("name", "")) + three(id)


static func potion_on(s: XState, mp: bool, id: int) -> bool:
	return bool(data_in(recovery(s), _flags_key(mp)).get(potion_key(id), false))


static func data_in(d: Dictionary, key: String) -> Dictionary:
	if not d.get(key) is Dictionary:
		d[key] = {}
	return d[key]


## 确定切换开关；每次都按列表重建 GetHpArrItems（[开, ID, "ZL"]）/ GetMpArrItems（[开, ID]）
static func toggle_potion(s: XState, mp: bool, list: Array, i: int) -> void:
	var flags := data_in(recovery(s), _flags_key(mp))
	if i >= 0 and i < list.size():
		var k := potion_key(int(list[i].id))
		flags[k] = not bool(flags.get(k, false))
	rebuild_potions(s, mp, list)


static func rebuild_potions(s: XState, mp: bool, list: Array) -> void:
	var flags := data_in(recovery(s), _flags_key(mp))
	var arr := []
	for e in list:
		var k := potion_key(int(e.id))
		flags[k] = bool(flags.get(k, false))
		arr.append([flags[k], int(e.id)] if mp else [flags[k], int(e.id), "ZL"])
	recovery(s)["GetMpArrItems" if mp else "GetHpArrItems"] = arr


static func _is_revive(id: int) -> bool:
	return XDB.rec("Items", id).get("effects", []).any(func(e): return int(e.code) == 22)


static func _use_potion(s: XState, logic: XBattleLogic, a: XActor, id: int) -> void:
	var it := XDB.rec("Items", id)
	if bool(it.get("consumable", true)):
		s.gain_item(id, -1)
	XHangUpAuto.apply_item(s, logic, a, it)


## XdRsData.hangUp.HMPapplyItem：以该角色为使用者，对自己（全体范围时对全队）逐个 apply（不满足 testApply 的对象没有效果）
static func apply_item(s: XState, logic: XBattleLogic, a: XActor, it: Dictionary) -> void:
	var scope := int(it.get("scope", 0))
	if not scope in [7, 8, 9, 10, 11]:
		return
	var targets := s.members() if scope in [8, 10] else [a]
	for t in targets:
		if t.is_dead() != (scope in [9, 10]):
			continue
		for i in maxi(1, int(it.get("repeats", 1))):
			for e in it.get("effects", []):
				logic._effect(a, t, e, {"skill": it, "hp": 0.0, "mp": 0.0, "added": [], "removed": []})


## 战后自动吃药（Scene_Battle.terminate 里挂机时的回血、回蓝），照原版逐行。
## BreakHPTrue/BreakMPTrue 只有前 4 格（第 5 名出战成员没有阈值，HP/MP 不满就吃）。
static func after_battle_recovery(s: XState, logic: XBattleLogic) -> void:
	var r := recovery(s)
	var hp_list: Array = r.get("GetHpArrItems", []) if r.get("GetHpArrItems") is Array else []
	var mp_list: Array = r.get("GetMpArrItems", []) if r.get("GetMpArrItems") is Array else []
	var members := s.battle_members()
	var brk := [true, true, true, true]
	var b := func(i): return bool(brk[i]) if i < brk.size() else false
	var set_b := func(i, v): if i < brk.size(): brk[i] = v
	var i := 0
	var guard := 0
	while i < members.size():
		guard += 1
		if SAFE_RECOVERY and guard > LOOP_CAP:
			break
		var a: XActor = members[i]
		var before_hp := a.hp
		var was_break: bool = b.call(i)
		var rate := a.hp / maxf(a.mhp, 1.0)
		if a.mhp > 1 and rate < 1.0 and rate > 0.0:
			if r.get("HpV") and float(r.HpV) > rate * 100.0 and b.call(i):
				set_b.call(i, false)
			elif not b.call(i):
				for arr in hp_list:
					if s.item_count(int(arr[1])) <= 0:
						arr[0] = false
					if arr[0] and _is_revive(int(arr[1])):
						continue
					if arr[0] and a.hp < a.mhp and a.hp > 0:
						_use_potion(s, logic, a, int(arr[1]))
						if s.item_count(int(arr[1])) <= 0:
							arr[0] = false
		elif a.hp <= 0:
			var revive := false
			set_b.call(i, false)
			for arr in hp_list:
				if s.item_count(int(arr[1])) <= 0:
					arr[0] = false
				if arr[0] and _is_revive(int(arr[1])):
					revive = true
				if revive and arr[0] and a.hp <= 0:
					_use_potion(s, logic, a, int(arr[1]))
					if s.item_count(int(arr[1])) <= 0:
						arr[0] = false
			if a.hp <= 0:
				set_b.call(i, true)
		# 没回满再来一轮：开着的药里还有非复活药（"ZL"）就重做这名角色
		rate = a.hp / maxf(a.mhp, 1.0)
		if rate < 1.0 and rate > 0.0 and not b.call(i):
			for arr in hp_list:
				if arr[0] and _is_revive(int(arr[1])):
					arr[2] = "FH"
			var any_on := hp_list.any(func(x): return x[0] == true)
			var none_plain := not hp_list.any(func(x): return x[0] == true and x[2] != "FH")
			var any_zl := hp_list.any(func(x): return x[0] == true and x[2] == "ZL")
			if any_on and (none_plain or any_zl) and any_zl and (not SAFE_RECOVERY or was_break or a.hp != before_hp):
				continue
		i += 1
		guard = 0
	brk.fill(true)
	i = 0
	guard = 0
	while i < members.size():
		guard += 1
		if SAFE_RECOVERY and guard > LOOP_CAP:
			break
		var a: XActor = members[i]
		if SAFE_RECOVERY and a.is_dead():
			i += 1
			continue
		var before_mp := a.mp
		var was_break: bool = b.call(i)
		var rate := a.mp / maxf(a.mmp, 1.0)
		if a.mmp > 1 and rate < 1.0:
			if r.get("MpV") and float(r.MpV) > rate * 100.0 and b.call(i):
				set_b.call(i, false)
			elif not b.call(i):
				for arr in mp_list:
					if s.item_count(int(arr[1])) <= 0:
						arr[0] = false
					if arr[0] and a.mp < a.mmp:
						_use_potion(s, logic, a, int(arr[1]))
						if s.item_count(int(arr[1])) <= 0:
							arr[0] = false
		if a.mp / maxf(a.mmp, 1.0) < 1.0 and not b.call(i) and mp_list.any(func(x): return x[0] == true) and (not SAFE_RECOVERY or was_break or a.mp != before_mp):
			continue
		i += 1
		guard = 0


# ---- 自动卖出 ----
static func sell_config(s: XState) -> Dictionary:
	var c := data(s, "SellWeapon")
	var v = c.get("SellQuality")
	if not (v is int or v is float):
		c["SellQuality"] = 1
	return c


## 每几场：+1，超过 10 后回 0
static func change_sell_every(s: XState) -> void:
	var c := sell_config(s)
	c.SellQuality = 0 if int(c.SellQuality) > 10 else int(c.SellQuality) + 1


## 七档的卖出状态：none / all / partial（installUnifiedQualityRuntime.autoState）
static func grade_state(s: XState, g: int) -> String:
	var c := sell_config(s)
	var ids := legacy_of(g)
	var n := ids.filter(func(q): return bool(c.get("quality%d" % q, false))).size()
	return "none" if n == 0 else "all" if n == ids.size() else "partial"


static func legacy_of(g: int) -> Array:
	var out := []
	var grades: Array = XQuality.config().itemGrades
	for q in grades.size():
		if int(grades[q]) == g:
			out.append(q)
	return out


## 确定切换一档：没有卖的全开，否则全关（播确定音由页面负责）
static func toggle_grade(s: XState, g: int) -> void:
	var c := sell_config(s)
	var on := grade_state(s, g) == "none"
	for q in legacy_of(g):
		c["quality%d" % q] = on


## SellWA：开着的旧档
static func sell_legacy(s: XState) -> Array:
	var c := sell_config(s)
	var out := []
	for q in XQuality.config().itemGrades.size():
		if bool(c.get("quality%d" % q, false)):
			out.append(q)
	return out


## 战后自动卖出：每场 +1，等于 SellQuality 时卖背包里开着的旧档装备（筛选同一键出售：XItemMarks.sellable_gear），归零。
## 价格与卖出报酬同商店（XItemMarks.sell）。返回卖掉的件数（-1 表示这场不卖）。
static func after_battle_sell(s: XState) -> int:
	var c := sell_config(s)
	better_frequency += 1
	if int(c.SellQuality) == 0 or int(c.SellQuality) != better_frequency:
		return -1
	better_frequency = 0
	var list := XItemMarks.sellable_gear(s, sell_legacy(s))
	for e in list:
		XItemMarks.sell(s, e, 1)   # XdRsData.hangUp.doSell：同商店，含 YEP_X_MoreCurrencies 卖出报酬
	return list.size()


## 快捷界面下方的列表（HangUp_Inter.drawHMPU）：开着且还有的回血/回蓝药「名字 剩余: N」（按 ID 去重排序），
## 再加「每 N 次战斗后卖出的装备品质:」与七档摘要（部分开的写「（部分）」）。只在挂机中显示。
static func panel_lines(s: XState) -> Dictionary:
	var r := recovery(s)
	var ids := {}
	for key in ["GetHpArrItems", "GetMpArrItems"]:
		if r.get(key) is Array:
			for arr in r[key]:
				if arr[0]:
					ids[int(arr[1])] = true
	var potions := []
	var keys := ids.keys()
	keys.sort()
	for id in keys:
		if s.item_count(id) > 0:
			potions.append("%s 剩余: %d" % [XDB.rec("Items", id).get("name", ""), s.item_count(id)])
	var summary := []
	var c: Dictionary = s.hang_up.get("SellWeapon", {}) if s.hang_up.get("SellWeapon") is Dictionary else {}
	if int(c.get("SellQuality", 0)) > 0:
		for g in XQuality.config().names.size():
			var st := grade_state(s, g)
			if st != "none":
				summary.append(str(XQuality.config().names[g]) + ("（部分）" if st == "partial" else ""))
	return {"potions": potions, "every": int(c.get("SellQuality", 0)), "grades": summary}
