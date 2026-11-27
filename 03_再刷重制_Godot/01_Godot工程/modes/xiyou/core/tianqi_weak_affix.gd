class_name XTianqiWeakAffix
extends RefCounted
## 【cc·未经审查】天启篇弱者专属词条：批 0A 规则地基（私密仓 重制设定/天启篇_弱者专属词条设计_v0.3 第二节第 1、2、4（一句）、5、6 条
## ＋ v0.3.1 第二节四条；Kyo D65～D72，D72：先做批 0A，具体词条等基础数值定了再做）。这里只有地基，**一条具体词条都没有**：
## 表 tianqi_data/weak_affix_table.json 的 entries 一律默认关（批 1 起有条目），「可引导」名单是空的，所以开着时战斗结果和没有本模块逐字节一样。
##
## 一、装备与作用域（第 5 条）
##   装备实例上 tianqi_exclusive: {key}；只认武器、副手两格（rules.slots），两格同一条只算一条。
##   生效＝模块开（ENABLED，O-524）＋天启篇档＋（发行另要 XTianqi.RELEASE_OPEN）＋这条开着（entries[key].enabled，默认全关）＋
##   装的人是本人（entries[key].actor）＋他在场上（logic.actors；助力位没上场不生效）＋活着。
##   每人的库存、格数、标签放在本场 unit 里，换装、离场、倒下、战斗结束都清（unit 每次取都对一遍签名，变了就从零起）。
## 二、根与五类事件（第 2 条）
##   act／_forced_run 各开一根（root_begin／root_end，进出配对，中途没收尾的下一根开始时报警清掉）；根里按阶段记事件类型：
##   主动根 ROOT → 行动执行完后的各种追加 FOLLOW（再释放 RECAST）；行动里的原生反击、反射 COUNTER；本模块代出的专属派生 DERIVED。
##   只有 ROOT 里、根的出手者用根的那一招造成的直接有效命中才记进 hits（四骑士主动技经 horseman_strike 同样记；回合末死期、
##   灼烧、疫病不经这两处，所以不记）；专属派生打到混子不记「这人打过混子」（XTianqiHorsemen.hp_damage 看 in_derived）。
##   次数：每根（take_root）、每自然回合（take_turn，只在回合开始、回合结束清；多动、强制行动、追加都不清）。
## 三、最终受击者（第 1 条＋v0.3.1 第二节第 1 条）
##   只在 execute 的选目标之后、排在四骑士嘲讽、瘟疫挑衅、混子之盾三层之后（三层改过目标就不动）；强制行动、混乱不引导；
##   技能要在「可引导」名单里且是单体对敌（scope 1）。成功后记 guide{guider, orig}：原生掩护对引导者跳过，反射、反击按引导者判（目标就是他）。
##   每一段生效前复查（segment_target，两种多段都经这里）：引导者合法照打；不合法（倒下，或挂着暂不倒下而生命到 0）回原目标并摘标签，
##   原目标也不合法就跳过这一段；不重掷、不改找别人。回原目标时原目标记进收尾结算（finish_targets）。多个引导者取出战栏靠前的。
## 四、首领（第 4 条那一句）：boss_turns（控制向下取半、普通减益向上取半至少 1；幅度不砍）。
## 五、看得见（v0.3.1 第二节第 4 条）：badges（角标文字）、say（战斗日志一行）只留出口，图标和文案交小A。
## 六、掉落（第 5 条末句、D65）：drop_candidates／roll_drop 只给接口，**还没接进掉落**（条目为空时池恒空，接了也不改任何结果）；
##   开第一条时连同可获得兵器交集表、深渊商人指定、重铸保护一起接。
## 七、本人投影（批 1，T018）：表 entries[键].proj 按技能号写换属性、整数倍率、新范围和说明替换；skill_view 给本人复制一份改过的技能，
##   formula 按出手者 proj_of 换属性、乘倍率。批 1：w21 玛莎「御风术」、w17 克洛什「精准击中」，默认关。
## 八、批 2 前四人（T230）：w31 露茜、w23 魔雷老人、w103 波风水门、w3 艾坤的规则在 XTianqiWeakB2（tianqi_weak_b2.gd），start 时 install；
##   这里另给 main_target（这一根的主目标，guide_targets 记）、cut／dmg_pct（这一根伤害整数百分比，formula 读）、处理对象的 root_skill 钩子。
## 具体词条以 register(key, 处理对象) 挂进来：处理对象可有 root_end(logic, frame) -> Array（这一根结算完后出专属派生，派生用 derived_invoke）、
## root_skill(logic, frame, skill)（execute 付费后这一根的那一招）、turn_begin(logic)、turn_end(logic)、badge(logic, b) -> String。

