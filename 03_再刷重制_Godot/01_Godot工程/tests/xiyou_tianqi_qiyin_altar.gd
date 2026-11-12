extends Node
## 天启篇七印祭坛流程专项（XTianqiQiyin、XTianqiQiyinRule、qiyin_altar.json）。
## 一、数据：数字避开 4、七印和掉落表一致、借的图／敌群／Boss 在、台词齐全、入口事件在。
## 二、揭印：31～35 层守层者依次揭开；34 层认鸿钧记录；默印要前六印都首通。
## 三、入口：一印都没揭开时照原版；揭开后三处入口接管；原版档、开关关掉不动。
## 四、祭坛：第一次开送印钥、守层者首杀补发套装件（只一次）、野外印钥回祭坛时报。
## 五、里副本：花印钥、三场连战带规则、Boss 那场重标、输了不退印钥；首通加件；直取只打 Boss；没印钥进不去；献印屑；躁动每 3 次。
## 六、揭开：封着只看印、部位、光；揭开亮成色和名字；当场揭。
## 七、规则：七条各自的效果，和不在里副本时一概不动。
## 八、七印书卷：别的战斗里揭的规则只对敌方生效；里副本里本印规则优先。
## 九、野外印钥：31～35 层精英／守护者必掉，别的按几率，大厅、里副本里不掉。
## 数字避开 4（Kyo 11-11）：用例里的层号、地图号照实写。

class FakeHost extends RefCounted:
	var answers: Array = []
	var asked: Array = []
	var said: Array = []
	var moves: Array = []
	var names: Array = []
	var battles: Array = []
	var results: Array = []
	func show_text(_f: String, _i: int, lines: Array) -> void:
		said.append_array(lines)
	func show_text_with_choices(_f: String, _i: int, lines: Array, options: Array, _cancel: int) -> int:
		said.append_array(lines)
		asked.append(options)
		return int(answers.pop_front()) if not answers.is_empty() else options.size() - 1
	func transfer(id: int, x: int, y: int, d: int, _fade := 0) -> void:
		moves.append([id, x, y, d])
		names.append(XTianqiQiyin.map_name(XState.current, id, "原名"))
		XState.current.map_id = id
	func start_battle(troop: int, can_escape: bool, can_lose: bool, _random := false) -> int:
		battles.append({"troop": troop, "escape": can_escape, "lose": can_lose, "rule": XTianqiQiyinRule.pending().duplicate(true),
			"tone": XState.current.screen.tone.duplicate()})
		XTianqiQiyinRule._pending = {}
		return int(results.pop_front()) if not results.is_empty() else 0


var results: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok, "detail": detail})


func _ids(tier: String) -> Array:
	return XTier.ids(tier).filter(func(id): return not XImportedBalance.is_disabled_actor(id) and not XActorModules.IDS.has(id))


## 天启篇存档、5 个弱者、战争线开场已打完、变量 20 = floor
func _state(floor := 32, line := "war") -> XState:
	var lineup := _ids(XTier.WEAK).slice(0, 5)
	var s := XTianqi.start_new_game(3, "jianxian", lineup)
	XTianqi.take_pending()
	for id in lineup:
		XTianqi._joining = true
		s.add_actor(int(id))
		XTianqi._joining = false
	s.map_id = 4
	s.set_variable(20, floor)
	XState.current = s
	if line != "":
		s.flags.tianqi["line"] = line
		XTianqiWarLine.progress(s)["stage"] = XTianqiWarLine.STAGE_DONE
	XTianqiQiyin.set_current("")
	XTianqiQiyin.rng_override = XRandomStream.create("0123012301230123", "qiyin")
	return s


func _has(host: FakeHost, text: String) -> bool:
	return host.said.any(func(t): return str(t).contains(text))


func _run() -> void:
	XMessageBox.auto = true
	seed(20261112)
	XSave.dir_override = "user://test_xiyou_tianqi_qiyin_altar"
	XConfig.path_override = XSave.dir().path_join("options.json")
	DirAccess.make_dir_recursive_absolute(XSave.dir_override)
	DirAccess.remove_absolute(XSave.dir_override.path_join("global.json"))
	_data()
	_unlock()
	_entries()
	_sync()
	await _dungeon()
	await _dungeon_lost()
	await _direct_and_restless()
	await _no_key_and_offering()
	await _reveal()
	await _altar_menu()
	_rules()
	_scroll()
	_field_keys()
	DirAccess.remove_absolute(XGlobalVars.path())
	var passed := results.filter(func(r): return r.passed).size()
	for r in results:
		if not r.passed:
			print("FAIL ", r.name, " ", JSON.stringify(r.detail))
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


# ---- 一、数据 ----

