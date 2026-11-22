class_name XUpdatePage
extends Control
## 自动更新第①批：「检查更新」页（弹在标题上面的一页）。
## 标题的按钮这样接：actions["check_update"] = func(): XUpdatePage.open(self)；红点看 XUpdateClient.instance(get_tree()).has_update()。
## 打开就查一次（手动查不受每天一次的限制），按结果显示五种状态：
##   正在检查／已是最新／有补丁／要换整包／读不到。
## 有补丁时（第②批）：点「立即更新」在游戏内下载（XUpdateInstall：多源、续传、校验），下完备份存档、登记，提示重启生效；
## 下载中可以取消，已下的部分留着下次接着下。XUpdateInstall.ENABLED 关着时照「要换整包」提示去 QQ 群。
## 正在用补丁时页面下方有「退回安装包自带版本」（点两次才执行）；启动失败被自动退回、或版本被撤回时在这里说明。
## 确定／取消键、点按钮、点页面外的暗处都能关。不自动打开网页、不下载任何东西。
## 强制更新（open_forced，XForceUpdate 在进标题前盖上来，Kyo 11-14）：同一页的另一种样子——底色不透明、关不掉（取消键、
## 点暗处都不关），右边的按钮是「退出游戏」；能装补丁时「更新」，下载失败「再试一次」并给手动下载链接，
## 底包太旧（只能换整包）只给手动下载。链接取清单的 download_url，没有就照旧指 QQ 群。玩家点了才打开浏览器。

signal closed

const GROUP_HINT := "请到 QQ 群 " + XFeedback.QQ_GROUP + " 的群文件下载"
const W := 760.0
const LAYER := 90
const SCROLL_STEP := 72.0

## 换掉下载安装那一步（测试用）：Callable(page: XUpdatePage, result: Dictionary)。空＝用 XUpdateInstall。
static var patch_installer: Callable
## 换掉「打开网页」（测试用）：Callable(url: String)。空＝OS.shell_open（安卓会打开系统浏览器）。
static var link_opener: Callable

const DOWNLOADING := "downloading"
const READY := "ready"          # 已下载登记好，等重启
const FAILED := "failed"
const ROLLED := "rolled"        # 已手动退回，等重启

## T361（F-07）回退开关：更新页、更新说明页的框改用 XUiSkin 暖炭底＋1px 旧金细线（同统一确认弹窗 XSkinConfirm），
## 内边距走 8 的网格；false＝回到深紫蓝底＋2px 亮金硬框、22px 上下边距
static var FRAME_V2 := true

## T369（卡 T，T254 §4.2，O-631）回退开关：天启篇新标题上的更新页换新界面样式（XUiSkin 弹窗：宽 640／400、标题 26、橙色问题边、金进度条、
## 次按钮在左主按钮在右、退回改小字链接 3 秒复位、新增「重新检查」「手动下载」位）。是否用新样式由调用处传 use_skin（标题上没有存档，
## XUiSkin.on() 答不上来，见 XUiSkin 那条优化）；false＝照 T361 的暖炭框旧画法，一行不变。
static var SKIN_V1 := true
const SKIN_W := 640.0
const SKIN_W_SMALL := 400.0
const SKIN_MAX_H := 620.0
const ROLLBACK_RESET_SEC := 3.0