## 开关（O-524）：false＝专属词条在战斗里完全不生效（不引导、不记事件、不派生），装备上的专属只显示灰字
static var ENABLED := true

const PATH := "res://modes/xiyou/tianqi_data/weak_affix_table.json"
const ITEM_KEY := "tianqi_exclusive"
const META := "tq_weak_affix"

## 事件类型（v0.3 第二节第 2 条那张表）
const ROOT := "root"
const FOLLOW := "native_follow"
const RECAST := "native_recast"
const COUNTER := "native_counter"
const DERIVED := "derived"

static var _data := {}
static var _load_failed := false
## 具体词条的处理对象：键 → Object（register）
static var _handlers := {}
## 测试注入：在表之外临时加条目、加可引导技能（正式数据只走表）
static var test_entries := {}
static var test_guidable := []


static func data() -> Dictionary:
	if _data.is_empty() and not _load_failed:
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = d if d is Dictionary else {}
		_load_failed = _data.is_empty()
	return _data


static func reload_table(d := {}) -> void:
	XActor.skills_touch()  # T546 R1 P3-1：技能记录读这张表，重载后角色技能表缓存作废
	_data = d
	_load_failed = false


static func rules() -> Dictionary:
	var r = data().get("rules", {})
	return r if r is Dictionary else {}


static func on(s = null) -> bool:
	if not ENABLED:
		return false
	if s == null:
		s = XState.current
	return s != null and XTianqi.active(s) and (XTianqi.RELEASE_OPEN or not ReleaseEntry.is_release())


static func _active(logic) -> bool:
	return logic != null and logic.state != null and on(logic.state)


# ---- 条目、开关 ----

static func entry(key: String) -> Dictionary:
	if test_entries.has(key):
		return test_entries[key]
	var e = data().get("entries", {}).get(key, {})
	return e if e is Dictionary else {}


## 这一条开着没有（按条开关，默认关）
static func enabled(key: String) -> bool:
	var e := entry(key)
	return not e.is_empty() and bool(e.get("enabled", false))


static func register(key: String, handler: Object) -> void:
	if handler == null:
		_handlers.erase(key)
	else:
		_handlers[key] = handler


static func guidable(skill) -> bool:
	if not (skill is Dictionary) or skill.has("tianqi_horseman") or int(skill.get("scope", 0)) != 1:
		return false
	var id := int(skill.get("id", 0))
	var list: Array = data().get("guidable_skills", [])
	return test_guidable.has(id) or list.has(id) or list.has(float(id))  # JSON 读进来是浮点（T231：Array.has 分 int／float）


# ---- 装备 ----

static func item_key(e) -> String:
	if not (e is Dictionary):
		return ""
	var x = e.get(ITEM_KEY, null)
	return str(x.get("key", "")) if x is Dictionary else ""


## 身上武器、副手的专属键（去重：武器副手带同一条只算一条）
static func keys_of(a) -> Array:
	var out := []
	if not (a is XActor):
		return out
	for i in rules().get("slots", [0, 1]):
		var slot := int(i)
		if slot < a.equips.size():
			var k := item_key(a.equips[slot])
			if k != "" and not out.has(k):
				out.append(k)
	return out


## 这件装备上的专属对这个人生效吗（不看在不在场）：{ok, gray, reason}。说明文字变灰用（D67：只本人生效、文字变灰）
static func text_state(item, a, s = null) -> Dictionary:
	var k := item_key(item)
	if k == "":
		return {"ok": false, "gray": false, "reason": ""}
	var e := entry(k)
	if e.is_empty():
		return {"ok": false, "gray": true, "reason": "unknown"}
	if not on(s) or not enabled(k):
		return {"ok": false, "gray": true, "reason": "off"}
	if not (a is XActor) or int(a.actor_id) != int(e.get("actor", 0)):
		return {"ok": false, "gray": true, "reason": "not_owner"}
	return {"ok": true, "gray": false, "reason": ""}


