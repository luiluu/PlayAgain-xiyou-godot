extends Node
## 战斗曲播放器已释放守卫（O-508，XAudio.STOP_FADE_GUARD）：开时已释放的 bgm 被判为「已释放」跳过；
## 关时 XBattleScene._bgm_released 恒假（胜利分支回到无条件操作 bgm 的原样），stop_fade 的签名与空值判断保持改动前原样。
var results := []


func check(name: String, ok: bool, detail = null) -> void:
	results.append({"name": name, "passed": ok})
	print(("PASS " if ok else "FAIL "), name, " ", detail if detail != null else "")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var b := XBattleScene.new()
	var live := AudioStreamPlayer.new()
	add_child(live)
	var dead := AudioStreamPlayer.new()  # 先交给 b.bgm 再释放：b.bgm 留下悬空引用（真实场景同款，类型变量不能直接赋已释放对象）
	var flag0 := XAudio.STOP_FADE_GUARD
	check("default_on", flag0 == true)
	# 开：有效不跳过、已释放跳过、空也跳过（原来会崩）
	XAudio.STOP_FADE_GUARD = true
	b.bgm = live
	check("on_live_not_released", not b._bgm_released())
	b.bgm = dead
	dead.free()
	check("on_freed_released", b._bgm_released())
	b.bgm = null
	check("on_null_released", b._bgm_released())
	# 关：一律不跳过＝回到改动前（无条件操作 bgm）
	XAudio.STOP_FADE_GUARD = false
	b.bgm = live
	check("off_live_not_released", not b._bgm_released())
	var dead2 := AudioStreamPlayer.new()
	b.bgm = dead2
	dead2.free()
	check("off_freed_not_released", not b._bgm_released())
	b.bgm = null
	check("off_null_not_released", not b._bgm_released())
	XAudio.STOP_FADE_GUARD = flag0
	# stop_fade 保持原签名（AudioStreamPlayer 类型参数）；有效播放器行为不变（开关两档）
	var sig := {}
	for m in (XAudio as Script).get_script_method_list():
		if m.name == "stop_fade":
			sig = m
	check("stop_fade_typed_param", not sig.is_empty() and sig.args.size() == 1 and sig.args[0].class_name == &"AudioStreamPlayer", sig.get("args"))
	for on in [true, false]:
		XAudio.STOP_FADE_GUARD = on
		live.volume_db = -3.0
		XAudio.fade_in(live, 5.0)
		XAudio.stop_fade(live)
		check("stop_fade_live_restores_" + str(on), not live.has_meta("fade_tween") and is_equal_approx(live.volume_db, -3.0), live.volume_db)
	XAudio.STOP_FADE_GUARD = flag0
	XAudio.stop_fade(null)
	check("stop_fade_null_ok", true)
	b.free()
	live.queue_free()
	var failed := results.filter(func(r): return not r.passed)
	print("TEST_RESULT=" + JSON.stringify({"passed": results.size() - failed.size(), "total": results.size()}))
	get_tree().quit.call_deferred(1 if failed.size() > 0 else 0)