## 更新页／更新说明页共用的框（更新说明页旧样式也借它）
static func frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if FRAME_V2:
		style.bg_color = Color(XSkinConfirm.DLG_LOW, 0.98)
		style.border_color = Color(XUiSkin.GOLD, 0.48)
		style.set_border_width_all(1)
		style.set_corner_radius_all(XUiSkin.RADIUS)
		style.anti_aliasing = true
		style.shadow_color = Color(0, 0, 0, 0.62)
		style.shadow_size = 18
		style.shadow_offset = Vector2(0, 8)
		style.content_margin_left = XUiSkin.PAD_LG + XUiSkin.GRID
		style.content_margin_right = XUiSkin.PAD_LG + XUiSkin.GRID
		style.content_margin_top = XUiSkin.PAD_LG
		style.content_margin_bottom = XUiSkin.PAD_LG
		return style
	style.bg_color = Color(0.06, 0.05, 0.1, 0.96)
	style.border_color = Color(0.86, 0.72, 0.38, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


static func dim_color(a: float) -> Color:
	return Color(0.03, 0.024, 0.024, a) if FRAME_V2 else Color(0, 0, 0, a)


static func title_color() -> Color:
	return XUiSkin.GOLD_LIGHT if FRAME_V2 else Color(1.0, 0.86, 0.5)


static func line_color() -> Color:
	return Color(XUiSkin.LINE, 0.35) if FRAME_V2 else Color(0.86, 0.72, 0.38, 0.5)


var client: XUpdateClient
var state := "checking"
var _title: Label
var _body: Label
var _buttons: HBoxContainer
var _primary: Button
var _close: Button
var _panel: PanelContainer
var _scroll: ScrollContainer
var _more: Label
var _rollback: Button
var _form: Button  # 反馈问卷按钮（没有问卷时为 null）
var _rollback_armed := false
var _notice := ""
var installer: XUpdateInstall
## 强制更新模式（open_forced 建的）：关不掉，只能更新、手动下载或退出游戏
var forced := false
var _forced_result: Dictionary = {}
var _action := ""   # 强制模式下主按钮做什么：install／retry／link／cancel／restart
var _link: Button   # 强制模式：下载失败时的「手动下载」按钮
var _recheck: Button  # 强制模式：只能整包时的「重新检查」（重新拉清单，不因失败次数放行）
## 新界面样式（T369）：调用处传 use_skin 决定，不问 XUiSkin.on()
var skin := false
var _notice_l: Label       # 新样式：「上次更新没用上」「已撤回」的橙色小字（旧样式放进正文）
var _verrow: HBoxContainer # 新样式：版本行（新版本号 GOLD_LIGHT）
var _ver_new: Label
var _ver_rest: Label
var _bar_row: HBoxContainer  # 新样式：下载进度条＋百分比
var _bar_fill: ColorRect
var _pct: Label
var _dots: HBoxContainer   # 新样式：检查中三枚金点
var _candle: Control       # 新样式：下好了标题前的小金蜡
var _buttons2: HBoxContainer  # 新样式：下载没完成时「关闭」单独一行
var _rb_gen := 0
var _dots_tween: Tween


## 页面放进单独的 CanvasLayer（盖在标题、logo 和一切画面之上，按整个视口居中），挂在 host 下，关页面时一起删。
static func open(host: Node, use_skin := false) -> XUpdatePage:
	var layer := CanvasLayer.new()
	layer.name = "UpdateLayer"
	layer.layer = LAYER
	var p := XUpdatePage.new()
	p.name = "UpdatePage"
	p.skin = use_skin and SKIN_V1
	layer.add_child(p)
	host.add_child(layer)
	return p


## 强制更新框（XForceUpdate 用）：result 是 XUpdateClient.check 的结果（forced＝true），或 {"state": "checking"}（还在查）。
static func open_forced(host: Node, result: Dictionary, use_skin := false) -> XUpdatePage:
	var layer := CanvasLayer.new()
	layer.name = "UpdateLayer"
	layer.layer = LAYER
	var p := XUpdatePage.new()
	p.name = "UpdatePage"
	p.skin = use_skin and SKIN_V1
	p.forced = true
	p._forced_result = result
	layer.add_child(p)
	host.add_child(layer)
	return p


## 手动下载的去处：清单的 download_url（https）；没有就是空（文字里照旧指 QQ 群）
static func download_link(result: Dictionary) -> String:
	var u = result.get("download_url", "")
	return u if u is String and u.begins_with("https://") else ""


## 强制更新各状态的文字（纯函数）。比 texts 多一个 action：主按钮做什么。
static func forced_texts(result: Dictionary, can_install: bool) -> Dictionary:
	var cur := str(result.get("current", ""))
	var ver := str(result.get("version", ""))
	var url := download_link(result)
	var manual := ("手动下载：%s\n（也可以%s %s）" % [url, GROUP_HINT, ver]) if url != "" else "%s %s" % [GROUP_HINT, ver]
	match str(result.get("state", "")):
		"checking":
			return {"title": "检查更新", "body": "正在检查更新……", "primary": "", "action": ""}
		XUpdateCheck.PATCH, XUpdateCheck.FULL:
			var lines := PackedStringArray()
			var installable: bool = result["state"] == XUpdateCheck.PATCH and can_install
			lines.append("当前版本 %s 已不能继续游戏，请更新到 %s。" % [cur, ver])
			if installable:
				lines.append("更新大小 %s，下载完重启游戏即可，存档会先备份。" % size_text(int(result.get("patch", {}).get("size", 0))))
			else:
				lines.append("这个版本要换新的安装包，游戏内更新不了。")
				lines.append(manual)
			var notes: Array = Array(result.get("notes", PackedStringArray()))
			if not notes.is_empty():
				lines.append("")
				lines.append("更新内容")
				for n in notes:
					lines.append("· " + str(n))
			if installable:
				return {"title": "需要更新", "body": "\n".join(lines), "primary": "更新", "action": "install"}
			return {"title": "需要更新", "body": "\n".join(lines), "primary": "打开下载页" if url != "" else "", "action": "link" if url != "" else ""}
		DOWNLOADING:
			var t := texts(result, true)
			t["body"] = "%s / %s\n可以取消，已下的部分会留着。" % [size_text(int(result.get("done", 0))), size_text(int(result.get("total", 0)))]
			t["action"] = "cancel"
			return t
		FAILED:
			return {"title": "更新没完成", "body": "%s\n可以再试一次（已下的部分接着下），或者%s" % [result.get("message", "网络不通或空间不够。"), manual],
				"primary": "再试一次", "action": "retry"}
		READY:
			var t := texts(result, true)
			t["action"] = "restart"
			return t
	var t := texts(result, can_install)
	t["action"] = ""
	return t


## 各状态显示的标题和正文（纯函数，测试直接比文字）。
static func texts(result: Dictionary, can_install: bool) -> Dictionary:
	var cur := str(result.get("current", ""))
	match str(result.get("state", "")):
		"checking":
			return {"title": "检查更新", "body": "正在检查……", "primary": ""}
		XUpdateCheck.LATEST:
			return {"title": "已是最新版本", "body": "当前版本 %s" % cur, "primary": ""}
		XUpdateCheck.PATCH, XUpdateCheck.FULL:
			# 版本、大小或去哪下放在前面，更新说明放最后（说明长了在框里滚动，按钮始终看得见）
			var lines := PackedStringArray()
			var date := str(result.get("date", ""))
			lines.append("新版本 %s%s" % [result.get("version", ""), "（%s）" % date if date != "" else ""])
			lines.append("当前版本 %s" % cur)
			var patch: Dictionary = result.get("patch", {})
			var installable: bool = result["state"] == XUpdateCheck.PATCH and can_install
			if installable:
				lines.append("更新大小 %s" % size_text(int(patch.get("size", 0))))
			else:
				lines.append("%s %s" % [GROUP_HINT, result.get("version", "")])
			var notes: Array = Array(result.get("notes", PackedStringArray()))
			if not notes.is_empty():
				lines.append("")
				lines.append("更新内容")
				for n in notes:
					lines.append("· " + str(n))
			return {"title": "有新版本", "body": "\n".join(lines), "primary": "立即更新" if installable else ""}
		DOWNLOADING:
			return {"title": "正在下载更新", "body": "%s / %s\n可以取消，已下的部分会留着，下次接着下。" % [size_text(int(result.get("done", 0))), size_text(int(result.get("total", 0)))], "primary": "取消下载"}
		READY:
			return {"title": "更新已准备好", "body": "新版本 %s 已下载，存档已备份。\n重启游戏后生效。" % result.get("version", ""), "primary": "退出游戏" if OS.get_name() == "Android" else "立即重启"}
		FAILED:
			return {"title": "下载没完成", "body": "%s\n已下的部分留着，下次接着下；也可以%s %s。" % [result.get("message", "网络不通或空间不够。"), GROUP_HINT, result.get("version", "")], "primary": "再试一次"}
		ROLLED:
			return {"title": "已退回", "body": "重启游戏后回到%s。" % result.get("target", "安装包自带版本"), "primary": "退出游戏" if OS.get_name() == "Android" else "立即重启"}
		_:
			return {"title": "暂时查不到", "body": "连不上更新服务器。\n当前版本 %s，新版本%s。" % [cur, GROUP_HINT], "primary": ""}


static func size_text(bytes: int) -> String:
	if bytes >= 1048576:
		return "%.1f MB" % (bytes / 1048576.0)
	return "%d KB" % maxi(1, int(ceil(bytes / 1024.0)))


func _ready() -> void:
	# 挂在自己的 CanvasLayer 下（open 里建），锚点铺满就是整个视口
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_fit)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = XUiSkin.theme() if skin else XUI.theme()
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = dim_color(0.95 if forced else 0.72)  # 强制更新：标题整个盖住
	if skin:
		dim.color = Color(0, 0, 0, 1.0 if forced else XSkinConfirm.DIM)  # 新样式：压暗 66%，强制更新底不透明
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # 点框里不算点外面
	_panel.add_theme_stylebox_override("panel", skin_frame(false) if skin else frame_style())
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_title = _lbl("", XUiSkin.FS_CARD if skin else 32, XUiSkin.TEXT_HI if skin else title_color())
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if skin:
		_title.add_theme_font_override("font", XUiSkin.font("title"))
		var trow := HBoxContainer.new()
		trow.alignment = BoxContainer.ALIGNMENT_CENTER
		trow.add_theme_constant_override("separation", 10)
		_candle = _make_candle()
		_candle.visible = false
		trow.add_child(_candle)
		trow.add_child(_title)
		box.add_child(trow)
	else:
		box.add_child(_title)
	var line := ColorRect.new()
	line.color = line_color()
	line.custom_minimum_size = Vector2(0, 1 if FRAME_V2 or skin else 2)
	box.add_child(line)
	if skin:
		_build_skin_head(box)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = false
	box.add_child(_scroll)
	_body = _lbl("", XUiSkin.FS_LIST - 2 if skin else 22, XUiSkin.TEXT if skin else XUI.TEXT)
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_more = _lbl("↑↓ 滚动查看全部内容", XUiSkin.FS_AUX if skin else 16, XUiSkin.TEXT_2 if skin else XUI.DIM)
	_more.name = "More"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_more)
	if skin:
		_build_skin_progress(box)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16 if skin else 32)
	box.add_child(_buttons)
	_primary = _make_button("立即更新", "primary")
	_primary.name = "Primary"
	_primary.pressed.connect(_on_primary)
	_buttons.add_child(_primary)
	_close = _make_button("退出游戏" if forced else "关闭")
	_close.name = "Close"
	_close.pressed.connect(_on_close)
	_buttons.add_child(_close)
	if skin:
		_link = _make_button("手动下载")
		_link.name = "Link"
		_link.pressed.connect(_open_link)
		_link.visible = false
		_buttons.add_child(_link)
		_recheck = _make_button("重新检查")
		_recheck.name = "Recheck"
		_recheck.pressed.connect(_on_recheck)
		_recheck.visible = false
		_buttons.add_child(_recheck)
		_buttons2 = HBoxContainer.new()
		_buttons2.name = "Buttons2"
		_buttons2.alignment = BoxContainer.ALIGNMENT_CENTER
		_buttons2.visible = false
		box.add_child(_buttons2)
		_arrange_buttons(false)  # 次按钮在左、主按钮在右（T254 §4.2）
	elif forced:
		_link = _make_button("手动下载")
		_link.name = "Link"
		_link.pressed.connect(_open_link)
		_link.visible = false
		_buttons.add_child(_link)
		_buttons.move_child(_link, 1)
		_recheck = _make_button("重新检查")
		_recheck.name = "Recheck"
		_recheck.pressed.connect(_on_recheck)
		_recheck.visible = false
		_buttons.add_child(_recheck)
		_buttons.move_child(_recheck, 2)
	# 反馈群（XFeedback）：按钮下面一行，点一下复制群号；不抢焦点，确定／取消键照旧
	if XFeedback.SHOW:
		var fb := XFeedback.make_button(18)
		fb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(fb)
	if XFeedback.SHOW and XFeedback.has_form():
		_form = XFeedback.make_form_button(18)
		_form.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(_form)
	_rollback = _make_rollback()
	_rollback.pressed.connect(_on_rollback)
	_rollback.visible = bool(XUpdateInstall.BootPatchScript.result.get("loaded", false)) and not forced
	box.add_child(_rollback)
	_fit()
	installer = XUpdateInstall.instance(get_tree())
	installer.progress.connect(_on_progress)
	var rb := XUpdateInstall.take_rollback_notice()
	if not rb.is_empty():
		_notice = "上次的更新 %s 没能用上（%s），已退回。\n" % [XUpdateCheck.version_of(int(rb.get("code", 0))), rb.get("reason", "")]
	client = XUpdateClient.instance(get_tree())
	var pending := XUpdateInstall.pending_code()
	if forced:
		show_forced(_forced_result)
		return
	if pending > 0:  # 已经下好登记了，只差重启
		show_result({"state": READY, "version": XUpdateCheck.version_of(pending)})
		return
	show_result({"state": "checking"})
	_check.call_deferred()


