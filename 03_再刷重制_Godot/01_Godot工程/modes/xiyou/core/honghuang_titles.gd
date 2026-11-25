class_name XHonghuangTitles
extends RefCounted
## 【cc·T493·未经审查】洪荒首通奖励②：三款称号＋一次性绑存档兑换码（Kyo 11-24／11-25 拍板，派单 T493）。只在西游档生效。
##
## 三款称号（接在 XDesignation 表里原版 1～30、kyo 专属 31、庆典 41～47 之后）：
## - 51 洪荒证道（紫）：西游档通关洪荒难度（打赢第 33 层最终守层者，层数变量 20 到 34，且洪荒开关 2483／2463 开着）就自动解锁；
##   跟别的称号一样记全局配置（所有存档共用）。已经通关的老存档读进来，地图空闲时同样补发（判定只看存档现状，不看是哪一版打的）。
## - 52 洪荒首证（曙光流光）：只能用兑换码解锁，没解锁的照别的称号显示 ???。
## - 53 洪荒·阿夜（极夜流光）：所有人都能在列表里看到（标「阿夜专属，不可获得」），只有兑换码绑定的那份存档能获得、佩戴。
## 52、53 记在存档里（s.flags[FLAG_KEY].titles，每份存档各算各的），不记全局配置：换档就没有。
##
## 兑换码（一次性、绑指定存档）：
## - 存档身份用 orb_seed（新游戏随机、随存档保存，导出导入、换存档位都不变；没有这个字段的旧档由存档内容算出，同一档每次一样）。
##   存档本身封存签名（XSaveSeal，D28），玩家改不了这个数，也改不了「已兑换」记号。
## - 仓库里只放 sha256(盐|兑换码|存档身份) 的十六进制（modes/xiyou/honghuang_redeem.json），兑换码原文不进仓库、日志、交付单；
##   码由 07_开发环境/洪荒兑换码.py 在本机生成（读玩家存档取身份、写哈希进配置、把码打到终端）。
## - 兑换：输入的码规范化（大写、去掉空格和横线）后连当前存档身份算哈希，配置里有这条才算对 → 解锁这条给的称号、记已兑换。
##   换一份存档（身份不同）哈希就对不上；同一份存档第二次输入提示已经兑换过、什么都不发。
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
const VISIBLE_LOCKED := {TITLE_AYE: "（阿夜专属，不可获得）"}
## 只记在存档里的称号（兑换码发）
const SAVE_TITLES := [TITLE_SHOUZHENG, TITLE_AYE]

## 通关洪荒：层数变量 20（神魔之塔层数，打赢 33 层守层者后加到 34）
const FLOOR_VARIABLE := 20
const CLEAR_FLOOR := 34

const FLAG_KEY := "honghuang_titles"
const CODES_PATH := "res://modes/xiyou/honghuang_redeem.json"
const SALT := "honghuang-redeem-v1"

## 玩家可见文字（待小A 文字审）
const REDEEM_OPTION := "输入兑换码"
const LEAVE_OPTION := "离开"
const REDEEM_PROMPT := "请输入兑换码："
const MSG_OK := "兑换成功！获得称号：%s。\n在大厅找奥尔夫尼选「更换称号」即可佩戴。"
const MSG_USED := "这个兑换码在这份存档已经用过了。"
const MSG_INVALID := "兑换码不对，或者不是给这份存档的。"
const MSG_UNAVAILABLE := "现在无法兑换。"
const TOAST_ZHENGDAO := "通关洪荒难度！获得称号：洪荒证道"

## 测试用：非 null 时代替配置文件里的兑换表（[{hash, titles}]）
static var codes_override = null
static var _codes = null


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


## 52、53 有没有（当前存档）
static func save_has(s, id: int) -> bool:
	if not on(s):
		return false
	return _flag_has(s.flags, id)


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


## 当前佩戴的称号能不能显示（返修 P1-1 展示侧双保险）：戴着 52／53 却没有兑换记号的（改明文存档硬塞的）不显示
static func worn_ok(s) -> bool:
	if s == null or not s.designation is Dictionary:
		return true
	var tid := save_title_by_name(str(s.designation.get("name", "")))
	return tid == 0 or _flag_has(s.flags, tid)


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


## 存档身份（orb_seed，见文件头）
static func save_identity(s) -> String:
	return str(int(s.orb_seed))


static func code_hash(code: String, identity: String) -> String:
	return ("%s|%s|%s" % [SALT, normalize(code), identity]).sha256_text()


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
	var h := code_hash(n, save_identity(s))
	var entry := {}
	for e in codes():
		if str(e.hash) == h:
			entry = e
			break
	if entry.is_empty():
		return {"ok": false, "text": MSG_INVALID, "titles": []}
	if not s.flags.get(FLAG_KEY) is Dictionary:
		s.flags[FLAG_KEY] = {}
	var rec: Dictionary = s.flags[FLAG_KEY]
	if not rec.get("used") is Array:
		rec["used"] = []
	if not rec.get("titles") is Dictionary:
		rec["titles"] = {}
	if (rec.used as Array).has(h):
		return {"ok": false, "text": MSG_USED, "titles": []}
	(rec.used as Array).append(h)
	var got := []
	for id in entry.titles:
		var tid := int(id)
		if is_save_title(tid) and rec.titles.get(str(tid)) != true:
			rec.titles[str(tid)] = true
			got.append(tid)
	var names := "、".join(got.map(func(id): return str(title(id).get("name", ""))))
	return {"ok": not got.is_empty(), "text": MSG_OK % names if names != "" else MSG_USED, "titles": got}


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
