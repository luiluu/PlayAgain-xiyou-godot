extends Node
## 【cc·白龙_11·未经审查】云裳天衣铺一期（XYunshangShop：首页与配置天衣神纹）：照参照 p7.shop（yunshang_probe 拿原版 Scene_Yunshang 逐页量的
## Window_YunChoices 说明行与各行），用按键走同一串操作——首页、选队员、空袖藏星选借用技能（中途取消不改）、九曲回针选针眼、
## 七曜流霞选元素、寸光留仙无需配置、选队员时取消、返回；每页比说明行、各行文字与能不能选，选完比设置。
## 再存档→清掉内存里的设置→读档：设置按天衣带回来（JSON 读回是浮点），读档后空袖藏星的借用技能照样出现在云裳的技能里。
## 针眼照原版全列时（XYunshang.o_eye_cooldown = false）比参照；默认（O-待定）只列有冷却的，比参照里有冷却的那几行。
## 【cc·白龙_12·未经审查】二期照参照 p8（XYunshangOrders，账本文件放测试目录）：
## - p8.craft／.r01：制作（装备随机数 0.5／0.1：选中的天衣、八项、插槽、品质）→读开工前的档（天丝照扣、订单还在）→进度 9／10 格→领取→
##   再读最早的档（天衣照发）；各步比首页、天丝、账本摘要。
## - p8.gates：34／35 级、进阶 0～2、有没有天丝时首页三行能不能选、Y.submit 的提示、制作池。
## - p8.progress／.bench：真战斗里每回合末记 1 格、同一回合不重记；云裳不在队伍不记。
## - p8.clear：不朽的未知战斗胜利给天丝（来源地图、Leviathan 来源、难度变量 107、unpaired、10280 偶数次多 1、逃跑与别的敌群不给、每场一次）。
## - p8.advance：进阶页按键走一遍云裳的进阶（条件不够的提示、选天衣页、取消、灰行、确认窗字、进阶后的碎片／天衣／技能／账本），再比两次进阶后的提示。
## - p8.fallback：本档的账本记录缺失时首页是兜底页，确定关页；Y.submit 的提示。
## - p9：图标格号（技能与天衣等走 HD 图集，32／128 两种大小、四边透明）、织神天梭说明（等级 1／5／888）、天衣说明的粉色与粉色窗口皮。
## - p8.lose.sell／.base：领取后穿上卸下（不记）、商店卖出（XItemMarks.sell，记移除）／按底子扣（s.gain_gear 负数，不记），再读领取前的档；
##   重制另比存进方桌仓库（XWarehouse.deposit＝原版 loseItem，同卖出）与星级仓库（直接改 _armors，同按底子扣）。
const FIXTURE := "res://tests/fixtures/yunshang_oracle.json"
var checks := 0
var failures: Array = []
var cases := {}


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		if failures.size() <= 20:
			print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	get_viewport().push_input(e)
	await frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	get_viewport().push_input(r)
	await frames(2)


func pick(i: int) -> void:
	for k in i:
		await press("ui_down")
	await press("ui_accept")
	await frames(2)


func page(shop: XYunshangShop):
	var w := shop.win
	if w == null or not is_instance_valid(w) or w.is_queued_for_deletion():
		return null
	return {"info": w.info.map(func(t): return str(t)), "rows": w.entries.map(func(e): return [str(e.text), bool(e.get("enabled", true))])}


## 比一页
func same_page(tag: String, got, want) -> void:
	if want == null or got == null:
		check(tag + ".page", got == null and want == null, [got, want])
		return
	var wr: Array = (want.rows as Array).map(func(r): return [str(r[0]), bool(r[1])])
	check(tag + ".info", got.info == (want.info as Array).map(func(t): return str(t)), [got.info, want.info])
	check(tag + ".rows", got.rows == wr, [got.rows, wr])


func same_setting(tag: String, got: Dictionary, want: Dictionary) -> void:
	var g := {"borrow": (got.borrow as Array).map(func(b): return [int(b.owner), int(b.skill)]), "eye": int(got.eye),
		"elements": (got.elements as Array).map(func(e): return int(e)), "element": int(got.element)}
	var w := {"borrow": (want.borrow as Array).map(func(b): return [int(b.owner), int(b.skill)]), "eye": int(want.eye),
		"elements": (want.elements as Array).map(func(e): return int(e)), "element": int(want.element)}
	check(tag + ".setting", g == w, [g, w])


