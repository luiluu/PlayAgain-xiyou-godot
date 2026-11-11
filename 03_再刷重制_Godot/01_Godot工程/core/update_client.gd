class_name XUpdateClient
extends Node
## 自动更新第①批：读版本清单（联网）。挂在根节点下的单例，换场景不丢。
## - check()：依次读每个清单源的 channel.json 和 channel.sig，交给 XUpdateCheck 验签、挑最高版本、判断该提示什么；
##   结果放在 last 里并发 checked 信号。只发普通 GET，不带任何玩家信息；读到的内容只当数据。
## - auto_check()：进标题时调，一天最多静默查一次（记在 user://updates/check.json）；只在发行构建、非无头时真去查。
## - has_update()：给「检查更新」按钮亮红点用（上次查到有新版，且比现在运行的新）。
## 测试里把 fetcher 换成假的（url → 字节），不真联网。

signal checked(result: Dictionary)

const BootPatchScript := preload("res://core/boot_patch.gd")
const NODE_NAME := "UpdateClient"
const STAMP_FILE := "user://updates/check.json"
const TIMEOUT_SEC := 10.0
const DAY_SEC := 86400

## O-待定·检查更新 开关：false 回退为不联网（auto_check 不查；check 直接返回读不到）。
static var ENABLED := true
## 进标题自动查（每天一次）。false 只在点按钮时查。
static var AUTO := true
## 清单源，依次读、逐个验签、取版本最高的。照 MOD 的做法：Gitee 为主，GitHub 更新仓库经 CDN 当镜像。
static var channel_urls: PackedStringArray = [
	"https://gitee.com/kyoluu/play-again_-xiyou_-kyo/raw/main/godot/channel.json",
	"https://cdn.jsdelivr.net/gh/luiluu/zaishuayiba-updates@main/godot/channel.json",
	"https://raw.githubusercontent.com/luiluu/zaishuayiba-updates/main/godot/channel.json",
]
static var public_key := XUpdateCheck.PUBLIC_KEY
static var stamp_path := STAMP_FILE

## 上一次 check 的结果（XUpdateCheck.evaluate 的返回）；没查过是空字典。
var last: Dictionary = {}
var checking := false
## 换掉联网：Callable(url: String) -> PackedByteArray（可以是协程）。空＝用 HTTPRequest。
var fetcher: Callable


static func instance(tree: SceneTree) -> XUpdateClient:
	var n := tree.root.get_node_or_null(NODE_NAME) as XUpdateClient
	if n == null:
		n = XUpdateClient.new()
		n.name = NODE_NAME
		n.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child(n)
	return n


## 安装包自带的开发编号（补丁载入前读到的）。
static func base_code() -> int:
	var b := int(BootPatchScript.result.get("base", 0))
	return b if b > 0 else BootPatchScript.base_code()


## 现在实际运行的开发编号：装了补丁就是补丁带来的 build_info 的号。
static func current_code() -> int:
	return BootPatchScript.base_code()


func _fetch(url: String) -> PackedByteArray:
	if fetcher.is_valid():
		return await fetcher.call(url)
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	http.max_redirects = 4
	add_child(http)
	var body := PackedByteArray()
	if http.request(url, PackedStringArray(["Accept: */*"])) == OK:
		var r: Array = await http.request_completed
		if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200:
			body = r[3]
	http.queue_free()
	return body


## 读清单并判断。同一时间只跑一轮；正在查时再调，等那一轮的结果。
func check() -> Dictionary:
	if checking:
		return await checked
	checking = true
	var sources: Array = []
	if ENABLED:
		for url in channel_urls:
			var raw := await _fetch(url)
			if raw.is_empty():
				continue
			var sig := await _fetch(url.trim_suffix(".json") + ".sig")
			sources.append({"json": raw, "sig": sig})
	var manifest := XUpdateCheck.pick_best(sources, public_key)
	last = XUpdateCheck.evaluate(manifest, base_code(), current_code())
	if last["state"] != XUpdateCheck.BAD:
		_save_stamp()
	checking = false
	checked.emit(last)
	return last


## 进标题时调：一天最多查一次；不满足条件什么都不做。返回这次有没有真去查。
func auto_check() -> bool:
	_load_stamp()
	if not ENABLED or not AUTO or checking:
		return false
	if not ReleaseEntry.is_release() or DisplayServer.get_name() == "headless":
		return false
	if not due(_stamp_time(), int(Time.get_unix_time_from_system())):
		return false
	check()
	return true


## 离上次查到结果是否满一天（时钟被调回去也算到期）。
static func due(last_time: int, now: int) -> bool:
	return last_time <= 0 or now < last_time or now - last_time >= DAY_SEC


## 红点：上次查到的最新版比现在运行的新。
func has_update() -> bool:
	if last.is_empty():
		_load_stamp()
	if last.is_empty() or last.get("state") == XUpdateCheck.BAD:
		return false
	return XUpdateCheck.compare_versions(str(last.get("version", "")), XUpdateCheck.version_of(current_code())) > 0


func _stamp_time() -> int:
	var d = _read_stamp()
	return int(d.get("time", 0)) if typeof(d) == TYPE_DICTIONARY else 0


func _read_stamp() -> Variant:
	if not FileAccess.file_exists(stamp_path):
		return null
	var j := JSON.new()
	return j.data if j.parse(FileAccess.get_file_as_string(stamp_path)) == OK else null


## 启动后还没查过时，用上次记下的结果给红点（只留版本号和状态，补丁地址每次现查，不信旧记录）。
func _load_stamp() -> void:
	if not last.is_empty():
		return
	var d = _read_stamp()
	if typeof(d) == TYPE_DICTIONARY and d.get("version") is String and d.get("state") is String:
		last = {"state": XUpdateCheck.FULL if d["state"] != XUpdateCheck.LATEST else XUpdateCheck.LATEST,
			"current": XUpdateCheck.version_of(current_code()), "version": d["version"], "code": int(d.get("code", 0)),
			"date": str(d.get("date", "")), "notes": PackedStringArray(), "patch": {}, "revoked": false, "stale": true}


func _save_stamp() -> void:
	DirAccess.make_dir_recursive_absolute(stamp_path.get_base_dir())
	var f := FileAccess.open(stamp_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"time": int(Time.get_unix_time_from_system()), "state": last["state"],
			"version": last["version"], "code": last["code"], "date": last["date"]}))