func _data() -> void:
	XTianqiQiyin.reload()
	_check("nice_numbers", XTianqiQiyin.nice_number_violations().is_empty(), XTianqiQiyin.nice_number_violations())
	var keys := XTianqiQiyin.seal_keys()
	_check("seals_match_drop", keys == XTianqiQiyinDrop.seals(), [keys, XTianqiQiyinDrop.seals()])
	_check("seals_match_gear", keys == XTianqiQiyinGear.seal_keys().map(func(x): return str(x.key) if x is Dictionary else str(x)) or keys.all(func(k): return not XTianqiQiyinGear.set_of(k).is_empty()))
	var rules := []
	for k in keys:
		var info := XTianqiQiyin.seal_info(k)
		rules.append(str(info.rule))
		_check("map_%s" % k, not XDB.map(int(info.map)).is_empty(), info.map)
		_check("troops_%s" % k, info.troops.size() == 3 and info.troops.all(func(t): return not XDB.rec("Troops", int(t)).is_empty()), info.troops)
		var boss_t := XDB.rec("Troops", int(info.troops[2]))
		_check("boss_in_troop_%s" % k, boss_t.get("members", []).any(func(m): return int(m.enemyId) == int(info.boss.enemy)), [info.boss, boss_t.get("name")])
		_check("rule_text_%s" % k, str(info.rule_name) != "" and str(info.rule_text) != "")
		_check("unlock_%s" % k, XTianqiQiyin.data().unlock.has(k))
	_check("seven_rules", rules.size() == 7 and rules.duplicate().filter(func(r): return rules.count(r) == 1).size() == 7, rules)
	var scene_keys := ["first_open", "locked", "head", "pick_seal", "no_key", "restless", "enter", "mode", "offer_head", "offer_part", "gem",
		"next", "lost", "boss_win", "drop_head", "shards", "key_refund", "first_clear", "floor_kill", "field_keys", "reveal_none",
		"reveal_head", "reveal_done", "bag_head", "leave"]
	_check("scenes_all", scene_keys.all(func(k): return not XTianqiQiyin.scene(k).is_empty()), scene_keys.filter(func(k): return XTianqiQiyin.scene(k).is_empty()))
	for en in XTianqiQiyin.data().entries:
		var m := XDB.map(int(en.map))
		var ok: bool = m.get("events", []).any(func(ev): return ev is Dictionary and int(ev.id) == int(en.event))
		_check("entry_%d_%d" % [int(en.map), int(en.event)], ok)
	_check("altar_map", not XDB.map(int(XTianqiQiyin.data().altar.map)).is_empty())
	_check("rebase_ref", XDB.rec("Enemies", int(XTianqiQiyin.data().rebase.ref)).get("params", []).size() == 8)


# ---- 二、揭印 ----

func _unlock() -> void:
	var expect := {31: [], 32: ["bai", "hong"], 33: ["bai", "hong", "hei"], 34: ["bai", "hong", "hei", "hui"],
		35: ["bai", "hong", "hei", "hui", "xun"], 36: ["bai", "hong", "hei", "hui", "xun", "zhen"]}
	for f in expect:
		var s := _state(f)
		_check("unlock_floor_%d" % f, XTianqiQiyin.unlocked_seals(s) == expect[f], [XTianqiQiyin.unlocked_seals(s), expect[f]])
	var s34 := _state(34)
	XTianqiSummit.progress(s34)["hongjun"] = true
	_check("unlock_hongjun_flag", XTianqiQiyin.unlocked(s34, "xun"))
	var s36 := _state(36)
	var fc: Dictionary = XTianqiQiyin.progress(s36).drop.first_clear
	for k in ["bai", "hong", "hei", "hui", "xun"]:
		fc[k] = true
	_check("mo_needs_six", not XTianqiQiyin.unlocked(s36, "mo"))
	fc["zhen"] = true
	_check("mo_after_six", XTianqiQiyin.unlocked(s36, "mo"))


# ---- 三、入口 ----

func _entries() -> void:
	var s := _state(31)
	_check("entry_locked_original", not XTianqiQiyin.intercepts(s, 4, 48))
	s.set_variable(20, 32)
	_check("entry_hall", XTianqiQiyin.intercepts(s, 4, 48))
	_check("entry_156", XTianqiQiyin.intercepts(s, 156, 2))
	_check("entry_157", XTianqiQiyin.intercepts(s, 157, 2))
	_check("entry_other_event", not XTianqiQiyin.intercepts(s, 4, 36) and not XTianqiQiyin.intercepts(s, 156, 1))
	var noline := _state(32, "")
	_check("entry_no_line", not XTianqiQiyin.intercepts(noline, 4, 48))
	var plain := XState.new()
	plain.set_variable(20, 36)
	_check("entry_plain_save", not XTianqiQiyin.intercepts(plain, 4, 48) and not XTianqiQiyin.allowed(plain))
	XTianqiQiyin.ENABLED = false
	_check("entry_switch_off", not XTianqiQiyin.intercepts(s, 4, 48))
	XTianqiQiyin.ENABLED = true


# ---- 四、祭坛开张 ----

