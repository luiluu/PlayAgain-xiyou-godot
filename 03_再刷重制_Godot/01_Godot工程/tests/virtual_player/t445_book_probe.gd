extends "res://tests/virtual_player/k_calibrate.gd"
## T445：沿用 K 探针的养成与木桩，显式装书；--t444 重跑第二批之前的狗逍遥核算。
## godot --headless --audio-driver Dummy --path <工程> res://tests/virtual_player/t445_book_probe.tscn --
##   --tier=all --actors=95,122,163,167,1,2,22,3,12,18 --book-build=normal --noisy --seed=1
## --book-build=normal|empty|balanced|extreme；T444 单段重量用 --t444 --single --actors=1。
## --noisy --seed=101/202/303 为随机样本；不带 --noisy 跑确定值。JSON 输出可加 --out=<路径>。

const EXTREME := [6308, 6328, 6530, 6652, 6307, 6327, 6529, 6660, 6316, 6315, 6528, 6616, 6661,
	6312, 6653, 6662, 6610, 6311, 6658, 6672, 10436, 6651, 6606, 6618, 6509]
const BALANCED_UTILITY := [6504, 6613, 6625, 10432, 6508, 6304, 6563, 6336, 6332, 6664]
# 按实战主系固定，填满运行时 XTier 的 3/4/6 格。K 报表另按天启篇技能卡档位分组。
const NORMAL_SECRETS := {
	95: [2471, 2480, 488, 6159], 122: [2472, 2480, 489], 163: [2471, 2480, 488], 167: [2478, 2480, 489],
	1: [2471, 2480, 6159, 488], 2: [2471, 2480, 489, 6159, 488, 6139], 22: [2471, 2480, 488, 6139, 489, 6159],
	3: [2471, 2480, 488, 489, 6139, 6159],
	12: [2472, 2480, 488, 489, 6139, 6159],
	18: [2472, 2480, 488, 489, 6139, 6159],
}

var book_build := "normal"
var historical := false
var invalid := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--book-build="):
			book_build = arg.trim_prefix("--book-build=")
		elif arg == "--t444":
			historical = true
	if book_build not in ["normal", "empty", "balanced", "extreme"]:
		push_error("未知量数配法：" + book_build)
		get_tree().quit(2)
		return
	super._ready()


func _run() -> void:
	XTianqiLedger.violations.clear()
	if historical:
		XTianqiGeneralBooks.data()
		for sid in XTianqiGeneralBooks.data().get("groups", {}).get("remaining_books", []):
			XTianqiGeneralBooks._skills.erase(int(sid))
	super._run()
	print("BOOK_PROBE " + JSON.stringify({"build": book_build, "historical": historical,
		"violations": XTianqiLedger.violations.size(), "invalid": invalid, "rows": report.rows.size()}))
	if invalid or not XTianqiLedger.violations.is_empty() or report.rows.size() != only.size():
		get_tree().quit.call_deferred(1)


func _secrets(a: XActor) -> void:
	if historical:
		super._secrets(a)
		return
	var loadout: Array = NORMAL_SECRETS.get(a.actor_id, [])
	for sid in loadout:
		a.learn_skill(int(sid))
	var slots := XTianqiSecrets.active_ids(a)
	var limit := XTianqiSecrets.limit(a)
	if slots.size() != limit or not loadout.all(func(sid): return slots.has(sid)):
		invalid = true
		push_error("实战配置未正确装满秘籍格：%d %s / %s，上限 %d" % [a.actor_id, slots, loadout, limit])
	a.set_meta("k_secrets", slots)


func _measure(id: int, tier: String) -> Dictionary:
	var s := _state(id)
	var actor := s.actor(id)
	var lottery: Array = []
	if book_build in ["normal", "balanced"]:
		lottery = EXTREME.slice(0, 15) + BALANCED_UTILITY
	elif book_build == "extreme":
		lottery = EXTREME
	for sid in lottery:
		actor.learn_skill(int(sid))
	if not lottery.all(func(sid): return actor.skill_ids.has(sid)):
		invalid = true
		push_error("抽奖被动未全部学会：%d" % id)
	actor.param_mark_dirty()
	actor.refresh_passive()
	var row := _measure_in(s, actor, tier, true)
	row["lottery_count"] = lottery.size()
	row["ledger_violations"] = XTianqiLedger.violations.size()
	return row