func wear(s: XState, a: XActor, k: int) -> void:
	s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
	XEquipment.change(s, a, a.equip_slots().find(4), s.gear[s.gear.size() - 1])


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_yunshang_shop"
	XConfig.path_override = XSave.dir().path_join("options.json")
	XYunshangOrders.path_override = XSave.dir().path_join(XYunshangOrders.FILE)
	DirAccess.make_dir_recursive_absolute(XSave.dir())
	DirAccess.remove_absolute(XYunshangOrders.path_override)
	XYunshangOrders.reload()
	XStarWarehouse.path_override = XSave.dir().path_join("star_warehouse.json")
	DirAccess.remove_absolute(XStarWarehouse.path_override)
	XGear.force_roll = 0.5
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for c in ref.cases:
		cases[str(c.id)] = c.observed
	var want := {}
	for c in ref.cases:
		if str(c.id) == "p7.shop":
			for st in c.observed.steps:
				want[str(st.tag)] = st
	check("oracle", want.size() == 15, want.keys())
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10, XYunshang.ACTOR]:
		s.add_actor(id)
	s.actor_advance[XYunshang.ACTOR] = 0
	var a := s.actor(XYunshang.ACTOR)
	a.change_level_mv(45)
	for id in [1, 8, 9]:
		s.actor(id).change_level_mv(55)
	var one := s.actor(1)
	var eight := s.actor(8)
	var nine := s.actor(9)
	wear(s, a, 6)
	wear(s, one, 7)
	wear(s, eight, 14)
	wear(s, nine, 9)
	XYunshang.o_eye_cooldown = false
	var shop := XYunshangShop.new()
	add_child(shop)
	await frames(3)
	var at := func(tag: String) -> void: same_page(tag, page(shop), want[tag].page)
	at.call("home")
	await pick(3)
	at.call("actors")
	await pick(3)
	at.call("borrow0")
	await pick(0)
	at.call("borrow1")
	await press("ui_cancel")
	at.call("borrowCancel")
	same_setting("borrowCancel", XYunshang.setting(a), want.borrowCancel.setting)
	await pick(3)
	await pick(3)
	await pick(0)
	await pick(0)
	at.call("borrow2")
	await pick(1)
	at.call("borrowed")
	same_setting("borrowed", XYunshang.setting(a), want.borrowed.setting)
	await pick(3)
	await pick(0)
	at.call("eye")
	await pick(1)
	at.call("eyed")
	same_setting("eyed", XYunshang.setting(one), want.eyed.setting)
	# O-待定 默认：针眼只列有冷却的。1 号这时会的四个都没有冷却，列表为空；再教他青龙斩（<Cooldown: 3>），只列它
	XYunshang.o_eye_cooldown = true
	var by_name := {}
	for sk in one.skills():
		by_name[str(sk.name)] = sk
	check("eye.cooldown.none", (want.eye.page.rows as Array).all(func(r): return by_name.has(str(r[0])) and not XYunshang.eye_candidate(by_name[str(r[0])])))
	one.learn_skill(322)
	shop.configure(one)
	await frames(2)
	var got_eye = page(shop)
	check("eye.cooldown.rows", got_eye != null and got_eye.rows == [["青龙斩", true]], got_eye)
	await press("ui_cancel")
	one.forget_skill(322)
	XYunshang.o_eye_cooldown = false
	await pick(3)
	await pick(1)
	at.call("element0")
	await pick(2)
	at.call("element1")
	await pick(0)
	await pick(0)
	at.call("elemented")
	same_setting("elemented", XYunshang.setting(eight), want.elemented.setting)
	XToast.shown.clear()
	await pick(3)
	await pick(2)
	at.call("plain")
	check("plain.toast", XToast.shown.has("这件天衣无需战前配置"), XToast.shown)
	same_setting("plain", XYunshang.setting(nine), want.plain.setting)
	await pick(3)
	await press("ui_cancel")
	at.call("actorsCancel")
	var closed := [false]
	shop.closed.connect(func(): closed[0] = true)
	await pick(4)
	check("back.closed", closed[0])
	shop.queue_free()
	XYunshang.o_eye_cooldown = true
	await save_load(s)
	for roll in [0.5, 0.1]:
		await p8_craft(roll)
	await p8_gates()
	p8_progress(true)
	p8_progress(false)
	p8_clear()
	await p8_advance()
	await p8_fallback()
	for how in ["sell", "base", "warehouse", "star"]:
		p8_lose(how)
	p9_display()
	XGear.force_roll = -1.0
	finish()


