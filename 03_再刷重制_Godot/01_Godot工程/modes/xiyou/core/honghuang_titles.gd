class_name XHonghuangTitles
extends RefCounted
## 【cc·T493·未经审查】洪荒首通奖励②：三款称号＋兑换码（Kyo 11-24／11-25 拍板，派单 T493；T508 改成不绑存档）。只在西游档生效。
##
## 三款称号（接在 XDesignation 表里原版 1～30、kyo 专属 31、庆典 41～47 之后）：
## - 51 洪荒证道（紫）：西游档通关洪荒难度（打赢第 33 层最终守层者，层数变量 20 到 34，且洪荒开关 2483／2463 开着）就自动解锁；
##   跟别的称号一样记全局配置（所有存档共用）。已经通关的老存档读进来，地图空闲时同样补发（判定只看存档现状，不看是哪一版打的）。
## - 52 洪荒首证（曙光流光）：只能用兑换码解锁；T509 起没解锁的也照名字列出（标首证人、不可获得），选了不变，只有兑过码的本机能佩戴。
## - 53 洪荒·阿夜（极夜流光）：所有人都能在列表里看到（标「阿夜专属，不可获得」），只有兑过码的那台设备能获得、佩戴。
## T508 起 52、53 记在本机解锁文件里（见下），本机所有存档（含之后新开档）都有；不记 options.json（明文，能伪造）。
## T493 时兑在存档里的记号（s.flags[FLAG_KEY].titles）照旧认。
##
## 兑换码（T508：本机兑一次、本机永久拥有；Kyo 11-25「他对换了以后，他本机的游戏就永久拥有这个称号，他能复用」）：
## - 码不绑存档、不绑设备：仓库里只放 sha256(盐 v2|兑换码) 的十六进制（modes/xiyou/honghuang_redeem.json），
##   兑换码原文不进仓库、日志、交付单；码由 07_开发环境/洪荒兑换码.py 在本机生成（写哈希进配置、码原文写本机私密文件）。
##   代价：码外流，别的设备也能兑（称号纯外观，Kyo 知情）。
## - 兑换：输入的码规范化（大写、去掉空格和横线）后算哈希，配置里有这条才算对 → 写本机解锁文件 → 本机所有存档都有这条给的称号。
##   本机已经有了再输入，提示已经拥有、什么都不改。
## - 本机解锁文件 <存档目录>/honghuang_titles.ksv：用存档封存同一套 AES＋HMAC（XSaveSeal.seal／unseal，发行包用注入的密钥）封起来，
##   内容 {titles: {"52": true…}, used: [码哈希], machine: 本机 ID 哈希}。machine＝sha256(盐|OS.get_unique_id())，
##   拷到别的设备上对不上就不认；改过（签名不对）也不认。不认时只是没有称号，文件原样不动、不碰存档和设置；删掉同样只是丢称号。
##   安卓的 get_unique_id 是 ANDROID_ID（8.0 起按应用签名＋用户＋设备，卸载重装不变、恢复出厂才变）；
##   但卸载会连存档目录一起删，解锁文件也没了，要再输一次码（码不绑设备，照样能兑）。
## - 设备 ID 取不到（OS.get_unique_id() 返回空，系统查询失败时可能这样）：不认、不写本机解锁（返修 P1-1：空 ID 的哈希所有这类设备都一样，
##   拷文件就能通用），兑换提示暂时无法保存、可以稍后重试，什么都不改。
## - 有封存密钥但文件写失败：同上，兑换没完成、什么都不改，提示稍后重试（返修 P2-1）。
## - 没有封存密钥（发行包没注入密钥的旧底包）才退回 T493 的做法：记在当前存档里（s.flags[FLAG_KEY]，这份存档一次），提示只在当前存档、记得存档。
## - 读本机文件走 XSaveSeal.read（有大小上限，只认 sealed）（返修 P2-2）；运行中外部改了文件，重启后才生效（P3-1 没做）。
## - 存档里的记号（T493 兑过的、上面退回时记的）照旧认；明文导入、补签旧明文档照旧清掉（strip_unsealed），展示侧照旧再校验（worn_ok）。
## - T493 的 v1 码（sha256(盐 v1|码|orb_seed)，绑存档）作废：配置里删掉那条，旧码输入提示码不对；已用旧码兑过的存档照旧有。
## - 入口：大厅洪荒碑调查后多一个「输入兑换码」选项（XHonghuangMonument.inspect）。
##
## 流光：称号颜色是基色（列表外、侧栏等静态地方用），头顶名牌按 flow_style(名字) 逐字渐变并随时间流动（XDesignationPlate）；
## 画面特效关着（或省电）时停在一帧，不每帧重画。
##
## 回退开关 ENABLED＝false：三款称号不列、不自动解锁、碑上没有兑换选项、名牌不流光（存档里已有的记号原样留着，开回来照旧）。
## 天启篇存档（XTianqi.active）一律不列、不解锁、不能兑换，天启篇零改动。