## 战斗里这个人此刻生效的专属键（本人、在场、活着、开关开着）
static func active_keys(logic, a) -> Array:
	if not _active(logic) or not (a is XActor) or not logic.actors.has(a) or a.is_dead():
		return []
	return keys_of(a).filter(func(k): return enabled(k) and int(entry(k).get("actor", 0)) == int(a.actor_id))


# ---- 本场数据 ----

static func _store(logic) -> Dictionary:
	if not logic.has_meta(META):
		logic.set_meta(META, {"frames": [], "roots": 0, "turn_used": {}, "marks": {}, "units": {}})
	return logic.get_meta(META)


## BattleLogic.setup 末尾：本场数据从零起
static func start(logic) -> void:
	if logic.has_meta(META):
		logic.remove_meta(META)
	cut = {}
	XTianqiWeakB2.install()  # 批 2 前四人（T230）的处理对象
	if _active(logic):
		_store(logic)


## BattleLogic.end_battle：库存、格数、标签全清（战斗结束、逃跑都走这里）
static func finish(logic) -> void:
	cut = {}
	if logic != null and logic.has_meta(META):
		logic.remove_meta(META)


## 这个人这一场的专属数据（库存、格数、标签放 stock[键] 里）。换装、离场、倒下：签名对不上就从零起
static func unit(logic, a) -> Dictionary:
	if not _active(logic) or not (a is XActor):
		return {}
	var units: Dictionary = _store(logic).units
	var sig := ",".join(active_keys(logic, a))
	if sig != "":
		for i in rules().get("slots", [0, 1]):
			var slot := int(i)
			sig += "|%d" % (hash(a.equips[slot]) if slot < a.equips.size() and a.equips[slot] is Dictionary else 0)  # 换了别的一件也算换装
	var u = units.get(a)
	if not (u is Dictionary) or str(u.sig) != sig:
		u = {"sig": sig, "stock": {}}
		units[a] = u
	return u


static func stock(logic, a, key: String) -> Dictionary:
	var u := unit(logic, a)
	if u.is_empty():
		return {}
	if not u.stock.has(key):
		u.stock[key] = {}
	return u.stock[key]


# ---- 根与事件 ----

static func _frame(logic) -> Dictionary:
	if not logic.has_meta(META):
		return {}
	var frames: Array = logic.get_meta(META).frames
	return frames.back() if not frames.is_empty() else {}


## act／_forced_run 开头：开一根
static func root_begin(logic, u, skill) -> void:
	if not _active(logic):
		return
	var st := _store(logic)
	for a in st.units.keys():
		unit(logic, a)  # 根与根之间换过装、离过场、倒下过的：在这里对签名，变了从零起
	st.roots = int(st.roots) + 1
	st.frames.append({"id": int(st.roots), "user": u, "skill": _skill_key(skill), "forced": false,
		"kinds": [ROOT], "used": {}, "hits": [], "guide": {}, "finish": []})


## 这一根的一招（execute 付费之后的投影）：记下来认直接命中用
static func root_skill(logic, skill) -> void:
	var f := _frame(logic)
	if not f.is_empty() and _kind(f) == ROOT:
		f.skill = _skill_key(skill)
		for k in _live_keys(logic):
			var h = _handlers.get(k)
			if h != null and h.has_method("root_skill"):
				h.root_skill(logic, f, skill)


## 这一根定的主目标（execute 选目标、专属引导之后的第一个；全体技取它排第一的那个）。没有＝null
static func main_target(logic):
	var f := _frame(logic)
	return f.get("main") if not f.is_empty() else null


## 这一根伤害的整数百分比（批 2 波风水门第一次飞雷神 −30%）：{user, skill, pct}，root_skill 里由词条设、root_end 清
static var cut := {}


