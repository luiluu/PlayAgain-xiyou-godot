class_name XAffixAbsorb
extends RefCounted
## 【cc·未经审查】专武·特效吸取（正式西游 v0.30 起 installAbyssMerchantRuntime 的 M.absorbCapacity／absorptions／absorbView／
## extraAffixes／absorb，v0.36 起多槽；技能 10455 在技能页用 → CodexAbyssMerchant.openAbsorb → Scene_Merchant29 的 absorb 模式）。
## - 开放专武＝武器备注 <req_actors: …> 里有可用角色的（XActor.absorb_owners）；槽位按所属角色里最高等级开放：1 级一条、35 级两条、60 级三条。
## - 吸取记在专武实例的 _codexAbsorbed29（数组，每格 {db, id} 或 null；旧单条描述照认），随存档保存。
## - 效果视图（absorbView）：开放槽位里的特效按 DreamX 前缀合并（XGear.combine）进专武的复制品；角色 equip_list 返回视图
##   （原版 Game_Actor.equips 包装），算能力值、特性、备注都用它；改装备本身（镶嵌、升级、登记、锁定、熔炼）的地方用 XActor.raw_equip_list／real。
## - 额外特效（extraAffixes）：商人抽出的装备只认抽到的那条（_codexExtraAffix29）；其它装备认备注里含有某条商人特效的全部
##   「Mod特效／神话特效」行的那些特效（按 params、traits、note 去重）。
## - 吸取：材料须在背包、没装备、名字不带 [锁定]；扣掉材料，选定槽位写入（替换只影响该槽）。出错照原版文字，失败不扣材料。
## 与原版的差别：原版视图合并后再跑一遍 processYanflyTags（备注重新解析）；重制的词缀合并已经合并解析好的 meta／yep，不再重解析。

const KEY := "_codexAbsorbed29"
const VIEW_FLAG := "_codexAbsorbView29"
const EXTRA_KEY := "_codexExtraAffix29"

## 吸取后加一（让视图缓存全部重建）
static var revision := 0
## instanceId → {src, view, 以及判断是否过期用的字段}
static var _views := {}
static var _affix_lines_src = null
static var _affix_lines := []   # [{d, lines, sig}]


## M.real：视图换回专武本体；不是视图原样返回
static func real(e):
	if e is Dictionary and e.has(VIEW_FLAG):
		var c = _views.get(str(e.get("instanceId", "")))
		if c != null:
			return c.src
	return e


## M.absorbOwners：只认武器
static func owners(e: Dictionary) -> Array:
	e = real(e)
	if str(e.get("kind", "")) != "weapon":
		return []
	return XActor.absorb_owners(int(e.get("base", e.get("id", 0))))


static func can_absorb(e: Dictionary) -> bool:
	return not owners(e).is_empty()


## M.absorbCapacity：所属角色（已建档的）里最高等级 ≥60 三条、≥35 两条，否则一条
static func capacity(e: Dictionary, s: XState = null) -> int:
	if s == null:
		s = XState.current
	var lv := 1
	if s != null:
		for id in owners(e):
			var a = s.actors.get(int(id))
			if a != null:
				lv = maxi(lv, int(a.level))
	return 3 if lv >= 60 else (2 if lv >= 35 else 1)


## M.absorptions：每格描述或 null；旧单条（字典）当一格
static func absorptions(e: Dictionary) -> Array:
	e = real(e)
	var d = e.get(KEY)
	if d is Array:
		return d
	if d is Dictionary:
		return [d]
	return []


static func record(d) -> Dictionary:
	if not (d is Dictionary) or not d.has("db") or not d.has("id"):
		return {}
	return XDB.rec(str(d.db), int(d.id))


## M.absorbView：有吸取就返回合并了开放槽位特效的复制品（缓存，按本体的会变字段判断过期）；没有或解析不了返回本体
static func view(e: Dictionary, s: XState = null) -> Dictionary:
	if not e.has(KEY) or e.has(VIEW_FLAG):
		return e
	var id := str(e.get("instanceId", ""))
	var cap := capacity(e, s)
	var c = _views.get(id) if id != "" else null
	if c != null and _fresh(c, e, cap):
		return c.view
	var active := []
	for d in absorptions(e).slice(0, cap):
		if d != null:
			active.append(d)
	if active.is_empty() or active.any(func(d): return record(d).is_empty()):
		return e
	var v: Dictionary = e.duplicate(true)
	v.erase(KEY)
	for d in active:
		XGear.combine(v, record(d), "prefix")
	v[VIEW_FLAG] = true
	if id != "":
		if _views.size() > 64:
			_views.clear()
		var p: Array = e.get("params", [])
		_views[id] = {"src": e, "view": v, "cap": cap, "rev": revision, "abs": e.get(KEY), "note": str(e.get("note", "")),
			"name": str(e.get("name", "")), "traits": e.get("traits"), "tn": (e.get("traits", []) as Array).size(), "pref": p,
			"params": p.duplicate(), "upgrades": e.get("upgrades"), "un": (e.get("upgrades", []) as Array).size(),
			"yep": e.get("yep"), "orb": e.get("_codexOrb"), "level": e.get("level"), "meta": e.get("meta")}
	return v


