class_name XSkinCasinoDialog
extends XSkinConfirm
## 【cc·天启篇·未经审查】T365 卡 Q：赌场数量框新画法（T254 3.19；弹窗）。是统一确认弹窗（XSkinConfirm：整屏压暗 66%、居中面板、标题、说明、一排钮）加一块中间区：
## 两行（持有奖券、最多能抽）、数量选择小件（XSkinStepper，不弹键盘）、状态行（够用绿／不够橙）、抽取进行态的 8px 金色进度条。
## 抽取规则、积分门槛、停止流程、结果消息全部还是 XCasinoBatch 原来的代码；XCasinoDialog 在新界面开着时把 drawing_started／stopping／set_status 交过来。
## 旧页 → 新页（T254 3.19 对应表）：
## - 标题、说明 → 同。「抽数（持有 N 张券，最多 N 抽）」→ 两行「持有奖券 N 张」「最多能抽 N 抽」（20 连抽写「最多能抽 N 次（20 连）」）。
## - 数字输入框＋「MAX」→ 数量选择（「最多」一下到顶，点中间的数字弹键盘手输，按住连加）。
## - 状态行「共 N 抽，消耗 N 张券；积分门槛 …」→ 同一句，够用绿、不够橙。
## - 「取消」「开始抽取」，回车确定、Esc 取消 → 两枚按钮，默认亮「开始抽取」；键照旧（回车＝开始抽取，Esc＝取消）。
## - 抽取进行中：同一张弹窗原地换态——数量选择整排变灰、「开始抽取」藏起来、只剩「停止后续抽取」，状态行跳「已完成 a / b 抽；二阶段 n 次」，上面加一条金色进度条。
## - 按了停止：按钮变灰写「正在完成当前一抽」（20 连时「正在完成当前20连抽」），字照旧。
## 新皮肤关着、或 ENABLED＝false 时 XCasinoDialog 不建这一块，旧框一行不变。

## T365 回退开关：false＝天启篇新皮肤下赌场框也回旧框
static var ENABLED := true
## 玩家可见文字（待小A 审）
const T_STOCK := "持有奖券 %d 张"
const T_MAX_SINGLE := "最多能抽 %d 抽"
const T_MAX_TWENTY := "最多能抽 %d 次（20 连）"
const T_CANCEL := "取消"
const T_START := "开始抽取"
const T_STOP := "停止后续抽取"
const PANEL_W := 520.0
const REGION_H := 152.0      # 中间区高（两行 52＋数量选择 44＋状态行＋进度条）
const ROW_FS := 17

var dlg: XCasinoDialog
var session: Dictionary
var stepper: XSkinStepper
var status_text := ""
var status_bad := false
var phase := "quantity"      # quantity／drawing／stopping


func _init(d: XCasinoDialog) -> void:
	super()
	dlg = d
	session = d.session
	name = "SkinCasinoDialog"
	var rules: Dictionary = session.rules
	var twenty: bool = session.mode == "twenty"
	setup({"title": str(rules.title), "body": ("每次消耗20张券，完整执行一次20连抽，逐次判定二阶段、欧皇之证及原生奖励。" if twenty else "每抽消耗1张券，逐次判定二阶段与欧皇之证。")
		+ "自动选择「赢下所有」，积分不足时停止。", "buttons": [T_CANCEL, T_START], "index": 1, "width": PANEL_W})
	chosen.connect(_on_chosen)
	cancelled.connect(func(): if can_cancel(): XCasinoBatch.cancel())
	stepper = XSkinStepper.new()
	stepper.focused = true   # 键盘落点永远在数量上（旧框：数字框自动取得焦点）
	add_child(stepper)
	stepper.value_changed.connect(func(_v): preview())
	refresh_limit()
	preview()


func can_cancel() -> bool:
	return phase != "stopping"


# ---- 摆位：确认弹窗往下多加一块中间区 ----

func panel_rect() -> Rect2:
	var p := super()
	var h := p.size.y + REGION_H
	return Rect2(p.position.x, (size.y - h) / 2.0, p.size.x, h)


## 中间区的框（相对整屏）
func region_rect() -> Rect2:
	var p := panel_rect()
	var body_end := p.end.y - PAD - BTN_H - 24.0 - REGION_H
	return Rect2(p.position.x + PAD, body_end + 12.0, p.size.x - PAD * 2.0, REGION_H)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		place_stepper()


func place_stepper() -> void:
	if stepper == null:
		return
	var r := region_rect()
	stepper.position = Vector2(r.position.x, r.position.y + 60.0)
	stepper.size = Vector2(r.size.x, XSkinStepper.H)


# ---- 数据（照旧 XCasinoDialog）----

## 现在最多能抽几次；同时刷新两行、数量选择的范围
func refresh_limit() -> int:
	var n := XCasinoBatch.maximum(XState.current, session.mode)
	stepper.set_range(1, maxi(n, 1), stepper.value)
	if phase == "quantity":
		stepper.enabled = n >= 1
	place_stepper()
	queue_redraw()
	return n


func stock_text() -> String:
	return T_STOCK % XCasinoBatch.stock(XState.current)