static func dmg_pct(a, skill_id: int) -> int:
	if cut.is_empty() or not is_same(cut.get("user"), a) or int(cut.get("skill", 0)) != skill_id:
		return 100
	return int(cut.get("pct", 100))


## act／_forced_run 末尾：这一根结算完——各条专属按 hits 出派生，然后收根
static func root_end(logic, _u = null) -> Array:
	if not _active(logic):
		return []
	var st := _store(logic)
	if st.frames.is_empty():
		return []
	var f: Dictionary = st.frames.back()
	cut = {}
	f.kinds = [DERIVED]  # 派生不能自称主动根
	_drop_dead_guiders(st)
	var logs := []
	for k in _live_keys(logic):
		var h = _handlers.get(k)
		if h != null and h.has_method("root_end"):
			logs.append_array(h.root_end(logic, f))
	st.frames.pop_back()
	return logs


## 行动执行完以后（追加、再释放阶段）
static func set_kind(logic, kind: String) -> void:
	var f := _frame(logic)
	if not f.is_empty():
		f.kinds[f.kinds.size() - 1] = kind if _kind(f) != DERIVED else DERIVED


static func push_kind(logic, kind: String) -> void:
	var f := _frame(logic)
	if not f.is_empty():
		f.kinds.append(DERIVED if _kind(f) == DERIVED else kind)  # 派生里的反击仍算派生，不连锁


static func pop_kind(logic) -> void:
	var f := _frame(logic)
	if not f.is_empty() and f.kinds.size() > 1:
		f.kinds.pop_back()


static func _kind(f: Dictionary) -> String:
	return str(f.kinds.back()) if not f.is_empty() and not f.kinds.is_empty() else ""


static func kind(logic) -> String:
	return _kind(_frame(logic)) if logic != null else ""


static func in_derived(logic) -> bool:
	return logic != null and kind(logic) == DERIVED


## 原生反击、反射打混子不记「打过混子」（O-525，v0.3.1 第二节第 3 条「顺手对齐」）；false＝回到旧行为：原生反击照记
static var COUNTER_NO_HUNZI_MARK := true


## 这一击不是出手者自己的行动：专属派生；原生反击、反射（COUNTER_NO_HUNZI_MARK 开着时）
static func not_own_action(logic) -> bool:
	if logic == null:
		return false
	var k := kind(logic)
	return k == DERIVED or (COUNTER_NO_HUNZI_MARK and k == COUNTER)


static func _skill_key(skill) -> String:
	if not (skill is Dictionary):
		return ""
	if skill.has("tianqi_horseman"):
		return "h:" + str(skill.tianqi_horseman) + ":" + str(skill.get("key", skill.get("name", "")))
	return str(int(skill.get("id", 0)))


## BattleLogic.apply／horseman_strike 之后：主动根里出手者用根的那一招直接有效命中对面的人，记一笔
static func note_hit(logic, u, skill, t, r) -> void:
	if not _active(logic) or not (r is Dictionary):
		return
	var f := _frame(logic)
	if f.is_empty() or _kind(f) != ROOT or not is_same(u, f.user) or u == null or t == null:
		return
	if str(r.get("type", "")) != "hit" or bool(r.get("missed", false)) or bool(r.get("evaded", false)) or bool(r.get("reflected", false)):
		return
	if u.is_actor() == t.is_actor() or _skill_key(skill) != str(f.skill):
		return
	f.hits.append({"user": u, "target": t, "hp": float(r.get("hp", 0.0))})


## 这一根里直接有效命中过 t 的次数（多段算多次；专属自己决定「只算一次」）
static func hits_on(frame: Dictionary, t) -> int:
	return frame.get("hits", []).filter(func(h): return is_same(h.target, t)).size()


## 专属派生：以 u 的名义对 t 打一下 skill（照原生的反射、反击走，但都算派生，不再触发任何专属、不记直接命中）
static func derived_invoke(logic, u, skill: Dictionary, t) -> Array:
	if not _active(logic):
		return []
	push_kind(logic, DERIVED)
	var out: Array = logic.mark_views(logic._invoke(u, skill, t))
	pop_kind(logic)
	return out


# ---- 次数 ----