static var ENABLED := true

const TITLE_ZHENGDAO := 51
const TITLE_SHOUZHENG := 52
const TITLE_AYE := 53
const ICON_ZHENGDAO := 6426
const ICON_SHOUZHENG := 6427
const ICON_AYE := 6428
## 名牌流光样式
const FLOW_DAWN := "dawn"     # 洪荒首证：曙光（赤金→玫红→白金，外加一道亮光扫过、暖色光晕）
const FLOW_NIGHT := "night"   # 洪荒·阿夜：极夜（月银→冰蓝→暮紫循环）
## 称号表（名字、说明文字待小A 文字审）
const TITLES := [
	{"id": TITLE_ZHENGDAO, "name": "洪荒证道", "icon": ICON_ZHENGDAO, "color": "#b44dff"},
	{"id": TITLE_SHOUZHENG, "name": "洪荒首证", "icon": ICON_SHOUZHENG, "color": "#ffb38a", "flow": FLOW_DAWN},
	{"id": TITLE_AYE, "name": "洪荒·阿夜", "icon": ICON_AYE, "color": "#a9c8ff", "flow": FLOW_NIGHT},
]
## 所有人可见、没拿到时也照名字列出的称号（其余没拿到显示 ???）
const VISIBLE_LOCKED := {
	TITLE_SHOUZHENG: "：首位证道洪荒者的荣誉。首证人：大手子。（不可获得）",  # T509：52 也所有人可见（待小A 审）
	TITLE_AYE: "（阿夜专属，不可获得）",
}
## 只记在存档里的称号（兑换码发）
const SAVE_TITLES := [TITLE_SHOUZHENG, TITLE_AYE]

## 通关洪荒：层数变量 20（神魔之塔层数，打赢 33 层守层者后加到 34）
const FLOOR_VARIABLE := 20
const CLEAR_FLOOR := 34

const FLAG_KEY := "honghuang_titles"
const CODES_PATH := "res://modes/xiyou/honghuang_redeem.json"
const SALT := "honghuang-redeem-v2"

## 玩家可见文字（待小A 文字审）
const REDEEM_OPTION := "输入兑换码"
const LEAVE_OPTION := "离开"
const REDEEM_PROMPT := "请输入兑换码："
const MSG_OK := "兑换成功！获得称号：%s。\n本机的西游存档都可佩戴。到大厅找奥尔夫尼，选择「更换称号」。"
const MSG_USED := "本机已解锁这些称号。"
const MSG_INVALID := "兑换码不正确，请核对后重试。"
## 没有封存密钥的兼容路径（只记当前存档）
const MSG_OK_SAVE := "兑换成功！获得称号：%s。\n称号仅在当前存档可用，请记得存档。"
const MSG_USED_SAVE := "这份存档已解锁这些称号。"
## 有密钥但写不了本机解锁（设备 ID 取不到、写文件失败）：兑换没完成
const MSG_RETRY := "称号解锁暂时无法保存，请稍后重试。"
const MSG_UNAVAILABLE := "现在无法兑换。"
const TOAST_ZHENGDAO := "通关洪荒难度！获得称号：洪荒证道"

## 测试用：非 null 时代替配置文件里的兑换表（[{hash, titles}]）
static var codes_override = null
static var _codes = null
## 本机解锁文件名（在 XSave.dir() 下）
const LOCAL_FILE := "honghuang_titles.ksv"
const MACHINE_SALT := "honghuang-machine-v1"
## 测试用：非空时代替 OS.get_unique_id()（模拟换一台设备）
static var machine_id_override := ""
## 测试用：true 时当作设备 ID 取不到（OS.get_unique_id() 返回空）
static var machine_id_missing := false
## 测试用：true 时写本机解锁文件当作失败（模拟磁盘写不进）
static var write_fail_for_test := false
## 本机解锁缓存：读过的文件路径 → {titles: {}, used: []}（名牌每帧要查，不每次读盘）
static var _local_path := ""
static var _local := {}


