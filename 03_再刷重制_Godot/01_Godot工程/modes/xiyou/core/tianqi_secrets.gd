class_name XTianqiSecrets
extends RefCounted
## 【小A·天启篇·未经审查】秘籍格核心系统（T446 / T013-1b；设计依据：天启篇_原版养成线重做方案_v0.3 第三节第 8 条、D274）。
##
## 规则：
## - 格数上限读 balance_table.json tiers.<档位>.secret_cap（弱者 6、强者 4、超强者 3）。
## - 占格：功法（stype=6）、通用被动书（code 43 ＋ CE code 44，stype=4）、元素转换书（老 5068~5075 ＋ 新 11201~11205）、
##   深渊六式被动（6192~6203 / 6206~6211）与止戈/天怒（6185 / 6204）。
## - 不占格：号卷（XTianqiTrumpet / <CodexPower>）、抽奖被动（stype=5）、主动书（stype 1/2/3 等）、
##   角色自带/职业/进阶被动、27 本 Boss 血脉（D274④）、58 张外观变身卡（6801~6858）、种族技能、万灵增元丹被动。
## - 元素转换书：首次学占 1 格；当前生效格里已有另一门转换书时原地替换，不要求先空出新格。
## - 花场钱封印：腾出 1 格、不退书、被动立即失效（_skill_records 滤掉已封，不删 skill_ids）；封印记录在 flags.tianqi.secrets。
## - 老存档迁移：读档后若某角色生效占格秘籍超出上限，不没收，超出部分自动移入已封并授予该角色一次免费自选生效格（free_pick）。
## - 回退开关：ENABLED = false 完整回退到旧临时截断；西游档（XTianqi.active == false）零变化、零存档字段。
##
## 玩家可见文字（待小A/cc Sonnet 审）全部集中在本模块 ui_* / learn_reason / seal / unseal 中，
## 发行空壳替换本脚本后西游发行包零外泄。

static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/secret_books.json"
const SECTION := "secrets"

static var _data: Dictionary = {}
static var _load_failed := false
static var _index_ready := false
static var _include_set := {}
static var _exempt_set := {}
static var _conversion_set := {}
static var _conversion_items := {}
static var _ignore_items := {}
static var _slot_stypes := [4, 6]
static var _book_skills := {}
static var _ce_item_skills := {}  # item_id -> Array[int]（该 CE 物品会教的占格技能列表）


# ---- 数据加载与开关 ----

static func data() -> Dictionary:
	if _data.is_empty() and not _load_failed:
		if XDataFile.missing(PATH):
			return {}
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text()) if f != null else null
		if not parsed is Dictionary:
			_load_failed = true
			push_error("XTianqiSecrets: 读不到或解析失败 " + PATH)
			return {}
		_data = parsed
	return _data


static func reload_table() -> void:
	_data = {}
	_load_failed = false
	_index_ready = false
	_include_set = {}
	_exempt_set = {}
	_conversion_set = {}
	_conversion_items = {}
	_ignore_items = {}
	_slot_stypes = [4, 6]
	_book_skills = {}
	_ce_item_skills = {}


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release()) and not data().is_empty()


static func _ensure_index() -> void:
	if _index_ready:
		return
	var d := data()
	if d.is_empty():
		return
	_index_ready = true
	var rules: Dictionary = d.get("rules", {})
	var st_raw = rules.get("slot_stypes", [4, 6])
	_slot_stypes = []
	if st_raw is Array:
		for x in st_raw:
			_slot_stypes.append(int(x))
	if _slot_stypes.is_empty():
		_slot_stypes = [4, 6]
	# 豁免名单
	var ex: Dictionary = d.get("seal_exempt", {})
	for k in ["bloodlines", "not_book"]:
		for sid in ex.get(k, []):
			_exempt_set[int(sid)] = true
	var cr: Array = ex.get("costume_range", [])
	if cr.size() >= 2:
		for sid in range(int(cr[0]), int(cr[1]) + 1):
			_exempt_set[sid] = true
	# 显式占格与转换书名单
	var inc: Dictionary = d.get("include_skills", {})
	for k in ["abyss_six_passives", "sect_passives", "conversion_skills"]:
		for sid in inc.get(k, []):
			_include_set[int(sid)] = true
	for sid in inc.get("conversion_skills", []):
		_conversion_set[int(sid)] = true
	for sid in XTianqiElements.CONVERSION_SKILLS:
		_conversion_set[int(sid)] = true
		_include_set[int(sid)] = true
	var ci: Dictionary = d.get("conversion_items", {})
	for k in ci:
		if str(k).is_valid_int():
			_conversion_items[int(k)] = int(ci[k])
	for iid in d.get("ignore_items", []):
		_ignore_items[int(iid)] = true
	# 扫描物品表（code 43 ＋ CE code 44）建立书教技能索引
	_scan_items()


