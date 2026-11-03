class_name XGrowthForge
extends RefCounted
## 【cc·八戒·未经审查】成长装备期二：利维坦锻造（installNativeLeviathanForge，冻结 v0.28 modules.json 第 16 个）与杰作无我锻造
## （installNativeHubrisRuntime 第 17 个的 forge 段）。参照 growth_forge_probe（tests/fixtures/growth_forge_oracle.json），专项 xiyou_growth_forge。
## - 锻造锤 2867：Map176 胜利、来源地图 108／165（没记来源按变量 107：1→164、2／3→165，其余 0）、敌群 570～575，20%、每场一次；
##   掷在心钢 clearReward 之后、狂妄 clearReward 之前（同原版 endBattle 包装次序）。来源 164（魔王之渊）进去的永远不掉（原版如此，108 号地图不存在）。
## - 解锁：第一次拥有（背包或穿着）心钢／利维坦实例设 _codexLeviathanUnlocked、学配方 457，狂妄／无我设 _codexAtaraxiaUnlocked、学 458；
##   失去装备后仍解锁。标记存在 XState.crafting（codexLeviathanUnlocked／codexAtaraxiaUnlocked，随存档）。
##   原版在 gainItem、读档、建配方时检查；重制在 gain_gear 时检查，另在查配方是否学会、能否锻造时补查（旧档读进来就补上）。
## - 锻造（配方 457／458 的 craft 被改写）：战斗外、已解锁、选的是自己的原件实例、200 人道意志碎片＋5 锻造锤；
##   同一实例改成杰作：底子、属性加两件模板之差、名字、图标、说明、备注标签与元数据；层数、盛名、词条、强化全保留；扣材料；穿着的角色刷新。
##   配方的材料数按自己的原件实例（含穿着的），能做 1 件或 0 件，不看金币。
## - 原版锻造后由 describe 重写说明行；重制把原件模板的说明行（<pos=APs …>）换成杰作模板的同一行（层数相关的动态说明行在尾项 help_card 做）。
## 提示（$.toaster）：第一次得到时报解锁（读档、补查不报，同 unlockForge(false)），得到锻造锤报获得。

const FRAGMENT := 2530
const HAMMER := 2867
const FRAGMENT_COST := 200
const HAMMER_COST := 5
const CORE_MAP := 176
const CORE_ORIGINS := [108, 165]
const CORE_TROOPS := [570, 571, 572, 573, 574, 575]
const CORE_RATE := 0.20
const LEVIATHAN_RECIPE := 457
const ATARAXIA_RECIPE := 458
const KINDS := {
	LEVIATHAN_RECIPE: {"base": 7900, "master": 7901, "flag": "codexLeviathanUnlocked", "from": "心之钢", "to": "杰作利维坦",
		"tag": ["<CodexHeartsteel>", "<CodexLeviathan>"], "meta": ["CodexHeartsteel", "CodexLeviathan"], "label": "心钢层数"},
	ATARAXIA_RECIPE: {"base": 7902, "master": 7903, "flag": "codexAtaraxiaUnlocked", "from": "狂妄", "to": "杰作无我",
		"tag": ["<CodexHubris>", "<CodexAtaraxia>"], "meta": ["CodexHubris", "CodexAtaraxia"], "label": "盛名层数"},
}

static var _core_rolled := false
## H._forgeSource／U._forgeSource：界面选好的原件，配方 craft 时用
static var forge_source := {}


static func is_forge_recipe(id: int) -> bool:
	return KINDS.has(id)

static func _kind_of(item) -> int:
	var b := XHeartsteel.base_id(item)
	for id in KINDS:
		if b == int(KINDS[id].base) or b == int(KINDS[id].master):
			return id
	return 0

## H.ownedGear／U.ownedGear：背包里的加全队（含后备）穿着的，同一件只算一次
static func owned_gear(s: XState, id: int) -> Array:
	var out: Array = []
	var items: Array = s.gear.duplicate()
	for a in s.members():
		items.append_array(a.equip_list())
	for e in items:
		if e is Dictionary and _kind_of(e) == id and out.find_custom(func(x): return is_same(x, e)) < 0:
			out.append(e)
	return out

## H.forgeSources：自己的原件实例（心之钢／狂妄）
static func forge_sources(s: XState, id: int) -> Array:
	return owned_gear(s, id).filter(func(e): return XHeartsteel.base_id(e) == int(KINDS[id].base))


