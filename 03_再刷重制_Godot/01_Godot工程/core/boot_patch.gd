extends Node
## 自动更新第 0 批（技术验证，Kyo 2026-11-11「安排开工」；O-274）。
## 第一个自动加载，排在 GameApp 前面：在 _init 里把用户目录里已校验的补丁包叠到底包上。
## 引擎按顺序逐个载入自动加载脚本，所以这里载入补丁之后，GameApp 及其后所有脚本、数据、图都读到补丁里的版本。
## 本脚本一旦运行就不能再被补丁替换，所以写得尽量短，**不引用任何带 class_name 的脚本**（引用了就会先于补丁载入）。
## 第 0 批做「登记了、校验过就载入」；第②批加启动计数与自动退回（prepare／confirm）。下载与登记在 XUpdateInstall。
##
## 用户目录约定：
##   user://updates/active.json   {"file": "x.pck", "sha256": "…", "size": 123, "base": 453, "code": 470,
##                                 "confirmed": false, "boots": 0, "prev": {上一份的同样几项} 或 null}
##   user://updates/rolled_back.json  自动退回后留的提示 {"code": 被退回的号, "reason": "启动失败"}
##   user://updates/<file>        补丁包本体
## 不载入的情况（都只记原因、照常用底包启动）：开关关着、没有登记、登记坏了、文件不在、字节数或 SHA-256 对不上、
## 补丁对应的底包编号不是本包的编号。

const DIR := "user://updates"
const STATE_FILE := "user://updates/active.json"
const BUILD_INFO := "res://content/build_info.json"
const ROLLED_BACK_NAME := "rolled_back.json"
const MAX_BOOTS := 2
const CONFIRM_FRAMES := 180

## O-274 开关：false 回退为不认任何补丁（只用安装包自带内容）。
static var enabled := true
## 本次启动的结果，给界面和测试看：{"loaded": bool, "reason": String, "code": int, "base": int}
static var result := {"loaded": false, "reason": "未运行", "code": 0, "base": 0}
var _frames := 0


func _init() -> void:
	prepare(STATE_FILE)
	result = apply(STATE_FILE)
	if result["loaded"] or result["reason"] != "没有登记":
		print("BOOT_PATCH loaded=%s reason=%s base=%d code=%d" % [result["loaded"], result["reason"], result["base"], result["code"]])
	set_process(result["loaded"] and not result.get("confirmed", true))


## 新补丁第一次启动后还没确认过：主循环带着当前场景跑满 CONFIRM_FRAMES 帧就算启动成功。
func _process(_delta: float) -> void:
	if get_tree().current_scene == null:
		return
	_frames += 1
	if _frames >= CONFIRM_FRAMES:
		confirm(STATE_FILE)
		set_process(false)


## 启动计数与自动退回（第②批）。新装的补丁在登记里是 confirmed=false：每次启动先把 boots 加一；
## 已经试过 MAX_BOOTS 次还没确认（启动中途崩了、卡死被杀），就退回上一份（登记里的 prev；没有就退回安装包自带内容），
## 并留一条 rolled_back.json 给界面提示。必须在载入补丁之前做。
static func prepare(state_path: String) -> void:
	if not enabled or not FileAccess.file_exists(state_path):
		return
	var st = _json(state_path)
	if typeof(st) != TYPE_DICTIONARY or st.get("confirmed", true) == true:
		return
	var boots := int(st.get("boots", 0))
	if boots < MAX_BOOTS:
		st["boots"] = boots + 1
		_write(state_path, st)
		return
	var note := {"code": int(st.get("code", 0)), "reason": "启动失败"}
	var prev = st.get("prev")
	_write(state_path.get_base_dir().path_join(ROLLED_BACK_NAME), note)
	if typeof(prev) == TYPE_DICTIONARY and prev.get("file") is String:
		prev["confirmed"] = true
		prev["prev"] = null
		_write(state_path, prev)
	else:
		DirAccess.remove_absolute(state_path)


## 标记当前补丁启动成功，之后不再计数。
static func confirm(state_path: String) -> void:
	var st = _json(state_path)
	if typeof(st) == TYPE_DICTIONARY and st.get("confirmed", true) != true:
		st["confirmed"] = true
		st["boots"] = 0
		_write(state_path, st)
	result["confirmed"] = true


static func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


## 底包自己的开发编号。必须在载入补丁之前读（补丁里也带 build_info.json，载入后读到的就是新号了）。
static func base_code() -> int:
	var d = _json(BUILD_INFO)
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	return str(d.get("developmentVersion", "")).trim_prefix("dev.").to_int()


## 读 JSON；坏了返回 null，不打引擎报错（JSON.parse_string 坏内容会打 ERROR）。
static func _json(path: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(FileAccess.get_file_as_string(path)) == OK else null


## 读登记、校验、载入。state_path 可换，给测试用。
static func apply(state_path: String) -> Dictionary:
	var out := {"loaded": false, "reason": "", "code": 0, "base": base_code()}
	if not enabled:
		out["reason"] = "开关关着"
		return out
	if not FileAccess.file_exists(state_path):
		out["reason"] = "没有登记"
		return out
	var st = _json(state_path)
	if typeof(st) != TYPE_DICTIONARY or not (st.get("file") is String) or not (st.get("sha256") is String):
		out["reason"] = "登记坏了"
		return out
	var file := str(st["file"])
	if file.is_empty() or file.contains("/") or file.contains("\\") or file.contains(".."):
		out["reason"] = "登记坏了"
		return out
	out["code"] = int(st.get("code", 0))
	if int(st.get("base", -1)) != out["base"]:
		out["reason"] = "底包不符"
		return out
	var path := state_path.get_base_dir().path_join(file)
	if not FileAccess.file_exists(path):
		out["reason"] = "文件不在"
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or (st.has("size") and f.get_length() != int(st["size"])):
		out["reason"] = "字节数不符"
		return out
	f = null
	# 截断的包 load_resource_pack 也可能返回 true 却什么都没换（小工程实测），所以一定先比 SHA。
	if FileAccess.get_sha256(path) != str(st["sha256"]).to_lower():
		out["reason"] = "校验不符"
		return out
	if not ProjectSettings.load_resource_pack(path, true):
		out["reason"] = "载入失败"
		return out
	out["loaded"] = true
	out["reason"] = "已载入"
	out["confirmed"] = st.get("confirmed", true) == true
	return out
