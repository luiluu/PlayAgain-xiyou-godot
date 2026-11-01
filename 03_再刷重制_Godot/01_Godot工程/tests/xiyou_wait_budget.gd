extends Node
## 【cc·哪吒·未经审查】测试等待超时 WaitBudget（tools30）：墙钟与帧数都过了才算超时；进度签名一变就重新计时；USE_FRAMES=false 回到只看墙钟。
const WaitBudget := preload("res://tests/wait_budget.gd")
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
	# 100 毫秒＝6 帧的预算：先在一帧里睡过 100 毫秒（慢机器），帧数没到就还在等
	var w := WaitBudget.new(100)
	check("limit_frames", w.limit_frames == 6, w.limit_frames)
	OS.delay_msec(120)
	check("slow_machine_keeps_waiting", w.waiting(), [Engine.get_process_frames()])
	for i in range(7):
		await get_tree().process_frame
	check("both_out_times_out", not w.waiting())
	# 签名一变就从头计；签名不变时照样到点
	var p := WaitBudget.new(100)
	OS.delay_msec(120)
	for i in range(7):
		await get_tree().process_frame
	check("progress_resets", p.waiting([1]))
	OS.delay_msec(120)
	for i in range(7):
		await get_tree().process_frame
	check("stalled_signature_times_out", not p.waiting([1]))
	check("new_signature_resumes", p.waiting([2]))
	# 回退：只看墙钟
	WaitBudget.USE_FRAMES = false
	var o := WaitBudget.new(100)
	OS.delay_msec(120)
	check("rollback_wall_clock_only", not o.waiting())
	WaitBudget.USE_FRAMES = true
	# 快机器：帧早就够了，墙钟没到还在等
	var f := WaitBudget.new(5000)
	for i in range(400):
		await get_tree().process_frame
	check("fast_machine_waits_for_wall_clock", f.waiting())
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