## 每根一次：这一根里第一次返回 true（全体、多段都是一根）
static func take_root(logic, owner, key: String) -> bool:
	var f := _frame(logic)
	if f.is_empty():
		return false
	var k := "%d|%s" % [owner.get_instance_id() if owner != null else 0, key]
	if f.used.has(k):
		return false
	f.used[k] = true
	return true


static func turn_count(logic, owner, key: String) -> int:
	if not _active(logic):
		return 0
	return int(_store(logic).turn_used.get("%d|%s" % [owner.get_instance_id() if owner != null else 0, key], 0))


## 每自然回合最多 cap 次：没到上限就记一次、返回 true
static func take_turn(logic, owner, key: String, cap := 1) -> bool:
	if not _active(logic):
		return false
	var n := turn_count(logic, owner, key)
	if n >= cap:
		return false
	_store(logic).turn_used["%d|%s" % [owner.get_instance_id() if owner != null else 0, key]] = n + 1
	return true


## BattleLogic.start_turn 开头：自然回合开始
static func turn_begin(logic) -> void:
	if not _active(logic):
		return
	var st := _store(logic)
	if not st.frames.is_empty():
		push_warning("天启篇专属词条：上一根没有收尾（%d 层），开新回合时清掉" % st.frames.size())
		st.frames.clear()
		cut = {}  # 没收尾那一根的伤害百分比一起清
	st.turn_used.clear()
	for k in _live_keys(logic):
		var h = _handlers.get(k)
		if h != null and h.has_method("turn_begin"):
			h.turn_begin(logic)


## BattleLogic.end_turn：自然回合结束——次数清零，「到本自然回合结束」的标签（受邀）摘掉
static func turn_end(logic) -> void:
	if not _active(logic):
		return
	var st := _store(logic)
	st.turn_used.clear()
	st.marks.clear()
	for k in _live_keys(logic):
		var h = _handlers.get(k)
		if h != null and h.has_method("turn_end"):
			h.turn_end(logic)


static func _live_keys(logic) -> Array:
	var out := []
	for a in logic.actors:
		for k in active_keys(logic, a):
			if not out.has(k):
				out.append(k)
	return out


# ---- 最终受击者：专属引导 ----

## 敌人 foe 这一回合的可引导根行动改打 guider（到本自然回合结束；同一个引导者重复标只留一份）
static func mark_guide(logic, foe, guider, key := "") -> void:
	if not _active(logic) or foe == null or guider == null:
		return
	var marks: Dictionary = _store(logic).marks
	if not marks.has(foe):
		marks[foe] = {}
	marks[foe][guider] = key


static func unmark_guide(logic, foe, guider = null) -> void:
	if not _active(logic):
		return
	var marks: Dictionary = _store(logic).marks
	if guider == null:
		marks.erase(foe)
	elif marks.has(foe):
		marks[foe].erase(guider)


## 引导者倒下：他挂出去的引导全部作废（同回合被拉起来，旧的也不再生效）。倒下的人没有生效键、处理对象收不到，所以在这里扫
static func _drop_dead_guiders(st: Dictionary) -> void:
	for foe in st.marks.keys():
		var m: Dictionary = st.marks[foe]
		for g in m.keys():
			if g == null or not is_instance_valid(g) or g.is_dead():
				m.erase(g)
		if m.is_empty():
			st.marks.erase(foe)


static func guiders_of(logic, foe) -> Array:
	if not _active(logic):
		return []
	return _store(logic).marks.get(foe, {}).keys()


## 合法：活着（挂着暂不倒下而生命到 0 不算）、在场、没隐身
static func legal(logic, b) -> bool:
	if b == null or b.is_dead() or (b.immortal and b.hp <= 0.0):
		return false
	if b is XEnemy:
		return logic.enemies.has(b) and not b.hidden
	return logic.actors.has(b)


## execute 选完目标：可引导技能改打引导者（layers_changed＝四骑士、瘟疫、混子之盾三层改过目标，不再动）
static func guide_targets(logic, u, skill, list: Array, layers_changed := false, forcing := false) -> Array:
	var out := _guide_targets(logic, u, skill, list, layers_changed, forcing)
	var f := _frame(logic)
	if not f.is_empty() and _kind(f) == ROOT and is_same(u, f.user) and not f.has("main"):
		f.main = out[0] if not out.is_empty() else null  # 这一根的主目标（批 2：艾坤传球、魔雷老人落雷打它）
	return out