func max_text() -> String:
	var n := XCasinoBatch.maximum(XState.current, session.mode)
	return (T_MAX_TWENTY if session.mode == "twenty" else T_MAX_SINGLE) % n


## 状态行：同旧「共 N 抽，消耗 N 张券；积分门槛 …」，够用绿、不够橙
func preview() -> void:
	var n := stepper.value
	var cost := int(session.rules.cost)
	var thr := int(session.rules.threshold)
	var s := XState.current
	var enough := n * cost <= XCasinoBatch.stock(s) and int(s.variable(XCasinoBatch.VAR_POINTS)) >= thr
	status_text = "共 %d 抽，消耗 %d 张券；积分门槛 %d。" % [n * cost, n * cost, thr] if n > 0 else ""
	status_bad = not enough
	queue_redraw()


func confirm() -> void:
	var n := refresh_limit()
	var value := stepper.value
	if n < 1 or value < 1 or value > n:
		set_status("请输入1～%d之间的整数。" % n if n >= 1 else "抽奖券不足。", true)
		return
	XCasinoBatch.begin(value)


func press_max() -> void:
	if phase != "quantity":
		return
	var n := refresh_limit()
	if n < 1:
		set_status("抽奖券不足。", true)
		return
	stepper.to_max()
	preview()


## 抽取开始：数量选择整排变灰、「开始抽取」藏起来、只剩「停止后续抽取」
func drawing_started() -> void:
	phase = "drawing"
	stepper.enabled = false
	setup({"title": title, "body": body, "buttons": [T_STOP], "index": 0, "width": PANEL_W})
	status_bad = false
	queue_redraw()


func stopping() -> void:
	phase = "stopping"
	setup({"title": title, "body": body, "buttons": [{"text": "正在完成当前" + ("20连抽" if session.mode == "twenty" else "一抽"), "disabled": true}], "index": 0, "width": PANEL_W})
	queue_redraw()


func set_status(text: String, bad := false) -> void:
	status_text = text
	status_bad = bad
	queue_redraw()


func _on_chosen(i: int) -> void:
	if phase == "quantity":
		if i == 0:
			XCasinoBatch.cancel()
		else:
			confirm()
	elif phase == "drawing":
		XCasinoBatch.cancel()


## 进度（已完成／请求）；没开始为 0
func progress() -> float:
	var req := int(session.get("requested", 0))
	return clampf(float(int(session.get("used", 0))) / float(req), 0.0, 1.0) if req > 0 else 0.0


# ---- 按键：回车＝开始抽取，Esc＝取消（XCasinoDialog._input 接），其余落在数量上 ----

func handle_input(event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	if phase == "quantity":
		if event.is_action_pressed("ui_accept"):
			confirm()
			return true
		if stepper.handle_input(event):
			return true
	return event.is_pressed()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	accept_event()   # 模态：点到面板外也不穿到底下
	if event.button_index != MOUSE_BUTTON_LEFT or event.pressed:
		return
	for i in buttons.size():
		if button_rect(i).has_point(event.position) and not is_disabled(i):
			select(i)
			activate(i)   # 弹窗上点一下就算（不像列表要点两下）
			return


# ---- 画：确认弹窗的壳之外，中间区的两行、状态行、进度条 ----

func _draw() -> void:
	super()
	var f := XUiSkin.font("body")
	var r := region_rect()
	var fs := XUiSkin.fs(ROW_FS)
	_row(f, r.position.x, r.position.y + 2.0, fs, stock_text())
	_row(f, r.position.x, r.position.y + 30.0, fs, max_text())
	var sy := r.position.y + 60.0 + XSkinStepper.H + 12.0
	var col := XUiSkin.TEXT_2
	if status_text != "":
		col = XUiSkin.DOWN if status_bad else (XUiSkin.UP if phase == "quantity" else XUiSkin.TEXT)
	var fit := XSkinList.fit_text(f, status_text, r.size.x, fs, 15)
	XUiSkin.ds(self, f, Vector2(r.position.x, sy + int(fit[1]) * 0.95), str(fit[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit[1]), col)
	if phase != "quantity":
		var bar := Rect2(r.position.x, r.end.y - 10.0, r.size.x, 8.0)
		draw_rect(bar, Color(1, 1, 1, 0.10))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress(), bar.size.y)), XUiSkin.GOLD)


## 一行：「持有奖券 N 张」里的数字金色（GOLD_LIGHT），其余次要字
func _row(f: Font, x: float, y: float, fs: int, text: String) -> void:
	var cur := x
	var re := RegEx.create_from_string("\\d+")
	var pos := 0
	for m in re.search_all(text):
		var pre := text.substr(pos, m.get_start() - pos)
		cur = _seg(f, cur, y, fs, pre, XUiSkin.TEXT_2)
		cur = _seg(f, cur, y, fs, m.get_string(), XUiSkin.GOLD_LIGHT)
		pos = m.get_end()
	_seg(f, cur, y, fs, text.substr(pos), XUiSkin.TEXT_2)


func _seg(f: Font, x: float, y: float, fs: int, t: String, col: Color) -> float:
	if t == "":
		return x
	XUiSkin.ds(self, f, Vector2(x, y + fs * 0.95), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return x + f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