func _exit_tree() -> void:
	if _dots_tween != null:
		_dots_tween.kill()
		_dots_tween = null


func _check() -> void:
	var r: Dictionary = await client.check()
	if not is_inside_tree():
		return
	if r.get("revoked", false):  # 现在用的这一版被撤回了：退回上一份，下次启动生效
		var back := XUpdateInstall.rollback(false, "已撤回")
		_notice += "当前版本已被撤回，重启后回到%s。\n" % (XUpdateCheck.version_of(back) if back > 0 else "安装包自带版本")
	show_result(r)


## 强制更新框换成查到的结果（XForceUpdate 查完时调；还在查时给 {"state": "checking"}）。
## 已经下好、只差重启的补丁够新时直接显示「已准备好」。
func show_forced(result: Dictionary) -> void:
	_forced_result = result
	var pending := XUpdateInstall.pending_code()
	if pending > 0 and pending >= int(result.get("min_playable", 0)) and str(result.get("state", "")) != "checking":
		show_result({"state": READY, "version": XUpdateCheck.version_of(pending), "download_url": download_link(result)})
		return
	show_result(result)


func show_result(result: Dictionary) -> void:
	state = str(result.get("state", XUpdateCheck.BAD))
	if forced and download_link(result) == "" and download_link(_forced_result) != "":
		result["download_url"] = _forced_result["download_url"]  # 下载中、失败这些状态也带着手动下载链接
	set_meta("result", result)
	var can_install := patch_installer.is_valid() or XUpdateInstall.ENABLED
	var t := forced_texts(result, can_install) if forced else texts(result, can_install)
	_action = str(t.get("action", ""))
	if skin:
		_show_skin(result, t)
		return
	_title.text = t["title"]
	_set_body(_notice + t["body"])
	_primary.visible = t["primary"] != ""
	_primary.text = t["primary"] if t["primary"] != "" else "立即更新"
	if forced:
		_close.text = "退出游戏"
		# 失败时、或上次的更新没用上（_notice）时，旁边给「手动下载」（主按钮已经是打开下载页时不重复）
		_link.visible = download_link(result) != "" and _action != "link" and (state == FAILED or _notice != "")
		_recheck.visible = state == XUpdateCheck.FULL or (state == XUpdateCheck.PATCH and _action != "install")
		_recheck.disabled = false
	else:
		_close.text = "稍后再说" if state == XUpdateCheck.PATCH and _primary.visible else "关闭"
	_scroll.scroll_vertical = 0
	_focus_default.call_deferred()


