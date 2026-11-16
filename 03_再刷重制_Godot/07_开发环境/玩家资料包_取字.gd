extends Node
## 玩家资料包·无头取字（T008 期一，cc 2026-11-16）：只在 玩家资料包.py 建的「发行空壳脱敏树」里跑，不在开发工程里跑。
## 玩家资料包.py 把本脚本拷进脱敏树的 res://_xxy_pubpack/，配一个只挂本脚本的场景，用
##   godot --headless --path <脱敏树> res://_xxy_pubpack/dump.tscn -- <输出 json> <补丁号> [<老底包发行名> <老底包起算号>]
## 启动；写完输出就退出（退出码 0＝写成，1＝没写成）。
##
## 取的是「玩家在游戏里实际看到的字」，不是数据库原文：
##   - 技能／物品／武器／防具：XHelpCard.content()（说明卡逐行，含 <pos=APs> 等备注渲染出的行）；控制符（\c[n]、\i[n]、\lock[1]…）去掉。
##   - 状态：XPartyStatusPanel.description()（状态详情页那句）。
##   - 角色：数据库 profile（人物页）；职业、敌人：只取名字（敌人图鉴的八维随难度变，数据库原值≠玩家看到的，期一不出）。
##   - 版本号：XVersionLabel.version_text()（右下角那串）与 XUpdateCheck.version_of(补丁号)；老底包更新弹窗按老底包的发行名／起算号
##     再调一次 XUpdateCheck.version_of（同一个函数，F1 不另写算法，契约 C1）。
## 发行开关：ReleaseEntry.simulate_release 设 true 后清 XDB 表缓存再取，异化隐藏（XAlienBattle.hidden）等发行门按发行构建算。
## 输出 json 里带内部数字编号（id）只给 玩家资料包.py 内部配对用，它出包前全部剥掉，不落进资料包。

const TestEnv = preload("res://tests/xiyou_test_env.gd")
const KINDS := ["Actors", "Classes", "Skills", "Items", "Weapons", "Armors", "States", "Enemies"]

var _code_re: RegEx
var _brace_re: RegEx
var _col_re: RegEx
var _name_re: RegEx


func _ready() -> void:
	_run.call_deferred()


func _plain(t: String) -> String:
	# MV／重制的文字控制符：\c[n] \C[n] \i[n] \col[50] \lock[1] \V[n] \N[n] 等一律去掉；\{ \} 字号加减去掉；转义的 ESC 同理
	t = t.replace("\u001b", "\\")
	t = _col_re.sub(t, "　", true)  # 两列排版（\col[50]）：左右两栏之间留一个全角空格，别粘成一串
	t = _name_re.sub(t, "$1：", true)  # 对话名字框 \n<名字>
	t = _code_re.sub(t, "", true)
	t = _brace_re.sub(t, "", true)
	t = t.replace("\\n", "\n")
	var lines := []
	for ln in t.split("\n"):
		var s := ln.strip_edges()
		if s != "":
			lines.append(s)
	return "\n".join(lines)


func _card_text(obj: Dictionary) -> String:
	var rows: Array = XHelpCard.content(obj)
	var out := []
	for i in rows.size():
		if i == 0:
			continue  # 第一行是名字（带星级），名字另有字段
		var s := _plain(str(rows[i][0]))
		if s != "":
			out.append(s)
	return "\n".join(out)


func _run() -> void:
	_code_re = RegEx.create_from_string("\\\\[A-Za-z]+\\[[^\\]]*\\]")
	_brace_re = RegEx.create_from_string("\\\\[{}!.|><^$]")
	_col_re = RegEx.create_from_string("\\\\col\\[\\d+\\]")
	_name_re = RegEx.create_from_string("\\\\n<([^>]*)>")
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("用法：-- <输出 json> <补丁号> [<老底包发行名> <老底包起算号>]")
		get_tree().quit(1)
		return
	var out_path := str(args[0])
	var patch := int(args[1])
	TestEnv.isolate("xxy_pubpack")
	ReleaseEntry.simulate_release = true
	XDB._tables = {}
	var res := {"ok": false, "kinds": {}, "version": {}, "release": {}}
	if not XDB.available():
		push_error("generated 数据不在（XDB.available() 为假）")
		get_tree().quit(1)
		return
	res.release = {"is_release": ReleaseEntry.is_release(), "alien_hidden": XAlienBattle.hidden()}
	# 版本号：右下角与补丁号（契约 C1，同一套逻辑）
	XUpdateCheck.release_name = ""
	XUpdateCheck.release_base = 0
	var label := XVersionLabel.version_text()
	XUpdateClient.init_versions()
	var ver := {"label": label, "of_patch": "v" + XUpdateCheck.version_of(patch),
		"release_name": XUpdateCheck.release_name, "release_base": XUpdateCheck.release_base,
		"current_code": XUpdateClient.current_code()}
	if args.size() >= 4:
		var keep_name := XUpdateCheck.release_name
		var keep_base := XUpdateCheck.release_base
		XUpdateCheck.release_name = str(args[2])
		XUpdateCheck.release_base = int(args[3])
		ver["legacy_popup"] = XUpdateCheck.version_of(patch)
		XUpdateCheck.release_name = keep_name
		XUpdateCheck.release_base = keep_base
	res.version = ver
	for kind in KINDS:
		var t = XDB.table(kind)
		var rows := []
		if t is Array:
			for i in range(1, t.size()):
				var r: Dictionary = XDB.rec(kind, i)
				if r.is_empty():
					continue
				var name := _plain(str(r.get("name", "")))
				var row := {"id": i, "name": name}
				match kind:
					"Actors":
						row.nickname = _plain(str(r.get("nickname", "")))
						row.description = _plain(str(r.get("profile", "")))
					"Skills", "Items", "Weapons", "Armors":
						row.description = _card_text(r)
						if r.has("price"):
							row.price = int(r.get("price", 0))
						if kind == "Weapons" or kind == "Armors":
							row.params = r.get("params", [])
					"States":
						row.description = _plain(XPartyStatusPanel.description(r))
					"Enemies":
						row.in_book = XEnemyBook.listed(i)
				var hidden := false
				if kind == "Items":
					hidden = XAlienHide.blocks_item(i)
				elif kind == "Weapons":
					hidden = XAlienHide.blocks_base("weapon", i)
				elif kind == "Armors":
					hidden = XAlienHide.blocks_base("armor", i)
				row.open = not hidden
				rows.append(row)
		res.kinds[kind] = rows
	res.ok = true
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("写不了 " + out_path)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify(res))
	f.close()
	print("XXY_PUBPACK_OK ", out_path)
	get_tree().quit(0)