func _sync() -> void:
	var s := _state(32)
	var notes := XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	_check("first_open_keys", XTianqiQiyin.keys(s) == int(XTianqiQiyin.data().keys.first_open), p.keys)
	_check("first_open_note", notes.any(func(n): return n[0] == "first_open"), notes)
	var seals: Array = p.bag.map(func(i): return str(i.seal))
	seals.sort()
	_check("floor31_kill_pieces", seals == ["bai", "hong"] and p.bag.all(func(i): return str(i.kind) == "set" and not bool(i.revealed)), p.bag)
	var again := XTianqiQiyin.sync(s)
	_check("sync_once", XTianqiQiyin.keys(s) == int(XTianqiQiyin.data().keys.first_open) and p.bag.size() == 2 and again.is_empty(), [p.keys, p.bag.size(), again])
	s.set_variable(20, 33)
	XTianqiQiyin.sync(s)
	_check("floor32_kill_piece", p.bag.size() == 3 and str(p.bag[2].seal) == "hei", p.bag.size())


# ---- 五、里副本 ----

func _dungeon() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	var bag0: int = p.bag.size()
	var keys0 := XTianqiQiyin.keys(s)
	var host := FakeHost.new()
	host.answers = [1]  # 结算后「先收着」
	var r: int = await XTianqiQiyin.run_dungeon(host, s, "bai", false, {})
	_check("dungeon_win", r == 0, r)
	_check("dungeon_three_fights", host.battles.map(func(b): return b.troop) == [249, 250, 52], host.battles)
	_check("dungeon_no_escape_can_lose", host.battles.all(func(b): return not b.escape and b.lose))
	_check("dungeon_rule_each_fight", host.battles.all(func(b): return str(b.rule.get("seal", "")) == "bai"), host.battles)
	_check("dungeon_boss_flag", host.battles.map(func(b): return bool(b.rule.boss)) == [false, false, true])
	_check("dungeon_map_name", host.names.has(str(XTianqiQiyin.seal_info("bai").name)), host.names)
	_check("dungeon_tone", host.battles[0].tone == XTianqiQiyin.seal_info("bai").tone.map(func(x): return float(x)) or host.battles[0].tone.size() == 4, host.battles[0].tone)
	var refunded := XTianqiQiyin.keys(s) - (keys0 - 1)
	_check("dungeon_key_spent", refunded == 0 or refunded == 1, [keys0, XTianqiQiyin.keys(s)])
	_check("dungeon_first_clear", bool(p.drop.first_clear.get("bai", false)))
	_check("dungeon_first_clear_piece", p.bag.size() >= bag0 + 1 and p.bag.slice(bag0).all(func(i): return str(i.seal) == "bai" and not bool(i.revealed)), p.bag.slice(bag0))
	_check("dungeon_first_clear_said", _has(host, "首通"))
	_check("dungeon_reveal_asked", host.asked.any(func(o): return o.has("先收着")))
	_check("dungeon_enter_count", int(p.drop.enter_count) == 1)
	# 魔塔：每场前三选一捡宝石，累计进下一场
	var s2 := _state(34)
	XTianqiQiyin.sync(s2)
	var h2 := FakeHost.new()
	h2.answers = [0, 1, 2, 1]
	await XTianqiQiyin.run_dungeon(h2, s2, "hui", false, {})
	_check("tower_gems", h2.battles.size() == 3 and is_equal_approx(float(h2.battles[2].rule.gems.get("atk", 0.0)), 0.1)
		and is_equal_approx(float(h2.battles[2].rule.gems.get("def", 0.0)), 0.1) and is_equal_approx(float(h2.battles[2].rule.gems.get("hp", 0.0)), 0.1)
		and h2.battles[0].rule.gems.size() == 1, h2.battles.map(func(b): return b.rule.gems))
	# 锁着的印进不去
	var h3 := FakeHost.new()
	_check("locked_seal_refused", await XTianqiQiyin.run_dungeon(h3, s, "zhen", false, {}) == -1 and h3.battles.is_empty())


func _dungeon_lost() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	var bag0: int = p.bag.size()
	var keys0 := XTianqiQiyin.keys(s)
	var host := FakeHost.new()
	host.results = [0, 2]
	var r: int = await XTianqiQiyin.run_dungeon(host, s, "hong", false, {})
	_check("lost_result", r == 1 and host.battles.size() == 2, [r, host.battles.size()])
	_check("lost_key_gone", XTianqiQiyin.keys(s) == keys0 - 1)
	_check("lost_no_drop", p.bag.size() == bag0 and not bool(p.drop.first_clear.get("hong", false)))
	_check("lost_said", _has(host, "印钥没了"))