static func _guide_targets(logic, u, skill, list: Array, layers_changed := false, forcing := false) -> Array:
	if not _active(logic) or forcing or layers_changed or list.size() != 1 or not guidable(skill):
		return list
	var f := _frame(logic)
	if f.is_empty() or _kind(f) != ROOT or not is_same(u, f.user) or XConfusion.confused(u):
		return list
	var orig = list[0]
	if orig == null or orig.is_actor() == u.is_actor():
		return list
	var side: Array = logic.actors if orig.is_actor() else logic.enemies
	var best = null
	for g in guiders_of(logic, u):
		if g == null or g.is_actor() != orig.is_actor() or not legal(logic, g):
			continue
		if best == null or side.find(g) < side.find(best):
			best = g  # 同时有多个引导者：取出战栏靠前的
	if best == null or is_same(best, orig):
		return list
	f.guide = {"guider": best, "orig": orig, "active": true, "reverted": false}
	return [best]


## 掩护（substitute_for）：被专属引导成功的那一个目标，原生掩护不再换人
static func guided(logic, t) -> bool:
	if not _active(logic):
		return false
	var g: Dictionary = _frame(logic).get("guide", {})
	return not g.is_empty() and bool(g.active) and is_same(t, g.guider)


## 每一段生效前（execute 的逐段循环、行动序列的 ACTION EFFECT）：返回这一段实际要打的人；null＝这一段跳过
static func segment_target(logic, _u, _skill, t):
	if not _active(logic):
		return t
	var f := _frame(logic)
	if _kind(f) != ROOT:
		return t  # 只管主动根本身的段（T035）：根执行完的追加（FOLLOW_FULL 打满整招）、再释放、反击、派生不复用这一根的引导
	var g: Dictionary = f.get("guide", {})
	if g.is_empty() or not is_same(t, g.guider):
		return t
	if bool(g.active) and legal(logic, t):
		return t
	if bool(g.active):
		g.active = false  # 摘掉「已引导」：之后的段按没被引导处理，原生掩护照常
		g.reverted = true
		var fin: Array = f.finish
		if not fin.has(g.orig):
			fin.append(g.orig)
	return g.orig if legal(logic, g.orig) else null


## execute 收尾（逐个 refresh 倒下结算）要加上的人：引导失效后回去打的原目标
static func finish_targets(logic) -> Array:
	if not _active(logic):
		return []
	return _frame(logic).get("finish", [])


# ---- 首领（第 4 条，0A 只这一句） ----

## 专属上的减益挂到首领身上的回合数：控制向下取半（0＝不挂），普通减益向上取半、至少 1 回合；不是首领原样
static func boss_turns(e, state_id: int, n: int) -> int:
	if not (e is XEnemy) or not e.boss_difficulty_boss or n <= 0:
		return n
	if XEnemy.boss_control_state(state_id):
		return n / 2
	return maxi(1, ceili(n / 2.0))


# ---- 看得见（出口；图标和文案交小A） ----

## 角色或敌人身上的文字角标（蓄雷格数、传球库存、被护者、受邀者……由各条专属给）
static func badges(logic, b) -> Array:
	var out := []
	if not _active(logic) or not logic.has_meta(META):
		return out  # 只读：战斗结束（finish 已清本场数据）后胜利镜头、结算期间不重建，角标跟着消失
	for k in _live_keys(logic):
		var h = _handlers.get(k)
		if h != null and h.has_method("badge"):
			var s = h.badge(logic, b)
			if s is String and s != "":
				out.append(s)
	return out


## 战斗日志一行
static func say(text: String) -> Dictionary:
	return {"type": "battle_text", "text": text}