## 存档→清掉设置→读档：三件天衣的设置都回来；空袖藏星没醒取第一个借用技能（1 号的万剑诀），读档后照样在云裳的技能里
func save_load(s: XState) -> void:
	var before = JSON.parse_string(JSON.stringify(s.flags.get(XYunshang.SETTINGS_FLAG, {})))
	check("save", XSave.save(1))
	s.flags.erase(XYunshang.SETTINGS_FLAG)
	check("load", XSave.load_slot(1))
	var t := XState.current
	check("load.settings", JSON.stringify(t.flags.get(XYunshang.SETTINGS_FLAG, {})) == JSON.stringify(before), [t.flags.get(XYunshang.SETTINGS_FLAG), before])
	var a := t.actor(XYunshang.ACTOR)
	check("load.borrow_type", int(XYunshang.setting(a).borrow[0].skill) == 160 and XYunshang.key(a) == 6, XYunshang.setting(a))
	check("load.borrowed_skill", a.skills().any(func(sk): return int(sk.id) == 160), a.skills().map(func(sk): return int(sk.id)))
	check("load.eye", int(XYunshang.setting(t.actor(1)).eye) == 311, XYunshang.setting(t.actor(1)))


# ---- 二期（p8）----
const SILK := 2942
const SHARD := 2530


## JSON 读回的整数是浮点：整数值的浮点一律转成整数再比
func norm(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		return v.map(func(x): return norm(x))
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = norm(v[k])
		return o
	return v


func same(tag: String, got, want) -> void:
	check(tag, JSON.stringify(norm(got)) == JSON.stringify(norm(want)), [norm(got), norm(want)])


## 同参照 newGame＋grow＋addActor：队伍 1、8、9、10，云裳 level 级进阶 0 排在最后；地图 4
func new_cloud(level: int) -> XState:
	var s := XState.new_game_blank()
	s.actor_max_level = 99
	s.switches[2494] = true
	s.map_id = 4
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, 9, 10, XYunshang.ACTOR]:
		s.add_actor(id)
	s.actor(XYunshang.ACTOR).change_level_mv(level)
	return s


## 参照 setStage：改账本里的进阶次数再重放
func set_stage(s: XState, n: int) -> void:
	XYunshangOrders.transaction(s, func(p): p.stage = n)


func ledger_sum(s: XState):
	var p = XYunshangOrders.ledger(s)
	if p == null:
		return null
	var o = p.order
	return {"journal": (p.journal as Array).map(func(j): return ["delta", j.item, j.delta] if j.has("delta") else ["grant", str(j.grant.name)] if j.has("grant") else ["remove"]),
		"order": {"name": str(o.spec.name), "progress": o.progress, "tokens": (o.roundTokens as Array).size()} if o != null else null,
		"clears": p.clears, "bonusClears": p.get("bonusClears", 0), "stage": p.stage}


func spec_sum(sp: Dictionary) -> Dictionary:
	return {"name": str(sp.name), "base": sp.base, "params": sp.params, "traits": (sp.traits as Array).map(func(t): return [t.code, t.dataId, t.value]),
		"prefix": "" if (sp.affixIds as Array).is_empty() else str(sp.affixIds), "suffix": "", "slots": sp.upgradeSlots,
		"quality": str(sp.meta.quality), "ici": str(sp.meta.ici), "variance": sp.meta.get("Random Variance")}


func robes(s: XState) -> Array:
	return XYunshangOrders.owned(s).map(func(e): return [str(e.name), int(e.base)])


func steps_of(id: String) -> Dictionary:
	var out := {}
	for st in cases[id].steps:
		out[str(st.tag)] = st
	return out


