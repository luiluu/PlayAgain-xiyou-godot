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
	return max_level_in(item, XState.current)


static func max_level_in(item: Dictionary, state: XState) -> float:
	var own := raw_max_level(item)
	if own < 0.0:
		return -1.0
	var cap := level_cap(state)
	return minf(own, float(cap)) if cap > 0 else own


## O-388（法宝与积分重构 v0.2，Kyo 11-13 通过）：西游本体的法宝上限。原版插件参数 Max Level 888 对全部法宝生效（另有 18 件
## 备注也写 888），一颗究极丹（100 万经验）就到 331 级，10 级角色几十万生命。
## - LEVEL_99：上限封到 99；回退 `XMagicWeapon.LEVEL_99 = false`（照原版 888）。
## - FLOOR_CAP：再跟楼层走，上限 ＝ min(99, 9 ＋ 3 × 最高到达层)，最高到达层＝变量 20（至少 1）：1 层 12、10 层 39、30 层 99；
##   回退 `XMagicWeapon.FLOOR_CAP = false`（只封 99）。
## 超过上限的经验作废（照原版满级不得经验）；已经超过楼层上限的法宝存档保留原/折算等级，生效与显示按本层上限，升层后自动恢复。
## - TIANQI_TOO：天启篇存档（现在的新开局入口）也照这个上限；`XMagicWeapon.TIANQI_TOO = false` 时天启篇照数据。
## 天启篇法宝的阶（XTianqiAffixRoll.artifact_tier_of）按 top_level（封 99、不跟楼层）算，楼层上限不让阶提前满。
static var LEVEL_99 := true
static var FLOOR_CAP := true
static var TIANQI_TOO := true
const CAP_TOP := 99

## O-662（T468＋T476，Kyo 11-24「99级法宝总数值和888级旧版数值一样」「超过99级的法宝等比例折算等级并且仍然受到层数上限限制」）：
## - 西游档（非天启篇）法宝在 99 级封顶下，1～99 级按线性折算使 99 级总成长属性精确等于原版 888 级总值（原上限 ÷ 99）；
## - 读档时老存档 >99 级法宝按 round(旧等级 × 99 / 888) 折算写回存档（封顶 99），加迁移标记只折一次；≤99 级不动；
## - 折算后再受当前楼层上限限制：存档保留折算值，生效与显示按本层上限，层数上限提高后自动恢复，不丢等级；
## - 天启篇存档零改动；无存档上下文不启用。回退：`XMagicWeapon.SCALE_99_TO_888 = false`。
static var SCALE_99_TO_888 := true
const OLD_LEVEL_MIGRATE_MARK := "fabao_old_lv_scaled_v1"


## 数据原版满级（不受 LEVEL_99／FLOOR_CAP 影响）；不是法宝返回 -1
static func raw_max_level(item: Dictionary) -> float:
	if not is_magic(item):
		return -1.0
	return _round_or(item.meta.get("Max Level", null), _param("Max Level", 15))


## 本次是否启用「西游档 99→原版上限（888）折算」：
## 须同时满足 SCALE_99_TO_888 与 LEVEL_99 均开启、已载入西游档（非天启篇）、法宝原上限 > CAP_TOP（99）。
static func scale_active(item = null, state: XState = null) -> bool:
	if not SCALE_99_TO_888 or not LEVEL_99:
		return false
	var s := state if state != null else XState.current
	if s == null or XTianqi.active(s):
		return false
	if item is Dictionary:
		return raw_max_level(item) > float(CAP_TOP)
	return true


## 老存档 >99 级法宝的 888→99 等比例折算公式：新等级 = clamp(round(旧等级 × 99 / 原上限), 1, 99)（888→99、331→37、1000→99）。
static func convert_old_level(old_lv: float, orig_max: float = 888.0) -> int:
	var denom := orig_max if orig_max > float(CAP_TOP) else 888.0
	return clampi(int(XPower.js_round(old_lv * float(CAP_TOP) / denom)), 1, CAP_TOP)