# ---- 本人投影（批 1：纯数据样板，v0.3 第三节＋v0.3.1 第三节 21、17） ----
## 表 entries[键].proj：{技能号: {stat_swap {原属性: 新属性}, mult 整数倍率, scope 新范围, header {表头: 值}, text {原词: 新词}}}。
## 只改本人看到的那一份技能（skill_view 复制一份改，不碰共享的改写表、XDB 记录）：技能页、帮助卡、战斗技能表、自动战斗、追加招都读这一份；
## 伤害（stat_swap、mult）在 XTianqiSkills.formula 里按出手者 proj_of 算。要角色卡开着（cards_on）：卡关着时技能不走模块公式，投影整个不做。

const VIEW_MARK := "_tq_weak_proj"
const STAT_NAMES := {"atk": "物理攻击", "def": "物理防御", "mat": "魔法攻击", "mdf": "魔法防御", "agi": "敏捷", "luk": "幸运", "mhp": "最大生命", "mmp": "最大魔法"}
static var _views := {}  # 技能号 → [原记录, 签名, 投影后的记录]


## 开着的条目里有投影的技能号（快速排除：没有就不看装备）
static func _proj_ids() -> Dictionary:
	proj_ids_builds += 1
	var out := {}
	if not ENABLED:
		return out
	var keys: Array = data().get("entries", {}).keys() + test_entries.keys()
	for k in keys:
		if enabled(k):
			for id in entry(k).get("proj", {}):
				out[int(id)] = true
	return out


## T572 西游档卡顿（O-待定-1）：先判天启篇档（on），不是就不建投影号表。原来先建 _proj_ids 再判档，西游档每建一条技能记录
## （XActor._skill_records）都要把全部条目过一遍，技能表重建贵了约 9 倍（玩家存档 40 次行动 0.6→5.4 秒）。几项都是只读判断，换序结果不变。
## 回退：XIYOU_SKIP = false（先建投影号表再判档，同原来）
static var XIYOU_SKIP := true
## 专项量数：投影号表建了几次
static var proj_ids_builds := 0


## 这个人放 skill_id 时的投影规格（没有＝{}）：本人装着、条目开着、天启篇档、角色卡开着
static func proj_of(a, skill_id: int, s = null) -> Dictionary:
	if XIYOU_SKIP and not on(s):
		return {}
	if not (a is XActor) or not _proj_ids().has(skill_id) or not on(s) or not XTianqiSkills.cards_on(s):
		return {}
	for k in keys_of(a):
		var e := entry(k)
		if enabled(k) and int(e.get("actor", 0)) == int(a.actor_id):
			var p = e.get("proj", {}).get(str(skill_id), null)
			if p is Dictionary:
				var out: Dictionary = p.duplicate()
				out["key"] = k
				return out
	return {}


## 属性换算：stats {属性: 权重} 按 swap {原: 新} 换键，系数不变
static func swap_stats(stats: Dictionary, swap: Dictionary) -> Dictionary:
	var out := {}
	for k in stats:
		var nk := str(swap.get(str(k), str(k)))
		out[nk] = float(out.get(nk, 0.0)) + float(stats[k])
	return out


## 技能表跨调用缓存（XActor.SKILLS_XCALL，T546）的键：skill_view 对这个人可能用到的全部投影规格（proj_of 的输入）。proj_of 改读别的东西时这里一起改
static func view_sig(a) -> Array:
	if not (a is XActor) or not ENABLED or not on() or not XTianqiSkills.cards_on():
		return []
	var out := []
	for k in keys_of(a):
		var e := entry(k)
		if enabled(k) and int(e.get("actor", 0)) == int(a.actor_id):
			out.append([k, (e.get("proj", {}) as Dictionary).duplicate(true) if e.get("proj", {}) is Dictionary else e.get("proj")])
	return out


## 本人看到的技能记录（XActor._skill_records、XTianqiSkills._follow_of、XBattleLogic.act 都过这里）：没有投影原样返回；已经投影过的不再投影
static func skill_view(sk: Dictionary, a) -> Dictionary:
	if sk.is_empty() or sk.has(VIEW_MARK):
		return sk
	var id := int(sk.get("id", 0))
	var p := proj_of(a, id)
	if p.is_empty():
		return sk
	var sig := JSON.stringify(p)
	var hit = _views.get(id)
	if hit is Array and is_same(hit[0], sk) and str(hit[1]) == sig:
		return hit[2]
	var v: Dictionary = sk.duplicate(true)
	v[VIEW_MARK] = str(p.key)
	if p.has("scope"):
		v.scope = int(p.scope)
	v.note = _proj_note(str(v.get("note", "")), p)
	v.meta = XTianqiSkills.parse_meta(v.note)
	_views[id] = [sk, sig, v]
	return v