static func _scan_items() -> void:
	var re_power := RegEx.create_from_string("<CodexPower:\\s*\\d+>")
	var re_learn := RegEx.create_from_string("learnSkill\\((\\d+)\\)")
	var re_var := RegEx.create_from_string("var\\s+\\w+\\s*=\\s*(\\d+)\\s*;")
	var ces = XDB.table("CommonEvents")
	for it in XDB.table("Items"):
		if not it is Dictionary:
			continue
		var iid := int(it.get("id", 0))
		if iid <= 0 or _ignore_items.has(iid) or _conversion_items.has(iid):
			continue
		if re_power.search(str(it.get("note", ""))) != null:
			continue
		var ce_sids := {}
		for e in it.get("effects", []):
			var code := int(e.get("code", 0))
			var did := int(e.get("dataId", 0))
			if code == 43 and did > 0:
				_book_skills[did] = true
			elif code == 44 and did > 0 and ces is Array and did < ces.size() and ces[did] is Dictionary:
				for sid in _scan_ce(ces[did], re_learn, re_var):
					_book_skills[sid] = true
					ce_sids[sid] = true
		if not ce_sids.is_empty():
			var arr: Array[int] = []
			for sid in ce_sids:
				arr.append(int(sid))
			arr.sort()
			_ce_item_skills[iid] = arr


static func _scan_ce(ce: Dictionary, re_learn: RegEx, re_var: RegEx) -> Array[int]:
	var recruits := {}
	var has_learn := false
	for c in ce.get("list", []):
		var code := int(c.get("code", 0))
		var p: Array = c.get("parameters", [])
		if code == 129 and p.size() > 1 and int(p[1]) == 0:
			recruits[int(p[0])] = true
		elif code == 318 and p.size() > 3 and int(p[2]) == 0:
			has_learn = true
		elif code in [355, 655] and not p.is_empty():
			if str(p[0]).contains("learnSkill("):
				has_learn = true
	if not has_learn:
		return []  # 只有 forgetSkill（如转换药剂）或纯辅助事件不收
	var found := {}
	for c in ce.get("list", []):
		var code := int(c.get("code", 0))
		var p: Array = c.get("parameters", [])
		if code == 318 and p.size() > 3 and int(p[2]) == 0:
			if int(p[0]) == 0 and recruits.has(int(p[1])):
				continue
			found[int(p[3])] = true
		elif code in [355, 655] and not p.is_empty():
			var line := str(p[0])
			for m in re_learn.search_all(line):
				found[int(m.get_string(1))] = true
			for m in re_var.search_all(line):
				var sid := int(m.get_string(1))
				if int(XDB.rec("Skills", sid).get("stypeId", 0)) == 4:
					found[sid] = true
	var out: Array[int] = []
	for sid in found:
		out.append(int(sid))
	return out


# ---- 占格与格数判定 ----

static func is_conversion_skill(id: int) -> bool:
	if id <= 0:
		return false
	_ensure_index()
	return _conversion_set.has(id)


static func is_exempt(id: int) -> bool:
	if id <= 0:
		return true
	_ensure_index()
	if _exempt_set.has(id):
		return true
	if XTianqiLedger.PILL_PASSIVES.has(id) or XTianqiTrumpet.of_skill(id) != 0 or XPowerBooks.is_power(id):
		return true
	if not XRace.skill_info(id).is_empty():
		return true
	return false


## 该技能是否占秘籍格（功法、通用被动书 code 43/44、元素转换书、深渊六式被动与止戈/天怒）
static func occupies_slot(id: int) -> bool:
	if id <= 0:
		return false
	_ensure_index()
	if is_exempt(id):
		return false
	if _include_set.has(id):
		return true
	var sk := XDB.rec("Skills", id)
	if sk.is_empty():
		return false
	var stype := int(sk.get("stypeId", 0))
	if not _slot_stypes.has(stype):
		return false
	return _book_skills.has(id)