## 首页、天丝、账本摘要（还有 extra 里各项）
func shop_step(id: String, w: Dictionary, tag: String, shop: XYunshangShop, extra := {}) -> void:
	var want: Dictionary = w[tag]
	var s := XState.current
	same_page("%s.%s" % [id, tag], page(shop), want.page)
	same("%s.%s.silk" % [id, tag], s.item_count(SILK), want.silk)
	same("%s.%s.ledger" % [id, tag], ledger_sum(s), want.ledger)
	for k in extra:
		same("%s.%s.%s" % [id, tag, k], extra[k], want[k])


## 制作→读开工前的档→进度→领取→再读最早的档
func p8_craft(roll: float) -> void:
	var id := "p8.craft" if roll == 0.5 else "p8.craft.r01"
	var w := steps_of(id)
	var s := new_cloud(45)
	s.gain_item(SILK, 20)
	var shop := XYunshangShop.new()
	add_child(shop)
	await frames(3)
	shop_step(id, w, "home", shop)
	check(id + ".save", XSave.save(2))
	XGear.force_roll = roll
	XGear.reset_pool()
	await pick(0)
	XGear.force_roll = 0.5
	var o = XYunshangOrders.order(XState.current)
	shop_step(id, w, "submitted", shop, {"spec": spec_sum(o.spec) if o != null else null})
	same(id + ".errors", {"again": XYunshangOrders.submit(XState.current), "claim": XYunshangOrders.claim(XState.current)},
		{"again": w.errors.again, "claim": w.errors.claim})
	check(id + ".load", XSave.load_slot(2))
	shop.home()
	await frames(2)
	shop_step(id, w, "reloaded", shop, {"seq": XState.current.flags.get(XYunshangOrders.SEQ_FLAG)})
	var tokens := []
	for i in 9:
		tokens.append(XYunshangOrders.progress(XState.current, "t%d" % i))
	tokens.append(XYunshangOrders.progress(XState.current, "t3"))
	shop.home()
	await frames(2)
	shop_step(id, w, "nine", shop, {"tokens": tokens})
	same(id + ".early", XYunshangOrders.claim(XState.current), w.early.claim)
	tokens.append(XYunshangOrders.progress(XState.current, "t9"))
	tokens.append(XYunshangOrders.progress(XState.current, "t10"))
	shop.home()
	await frames(2)
	shop_step(id, w, "ten", shop, {"tokens": tokens})
	await pick(1)
	shop_step(id, w, "claimed", shop, {"robes": robes(XState.current), "uid": XState.current.gear.any(func(e): return str(e.get("_yunUid", "")) != "")})
	check(id + ".load2", XSave.load_slot(2))
	shop.home()
	await frames(2)
	shop_step(id, w, "reloadedClaimed", shop, {"robes": robes(XState.current), "seq": XState.current.flags.get(XYunshangOrders.SEQ_FLAG)})
	shop.queue_free()
	await frames(2)


func p8_gates() -> void:
	var i := 0
	for want in cases["p8.gates"].out:
		var tag := "p8.gates%d" % i
		i += 1
		var s := new_cloud(int(want.level))
		set_stage(s, int(want.stage))
		if int(want.silk) > 0:
			s.gain_item(SILK, int(want.silk))
		var shop := XYunshangShop.new()
		add_child(shop)
		await frames(3)
		same_page(tag, page(shop), want.page)
		var why := XYunshangOrders.submit(s)
		var o = XYunshangOrders.order(s)
		same(tag + ".submit", why if why != "" else "ok:" + str(o.spec.name), want.submit)
		same(tag + ".pool", XYunshangOrders.pool(s.actor(XYunshang.ACTOR)).map(func(r): return r[1]), want.pool)
		shop.queue_free()
		await frames(2)


func _logic(s: XState, troop: int) -> XBattleLogic:
	var logic := XBattleLogic.new()
	logic.setup(troop, s, XBattleRandom.create("0000000000000174"))
	return logic


## 每回合末记 1 格，同一回合不重记；云裳不在队伍不记
func p8_progress(in_party: bool) -> void:
	var id := "p8.progress" if in_party else "p8.progress.bench"
	var s := new_cloud(45)
	s.gain_item(SILK, 15)
	check(id + ".submit", XYunshangOrders.submit(s) == "")
	if not in_party:
		s.remove_actor(XYunshang.ACTOR)
	var logic := _logic(s, 3)
	logic.start_turn()
	var out := []
	logic.end_turn()
	out.append(XYunshangOrders.order(s).progress)
	logic.end_turn()
	out.append(XYunshangOrders.order(s).progress)
	logic.start_turn()
	logic.end_turn()
	out.append(XYunshangOrders.order(s).progress)
	logic.end_battle(-1)
	same(id, out, cases[id].out)


