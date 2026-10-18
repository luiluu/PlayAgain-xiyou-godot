extends Node
## 云端代码审查遗留的四处小修（数据用桩表，不依赖转换产物）：
## - 商店代购显示按武器／防具表查（防具与带 <Proxy Buy> 的物品同号时不再显示代购物品）；
## - 宝珠 Element Amplify 元素名写法按 System.elements 找元素号、读对数值；
## - 场景外观子节点有自己材质时保留；
## - 地图角色能当技能动画目标（flashScope 1 闪光只染行走图、3 隐藏不藏气泡）。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))


func _stub_db() -> void:
	XDB._tables["System"] = {"elements": ["", "物理", "火焰"]}
	XDB._tables["Items"] = [null, {"id": 1, "name": "代购券", "note": "<Proxy Buy: 2>", "iconIndex": 1, "description": "", "itypeId": 1},
		{"id": 2, "name": "代购物品", "note": "", "iconIndex": 2, "description": "代购说明", "itypeId": 1}]
	XDB._tables["Armors"] = [null, {"id": 1, "name": "铠甲", "note": "", "iconIndex": 9, "description": "铠甲说明", "etypeId": 4}]
	XDB._tables["Weapons"] = [null]
	XDB._tables["CodexOrbs"] = {}
	XDB._tables["CodexRaces"] = {}


func _shop() -> void:
	var shop := XShop.new()
	shop.goods = [[2, 1, 0, 0], [0, 1, 0, 0]]
	var rows := shop._buy_data().map(func(e): return e.rec.get("name"))
	check("shop_buy_list_names", rows == ["铠甲", "代购物品"], rows)
	shop.free()
	var armor := XItemMarks.shop_display(XItemMarks.shop_rec(2, 1))
	check("shop_armor_keeps_own_name", armor.get("name") == "铠甲" and int(armor.get("iconIndex")) == 9, armor)
	check("shop_armor_display_is_raw_record", not armor.has("kind"), armor.keys())
	var item := XItemMarks.shop_display(XItemMarks.shop_rec(0, 1))
	check("shop_item_proxy_copies_display", item.get("name") == "代购物品" and int(item.get("iconIndex")) == 2 and int(item.get("id")) == 1, item)


func _orbs() -> void:
	var eq := {}
	XOrbs.effect("Element Amplify 火焰: +15%", eq, true, "")
	check("orb_amplify_by_name", is_equal_approx(float(eq.get("yep", {}).get("elementAmplify", {}).get("2", 0.0)), 0.15), eq)
	XOrbs.effect("Element Amplify 火焰: +15%", eq, false, "")
	check("orb_amplify_by_name_detach", is_zero_approx(float(eq.yep.elementAmplify["2"])), eq)
	XOrbs.effect("Element Amplify 1: +10%", eq, true, "")
	check("orb_amplify_by_id", is_equal_approx(float(eq.yep.elementAmplify.get("1", 0.0)), 0.10), eq)
	var before := JSON.stringify(eq)
	XOrbs.effect("Element Amplify 雷电: +10%", eq, true, "")
	check("orb_amplify_unknown_name_ignored", JSON.stringify(eq) == before, eq)


func _scene_material() -> void:
	var bs := XBattlerSprite.new()
	var root := Node2D.new()
	var plain := Sprite2D.new()
	var own := Sprite2D.new()
	var own_mat := CanvasItemMaterial.new()
	own.material = own_mat
	root.add_child(plain)
	root.add_child(own)
	bs.sprite = root
	bs._body_material()
	check("scene_body_material", root.material is ShaderMaterial and plain.use_parent_material)
	check("scene_child_keeps_own_material", own.material == own_mat and not own.use_parent_material)
	root.free()
	bs.free()


func _map_target() -> void:
	var ch := MVCharacter.new()
	add_child(ch)
	check("map_char_is_anim_target", ch.has_method("set_anim_blend") and ch.has_method("set_anim_hidden"))
	ch.set_anim_blend(Color(0, 0, 0, 0))
	check("map_blend_zero_no_material", ch.material == null)
	ch.set_anim_blend(Color(1, 0, 0, 0.5))
	check("map_blend_sets_shader", ch.material is ShaderMaterial and ch.anim_blend().is_equal_approx(Color(1, 0, 0, 0.5)))
	ch.start_balloon(1)
	check("map_balloon_own_layer", ch._balloon_layer != null and not ch._balloon_layer.use_parent_material)
	ch.set_anim_hidden(true)
	check("map_hidden_flag", ch._anim_hidden and ch._balloon_layer.visible)
	ch.set_anim_hidden(false)
	ch.set_anim_blend(Color(0, 0, 0, 0))
	check("map_restored", not ch._anim_hidden and ch.anim_blend().a == 0.0)
	ch.queue_free()


func _run() -> void:
	_stub_db()
	_shop()
	_orbs()
	_scene_material()
	_map_target()
	await get_tree().process_frame
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
