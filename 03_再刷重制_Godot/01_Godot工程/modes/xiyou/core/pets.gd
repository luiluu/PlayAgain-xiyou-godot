class_name XPets
extends RefCounted
## 宠物（Star_PetSystem）的数据部分；菜单在 ui/pets.gd。原版宠物就是捕获时那只 Game_Enemy 实例（$gameParty.Pets），
## 这里只存菜单与出战用得到的字段。存档字段 XState.pets：
##   {list: [宠物…], war: 出战宠物在 list 里的序号（-1 没有，$gameParty.GTWar）, team_a: 共享角色序号（$gameParty.TeamATo）}
##   宠物 {enemy: 敌人 ID, elite: 是否神话, letter: 同名字母, push: 14 项加成（前 8 项整数，后 6 项是两位小数，原版存成 toFixed(2) 字符串）,
##         skills: [技能 ID…], lv_skills: {等级: 技能 ID}, exp: 经验, ls: 已用学习次数, ls_max: 学习次数上限}
## - 由敌人建宠物（Star.PetSystem.GetingPet）：按备注 <PetPushAttr> 每行「a-b」随机整数（后 6 项再 /100），<PetPushSkill> 每行
##   「a-b…:p%」按几率从范围里挑一个没学的，<ULevelS>「Lv等级:技能:权重%」每级按权重挑一个；名字里没有「变异」——原版写的是
##   indexOf("变异")（−1 为真），所以几乎总是补学到 2 个技能。学习次数上限 1～3。
## - 等级：经验表照职业 1 的 expParams（与角色同式）再 /10 取整，满级 50（GetLevel）。
## - 出战（onGotowarOk）：先撤掉原出战宠物，再给全队（$gameParty.members）学会宠物技能——带 <TeamA> 的只给出战栏位第 team_a 位；
##   前 8 项加成加进各队员的 _paramPlus。重制复用 XParamPlus 账本逐项加减，并记录本次收到加成的角色。
##   后 6 项由 war_xparam_plus 接进角色 traits_sum；整队槽位变化时 sync_team_a 即时迁移共享技能。
## - 捕获（地图神秘生物、战斗捕捉道具）、宠物参战与战后经验不在这里（见交付单）。

const RARITY_TAGS := ["【罕见】", "【十分罕见】", "【精英】", "【亘古未见】", "【首领】", "【稀有】", "【前所未见】", "【亘古未有】"]
const MAX_LEVEL := 50
## 原版缺陷：出战后新加入的角色未收到属性，休息却照扣。默认只撤实际发过的加成；false 恢复原版。
## 待总装分配优化编号，详见本车道交付单。
static var FIX_UNGRANTED_BONUS := true


static func _data(s: XState) -> Dictionary:
	var d := s.pets
	if not d.get("list") is Array:
		d.list = []
	if not d.has("war"):
		d.war = -1
	if not d.has("team_a"):
		d.team_a = 0
	return d


static func list(s: XState) -> Array:
	return _data(s).list


static func war_index(s: XState) -> int:
	return int(_data(s).war)


static func war_pet(s: XState) -> Dictionary:
	var i := war_index(s)
	return list(s)[i] if i >= 0 and i < list(s).size() else {}


static func notetags(note: String) -> PackedStringArray:
	return RegEx.create_from_string("[\\r\\n]+").sub(note, "\n", true).split("\n")


static func _block(tags: PackedStringArray, open: String, close: String) -> Array:
	var out := []
	var inside := false
	for t in tags:
		if t == open or inside:
			inside = true
			if t == close:
				inside = false
			elif t != open:
				out.append(t)
	return out


