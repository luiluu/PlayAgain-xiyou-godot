class_name XMagicWeapon
extends RefCounted
## 法宝等级与经验（CP_MagicWeapon 1.10+）与按等级学技能（CP_X_MagicWeaponLearnSkill 1.00）。
## 等级、经验存在装备实例上（item.level／item.exp，对应原版独立装备 object().level／exp）；没有这两个字段的实例读
## <Init Level>／<Init Exp>（再缺省取插件参数），读取不写回。每级能力成长见 XActor.magic_param，图标等级字见 XItemRow。
##
## - 升级：gain_exp 加经验后按「下一级所需」逐级升（扣掉所需，余下的留到下一级），满级后不再得经验；
##   下一级所需 = round(eval(<Exp Formula> 或插件「经验公式」))，公式里 level 为当前等级，出错时退回插件内置的
##   3*level*level+40*level+50。
## - 战斗胜利（BattleManager.gainRewards 之后）：全队每件法宝得敌群全体成员（含隐藏的）的 <Magic Weapon Exp>
##   之和（缺省「敌人提供最小经验」）；不在出战栏的按「后援经验比率」四舍五入；<Cannot Gain Exp After Victory> 不得。
## - 插件指令：MagicWeaponAllGainExp exp（全队全部法宝，不看上一条限制；法宝经验丹）、MagicWeaponLevelUp 角色 槽 级数。
## - 升级特性 <Equip LevelUp Trait Weapon|Armor|State: id>：那条记录的特性按法宝等级叠加（1 级就算 1 次）。
## - 按等级学技能 <Magic Weapon Learn Skill x: ALL> 或 <…: y1, y2>（等级在 [y1, y2] 时有）。
## 没做：<Magic Weapon LevelUp Effect>（任意 JS，v0.28 数据里没有装备用到；遇到时记进 unsupported_effects，不执行）；
## 战斗中法宝特性的整场缓存（原版开战后第一次算出就不再变，战斗中法宝等级本来不变，不影响结果）。

const DEFAULT_FORMULA := "3 * level * level + 40 * level + 50"
const PARAMS := "CP_MagicWeapon"

## 遇到 <Magic Weapon LevelUp Effect> 的升级记录（不执行，留给测试与排查）
static var unsupported_effects: Array = []

static var _trait_cache := {}
static var _learn_cache := {}
static var _formula_cache := {}


static func is_magic(item) -> bool:
	return item is Dictionary and not item.is_empty() and item.get("meta", {}).has("Magic Weapon")


## JS Number()：true→1、空串→0、数字串照读，其他为 NaN
static func js_number(v) -> float:
	if v is bool:
		return 1.0 if v else 0.0
	if v is int or v is float:
		return float(v)
	var s := str(v).strip_edges()
	if s == "":
		return 0.0
	return s.to_float() if s.is_valid_float() else NAN


## Math.round(Number(v) || fallback)
static func _round_or(v, fallback: float) -> float:
	var n := js_number(v)
	return XPower.js_round(n if not is_nan(n) and n != 0.0 else fallback)


static func _param(key: String, fallback: float) -> float:
	return _round_or(XDB.plugin(PARAMS).get(key, fallback), fallback)


static func level_of(item) -> float:
	return float(XEquipmentView.level(item)) if item is Dictionary else -1.0


static func max_level(item: Dictionary) -> float:
	if not is_magic(item):
		return -1.0
	return _round_or(item.meta.get("Max Level", null), _param("Max Level", 15))


static func exp_of(item: Dictionary) -> float:
	if not is_magic(item):
		return -1.0
	if item.has("exp"):
		return float(item.exp)
	return _round_or(item.meta.get("Init Exp", null), _param("Init Exp", 0))


static func use_exp(item: Dictionary) -> float:
	return _round_or(item.meta.get("Use Exp", null), _param("Use Exp", 0)) if is_magic(item) else -1.0


