class_name XActor
extends XBattler
## 角色：MV Game_Actor ＋ dsPassiveSkill 的被动规则（按标签本意实现，不复制正式版的重复累加问题）。
## 装备是实例：{"kind": "weapon"/"armor", "base": 基础ID, "params": [...], "traits": [...], "note", "meta", "yep"}。

var actor_id := 0
var class_id := 0
var _lv := 1
var exp_total := 0
var nickname := ""
var skill_ids: Array[int] = []
var equips: Array = []      # 每个装备槽一个实例或 null
var last_command := ""
var last_battle_skill := 0
var _passive_cache := {}    # 由 refresh_passive() 生成；能力值/技能变化后需刷新
## 真气（CodexZhenqi，actor._codexZhenqi；见 XZhenqi.data）：{qi, firsts, realm, pending, daofa, spec}，随存档
var zhenqi := {}


func setup(id: int) -> XActor:
	actor_id = id
	var d := data()
	class_id = int(d.classId)
	_lv = int(d.initialLevel)
	nickname = str(d.get("nickname", ""))
	exp_total = exp_for_level(_lv)
	equips.resize(equip_slots().size())
	var init: Array = d.get("equips", [])
	for i in range(equips.size()):
		var item_id := int(init[i]) if i < init.size() and init[i] != null else 0
		equips[i] = make_equip("weapon" if i == 0 else "armor", item_id) if item_id > 0 else null
	for l in class_data().get("learnings", []):
		if int(l.level) <= _lv:
			learn_skill(int(l.skillId))
	release_unequippable()
	refresh_passive()
	recover_all()
	return self


func data() -> Dictionary:
	return XDB.rec("Actors", actor_id)

func class_data() -> Dictionary:
	return XDB.rec("Classes", class_id)

func is_actor() -> bool:
	return true

func display_name() -> String:
	return str(data().get("name", ""))

func _level() -> int:
	return _lv


# ---- 装备 ----
## 西游正式版每位角色 19 个槽，对应 System.equipTypes 1..19。
func equip_slots() -> Array:
	var out := []
	for i in range(1, XDB.system().equipTypes.size()):
		out.append(i)
	return out

static func make_equip(kind: String, base_id: int) -> Dictionary:
	return XGear.template(kind,base_id)

## MV Game_Actor.canEquip：武器/防具类型由特性 51/52（及被动 passiveEWPN/EARM）放行，特性 54 封印装备类型；
## zbxz 插件的 <req_level:N> 等级需求。
func can_equip(item: Dictionary) -> bool:
	if item.is_empty():
		return false
	if traits_set(54).has(int(item.etypeId)):
		return false
	var req := int(item.get("meta", {}).get("req_level", 0))
	if req > _lv:
		return false
	var required: Array = item.get("equipment",{}).get("requirements",{}).get("actors",[]).map(func(v):return int(v))
	if not required.is_empty() and not required.has(actor_id):return false
	if item.kind == "weapon":
		var wt := int(item.wtypeId)
		return traits_set(51).has(wt) or not passive_values("passiveEWPN%02d" % wt).is_empty()
	var at := int(item.atypeId)
	return traits_set(52).has(at) or not passive_values("passiveEARM%02d" % at).is_empty()

## 槽位类型不符或不能装备的卸下（MV releaseUnequippableItems，反复直到稳定）。
func release_unequippable() -> Array:
	var removed := []
	var slots := equip_slots()
	var changed := true
	while changed:
		changed = false
		for i in range(equips.size()):
			var e = equips[i]
			if e != null and not e.is_empty() and (int(e.etypeId) != int(slots[i]) or not can_equip(e)):
				removed.append(e)
				equips[i] = null
				changed = true
	return removed

func equip_list() -> Array:
	return equips.filter(func(e): return e != null and not e.is_empty())


## Game_Actor.weapons()[0]
func first_weapon() -> Dictionary:
	for e in equip_list():
		if e.get("kind", "") == "weapon":
			return e
	return {}


## YEP_ItemCore hasWeapon/hasArmor → hasBaseItem：已装备的独立装备按基础编号比较
func has_base_equip(kind: String, base_id: int) -> bool:
	return equip_list().any(func(e): return e.get("kind", "") == kind and int(e.get("base", 0)) == base_id)