## 角色秘籍格上限（读 balance_table.json：弱 6 / 强 4 / 超 3）
static func limit(a) -> int:
	if not (a is XActor):
		return 0
	return XTianqiBalance.secret_cap(XTier.tier_of(a))


# ---- 存档分区（flags.tianqi.secrets）----

static func fill(d: Dictionary) -> void:
	if not (d.get("actors") is Dictionary):
		d["actors"] = {}
	var actors: Dictionary = d["actors"]
	for k in actors.keys():
		var row = actors[k]
		if not (row is Dictionary):
			actors[k] = {"sealed": [], "free_pick": false}
			continue
		var raw = row.get("sealed", [])
		var clean: Array[int] = []
		if raw is Array:
			for sid in raw:
				var id := int(sid)
				if id > 0 and not clean.has(id):
					clean.append(id)
		clean.sort()
		row["sealed"] = clean
		row["free_pick"] = bool(row.get("free_pick", false))


static func _peek_actor(s: XState, actor_id: int) -> Dictionary:
	if s == null or not on(s):
		return {}
	var sec = XTianqiSave.peek(s, SECTION)
	if not (sec is Dictionary):
		return {}
	var actors = sec.get("actors")
	if not (actors is Dictionary):
		return {}
	var row = actors.get(str(actor_id))
	return row if row is Dictionary else {}


static func _write_actor(s: XState, actor_id: int) -> Dictionary:
	var sec: Dictionary = XTianqiSave.section(s, SECTION)
	var actors: Dictionary = sec["actors"]
	var key := str(actor_id)
	if not (actors.get(key) is Dictionary):
		actors[key] = {"sealed": [], "free_pick": false}
	return actors[key]


## 该角色当前已封秘籍 ID（仅保留仍在 skill_ids 且占格的技能）
static func sealed_ids(a, s: XState = null) -> Array[int]:
	if not on(s) or not (a is XActor):
		return []
	if s == null:
		s = XState.current
	var row := _peek_actor(s, a.actor_id)
	var raw = row.get("sealed", [])
	var out: Array[int] = []
	if raw is Array:
		for sid in raw:
			var id := int(sid)
			if id > 0 and a.skill_ids.has(id) and occupies_slot(id) and not out.has(id):
				out.append(id)
	out.sort()
	return out


static func is_sealed(a, skill_id: int, s: XState = null) -> bool:
	if not on(s) or not (a is XActor) or skill_id <= 0:
		return false
	if s == null:
		s = XState.current
	var row := _peek_actor(s, a.actor_id)
	var raw = row.get("sealed", [])
	if not (raw is Array):
		return false
	for sid in raw:
		if int(sid) == skill_id:
			return occupies_slot(skill_id)
	return false


## 该角色当前占着生效格的秘籍 ID（升序）
static func active_ids(a, s: XState = null) -> Array[int]:
	if not on(s) or not (a is XActor):
		return []
	if s == null:
		s = XState.current
	var sealed := sealed_ids(a, s)
	var out: Array[int] = []
	for sid in a.skill_ids:
		var id := int(sid)
		if occupies_slot(id) and not sealed.has(id) and not out.has(id):
			out.append(id)
	out.sort()
	return out


static func used_slots(a, s: XState = null) -> int:
	if not on(s):
		return 0
	return active_ids(a, s).size()


static func has_free_pick(a, s: XState = null) -> bool:
	if not on(s) or not (a is XActor):
		return false
	if s == null:
		s = XState.current
	var row := _peek_actor(s, a.actor_id)
	return bool(row.get("free_pick", false)) and not sealed_ids(a, s).is_empty()


## 当前生效格里已装备的元素转换书技能 ID（没有为 0）
static func active_conversion_id(a, s: XState = null) -> int:
	for sid in active_ids(a, s):
		if is_conversion_skill(sid):
			return sid
	return 0


# ---- 学书拦截与物品检测 ----