## Star.PetSystem.GetingPet。rnd：返回 [0,1) 的函数（缺省 randf）
static func create(enemy_id: int, elite := false, letter := "", rnd := Callable()) -> Dictionary:
	if not rnd.is_valid():
		rnd = func(): return randf()
	var tags := notetags(str(XDB.rec("Enemies", enemy_id).get("note", "")))
	var push := []
	for line in _block(tags, "<PetPushAttr>", "</PetPushAttr>"):
		var m := RegEx.create_from_string("(\\d+)-(\\d+)").search(line)
		push.append(floori(float(rnd.call()) * (int(m.get_string(2)) - int(m.get_string(1)) + 1) + int(m.get_string(1))) if m else 0)
	var skills := []
	var skill_lines := _block(tags, "<PetPushSkill>", "</PetPushSkill>")
	for line in skill_lines:
		var learn := _range_skills(line, skills)
		var p := RegEx.create_from_string(":(\\d+)%").search(line)
		var roll := float(rnd.call()) * 100.0
		if p != null and roll <= float(p.get_string(1)):
			skills.append(learn[floori(float(rnd.call()) * 1000.0) % learn.size()] if not learn.is_empty() else 0)
	var by_level := {}
	for line in _block(tags, "<ULevelS>", "</ULevelS>"):
		var m := RegEx.create_from_string("(?i)Lv(\\d+):(\\d+):(\\d+)%").search(line)
		if m:
			var lv := int(m.get_string(1))
			if not by_level.has(lv):
				by_level[lv] = []
			by_level[lv].append([int(m.get_string(2)), int(m.get_string(3))])
	var lv_skills := {}
	var levels := by_level.keys()
	levels.sort()
	for lv in levels:
		var pool := []
		for pair in by_level[lv]:
			for b in pair[1]:
				pool.append(pair[0])
		lv_skills[str(lv)] = pool[roundi(float(rnd.call()) * 1000.0) % pool.size()]
	# 原版 if (Pet.name().indexOf("变异") && skills < 2)：名字里没有「变异」时 indexOf 是 −1（真）
	var pet_name := str(XDB.rec("Enemies", enemy_id).get("name", ""))
	if pet_name.find("变异") != 0 and skills.size() < 2:
		for line in skill_lines:
			var learn := _range_skills(line, skills)
			if skills.size() < 2 and not learn.is_empty():
				skills.append(learn[floori(float(rnd.call()) * 1000.0) % learn.size()])
	for i in range(8, push.size()):
		push[i] = String.num(float(push[i]) / 100.0, 2).to_float()  # toFixed(2) 后再当数用
	return {"enemy": enemy_id, "elite": elite, "letter": letter, "push": push, "skills": skills, "lv_skills": lv_skills,
		"exp": 0, "ls": 0, "ls_max": floori(float(rnd.call()) * 3.0) + 1}


## 一行「a-b,c-d…」里还没学的技能（原版按 $dataSkills 对象比，这里按 ID）
static func _range_skills(line: String, have: Array) -> Array:
	var out := []
	for m in RegEx.create_from_string("(\\d+)-(\\d+)").search_all(line):
		for id in range(int(m.get_string(1)), int(m.get_string(2)) + 1):
			if not have.has(id):
				out.append(id)
	return out


## Game_Enemy.name：神话前缀＋原名＋字母，去掉稀有度标签；出战的加「[出战]」
static func pet_name(s: XState, pet: Dictionary) -> String:
	var n := (XEnemy.elite_title() if bool(pet.get("elite", false)) else "") + str(XDB.rec("Enemies", int(pet.enemy)).get("name", "")) + str(pet.get("letter", ""))
	for t in RARITY_TAGS:
		n = n.replace(t, "")
	if s != null and is_same(war_pet(s), pet) and not pet.is_empty():
		n += "[出战]"
	return n


## Game_Enemy.expForLevel：职业 1 的经验曲线，再 /10
static func exp_for_level(lv: int) -> int:
	var p: Array = XDB.rec("Classes", 1).get("expParams", [30, 20, 30, 30])
	var basis := float(p[0])
	var extra := float(p[1])
	var acc_a := float(p[2])
	var acc_b := float(p[3])
	var v := XPower.js_round(basis * pow(lv - 1, 0.9 + acc_a / 250.0) * lv * (lv + 1) / (6.0 + pow(lv, 2) / 50.0 / acc_b) + (lv - 1) * extra)
	return int(XPower.js_round(v / 10.0))


static func level(pet: Dictionary) -> int:
	var e := int(pet.get("exp", 0))
	for i in range(1, MAX_LEVEL):
		if e >= exp_for_level(i) and e < exp_for_level(i + 1):
			return i
	return MAX_LEVEL