## 不朽的未知战斗胜利给天丝
func p8_clear() -> void:
	var i := 0
	for want in cases["p8.clear"].out:
		var tag := "p8.clear%d" % i
		i += 1
		var s := new_cloud(45)
		set_stage(s, int(want.get("stage", 1)))
		if bool(want.get("bench", false)):
			s.remove_actor(XYunshang.ACTOR)
		if want.has("var107"):
			s.variables[107] = int(want.var107)
		var from := int(want.from)
		if from != 0:
			XYunshangOrders.on_map_setup(s, s.map_id, from)
			s.map_id = from
		XYunshangOrders.on_map_setup(s, s.map_id, int(want.to))
		s.map_id = int(want.to)
		if want.has("leviathan"):
			s.flags.erase(XYunshangOrders.ORIGIN_FLAG)
			s.unknown_origin = int(want.leviathan) if want.leviathan != null else null
		var got := []
		for r in int(want.get("runs", 1)):
			var logic := _logic(s, int(want.troop))
			logic.end_battle(int(want.result))
			XYunshang.end_battle(logic, int(want.result))  # 同一场再收一次 endBattle：不重发
			got.append(s.item_count(SILK))
		same(tag + ".got", got, want.got)
		same(tag + ".origin", s.flags.get(XYunshangOrders.ORIGIN_FLAG), want.origin)
		same(tag + ".ledger", ledger_sum(s), want.ledger)


## 进阶页按键走云裳的进阶
func p8_advance() -> void:
	var w := steps_of("p8.advance")
	var s := new_cloud(34)
	var a := s.actor(XYunshang.ACTOR)
	var adv := XActorAdvancedScene.new()
	add_child(adv)
	await frames(3)
	adv._select(adv.members.find(a))
	await frames(2)
	XToast.shown.clear()
	var bottom := func() -> void:
		await press("ui_accept")
		await press("ui_accept")
	var at := func(tag: String, extra := {}) -> void:
		var want: Dictionary = w[tag]
		var yw := adv.yun_win
		var pg = {"info": [], "rows": yw.entries.map(func(e): return [str(e.text), bool(e.get("enabled", true))])} if yw != null and is_instance_valid(yw) else null
		same("p8.advance.%s.page" % tag, pg, want.page)
		same("p8.advance.%s.toasts" % tag, XToast.shown.duplicate(), want.toasts)
		XToast.shown.clear()
		if want.confirm != null:
			same("p8.advance.%s.confirm" % tag, adv.confirm_text, want.confirm)
		same("p8.advance.%s.index" % tag, adv.mode == "list", want.index)
		same("p8.advance.%s.stage" % tag, XYunshang.stage(a), want.stage)
		same("p8.advance.%s.shards" % tag, s.item_count(SHARD), want.shards)
		same("p8.advance.%s.robes" % tag, robes(s), want.robes)
		for k in extra:
			same("p8.advance.%s.%s" % [tag, k], extra[k], want[k])
	await bottom.call()
	at.call("level")
	a.change_level_mv(35)
	await bottom.call()
	at.call("shards")
	s.gain_item(SHARD, 60)
	s.gain_gear("armor", XYunshang.ROBE_FIRST, 1)
	XEquipment.change(s, a, a.equip_slots().find(4), s.gear[s.gear.size() - 1])
	for k in [3, 1]:
		s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
	await bottom.call()
	at.call("robes", {"reason": XYunshangOrders.requirements(s, a)})
	for k in [2, 1]:
		s.gain_gear("armor", XYunshang.ROBE_FIRST + k, 1)
	await bottom.call()
	at.call("pick0", {"reason": XYunshangOrders.requirements(s, a)})
	await pick(2)
	at.call("pick1")
	await press("ui_cancel")
	at.call("pickCancel", {"selection": adv.yun_selection != null})
	await bottom.call()
	await pick(0)
	at.call("pickDisabled")
	await pick(1)
	await pick(1)
	at.call("pick2")
	await pick(2)
	at.call("picked", {"selection": (adv.yun_selection.items as Array).map(func(e): return str(e.name)) if adv.yun_selection != null else null})
	await press("ui_accept")
	at.call("advanced", {"skills": (a.skill_ids as Array).filter(func(k): return k >= 10270 and k <= 10287).map(func(k): return int(k)), "ledger": ledger_sum(s),
		"equipped": not XYunshang.robe(a).is_empty()})
	await bottom.call()
	at.call("again", {"reason": XYunshangOrders.requirements(s, a)})
	a.change_level_mv(50)
	await bottom.call()
	at.call("again50", {"reason": XYunshangOrders.requirements(s, a)})
	set_stage(s, 2)
	same("p8.advance.done.reason", XYunshangOrders.requirements(s, a), w.done.reason)
	same("p8.advance.done.stage", XYunshang.stage(a), w.done.stage)
	var count := XYunshangOrders.advance(s, [])
	set_stage(s, 1)
	a.change_level_mv(40)
	same("p8.advance.errors", {"count": count, "level": XYunshangOrders.advance(s, [])}, {"count": w.errors.count, "level": w.errors.level})
	adv.queue_free()
	await frames(2)