static func learn_reason(a, skill_id: int, s: XState = null) -> String:
	if not on(s) or not (a is XActor) or not occupies_slot(skill_id):
		return ""
	if s == null:
		s = XState.current
	if a.skill_ids.has(skill_id):
		if is_sealed(a, skill_id, s):
			return "已学会此秘籍（已封印），请在技能页启封"
		return "已经学会这本秘籍"
	# 元素转换书：当前生效格已有另一门转换书 → 原地替换，不占新格
	if is_conversion_skill(skill_id) and active_conversion_id(a, s) > 0:
		return ""
	var cap := limit(a)
	var used := used_slots(a, s)
	if cap > 0 and used >= cap:
		return "%s最多装备 %d 本秘籍（当前 %d/%d），请先在技能页封印已有秘籍" % [XTier.tier_of(a), cap, used, cap]
	return ""


static func can_learn(a, skill_id: int, s: XState = null) -> bool:
	if not on(s):
		return true
	return learn_reason(a, skill_id, s).is_empty()


## 供 XActor.learn_skill 调用：关着或西游档恒返回 false（不拦）
static func blocks_learn(a, skill_id: int, s: XState = null) -> bool:
	if not on(s):
		return false
	return not learn_reason(a, skill_id, s).is_empty()


## 使用物品前校验（覆盖 code 43、元素转换书、CE code 44 被动书）
static func item_learn_reason(a, item: Dictionary, s: XState = null) -> String:
	if not on(s) or not (a is XActor) or item.is_empty():
		return ""
	if s == null:
		s = XState.current
	_ensure_index()
	var iid := int(item.get("id", 0))
	if _ignore_items.has(iid) or XPowerBooks.book_skill(item) > 0:
		return ""
	# 1) 元素转换书物品（老版 1035~1042、新版 3101~3105）
	if _conversion_items.has(iid):
		return learn_reason(a, int(_conversion_items[iid]), s)
	# 2) 直接学会技能（code 43）
	for e in item.get("effects", []):
		if int(e.get("code", 0)) == 43:
			var sid := int(e.get("dataId", 0))
			if occupies_slot(sid):
				return learn_reason(a, sid, s)
	# 3) 公共事件教技能（code 44）
	if _ce_item_skills.has(iid):
		var raw: Array = _ce_item_skills[iid]
		var slot_sids: Array[int] = []
		for sid in raw:
			if occupies_slot(int(sid)):
				slot_sids.append(int(sid))
		if slot_sids.is_empty():
			return ""
		if slot_sids.size() == 1:
			return learn_reason(a, slot_sids[0], s)
		# 多选一/升星类 CE（如心法正逆邪、精通 1~5★、小药丸）：
		# 若当前生效格已有同组中任意一本，则为原地替换/升星，净增 0 格，放行
		var act := active_ids(a, s)
		for sid in slot_sids:
			if act.has(sid):
				return ""
		var cap := limit(a)
		var used := act.size()
		if cap > 0 and used >= cap:
			return "%s最多装备 %d 本秘籍（当前 %d/%d），请先在技能页封印已有秘籍" % [XTier.tier_of(a), cap, used, cap]
	return ""


## 供 item_scene._effective 调用：-1 不归秘籍格管、1 有效、0 无效（满格或已学）
static func item_effective(a, item: Dictionary, s: XState = null) -> int:
	if not on(s) or not (a is XActor) or item.is_empty():
		return -1
	_ensure_index()
	var iid := int(item.get("id", 0))
	if _ignore_items.has(iid) or XPowerBooks.book_skill(item) > 0:
		return -1
	var managed := _conversion_items.has(iid)
	if not managed:
		for e in item.get("effects", []):
			if int(e.get("code", 0)) == 43 and occupies_slot(int(e.get("dataId", 0))):
				managed = true
				break
	if not managed and _ce_item_skills.has(iid):
		for sid in _ce_item_skills[iid]:
			if occupies_slot(int(sid)):
				managed = true
				break
	if not managed:
		return -1
	return 1 if item_learn_reason(a, item, s).is_empty() else 0


# ---- 封印、启封与免费自选 ----

static func seal_cost(s: XState, a = null) -> int:
	if not on(s):
		return 0
	if s == null:
		s = XState.current
	if a is XActor and has_free_pick(a, s):
		return 0
	var rules: Dictionary = data().get("rules", {})
	var units := float(rules.get("seal_field_units", 5))
	if XTianqiMoney.on(s):
		return XTianqiMoney.price(s, units)
	return int(rules.get("seal_fallback_gold", 1000))