# ---------------- T369 新界面样式（skin＝true 才走；旧样式不经过这里） ----------------

func _lbl(text: String, fs: int, col: Color) -> Label:
	if skin:
		var l := Label.new()
		l.text = text
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", col)
		l.add_theme_constant_override("outline_size", XUiSkin.outline_size())
		l.add_theme_color_override("font_outline_color", XUiSkin.outline_color())
		return l
	return XUI.label(text, fs, col)


## 新样式的弹窗框：同统一确认弹窗（DLG_LOW 底、灰细线）；danger＝出了问题的状态，边用 DOWN 橙
static func skin_frame(danger: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(XSkinConfirm.DLG_LOW, 0.98)
	st.border_color = Color(XUiSkin.DOWN, 0.9) if danger else Color(XUiSkin.line_c(), 0.42)
	st.set_border_width_all(2 if danger else 1)
	st.set_corner_radius_all(XUiSkin.RADIUS)
	st.anti_aliasing = true
	st.shadow_color = Color(0, 0, 0, 0.62)
	st.shadow_size = 18
	st.shadow_offset = Vector2(0, 8)
	st.content_margin_left = 32
	st.content_margin_right = 32
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	return st


## 出了问题的状态：下载没完成，和强制更新的「需要更新」
static func is_problem(st: String, is_forced: bool) -> bool:
	return st == FAILED or (is_forced and st in [XUpdateCheck.PATCH, XUpdateCheck.FULL])


## 内容少的状态宽 400，其余 640
static func skin_narrow(st: String) -> bool:
	return st in ["checking", XUpdateCheck.LATEST, XUpdateCheck.BAD, ROLLED, READY]


func _panel_w() -> float:
	if skin:
		return SKIN_W_SMALL if skin_narrow(state) else SKIN_W
	return W


func _make_candle() -> Control:
	var c := Control.new()
	c.name = "Candle"
	c.custom_minimum_size = Vector2(12, 24)
	var wax := ColorRect.new()
	wax.color = XUiSkin.GOLD
	wax.position = Vector2(3, 10)
	wax.size = Vector2(6, 14)
	var flame := ColorRect.new()
	flame.color = XUiSkin.GOLD_LIGHT
	flame.position = Vector2(4, 3)
	flame.size = Vector2(4, 6)
	c.add_child(wax)
	c.add_child(flame)
	return c


func _build_skin_head(box: VBoxContainer) -> void:
	_verrow = HBoxContainer.new()
	_verrow.name = "VersionRow"
	_verrow.alignment = BoxContainer.ALIGNMENT_CENTER
	_verrow.visible = false
	var a := _lbl("新版本 ", XUiSkin.FS_AUX, XUiSkin.TEXT_2)
	_ver_new = _lbl("", XUiSkin.FS_AUX, XUiSkin.GOLD_LIGHT)
	_ver_new.name = "NewVersion"
	_ver_rest = _lbl("", XUiSkin.FS_AUX, XUiSkin.TEXT_2)
	_verrow.add_child(a)
	_verrow.add_child(_ver_new)
	_verrow.add_child(_ver_rest)
	box.add_child(_verrow)
	_notice_l = _lbl("", XUiSkin.FS_AUX, XUiSkin.DOWN)
	_notice_l.name = "Notice"
	_notice_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_l.visible = false
	box.add_child(_notice_l)


func _build_skin_progress(box: VBoxContainer) -> void:
	_dots = HBoxContainer.new()
	_dots.name = "Dots"
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	_dots.visible = false
	for i in 3:
		var d := ColorRect.new()
		d.color = XUiSkin.GOLD
		d.custom_minimum_size = Vector2(8, 8)
		d.modulate.a = 0.35
		_dots.add_child(d)
	box.add_child(_dots)
	_bar_row = HBoxContainer.new()
	_bar_row.name = "ProgressRow"
	_bar_row.add_theme_constant_override("separation", 12)
	_bar_row.visible = false
	var track := ColorRect.new()
	track.name = "ProgressTrack"
	track.color = Color(1, 1, 1, 0.12)
	track.custom_minimum_size = Vector2(0, 8)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar_fill = ColorRect.new()
	_bar_fill.name = "ProgressFill"
	_bar_fill.color = XUiSkin.GOLD
	_bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_bar_fill.anchor_right = 0.0
	track.add_child(_bar_fill)
	_bar_row.add_child(track)
	_pct = _lbl("0%", XUiSkin.FS_AUX, XUiSkin.TEXT_2)
	_pct.name = "Percent"
	_bar_row.add_child(_pct)
	box.add_child(_bar_row)


func _set_progress(done: int, total: int) -> void:
	if _bar_fill == null:
		return
	var r := clampf(float(done) / float(maxi(1, total)), 0.0, 1.0)
	_bar_fill.anchor_right = r
	_bar_fill.offset_right = 0.0
	_pct.text = "%d%%" % int(round(r * 100.0))


func _make_rollback() -> Button:
	if not skin:
		var b := XUI.button("退回安装包自带版本", 36)
		b.name = "Rollback"
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 18)
		return b
	# 新样式：弹窗底一行带下划线的小字链接；点一下变红色选中条，再点才执行
	var l := Button.new()
	l.name = "Rollback"
	l.text = "退回安装包自带版本"
	l.alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_override("font", XUiSkin.font("body"))
	l.add_theme_font_size_override("font_size", XUiSkin.FS_AUX)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		l.add_theme_color_override(k, XUiSkin.TEXT_2)
	_style_rollback(false, l)
	return l


