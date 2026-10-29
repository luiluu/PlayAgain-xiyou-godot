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
## 事件「更改名字」320、「更改角色图像」322 改过的字段（name／characterName／characterIndex／faceName／faceIndex／battlerName），
## 空＝数据库原样；data() 把它盖在数据库记录上（MV Game_Actor._name、_characterName 等），随存档（looks）
var looks := {}
## MV Game_Actor._exp 里别的职业的经验（「更改职业」321 不保留经验时，换回原职业取回原经验）；当前职业的经验在 exp_total
var class_exp := {}
var _looks_src = null
var _looks_out := {}


func setup(id: int) -> XActor:
	actor_id = id
	var d := data()
	class_id = int(d.classId)
	_lv = int(d.initialLevel)
	nickname = str(d.get("nickname", ""))
	exp_total = exp_for_level(_lv)
	for l in class_data().get("learnings", []):
		if int(l.level) <= _lv:
			learn_skill(int(l.skillId))
	init_equips(d.get("equips", []))
	_fix_strong_classification()
	recover_all()
	XActorModules.setup(self)  # 专属角色模块的 Game_Actor.setup 包装（饿狼同步形态等）
	return self


## installNativeMiraRuntime 的 fixStrongClassification（Game_Actor.setup 之后）：141～172 号角色一律算强者——
## 忘弱者压制 6235、学强者压制 6216、旧档 5970 换 5971，去掉 1035／1276／1277。强弱分档系数本身属五乘区，按数值平衡不移植。
func _fix_strong_classification() -> void:
	if actor_id < 141 or actor_id > 172:
		return
	forget_skill(6235)
	learn_skill(6216)
	if skill_ids.has(5970):
		forget_skill(5970)
		learn_skill(5971)
	for sid in [1035, 1276, 1277]:
		if state_ids.has(sid):
			remove_state(sid)


func data() -> Dictionary:
	var rec := XDB.rec("Actors", actor_id)
	if looks.is_empty():
		return rec
	if not is_same(_looks_src, rec) or _looks_out.is_empty():
		_looks_out = rec.duplicate()
		_looks_out.merge(looks, true)
		_looks_src = rec
	return _looks_out

## 320／322：改名字或图像（Game_Actor.setName／setCharacterImage／setFaceImage／setBattlerImage）
func set_looks(fields: Dictionary) -> void:
	looks.merge(fields, true)
	_looks_out = {}

## Game_Actor.changeClass（321）：保留经验时新职业取当前经验，否则取新职业记下的经验（没有为 0），再按 changeExp 升降级；
## 降级不忘技能（MV levelDown 只减等级）
func change_class(id: int, keep_exp: bool) -> void:
	if XDB.rec("Classes", id).is_empty():
		return
	class_exp[class_id] = exp_total
	if keep_exp:
		class_exp[id] = exp_total
	class_id = id
	exp_total = maxi(int(class_exp.get(id, 0)), 0)
	while _lv < max_level() and exp_total >= exp_for_level(_lv + 1):
		_level_up()
	while _lv > 1 and exp_total < exp_for_level(_lv):
		_lv -= 1
	refresh_passive()
	refresh_resources()

func class_data() -> Dictionary:
	return XDB.rec("Classes", class_id)

func is_actor() -> bool:
	return true

func display_name() -> String:
	return str(data().get("name", ""))

func _level() -> int:
	return _lv


# ---- 装备 ----
## 西游正式版每位角色 19 个槽，对应 System.equipTypes 1..19；双持时第 2 格（副手）改为武器（YEP_EquipCore equipSlots）。
func equip_slots() -> Array:
	var out := []
	for i in range(1, XDB.system().equipTypes.size()):
		out.append(i)
	if out.size() >= 2 and is_dual_wield():
		out[1] = 1
	return XCat.equip_slots(self, out)  # 178 哈基米去掉副手

## MV Game_BattlerBase.slotType／isDualWield：特性 55 的最大值，1 为双持（职业、角色、装备、状态都可给，如刘备的专属剑 2005）
func slot_type() -> int:
	var types := traits_set(55)
	return types.max() if not types.is_empty() else 0

func is_dual_wield() -> bool:
	return slot_type() == 1 and not XCat.own(self)