## 法宝当前生效等级：
## - 存档保留原值／折算后的等级（由 level_of 读取），绝不因楼层上限低而砍掉存档等级；
## - 西游档启用 99→888 折算（scale_active）时，超过当前楼层上限（max_level_in）的按上限生效，层数提高后自动恢复；
## - 天启篇、无存档上下文或回退关折算时照原等级返回，天启篇零改动。
static func effective_level(item, state: XState = null) -> float:
	var lv := level_of(item)
	if lv < 0.0:
		return -1.0
	var s := state if state != null else XState.current
	if not scale_active(item, s):
		return lv
	var cap := max_level_in(item, s)
	return minf(lv, cap) if cap > 0.0 else lv


## 伤害公式、状态与升级特性读原版等效等级。领悟、升级和显示继续用实际等级口径。
static func combat_level(item: Dictionary) -> float:
	var lv := effective_level(item)
	if lv <= 0.0 or not scale_active(item):
		return lv
	return lv * raw_max_level(item) / float(CAP_TOP)


## 迁移单件老存档 >99 级法宝：写回 888→99 折算等级（≤99 级、非西游档或关折算不动）；返回是否改写。
static func migrate_item(item: Dictionary, state: XState = null) -> bool:
	if not scale_active(item, state):
		return false
	var old_lv := level_of(item)
	if old_lv <= float(CAP_TOP):
		return false
	var new_lv := convert_old_level(old_lv, raw_max_level(item))
	item["level"] = float(new_lv)
	if item.has("exp") and (new_lv >= CAP_TOP or float(item["exp"]) >= next_level_exp(item)):
		item["exp"] = 0.0
	return true


## 读档迁移（XState.from_dict 末尾调用，T476）：西游档老存档 >99 级法宝按 888→99 等比例折算并写回存档，
## 覆盖背包、全员装备栏及 PH 仓库；在 s.flags 写入 OLD_LEVEL_MIGRATE_MARK，重复读档不再折。天启篇与关折算零改动。
static func after_load(s: XState) -> int:
	if s == null or not scale_active(null, s) or bool(s.flags.get(OLD_LEVEL_MIGRATE_MARK, false)):
		return 0
	var all := s.gear.duplicate()
	for a in s.actors.values():
		for e in a.equips:
			if e is Dictionary:
				all.append(e)
	for w in s.warehouses.values():
		for list in w.get("items", {}).values():
			for v in list:
				if v is Dictionary:
					all.append(v)
	var seen := []
	var changed := 0
	for item in all:
		if not (item is Dictionary) or seen.any(func(x): return is_same(x, item)):
			continue
		seen.append(item)
		if migrate_item(item, s):
			changed += 1
	if changed > 0:
		s.flags[OLD_LEVEL_MIGRATE_MARK] = true
		for a in s.actors.values():
			a.refresh_passive()
	return changed


## 给定原始每级成长 per 与法宝生效等级 lv，计算本项实际总成长属性：
## - 关折算／天启档／原上限 ≤ 99：与原版一致（lv * per）；
## - 开折算时 1..98 级取 roundf(lv * orig_max / 99.0 * per)，99 级精确等于 orig_max * per（888 * per），支持负成长（如紫电）。
static func scaled_growth(item: Dictionary, per: float, lv: float, state: XState = null) -> float:
	if lv <= 0.0 or per == 0.0:
		return 0.0
	if not scale_active(item, state):
		return lv * per
	var orig_max := raw_max_level(item)
	var top := float(CAP_TOP)
	if lv >= top:
		return orig_max * per
	return roundf(lv * orig_max / top * per)


## 不跟楼层的满级（数据上限，LEVEL_99 时封到 99）
static func top_level(item: Dictionary) -> float:
	var own := raw_max_level(item)
	if own < 0.0:
		return -1.0
	return minf(own, float(CAP_TOP)) if LEVEL_99 else own


