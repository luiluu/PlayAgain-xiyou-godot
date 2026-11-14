class_name XForceUpdate
extends RefCounted
## 【cc·force-update·未经审查】发行版强制更新（Kyo 2026-11-14：很多玩家看不到检查更新的红点，一直停在旧版）。
## 每次启动（发行构建、非无头）在西游标题的 _ready 里先查一次清单（XUpdateClient.check，同一套源、验签和超时），
## 片头动画、声明屏放的时候在后台查；到出标题时：
##   - 查到「强制」（XUpdateCheck.evaluate 的 forced：现在运行的号低于清单的 min_playable）→ 盖一层强制更新框
##     （XUpdatePage.open_forced：不能关、不能进标题；能装补丁就「更新」，失败「再试一次」＋手动下载；底包太旧只给手动下载）；
##   - 连不上、清单坏、验签不过、没有 min_playable、版本够新 → 放行，照旧红点提示；连不上时标题角落提示一行「未能检查更新」；
##   - 还没查完 → 先盖强制更新框的「正在检查」状态（不能关），查完按上面处理；等满 WAIT_SEC 还没回来就放行，
##     之后结果回来、人还在标题且要强制，再把框盖上来。
## 一次运行只拦这一处（标题），进了游戏不再弹。
## 回退开关 ENABLED（O-待定-1）= false：启动不查、不拦，回到原来只有红点的样子。

## O-待定-1 开关：false 回退为不强制（启动不查，只有标题的每天一次静默查和红点）。
static var ENABLED := true
## 出标题时还没查完，最多等这么久就放行（秒）。单个源的超时在 XUpdateClient.TIMEOUT_SEC。
const DEFAULT_WAIT_SEC := 8.0  # Kyo 还没定，协调 11-14 建议 8 秒
static var WAIT_SEC := DEFAULT_WAIT_SEC
## 只给测试用：无头也照发行构建走（真无头跑的冒烟默认不联网、不拦）。
static var allow_headless := false

const OFFLINE_HINT := "未能检查更新"

## 这次运行查到的结果（XUpdateCheck.evaluate 的返回）；空＝还没查完或没查
static var result: Dictionary = {}
static var _started := false
static var _done := false


## 这次运行要不要查（发行构建、非无头、两个开关都开着）
static func wanted() -> bool:
	if not ENABLED or not XUpdateClient.ENABLED:
		return false
	if not ReleaseEntry.is_release():
		return false
	return allow_headless or DisplayServer.get_name() != "headless"


## 测试用：清掉这次运行的记录
static func reset() -> void:
	result = {}
	_started = false
	_done = false


## 西游标题 _ready 一开始调：后台开始查（一次运行只查一次）。
static func begin(tree: SceneTree) -> void:
	if _started or not wanted():
		return
	_started = true
	_run(tree)


static func _run(tree: SceneTree) -> void:
	var r: Dictionary = await XUpdateClient.instance(tree).check()
	result = r
	_done = true


## 这个结果要不要拦
static func blocks(r: Dictionary) -> bool:
	return bool(r.get("forced", false)) and str(r.get("state", "")) in [XUpdateCheck.PATCH, XUpdateCheck.FULL]


## 标题建好后调（host 是西游标题节点）。要拦就盖强制更新框，返回那一页；不拦返回 null。
## 连不上时在 hint_parent 里放一行「未能检查更新」（给了才放）。
static func on_title(host: Node, hint_parent: Control = null) -> XUpdatePage:
	if not _started:
		return null
	if host.get_node_or_null("UpdateLayer/UpdatePage") is XUpdatePage:  # 已经盖着（从子页回到标题时）
		var p := host.get_node("UpdateLayer/UpdatePage") as XUpdatePage
		if p.forced and not p.is_queued_for_deletion():
			return p
	if _done:
		if blocks(result):
			return XUpdatePage.open_forced(host, result)
		if str(result.get("state", "")) == XUpdateCheck.BAD and hint_parent != null:
			_add_hint(hint_parent)
		return null
	# 还没查完：先盖「正在检查」，查完再定
	var page := XUpdatePage.open_forced(host, {"state": "checking"})
	_wait(host, page, hint_parent)
	return page


static func _wait(host: Node, page: XUpdatePage, hint_parent: Control) -> void:
	var tree := host.get_tree()  # 等的时候标题节点可能已经换掉：后面只用 tree，不再碰 host 的方法（发行模板对已释放对象调方法会崩）
	var client := XUpdateClient.instance(tree)
	var timer := tree.create_timer(WAIT_SEC, true, false, true)
	var state := {"timed_out": false}
	timer.timeout.connect(func():
		if not _done and is_instance_valid(page) and not page.is_queued_for_deletion():
			state["timed_out"] = true
			page.close_page())  # 等太久：放行，结果回来再说
	while not _done:
		await client.checked
		await tree.process_frame  # 让 _run 先记下结果
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	if blocks(result):
		if state["timed_out"] or not is_instance_valid(page) or page.is_queued_for_deletion():
			if host.has_method("is_title_page") and not host.is_title_page():
				return  # 已经离开标题（读档页、设置页等也还在西游标题节点里，这里只在标题本页才补盖）
			XUpdatePage.open_forced(host, result)
		else:
			page.show_forced(result)
		return
	if is_instance_valid(page) and not page.is_queued_for_deletion():
		page.close_page()
	if str(result.get("state", "")) == XUpdateCheck.BAD and is_instance_valid(hint_parent):
		_add_hint(hint_parent)


static func _add_hint(parent: Control) -> void:
	if parent.get_node_or_null("UpdateOfflineHint") != null:
		return
	var l := XUI.label(OFFLINE_HINT, 16, XUI.DIM)
	l.name = "UpdateOfflineHint"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(12, 8)
	parent.add_child(l)
