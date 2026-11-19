extends Node
## 【cc·T224·未经审查】传送提速（XMapScene.FAST_TRANSFER，O-605）：
## - 光柱动画 117 在地图上按 rate 2 播（37 帧→75 帧＝1.25 秒），别的地图动画仍 rate 4；场所移动黑幕 12 帧。
## - 计时（真实时间，打印给交付单）：光柱＋淡出＋读图＋淡入，开／关各量一次同一张图；开着要比关着快 1 秒以上。
## - 回退：FAST_TRANSFER＝false 回到 rate 4、24 帧。
const TestEnv = preload("res://tests/xiyou_test_env.gd")
var checks := 0
var failures := []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func _ready() -> void:
	_run.call_deferred()


## 一次「光柱（等待）→ 场所移动」：返回 [动画毫秒, 淡出毫秒, 读图毫秒, 淡入毫秒]
func once(map: XMapScene, to: int) -> Array:
	var t0 := Time.get_ticks_usec()
	var anim := map.show_animation(map.player, XMapScene.TRANSFER_ANIM)
	await anim.done
	var t1 := Time.get_ticks_usec()
	await map.transfer_fade(true, 0)
	var t2 := Time.get_ticks_usec()
	await map.load_map(to, 5, 5, 2)
	var t3 := Time.get_ticks_usec()
	await map.transfer_fade(false, 0)
	var t4 := Time.get_ticks_usec()
	return [(t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000, (t4 - t3) / 1000]


func _run() -> void:
	TestEnv.isolate("xiyou_transfer_speed")
	XMessageBox.auto = true
	var s := XState.new_game(3, 1, [8, 10, 9])
	s.map_id = 4
	s.x = 14
	s.y = 23
	var map := XMapScene.new()
	add_child(map)
	for i in 6:
		await get_tree().process_frame
	var a := map.show_animation(map.player, XMapScene.TRANSFER_ANIM)
	check("anim.rate", a.rate == 2 and a.duration == 37 * 2 + 1, [a.rate, a.duration])
	var other := map.show_animation(map.player, 1)
	check("anim.other_rate", other == null or other.rate == 4)
	await a.done
	var on := []
	var off := []
	for to in [29, 37, 178]:
		XMapScene.FAST_TRANSFER = true
		on.append(await once(map, to))
		await map.load_map(4, 14, 23, 2)
		XMapScene.FAST_TRANSFER = false
		off.append(await once(map, to))
		await map.load_map(4, 14, 23, 2)
	XMapScene.FAST_TRANSFER = false
	var b := map.show_animation(map.player, XMapScene.TRANSFER_ANIM)
	check("off.rate", b.rate == 4 and b.duration == 37 * 4 + 1, [b.rate, b.duration])
	await b.done
	XMapScene.FAST_TRANSFER = true
	var sum := func(r): return r.reduce(func(x, y): return x + y, 0)
	for i in on.size():
		print("TIMING map=%d 开 动画%d 淡出%d 读图%d 淡入%d 合计%dms｜关 动画%d 淡出%d 读图%d 淡入%d 合计%dms" % ([[29, 37, 178][i]] + on[i] + [sum.call(on[i])] + off[i] + [sum.call(off[i])]))
		check("faster.%d" % i, sum.call(off[i]) - sum.call(on[i]) > 800, [on[i], off[i]])
		check("anim_on.%d" % i, on[i][0] > 1000 and on[i][0] < 1900, on[i])
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