## armed＝红色选中条；否则透明底、字下一条细线
func _style_rollback(armed: bool, b: Button = null) -> void:
	var l := b if b != null else _rollback
	var old := l.get_node_or_null("Underline")
	if old != null:
		l.remove_child(old)
		old.queue_free()
	if armed:
		var sel := XSkinButton.select(null, XUiSkin.SelState.FOCUS)
		for st in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
			l.add_theme_stylebox_override(st, sel)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			l.add_theme_color_override(k, XUiSkin.TEXT_HI)
		return
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 4
	flat.content_margin_bottom = 6
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		l.add_theme_stylebox_override(st, flat)
	var foc := XSkinButton.select(flat, XUiSkin.SelState.FOCUS)
	l.add_theme_stylebox_override("focus", foc)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		l.add_theme_color_override(k, XUiSkin.TEXT_2)
	var u := ColorRect.new()
	u.name = "Underline"
	u.color = Color(XUiSkin.TEXT_2, 0.7)
	u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	u.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	u.offset_left = 12
	u.offset_right = -12
	u.offset_top = -4
	u.offset_bottom = -3
	l.add_child(u)


## 3 秒没点第二下：变回去（gen 防旧计时器误伤新一轮）
func _rollback_reset(gen: int) -> void:
	if gen != _rb_gen or not _rollback_armed or _rollback == null or not is_instance_valid(_rollback):
		return
	_rollback_armed = false
	_rollback.text = "退回安装包自带版本"
	_style_rollback(false)