## Game_Item.nextLevelExp
static func next_level_exp(item: Dictionary) -> float:
	var lv := level_of(item)
	if lv < 0.0:
		return -1.0
	var formula := str(item.meta.get("Exp Formula", "")) if item.meta.get("Exp Formula", null) is String else ""
	if formula == "":
		formula = str(XDB.plugin(PARAMS).get("Init Exp Formula", DEFAULT_FORMULA))
	var v := _eval(formula, lv)
	if is_nan(v):
		v = _eval(DEFAULT_FORMULA, lv)
	return XPower.js_round(v)


static func _eval(formula: String, lv: float) -> float:
	if not _formula_cache.has(formula):
		var e := Expression.new()
		_formula_cache[formula] = e if e.parse(formula, ["level"]) == OK else null
	var ex = _formula_cache[formula]
	if ex == null:
		return NAN
	var v = ex.execute([lv])
	if ex.has_execute_failed() or not (v is float or v is int):
		return NAN
	return float(v)


## Game_Item.gainExp：满级不得；加完按下一级所需逐级升
static func gain_exp(item: Dictionary, amount: float, user: XActor = null) -> void:
	if not is_magic(item) or level_of(item) >= max_level(item):
		return
	var real := XPower.js_round(exp_of(item) + amount)
	item.exp = real
	while level_of(item) < max_level(item) and real >= next_level_exp(item):
		level_up(item, user)
		real = exp_of(item)


## Game_Item.levelUp：所需按升级前的等级算；已满级时只把经验设成所需（MagicWeaponLevelUp 对满级法宝）
static func level_up(item: Dictionary, user: XActor = null) -> bool:
	if not is_magic(item):
		return false
	var cur := exp_of(item)
	var need := next_level_exp(item)
	if level_of(item) < max_level(item):
		item.level = level_of(item) + 1.0
		item.exp = maxf(0.0, cur - need)
		_level_up_effect(item, user)
	else:
		item.exp = need
	return true


## CP_X_MagicWeaponLearnSkill 先 user.refresh()（学技能缓存作废），再跑 <Magic Weapon LevelUp Effect>
static func _level_up_effect(item: Dictionary, user: XActor) -> void:
	if user != null:
		user.refresh_passive()
		user.refresh_resources()
	if str(item.get("note", "")).contains("<Magic Weapon LevelUp Effect>"):
		unsupported_effects.append({"base": int(item.get("base", 0)), "level": level_of(item)})


## 敌人 <Magic Weapon Exp: x>：Math.round(Number(x)) || 敌人提供最小经验
static func enemy_exp(enemy_data: Dictionary) -> float:
	var n := XPower.js_round(js_number(enemy_data.get("meta", {}).get("Magic Weapon Exp", null)))
	return n if not is_nan(n) and n != 0.0 else _param("Enemy Min Exp", 0)


## BattleManager.gainRewards 之后：members 为全队，battle 为出战成员，troop 为敌群全体（XEnemy，含隐藏的）
static func gain_victory_exp(members: Array, battle: Array, troop: Array) -> void:
	var total := 0.0
	for e in troop:
		total += enemy_exp(e.data())
	var rate := js_number(XDB.plugin(PARAMS).get("Exp Rate Not Battler", 0))
	if is_nan(rate):
		rate = 0.0
	for a in members:
		for item in a.equips:
			if not is_magic(item) or item.get("meta", {}).has("Cannot Gain Exp After Victory"):
				continue
			gain_exp(item, total if battle.has(a) else XPower.js_round(total * rate), a)


## Game_Party.gainAllEquipExp（MagicWeaponAllGainExp）
static func party_gain_exp(s: XState, amount: float) -> void:
	for a in s.members():
		for item in a.equips:
			if is_magic(item):
				gain_exp(item, amount, a)