# ---- 解锁 ----
## H.unlockForge：拥有过就设标记并学配方；返回是不是这一次刚解锁
static func unlock(s: XState, id: int) -> bool:
	if s == null:
		return false
	var flag := str(KINDS[id].flag)
	var was := bool(s.crafting.get(flag, false))
	if not was and owned_gear(s, id).is_empty():
		return false
	s.crafting[flag] = true
	XCrafting.learn(s, id)
	return not was

## 还没解锁时补查一次（旧档读进来、或从仓库等不经 gain_gear 的路子拿到装备）；已解锁不再重学配方
static func unlocked(s: XState, id: int) -> bool:
	if s == null:
		return false
	if not bool(s.crafting.get(str(KINDS[id].flag), false)):
		unlock(s, id)
	return bool(s.crafting.get(str(KINDS[id].flag), false))

## Game_Party.gainItem 包装：得到心钢／狂妄一族的实例时检查解锁
static func on_gain(s: XState, kind: String, base_id: int) -> void:
	var id := _kind_of({"base": base_id}) if kind == "armor" else 0
	if id != 0 and unlock(s, id):
		XToast.show_text("已解锁打造配方：" + str(KINDS[id].to))


# ---- 锻造锤 ----
## H.unknownCoreOrigin：记了来源用它；没记按变量 107（1→164，2／3→165，其余 0）
static func unknown_core_origin(s: XState) -> int:
	if s.unknown_origin != null:
		return int(s.unknown_origin)
	var d := int(s.variables.get(107, 0))
	return 164 if d == 1 else (165 if d == 2 or d == 3 else 0)

## BattleManager.setup 包装：每场一次
static func start_battle() -> void:
	_core_rolled = false

## H.awardCore（endBattle 包装，心钢掉落之后）：Map176 胜利、来源 108／165、敌群 570～575，20% 得锻造锤
static func award_core(logic, result: int) -> bool:
	var s: XState = logic.state
	if result != 0 or s == null or s.map_id != CORE_MAP or not unknown_core_origin(s) in CORE_ORIGINS or not int(logic.troop_id) in CORE_TROOPS or _core_rolled:
		return false
	_core_rolled = true
	if logic._rule().next_float("growth_forge.core") >= CORE_RATE:
		return false
	s.gain_item(HAMMER, 1)
	XToast.show_text("获得锻造材料：锻造锤！")
	return true


# ---- 锻造 ----
## H.canForge：战斗外、已解锁、是自己的原件实例、材料够
static func can_forge(s: XState, id: int, source) -> bool:
	if s == null or XHeartsteel.in_battle or not unlocked(s, id) or not (source is Dictionary) or XHeartsteel.base_id(source) != int(KINDS[id].base):
		return false
	return forge_sources(s, id).any(func(e): return is_same(e, source)) and s.item_count(FRAGMENT) >= FRAGMENT_COST and s.item_count(HAMMER) >= HAMMER_COST

static func _replace_first(text: String, what: String, with: String) -> String:
	var i := text.find(what)
	return text if what == "" or i < 0 else text.substr(0, i) + with + text.substr(i + what.length())

static func _pos_rows(note: String) -> Array:
	return Array(note.split("\n")).filter(func(l): return str(l).begins_with("<pos="))

## H.previewForge：原件的深拷贝改成杰作（不动原件）
static func preview(id: int, source) -> Dictionary:
	if not (source is Dictionary) or XHeartsteel.base_id(source) != int(KINDS[id].base):
		return {}
	var k: Dictionary = KINDS[id]
	var view: Dictionary = source.duplicate(true)
	var base := XDB.rec("Armors", int(k.base))
	var master := XDB.rec("Armors", int(k.master))
	view.base = float(k.master)
	for i in range(8):
		view.params[i] = float(view.params[i]) + float(master.params[i]) - float(base.params[i])
	view.name = _replace_first(str(view.name), str(k.from), str(k.to))
	if str(view.get("baseName", "")) != "":
		view.baseName = _replace_first(str(view.baseName), str(k.from), str(k.to))
	view.iconIndex = int(master.iconIndex)
	view.description = _replace_first(str(view.description), str(base.description), str(master.description))
	var note := _replace_first(str(view.note), str(k.tag[0]), str(k.tag[1]))
	var from_rows := _pos_rows(str(base.note))
	var to_rows := _pos_rows(str(master.note))
	for i in range(mini(from_rows.size(), to_rows.size())):
		if from_rows[i] != to_rows[i]:
			note = _replace_first(note, from_rows[i], to_rows[i])
	view.note = note
	var meta: Dictionary = (view.get("meta", {}) as Dictionary).duplicate(true)
	meta.erase(k.meta[0])
	meta[k.meta[1]] = true
	view.meta = meta
	return view