## 按钮从左到右：次按钮（关闭／退出游戏）、手动下载、重新检查、主按钮；second_row＝关闭挪到第二排（下载没完成）
func _arrange_buttons(second_row: bool) -> void:
	var order: Array = [_link, _recheck, _primary] if second_row else [_close, _link, _recheck, _primary]
	var home: Node = _buttons2 if second_row else _buttons
	if _close.get_parent() != home:
		_close.reparent(home, false)
	var i := 0
	for b in order:
		_buttons.move_child(b, i)
		i += 1
	_buttons2.visible = second_row


## 新样式下各状态的显示（_action 已定）：标题／边／版本行／橙字／进度条／按钮个数与文字
func _show_skin(result: Dictionary, t: Dictionary) -> void:
	var problem := is_problem(state, forced)
	_panel.add_theme_stylebox_override("panel", skin_frame(problem))
	_title.text = t["title"]
	_title.add_theme_color_override("font_color", XUiSkin.DOWN if problem else XUiSkin.TEXT_HI)
	_candle.visible = state == READY
	var body: String = t["body"]
	var is_new := state in [XUpdateCheck.PATCH, XUpdateCheck.FULL] and not forced
	_verrow.visible = is_new
	if is_new:  # 版本行单独一行（新版本号淡金）；正文里的前两行（新版本、当前版本）去掉
		_ver_new.text = str(result.get("version", ""))
		var date := str(result.get("date", ""))
		_ver_rest.text = "%s  ·  当前版本 %s" % ["（%s）" % date if date != "" else "", result.get("current", "")]
		body = "\n".join(Array(body.split("\n")).slice(2))
	body = body.replace("· ", "◆ ")  # 更新内容的小菱形
	_notice_l.visible = _notice != ""
	_notice_l.text = _notice.strip_edges()
	_set_body(body)
	var downloading := state == DOWNLOADING
	_bar_row.visible = downloading
	if downloading:
		_set_progress(int(result.get("done", 0)), int(result.get("total", 0)))
	_set_dots(state == "checking")
	# 按钮
	var url := download_link(result)
	if url == "" and result.get("source") is Dictionary:
		url = download_link(result["source"])
	if url == "" and forced:
		url = download_link(_forced_result)
	if url != "" and download_link(result) == "":
		result["download_url"] = url
	var primary_text: String = t["primary"]
	if not forced and state in [XUpdateCheck.PATCH, XUpdateCheck.FULL] and primary_text == "" and url != "":
		primary_text = "打开下载页"  # 要换整包：和强制更新同一个按钮，点了换成「已打开（链接已复制）」
		_action = "link"
	_primary.visible = primary_text != ""
	_primary.text = primary_text if primary_text != "" else "立即更新"
	if forced:
		_close.text = "退出游戏"
		_link.visible = url != "" and _action != "link" and (state == FAILED or _notice != "")
		_recheck.visible = state == XUpdateCheck.FULL or (state == XUpdateCheck.PATCH and _action != "install")
	else:
		_close.text = "稍后再说" if (state == XUpdateCheck.PATCH and _primary.visible) or state == READY else "关闭"
		_link.visible = state == FAILED and url != ""
		_recheck.visible = state in [XUpdateCheck.LATEST, XUpdateCheck.BAD]
	_recheck.disabled = false
	_recheck.text = "重新检查"
	if _link != null:
		_link.text = "手动下载"
	_arrange_buttons(state == FAILED and not forced)
	_scroll.scroll_vertical = 0
	_fit()
	_focus_default.call_deferred()