static func team_a_skill(id: int) -> bool:
	return XDB.rec("Skills", id).get("meta", {}).has("TeamA")


## 出战栏位第 team_a 位的角色（$gameParty._battleMembers[TeamATo]）
static func team_a_actor(s: XState) -> XActor:
	var slots: Array = s.battle_slots if not s.battle_slots.is_empty() else s.party
	var i := int(_data(s).team_a)
	if i >= 0 and i < slots.size() and int(slots[i]) > 0:
		return s.actor(int(slots[i]))
	return null


## 出战宠物的技能撤回或学会（$gameParty.members 全体与角色仓库里的 _saveactors；<TeamA> 的只给共享角色）
static func _apply_skills(s: XState, pet: Dictionary, on: bool) -> void:
	for a in s.members() + XActorWarehouse.stored(s).map(func(id): return s.actor(id)):
		for id in pet.skills:
			if not on:
				a.forget_skill(int(id))
			elif not team_a_skill(int(id)):
				a.learn_skill(int(id))
		a.refresh_passive()
		var recipients: Array = _data(s).get("bonus_actors", [])
		if on or not FIX_UNGRANTED_BONUS or recipients.any(func(id): return int(id) == a.actor_id):
			for i in mini(8, pet.push.size()):
				XParamPlus.add(s, a.actor_id, i, float(pet.push[i]) * (1.0 if on else -1.0))
	if on:
		_data(s).bonus_actors = (s.party + s.saved_actors).duplicate()
		_data(s).bonus_ledger = true
		var t := team_a_actor(s)
		if t != null:
			for id in pet.skills:
				if team_a_skill(int(id)):
					t.learn_skill(int(id))
			t.refresh_passive()
			t.param_mark_dirty()
			t.refresh_resources()
		s.pet_team_actor = t.actor_id if t != null else 0
	else:
		s.pet_team_actor = 0
		_data(s).bonus_actors = []


## TeamALearn → 槽位修改 → TeamAForget。只撤旧接收者，不误忘其他角色原本会的同名技能。
static func sync_team_a(s: XState) -> void:
	var pet := war_pet(s)
	if pet.is_empty():
		return
	var target := team_a_actor(s)
	var next_id := target.actor_id if target != null else 0
	var old: XActor = s.actors.get(s.pet_team_actor)
	for id in pet.skills:
		if team_a_skill(int(id)):
			if old != null:
				old.forget_skill(int(id))
			if target != null:
				target.learn_skill(int(id))
	if old != null:
		old.refresh_passive()
	if target != null:
		target.refresh_passive()
	s.pet_team_actor = next_id


## refreshGTWar：先撤回技能及属性、截资源，再重学；本次发放名单防止未加先扣。
static func refresh_war(s: XState) -> void:
	var pet := war_pet(s)
	if pet.is_empty():
		return
	_apply_skills(s, pet, false)
	_apply_skills(s, pet, true)


## onGotowarOk：已出战返回 false（「已出战」）；否则撤掉原出战宠物、换上这只
static func go_to_war(s: XState, i: int) -> bool:
	if i < 0 or i >= list(s).size() or i == war_index(s):
		return false
	var old := war_pet(s)
	if not old.is_empty():
		_apply_skills(s, old, false)
	_data(s).war = i
	_apply_skills(s, list(s)[i], true)
	return true


## onRestOk：是出战宠物才休息；返回是否休息了（否则「未出战」）
static func rest(s: XState, i: int) -> bool:
	if i != war_index(s) or i < 0:
		return false
	var pet := war_pet(s)
	_apply_skills(s, pet, false)
	_data(s).war = -1
	return true


## onReleaseOk：出战的先撤，再从列表移除
static func release(s: XState, i: int) -> void:
	if i == war_index(s):
		rest(s, i)
	list(s).remove_at(i)
	if war_index(s) > i:
		_data(s).war = war_index(s) - 1


## onConfirmOk：换共享角色后 refreshGTWar（撤掉再学会）
static func set_team_a(s: XState, i: int) -> void:
	_data(s).team_a = i
	refresh_war(s)


