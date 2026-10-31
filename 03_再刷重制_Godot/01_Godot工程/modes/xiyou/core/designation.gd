class_name XDesignation
## 【cc·悟空·未经审查】称号系统（Star_Designation，玩家头顶名牌）。原版只有名字、图标、颜色三项，没有能力加成：
## - 称号表：插件参数 Designation 1～100（冻结源 30 条）→ $dataStarDesignationOpt；kyo 专属成就另登记 31 号
##   （installKyoAchievementRuntime syncDesignation：名字「kyo专属」、图标 240202、颜色 #f5f7fa，解锁跟着成就 143 是否到手）。
## - 解锁：ConfigManager.DesignationN（全局配置，所有存档共用，XConfig.designations）；事件脚本「ConfigManager.DesignationN[N] = true;」。
## - 当前称号：$gamePlayer.DesignationName／DesignationIcon／DesignationColor（进存档，XState.designation）。
## - 选择：Star.Designation.ChooseTitle 预约的公共事件——选项是全部称号（没解锁的显示 \I[0]???），取消清空，选到 ??? 不变。
## 参照 mv_oracle/designation_probe.cjs（tests/fixtures/designation_oracle.json）。头顶名牌的画面是第二期。

const KYO_ID := 31
const KYO_ACHIEVEMENT := 143

static func params() -> Dictionary:
	return XDB.plugin("Star_Designation")

static func show_text() -> String:
	return str(params().get("ShowText", ""))

## [{id, name, icon, color}]，按编号；kyo 专属 31 号接在最后
static func table() -> Array:
	var out := []
	var p := params()
	for i in range(1, 101):
		var raw = p.get("Designation %d" % i, "")
		var d = JSON.parse_string(str(raw)) if str(raw) != "" else null
		if d is Dictionary:
			out.append({"id": i, "name": str(d.get("DesignationName", "")), "icon": int(float(str(d.get("DesignationIcon", "0")))), "color": str(d.get("DesignationColor", ""))})
	if not out.any(func(d): return int(d.id) == KYO_ID):
		out.append({"id": KYO_ID, "name": "kyo专属", "icon": 240202, "color": "#f5f7fa"})
	return out

static func unlocked(id: int) -> bool:
	if id == KYO_ID:
		return XAchievement.global_has(KYO_ACHIEVEMENT)  # syncDesignation：DesignationN[31] = K.owned()
	return XConfig.designations().get(str(id)) == true

## 事件脚本 ConfigManager.DesignationN[N] = true
static func unlock(id: int) -> void:
	var n := XConfig.designations()
	if n.get(str(id)) != true:
		n[str(id)] = true
		XConfig.save_designations()

## 选择称号公共事件的选项文字（\I[图标]名字；没解锁的 \I[0]???）
static func choices() -> Array:
	return table().map(func(d): return "\\I[%d]%s" % [int(d.icon), d.name] if unlocked(int(d.id)) else "\\I[0]???")

## 选中后（branch：选项下标；取消为负）：取消清空成 {name "", icon 0, color #ffffff}；选到 ??? 不变
static func apply_choice(s: XState, branch: int) -> void:
	if branch < 0:
		s.designation = {"name": "", "icon": 0, "color": "#ffffff"}
		return
	var list := table()
	if branch >= list.size() or not unlocked(int(list[branch].id)):
		return
	var d: Dictionary = list[branch]
	s.designation = {"name": d.name if d.name != "" else "", "icon": int(d.icon), "color": d.color if d.color != "" else "#ffffff"}

## Star.Designation.ChooseTitle：提示文字＋选项（取消类型 -2，默认 -1，位置 1），按选中项设称号
static func choose(interp) -> void:
	var list := [{"code": 101, "indent": 0, "parameters": ["", 0, 0, 2]}, {"code": 401, "indent": 0, "parameters": [show_text()]},
		{"code": 102, "indent": 0, "parameters": [choices(), -2, -1, 1, 0]}, {"code": 0, "indent": 0, "parameters": []}]
	var sub := MVInterpreter.new(interp.host, interp.map_id, interp.event_id, list, interp._depth + 1)
	await sub.run()
	apply_choice(XState.current, int(sub._branch.get(0, -2)))