## 账本缺了本档的记录：兜底页，确定关页
func p8_fallback() -> void:
	var want: Dictionary = cases["p8.fallback"]
	var s := new_cloud(45)
	s.flags[XYunshangOrders.PROFILE_FLAG] = "missing-profile"
	var shop := XYunshangShop.new()
	add_child(shop)
	await frames(3)
	same_page("p8.fallback", page(shop), want.page)
	var closed := [false]
	shop.closed.connect(func(): closed[0] = true)
	await pick(1)
	check("p8.fallback.closed", closed[0] == bool(want.popped))
	same("p8.fallback.submit", XYunshangOrders.submit(s), want.submit)
	shop.queue_free()
	await frames(2)



## 领取的天衣离开背包：直接失去这一件记移除（读领取前的档不再发），交换与按底子扣不记
func p8_lose(how: String) -> void:
	var id := "p8.lose." + ("sell" if how in ["sell", "warehouse"] else "base")
	var w := steps_of(id)
	var s := new_cloud(45)
	s.gain_item(SILK, 15)
	check(id + "." + how + ".submit", XYunshangOrders.submit(s) == "")
	for i in 10:
		XYunshangOrders.progress(s, "t%d" % i)
	check(id + "." + how + ".save", XSave.save(3))
	check(id + "." + how + ".claim", XYunshangOrders.claim(s) == "")
	var a := s.actor(XYunshang.ACTOR)
	var at := func(tag: String, extra := {}) -> void:
		var t := XState.current
		var b := t.actor(XYunshang.ACTOR)
		var want: Dictionary = w[tag]
		var r := XYunshang.robe(b)
		same("%s.%s.%s.robes" % [id, how, tag], robes(t), want.robes)
		same("%s.%s.%s.equipped" % [id, how, tag], str(r.name) if not r.is_empty() else null, want.equipped)
		same("%s.%s.%s.ledger" % [id, how, tag], ledger_sum(t), want.ledger)
		for k in extra:
			same("%s.%s.%s.%s" % [id, how, tag, k], extra[k], want[k])
	at.call("claimed")
	var item = func(): return s.gear.filter(func(e): return str(e.get("_yunUid", "")) != "")[0]
	var slot := a.equip_slots().find(4)
	XEquipment.change(s, a, slot, item.call())
	at.call("worn")
	XEquipment.change(s, a, slot, null)
	at.call("unworn")
	var robe: Dictionary = item.call()
	match how:
		"sell":
			XItemMarks.sell(s, robe)
		"base":
			s.gain_gear("armor", int(robe.base), -1)
		"warehouse":
			XWarehouse.create(s, "<仓库:999>")
			check(id + ".warehouse.deposit", XWarehouse.deposit(s, "armor", robe))
			check(id + ".warehouse.stored", XWarehouse.stored(s, "armor").any(func(e): return is_same(e, robe) or (e is Dictionary and e.get("rec") is Dictionary and is_same(e.rec, robe))), XWarehouse.stored(s, "armor"))
		"star":
			check(id + ".star.deposit", XStarWarehouse.deposit_gear(s, robe) == "")
	at.call("lost")
	check(id + "." + how + ".load", XSave.load_slot(3))
	at.call("reloaded", {"seq": XState.current.flags.get(XYunshangOrders.SEQ_FLAG)})



