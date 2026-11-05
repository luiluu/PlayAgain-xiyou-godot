extends Node
## 【cc·rules·未经审查】portrait1：进阶页的云裳立绘（installNativeYunshangRuntime 第 582 行 Window_ActorAdvancedStatus.update 包装：
## 原 update 之后按 CodexSV.profiles.Yunshang 缩放，scaleFor＝min(72／可见高 132, 129／可见宽 124)≈0.545）；别的角色照原生（格宽不超内容宽一半就 1 倍）。
## MOG_CharPoses 奔跑姿势：插件参数「角色奔跑-3」＝CXK-lan-qiu，3 号艾坤在玩家／跟随位置跑步时换这张，停下后保持 3 帧再换回；
## 别人（没配）跑步照原图。跟随看玩家的保持帧数。
var passed := 0
var total := 0


func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := XState.new_game_blank()
	XState.current = s
	s.switches[2494] = true
	for id in [1, XYunshang.ACTOR]:
		s.add_actor(id)
	var page := XActorAdvancedScene.new()
	add_child(page)
	for i in 4:
		await get_tree().physics_frame
	check("first_is_1", page.current_actor() != null and page.current_actor().actor_id == 1, page.current_actor())
	check("actor1_native_scale", page.sprite.scale == Vector2.ONE, page.sprite.scale)
	var want := minf(72.0 / 132.0, 129.0 / 124.0)
	check("yunshang_scale_value", is_equal_approx(XActorAdvancedScene.yunshang_scale(), want), XActorAdvancedScene.yunshang_scale())
	page.index = page.members.find(s.actor(XYunshang.ACTOR))
	page._draw_status()
	for i in 4:
		await get_tree().physics_frame
	check("yunshang_shown", page.shown_actor == s.actor(XYunshang.ACTOR) and page.sprite.texture != null, page.shown_actor)
	check("yunshang_scale", page.sprite.scale.is_equal_approx(Vector2(want, want)), page.sprite.scale)
	page.queue_free()
	_dash_pose()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total and total > 0 else 1)


func _dash_pose() -> void:
	check("run_param", MVCharacter.run_pose(3) == "CXK-lan-qiu" and MVCharacter.run_pose(1) == "", MVCharacter.run_pose(3))
	var c := MVCharacter.new()
	c.set_image("RenWu_02", 0)
	c._apply_dash_pose(true, 3)
	check("run_on", c.character_name == "CXK-lan-qiu" and c.pose_original == "RenWu_02" and c.character_index == 0, c.character_name)
	var names := []
	for i in 4:
		c._apply_dash_pose(false, 3)
		names.append(c.character_name)
	check("run_hold_3", names == ["CXK-lan-qiu", "CXK-lan-qiu", "CXK-lan-qiu", "RenWu_02"], names)
	var o := MVCharacter.new()
	o.set_image("Actor1", 0)
	o._apply_dash_pose(true, 1)
	check("other_actor_same", o.character_name == "Actor1", o.character_name)
	c.free()
	o.free()
	# 跟随：读玩家的保持帧数；getActorId 取队伍顺序
	var s := XState.new_game_blank()
	XState.current = s
	for id in [1, 3]:
		s.add_actor(id)
	var f := MVFollower.new()
	f.member_index = 1
	f.set_image("RenWu_02", 0)
	MVPlayer.dash_pose = 2
	f._update_pose()
	var on := f.character_name
	MVPlayer.dash_pose = 0
	for i in 4:
		f._update_pose()
	check("follower", on == "CXK-lan-qiu" and f.character_name == "RenWu_02", [on, f.character_name, s.party])
	f.free()