## 普通攻击的动作与武器挥动图（MV Game_Actor.performAttack＋YEP_WeaponAnimation）：
## 先找 <Weapon Image: n>（状态→装备→职业→角色），动作取 attackMotions[n]（超出则 swing）；
## 否则按第一把武器的武器类型取系统攻击动作（0 突刺 1 挥舞 2 射击）。返回 {motion, image}。
func attack_visual() -> Dictionary:
	var names := ["thrust", "swing", "missile"]
	var motions: Array = XDB.system().get("attackMotions", [])
	var sources: Array = states() + equip_list() + [class_data(), data()]
	for o in sources:
		var img := str(o.get("meta", {}).get("Weapon Image", "")).strip_edges()
		if img.is_valid_int() and int(img) > 0:
			var n := int(img)
			var m = motions[n] if n < motions.size() else null
			return {"motion": names[clampi(int(m.type), 0, 2)] if m is Dictionary else "swing", "image": n}
	var wtype := 0
	for e in equip_list():
		if e.get("kind", "") == "weapon":
			wtype = int(e.get("wtypeId", 0))
			break
	var am = motions[wtype] if wtype < motions.size() else null
	if am is Dictionary:
		return {"motion": names[clampi(int(am.type), 0, 2)], "image": int(am.weaponImageId)}
	return {"motion": "thrust", "image": 0}


# ---- 等级与经验（MV Game_Actor.expForLevel）----
func exp_for_level(lv: int) -> int:
	var p: Array = class_data().expParams
	var basis := float(p[0])
	var extra := float(p[1])
	var acc_a := float(p[2])
	var acc_b := float(p[3])
	return int(roundf(basis * pow(lv - 1, 0.9 + acc_a / 250.0) * lv * (lv + 1) / (6.0 + pow(lv, 2) / 50.0 / acc_b) + (lv - 1) * extra))

## YEP_CoreEngine：每次换场景把 $dataActors[i].maxLevel 写成 $gameParty.ActorMaxLevel，实际上限就是队伍的那一个（XState.max_level）
func max_level() -> int:
	return XState.current.max_level() if XState.current else int(data().get("maxLevel", 99))

func max_tp() -> float:
	var value := super.max_tp()
	for extra in passive_values("passiveEXTTP"):
		value += _num(extra)
	return value

## Game_Actor.levelUp：等级 +1，学会该等级的职业技能；PKD_SimpleSkillsTree 给备注 pSkillPointsVarId 指定的变量加技能点（每级 1）
func _level_up() -> void:
	_lv += 1
	for l in class_data().get("learnings", []):
		if int(l.level) == _lv:
			learn_skill(int(l.skillId))
	var var_id := str(data().get("meta", {}).get("pSkillPointsVarId", "")).strip_edges()
	if var_id.is_valid_int() and int(var_id) > 0 and XState.current:
		var points := str(XDB.plugin("PKD_SimpleSkillsTree").get("skillPointsPerLevelUpGain:i", "1"))
		XState.current.set_variable(int(var_id), XState.current.variable(int(var_id)) + (int(points) if points.is_valid_int() else 1))

## Game_Actor.changeLevel（事件「增减等级」316）：夹在 1～上限，按 changeExp 逐级升降（降级不忘技能、不扣技能点），
## 返回新学会的技能 ID（displayLevelUp 用）
func change_level_mv(lv: int) -> Array:
	var before := skill_ids.duplicate()
	lv = clampi(lv, 1, max_level())
	exp_total = exp_for_level(lv)
	while _lv < lv:
		_level_up()
	while _lv > lv:
		_lv -= 1
	refresh_passive()
	refresh_resources()  # Game_Actor.changeExp 最后 refresh，降级后夹回新 HP/MP 上限。
	return skill_ids.filter(func(id): return not before.has(id))

## 直接设定等级（读档、测试夹具用）：只按数据库上限夹，不看队伍上限，不加技能点
func change_level(lv: int) -> void:
	_lv = clampi(lv, 1, int(data().get("maxLevel", 99)))
	exp_total = exp_for_level(_lv)
	for l in class_data().get("learnings", []):
		if int(l.level) <= _lv:
			learn_skill(int(l.skillId))
	refresh_passive()

## 获得经验，返回升了几级。
## YEP_CoreEngine：已到等级上限不再获得经验。rate 为 MV finalExpRate 里的出战/后备系数。
func gain_exp(amount: int, rate := 1.0) -> int:
	var before := _lv
	if _lv >= max_level():
		return 0
	exp_total += int(roundf(amount * exr * rate))
	while _lv < max_level() and exp_total >= exp_for_level(_lv + 1):
		_level_up()
	if _lv != before:
		refresh_passive()
		refresh_resources()
	return _lv - before


# ---- 技能 ----
func learn_skill(id: int) -> void:
	if not skill_ids.has(id) and not XDB.rec("Skills", id).is_empty():
		skill_ids.append(id)
		skill_ids.sort()