static func on(s = null) -> bool:
	var st = s if s != null else XState.current
	return ENABLED and st != null and not XTianqi.active(st)


static func title(id: int) -> Dictionary:
	for t in TITLES:
		if int(t.id) == id:
			return t
	return {}


## XDesignation.table 末尾追加（西游档、开关开着才加）
static func table_rows() -> Array:
	if not on():
		return []
	return TITLES.map(func(t): return {"id": t.id, "name": t.name, "icon": t.icon, "color": t.color})


static func is_save_title(id: int) -> bool:
	return SAVE_TITLES.has(id)


## 52、53 有没有：本机解锁文件里有，或当前存档里有兑换记号（T493 兑的、封存写不了时退回记的）
static func save_has(s, id: int) -> bool:
	if not on(s):
		return false
	return local_has(id) or _flag_has(s.flags, id)


# ---- 本机解锁文件（见文件头）----

static func local_path() -> String:
	return XSave.dir().path_join(LOCAL_FILE)


## 本机标记；设备 ID 取不到时返回 ""（调用方一律不认、不写）
## 系统设备 ID 最多每 ID_RECHECK_MS 重查一次（名牌每帧要问，不每帧查系统）；变了下面的本机缓存跟着失效
const ID_RECHECK_MS := 2000
static var _id_cache := ""
static var _id_at := -1


static func _raw_id() -> String:
	if machine_id_missing:
		return ""
	if machine_id_override != "":
		return machine_id_override
	var now := Time.get_ticks_msec()
	if _id_at < 0 or now - _id_at >= ID_RECHECK_MS:
		_id_cache = OS.get_unique_id()
		_id_at = now
	return _id_cache


static func machine_tag() -> String:
	var id := _raw_id()
	if id.strip_edges() == "":
		return ""
	return ("%s|%s" % [MACHINE_SALT, id]).sha256_text()


## 有没有封存密钥（能不能写本机解锁文件）
static func _can_seal() -> bool:
	return not XSaveSeal.seal("{}").is_empty()


## 读本机解锁（签名不对、不是本机的、没有文件，都当空的；文件不动）
## 缓存按「路径｜本机标记」记：先查设备标识，标识为空一律当空的；标识变了（变空、恢复、换了）缓存自动失效（热修 P1-1）
static func local_state() -> Dictionary:
	var p := local_path()
	var tag := machine_tag()
	var key := "%s|%s" % [p, tag]
	if key == _local_path:
		return _local
	_local_path = key
	_local = {"titles": {}, "used": []}
	if tag == "" or not FileAccess.file_exists(p):
		return _local
	var r := XSaveSeal.read(p)  # 有大小上限；不在封存管的文件名里，不触发目录迁移
	if str(r.get("status", "")) != "sealed":
		return _local
	var d = JSON.parse_string(str(r.text))
	if not d is Dictionary or str(d.get("machine", "")) != tag:
		return _local
	if d.get("titles") is Dictionary:
		for k in d.titles:
			if d.titles[k] == true and is_save_title(int(str(k))):
				_local.titles[str(int(str(k)))] = true
	if d.get("used") is Array:
		_local.used = (d.used as Array).filter(func(h): return h is String)
	return _local


static func local_has(id: int) -> bool:
	return local_state().titles.get(str(id)) == true


## 换了存档目录、设备 ID、密钥后重读（测试用）
static func reload_local() -> void:
	_local_path = ""
	_local = {}


## 写本机解锁（封存）；写不了返回 false
static func _write_local(titles: Dictionary, used: Array) -> bool:
	var tag := machine_tag()
	if tag == "" or write_fail_for_test:
		return false
	var text := JSON.stringify({"titles": titles, "used": used, "machine": tag})
	var ok := XSaveSeal.write_file(local_path(), text)
	reload_local()
	return ok


## 称号选择里没拿到的那一项怎么显示：所有人可见的照名字列＋说明，其余 ""（调用方显示 ???）
static func locked_choice(id: int) -> String:
	if not on() or not VISIBLE_LOCKED.has(id):
		return ""
	var t := title(id)
	return "\\I[%d]%s%s" % [int(t.icon), t.name, VISIBLE_LOCKED[id]]


## 称号名是不是 52／53（存档里称号只存名字），是就返回号，否则 0
static func save_title_by_name(d_name: String) -> int:
	for t in TITLES:
		if t.name == d_name and is_save_title(int(t.id)):
			return int(t.id)
	return 0


