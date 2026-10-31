extends Node
## 【cc·悟空·未经审查】称号系统（Star_Designation，XDesignation）：与 mv_oracle/designation_probe.cjs（tests/fixtures/designation_oracle.json）逐例比：
## 称号表（30 条＋kyo 专属 31 号）、ConfigManager.DesignationN（配置只在内存）、事件脚本解锁、条件分支脚本、
## 选择称号的选项文字（原版 \x1b 即 \）与选中后的称号（取消清空、选到 ??? 不变、选到已解锁）、存档往返；另跑一次真实的 ChooseTitle 脚本（宿主选第 1 项）。
const FIXTURE := "res://tests/fixtures/designation_oracle.json"
var passed := 0
var total := 0
var messages: Array = []

func check(label: String, ok: bool, detail = null) -> void:
	total += 1
	if ok:
		passed += 1
	else:
		print("FAIL ", label, " ", JSON.stringify(detail))

func _ready() -> void:
	_run.call_deferred()

## 解释器宿主：选择称号只用到消息与选项
func refresh_events() -> void:
	pass

## 选项窗：记下消息，选第 1 项（下标 0）
func show_message(msg: Dictionary) -> int:
	messages.append(msg)
	return 0

func _oracle(ref: Dictionary, id: String) -> Variant:
	for c in ref.cases:
		if c.id == id:
			return c.observed if c.errors.is_empty() else null
	return null

func _player(s: XState) -> Dictionary:
	return {} if s.designation.is_empty() else {"name": s.designation.name, "icon": float(s.designation.icon), "color": s.designation.color}

func _reset(unlocked: Array) -> XState:
	var s := XState.new_game(2, 1, [8, 9, 10])
	XState.current = s
	XConfig.designations().clear()
	for id in unlocked:
		if int(id) != XDesignation.KYO_ID:
			XConfig.designations()[str(int(id))] = true
	XConfig.achievements().erase(str(XDesignation.KYO_ACHIEVEMENT))
	if unlocked.has(float(XDesignation.KYO_ID)):
		XConfig.achievements()[str(XDesignation.KYO_ACHIEVEMENT)] = true
	return s

func _run() -> void:
	XSave.dir_override = "user://test_xiyou_designation"  # 配置只在内存
	XMessageBox.auto = true
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check("source", ref.sourceIdentity.runtimeInputs == XDB.load_json("manifest.json").runtimeInputs)
	for c in ref.cases:
		check(c.id + ".native", c.errors.is_empty(), c.errors)
	var t = _oracle(ref, "table")
	var got := XDesignation.table().map(func(d): return {"id": float(d.id), "name": d.name, "icon": float(d.icon), "color": d.color})
	check("table", t != null and got == t.list and XDesignation.show_text() == t.showText, [got.size(), t.list.size() if t else null])
	check("config_default", _reset([]) != null and XConfig.designations().is_empty())
	# 事件脚本解锁
	_reset([])
	await MVScript.run("ConfigManager.DesignationN[16] = true; ", MVInterpreter.new(self, 0, 0, []))
	var u = _oracle(ref, "script.unlock")
	check("script_unlock", u != null and XConfig.designations().keys() == u.after.keys() and XDesignation.unlocked(16), XConfig.designations())
	# 条件分支脚本
	var cs = _oracle(ref, "cond.script")
	_reset([])
	var locked = MVScript.eval_expr("ConfigManager.DesignationN[5]")
	_reset([5.0])
	var opened = MVScript.eval_expr("ConfigManager.DesignationN[5]")
	check("cond_script", cs != null and locked == cs.locked and opened == cs.unlocked, [locked, opened, cs])
	# 选项与选中
	for id in ["cancel", "locked", "pick", "pickFirst"]:
		var o = _oracle(ref, "choose." + id)
		var setup: Dictionary = {}
		for c in ref.cases:
			if c.id == "choose." + id:
				setup = c.setup
		var s := _reset(setup.unlocked)
		var labels := XDesignation.choices()
		check("choose.%s.choices" % id, o != null and labels == o.choices.map(func(x): return str(x).replace(char(27), "\\")), [labels.slice(0, 4), o.choices.slice(0, 4) if o else null])
		XDesignation.apply_choice(s, int(setup.branch))
		check("choose.%s.player" % id, o != null and _player(s) == o.player, [_player(s), o.player if o else null])
	# 存档往返
	var sv = _oracle(ref, "save")
	var s2 := _reset([4.0])
	XDesignation.apply_choice(s2, 3)
	var back := XState.from_dict(JSON.parse_string(JSON.stringify(s2.to_dict())))
	check("save_roundtrip", sv != null and _player(s2) == sv.picked and _player(back) == sv.restored, [_player(back), sv])
	# 真实脚本：ChooseTitle 弹选项，自动答第 1 项（征服者，已解锁）
	var s3 := _reset([1.0])
	messages.clear()
	await MVScript.run("Star.Designation.ChooseTitle(); ", MVInterpreter.new(self, 0, 0, []))
	var shown: Dictionary = messages[-1] if not messages.is_empty() else {}
	check("choose_script", s3.designation.get("name", "") == "征服者" and int(s3.designation.icon) == 1468
		and shown.get("choices", []) == XDesignation.choices() and int(shown.get("cancel", 0)) == -2, [s3.designation, shown.keys()])
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": total}))
	get_tree().quit(0 if passed == total else 1)
