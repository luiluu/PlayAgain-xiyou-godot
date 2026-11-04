extends Node
## 璇与屠苏的美术对照 tests/fixtures/xuan_tusu_art_oracle.json（mv_oracle/xuan_tusu_art_probe.cjs）：
## - icons：转换器换好的 iconIndex、XUI 图标取得到图、未竟环换图阶段；
## - bound：同一串绑定操作后的 SuperSV 标签、星魂、持武；
## - motions：专属技能的动作。
## - scene.*：真实 XBattleScene 里的画面（本地断言，jsdom 量不了坐标）：璇附身后身体藏起、宿主身后出星魂；屠苏站到宿主脚下、宿主手里有武具；解除后复位。
const FIXTURE := "res://tests/fixtures/xuan_tusu_art_oracle.json"
const XUAN := 177
const TUSU := 176
var results := []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(600))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _state() -> XState:
	var s := XState.new_game_blank()
	XState.current = s
	s.actor_max_level = 99
	s.switches[2494] = true
	s.party.clear()
	s.battle_slots.clear()
	for id in [XUAN, 1, 8, TUSU]:
		s.add_actor(id)
	s.actor(XUAN).change_level(60)
	s.actor_advance[XUAN] = 3
	s.actor(TUSU).change_level(60)
	s.actor(XUAN).refresh_passive()
	for id in [XUAN, 1, 8, TUSU]:
		s.actor(id).recover_all()
	return s


func _meta(a: XActor) -> Dictionary:
	var name := str(a.data().get("battlerName", ""))
	var m := XXuanTusuArt.meta(name, a.data().get("meta", {}), XXuanTusuArt.form_name(a))
	return {"sv": str(m.get("sv", "")), "speed": str(m.get("SVspeed", "")), "shadow": str(m.get("YCyy", "")), "zs0": str(m.get("SVzs0", "")), "zs1": str(m.get("SVzs1", "")), "zs7": str(m.get("SVzs7", ""))}


func _proj(s: XState, id: int):
	var p := XXuanTusuArt.projection_for(s.actor(id))
	return p if p != "" else null


func _run() -> void:
	XMessageBox.auto = true
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("oracle", ref is Dictionary and ref.cases.size() == 3 and ref.cases.all(func(c): return (c.errors as Array).is_empty()))
	for c in ref.cases:
		match str(c.id):
			"icons":
				_icons(c.observed)
			"bound":
				await _bound(c.observed)
			"motions":
				_motions(c.observed)
	await _scene()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"name": "xiyou_xuan_tusu_art", "passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)


func _icons(o: Dictionary) -> void:
	var bad := []
	var seen := {}
	for k in o.out:
		var pair: PackedStringArray = str(k).split(":")
		var got := int(XDB.rec(pair[0], int(pair[1])).get("iconIndex", 0))
		if got != int(o.out[k]):
			bad.append([k, got, o.out[k]])
		seen[got] = true
	check("icons.index", bad.is_empty(), bad)
	check("icons.count", (o.out as Dictionary).size() == 94, (o.out as Dictionary).size())
	var missing := []
	for id in seen:
		var t := XUI.icon_texture(int(id))
		if t == null or t.region.size != Vector2(32, 32):
			missing.append(id)
	check("icons.textures", missing.is_empty(), missing)
	check("icons.stages", [0, 1, 2, 3, 4, 5, 6].map(func(n): return XXuanTusuArt.relic_stage(n)) == (o.stages as Array).map(func(v): return int(v)), o.stages)
	check("icons.other_atlas", XXuanTusuArt.icon_slot(97).is_empty() and XXuanTusuArt.icon_slot(XXuanTusuArt.XUAN_ICON + 3) == ["Xuan_Icons_HD", 3])