## O-098：物品 372「魔兽要诀:高级灵根」原版指向公共事件 218，教的是 1673 高级灵甲术（与 373 相同），217「高级林根」(1672)
## 没有物品引用。重制用 372 时改学 1672；设 false 恢复原版
static var BOOK_FIX_372 := true


## 魔兽要诀（公共事件 190～292 的 Star.PetSystem.ComEveLearnSkill）：出战宠物没学过且学习次数没满 → 学会、次数 +1、
## refreshGTWar（撤掉再学会），提示「<技能名> 学习成功」；否则提示「该技能已存在」／「可学习技能已达上限」／「当前无出战宠物」，
## 并退还最后用的道具（$gameParty._lastItem）。返回提示
static func learn_book(s: XState, skill_id: int) -> String:
	if BOOK_FIX_372 and s.last_item == 372 and skill_id == 1673:
		skill_id = 1672
	var pet := war_pet(s)
	if not pet.is_empty():
		pet.ls_max = maxi(int(pet.get("ls_max", 1)), 0)
		pet.ls = clampi(int(pet.get("ls", 0)), 0, int(pet.ls_max))  # ensurePetLearningSlots
	if not pet.is_empty() and int(pet.ls) < int(pet.ls_max) and not pet.skills.has(skill_id):
		pet.skills.append(skill_id)
		pet.ls = int(pet.ls) + 1
		refresh_war(s)
		return str(XDB.rec("Skills", skill_id).get("name", "")) + " 学习成功"
	if not XDB.rec("Items", s.last_item).is_empty():
		s.gain_item(s.last_item, 1)
	if not pet.is_empty() and pet.skills.has(skill_id):
		return "该技能已存在"
	if not pet.is_empty() and int(pet.ls) == int(pet.ls_max):
		return "可学习技能已达上限"
	return "当前无出战宠物"


## 出战宠物前 8 项加成（原版加进队伍及角色仓库的 _paramPlus）
static func war_param_plus(s: XState, i: int) -> float:
	var pet := war_pet(s)
	return float(pet.push[i]) if not pet.is_empty() and i >= 0 and i < 8 and i < pet.push.size() else 0.0


## 仅兼容重制旧档：以前出战宠物没把前八项接到能力值；新档已经入账，不重复加。MV 旧档不迁移。
static func loaded(s: XState) -> void:
	var pet := war_pet(s)
	if pet.is_empty() or bool(_data(s).get("bonus_ledger", false)):
		return
	for a in s.members() + XActorWarehouse.stored(s).map(func(id): return s.actor(id)):
		for i in mini(8, pet.push.size()):
			XParamPlus.add(s, a.actor_id, i, float(pet.push[i]))
	_data(s).bonus_actors = (s.party + s.saved_actors).duplicate()
	_data(s).bonus_ledger = true


## 原版 traitsSum：push8..12 → XP0..4；XP5 不加，XP6 优先 push14、不存在时回退 push13。
## 特性是所有角色都能读，敌人不读；原版注释中的 sparam 分支未启用。
static func war_xparam_plus(s: XState, i: int) -> float:
	var pet := war_pet(s)
	if pet.is_empty() or i < 0 or i == 5:
		return 0.0
	var push: Array = pet.push
	if i + 8 < push.size() and float(push[i + 8]) != 0.0:
		return float(push[i + 8])
	return float(push[13]) if i == 6 and push.size() > 13 else 0.0


# ---- 喂养（Star_PetUpLevel）----
## 插件参数 PetEatItem 1～6，但读的循环只到 5（431 是技能教学书，不算口粮）
static func food_items() -> Array:
	var p := XDB.plugin("Star_PetUpLevel")
	var out := []
	for i in range(1, 6):
		var id := int(str(p.get("PetEatItem %d" % i, "0")))
		if id > 0:
			out.append(id)
	return out


