extends Node
## 【cc·白龙·未经审查】tusu7 屠苏的界面：战斗指令窗（installNativeTusuRuntime.js 第 230～285 行的 addSkillCommands／makeCommandList／
## Window_BattleSkill.includes 包装）与器谱（第 627～663 行 forgeRows／setKairen／forgeMenu）。行文、次序照原版代码逐字比。
## 队伍 [1, 8, 176, 10]，屠苏 60 级，打 3 号敌群。
const TUSU := 176
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(1200))


func _ready() -> void:
	_go.call_deferred()


func _state() -> XState:
	var s := XState.new_game(2, 1, [8, 10])
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	XTusuXuan.recruit(s, TUSU)
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 8, TUSU, 10]:
		s.add_actor(id)
	s.actor(TUSU).change_level_mv(60)
	for id in [1, 8, TUSU, 10]:
		s.actor(id).refresh_passive()
		s.actor(id).recover_all()
	return s


func _keys(rows: Array) -> Array:
	return rows.map(func(e): return [str(e.key), str(e.text), e.get("enabled", true) != false])


func _battle_ui() -> void:
	var s := _state()
	var b := XBattleScene.new()
	var l := b.logic
	l.setup(3, s, XBattleRandom.create("0000000000000176"))
	l.start_turn()
	var t: XActor = s.actor(TUSU)
	var h: XActor = s.actor(1)
	var terms: Array = XDB.system().terms.commands
	# 人形：原样（防御不改名、没有武相支援）
	var keys := _keys(b._command_entries(t)).map(func(r): return r[0])
	check("human.no_support", not keys.has("tusuSupport") and keys.has("guard"), keys)
	check("human.guard_name", b._command_entries(t).filter(func(e): return e.key == "guard")[0].text == str(terms[3]))
	# 化武剑给 1 号
	l.act(t, XDB.rec("Skills", XTusu.skill_id("huawu.sword")), h)
	var rows := _keys(b._command_entries(t))
	var jianqi := XDB.rec("Skills", XTusu.skill_id("support.jianqi"))
	check("bound.rows", rows.map(func(r): return r[0]) == ["attack", "tusuSupport", "stype:1", "guard", "item", "escape"], rows)
	check("bound.support_name", rows[1][1] == str(jianqi.name), rows[1])
	check("bound.support_enabled", rows[1][2] == (l.can_use(t, jianqi) and l.can_move(t)), rows[1])
	check("bound.yiwu_name", rows[2][1] == "易武", rows[2])
	check("bound.guard_name", rows[3][1] == "待命", rows[3])
	# 易武栏只列易武（易武不设等级门槛；当前武相那一项列出但用不了），别的专属技能、器谱都不列
	var listed := l.battle_skills(t).filter(func(x): return XTusu.battle_listed(t, x, 1)).map(func(x): return XTusu.key_of(x))
	check("bound.list", listed == ["yiwu.sword", "yiwu.bow", "yiwu.shield", "yiwu.book", "yiwu.hammer"], listed)
	# 支援不能用（没魔法）：灰显
	var mp: float = t.mp
	var hmp: float = h.mp
	t.mp = 0.0
	h.mp = 0.0
	check("bound.support_disabled", not _keys(b._command_entries(t))[1][2], _keys(b._command_entries(t))[1])
	t.mp = mp
	h.mp = hmp
	# 持武者：技能栏不重复，不插支援、防御不改名
	var hk := _keys(b._command_entries(h)).map(func(r): return r[0])
	var st := hk.filter(func(k): return str(k).begins_with("stype:"))
	var uniq := {}
	for k in st:
		uniq[k] = true
	check("host.dedupe", st.size() == uniq.size() and st.size() > 0, hk)
	check("host.plain", not hk.has("tusuSupport"), hk)
	# 别的队员不受影响
	var ok := _keys(b._command_entries(s.actor(8)))
	check("other.plain", not ok.map(func(r): return r[0]).has("tusuSupport") and ok.filter(func(r): return r[0] == "guard")[0][1] == str(terms[3]), ok)
	# XTusu.command_entries 的去重本身（持武者）：重复的 stype 只留第一个
	var dup := XTusu.command_entries(l, h, [{"key": "attack", "text": "a"}, {"key": "stype:1", "text": "x"}, {"key": "stype:1", "text": "x"}, {"key": "guard", "text": "g"}])
	check("host.dedupe_fn", dup.map(func(e): return e.key) == ["attack", "stype:1", "guard"], dup)
	l.end_battle(0)
	b.free()


