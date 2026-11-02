extends Node
## 【cc·白龙_13·未经审查】审查第 20 期两处小修：
## ① O-142 XYunshangOrders.o_profile_stage：旧档（没有订单档案编号）读档后第一次建档，stage 取当前进阶次数；回退支照原版写 0。
## ② item_eva：哈基米必中剑段（XCat.sure_segment）在甚尔外层，打天与咒缚的甚尔（混乱时）闪避 0，不加影速。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(400))


func _ready() -> void:
	XSave.dir_override = "user://test_xiyou_review20_fix"
	XYunshangOrders.path_override = XSave.dir().path_join(XYunshangOrders.FILE)
	DirAccess.make_dir_recursive_absolute(XSave.dir())
	for on in [true, false]:
		DirAccess.remove_absolute(XYunshangOrders.path_override)
		XYunshangOrders.reload()
		XYunshangOrders.o_profile_stage = on
		var s := XState.new_game(3, 1, [8, 9, 10])
		XState.current = s
		s.actor_advance[XYunshang.ACTOR] = 2  # 旧档：云裳已进阶两次，存档里没有订单档案编号
		var loaded := XState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
		XState.current = loaded
		XYunshangOrders.after_load(loaded, XYunshangOrders.identity(1, "old-save-%s" % on))
		var p = XYunshangOrders.profile(loaded)
		check("stage.%s" % on, p != null and int(p.stage) == (2 if on else 0), p)
	XYunshangOrders.o_profile_stage = true
	# ② 必中剑段不吃甚尔影速
	var s2 := XState.new_game(3, 1, [8, 9, 10])
	XState.current = s2
	var logic := XBattleLogic.new()
	logic.state = s2
	var cat := s2.actor(XCat.ACTOR)
	var toji := s2.actor(XToji.ACTOR)
	toji.learn_skill(XToji.NO_MP)
	toji.refresh_passive()
	var claw := XDB.rec("Skills", 10437)
	var fast := toji.agi > cat.agi * 1.5
	var open := logic.item_eva(cat, claw, toji)
	XCat.segment = {"actor": cat, "sure": true}
	var sure := logic.item_eva(cat, claw, toji)
	XCat.segment = {}
	check("eva.open", fast and open > 0.0, [toji.agi, cat.agi, open])
	check("eva.sure", sure == 0.0, sure)
	print("TEST_RESULT=" + JSON.stringify({"name": "xiyou_review20_fix", "passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