## 显示：图标、织神天梭说明、天衣粉色
func p9_display() -> void:
	for pair in cases["p9.icons"].out:
		var want := int(pair[1]) if pair[1] != null else -1
		same("p9.icons.%d" % int(pair[0]), XYunshang.icon_slot(int(pair[0])), want)
	var t := XUI.icon_texture(130270)
	check("p9.icons.texture32", t != null and t.get_size() == Vector2(32, 32), t)
	var big := XItemStatusPainter.large_icon(210118)
	check("p9.icons.texture128", big != null and big.get_size() == Vector2(128, 128), big)
	var img := XYunshang.icon_image(210118)
	check("p9.icons.pad", img != null and img.get_pixel(2, 2).a8 == 0 and img.get_pixel(125, 125).a8 == 0 and img.get_pixel(64, 64).a8 > 0)
	# 缩放：128 图里不透明的范围＝原格不透明的范围 ×112/格宽、再移 8（±1）
	var atlas: Image = (load(XDB.img_path("system", XYunshang.ICON_ATLAS)) as Texture2D).get_image()
	atlas.decompress()
	var cell := atlas.get_width() / 6.0
	var src_box := atlas.get_region(Rect2i(0, roundi(3 * cell), roundi(cell), roundi(cell))).get_used_rect()
	var box := img.get_used_rect()
	var k := 112.0 / roundi(cell)
	check("p9.icons.scale", absf(box.position.x - (8 + src_box.position.x * k)) <= 1.5 and absf(box.end.x - (8 + src_box.end.x * k)) <= 1.5
		and absf(box.position.y - (8 + src_box.position.y * k)) <= 1.5, [box, src_box, cell])
	check("p9.icons.native", XUI.icon_texture(100) != null and XUI.icon_texture(100).atlas.resource_path.contains("IconSet_1"))
	var s := new_cloud(45)
	var i := 0
	for want in cases["p9.relicHelp"].out:
		s.gain_gear("armor", XYunshang.RELIC, 1)
		var r: Dictionary = s.gear[s.gear.size() - 1]
		r.level = int(want.level)
		r.exp = int(want.exp)
		same("p9.relicHelp%d" % i, XHelpCard.desc_params(r, 2).map(func(x): return [x[0], x[1], x[2]]), want.rows)
		i += 1
	for want in cases["p9.robeHelp"].out:
		s.gain_gear("armor", int(want.id), 1)
		var r: Dictionary = s.gear[s.gear.size() - 1]
		same("p9.robeHelp%d.rows" % int(want.id), XHelpCard.desc_params(r, 2).map(func(x): return [x[0], x[1], x[2]]), want.rows)
		same("p9.robeHelp%d.color" % int(want.id), XQuality.color_text(r), want.normal)
		var card := XHelpCard.new()
		add_child(card)
		card.show_for(r, "armor")
		check("p9.robeHelp%d.skin" % int(want.id), card.robe_card)
		card.queue_free()
	var relic := XDB.rec("Armors", XYunshang.RELIC)
	check("p9.relic.not_pink", XQuality.color_text(relic) != XYunshang.ROBE_COLOR and not XYunshang.is_robe(relic) and not XYunshang.is_robe(XDB.rec("Skills", 7920)))
	# 粉色窗口皮：每个不透明像素＝粉色×(0.18＋0.82×亮度)
	var path := XDB.img_path("system", "Window12")
	var src: Image = (load(path) as Texture2D).get_image()
	src.decompress()
	var tinted: Image = XYunshang.robe_skin(path).get_image()
	var c := src.get_pixel(40, 40)
	var shade := 0.18 + 0.82 * (c.r8 * 0.2126 + c.g8 * 0.7152 + c.b8 * 0.0722) / 255.0
	var g := tinted.get_pixel(40, 40)
	check("p9.skin", c.a8 == 0 or (g.r8 == roundi(255 * shade) and g.g8 == roundi(169 * shade) and g.b8 == roundi(202 * shade) and g.a8 == c.a8), [c, g])


func finish() -> void:
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_yunshang_shop", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