## 初始装备（YEP_ItemCore initIndependentEquips）：convertInitEquips 第 1 项与双持时的第 2 项查武器表、其余查防具表（编号 ≤0 跳过）；
## 槽位类型在开头取一次，逐槽 grabInitEquips（武器槽取表里第一把武器，其余取同装备类型的第一件），能装备才装；
## 最后 releaseUnequippableItems(true)：装上后槽位类型变了（如装了带双持的武器）而不合的直接丢掉，不进背包。
func init_equips(ids: Array) -> void:
	refresh_passive()   # 可装备判断要用已学技能的被动（passiveEWPN）
	var dual := is_dual_wield()
	var items := []
	for i in range(ids.size()):
		var id := int(ids[i]) if ids[i] != null else 0
		if id <= 0:
			continue
		var weapon := i == 0 or (i == 1 and dual)
		var base := XDB.rec("Weapons" if weapon else "Armors", id)
		items.append(make_equip("weapon" if weapon else "armor", id) if not base.is_empty() else null)
	var slots := equip_slots()
	equips.clear()
	equips.resize(slots.size())
	for i in range(slots.size()):
		var picked := -1
		for j in range(items.size()):
			var e = items[j]
			if e != null and ((int(slots[i]) == 1 and e.kind == "weapon") or int(e.etypeId) == int(slots[i])):
				picked = j
				break
		if picked < 0:
			continue
		var item: Dictionary = items[picked]
		items[picked] = null
		if can_equip(item):
			equips[i] = item
			refresh_passive()
	release_unequippable()
	refresh_passive()

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

## 槽位类型不符或不能装备的卸下（MV releaseUnequippableItems，反复直到稳定）。返回卸下的件（换装时退回背包）。
func release_unequippable() -> Array:
	var removed := []
	var changed := true
	while changed:
		changed = false
		var slots := equip_slots()   # 每轮重取：卸下带双持的武器后第 2 格变回副手
		for i in range(equips.size()):
			var e = equips[i]
			if e != null and not e.is_empty() and (int(e.etypeId) != int(slots[i]) or not can_equip(e)):
				removed.append(e)
				equips[i] = null
				changed = true
	return removed

## Game_Actor.refresh 开头 releaseUnequippableItems(false)：不能再装的卸下、退回队伍背包，之后不自动穿回。
## 难度 2～4 的被动 5980「难度适应」开战附加 Permanent 状态 1691（封印宝宝／坐骑／圣器／形态 18／16／15／19），首战就把这几格卸进背包，
## 战后状态不解除、仍不能装（技能说明写明「无法装备宝宝，坐骑，圣器，形态」，属原版设计）。加减状态内部的 refresh 同样会卸。
## 只有队伍里的本体才把卸下的件放回背包；战力预览等克隆只卸不入包。
## 只给参照对照夹具用：同 custom_params_probe 在实例上停掉 releaseUnequippableItems（直接装上别的角色专属的件）
var keep_unequippable := false

func release_to_party() -> void:
	if keep_unequippable:
		return
	var removed := release_unequippable()
	if removed.is_empty():
		return
	refresh_passive()
	var s := XState.current
	if s != null and s.actors.get(actor_id) == self:
		s.gear.append_array(removed)

func add_state(id: int, random: XRandomStream = null) -> void:
	# 异化疫囊 addProtected：受保护状态直接走 Game_Battler.addState，绕过角色侧的拦截
	if not XAlienBattle.pest_state(self, id) and (XQiyu.blocks_state(actor_id, id) or (STRONG_WEAK_STATES.has(id) and is_strong_classified())):
		return
	var fresh := not state_ids.has(id)
	super(id, random)
	if fresh and state_ids.has(id) and lifecycle_context.get("resources") == null:
		release_to_party()

func remove_state(id: int) -> void:
	var had := state_ids.has(id)
	super(id)
	if had:
		release_to_party()

func refresh_resources(random: XRandomStream = null) -> void:
	super(random)

func equip_list() -> Array:
	var list := equips.slice(1) if _cat_bare else equips
	return list.filter(func(e): return e != null and not e.is_empty())


## 算能力值／特性／被动缓存用的装备：178 持剑时武器槽换成剑的翻倍视图（XCat.sword_view），其余同 equip_list
var _cat_bare := false
func stat_equips() -> Array:
	var list := equip_list()
	if XCat.enabled_sword(self):
		list[0] = XCat.sword_view(equips[0])
	return list


## Game_Actor.weapons()[0]
func first_weapon() -> Dictionary:
	for e in equip_list():
		if e.get("kind", "") == "weapon":
			return e
	return {}


