class_name XRaceMenu
extends Control
## 种族祝福（主菜单「种族祝福」、种族向导与进阶石公共事件 → CodexRaces.openMenu → Scene_CodexBindMenu；正式 installNativeRaceRuntime 的
## defaults／members／actorPage／racePage 与两种确认页），每页一个 XChoiceWindow。行文逐字照搬（参照 race_menu_probe.cjs 的 pages，
## 测试 tests/xiyou_race_menu）；说明按 48 个半角宽换行。规则在 XRace。打开时先补全队数据、领种族补给暂存箱。
## rank：进阶石公共事件 openMenu({rank:N}) 的目标阶，只在从队员页进角色页那一次用（原版之后回到角色页都不带它）。

signal closed

var choice: XChoiceWindow
var rank := 0
## 测试用：每次打开的页 {info, rows}
var log: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = XUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	XUI.menu_background(self)
	choice = XChoiceWindow.new()
	add_child(choice)
	XRace.migrate(s())
	XRace.claim_inbox(s())
	if XRace.default_race(s()) < 0:
		defaults()
	else:
		members()


func s() -> XState:
	return XState.current


func notify(text: String) -> void:
	XToast.show_text(text, true, "race")


func choose(rows: Array, ok: Callable, cancel: Callable, lines := []) -> void:
	var wrapped := XOrbShop.wrap_info(lines)
	log.append({"info": wrapped, "rows": rows.map(func(r): return {"label": str(r.label), "enabled": r.get("enabled", true) != false})})
	choice.open(rows, ok, cancel, wrapped)


func close() -> void:
	closed.emit()


func members() -> void:
	var rows := s().members().map(func(a): return {"label": a.display_name() + " · " + XRace.label(s(), a), "actor": a})
	choose(rows, func(row): actor_page(row.actor, rank), close, ["调整角色祝福；换族保留阶位", "进阶材料七族通用；每名角色首次调整免费"])


func defaults() -> void:
	var rows := []
	for r in 7:
		rows.append({"label": XRace.race_name(r) + "族", "race": r})
	choose(rows, _default_confirm, close, ["选择开局默认祝福"])


func _default_confirm(row: Dictionary) -> void:
	choose([{"label": "确定开局默认"}, {"label": "返回"}], _default_answer.bind(int(row.race)), close,
		XRace.effects(int(row.race), 1) + ["新招募角色默认继承该族，可逐人调整"])


func _default_answer(answer: Dictionary, r: int) -> void:
	if answer.label == "返回":
		defaults()
		return
	XRace.set_default(s(), r, true)
	members()


func race_page(a: XActor) -> void:
	var d := XRace.data(s(), a)
	var rows := []
	for r in 7:
		rows.append({"label": XRace.race_name(r) + "族" + ("（当前）" if int(d.race) == r else ""), "race": r})
	choose(rows, _race_confirm.bind(a), members, [a.display_name() + " 当前：" + XRace.label(s(), a)])


func _race_confirm(row: Dictionary, a: XActor) -> void:
	var d := XRace.data(s(), a)
	var lines := XRace.effects(int(row.race), int(d.rank)) + ["保留当前阶位；" + ("本次调整免费" if bool(d.free) else "消耗忘情水×1")]
	choose([{"label": "确定选择"}, {"label": "返回"}], _race_answer.bind(a, int(row.race)), race_page.bind(a), lines)


func _race_answer(answer: Dictionary, a: XActor, r: int) -> void:
	if answer.label == "返回":
		race_page(a)
		return
	var result := XRace.change(s(), a, r)
	notify(a.display_name() + "：" + XRace.label(s(), a) if result.ok else str(result.reason))
	actor_page(a)


func actor_page(a: XActor, requested := 0) -> void:
	var d := XRace.data(s(), a)
	var rows := [{"label": "调整种族", "key": "race"}]
	if int(d.race) >= 0 and int(d.rank) < 7:
		rows.append({"label": "进阶至第%d阶" % (requested if requested > 0 else int(d.rank) + 1), "key": "rank"})
	if int(d.race) == 3:
		rows.append({"label": "血契：" + ("开启" if bool(d.blood) else "关闭"), "key": "blood"})
	var info := [a.display_name() + "：" + XRace.label(s(), a)]
	info += XRace.effects(int(d.race), int(d.rank)) if int(d.race) >= 0 else ["旧档多族请先选择一种；最高阶位已保留"]
	choose(rows, _actor_row.bind(a, requested), members, info)


func _actor_row(row: Dictionary, a: XActor, requested: int) -> void:
	var d := XRace.data(s(), a)
	match str(row.key):
		"race":
			race_page(a)
		"blood":
			d.blood = not bool(d.blood)
			actor_page(a)
		_:
			var to := requested if requested > 0 else int(d.rank) + 1
			var stone := int(XRace.config().stones[to - 2])
			choose([{"label": "确定进阶"}, {"label": "返回"}], _rank_answer.bind(a, to), actor_page.bind(a, 0),
				["消耗" + str(XDB.rec("Items", stone).get("name", "")) + "×1"] + XRace.effects(int(d.race), to))


func _rank_answer(answer: Dictionary, a: XActor, to: int) -> void:
	if answer.label == "确定进阶":
		var result := XRace.upgrade(s(), a, to)
		notify(a.display_name() + "：" + XRace.label(s(), a) if result.ok else str(result.reason))
	actor_page(a)
