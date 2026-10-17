extends Node
## 战斗技能动画 MVAnimation 对照正式版 Sprite_Animation 逐帧读数 tests/fixtures/mv_anim_oracle.json
## （ui_reference ?battle_ref=1 的 __animRef.suite()：战斗夹具 4 人、敌群 2）。在真实战斗画面里经 XBattleScene._start_animation
## 播到敌人或角色身上，逐帧比：是否已移除（播完的下一帧）、相对目标的位置、剩余时长、帧序、可见格数、
## 目标混合色（flashScope 1）、目标显示（flashScope 3）、屏幕闪光（flashScope 2）。另查转色相材质、地图动画（无目标）照常播完。

class QuietBattle extends XBattleScene:
	func _main() -> void:
		pass

var results := []
var oracle: Dictionary


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", detail)


func _run() -> void:
	XSave.dir_override = "user://test_xiyou_mv_animation"
	XConfig.path_override = XSave.dir().path_join("options.json")
	var f := FileAccess.open("res://tests/fixtures/mv_anim_oracle.json", FileAccess.READ)
	oracle = JSON.parse_string(f.get_as_text()) if f else {}
	check("oracle_present", oracle.has("traces") and oracle.traces.size() == 5)
	XConfig.set_flag("CombatSkillAnimation", true)
	XState.new_game(3, 1, [8, 9, 10])
	XEnemy.force_roll = 100.0
	var b := QuietBattle.new()
	b.setup(2, true, false, {})
	add_child(b)
	for i in 2:
		await get_tree().physics_frame
	for k in oracle.get("traces", {}):
		_replay(b, k, oracle.traces[k])
	_hue(b)
	_map()
	b.logic.end_battle()
	b.queue_free()
	XConfig.set_battle_speed(4)
	for sp in find_children("*", "AudioStreamPlayer", true, false):
		(sp as AudioStreamPlayer).stop()
	await get_tree().create_timer(0.5, true, false, true).timeout
	DirAccess.remove_absolute(XConfig.path_override)
	DirAccess.remove_absolute(XSave.dir())
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)


## 逐帧推进（不等真实帧：动画关掉自己的 _physics_process，由这里调），每帧的读数与正式版同一行比
func _replay(b: XBattleScene, k: String, t: Dictionary) -> void:
	XConfig.set_battle_speed(int(t.speed))
	var who: XBattler = (b.logic.actors if t.side == "actor" else b.logic.enemies)[int(t.index)]
	var ts: XBattlerSprite = b.sprites[who]
	var a := b._start_animation(int(t.anim), who)
	check("%s_started" % k, a != null and a.rate == int(t.rate))
	if a == null:
		return
	a.set_physics_process(false)
	# 动画图没导出（动画 24 没有技能用到，只在这里对照隐藏目标）时不比可见格数
	var has_sheets := range(2).all(func(i): return a.sheets[i] != null or str(a.anim.get("animation%dName" % (i + 1), "")) == "")
	var bad := []
	var last := {}
	for row in t.frames:
		if is_instance_valid(a) and a.is_inside_tree():
			a._physics_process(1.0 / 60)
		var live := is_instance_valid(a) and a.is_inside_tree()
		var blend := ts.anim_blend()
		var mine := [int(row[0]), 1 if live else 0]
		if live:
			var d := a.position - ts.position
			last = {"d": [d.x, d.y], "cells": a._sprites.filter(func(s): return s.visible).size()}
			mine += [d.x, d.y, a.duration, a.frame_index() if a.playing() else null, last.cells]
		else:
			mine += [last.d[0], last.d[1], 0, null, last.cells]
		mine += [roundi(blend.r * 255), roundi(blend.g * 255), roundi(blend.b * 255), blend.a * 255.0, 1 if ts.sprite.visible else 0]
		var screen := a.flash_opacity() if live and a.flash.visible else 0.0
		var want_screen: float = float(row[12]) if int(row[13]) == 1 else 0.0
		var same: bool = mine.slice(0, 2) == [int(row[0]), int(row[1])] and is_equal_approx(mine[2], float(row[2])) \
			and absf(mine[3] - float(row[3])) <= 0.5 and mine[4] == int(row[4]) and mine[5] == (null if row[5] == null else int(row[5])) \
			and (mine[6] == int(row[6]) or not has_sheets) and absf(mine[10] - float(row[10])) < 0.01 and mine[11] == int(row[11]) \
			and absf(screen - want_screen) < 0.01
		if float(row[10]) > 0.0:
			same = same and mine.slice(7, 10) == [int(row[7]), int(row[8]), int(row[9])]
		if not same:
			bad.append({"mv": row, "godot": mine + [screen]})
	check("%s_frames" % k, bad.is_empty(), bad.slice(0, 3))
	check("%s_restored" % k, ts.anim_blend().a == 0.0 and ts.sprite.visible)


## animation1Hue/animation2Hue：格子用转色相材质，色相取对应的图
func _hue(b: XBattleScene) -> void:
	var t: Dictionary = oracle.traces.get("hue14", {})
	if t.is_empty():
		return
	XConfig.set_battle_speed(4)
	var a := b._start_animation(14, b.logic.enemies[0])
	a.set_physics_process(false)
	var seen := {}
	while a.playing():
		a.advance()
		var cells: Array = a.anim.frames[a.frame]
		for i in cells.size():
			var s := a._sprites[i]
			if not s.visible:
				continue
			var hue := int(a.anim.animation1Hue if int(cells[i][0]) < 100 else a.anim.animation2Hue)
			var m := s.material
			var got := int(m.get_shader_parameter("hue")) if m is ShaderMaterial else 0
			seen["%d:%d" % [hue, got]] = true
	check("hue14_materials", seen.keys().all(func(x): return x.split(":")[0] == x.split(":")[1]) and seen.has("135:135"), seen.keys())
	check("hue14_oracle_hue", int(t.samples.hue) == int(a.anim.animation1Hue))
	a.finish()


## 地图动画（map_scene.show_animation）没有目标：闪光/隐藏只是不作用，rate 4，播完下一帧移除
func _map() -> void:
	XConfig.set_battle_speed(1)
	var host := Node2D.new()
	add_child(host)
	var a := MVAnimation.play(host, 24, Vector2(100, 100))
	a.set_physics_process(false)
	var done := {"v": false}
	a.done.connect(func(): done.v = true)
	var n := 0
	while not done.v and n < 200:
		a._physics_process(1.0 / 60)
		n += 1
	check("map_rate_and_removal", a.rate == 4 and n == a.anim.frames.size() * 4 + 2, n)
	host.queue_free()
