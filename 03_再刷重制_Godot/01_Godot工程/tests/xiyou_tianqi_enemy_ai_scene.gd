extends Node
## 天启篇六维③敌方 AI（T277 r1 P1-3）战斗画面专项：低韧性慌乱战报在真战斗画面 XBattleScene._play 里停得住。
## 三种表现（防御退缩、胡乱普攻、发抖空过）各让 BattleLogic.act 出一次真记录（战报由 XTianqiEnemyAI.take_logs 插在最前），
## 逐物理帧看日志行：战报至少停 FIT_TEXT_FRAMES−2 帧（tianqi_fit 停帧）；对照组去掉 tianqi_fit 时 0～1 帧就没了（返修前的样子）。
var checks := 0
var failures: Array = []


func check(tag: String, ok: bool, detail = null) -> void:
	checks += 1
	if not ok:
		failures.append(tag)
		print("FAIL ", tag, " ", JSON.stringify(detail).left(800))


func frames(n := 1) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	XMessageBox.auto = true
	var s := XState.new_game_blank()
	s.party.clear()
	s.battle_slots.clear()
	for id in [1, 2, 3]:
		s.add_actor(id)
		s.actor(id).add_param(0, 1e12)
		s.actor(id).recover_all()
	var b := XBattleScene.new()
	b.setup(2, true, false, XDB.map(5))
	add_child(b)
	await frames(30)
	var foes: Array = b.logic.alive(b.logic.enemies)
	check("setup", b.logic.actors.size() >= 1 and not foes.is_empty(), [b.logic.actors.size(), foes.size()])
	var e: XEnemy = foes[0]
	var skills := [XDB.rec("Skills", XBattleLogic.GUARD_SKILL), e.attack_skill(), null]
	for k in 3:
		var text := XTianqiEnemyAI.panic_text(e, k)
		e.set_meta(XTianqiEnemyAI.META_PANIC, text)
		var logs: Array = b.logic.act(e, skills[k], null)
		var first: Dictionary = logs[0] if not logs.is_empty() and logs[0] is Dictionary else {}
		check("logs_first_%d" % k, str(first.get("type", "")) == "battle_text" and str(first.get("text", "")) == text and bool(first.get("tianqi_fit", false)), first)
		var shown: int = await _visible_frames(b, logs, text)
		check("stays_%d" % k, shown >= XBattleScene.FIT_TEXT_FRAMES - 2, shown)
		var bare := logs.duplicate(true)
		bare[0].erase("tianqi_fit")
		var bare_shown: int = await _visible_frames(b, bare, text)
		check("bare_gone_%d" % k, bare_shown <= 1, bare_shown)
		for a in b.logic.actors:
			a.recover_all()
		e.recover_all()
	b.queue_free()
	await frames(3)
	XMessageBox.auto = false
	print("TEST_RESULT=" + JSON.stringify({"passed": checks - failures.size(), "total": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


## 跑 _play，逐物理帧数日志里有这句战报的帧数
func _visible_frames(b: XBattleScene, logs: Array, text: String) -> int:
	var done := [false]
	var run := func():
		await b._play(logs)
		done[0] = true
	run.call()
	var n := 0
	for i in 900:
		if b._log_lines.any(func(l): return str(l.text) == text):
			n += 1
		if done[0]:
			break
		await frames(1)
	check("play_finished", done[0])
	return n