## 插件指令；认得就返回 true
static func plugin_command(s: XState, args: PackedStringArray) -> bool:
	match args[0]:
		"MagicWeaponAllGainExp":
			party_gain_exp(s, _arg(args, 1))
			return true
		"MagicWeaponLevelUp":
			var aid := int(_arg(args, 1))
			var slot := int(_arg(args, 2))
			var times := int(_arg(args, 3))
			var a: XActor = s.actor(aid) if aid > 0 and not XDB.rec("Actors", aid).is_empty() else null
			if a != null and slot >= 0 and slot < a.equips.size():
				for i in range(times):
					if is_magic(a.equips[slot]):
						level_up(a.equips[slot], a)
			return true
	return false


## Number(args[i]) || 0
static func _arg(args: PackedStringArray, i: int) -> float:
	var n := js_number(args[i]) if i < args.size() else 0.0
	return n if not is_nan(n) else 0.0


## Game_Item.levelUpTraitObject：<Equip LevelUp Trait Weapon|Armor|State: id>（按数据库原件解析一次）
static func level_up_trait_object(item: Dictionary) -> Dictionary:
	if not is_magic(item):
		return {}
	var key := _key(item)
	if not _trait_cache.has(key):
		var m := RegEx.create_from_string("<Equip LevelUp Trait (Weapon|Armor|State): (\\d+)>").search(str(_base(item).get("note", "")))
		var rec := {}
		if m:
			rec = XDB.rec({"Weapon": "Weapons", "Armor": "Armors", "State": "States"}[m.get_string(1)], int(m.get_string(2)))
		_trait_cache[key] = rec
	return _trait_cache[key]


## Game_Actor.traitObjects 追加：每件法宝的升级特性对象按等级重复
static func trait_objects(equips: Array) -> Array:
	var out := []
	for item in equips:
		if not is_magic(item):
			continue
		var o := level_up_trait_object(item)
		if o.is_empty():
			continue
		for i in range(int(level_of(item))):
			out.append(o)
	return out


## CP_X_MagicWeaponLearnSkill loadEquipSkillLearnData：逐行匹配，ALL 永久；否则取「y1, y2」，y1、y2 都大于 0 且 y2≥y1 才收
static func learn_data(item: Dictionary) -> Array:
	var key := _key(item)
	if not _learn_cache.has(key):
		var out := []
		var re := RegEx.create_from_string("<Magic Weapon Learn Skill (\\d+): ([\\s\\S]+)>")
		for line in str(_base(item).get("note", "")).split("\n"):
			var m := re.search(line)
			if m == null:
				continue
			var sid := int(m.get_string(1))
			var text := m.get_string(2).strip_edges().to_upper()
			var lo := 0.0
			var hi := 0.0
			var all := text == "ALL"
			if not all:
				var parts := text.split(",")
				lo = _num_or_zero(parts[0])
				hi = _num_or_zero(parts[1]) if parts.size() > 1 else 0.0
			if sid > 0 and ((lo > 0 and hi > 0 and hi >= lo) or all):
				out.append({"id": sid, "min": lo, "max": hi, "all": all})
		_learn_cache[key] = out
	return _learn_cache[key]


static func _num_or_zero(s: String) -> float:
	var n := js_number(s)
	return n if not is_nan(n) else 0.0


## Game_Item.magicWeaponSkills：这件法宝当前等级给的技能编号
static func item_skills(item) -> Array:
	if not is_magic(item):
		return []
	var lv := level_of(item)
	var out := []
	for d in learn_data(item):
		if d.all or (lv >= d.min and lv <= d.max):
			out.append(int(d.id))
	return out


## Game_Actor.magicWeaponSkills：全部装备槽
static func skills(equips: Array) -> Array:
	var out := []
	for item in equips:
		out.append_array(item_skills(item))
	return out


## 数据库原件（实例复制原件；载入时的解析按原件备注）
static func _base(item: Dictionary) -> Dictionary:
	var rec := XDB.rec("Weapons" if str(item.get("kind", "")) == "weapon" else "Armors", int(item.get("base", item.get("id", 0))))
	return rec if not rec.is_empty() else item


static func _key(item: Dictionary) -> String:
	return str(item.get("kind", "")) + ":" + str(int(item.get("base", item.get("id", 0))))