func _bound(rows: Array) -> void:
	var s := _state()
	var l := XBattleLogic.new()
	var rand := XBattleRandom.create("0000000000000176")
	l.setup(3, s, rand)
	for e in l.enemies:
		var p: Array = (e.data().params as Array).map(func(v): return float(v))
		p[0] += 1e9
		e.zq_ref = {"p": p, "k": 1.0}
		e.param_mark_dirty()
		e.param_refresh()
	l.start_turn()
	var a := s.actor(XUAN)
	var ts := s.actor(TUSU)
	var i := [0]
	var row := func() -> void:
		var want: Dictionary = rows[i[0]]
		var tag := "bound." + str(want.tag)
		check(tag + ".xuan", _meta(a) == want.xuan, [_meta(a), want.xuan])
		check(tag + ".tusu", _meta(ts) == want.tusu, [_meta(ts), want.tusu])
		var pr := [_proj(s, 1), _proj(s, 8), _proj(s, TUSU), _proj(s, XUAN)]
		check(tag + ".proj", pr == want.proj, [pr, want.proj])
		var host := [XTusu.weapon_of_host(s.actor(1)), XTusu.weapon_of_host(s.actor(8))]
		check(tag + ".host", host == want.host, [host, want.host])
		check(tag + ".bound", [XBinding.is_bound(a), XBinding.is_bound(ts)] == want.bound, want.bound)
		i[0] += 1
	var turn := func() -> void:
		l.end_turn()
		l.start_turn()
	row.call()
	ts.mp = ts.mmp
	l.act(ts, XDB.rec("Skills", XTusu.skill_id("huawu.sword")), s.actor(1))
	row.call()
	for w in ["bow", "shield", "book", "hammer"]:
		ts.mp = ts.mmp
		l.act(ts, XDB.rec("Skills", XTusu.skill_id("yiwu." + w)), null)
		row.call()
		turn.call()
	l.act(a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, "jixing")), s.actor(8))
	row.call()
	turn.call()
	var d: Dictionary = XXuanBattle.data
	d.liexingUntil = XBinding.current_round() + 1
	d.shadows = [1]
	row.call()
	d.shadows = []
	d.liexingUntil = -1
	row.call()
	l._state_add(s.actor(8), 1)
	XBinding.validate()
	row.call()
	l.end_battle(0)


func _motions(o: Dictionary) -> void:
	var s := _state()
	var a := s.actor(XUAN)
	var ts := s.actor(TUSU)
	var bad := []
	for k in o:
		var key := str(k)
		if key.begins_with("attack"):
			continue
		var who: XActor = a if key.begins_with("x.") else ts
		var id := XTusuXuan.skill_id(XUAN if key.begins_with("x.") else TUSU, key.substr(2))
		var got := XXuanTusuArt.motion_for(who, XDB.rec("Skills", id))
		if got != "" and got != str(o[k]):
			bad.append([k, got, o[k]])
	check("motions.keys", bad.is_empty(), bad)
	check("motions.attack", XXuanTusuArt.motion_for(a, a.attack_skill()) == str(o.attackX) and XXuanTusuArt.motion_for(ts, ts.attack_skill()) == str(o.attackT), [o.attackX, o.attackT])


func _scene() -> void:
	var s := _state()
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	var l: XBattleLogic = b.logic
	var a := s.actor(XUAN)
	var ts := s.actor(TUSU)
	var host := s.actor(1)
	var sa: XBattlerSprite = b.sprites[a]
	var st: XBattlerSprite = b.sprites[ts]
	var sh: XBattlerSprite = b.sprites[host]
	check("scene.idle_frames", str(sa.look.frame("wait", 0).get("asset", "")) == "Codex_Xuan_v1", sa.look.frame("wait", 0).get("asset"))
	check("scene.idle_no_proj", not sh.has_meta("xt_proj") and not sh.has_meta("xt_held"))
	var home_t: Vector2 = st.position
	ts.mp = ts.mmp
	l.act(ts, XDB.rec("Skills", XTusu.skill_id("huawu.sword")), host)
	await frames(4)
	check("scene.tusu_form", str(st.look.frame("wait", 0).get("asset", "")) == "Codex_Tusu_sword_v1", st.look.frame("wait", 0).get("asset"))
	check("scene.tusu_attach", st.position == sh.position + Vector2(0, 1), [st.position, sh.position])
	check("scene.tusu_no_shadow", st.shadow == null or not st.shadow.visible)
	var held = sh.get_meta("xt_held", null)
	check("scene.held", held != null and held.visible and held.texture != null, held)
	if held != null:
		var hs: float = held.scale.x
		check("scene.held_size", hs > 0.1 and hs < 1.5, hs)
	l.act(a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, "jixing")), host)
	await frames(4)
	check("scene.xuan_hidden", not sa.sprite.visible)
	var proj = sh.get_meta("xt_proj", null)
	check("scene.proj", proj != null and proj.texture != null, proj)
	await frames(12)
	check("scene.proj_opacity", proj != null and is_equal_approx(proj.modulate.a, 208.0 / 255.0), proj.modulate.a if proj else null)
	check("scene.proj_behind", proj != null and proj.get_index() < sh.sprite.get_index())
	XXuanTusuArt.note_cast(a, XDB.rec("Skills", XTusuXuan.skill_id(XUAN, "huiguang")))
	await frames(2)
	check("scene.proj_cast", proj != null and str(proj.texture.resource_path).contains("cast"), proj.texture.resource_path if proj else null)
	# 解除：璇回来，星魂淡出；屠苏回原位
	XBinding.unbind(a, "return")
	XBinding.unbind(ts, "return")
	await frames(14)
	check("scene.xuan_back", sa.sprite.visible)
	check("scene.proj_fade", proj != null and not proj.visible)
	check("scene.tusu_home", st.position == st.home, [st.position, st.home, home_t])
	check("scene.held_off", held != null and not held.visible)
	b.queue_free()
	await frames(2)