## Game_Actor.attackElements（rpg_οbjects.js:3970）：没装武器时另加空手属性物理(1)，
## 所以带攻击属性特性的角色（154 火、158 雷）空手普攻是「本属性＋物理」。
func attack_elements() -> Array:
	var es := super()
	if first_weapon().is_empty() and not es.has(1):
		es.append(1)
	return es


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
	XActorModules.level_up(self)  # 专属角色模块的 levelUp 包装

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
		XActorModules.level_down(self)  # 专属角色模块的 levelDown 包装
	refresh_passive()
	refresh_resources()  # Game_Actor.changeExp 最后 refresh，降级后夹回新 HP/MP 上限。
	return skill_ids.filter(func(id): return not before.has(id))

## 直接设定等级（读档、测试夹具用）：只按数据库上限夹，不看队伍上限，不加技能点
func change_level(lv: int) -> void:
	var before := _lv
	_lv = clampi(lv, 1, int(data().get("maxLevel", 99)))
	exp_total = exp_for_level(_lv)
	for l in class_data().get("learnings", []):
		if int(l.level) <= _lv:
			learn_skill(int(l.skillId))
	XActorModules.level_changed(self, before)  # 直接改等级：按升／降调专属角色模块的 levelUp／levelDown 包装
	refresh_passive()

## 获得经验，返回升了几级。
## YEP_CoreEngine：已到等级上限不再获得经验。rate 为 MV finalExpRate 里的出战/后备系数。
func gain_exp(amount: int, rate := 1.0, random: XRandomStream = null) -> int:
	var before := _lv
	if _lv >= max_level():
		return 0
	exp_total += int(roundf(amount * exr * rate))
	while _lv < max_level() and exp_total >= exp_for_level(_lv + 1):
		_level_up()
	if _lv != before:
		refresh_passive()
		refresh_resources(random)
	return _lv - before


# ---- 技能 ----
## installStrongActorClassificationRuntime：167～174、<GuyuActor>、<CodexSuperStrong> 的角色学弱者分档技能时改学强者那档，且不挂弱者状态
const STRONG_SKILL_REPLACE := {5968: 5969, 5970: 5971, 5972: 5973, 6235: 6216}
const STRONG_WEAK_STATES := [1035, 1273, 1274, 1276, 1277, 1279, 1280]

func is_strong_classified() -> bool:
	var note := str(data().get("note", ""))
	return (actor_id >= 167 and actor_id <= 174) or note.contains("<GuyuActor>") or note.contains("<CodexSuperStrong>")

## 读档修复（extractSaveContents 里 repair）：弱者分档技能换成强者那档，去掉弱者状态
func repair_strong_classified() -> void:
	if not is_strong_classified():
		return
	for weak in STRONG_SKILL_REPLACE:
		if skill_ids.has(weak):
			forget_skill(weak)
			learn_skill(weak)
	for st in STRONG_WEAK_STATES:
		if state_ids.has(st):
			state_ids.erase(st)
			state_turns.erase(st)
	refresh_passive()

func learn_skill(id: int) -> void:
	if XRace.learn(XState.current, self, id):  # installNativeRaceRuntime learnSkill 包装：种族技能改种族数据再 sync
		return
	if STRONG_SKILL_REPLACE.has(id) and is_strong_classified():
		id = STRONG_SKILL_REPLACE[id]
	if not XActorModules.can_learn(self, id) or (XPowerBooks.is_power(id) and not XPowerBooks.learn_reason(self, id).is_empty()):
		return
	if not skill_ids.has(id) and not XDB.rec("Skills", id).is_empty():
		skill_ids.append(id)
		skill_ids.sort()

func forget_skill(id: int) -> void:
	if XPowerBooks.protected_forget(self, id):
		return
	skill_ids.erase(id)

func skills() -> Array:
	var ids: Array[int] = skill_ids.duplicate()
	for t in all_traits():
		if int(t.code) == TRAIT_SKILL_ADD and not ids.has(int(t.dataId)):
			ids.append(int(t.dataId))
	for id in XEquipSuits.ids(self,"skills"):
		if not ids.has(id):ids.append(id)
	for id in XMagicWeapon.skills(equips):  # CP_X_MagicWeaponLearnSkill：法宝按等级学的技能；O-099 去重（原版 concat 不去重）
		if not ids.has(id):ids.append(id)
	if XAlienBattle.devours(self):  # 异化饕餮 skills 包装（Adv:86）：战斗中多吞噬技能（原版 push 不去重）
		ids.append(XAlienBattle.devour_id())
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
	out.append_array(stat_equips())
	out.append_array(states())
	out.append_array(XMagicWeapon.trait_objects(equips))  # CP_MagicWeapon：升级特性对象按法宝等级重复
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
	return super.param_rate(i) * XEquipSuits.value(self,"param",i,true) * (1.0 + XPowerBooks.param_rate_bonus(self, i) / 100.0)