## Scene_PetSystem.onUpLeveListOk（列表只在有这件口粮时可确定）：先扣一件；不是出战宠物且没满级时，
## 等级 + <PetUpLevel>（上限 50），经验设为该级起点，补学到这一级为止的等级技能；否则把口粮还回去。返回是否喂成
static func feed(s: XState, i: int, item_id: int) -> bool:
	var pet: Dictionary = list(s)[i]
	s.gain_item(item_id, -1)
	if i == war_index(s) or level(pet) >= MAX_LEVEL:
		s.gain_item(item_id, 1)
		return false
	var up := mini(level(pet) + int(str(XDB.rec("Items", item_id).get("meta", {}).get("PetUpLevel", "0")).strip_edges()), MAX_LEVEL)
	pet.exp = exp_for_level(up)
	var lv := level(pet)
	var keys: Array = pet.lv_skills.keys().map(func(k): return int(k))
	keys.sort()
	for k in keys:
		if k <= lv and not pet.skills.has(int(pet.lv_skills[str(k)])):
			pet.skills.append(int(pet.lv_skills[str(k)]))
	return true


# ---- 合成（Star_PetSynthesis）----
## 选为宠物一／二的条件：不是出战宠物、不是另一只、满 50 级
static func can_pick(s: XState, i: int, other: int) -> bool:
	return i >= 0 and i < list(s).size() and i != war_index(s) and i != other and level(list(s)[i]) == MAX_LEVEL


## O-080：原版 getRandomArrayElements 在要的个数多于技能数时（两只合起来不到 4 个技能）会把空位换进结果，得到 undefined 技能；
## 这里把个数限在 0～技能数。设 false 恢复原版算法（空位记为 0）
const SYNTH_CLAMP_SKILLS := true


## Star.PetSynthesis.RefStat：随机取 A 或 B 当结果，学习次数清零，14 项加成 = (A+B)/2 × floor(随机×41+80)/100，
## 技能 = A、B 技能去重后随机留 floor(n/2)+floor(随机×5−2) 个（上限 12）；结果放到列表最后，A、B 原位删除。返回结果的新序号，失败 −1
static func synthesize(s: XState, a: int, b: int, rnd := Callable()) -> int:
	if not rnd.is_valid():
		rnd = func(): return randf()
	var l := list(s)
	if a < 0 or b < 0 or a >= l.size() or b >= l.size():
		return -1
	var pa: Dictionary = l[a]
	var pb: Dictionary = l[b]
	var war := war_pet(s)
	var r: Dictionary = pa if roundi(float(rnd.call())) == 1 else pb
	r.ls_max = 0
	r.ls = 0
	var push := []
	for i in r.push.size():
		push.append((float(pa.push[i]) + float(pb.push[i])) / 2.0 * (floorf(float(rnd.call()) * 41.0 + 80.0) / 100.0))
	var skills := []
	for id in pa.skills + pb.skills:
		if not skills.has(int(id)):
			skills.append(int(id))
	var count := mini(floori(skills.size() / 2.0) + floori(float(rnd.call()) * 5.0 - 2.0), 12)
	r.push = push
	r.skills = _random_elements(skills, count, rnd)
	l.append(r)
	_erase_same(l, pa)
	_erase_same(l, pb)
	_data(s).war = -1
	for i in l.size():
		if not war.is_empty() and is_same(l[i], war):
			_data(s).war = i
	return l.size() - 1


## Array.prototype.remove：删掉第一个（按同一个对象）
static func _erase_same(l: Array, x: Dictionary) -> void:
	for i in l.size():
		if is_same(l[i], x):
			l.remove_at(i)
			return


## Star.PetSynthesis.getRandomArrayElements（洗牌取尾部 count 个）
static func _random_elements(arr: Array, count: int, rnd: Callable) -> Array:
	var shuffled := arr.duplicate()
	var n := arr.size()
	if SYNTH_CLAMP_SKILLS:
		count = clampi(count, 0, n)
	var m := n - count
	if m >= n:
		return []
	var i := n
	while i > m:
		i -= 1
		var idx := floori((i + 1) * float(rnd.call()))
		var get_at := func(k: int) -> int: return int(shuffled[k]) if k >= 0 and k < shuffled.size() else 0
		var tmp: int = get_at.call(idx)
		if idx >= 0 and idx < shuffled.size():
			shuffled[idx] = get_at.call(i)
		if i >= 0 and i < shuffled.size():
			shuffled[i] = tmp
	return shuffled.slice(maxi(m, 0)) if m >= 0 else shuffled.slice(shuffled.size() + m)