func forget_skill(id: int) -> void:
	skill_ids.erase(id)

func skills() -> Array:
	var ids: Array[int] = skill_ids.duplicate()
	for t in all_traits():
		if int(t.code) == TRAIT_SKILL_ADD and not ids.has(int(t.dataId)):
			ids.append(int(t.dataId))
	for id in XEquipSuits.ids(self,"skills"):
		if not ids.has(id):ids.append(id)
	var out := []
	for id in ids:
		var s := XDB.rec("Skills", id)
		if not s.is_empty():
			out.append(XZhenqi.skill_view(s, self))  # 道法按境界缩放（CodexZhenqi.skillView）
	return out


# ---- 特性对象 ----
## 宝珠：同类新宝珠的标记特性只算阶位最高 3 件装备（installNativeOrbRuntime capDrops，见 XOrbs）
func all_traits() -> Array:
	return XOrbs.filter_traits(super.all_traits(), equips)

func trait_objects() -> Array:
	var out := [data(), class_data()]
	out.append_array(equip_list())
	out.append_array(states())
	var resistance := []
	for id in XEquipSuits.ids(self,"statesResist"):
		resistance.append({"code":TRAIT_STATE_RESIST,"dataId":id,"value":1})
	if not resistance.is_empty():out.append({"traits":resistance})
	return out


func states() -> Array:
	var result := super.states()
	for id in XEquipSuits.ids(self,"states"):
		var state := XDB.rec("States",id)
		if not state.is_empty() and not result.has(state):result.append(state)
	return result

func param_rate(i: int) -> float:
	return super.param_rate(i) * XEquipSuits.value(self,"param",i,true)

# ---- dsPassiveSkill：被动标签只从已有技能读取 ----
func passive_values(tag: String) -> Array:
	var out := []
	for s in skills():
		var m: Dictionary = s.get("meta", {})
		if m.has(tag):
			out.append(m[tag])
	return out

static func _num(v) -> float:
	var r := RegEx.create_from_string("[-+]?\\d*\\.?\\d+")
	var m := r.search(str(v))
	return float(m.get_string()) if m else 0.0

static func _param_boost(base: float, meta) -> float:
	var s := str(meta)
	return floorf(base * _num(s) * 0.01) if s.contains("%") else _num(s)

func _condition(cond: String, value: float) -> bool:
	match cond:
		"HPUP": return hp_rate() >= value * 0.01
		"HPLW": return hp_rate() <= value * 0.01
		"MPUP": return mp / maxf(mmp, 1.0) >= value * 0.01
		"MPLW": return mp / maxf(mmp, 1.0) <= value * 0.01
	return false

## 被动标签的编号只取一位（原插件 ('0'+id).slice(-1)）
func _tag(prefix: String, i: int) -> String:
	return prefix + str(i % 10)

func param_base_direct(i: int) -> float:
	var params: Array = class_data().params
	return float(params[i][_lv])

func param_base(i: int) -> float:
	var base := param_base_direct(i)
	var v := base
	for m in passive_values(_tag("passivePBST", i)):
		v += _param_boost(base, m)
	for m in passive_values(_tag("passivePBSTEX", i)):
		var parts := str(m).split(",")
		if parts.size() >= 3 and _condition(parts[1].strip_edges(), float(parts[2])):
			v += _param_boost(base, parts[0])
	return v

## 装备属性；被动 passiveWPNMxx / passiveARMMxx 按武器/防具类型放大该装备的正值属性。
func param_plus(i: int) -> float:
	var v := XEquipSuits.value(self,"param",i,false)
	for e in equip_list():
		var p := float(e.params[i])
		v += p
		if p > 0.0:
			var tag := ("passiveWPNM%02d" % int(e.wtypeId)) if e.kind == "weapon" else ("passiveARMM%02d" % int(e.atypeId))
			for m in passive_values(tag):
				v += _param_boost(p, m)
	return v

## 正式版运行时对角色命中率保底 0.9（命中 = xparam 0）。
func xparam(i: int) -> float:
	var v := super.xparam(i)
	for m in passive_values(_tag("passiveXPBST", i)):
		v += _num(m) * 0.01
	v = (v + XEquipSuits.value(self,"xparam",i,false)/100) * XEquipSuits.value(self,"xparam",i,true)
	return maxf(0.9, v) if i == 0 else v

func sparam(i: int) -> float:
	var v := traits_pi(TRAIT_SPARAM, i)
	for m in passive_values(_tag("passiveSPBST", i)):
		v += _num(m) * 0.01
	v = (v + XEquipSuits.value(self,"sparam",i,false)/100) * XEquipSuits.value(self,"sparam",i,true)
	if i == 6 or i == 7:
		return additive_rate(TRAIT_SPARAM, i, v, [])
	return v