## 当前存档的法宝等级上限；0＝不限（照数据）
static func level_cap(s: XState) -> int:
	if not LEVEL_99 or s == null or (not TIANQI_TOO and XTianqi.active(s)):
		return 0
	if not FLOOR_CAP:
		return CAP_TOP
	return mini(CAP_TOP, 9 + 3 * maxi(1, int(s.variable(20))))


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


## Game_Item.gainExp：满级不得；加完按下一级所需逐级升。
## 连升多级时角色只在最后重算一次（原版每级 user.refresh()）：重算不影响下一级所需，法宝成长是线性的、生命魔法夹值
## 取最后一次与逐级夹出来一样，结果相同；究极丹（100 万经验，上限 888 级）一颗连升几百级，逐级重算一颗要一秒以上。
static func gain_exp(item: Dictionary, amount: float, user: XActor = null) -> void:
	if not is_magic(item) or level_of(item) >= max_level(item):
		return
	var real := XPower.js_round(exp_of(item) + amount)
	item.exp = real
	var leveled := false
	while level_of(item) < max_level(item) and real >= next_level_exp(item):
		level_up(item, user, false)
		leveled = true
		real = exp_of(item)
	if leveled:
		_refresh_user(user)


## Game_Item.levelUp：所需按升级前的等级算；已满级时只把经验设成所需（MagicWeaponLevelUp 对满级法宝）。
## refresh 为假时不重算角色（连升时由调用方最后重算一次）
static func level_up(item: Dictionary, user: XActor = null, refresh := true) -> bool:
	if not is_magic(item):
		return false
	var cur := exp_of(item)
	var need := next_level_exp(item)
	if level_of(item) < max_level(item):
		item.level = level_of(item) + 1.0
		XActor.hold_touch()  # T576：按等级学的技能变了，技能 id 表的保留作废
		item.exp = maxf(0.0, cur - need)
		XTianqiAffixRoll.refresh_growth(item)  # 天启篇：通用法宝的光环随养成升阶
		_level_up_effect(item, user if refresh else null)
	else:
		item.exp = need
	return true


static func _refresh_user(user: XActor) -> void:
	if user != null:
		user.refresh_passive()
		user.refresh_resources()


## CP_X_MagicWeaponLearnSkill 先 user.refresh()（学技能缓存作废），再跑 <Magic Weapon LevelUp Effect>
static func _level_up_effect(item: Dictionary, user: XActor) -> void:
	_refresh_user(user)
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
			if not XFabaoFeed.NO_PILLS:  # 经验丹下架（O-401）：不再加经验
				party_gain_exp(s, _arg(args, 1))
			return true
		"MagicWeaponLevelUp":
			var aid := int(_arg(args, 1))
			var slot := int(_arg(args, 2))
			var times := int(_arg(args, 3))
			var a: XActor = s.actor(aid) if aid > 0 and not XDB.rec("Actors", aid).is_empty() else null
			if a != null and slot >= 0 and slot < a.equips.size():
				var leveled := false
				for i in range(times):
					if is_magic(a.equips[slot]):
						level_up(a.equips[slot], a, false)
						leveled = true
				if leveled:
					_refresh_user(a)  # 同 gain_exp：连升只在最后重算一次
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


## Game_Actor.traitObjects 追加：每件法宝的升级特性按战斗等级叠加，只计完整份数。
static func trait_objects(equips: Array) -> Array:
	var out := []
	for item in equips:
		if not is_magic(item):
			continue
		var o := level_up_trait_object(item)
		if o.is_empty():
			continue
		for i in range(int(combat_level(item))):
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


## Game_Item.magicWeaponSkills：这件法宝当前生效等级给的技能编号
static func item_skills(item) -> Array:
	if not is_magic(item):
		return []
	var lv := effective_level(item)
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
