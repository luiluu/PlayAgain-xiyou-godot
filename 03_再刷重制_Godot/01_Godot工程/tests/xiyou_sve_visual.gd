extends Node
## YEP_X_AnimatedSVEnemies 画面规则守卫（bailong-visual1）：影子、呼吸、武器图／攻击动作、倒下。
## 参照 oracle/sve.json（mv_oracle/sve_probe.cjs 用真实 Game_Enemy／Sprite_Enemy 量冻结正式源）。
## 全库计数：SV 敌人 186，全部显示影子、全部不呼吸；非 SV 1814 个全部呼吸（9 个周期 11 帧、其余 20 帧）；
## 武器图 44 个、其余 142 个 thrust 无武器；<Sideview No Collapse> 实测被 MOG 默认死亡效果盖住（SV／非 SV 倒下透明度一样），不实现。
var passed := 0
var total := 0


func check(tag: String, ok: bool, detail = null) -> void:
	total += 1
	if ok: passed += 1
	else: print("FAIL ", tag, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var ref = XDB.load_json("oracle/sve.json")
	check("oracle_present", ref is Dictionary and ref.has("cases"))
	if not (ref is Dictionary and ref.has("cases")):
		return _finish()
	var cases := {}
	for c in ref.cases:
		check(c.id + ".oracle_clean", c.errors.is_empty(), c.errors)
		cases[c.id] = c
	_census(cases.census.observed)
	_weapons(cases.weapon.observed)
	_breath(cases.breath.observed)
	_collapse(cases.collapse.observed)
	_sprites(cases.census.observed)
	_finish()


## 每个敌人：XSvEnemy 的规则等于原版 Game_Enemy 读数；全库计数
func _census(c: Dictionary) -> void:
	check("census.total", int(c.total) == 2000, c.total)
	var p: Dictionary = c.params
	check("census.params", p.shadow == false and int(p.breathing) == 1 and int(p.speed) == 20 and p.collapse == false and int(p.mogDefault) == 0, p)
	var sv := 0
	var shadow := 0
	var breath := 0
	var breath11 := 0
	var bad := []
	for r in c.rows:
		var e := XEnemy.new().setup(int(r.id), 1)
		var is_sv := int(r.sv) == 1
		if XSvEnemy.is_sv(e) != is_sv:
			bad.append(["sv", r.id])
		# 影子：原版只有 SV 敌人画（非 SV 的 9 个备注无效）
		var want_shadow := is_sv and int(r.shadow) == 1
		if XSvEnemy.shadow(e) != want_shadow:
			bad.append(["shadow", r.id])
		var br := XSvEnemy.breathing(e)
		if br.on != (int(r.breath) == 1) or not is_equal_approx(br.speed, float(r.speed)) or not is_equal_approx(br.rx, float(r.rx)) or not is_equal_approx(br.ry, float(r.ry)):
			bad.append(["breath", r.id, br])
		if int(r.link) != 0 or int(r.collapse) != 0:
			bad.append(["link_or_collapse_tag_appeared", r.id])  # 出现 HP 联动呼吸、<Sideview Collapse> 就要回来实现
		if is_sv:
			sv += 1
		if want_shadow:
			shadow += 1
		if br.on:
			breath += 1
			if br.speed == 11.0:
				breath11 += 1
	check("census.rows_match", bad.is_empty(), bad.slice(0, 5))
	check("census.sv_186", sv == 186, sv)
	check("census.shadow_186", shadow == 186, shadow)
	check("census.breath_1814", breath == 1814 and breath11 == 9, [breath, breath11])


func _weapons(rows: Array) -> void:
	check("weapon.rows", rows.size() == 186, rows.size())
	var bad := []
	var armed := 0
	var thrust := 0
	for r in rows:
		var e := XEnemy.new().setup(int(r.id), 1)
		var v := XSvEnemy.attack_visual(e)
		if int(v.image) != int(r.weaponImageId) or v.motion != r.motion or int(r.anim) != 1:
			bad.append([r.id, v, r])
		if XActionSequence.attack_motion(e) != r.motion:
			bad.append(["seq", r.id])
		if int(v.image) > 0:
			armed += 1
		elif v.motion == "thrust":
			thrust += 1
	check("weapon.rows_match", bad.is_empty(), bad.slice(0, 5))
	check("weapon.armed_44_thrust_142", armed == 44 and thrust == 142, [armed, thrust])
	# 非 SV 敌人没有动作与武器
	var plain := XSvEnemy.attack_visual(XEnemy.new().setup(1, 1))
	check("weapon.plain_none", plain.motion == "" and int(plain.image) == 0, plain)
	check("weapon.plain_thrust_cond", XActionSequence.attack_motion(XEnemy.new().setup(1, 1)) == "thrust")


## 呼吸时序：原版 scale = 基础 + cos(帧 / 周期) × 速率（svRand 取 0）
func _breath(b: Dictionary) -> void:
	for k in ["nonSvDefault", "nonSvTag"]:
		var d: Dictionary = b[k]
		var e := XEnemy.new().setup(int(d.id), 1)
		var br := XSvEnemy.breathing(e)
		check("breath.%s.params" % k, br.on and is_equal_approx(br.speed, float(d.speed)), [br, d.speed])
		var bad := 0
		for f in d.frames:
			var fr := float(f[0])
			var sx: float = 1.0 + cos(fr / br.speed) * br.rx
			var sy: float = 1.0 + cos(fr / br.speed) * br.ry
			if absf(sx - float(f[1])) > 0.00002 or absf(sy - float(f[2])) > 0.00002:
				bad += 1
		check("breath.%s.curve" % k, bad == 0, bad)
	var sv: Dictionary = b.sv
	check("breath.sv.flat", not sv.isBreathing and sv.frames.all(func(f): return float(f[2]) == 1.0 and float(f[1]) == -1.0), sv.frames.slice(0, 3))
	check("breath.sv.rule", not XSvEnemy.breathing(XEnemy.new().setup(int(sv.id), 1)).on)


## 倒下：SV 与非 SV 同样淡出（MOG_CollapseEffects 默认效果接管），<Sideview No Collapse> 不改变画面
func _collapse(c: Dictionary) -> void:
	check("collapse.sv_notag_collapse_data", c.sv.collapseData[0] == 0 and not c.sv.isSideviewCollapse and c.plain.isSideviewCollapse, [c.sv.collapseData, c.plain.collapseData])
	check("collapse.same_timeline", JSON.stringify(c.sv.line.map(func(x): return [x[0], x[1]])) == JSON.stringify(c.plain.line.map(func(x): return [x[0], x[1]])), null)
	var gone := false
	for x in c.sv.line:
		if int(x[0]) >= 80 and int(x[1]) == 0:
			gone = true
	check("collapse.sv_fades_out", gone, c.sv.line.slice(6, 10))
	check("collapse.no_sv_collapse_tag", int(c.svCollapseTrueCount) == 0)


## 画面节点：SV 敌人有影子（缩放 = 一格宽 / 64）、非 SV 没有、角色照旧；SV 敌人出武器图时挂在根上镜像
func _sprites(c: Dictionary) -> void:
	var sv_id := 0
	var armed_id := 0
	var plain_id := 0
	for r in c.rows:
		if int(r.sv) == 1:
			if sv_id == 0: sv_id = int(r.id)
			if armed_id == 0 and not r.weapons.is_empty() and int(r.weapons[0][0]) > 0: armed_id = int(r.id)
		elif plain_id == 0:
			plain_id = int(r.id)
	var s := XBattlerSprite.new()
	add_child(s)
	var e := XEnemy.new().setup(sv_id, 1)
	s.setup(e, 1.0)
	check("sprite.sv_shadow", s.shadow != null and s.shadow.texture != null, null)
	if s.shadow:
		check("sprite.sv_shadow_scale", is_equal_approx(s.shadow.scale.x, s.look.cell.x / 64.0) and s.shadow.scale.x == s.shadow.scale.y, s.shadow.scale)
	var p := XBattlerSprite.new()
	add_child(p)
	p.setup(XEnemy.new().setup(plain_id, 1), 1.0)
	check("sprite.plain_no_shadow", p.shadow == null)
	var w := XBattlerSprite.new()
	add_child(w)
	w.setup(XEnemy.new().setup(armed_id, 1), 1.0)
	w.start_weapon(int(XSvEnemy.attack_visual(w.battler as XEnemy).image))
	check("sprite.enemy_weapon_mirrored", w.weapon != null and w.weapon.flip_h and w.weapon.position.x > 0, null)


func _finish() -> void:
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