func passive_element_values(e: int) -> Array:
	return passive_values("passiveELEM%02d" % e).map(func(m): return _num(m) / 100.0)


# ---- 伤害结算用的被动缓存（dsPassiveSkill refreshPassiveCache，单次汇总）----
func refresh_passive() -> void:
	var c := {"harmRe": {}, "penetrateFixed": {}, "penetratePercent": {}, "skillPass": {}, "skillTypeDvup": {},
		"SkETypeHarmRi": {}, "globalHarmRi": 0.0, "critHarmRi": 0.0, "itemRateUp": 0.0,
		"certainHit": {"global": false, "bySkill": {}}}
	var objs := equip_list() + skills() + states()
	for o in objs:
		var note := str(o.get("note", ""))
		var meta: Dictionary = o.get("meta", {})
		for m in _scan(note, "<passiveHarmRe(\\d+):\\s*([\\d.]+)>"):
			c.harmRe[int(m[0])] = c.harmRe.get(int(m[0]), 0.0) + float(m[1])
		for m in _scan(note, "<DepassiveHarmRe(\\d+):\\s*([\\d.]+%?)>"):
			var key := "penetratePercent" if m[1].contains("%") else "penetrateFixed"
			c[key][int(m[0])] = c[key].get(int(m[0]), 0.0) + _num(m[1])
		for k in meta:
			if str(k).begins_with("SkillPass"):
				var sid := int(str(k).substr(9))
				var row: Dictionary = c.skillPass.get(sid, {"rate": 0.0, "flat": 0.0})
				if str(meta[k]).contains("%"):
					row.rate += _num(meta[k]) / 100.0
				else:
					row.flat += _num(meta[k])
				c.skillPass[sid] = row
		for m in _scan(note, "<SkillTypesDvup([A-Za-z]+):\\s*([\\d.]+%?)>"):
			c.skillTypeDvup[m[0]] = c.skillTypeDvup.get(m[0], 0.0) + _num(m[1]) / 100.0
		for m in _scan(note, "<SkETypeHarmRi(\\d+):\\s*([\\d.]+%?)>"):
			c.SkETypeHarmRi[int(m[0])] = c.SkETypeHarmRi.get(int(m[0]), 0.0) + _num(m[1]) / 100.0
		for m in _scan(note, "(?i)<passiveHarmRi:([-]?\\d+(?:\\.\\d+)?)(%?)>"):
			c.globalHarmRi += float(m[0]) / 100.0
		for m in _scan(note, "(?i)<passiveCrHarmRi:([-]?\\d+(?:\\.\\d+)?)(%?)>"):
			c.critHarmRi += float(m[0]) / 100.0
		# 必中：<SkillCertainHitss> 全部技能，<SkillCertainHitN: 技能ID> 指定技能（命中率 1，且不会被反击/反射）
		if meta.has("SkillCertainHitss"):
			c.certainHit.global = true
		for k in meta:
			if str(k).begins_with("SkillCertainHit") and str(meta[k]).strip_edges().is_valid_int():
				c.certainHit.bySkill[int(str(meta[k]).strip_edges())] = true
		if meta.has("passiveIRUP"):
			c.itemRateUp += _num(meta.passiveIRUP)
	_passive_cache = c

func passive_cache() -> Dictionary:
	return _passive_cache

static func _scan(text: String, pattern: String) -> Array:
	var out := []
	for m in RegEx.create_from_string(pattern).search_all(text):
		var g := []
		for i in range(1, m.get_group_count() + 1):
			g.append(m.get_string(i))
		out.append(g)
	return out


## 战斗开始的加状态标签（dsPassiveSkill Scene_Battle.start）：装备与技能上「前缀＋状态 ID: 概率%」。
## 返回 [[前缀, 状态 ID, 概率], ...]，按前缀分组的顺序（与原版逐个前缀遍历一致）。
const START_STATE_TAGS := ["StartPushState", "StartRomActPushState", "StartRomEmePushState", "StartRomPushState", "StartAEPushState", "StartWTPushState"]

func battle_start_state_tags() -> Array:
	var out := []
	var objs := equip_list() + skills()
	for prefix in START_STATE_TAGS:
		for o in objs:
			for k in o.get("meta", {}):
				var key := str(k)
				if key.begins_with(prefix) and key.substr(prefix.length()).is_valid_int():
					out.append([prefix, int(key.substr(prefix.length())), _num(o.meta[k])])
	return out
