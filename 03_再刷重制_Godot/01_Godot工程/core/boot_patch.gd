extends Node
## 自动更新第 0 批（技术验证，Kyo 2026-11-11「安排开工」；O-待定·补丁叠加载入）。
## 第一个自动加载，排在 GameApp 前面：在 _init 里把用户目录里已校验的补丁包叠到底包上。
## 引擎按顺序逐个载入自动加载脚本，所以这里载入补丁之后，GameApp 及其后所有脚本、数据、图都读到补丁里的版本。
## 本脚本一旦运行就不能再被补丁替换，所以写得尽量短，**不引用任何带 class_name 的脚本**（引用了就会先于补丁载入）。
## 本批只做「登记了、校验过就载入」；下载、启动失败自动回退、存档备份在后面的批次做。
##
## 用户目录约定：
##   user://updates/active.json   {"file": "x.pck", "sha256": "…", "size": 123, "base": 453, "code": 470}
##   user://updates/<file>        补丁包本体
## 不载入的情况（都只记原因、照常用底包启动）：开关关着、没有登记、登记坏了、文件不在、字节数或 SHA-256 对不上、
## 补丁对应的底包编号不是本包的编号。

const DIR := "user://updates"
const STATE_FILE := "user://updates/active.json"
const BUILD_INFO := "res://content/build_info.json"

## O-待定 开关：false 回退为不认任何补丁（只用安装包自带内容）。
static var enabled := true
## 本次启动的结果，给界面和测试看：{"loaded": bool, "reason": String, "code": int, "base": int}
static var result := {"loaded": false, "reason": "未运行", "code": 0, "base": 0}


func _init() -> void:
	result = apply(STATE_FILE)
	if result["loaded"] or result["reason"] != "没有登记":
		print("BOOT_PATCH loaded=%s reason=%s base=%d code=%d" % [result["loaded"], result["reason"], result["base"], result["code"]])


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
	return out