# ---- dsPassiveSkill：被动标签只从已有技能读取 ----
func passive_values(tag: String) -> Array:
	var out := []
	for s in skills():
		var m: Dictionary = s.get("meta", {})
		if m.has(tag):
			out.append(m[tag])
	return out

## Game_Actor.replaceAttackSkillId：状态 → 装备（按槽序）→ 技能 → 职业 → 角色
func replace_attack_objects() -> Array:
	var out := super.replace_attack_objects()
	out.append_array(equip_list())
	out.append_array(skills())
	out.append(class_data())
	out.append(data())
	return out

## Game_Actor.weaponUnleashes：状态 → 装备（按槽序）→ 职业 → 角色
func weapon_unleash_objects() -> Array:
	var out := super.weapon_unleash_objects()
	out.append_array(equip_list())
	out.append(class_data())
	out.append(data())
	return out

const TOJI := 171
const TOJI_MAIN := [10216, 10217, 10218, 10219]
const TOJI_SHAPES := [2630, 2631, 2632, 2633]

## 甚尔（installNativeTojiRuntime）：普攻是当前形态的主技能（没有形态状态算第一形态）；宿傩（installNativeSukunaRuntime）恒为 10238
func attack_skill_id() -> int:
	if actor_id == TOJI:
		for i in TOJI_SHAPES.size():
			if is_state_affected(TOJI_SHAPES[i]):
				return TOJI_MAIN[i]
		return TOJI_MAIN[0]
	if actor_id == XSukuna.ACTOR:
		return 10238
	return super.attack_skill_id()

## 指令窗「攻击」那一项的名字：YEP_WeaponUnleash addAttackCommand 取技能的 commandAttackText（备注 <Command Text: x>／<Attack Text: x>，
## 同义 Name，后写的盖前面；没有就技能名）；甚尔（installNativeTojiRuntime）直接用技能名
func attack_command_text() -> String:
	var skill := attack_skill()
	if actor_id == TOJI:
		return str(skill.get("name", ""))
	var text := str(skill.get("name", ""))
	for line in str(skill.get("note", "")).split("\n"):
		var m := _command_text_line.search(line)
		if m:
			text = m.get_string(2)
	return text

static var _command_text_line := RegEx.create_from_string("(?i)<(COMMAND NAME|COMMAND TEXT|ATTACK NAME|ATTACK TEXT):[ ](.*)>")

## 道法（XZhenqi）：连击普攻次数＋1、分神必定再动＋1
func attack_times_add() -> float:
	return super.attack_times_add() + (1.0 if XZhenqi.has_daofa(self, "lianji") else 0.0)

func action_plus_set() -> Array:
	var out := super.action_plus_set()
	# dsPassiveSkill Game_Actor.actionPlusSet：每个 <passiveAPLUS:N%> 被动加一项追加行动几率（取第一个整数 ×0.01）
	for m in passive_values("passiveAPLUS"):
		var found := RegEx.create_from_string("(\\d+)").search(str(m))
		if found:
			out.append(float(found.get_string(1)) * 0.01)
	if XZhenqi.has_daofa(self, "fenshen"):
		out.append(1.0)
	XActorModules.action_plus_set(self, out)  # 专属角色模块的 actionPlusSet 包装（黄泉 10175）
	return out

## dsPassiveSkill：passiveSUBS 掩护、passivePRETP 保留 TP（灵台、护法等技能）
func is_substitute() -> bool:
	return super.is_substitute() or not passive_values("passiveSUBS").is_empty()

func is_preserve_tp() -> bool:
	return super.is_preserve_tp() or not passive_values("passivePRETP").is_empty()

## dsPassiveSkill：<passiveATKST状态编号:付与率%> 加进攻击附加状态，付与率按 % 加到 attackStatesRate（如破甲 2705:100%）
func attack_states() -> Array:
	var out := super.attack_states()
	for s in skills():
		for k in s.get("meta", {}):
			if str(k).begins_with("passiveATKST") and str(k).substr(12).is_valid_int() and not out.has(int(str(k).substr(12))):
				out.append(int(str(k).substr(12)))
	return out

