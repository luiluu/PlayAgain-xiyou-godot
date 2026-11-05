extends Node
## 地图气泡（Sprite_Balloon，ui10）：正式版 SSEP_BattleSpeedUp_v2 把 waitTime 改成 Balloon÷Default÷Default＝12÷2÷2＝3，
## 气泡共 8×8＋3＝67 帧；帧号 7 − max(floor((剩余 − 3)／8), 0)，setup 那帧还没 updateFrame 不画；
## 透明／不透明度 0 的角色照样画气泡（Sprite_Balloon 加在角色精灵的父节点上）。回退开关 MVCharacter.BALLOON_SSEP。

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


## 照 rpg_sprites.js Sprite_Balloon 算的每帧画面（update 后剩余 d，d>0 才 updateFrame），独立于重制实现
static func mv_frames(wait: int) -> Array:
	var out := []
	var d := 8 * 8 + wait
	while d > 0:
		d -= 1
		if d > 0:
			out.append(7 - maxi(floori(float(d - wait) / 8.0), 0))
	return out


func _run() -> void:
	var p := XDB.plugin("SSEP_BattleSpeedUp_v2")
	check("ssep_params", str(p.get("Balloon", "")) == "12" and str(p.get("BattleSpeed (Default)", "")) == "2" and str(p.get("OkayKeyBoost", "")) == "false", p)
	check("wait_is_3", MVCharacter.balloon_wait() == 3, MVCharacter.balloon_wait())
	var ch := MVCharacter.new()
	add_child(ch)
	ch.start_balloon(2)
	check("duration_67", ch._balloon_t == 67, ch._balloon_t)
	check("setup_frame_not_drawn", ch.balloon_frame() == -1, ch.balloon_frame())
	var got := []
	while ch.is_balloon_playing():
		ch.update_character()
		if ch.is_balloon_playing():
			got.append(ch.balloon_frame())
	var want := mv_frames(3)
	check("frames_match_mv", got == want, [got, want])
	check("last_frame_held_10", want.count(7) == 10 and want.count(0) == 8, [want.count(7), want.count(0)])
	ch.transparent = true
	ch.opacity = 0
	ch.start_balloon(1)
	ch.update_character()
	check("transparent_still_has_frame", ch.balloon_frame() == 0 and ch._balloon_layer != null and ch._balloon_layer.visible, ch.balloon_frame())
	MVCharacter.BALLOON_SSEP = false
	ch.start_balloon(1)
	check("rollback_duration_76", ch._balloon_t == 76 and MVCharacter.balloon_wait() == 12, ch._balloon_t)
	got = []
	while ch.is_balloon_playing():
		ch.update_character()
		if ch.is_balloon_playing():
			got.append(ch.balloon_frame())
	check("rollback_frames_mv_default", got == mv_frames(12), got)
	MVCharacter.BALLOON_SSEP = true
	ch.queue_free()
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