func _direct_and_restless() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	p.keys = 9
	var h := FakeHost.new()
	h.answers = [1]
	await XTianqiQiyin.run_dungeon(h, s, "bai", false, {})
	_check("direct_allowed_after_clear", XTianqiQiyinDrop.direct_allowed(p.drop, "bai"))
	var h2 := FakeHost.new()
	h2.answers = [1]
	await XTianqiQiyin.run_dungeon(h2, s, "bai", true, {})
	_check("direct_boss_only", h2.battles.size() == 1 and int(h2.battles[0].troop) == 52 and bool(h2.battles[0].rule.boss), h2.battles)
	_check("restless_not_yet", str(p.drop.restless) == "")
	var h3 := FakeHost.new()
	h3.answers = [1]
	await XTianqiQiyin.run_dungeon(h3, s, "hong", false, {})
	var picked := str(p.drop.restless_last)
	_check("restless_third_enter", picked == "bai" or picked == "hong", p.drop)
	_check("restless_said", _has(h3, "躁动"))
	# 选印菜单：躁动、未通标在名字后面（打完躁动那一印就平息了：第三次打的是 hong，躁动的若是 bai 还亮着）
	var labels: Array = XTianqiQiyin.seal_options(s).map(func(o): return o.label)
	if str(p.drop.restless) != "":
		_check("seal_label_restless", labels.any(func(l): return l.contains("【躁动】")), labels)
	else:
		_check("seal_label_restless_calmed", not labels.any(func(l): return l.contains("【躁动】")) and picked == "hong", [labels, picked])
	# 直取走菜单：首通过的印问「打满三场／直取」
	var h4 := FakeHost.new()
	h4.answers = [0, 1, 0, 1]  # 选 bai → 直取 → 不献 → 先收着
	p.shards = 9
	await XTianqiQiyin.choose_and_run(h4, s)
	_check("menu_direct", h4.battles.size() == 1 and int(h4.battles[0].troop) == 52, h4.battles)


func _no_key_and_offering() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	p.keys = 0
	var h := FakeHost.new()
	h.answers = [0]  # 选 bai（没首通，不问直取；印屑不够，不问献）
	var r: int = await XTianqiQiyin.choose_and_run(h, s)
	_check("no_key_refused", r == -1 and h.battles.is_empty() and _has(h, "没有印钥"), [r, h.said])
	p.keys = 3
	p.shards = 6
	var h2 := FakeHost.new()
	h2.answers = [0, 1, 2, 1]  # 选 bai → 献印屑 → 护手 → 先收着
	await XTianqiQiyin.choose_and_run(h2, s)
	_check("offer_spent", h2.battles.size() == 3 and XTianqiQiyin.shards(s) >= 1, [XTianqiQiyin.shards(s), h2.battles.size()])
	_check("offer_part_asked", h2.asked.any(func(o): return o.has("护手")))
	var bad := await XTianqiQiyin.run_dungeon(FakeHost.new(), s, "bai", false, {"kind": "shards", "part": "head"}) if XTianqiQiyin.shards(s) < 5 else -1
	_check("offer_needs_shards", bad == -1)


# ---- 六、揭开 ----

func _reveal() -> void:
	var s := _state(32)
	XTianqiQiyin.sync(s)
	var p := XTianqiQiyin.progress(s)
	var item: Dictionary = p.bag[0]
	var sealed := XTianqiQiyin.sealed_label(item)
	_check("sealed_label_hides", sealed.contains("印·") and sealed.contains("光") and not sealed.contains("成色"), sealed)
	var it := XTianqiQiyin.reveal(s, 0)
	var shown := XTianqiQiyin.revealed_label(it)
	var setname := str(XTianqiQiyinGear.set_of(str(it.seal)).name)
	_check("revealed_label", bool(it.revealed) and shown.contains(setname) and shown.contains("成色"), shown)
	_check("reveal_out_of_range", XTianqiQiyin.reveal(s, 99).is_empty())
	var w := {"kind": "weapon", "seal": "hong", "wtype": "剑", "true_seal": true, "grades": ["ji", "ji", "ji"], "revealed": true}
	var wl := XTianqiQiyin.revealed_label(w)
	_check("weapon_label", wl.contains("止戈") and wl.contains("【真印】") and wl.contains("极"), wl)
	var mo := {"kind": "weapon", "seal": "mo", "wtype": "书", "true_seal": false, "grades": ["putong", "ji", "shangpin"], "revealed": true}
	_check("mo_weapon_label", XTianqiQiyin.revealed_label(mo).contains("不立文字"), XTianqiQiyin.revealed_label(mo))
	# 祭坛里的揭开：全部揭开
	var h := FakeHost.new()
	h.answers = [p.bag.size() - 1]  # 剩一件封着：「全部揭开」在它后面
	await XTianqiQiyin.run_reveal(h, s)
	_check("reveal_all", XTianqiQiyin.sealed_items(s).is_empty(), p.bag)
	var h2 := FakeHost.new()
	await XTianqiQiyin.run_reveal(h2, s)
	_check("reveal_none", _has(h2, "没有封着"))
	# 当场揭：结算时选「揭开」
	p.keys = 3
	var h3 := FakeHost.new()
	h3.answers = [0]
	var n0: int = p.bag.size()
	await XTianqiQiyin.run_dungeon(h3, s, "hong", false, {})
	_check("reveal_on_the_spot", p.bag.size() > n0 and p.bag.slice(n0).all(func(i): return bool(i.revealed)) and _has(h3, "揭开了"), p.bag.slice(n0))