func attack_states_rate(id: int) -> float:
	var v := super.attack_states_rate(id)
	for m in passive_values("passiveATKST%04d" % id):
		v += _num(m) * 0.01
	return v

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
	v += XTraining.param_bonus(self, i)
	return v

## 装备属性；被动 passiveWPNMxx / passiveARMMxx 按武器/防具类型放大该装备的正值属性。
## 178 持剑：全量＋(全量−去掉武器槽)，即剑的整份贡献再算一遍（CodexCat paramPlus 包装）
func param_plus(i: int) -> float:
	var full := _param_plus(i)
	if not XCat.enabled_sword(self):
		return full + XRaceBattle.param_plus(self, i)
	_cat_bare = true
	var bare := _param_plus(i)
	_cat_bare = false
	return full + (full - bare) + XRaceBattle.param_plus(self, i)  # 种族灵族：武器本体 ×q/2（包在小猫剑圣外层）

func _param_plus(i: int) -> float:
	var v := XParamPlus.bonus(self, i) + XEquipSuits.value(self,"param",i,false)
	for e in equip_list():
		var p := float(e.params[i])
		v += p
		if p > 0.0:
			var tag := ("passiveWPNM%02d" % int(e.wtypeId)) if e.kind == "weapon" else ("passiveARMM%02d" % int(e.atypeId))
			for m in passive_values(tag):
				v += _param_boost(p, m)
		v += magic_param(e, i)
		v += custom_param(e, i)
	return XActorModules.param_plus(self, i, v)  # 专属角色模块的 paramPlus 包装（黄泉 10176／10177／10182）

## YEP_EquipCore evalParamPlus：<Custom Parameters> 由转换器解析成每项能力的 常数 + 等级系数 × 等级 + Σ 变量系数 × v[编号]，
## 每次按当前等级与变量求值；不受 passiveWPNM／ARMM 放大（那只看 item.params）。原件按数据库基础编号取（实例复制原件的 parameterEval）。
static var _custom_param_cache := {}
func custom_param(e: Dictionary, i: int) -> float:
	var kind := str(e.get("kind", ""))
	var base := int(e.get("base", e.get("id", 0)))
	var key := kind + ":" + str(base)
	if not _custom_param_cache.has(key):
		var rec := XDB.rec("Weapons" if kind == "weapon" else "Armors", base)
		_custom_param_cache[key] = (rec if not rec.is_empty() else e).get("customParams", {}).get("params", [])
	var terms: Array = _custom_param_cache[key]
	if terms.is_empty():
		return 0.0
	var t: Dictionary = terms[i]
	var v := float(t.k) + float(t.level) * _lv
	for vid in t.vars:
		v += float(t.vars[vid]) * (XState.current.variable(int(vid)) if XState.current else 0.0)
	return v

## CP_MagicWeapon paramPlus：法宝加 等级 × 每级成长；成长在载入时从数据库原件备注解析一次（实例复制原件的 paramPlusPerLevel），
## 不受 passiveWPNM／ARMM 放大。等级取 XEquipmentView.level（实例 level，缺省 <Init Level>）。
static var _magic_growth_cache := {}
static func magic_param(e: Dictionary, i: int) -> float:
	var lv = XEquipmentView.level(e)
	if float(lv) < 0.0:
		return 0.0
	var kind := str(e.get("kind", ""))
	var key := kind + ":" + str(int(e.get("base", e.get("id", 0))))
	if not _magic_growth_cache.has(key):
		var rec := XDB.rec("Weapons" if kind == "weapon" else "Armors", int(e.get("base", e.get("id", 0))))
		_magic_growth_cache[key] = XPower.magic_growth(rec if not rec.is_empty() else e)
	return float(lv) * float(_magic_growth_cache[key][i])

## 178 哈基米的 param 包装（速度 ×1.88、抱剑喵铃 ×1.6），在 G_StateParam 之外
func param(i: int) -> float:
	return XRaceBattle.param(self, i, XAlienBattle.param(self, i, param_before_alien(i)))  # 按原版安装先后由内到外：专属角色模块（米拉 98、宿傩 113）→小猫剑圣（115）→异化逆骨（129）→种族祝福（148）

## 异化包装之内的取值（逆骨的物攻改读物防取这一层，原版 old.call(this, 3)）
func param_before_alien(i: int) -> float:
	return XCat.param(self, i, XActorModules.param(self, i, super.param(i)))