## 存档 flags 里有没有这条称号的兑换记号（不看开关：回退时只用来判断，不删不改）
static func _flag_has(flags, id: int) -> bool:
	var rec = flags.get(FLAG_KEY) if flags is Dictionary else null
	return rec is Dictionary and rec.get("titles") is Dictionary and rec.titles.get(str(id)) == true


## 当前佩戴的称号能不能显示（返修 P1-1 展示侧双保险）：戴着 52／53，本机和存档里都没有兑换记号的（改明文存档硬塞的）不显示
static func worn_ok(s) -> bool:
	if s == null or not s.designation is Dictionary:
		return true
	var tid := save_title_by_name(str(s.designation.get("name", "")))
	return tid == 0 or _flag_has(s.flags, tid) or (on(s) and local_has(tid))


## 没签名的明文存档数据（封存开着时的明文导入、XSaveSeal 补签旧明文档）去掉 52／53：兑换记号整条删、佩戴着的清空。
## T493 晚于 D28 封存，合法兑换过的存档只会是封存格式，明文里出现 52／53 只能是手改的（返修 P1-1）。返回改没改。
static func strip_unsealed(data) -> bool:
	if not data is Dictionary:
		return false
	var changed := false
	if data.get("flags") is Dictionary and (data.flags as Dictionary).has(FLAG_KEY):
		(data.flags as Dictionary).erase(FLAG_KEY)
		changed = true
	var dg = data.get("designation")
	if dg is Dictionary and save_title_by_name(str(dg.get("name", ""))) != 0:
		data["designation"] = {"name": "", "icon": 0, "color": "#ffffff"}
		changed = true
	return changed


## 名牌流光样式：按称号名找（存档里称号只存名字、图标、颜色，不改存档结构）
static func flow_style(d_name: String) -> String:
	if not ENABLED or d_name == "":
		return ""
	for t in TITLES:
		if t.name == d_name and t.has("flow"):
			return str(t.flow)
	return ""


## 流光颜色：style、第 i 个字（共 n 个）、时间 t（秒）
static func flow_color(style: String, i: int, n: int, t: float) -> Color:
	var u := (float(i) + 0.5) / maxf(1.0, float(n))
	match style:
		FLOW_DAWN:
			# 赤金→玫红→白金三段循环，外加一道窄亮带从左扫到右（约 2.4 秒一轮），比单纯色相流动更显眼
			var stops := [Color("#ffcf4a"), Color("#ff5a6e"), Color("#fff1c4")]
			var p := fposmod(u * 1.2 - t * 0.35, 1.0) * 3.0
			var k := int(floor(p))
			var c: Color = (stops[k % 3] as Color).lerp(stops[(k + 1) % 3], p - float(k))
			var band := fposmod(t / 2.4, 1.0) * 1.6 - 0.3
			var glow := clampf(1.0 - absf(u - band) / 0.18, 0.0, 1.0)
			return c.lerp(Color.WHITE, glow * 0.85)
		FLOW_NIGHT:
			var stops := [Color("#dfe8ff"), Color("#6fd3ff"), Color("#9a7bff")]
			var p := fposmod(u * 0.9 - t * 0.22, 1.0) * 3.0
			var k := int(floor(p))
			return (stops[k % 3] as Color).lerp(stops[(k + 1) % 3], p - float(k))
	return Color.WHITE


## 曙光的字描边：暖色光晕随时间明暗（别的样式 / 没样式返回 null，用默认黑描边）
static func flow_outline(style: String, t: float):
	if style == FLOW_DAWN:
		return Color(0.55, 0.12, 0.05, 0.75 + 0.2 * sin(t * 3.0))
	return null


# ---- 洪荒证道：通关自动解锁（含老存档补发）----

static func cleared(s) -> bool:
	return on(s) and XHonghuang.is_honghuang(s) and s.variable(FLOOR_VARIABLE) >= CLEAR_FLOOR


## 地图空闲时查（XMapScene 每 30 帧一次）；新解锁返回 true（调用方弹提示）
static func check_clear(s) -> bool:
	if not cleared(s) or XDesignation.unlocked(TITLE_ZHENGDAO):
		return false
	XDesignation.unlock(TITLE_ZHENGDAO)
	return true


# ---- 兑换码 ----