func _forge() -> void:
	var s := _state()
	var page := XTusuForge.new()
	s.actor_advance[TUSU] = 1
	add_child(page)
	var info0 := XOrbShop.wrap_info([XTusu.FORGE_NAMES.forgeInfo])
	var home: Dictionary = page.log[-1]
	check("forge.home", home.rows == [{"label": "第1道铭文：未开刃", "enabled": true}, {"label": "（未开放）第2道铭文：未开刃", "enabled": false},
		{"label": "（未开放）第3道铭文：未开刃", "enabled": false}], home.rows)
	check("forge.home_info", home.info == info0, home.info)
	# 选第 1 道 → 五相
	page.choice._ok.call(page.choice.rows[0])
	var wp: Dictionary = page.log[-1]
	check("forge.pick_info", wp.info == XOrbShop.wrap_info(["第1道铭文：选择开刃的武相"]), wp.info)
	check("forge.pick_rows", wp.rows.map(func(r): return r.label) == ["开刃·剑　剑气纵横附带群体破防", "开刃·弓　贯日击杀目标时返还锁定",
		"开刃·盾　霸体回合主动施放金汤时，护盾量额外提高20%", "开刃·书　和鸣增幅一次治疗或护盾法术；仍支付支援费用", "开刃·锤　挫势可叠到2层"], wp.rows)
	page.choice._ok.call(page.choice.rows[1])  # 开刃·弓
	check("forge.set", XTusu.kairen(s) == ["bow"], XTusu.kairen(s))
	check("forge.back_home", page.log[-1].rows[0].label == "第1道铭文：开刃·弓", page.log[-1].rows)
	check("forge.learned", s.actor(TUSU).skill_ids.has(XTusu.skill_id("kairen.bow")))
	# 进阶 2 次：第 2 道开放；弓已开在第 1 道，第 2 道里灰显
	s.actor_advance[TUSU] = 2
	page.home()
	page.choice._ok.call(page.choice.rows[1])
	check("forge.taken", page.log[-1].rows.map(func(r): return r.enabled) == [true, false, true, true, true], page.log[-1].rows)
	page.choice._cancel.call()
	check("forge.cancel_home", page.log[-1].rows.size() == 3 and page.log[-1].rows[1].label == "第2道铭文：未开刃", page.log[-1].rows)
	# 重新开刃第 1 道（弓→剑）：碎片不够不换，够了扣 10
	page.choice._ok.call(page.choice.rows[0])
	page.choice._ok.call(page.choice.rows[0])
	check("forge.reforge_short", XTusu.kairen(s) == ["bow"], XTusu.kairen(s))
	s.gain_item(XTusu.REFORGE_ITEM, 12)
	page.choice._ok.call(page.choice.rows[0])
	page.choice._ok.call(page.choice.rows[0])
	check("forge.reforge", XTusu.kairen(s) == ["sword"] and s.item_count(XTusu.REFORGE_ITEM) == 2, [XTusu.kairen(s), s.item_count(XTusu.REFORGE_ITEM)])
	# 首页取消关页
	var closed := [false]
	page.closed.connect(func(): closed[0] = true)
	page.choice._cancel.call()
	check("forge.close", closed[0])
	page.queue_free()


func _go() -> void:
	_battle_ui()
	_forge()
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_tusu_ui", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