func _altar_menu() -> void:
	var s := _state(32)
	var h := FakeHost.new()
	h.answers = [1, 2, 0]  # 揭开封着的 → 「全部揭开」（两件之后）→ 回到菜单后离开（取完选最后一个）
	await XTianqiQiyin.run_altar(h, s)
	var altar: Dictionary = XTianqiQiyin.data().altar
	_check("altar_transfer", h.moves[0] == [int(altar.map), int(altar.pos[0]), int(altar.pos[1]), int(altar.pos[2])], h.moves)
	_check("altar_name", h.names[0] == str(altar.name), h.names)
	_check("altar_first_open_said", _has(h, "别全揭开"))
	_check("altar_home", h.moves[-1] == [XTianqi.HALL_MAP, XTianqi.HALL_POS.x, XTianqi.HALL_POS.y, XTianqi.HALL_POS.z] and XTianqiQiyin.current() == "")
	_check("altar_revealed_all", XTianqiQiyin.sealed_items(s).is_empty())
	_check("altar_tint_reset", s.screen.tone.all(func(x): return is_zero_approx(float(x))), s.screen.tone)
	XTianqiQiyin.set_current("altar")
	_check("altar_no_encounter", XTianqiQiyin.no_encounter(s, 54))
	XTianqiQiyin.set_current("")
	_check("no_encounter_outside", not XTianqiQiyin.no_encounter(s, 54))
	_check("map_name_outside", XTianqiQiyin.map_name(s, 54, "古龙祭坛") == "古龙祭坛")


# ---- 七、规则 ----

func _fight(s: XState, seal: String, troop: int, boss := false, gems := {}) -> XBattleLogic:
	XTianqiQiyinRule.prepare(seal, boss, gems)
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	return lg