## 永久写能力属于当前真实实例；影子克隆虽保留actor_id，也不能借它写真实账本。
func can_add_param() -> bool:
	if XState.current == null or XState.current.actors.get(actor_id) != self:
		return false
	var resources: XResourceContext = lifecycle_context.get("resources")
	return bool(lifecycle_context.get("execute", true)) and not bool(lifecycle_context.get("preview", false)) and (resources == null or not resources.preview)

## 永久 addParam 复用事件 317 的同一存档字段，每次调用按原版单独刷新。
func add_param(i: int, value: float) -> void:
	if can_add_param():
		XParamPlus.add(XState.current, actor_id, i, value)


## Star_PetSystem 在 traitsSum 层相加，先于被动／套装倍率与命中保底。
func traits_sum(code: int, id: int) -> float:
	var v := super.traits_sum(code, id)
	if code == TRAIT_XPARAM and XState.current != null:
		v += XPets.war_xparam_plus(XState.current, id)
	return v


## 正式版运行时对角色命中率保底 0.9（命中 = xparam 0）。
func xparam(i: int) -> float:
	var v := super.xparam(i)
	for m in passive_values(_tag("passiveXPBST", i)):
		v += _num(m) * 0.01
	v = (v + XEquipSuits.value(self,"xparam",i,false)/100) * XEquipSuits.value(self,"xparam",i,true)
	v = XActorModules.xparam(self, i, v)  # 专属角色模块的 Game_Actor.xparam 包装（米拉／渡鸦面板暴击）
	return maxf(0.9, v) if i == 0 else v

func sparam(i: int) -> float:
	var v := traits_pi(TRAIT_SPARAM, i)
	for m in passive_values(_tag("passiveSPBST", i)):
		v += _num(m) * 0.01
	v = (v + XEquipSuits.value(self,"sparam",i,false)/100) * XEquipSuits.value(self,"sparam",i,true)
	if i == 6 or i == 7:
		return XCat.sparam(self, i, additive_rate(TRAIT_SPARAM, i, v, []))
	return v

func passive_element_values(e: int) -> Array:
	return passive_values("passiveELEM%02d" % e).map(func(m): return _num(m) / 100.0)


# ---- 伤害结算用的被动缓存（dsPassiveSkill refreshPassiveCache，单次汇总）----
func refresh_passive() -> void:
	var c := {"harmRe": {}, "penetrateFixed": {}, "penetratePercent": {}, "skillPass": {}, "skillTypeDvup": {},
		"SkETypeHarmRi": {}, "globalHarmRi": 0.0, "critHarmRi": 0.0, "itemRateUp": 0.0,
		"certainHit": {"global": false, "bySkill": {}}, "damageElement": 0,
		"consumeReduce": {"bySkill": {}, "byType": {"Zj": 0, "Mf": 0}, "all": 0}}
	var objs := stat_equips() + skills() + states()
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
		# dsPassiveSkill <DamageElements: N>：覆盖所有伤害技能的属性（摇光的圣光体：任何伤害都转神圣）；后读到的覆盖先读到的
		if meta.has("DamageElements") and str(meta.DamageElements).strip_edges().is_valid_int():
			c.damageElement = int(str(meta.DamageElements).strip_edges())
		if meta.has("passiveIRUP"):
			c.itemRateUp += _num(meta.passiveIRUP)
		# dsPassiveSkill读取meta（重复同名标签取最后一条），parseInt按首个有符号整数解析。
		for key in meta:
			var tag := str(key)
			if not tag.begins_with("ConsumeReduce"):
				continue
			var number := RegEx.create_from_string("^\\s*([+-]?\\d+)").search(str(meta[key]))
			if number == null:
				push_error("ConsumeReduce标签不是整数：" + tag + ":" + str(meta[key]))
				continue
			var value := int(number.get_string(1))
			var suffix := tag.substr(13)
			if suffix == "All":
				c.consumeReduce.all += value
			elif suffix in ["Zj", "Mf"]:
				c.consumeReduce.byType[suffix] += value
			elif suffix.is_valid_int():
				var id := int(suffix)
				c.consumeReduce.bySkill[id] = c.consumeReduce.bySkill.get(id, 0) + value
	XActorModules.passive_cache(self, c)  # 专属角色模块的 initPassiveCache 包装（渡鸦魂海刻度的暴伤／终伤池）
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