static func normalize(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


## 码哈希（不带存档身份，见文件头；和 07_开发环境/洪荒兑换码.py 同一算法）
static func code_hash(code: String) -> String:
	return ("%s|%s" % [SALT, normalize(code)]).sha256_text()


static func codes() -> Array:
	if codes_override != null:
		return codes_override
	if _codes == null:
		_codes = []
		if FileAccess.file_exists(CODES_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(CODES_PATH))
			if d is Dictionary and d.get("codes") is Array:
				_codes = (d.codes as Array).filter(func(e): return e is Dictionary and str(e.get("hash", "")) != "" and e.get("titles") is Array)
	return _codes


## 兑换：返回 {ok: bool, text: 提示文字, titles: [新解锁的号]}
static func redeem(s, code: String) -> Dictionary:
	if not on(s):
		return {"ok": false, "text": MSG_UNAVAILABLE, "titles": []}
	var n := normalize(code)
	if n == "":
		return {"ok": false, "text": MSG_INVALID, "titles": []}
	var h := code_hash(n)
	var entry := {}
	for e in codes():
		if str(e.hash) == h:
			entry = e
			break
	if entry.is_empty():
		return {"ok": false, "text": MSG_INVALID, "titles": []}
	var want := []
	for id in entry.titles:
		var tid := int(id)
		if is_save_title(tid) and not want.has(tid):
			want.append(tid)
	if not _can_seal():
		return _redeem_to_save(s, h, want)
	if machine_tag() == "":
		return {"ok": false, "text": MSG_RETRY, "titles": []}  # 设备标识取不到：先于「已拥有」判断，不认缓存（热修 P1-1）
	# 本机还没有的就写本机解锁文件（T493 只兑在某份存档里的，也补成本机拥有）
	var got := want.filter(func(tid): return not local_has(tid))
	if got.is_empty():
		return {"ok": false, "text": MSG_USED, "titles": []}
	var loc := local_state()
	var titles: Dictionary = (loc.titles as Dictionary).duplicate()
	var used: Array = (loc.used as Array).duplicate()
	for tid in want:
		titles[str(tid)] = true
	if not used.has(h):
		used.append(h)
	if not _write_local(titles, used):
		# 设备 ID 取不到、写文件失败：兑换没完成，什么都不改，可以重试（返修 P1-1／P2-1）
		return {"ok": false, "text": MSG_RETRY, "titles": []}
	var names := "、".join(got.map(func(id): return str(title(id).get("name", ""))))
	return {"ok": true, "text": MSG_OK % names, "titles": got}


## 没有封存密钥：退回 T493 做法，记在当前存档里（这份存档一次）
static func _redeem_to_save(s, h: String, want: Array) -> Dictionary:
	var got := want.filter(func(tid): return not _flag_has(s.flags, tid))
	if got.is_empty():
		return {"ok": false, "text": MSG_USED_SAVE, "titles": []}
	if not s.flags.get(FLAG_KEY) is Dictionary:
		s.flags[FLAG_KEY] = {}
	var rec: Dictionary = s.flags[FLAG_KEY]
	if not rec.get("used") is Array:
		rec["used"] = []
	if not rec.get("titles") is Dictionary:
		rec["titles"] = {}
	if not (rec.used as Array).has(h):
		(rec.used as Array).append(h)
	for tid in got:
		rec.titles[str(tid)] = true
	var names := "、".join(got.map(func(id): return str(title(id).get("name", ""))))
	return {"ok": true, "text": MSG_OK_SAVE % names, "titles": got}


## 洪荒碑调查后的兑换流程（interp：当前事件解释器）
static func redeem_flow(interp) -> void:
	if not on() or interp == null or not interp.host_alive():
		return
	var list := [{"code": 102, "indent": 0, "parameters": [[REDEEM_OPTION, LEAVE_OPTION], 1, -1, 2, 0]}, {"code": 0, "indent": 0, "parameters": []}]
	var sub := MVInterpreter.new(interp.host, interp.map_id, interp.event_id, list, interp._depth + 1)
	await sub.run()
	if int(sub._branch.get(0, -2)) != 0 or not interp.host_alive():
		return
	var text: String = await interp.host.input_text(REDEEM_PROMPT, "")
	if not interp.host_alive() or text.strip_edges() == "":
		return
	var r := redeem(XState.current, text)
	await interp.host.show_message({"face": "", "index": 0, "background": 0, "position": 2, "lines": Array(str(r.text).split("\n"))})