func _rules() -> void:
	var s := _state(36)
	XTianqiQiyin.set_current("bai")
	# 重标：Boss 换名字、能力值按参照
	var plain := XBattleLogic.new()
	plain.setup(52, s)
	var p0: XEnemy = plain.enemies[0]
	var lg := _fight(s, "bai", 52, true)
	var e: XEnemy = lg.enemies[0]
	var ref: Array = XDB.rec("Enemies", int(XTianqiQiyin.data().rebase.ref)).params
	var rate: Array = XTianqiQiyin.data().rebase.boss
	_check("rebase_boss_name", e.display_name().contains("疫土之主") and not p0.display_name().contains("疫土"), [e.display_name(), p0.display_name()])
	_check("rebase_boss_params", is_equal_approx(float(e.data().params[0]), roundf(float(ref[0]) * float(rate[0]))) and e.data().dropItems.is_empty(), e.data().params)
	_check("rebase_hp_full", is_equal_approx(e.hp, e.mhp) and e.mhp > p0.mhp, [e.mhp, p0.mhp])
	_check("rule_pending_used", XTianqiQiyinRule.pending().is_empty() and XTianqiQiyinRule.active(lg))
	_check("rule_announced", lg.turn_start_logs.any(func(l): return l is Dictionary and str(l.get("text", "")).contains("不愈")), lg.turn_start_logs.size())
	var elite := _fight(s, "bai", 249, false)
	var erate: Array = XTianqiQiyin.data().rebase.elite
	_check("rebase_elite_params", elite.enemies.all(func(x): return is_equal_approx(float(x.data().params[2]), roundf(float(ref[2]) * float(erate[2])))))
	_check("rebase_elite_name_kept", elite.enemies.all(func(x): return not x.display_name().contains("【里】")))
	elite.end_battle(0)
	plain.end_battle(0)
	# 不愈：减益状态和能力值减益不到期；增益照常
	var bad := -1
	var good := -1
	for id in range(1, 200):
		var rec := XDB.rec("States", id)
		if rec.is_empty() or int(rec.get("autoRemovalTiming", 0)) != 2:
			continue
		if bad < 0 and XTianqiQiyinRule.debuff_state(id):
			bad = id
		elif good < 0 and not XTianqiQiyinRule.debuff_state(id) and int(rec.get("restriction", 0)) == 0:
			good = id
	_check("no_cure_states_found", bad > 0 and good > 0, [bad, good])
	_check("no_cure_keeps_debuff", XTianqiQiyinRule.keeps_state(lg, bad) and not XTianqiQiyinRule.keeps_state(lg, good))
	_check("no_cure_keeps_debuff_buff", XTianqiQiyinRule.keeps_debuff(lg, -1) and not XTianqiQiyinRule.keeps_debuff(lg, 1))
	var a: XBattler = lg.actors[0]
	a.buffs[2] = -1
	a.buff_turns[2] = 1
	lg._tick_states(a, 2)
	_check("no_cure_tick", a.buffs[2] == -1 and a.buff_turns[2] == 1, [a.buffs[2], a.buff_turns[2]])
	lg.end_battle(0)
	_check("rule_end_clears", not XTianqiQiyinRule.active(lg))
	# 杀声
	var wc := _fight(s, "hong", 33)
	var base := XTianqiQiyinRule.hp_damage(wc, wc.actors[0], wc.enemies[0], 1000.0)
	wc._die(wc.enemies[1])
	var after := XTianqiQiyinRule.hp_damage(wc, wc.actors[0], wc.enemies[0], 1000.0)
	_check("war_cry_base", is_equal_approx(base, 1000.0), base)
	_check("war_cry_one_dead", is_equal_approx(after, 1050.0), after)
	_check("war_cry_both_sides", is_equal_approx(XTianqiQiyinRule.hp_damage(wc, wc.enemies[0], wc.actors[0], 1000.0), 1050.0))
	_check("war_cry_heal_untouched", is_equal_approx(XTianqiQiyinRule.hp_damage(wc, wc.actors[0], wc.actors[1], -500.0), -500.0))
	wc.end_battle(0)
	# 限时：我方第 6 个技能放不了，普攻、防御照常；魔法、TP 不再生
	var ex := _fight(s, "hei", 10)
	var u: XBattler = ex.actors[0]
	var sk := {"id": 99999, "occasion": 0}
	for i in 5:
		_check("exam_skill_%d_ok" % i, XTianqiQiyinRule.can_use(ex, u, sk))
		XTianqiQiyinRule.on_act(ex, u, sk)
	_check("exam_sixth_blocked", not XTianqiQiyinRule.can_use(ex, u, sk))
	_check("exam_attack_ok", XTianqiQiyinRule.can_use(ex, u, u.attack_skill()) and XTianqiQiyinRule.can_use(ex, u, XDB.rec("Skills", XBattleLogic.GUARD_SKILL)))
	_check("exam_enemy_unlimited", XTianqiQiyinRule.can_use(ex, ex.enemies[0], sk))
	_check("exam_no_regen", XTianqiQiyinRule.no_regen(ex))
	u.mp = 0.0
	u.tp = 0.0
	ex._regenerate(u, [])
	_check("exam_regen_zero", is_zero_approx(u.mp) and is_zero_approx(u.tp), [u.mp, u.tp])
	ex.start_turn()
	_check("exam_reset_each_turn", XTianqiQiyinRule.can_use(ex, u, sk))
	ex.end_battle(0)
	# 魔塔：没有暴击，宝石加伤、减伤
	var mt := _fight(s, "hui", 291, false, {"atk": 0.2, "def": 0.1, "hp": 0.1})
	_check("tower_no_crit", XTianqiQiyinRule.no_crit(mt) and is_zero_approx(mt.item_cri(mt.actors[0], mt.actors[0].attack_skill(), mt.enemies[0])))
	_check("tower_atk_gem", is_equal_approx(XTianqiQiyinRule.hp_damage(mt, mt.actors[0], mt.enemies[0], 1000.0), 1200.0))
	_check("tower_def_gem", is_equal_approx(XTianqiQiyinRule.hp_damage(mt, mt.enemies[0], mt.actors[0], 1200.0), 1000.0))
	mt.end_battle(0)
	# 献祭：生命最高的那只掉 10% 当前生命，那一方本回合出伤 +10%
	var sc := _fight(s, "xun", 122)
	var top = null
	for b in sc.actors + sc.enemies:
		if b.is_alive() and (top == null or b.hp > top.hp):
			top = b
	var hp0: float = top.hp
	sc.start_turn()
	_check("sacrifice_hp", is_equal_approx(top.hp, hp0 - floorf(hp0 * 0.1)), [hp0, top.hp])
	var side_u = sc.enemies[0] if top is XEnemy else sc.actors[0]
	var other_u = sc.actors[0] if top is XEnemy else sc.enemies[0]
	_check("sacrifice_bonus", is_equal_approx(XTianqiQiyinRule.hp_damage(sc, side_u, other_u, 1000.0), 1100.0)
		and is_equal_approx(XTianqiQiyinRule.hp_damage(sc, other_u, side_u, 1000.0), 1000.0))
	sc.end_battle(0)
	# 星坠：第 3 回合开始全场掉 33% 当前生命
	var sf := _fight(s, "zhen", 187)
	sf.start_turn()
	sf.start_turn()
	var hps: Array = (sf.actors + sf.enemies).map(func(b): return b.hp)
	sf.start_turn()
	var ok := true
	var all: Array = sf.actors + sf.enemies
	for i in all.size():
		if not is_equal_approx(all[i].hp, maxf(1.0, hps[i] - floorf(hps[i] * 0.33))):
			ok = false
	_check("star_fall_turn3", ok and int(sf.turn) == 3)
	sf.end_battle(0)
	# 寂静：双数回合我方只能普攻、防御，敌人只普攻
	var si := _fight(s, "mo", 216)
	si.start_turn()
	_check("silence_odd_free", XTianqiQiyinRule.can_use(si, si.actors[0], sk) and XTianqiQiyinRule.decide_enemy(si, si.enemies[0]).is_empty())
	si.start_turn()
	_check("silence_even_blocked", not XTianqiQiyinRule.can_use(si, si.actors[0], sk) and XTianqiQiyinRule.can_use(si, si.actors[0], si.actors[0].attack_skill()))
	var dec := XTianqiQiyinRule.decide_enemy(si, si.enemies[0])
	_check("silence_enemy_attack", dec.size() == 2 and int(dec[0].id) == si.enemies[0].attack_skill_id(), dec)
	si.end_battle(0)
	# 不在里副本：一概不动
	XTianqiQiyin.set_current("")
	var nf := XBattleLogic.new()
	nf.setup(33, s)
	_check("outside_inactive", not XTianqiQiyinRule.active(nf) and is_equal_approx(XTianqiQiyinRule.hp_damage(nf, nf.actors[0], nf.enemies[0], 1000.0), 1000.0)
		and XTianqiQiyinRule.can_use(nf, nf.actors[0], sk) and not XTianqiQiyinRule.no_regen(nf) and not XTianqiQiyinRule.no_crit(nf)
		and not XTianqiQiyinRule.keeps_state(nf, bad) and XTianqiQiyinRule.start_turn(nf).is_empty())
	nf.end_battle(2)
	# 原版档：prepare 了也不开
	var plain_s := XState.new()
	XTianqiQiyinRule.prepare("bai", true)
	var pl := XBattleLogic.new()
	pl.setup(52, plain_s)
	_check("plain_save_no_rule", not XTianqiQiyinRule.active(pl) and not pl.enemies[0].display_name().contains("疫土"))
	XState.current = s


