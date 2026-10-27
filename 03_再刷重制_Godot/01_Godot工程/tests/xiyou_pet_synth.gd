extends Node
## 宠物喂养（Star_PetUpLevel）与合成（Star_PetSynthesis）：对照冻结 v0.28 浏览器参照 tests/fixtures/pet_synth_oracle.json
## （新局 1/8/9/10，原版 GetingPet 造的敌人 1、288、10 三只宠物，前两只 50 级；口粮 426×3、428×1）：
## 喂养列表逐条绘制、吃棒棒糖（1→6 级）与肉排（→50 级、补学等级技能）、出战宠物不吃；合成窗、选为宠物一／二后的目录名、
## 同一只不能当两边、合成结果（随机数用参照的序列：取哪只、14 项加成、技能、学习次数、列表顺序与选中项），再走一遍菜单操作。

const FIXTURE := "res://tests/fixtures/pet_synth_oracle.json"
const POS_TOL := 0.05

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func frames(n := 2) -> void:
	for i in range(n):
		await get_tree().process_frame


## 窗口开合在 physics 更新，遮挡在 XPetScene._process 更新；固定等 10 个 physics tick
## 不能保证随后已跑过一次 process（重负载补帧时尤其如此）。先等真实开合终点，再让遮挡刷新。
## 有界等待；超时仍交给原遮挡断言失败，不调用 _clip_status，不改变判定或容差。
func settled_window(w: XMVWindow, target: int) -> void:
	for _frame in 90:
		if w.openness == target:
			await get_tree().process_frame
			return
		await get_tree().process_frame


static func _col(t: String) -> String:
	return (XQuality.parse_rgba(t) if t.begins_with("rgba") else Color(t)).to_html(false)


## 文字 [文字,x,y,宽,对齐,字号,颜色,不透明度 0～255]、图标 [图标号,x,y,不透明度]
static func want_form(ops: Array) -> Array:
	return ops.map(func(o): return [int(o[1]), float(o[2]), float(o[3]), int(o[4])] if o[0] == "i" else [str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[5]), float(o[6]), XEnemy.name_color(str(o[1]), 2, Color(_col(str(o[7])))).to_html(false), int(o[8])])


static func got_form(ops: Array) -> Array:
	return ops.map(func(o): return [int(o[1]), float(o[2]), float(o[3]), roundi(float(o[4]) * 255)] if o[0] == "i" else [str(o[1]), float(o[2]), float(o[3]), float(o[4]), str(o[6]), float(o[7]), (o[8] as Color).to_html(false), roundi(float(o[9]) * 255)])


static func diff(got: Array, want: Array) -> String:
	for i in maxi(got.size(), want.size()):
		if i >= got.size() or i >= want.size():
			return "#%d 条数 %d≠%d %s" % [i, got.size(), want.size(), JSON.stringify(want[i] if i < want.size() else got[i])]
		var g: Array = got[i]
		var w: Array = want[i]
		var bad := g.size() != w.size()
		if not bad:
			for k in w.size():
				if w[k] is String:
					bad = bad or str(g[k]) != w[k]
				else:
					bad = bad or absf(float(g[k]) - float(w[k])) > POS_TOL
		if bad:
			return "#%d got %s want %s" % [i, JSON.stringify(g), JSON.stringify(w)]
	return ""


static func pet_from(p: Dictionary) -> Dictionary:
	var lv := {}
	for k in p.lvSkills:
		lv[str(k)] = int(p.lvSkills[k])
	return {"enemy": int(p.id), "elite": bool(p.elite), "letter": "", "push": p.paramPush.map(func(v): return float(str(v))),
		"skills": p.skills.map(func(v): return int(v)), "lv_skills": lv, "exp": int(p.exp), "ls": int(p.ls[0]), "ls_max": int(p.ls[1])}


func _setup(ref: Dictionary) -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	s.pets.list = ref.pets.map(func(p): return pet_from(p))
	s.gain_item(426, 3)
	s.gain_item(428, 1)
	return s


func feed_ops(s: XState) -> Array:
	var ops := []
	var food := XPets.food_items()
	for i in mini(food.size(), XPetScene.FEED_ROWS):
		ops += XPetScene.feed_row_ops(s, int(food[i]), i * 36.0)
	return ops