static func seal(s: XState, a: XActor, skill_id: int) -> Dictionary:
	if not on(s):
		return {"ok": false, "reason": "秘籍格系统未开启"}
	if s == null:
		s = XState.current
	if a == null or not a.skill_ids.has(skill_id) or not occupies_slot(skill_id):
		return {"ok": false, "reason": "该技能不属于可封印的秘籍"}
	if is_sealed(a, skill_id, s):
		return {"ok": false, "reason": "该秘籍已经处于封印状态"}
	var cost := seal_cost(s, a)
	if cost > 0 and s.gold < cost:
		return {"ok": false, "reason": "精魂不足（封印需要 %s 精魂）" % XMenu._group(cost), "cost": cost}
	if cost > 0:
		s.gold -= cost
	var row := _write_actor(s, a.actor_id)
	var arr: Array = row["sealed"]
	if not arr.has(skill_id):
		arr.append(skill_id)
		arr.sort()
	_refresh_actor(a)
	return {"ok": true, "cost": cost, "free": cost == 0}


static func unseal(s: XState, a: XActor, skill_id: int) -> Dictionary:
	if not on(s):
		return {"ok": false, "reason": "秘籍格系统未开启"}
	if s == null:
		s = XState.current
	if a == null or not is_sealed(a, skill_id, s):
		return {"ok": false, "reason": "该秘籍未处于封印状态"}
	var replaced := 0
	if is_conversion_skill(skill_id):
		replaced = active_conversion_id(a, s)
	if replaced == 0:
		var cap := limit(a)
		var used := used_slots(a, s)
		if cap > 0 and used >= cap:
			return {"ok": false, "reason": "秘籍格已满（%d/%d），请先封印一本秘籍" % [used, cap]}
	var row := _write_actor(s, a.actor_id)
	var arr: Array = row["sealed"]
	arr.erase(skill_id)
	if replaced > 0 and not arr.has(replaced):
		arr.append(replaced)
	arr.sort()
	_refresh_actor(a)
	return {"ok": true, "replaced": replaced}


static func finish_free_pick(s: XState, a: XActor) -> void:
	if not on(s) or a == null:
		return
	if s == null:
		s = XState.current
	var sec = XTianqiSave.peek(s, SECTION)
	if not (sec is Dictionary):
		return
	var actors = sec.get("actors")
	if not (actors is Dictionary):
		return
	var row = actors.get(str(a.actor_id))
	if row is Dictionary:
		row["free_pick"] = false


static func _refresh_actor(a: XActor) -> void:
	a.read_touch()
	a.param_mark_dirty()
	a.refresh_passive()
	a.refresh_resources()


# ---- 老存档迁移（XTianqiSave.after_load 调用，幂等）----

static func migrate_after_load(s: XState) -> void:
	if not on(s) or not XTianqiSave.ENABLED or s == null:
		return
	# 1) 清理已有 secrets 节中已经不在 skill_ids 或不再占格的脏 ID
	var existing = XTianqiSave.peek(s, SECTION)
	if existing is Dictionary:
		fill(existing)
		var actors_map: Dictionary = existing.get("actors", {})
		for k in actors_map.keys():
			var aid := int(k)
			var a: XActor = s.actors.get(aid)
			if a == null:
				continue
			var row: Dictionary = actors_map[k]
			var kept: Array[int] = []
			for sid in row.get("sealed", []):
				var id := int(sid)
				if a.skill_ids.has(id) and occupies_slot(id) and not kept.has(id):
					kept.append(id)
			kept.sort()
			row["sealed"] = kept
	# 2) 检查每名角色是否超格（老存档不没收，超出部分自动移入已封并授予一次免费自选）
	for a in s.actors.values():
		if not (a is XActor):
			continue
		var cap := limit(a)
		if cap <= 0:
			continue
		var act := active_ids(a, s)
		if act.size() <= cap:
			continue
		var row := _write_actor(s, a.actor_id)
		var sealed: Array = row["sealed"]
		var overflow := act.slice(cap)
		for sid in overflow:
			if not sealed.has(sid):
				sealed.append(sid)
		sealed.sort()
		row["free_pick"] = true
		_refresh_actor(a)


# ---- UI 辅助（供 skill_scene.gd / skin_skill_page.gd 调用，发行空壳零外泄）----