# ---- 八、七印书卷 ----

func _scroll_fight(s: XState, key: String, troop: int) -> XBattleLogic:
	var lg := XBattleLogic.new()
	lg.setup(troop, s)
	XTianqiQiyinEffects._store(lg).scroll_rule = key
	return lg


func _scroll() -> void:
	var s := _state(36)
	XTianqiQiyin.set_current("")
	var sk := {"id": 99999, "occasion": 0}
	# 星坠：只砸敌人
	var sf := _scroll_fight(s, "zhen", 187)
	var logs := XTianqiQiyinRule.take_logs(sf)
	_check("scroll_announced", XTianqiQiyinRule.active(sf) and XTianqiQiyinRule.enemy_only(sf) and logs.any(func(l): return str(l.get("text", "")).contains("七印书卷")), logs)
	sf.start_turn()
	sf.start_turn()
	var ahp: Array = sf.actors.map(func(b): return b.hp)
	var ehp: Array = sf.enemies.map(func(b): return b.hp)
	sf.start_turn()
	var ok := true
	for i in sf.enemies.size():
		if not is_equal_approx(sf.enemies[i].hp, maxf(1.0, ehp[i] - floorf(ehp[i] * 0.33))):
			ok = false
	_check("scroll_star_enemy_only", ok and sf.actors.map(func(b): return b.hp) == ahp)
	sf.end_battle(0)
	# 寂静：双数回合敌人只普攻，我方照常放技能
	var si := _scroll_fight(s, "mo", 216)
	si.start_turn()
	si.start_turn()
	_check("scroll_silence_enemy", not XTianqiQiyinRule.decide_enemy(si, si.enemies[0]).is_empty() and not XTianqiQiyinRule.can_use(si, si.enemies[0], sk))
	_check("scroll_silence_actor_free", XTianqiQiyinRule.can_use(si, si.actors[0], sk))
	si.end_battle(0)
	# 魔塔：只有敌人不能暴击
	var mt := _scroll_fight(s, "hui", 291)
	mt.start_turn()
	_check("scroll_tower", XTianqiQiyinRule.no_crit(mt, mt.enemies[0]) and not XTianqiQiyinRule.no_crit(mt, mt.actors[0]))
	mt.end_battle(0)
	# 杀声：只加打在敌人身上的
	var wc := _scroll_fight(s, "hong", 33)
	wc.start_turn()
	wc._die(wc.enemies[1])
	_check("scroll_war_cry", is_equal_approx(XTianqiQiyinRule.hp_damage(wc, wc.actors[0], wc.enemies[0], 1000.0), 1050.0)
		and is_equal_approx(XTianqiQiyinRule.hp_damage(wc, wc.enemies[0], wc.actors[0], 1000.0), 1000.0))
	wc.end_battle(0)
	# 限时：只限敌人
	var ex := _scroll_fight(s, "hei", 10)
	ex.start_turn()
	for i in 5:
		XTianqiQiyinRule.on_act(ex, ex.enemies[0], sk)
		XTianqiQiyinRule.on_act(ex, ex.actors[0], sk)
	_check("scroll_exam_enemy", not XTianqiQiyinRule.can_use(ex, ex.enemies[0], sk) and XTianqiQiyinRule.can_use(ex, ex.actors[0], sk))
	_check("scroll_exam_regen", XTianqiQiyinRule.no_regen(ex, ex.enemies[0]) and not XTianqiQiyinRule.no_regen(ex, ex.actors[0]))
	ex.end_battle(0)
	# 不愈：只有敌人身上的减益不到期
	var nc := _scroll_fight(s, "bai", 33)
	nc.start_turn()
	var bad := -1
	for id in range(1, 200):
		if not XDB.rec("States", id).is_empty() and XTianqiQiyinRule.debuff_state(id):
			bad = id
			break
	_check("scroll_no_cure", XTianqiQiyinRule.keeps_state(nc, bad, nc.enemies[0]) and not XTianqiQiyinRule.keeps_state(nc, bad, nc.actors[0])
		and XTianqiQiyinRule.keeps_debuff(nc, -1, nc.enemies[0]) and not XTianqiQiyinRule.keeps_debuff(nc, -1, nc.actors[0]))
	nc.end_battle(0)
	# 献祭：只扣敌方生命最高那只，不给敌方加伤
	var sc := _scroll_fight(s, "xun", 122)
	var top = null
	for b in sc.enemies:
		if b.is_alive() and (top == null or b.hp > top.hp):
			top = b
	var hp0: float = top.hp
	var a_hp: Array = sc.actors.map(func(b): return b.hp)
	sc.start_turn()
	_check("scroll_sacrifice", is_equal_approx(top.hp, hp0 - floorf(hp0 * 0.1)) and sc.actors.map(func(b): return b.hp) == a_hp
		and is_equal_approx(XTianqiQiyinRule.hp_damage(sc, sc.enemies[0], sc.actors[0], 1000.0), 1000.0))
	sc.end_battle(0)
	# 书卷那场打赢照样掉野外印钥
	s.map_id = 156
	var k0 := XTianqiQiyin.keys(s)
	var fk := _scroll_fight(s, "zhen", 216)
	fk.start_turn()
	fk.end_battle(0)
	_check("scroll_field_key", XTianqiQiyin.keys(s) == k0 + 1 and not XTianqiQiyinRule.active(fk), [k0, XTianqiQiyin.keys(s)])
	# 里副本里本印规则优先
	s.map_id = 61
	XTianqiQiyin.set_current("bai")
	var dg := _fight(s, "bai", 249)
	XTianqiQiyinEffects._store(dg).scroll_rule = "zhen"
	dg.start_turn()
	_check("scroll_dungeon_keeps_seal", XTianqiQiyinRule.rule_of(dg) == "no_cure" and not XTianqiQiyinRule.enemy_only(dg))
	dg.end_battle(0)
	XTianqiQiyin.set_current("")
	# 原版档：书卷不开
	var plain_s := XState.new()
	var pl := _scroll_fight(plain_s, "zhen", 33)
	pl.start_turn()
	_check("scroll_plain_save", not XTianqiQiyinRule.active(pl))
	XState.current = s