## 说明跟着变（v0.3.1 第二节第 4 条）：表头（对象）、「伤害」行里的属性名和 × 后面的系数、指定的词；末尾加一行专属说明
static func _proj_note(note: String, p: Dictionary) -> String:
	var style := " size=18 color=rgba(255,255,255,1) line=false align=0"
	var m := RegEx.create_from_string("<pos=APs text=[^>]*?( size=[^>]*)>").search(note)
	if m != null:
		style = m.get_string(1)
	for key in p.get("header", {}):
		note = RegEx.create_from_string("<pos=APs text=%s:[^>]*?( size=[^>]*)>" % str(key)).sub(note, "<pos=APs text=%s:%s$1>" % [key, p.header[key]], true)
	var rx := RegEx.create_from_string("<pos=APs text=\\\\c\\[1\\]伤害[：:][^>]*?(?= size=)")
	var mult := int(p.get("mult", 1))
	var out := ""
	var pos := 0
	for hit in rx.search_all(note):
		out += note.substr(pos, hit.get_start() - pos)
		var line := hit.get_string()
		for k in p.get("stat_swap", {}):
			line = line.replace(str(STAT_NAMES.get(str(k), k)), str(STAT_NAMES.get(str(p.stat_swap[k]), p.stat_swap[k])))
		for w in p.get("text", {}):
			line = line.replace(str(w), str(p.text[w]))
		if mult != 1:
			line = _mult_line(line, mult)
		out += line
		pos = hit.get_end()
	note = out + note.substr(pos)
	var extra := str(p.get("line", ""))
	if extra != "":
		note += "\n<pos=APs text=\\c[1]%s%s>" % [extra, style]
	return note


## 「×数」乘整数倍（×40% → ×80%，×1 → ×2）；「+1%」这类加成不动
static func _mult_line(line: String, mult: int) -> String:
	var rx := RegEx.create_from_string("×(\\d+(?:\\.\\d+)?)")
	var out := ""
	var pos := 0
	for hit in rx.search_all(line):
		out += line.substr(pos, hit.get_start() - pos)
		var n := float(hit.get_string(1)) * mult
		out += "×" + (str(int(n)) if n == floorf(n) else str(snappedf(n, 0.01)))
		pos = hit.get_end()
	return out + line.substr(pos)


# ---- 掉落（接口；还没接进掉落，见文件头第六条） ----

## 这件兵器能出哪些专属：开着的条目里，本人在队（含助力位）、是弱者、能装这件
static func drop_candidates(item: Dictionary, s: XState) -> Array:
	var out := []
	if not on(s) or item.is_empty() or str(item.get("kind", "")) != "weapon":
		return out
	var keys: Array = data().get("entries", {}).keys() + test_entries.keys()
	keys.sort()
	for k in keys:
		if out.has(k) or not enabled(k):
			continue
		var id := int(entry(k).get("actor", 0))
		if id <= 0 or not s.party.has(id) or not XTier.is_weak(id):
			continue
		var a: XActor = s.actor(id)
		if a != null and a.can_equip(item):
			out.append(k)
	return out


## 掷专属：池空不掷（不动任何随机）、返回 ""；否则走这件装备自己的流（XTianqiRandom.item_roll，读档不变、不挪别的抽样）
static func roll_drop(item: Dictionary, s: XState) -> String:
	var pool := drop_candidates(item, s)
	if pool.is_empty():
		return ""
	var r := XTianqiRandom.item_roll(s, item, "weak_exclusive")
	if float(r.call()) >= float(rules().get("drop_rate", 0.3)):  # 待基础数值标定（D65 暂测 30%）
		return ""
	var k: String = pool[mini(pool.size() - 1, int(float(r.call()) * pool.size()))]
	item[ITEM_KEY] = {"key": k}
	return k