## 该技能分类页是否展示秘籍格（功法 6、被动 4）
static func is_secret_stype(stype: int) -> bool:
	if not on():
		return false
	_ensure_index()
	return _slot_stypes.has(stype)


## 某角色在指定技能分类下的已封秘籍视图数组（附加 _tq_sealed = true，不污染 XDB 原表）
static func sealed_entries_for_stype(a: XActor, stype: int, s: XState = null) -> Array:
	if not on(s) or a == null:
		return []
	var out := []
	for sid in sealed_ids(a, s):
		var rec := XDB.rec("Skills", sid)
		if rec.is_empty() or int(rec.get("stypeId", 0)) != stype:
			continue
		var view := rec.duplicate()
		view["_tq_sealed"] = true
		out.append(view)
	return out


static func is_entry_sealed(sk: Dictionary) -> bool:
	return bool(sk.get("_tq_sealed", false))


static func is_entry_manageable(a: XActor, sk: Dictionary, s: XState = null) -> bool:
	if not on(s) or a == null or sk.is_empty():
		return false
	if is_entry_sealed(sk):
		return true
	var sid := int(sk.get("id", 0))
	return sid > 0 and a.skill_ids.has(sid) and occupies_slot(sid)


## 状态栏／列表顶标题用的秘籍格概要（如「秘籍格 3 / 6」或「秘籍格 4 / 4 · 已封 2 · 免费自选」）
static func ui_slot_text(a: XActor, s: XState = null) -> String:
	if not on(s) or a == null:
		return ""
	var used := used_slots(a, s)
	var cap := limit(a)
	var sn := sealed_ids(a, s).size()
	var base := "秘籍格 %d / %d" % [used, cap]
	if sn > 0:
		base += "（已封 %d）" % sn
	if has_free_pick(a, s):
		base += " · 免费自选"
	return base


static func ui_list_title(base_title: String, a: XActor, stype: int, s: XState = null) -> String:
	if not on(s) or a == null or not is_secret_stype(stype):
		return base_title
	return "%s · %s" % [base_title, ui_slot_text(a, s)]


## 列表行右侧标签与选中原因提示（返回 {} 表示非秘籍）
static func ui_row_meta(a: XActor, sk: Dictionary, s: XState = null) -> Dictionary:
	if not on(s) or a == null or sk.is_empty():
		return {}
	var free := has_free_pick(a, s)
	if is_entry_sealed(sk):
		return {
			"sealed": true,
			"badge": "已封",
			"old_badge": "[已封]",
			"reason": "按确定免费启封" if free else "按确定启封",
		}
	var sid := int(sk.get("id", 0))
	if sid > 0 and a.skill_ids.has(sid) and occupies_slot(sid):
		return {
			"sealed": false,
			"badge": "占格",
			"old_badge": "[秘籍]",
			"reason": "按确定免费封印" if free else "按确定封印",
		}
	return {}


## 详情牌按钮与副标题补充（供新皮肤 skin_skill_page.gd 用）
static func ui_card_actions(s: XState, a: XActor, sk: Dictionary) -> Dictionary:
	if not on(s) or a == null or sk.is_empty() or not is_entry_manageable(a, sk, s):
		return {}
	if s == null:
		s = XState.current
	var free := has_free_pick(a, s)
	var btns: Array = []
	var tag := ""
	if is_entry_sealed(sk):
		var sid := int(sk.get("id", 0))
		var can_up := (is_conversion_skill(sid) and active_conversion_id(a, s) > 0) or used_slots(a, s) < limit(a)
		tag = "已封印 · 不生效"
		btns.append({"text": "启封秘籍", "action": "unseal", "disabled": not can_up})
	else:
		var cost := seal_cost(s, a)
		tag = "占秘籍格（%d/%d）" % [used_slots(a, s), limit(a)]
		if cost == 0:
			btns.append({"text": "免费封印", "action": "seal", "disabled": false})
		else:
			btns.append({"text": "封印（%s 精魂）" % XMenu._group(cost), "action": "seal", "disabled": s.gold < cost})
	if free:
		btns.append({"text": "完成自选", "action": "finish_free", "disabled": false})
	return {"tag": tag, "buttons": btns}