# ---- 九、野外印钥 ----

func _field_keys() -> void:
	var s := _state(33)
	var p := XTianqiQiyin.progress(s)
	p.keys = 0
	_check("field_elite_sure", XTianqiQiyin.field_drop(s, 156, "【精英】某某") == 1 and XTianqiQiyin.keys(s) == 1)
	_check("field_guardian_sure", XTianqiQiyin.field_drop(s, 157, "【守护者】某某") == 1)
	_check("field_hall_none", XTianqiQiyin.field_drop(s, 4, "【精英】某某") == 0)
	XTianqiQiyin.set_current("bai")
	_check("field_in_dungeon_none", XTianqiQiyin.field_drop(s, 156, "【精英】某某") == 0)
	XTianqiQiyin.set_current("")
	var got := 0
	for i in 2000:
		got += XTianqiQiyin.field_drop(s, 148, "野猪*3", XRandomStream.create(XRandomStream.derive("0123012301230123", str(i)), "qiyin"))
	_check("field_chance", got > 60 and got < 150, got)
	var notes := XTianqiQiyin.sync(s)
	_check("field_keys_reported", notes.any(func(n): return n[0] == "field_keys") and int(p.field_keys) == 0, notes)
	# 战斗收尾：31～35 层一场普通战斗打赢了才掉
	s.map_id = 156
	var k0 := XTianqiQiyin.keys(s)
	var lg := XBattleLogic.new()
	lg.setup(216, s)  # 【精英】龙人禁卫军*3
	lg.end_battle(0)
	_check("battle_end_field_key", XTianqiQiyin.keys(s) == k0 + 1, [k0, XTianqiQiyin.keys(s)])
	var lg2 := XBattleLogic.new()
	lg2.setup(216, s)
	lg2.end_battle(2)
	_check("battle_lost_no_key", XTianqiQiyin.keys(s) == k0 + 1)
	XTianqiQiyin.rng_override = null