func _run() -> void:
	var ref = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check("fixture_loaded", ref is Dictionary and ref.has("result")):
		get_tree().quit.call_deferred(1)
		return
	var s := _setup(ref)
	check("levels", s.pets.list.map(func(p): return XPets.level(p)) == ref.pets.map(func(p): return int(p.lv)))
	check("food_items", XPets.food_items() == ref.feedData.map(func(x): return int(x)), XPets.food_items())
	var d := diff(got_form(feed_ops(s)), want_form(ref.feedList))
	check("feed_list", d == "", d)
	# 喂养第 3 只：棒棒糖、肉排
	check("feed_1", XPets.feed(s, 2, 426), null)
	var p2: Dictionary = s.pets.list[2]
	var f1: Dictionary = ref.afterFeed1
	check("after_feed_1", int(p2.exp) == int(f1.exp) and XPets.level(p2) == int(f1.lv) and p2.skills == f1.skills.map(func(x): return int(x)) and s.item_count(426) == int(f1.n426), [p2.exp, XPets.level(p2), p2.skills])
	d = diff(got_form(feed_ops(s)), want_form(f1.list))
	check("feed_list_after", d == "", d)
	XPets.feed(s, 2, 428)
	var f2: Dictionary = ref.afterFeed2
	check("after_feed_2", int(p2.exp) == int(f2.exp) and XPets.level(p2) == 50 and p2.skills == f2.skills.map(func(x): return int(x)) and s.item_count(428) == int(f2.n428), [p2.exp, p2.skills])
	# 出战宠物与满级不吃，口粮退回
	s.gain_item(426, 1)
	var before := s.item_count(426)
	check("feed_full_refund", not XPets.feed(s, 2, 426) and s.item_count(426) == before)
	XPets.go_to_war(s, 2)
	check("feed_war_refund", not XPets.feed(s, 2, 426) and s.item_count(426) == before)
	XPets.rest(s, 2)
	# 合成
	check("syn_pick", XPets.can_pick(s, 0, -1) and XPets.can_pick(s, 1, 0) and not XPets.can_pick(s, 0, 0))
	var seq: Array = ref.seq
	var k := [0]
	var rnd := func() -> float:
		var v := float(seq[k[0] % seq.size()])
		k[0] += 1
		return v
	var r := XPets.synthesize(s, 0, 1, rnd)
	var res: Dictionary = ref.result
	var pet: Dictionary = s.pets.list[r] if r >= 0 else {}
	var push_ok: bool = not pet.is_empty() and pet.push.size() == res.paramPush.size()
	if push_ok:
		for i in pet.push.size():
			push_ok = push_ok and absf(float(pet.push[i]) - float(res.paramPush[i])) < 1e-9
	check("syn_result", r == int(res.sel) and push_ok and pet.skills == res.skills.map(func(x): return int(x)) and [int(pet.ls), int(pet.ls_max)] == res.ls.map(func(x): return int(x))
		and s.pets.list.map(func(p): return int(p.enemy)) == res.order.map(func(x): return int(x)) and XPets.pet_name(s, pet) == str(res.name),
		[r, pet.get("push"), pet.get("skills"), s.pets.list.map(func(p): return int(p.enemy))])
	await _flow(ref)
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 菜单操作：合成窗、宠物一／二登记与名字后缀、合成；喂养列表
func _flow(ref: Dictionary) -> void:
	var s := _setup(ref)
	var page := XPetScene.new()
	add_child(page)
	await frames()
	var rect := func(w: Control) -> Array: return [w.position.x, w.position.y, w.size.x, w.size.y]
	var near := func(a: Array, b: Array) -> bool:
		for i in 4:
			if absf(float(a[i]) - float(b[i])) > 0.7:
				return false
		return true
	check("geometry", near.call(rect.call(page.feed_win), ref.geo.feed) and near.call(rect.call(page.syn_win), ref.geo.syn), [rect.call(page.feed_win), rect.call(page.syn_win)])
	var syn_ops := []
	for i in XPetScene.SYN_COMMANDS.size():
		syn_ops.append(XPetScene._t(XPetScene.SYN_COMMANDS[i], 6, i * 36.0, 814) + [1.0])
	var d := diff(got_form(syn_ops), want_form(ref.synList))
	check("syn_list", d == "", d)
	# 第 1 只登记为宠物一
	page.select(0)
	page.ok()
	page.cmd = 5
	page.ok()
	check("syn_open", page.mode == "syn" and page.syn == 0)
	await settled_window(page.syn_win, 255)
	check("syn_occludes_status", is_equal_approx(page.status_cover, float(ref.geo.syn[1])))
	page.ok()
	check("syn_a", page.mode == "bottom" and is_same(page.syn_a, s.pets.list[0]) and page.display_name(s.pets.list[0]) == str(ref.afterA.index[0][1])
		and page._status_ops[0][1] == str(ref.afterA.statusName[1]), [page.display_name(s.pets.list[0]), page._status_ops[0]])
	page.cancel()
	# 同一只再登记为宠物二：不行
	page.ok()
	page.cmd = 5
	page.ok()
	page.syn = 1
	page.ok()
	check("syn_same_refused", page.syn_b.is_empty())
	page.cancel()
	page.select(1)
	page.ok()
	page.cmd = 5
	page.ok()
	page.syn = 1
	page.ok()
	var names := []
	for i in 3:
		names.append(page.display_name(s.pets.list[i]))
	check("syn_b_names", names == ref.afterB.index.map(func(o): return str(o[1])), names)
	# 登记完回到底部指令（光标仍在「合成」），再进合成窗按「合成」
	page.ok()
	page.syn = 2
	page.ok()
	check("syn_done", s.pets.list.size() == 2 and page.mode == "index" and page.index == 1 and page.syn_a.is_empty() and page.syn_b.is_empty(), [s.pets.list.size(), page.mode, page.index])
	# 喂养：第 1 只（哥布林士兵，1 级）吃棒棒糖
	page.select(0)
	page.ok()
	page.cmd = 6
	page.ok()
	check("feed_open", page.mode == "feed" and page.feed_index == 0 and (page.feed_win.openness < 255 or page.feed_win._opening))
	await settled_window(page.feed_win, 255)
	check("feed_occludes_status", is_equal_approx(page.status_cover, float(ref.geo.feed[1])))
	page.ok()
	check("feed_done", XPets.level(s.pets.list[0]) == 6 and s.item_count(426) == 2 and page.mode == "feed")
	page.feed_index = 1
	page.ok()
	check("feed_none_buzz", s.item_count(427) == 0 and XPets.level(s.pets.list[0]) == 6)
	page.cancel()
	check("feed_cancel", page.mode == "bottom")
	await settled_window(page.feed_win, 0)
	check("status_restored_after_feed", is_equal_approx(page.status_cover, XPetScene.STATUS_RECT.end.y))
	page.queue_free()
	await frames()