## 检查中：三枚金点依次亮（动效「全部」档才动，简化档、关：静止）
func _set_dots(on: bool) -> void:
	if _dots_tween != null:
		_dots_tween.kill()
		_dots_tween = null
	_dots.visible = on
	if not on:
		return
	for d in _dots.get_children():
		d.modulate.a = 0.35
	if not XUiSkin.breathing():
		return
	_dots_tween = create_tween().set_loops()
	for d in _dots.get_children():
		_dots_tween.tween_property(d, "modulate:a", 1.0, 0.25)
		_dots_tween.tween_property(d, "modulate:a", 0.35, 0.15)


func _set_body(text: String) -> void:
	_body.text = text
	_fit()


## 框的宽高跟着视口：说明区最多占到放得下按钮为止，超出就在框里滚动。
func _fit() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var w := minf(_panel_w(), vp.x - 64.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	var inner := w - 64.0
	_body.custom_minimum_size = Vector2(inner - 12.0, 0)
	var lh := float(_body.get_line_height())
	var lines := _wrapped_lines(inner - 12.0)
	var want := lines * (lh + 2.0) + 4.0
	# 标题、分隔线、提示、按钮、退回、上下边距大约占的高度
	var chrome := 44.0 + 2.0 + 22.0 + 48.0 + (44.0 if _rollback != null and _rollback.visible else 0.0) + 44.0 + 12.0 * 5
	if _form != null:  # 反馈问卷一行（XFeedback.has_form）
		chrome += _form.get_combined_minimum_size().y + 12.0
	if skin:  # 版本行、橙色小字、进度条、第二排按钮（可见时）各占一行
		for c in [_verrow, _notice_l, _bar_row, _dots, _buttons2]:
			if c != null and c.visible:
				chrome += c.get_combined_minimum_size().y + 12.0
	var cap := maxf(120.0, vp.y - 64.0 - chrome)
	if skin:  # 弹窗最高 620（字体 130% 时跟着内容长到这里，再多在框里滚）
		cap = minf(cap, maxf(120.0, SKIN_MAX_H - chrome - 48.0))
	var h := minf(want, cap)
	_scroll.custom_minimum_size = Vector2(inner, h)
	_more.visible = want > cap + 1.0


## 按给定宽度估算换行后的行数（Label 还没排版时 get_line_count 不准）
func _wrapped_lines(width: float) -> int:
	var font := _body.get_theme_font("font")
	var fs := _body.get_theme_font_size("font_size")
	var n := 0
	for para in _body.text.split("\n"):
		var pw := font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		n += maxi(1, int(ceil(pw / maxf(1.0, width))))
	return n


func _focus_default() -> void:
	if is_inside_tree():
		(_primary if _primary.visible else _close).grab_focus()


func _focus_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if skin:  # 新样式：按画面上的次序（左→右、第二排、退回链接）
		for row in [_buttons, _buttons2]:
			for c in row.get_children():
				if c is Button and c.visible:
					out.append(c)
		if _rollback != null and _rollback.visible:
			out.append(_rollback)
		return out
	for b in [_primary, _link, _recheck, _close, _rollback]:
		if b != null and b.visible:
			out.append(b)
	return out


## 当前选中的按钮（焦点不在本页按钮上时按默认算）
func focused_button() -> Button:
	var f := get_viewport().gui_get_focus_owner()
	var bs := _focus_buttons()
	if f in bs:
		return f
	return _primary if _primary.visible else _close


func _make_button(text: String, kind := "") -> Button:
	if skin:
		var sb := XSkinButton.apply(Button.new(), kind, XUiSkin.FS_LIST)
		sb.text = text
		sb.custom_minimum_size = Vector2(168, 46)
		sb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		return sb
	var b := XUI.button(text, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.x = 200
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.06)
	normal.border_color = Color(0.86, 0.72, 0.38, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(0.86, 0.72, 0.38, 0.28)
	hot.border_color = Color(1.0, 0.86, 0.5)
	hot.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, hot)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.7))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.7))
	return b


func _on_primary() -> void:
	if forced or (skin and _action == "link"):
		match _action:
			"link":
				_open_link()
				return
			"install":
				if patch_installer.is_valid():
					patch_installer.call(self, get_meta("result"))
				else:
					_install(get_meta("result"))
				return
	match state:
		XUpdateCheck.PATCH:
			if patch_installer.is_valid():
				patch_installer.call(self, get_meta("result"))
			else:
				_install(get_meta("result"))
		DOWNLOADING:
			installer.cancel()
		FAILED:
			_install(get_meta("result").get("source", {}))
		READY, ROLLED:
			XUpdateInstall.restart(get_tree())


## 下载、校验、备份存档、登记。result 是 state＝patch 的检查结果。
func _install(result: Dictionary) -> void:
	var patch: Dictionary = result.get("patch", {})
	if patch.is_empty() or installer.busy:
		return
	var total := int(patch.get("size", 0))
	if not XUpdateInstall.enough_space(total):
		show_result({"state": FAILED, "version": result.get("version", ""), "message": "剩余空间不够。", "source": result})
		return
	show_result({"state": DOWNLOADING, "done": 0, "total": total, "source": result})
	var base := XUpdateClient.base_code()
	var path := await installer.download(patch, base)
	var ok := path != "" and XUpdateInstall.register(patch, base)
	if ok:
		XWhatsNew.note_install(result, patch)  # 记下这一版的说明，重启进游戏后弹一次「本次更新内容」（update-whatsnew；页面关了也照记）
	if not is_inside_tree():
		return
	if ok:
		show_result({"state": READY, "version": result.get("version", "")})
	else:
		show_result({"state": FAILED, "version": result.get("version", ""), "source": result,
			"message": "已取消。" if path == "" and installer._cancelled else ("存档备份或登记没成功。" if path != "" else "网络不通或文件不对。")})