static func _fresh(c: Dictionary, e: Dictionary, cap: int) -> bool:
	if c.cap != cap or c.rev != revision or not is_same(c.abs, e.get(KEY)) or not is_same(c.src, e):
		return false
	if not is_same(c.traits, e.get("traits")) or c.tn != (e.traits as Array).size():
		return false
	if not is_same(c.upgrades, e.get("upgrades")) or c.un != (e.get("upgrades", []) as Array).size():
		return false
	if not is_same(c.yep, e.get("yep")) or not is_same(c.orb, e.get("_codexOrb")) or not is_same(c.meta, e.get("meta")):
		return false
	if c.level != e.get("level") or c.name != str(e.get("name", "")) or c.note != str(e.get("note", "")):
		return false
	var p: Array = e.get("params", [])
	if not is_same(c.pref, p) or p.size() != (c.params as Array).size():
		return false
	for k in p.size():
		if p[k] != c.params[k]:
			return false
	return true


## affixLabel：特效物品备注 text=… size= 那段去掉 \c[n]；没有写「额外特效」
static func label(d) -> String:
	var t := record(d)
	var m := RegEx.create_from_string("text=(.*?) size=").search(str(t.get("note", "")))
	if m == null:
		return "额外特效"
	return RegEx.create_from_string("\\\\c\\[\\d+\\]").sub(m.get_string(1), "", true)


static func _lines() -> Array:
	var cfg = XDB.table("CodexMerchants")
	if is_same(cfg, _affix_lines_src):
		return _affix_lines
	_affix_lines_src = cfg
	_affix_lines = []
	var re := RegEx.create_from_string("(?i)(?:mod|神话)特效\\s*[:：]")
	var affixes: Dictionary = cfg.get("affixes", {}) if cfg is Dictionary else {}
	for cat in affixes:
		for d in affixes[cat]:
			var t := record(d)
			var lines := []
			for line in str(t.get("note", "")).split("\n"):
				line = line.trim_suffix("\r")
				if re.search(line) != null:
					lines.append(line)
			if not lines.is_empty():
				_affix_lines.append({"d": {"db": str(d.db), "id": int(d.id)}, "lines": lines,
					"sig": JSON.stringify([t.get("params"), t.get("traits"), t.get("note")])})
	return _affix_lines


## M.extraAffixes：材料能给出的额外特效描述
static func extra_affixes(material: Dictionary) -> Array:
	material = real(material)
	if material.is_empty():
		return []
	var x = material.get(EXTRA_KEY)
	if x is Dictionary:
		return [{"db": str(x.db), "id": int(x.id)}]
	var note := str(material.get("note", ""))
	var out := []
	var seen := {}
	for a in _lines():
		if seen.has(a.sig):
			continue
		if (a.lines as Array).all(func(line): return note.contains(line)):
			seen[a.sig] = true
			out.append((a.d as Dictionary).duplicate())
	return out


static func locked(e: Dictionary) -> bool:
	return str(e.get("name", "")).contains("[锁定]")


static func _in_bag(s: XState, e: Dictionary) -> bool:
	return s.gear.any(func(x): return is_same(x, e))


static func _worn(s: XState, e: Dictionary) -> bool:
	return s.members().any(func(a): return a.raw_equip_list().any(func(x): return is_same(x, e)))


## absorbHome29 的目标：背包武器＋队员身上装备里的开放专武（去重）
static func targets(s: XState) -> Array:
	var all: Array = s.gear.filter(func(e): return str(e.get("kind", "")) == "weapon")
	for a in s.members():
		all.append_array(a.raw_equip_list())
	var out := []
	for e in all:
		if can_absorb(e) and not out.any(func(x): return is_same(x, e)):
			out.append(e)
	return out


## materials29：背包武器、防具里不是目标、没锁定、有额外特效的
static func materials(s: XState, target: Dictionary) -> Array:
	target = real(target)
	var list: Array = s.gear.filter(func(e): return str(e.get("kind", "")) == "weapon") + s.gear.filter(func(e): return str(e.get("kind", "")) == "armor")
	return list.filter(func(e): return not is_same(e, target) and not locked(e) and not extra_affixes(e).is_empty())


## M.absorb：成功返回 ""，否则返回原版的错误文字（不扣材料、不改专武）
static func absorb(s: XState, target: Dictionary, material: Dictionary, d: Dictionary, slot := 0) -> String:
	target = real(target)
	material = real(material)
	if target.is_empty() or str(target.get("kind", "")) != "weapon" or not can_absorb(target) or not (_in_bag(s, target) or _worn(s, target)):
		return "请先持有当前开放的专武。"
	if material.is_empty() or is_same(material, target) or not _in_bag(s, material) or locked(material):
		return "请选择背包中未锁定、未装备的材料。"
	if _worn(s, material):
		return "材料正在装备中，请先卸下。"
	if not extra_affixes(material).any(func(x): return str(x.db) == str(d.get("db", "")) and int(x.id) == int(d.get("id", 0))):
		return "材料不包含所选额外特效。"
	var cap := capacity(target, s)
	if slot < 0 or slot >= cap:
		return "所选吸取槽位尚未开放。"
	var had := target.has(KEY)
	var old = target.get(KEY)
	var next := absorptions(target).duplicate(true)
	while next.size() < slot:
		next.append(null)
	if next.size() == slot:
		next.append(null)
	next[slot] = {"db": str(d.db), "id": int(d.id)}
	target[KEY] = next
	revision += 1
	var err := ""
	if is_same(view(target, s), target):
		err = "特效解析失败。"
	elif not s.lose_gear(material) or _in_bag(s, material):
		err = "材料消耗失败。"
	if err != "":
		if had:
			target[KEY] = old
		else:
			target.erase(KEY)
		revision += 1
		return err
	for a in s.members():
		a.refresh_passive()  # CodexV029.refresh
	return ""