## H.forge：同一实例原地改成杰作，扣材料；扣不对就整件还原、材料补回（原版事务）。返回这件，不能锻造为空
static func forge(s: XState, id: int, source) -> Dictionary:
	if not can_forge(s, id, source):
		return {}
	var view := preview(id, source)
	var snapshot: Dictionary = source.duplicate(true)
	var f := s.item_count(FRAGMENT)
	var n := s.item_count(HAMMER)
	source.clear()
	source.merge(view)
	s.gain_item(FRAGMENT, -FRAGMENT_COST)
	s.gain_item(HAMMER, -HAMMER_COST)
	if s.item_count(FRAGMENT) != f - FRAGMENT_COST or s.item_count(HAMMER) != n - HAMMER_COST:
		source.clear()
		source.merge(snapshot)
		s.gain_item(FRAGMENT, f - s.item_count(FRAGMENT))
		s.gain_item(HAMMER, n - s.item_count(HAMMER))
		return {}
	for a in s.members():
		if a.equip_list().any(func(e): return is_same(e, source)):
			a.refresh_passive()
			a.param_mark_dirty()
			a.hp = minf(a.hp, a.mhp)
	return source


# ---- 配方（$gameRecipes[457／458] 的改写） ----
## getMaterialCount：原件那一项按自己的原件实例数（含穿着的）
static func material_count(s: XState, id: int, m: Dictionary) -> int:
	if str(m.get("type", "")) == "armor" and int(m.get("id", 0)) == int(KINDS[id].base):
		return forge_sources(s, id).size()
	return -1

## craftable：战斗外、学会、材料、等级（不看金币）
static func craftable(s: XState, r: Dictionary) -> bool:
	return not XHeartsteel.in_battle and XCrafting.known(s, r) and XCrafting.has_materials(s, r) and XCrafting.has_level(s, r)


# ---- 界面文字 ----
## H.helpNumber：保留 6 位小数，去掉多余的 0
static func help_number(n: float) -> String:
	var v := roundf(n * 1000000.0) / 1000000.0
	return str(int(v)) if v == floorf(v) else str(v)

## H.damageText
static func damage_text(item) -> String:
	var lev := XHeartsteel.is_leviathan(item)
	return "伤害：[%d＋常态最大生命×%s]×%s" % [1000 if lev else 700, "8%" if lev else "6%", help_number(1.0 + 0.1 * XHeartsteel.stage(item))]

## forgeDetailLines：锻造详情窗第 224 行起
static func detail_lines(id: int, source) -> Array:
	if id == LEVIATHAN_RECIPE:
		if not (source is Dictionary) or source.is_empty():
			return ["选择一件心之钢，含已装备的实例", "品质、词条与心钢层数完整继承"]
		return ["品质、词条、心钢与强化进度完整保留", "基础生命额外＋10000，双防各＋300", "回合结束回复5%最大生命", damage_text(preview(id, source)),
			"最大生命×" + help_number(1.1 + 0.1 * XHeartsteel.stage(source))]
	if not (source is Dictionary) or source.is_empty():
		return ["选择一件狂妄，含已装备的实例", "品质、词条与盛名层数完整继承"]
	return ["品质、词条、盛名与强化进度完整保留", "基础物理攻击额外＋500", "物理防御穿透由18%提高至27%",
		"扬名时物理攻击×" + help_number(1.2 + 0.1 * XHeartsteel.stage_of(XHubris.growth(source))), "扬名持续4个完整回合"]

## forgeHelpText：帮助窗两行
static func help_text(id: int, source, picking: bool, shown: bool) -> String:
	var k: Dictionary = KINDS[id]
	if not (source is Dictionary) or source.is_empty():
		return "%s：选择一件%s升级；消耗200人道意志碎片与5锻造锤" % [k.to, k.from]
	return "选择: " + str(source.name) + "\n品质、词条、" + str(k.label) + "及强化进度保留" + (("；按 Shift 返回升级预览" if shown else "；按 Shift 查看词条") if picking else "")

static func growth_of(id: int, item) -> int:
	return XHeartsteel.stacks(item) if id == LEVIATHAN_RECIPE else XHubris.growth(item)

## 选原件列表第二行：品质 · 层数 · 已装备／背包
static func source_row(s: XState, id: int, item: Dictionary) -> String:
	var worn := s.members().any(func(a): return a.equip_list().any(func(e): return is_same(e, item)))
	return "%s · %s:%d%s" % [XGear.quality_name(item), KINDS[id].label, growth_of(id, item), " · 已装备" if worn else " · 背包"]