## 封印／启封确认弹窗文案（新旧两套皮肤共用）
static func ui_confirm_spec(s: XState, a: XActor, sk: Dictionary) -> Dictionary:
	if not on(s) or a == null or sk.is_empty() or not is_entry_manageable(a, sk, s):
		return {}
	if s == null:
		s = XState.current
	var nm := str(sk.get("name", ""))
	var sid := int(sk.get("id", 0))
	var free := has_free_pick(a, s)
	if is_entry_sealed(sk):
		var old_conv := active_conversion_id(a, s) if is_conversion_skill(sid) else 0
		var body := ""
		var can_up := true
		if old_conv > 0:
			var old_nm := str(XDB.rec("Skills", old_conv).get("name", ""))
			body = "启封后将与当前生效的「%s」互换（不额外占格），被动立即生效。" % old_nm
		elif used_slots(a, s) >= limit(a):
			can_up = false
			body = "当前秘籍格已满（%d / %d），请先封印一本生效中的秘籍。" % [used_slots(a, s), limit(a)]
		else:
			body = "启封后将占用 1 个秘籍格（当前 %d / %d），被动立即生效。" % [used_slots(a, s), limit(a)]
		var buttons: Array = [{"text": "确认启封", "disabled": not can_up, "action": "unseal"}]
		if free:
			buttons.append({"text": "完成自选", "disabled": false, "action": "finish_free"})
		buttons.append({"text": "取消", "disabled": false, "action": "cancel"})
		return {"title": "启封「%s」？" % nm, "body": body, "danger": false, "buttons": buttons, "skill_id": sid}
	var cost := seal_cost(s, a)
	var body2 := ""
	var can_seal := true
	if cost == 0:
		body2 = "老存档免费自选期间本次封印不收费。封印后被动立即失效，腾出 1 个秘籍格（书本不退还，可在已封列表重新启封）。"
	else:
		can_seal = s.gold >= cost
		body2 = "封印后被动立即失效，腾出 1 个秘籍格，书本不退还。需花费 %s 精魂（当前 %s）。" % [XMenu._group(cost), XMenu._group(s.gold)]
	var buttons2: Array = [{"text": "确认封印", "disabled": not can_seal, "action": "seal"}]
	if free:
		buttons2.append({"text": "完成自选", "disabled": false, "action": "finish_free"})
	buttons2.append({"text": "取消", "disabled": false, "action": "cancel"})
	return {"title": "封印「%s」？" % nm, "body": body2, "danger": true, "buttons": buttons2, "skill_id": sid}


static func ui_gold_currency(s: XState = null) -> Array:
	if not on(s):
		return []
	if s == null:
		s = XState.current
	return [["精魂", XMenu._group(s.gold)]]


static func ui_action_toast(action: String, sk_name: String, res: Dictionary) -> String:
	if not on():
		return ""
	if not bool(res.get("ok", false)):
		return str(res.get("reason", "操作失败"))
	match action:
		"seal":
			if bool(res.get("free", false)):
				return "已免费封印「%s」，腾出 1 个秘籍格" % sk_name
			return "已封印「%s」（消耗 %s 精魂），腾出 1 个秘籍格" % [sk_name, XMenu._group(int(res.get("cost", 0)))]
		"unseal":
			return "已启封「%s」，被动已生效" % sk_name
		"finish_free":
			return "已完成老存档免费自选，后续封印将收取精魂"
	return ""


## 技能页执行封印／启封／完成自选（含音效与提示，成功返回 true；关着或西游档恒返回 false）
static func ui_exec_action(s: XState, a: XActor, action: String, skill_id: int) -> bool:
	if not on(s):
		return false
	if s == null:
		s = XState.current
	var sk_name := str(XDB.rec("Skills", skill_id).get("name", "")) if skill_id > 0 else ""
	if action == "finish_free":
		finish_free_pick(s, a)
		XSound.system(1)
		XToast.show_text(ui_action_toast("finish_free", sk_name, {"ok": true}), true)
		return true
	var res := seal(s, a, skill_id) if action == "seal" else unseal(s, a, skill_id)
	if not bool(res.get("ok", false)):
		XSound.system(3)
		XToast.show_text(ui_action_toast(action, sk_name, res), true)
		return false
	XSound.system(1)
	XToast.show_text(ui_action_toast(action, sk_name, res), true)
	return true