func _on_progress(done: int, total: int) -> void:
	if state == DOWNLOADING:
		var r: Dictionary = get_meta("result")
		r["done"] = done
		r["total"] = total
		_body.text = ("" if skin else _notice) + (forced_texts(r, true) if forced else texts(r, true))["body"]
		_set_progress(done, total)


func _on_rollback() -> void:
	if not _rollback_armed:
		_rollback_armed = true
		_rollback.text = "再点一次确认退回"
		if skin:  # 新样式：变成红色选中条，3 秒不点自己变回去
			_style_rollback(true)
			_rb_gen += 1
			var gen := _rb_gen
			get_tree().create_timer(ROLLBACK_RESET_SEC, true, false, true).timeout.connect(func(): _rollback_reset(gen))
		return
	XUpdateInstall.rollback(true)
	_rollback.visible = false
	show_result({"state": ROLLED})


## 强制更新「重新检查」：重新拉清单。不用再强制了（Kyo 调低了 min_playable、或已是最新）就关框放行；
## 还要强制就换成新结果；连不上就留在框里提示，不因为查不到放行（启动时连不上才放行）。
func _on_recheck() -> void:
	if client == null or client.checking:
		return
	if skin and not forced:  # 新样式：已是最新／读不到时的「重新检查」，重查一遍清单
		show_result({"state": "checking"})
		_check.call_deferred()
		return
	_recheck.disabled = true
	_recheck.text = "正在检查……"
	var r: Dictionary = await client.check()
	if not is_inside_tree():
		return
	_recheck.text = "重新检查"
	_recheck.disabled = false
	if str(r.get("state", "")) == XUpdateCheck.BAD:
		show_result(get_meta("result"))
		_set_body("暂时连不上更新服务器，请稍后再点「重新检查」。\n" + _body.text)
		return
	XForceUpdate.result = r
	if not XForceUpdate.blocks(r):
		close_page()
		return
	show_forced(r)


## 右边的按钮：平时是关闭；强制更新时是退出游戏
func _on_close() -> void:
	if forced:
		get_tree().quit()
	else:
		close_page()


## 打开手动下载页（系统浏览器；安卓打开默认浏览器），同时把链接复制到剪贴板，打不开也能自己粘贴
func _open_link() -> void:
	var url := download_link(get_meta("result", {}))
	if url == "":
		url = download_link(_forced_result)
	if url == "":
		return
	DisplayServer.clipboard_set(url)
	if link_opener.is_valid():
		link_opener.call(url)
	else:
		OS.shell_open(url)
	if _link != null and _link.visible:
		_link.text = "已打开（链接已复制）"
	elif _action == "link":
		_primary.text = "已打开（链接已复制）"


## 关掉这一页。强制更新框只由 XForceUpdate 关（查完不用拦、或等太久放行），玩家的按键、点击关不掉。
func close_page() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	var layer := get_parent()
	if layer is CanvasLayer and layer.name == "UpdateLayer":
		layer.queue_free()
	else:
		queue_free()


func _gui_input(event: InputEvent) -> void:
	# 点到框外的暗处才关（框里的空白、滚轮都不算）
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		accept_event()
		if not forced and not _panel.get_global_rect().has_point(event.global_position):
			close_page()


## 这一页开着时键盘、手柄全部在这里处理，一个都不漏到下面的标题菜单：
## 左右／Tab 换按钮，上下／翻页键滚动说明，确定键按下选中的按钮，取消键关掉。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		return
	XKeyMap.handled(self)
	if is_queued_for_deletion() or not event.is_pressed():
		return
	if event.is_action_pressed("ui_cancel"):
		if not forced:  # 强制更新关不掉
			close_page()
	elif event.is_action_pressed("ui_accept"):
		focused_button().pressed.emit()
	elif event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_focus_prev", true):
		_move_focus(-1)
	elif event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_focus_next", true):
		_move_focus(1)
	elif event.is_action_pressed("ui_up", true):
		_scroll.scroll_vertical -= int(SCROLL_STEP)
	elif event.is_action_pressed("ui_down", true):
		_scroll.scroll_vertical += int(SCROLL_STEP)
	elif event.is_action_pressed("ui_page_up", true):
		_scroll.scroll_vertical -= int(_scroll.size.y * 0.8)
	elif event.is_action_pressed("ui_page_down", true):
		_scroll.scroll_vertical += int(_scroll.size.y * 0.8)


func _move_focus(d: int) -> void:
	var bs := _focus_buttons()
	if bs.is_empty():
		return
	var i := bs.find(focused_button())
	bs[posmod(i + d, bs.size())].grab_focus()
