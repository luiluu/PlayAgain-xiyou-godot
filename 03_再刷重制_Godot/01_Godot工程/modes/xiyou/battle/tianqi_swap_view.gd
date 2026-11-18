class_name XTianqiSwapView
extends RefCounted
## T182（T086-c，私密仓《天启篇_发作真换人 v0.2》第三节第 2～4 条、第七节 battle_scene 一行）：发作真换人的画面。只读逻辑层，不改规则。
## - 演出：发作强制换人、自动换回照逻辑层的 tianqi_swap 记录换图（XBattleScene._tianqi_swap_view）。被换下的先闪红淡出，上场的淡入，
##   日志报一句、停一下；不弹对话框（挂机、自动战斗不卡）。玩家自己点的「换人」照旧（对话框那句）。
## - 锁定：助力位锁着时「换人」指令照样列出、变灰，选中时在指令旁边写原因；队伍面板下面挂一行「助力位：谁、锁定还剩几回合」。
## - 文字小A 定稿（T182 核查报告第二节）。

## 演出时长（物理帧，60／秒）
const FADE_OUT_FRAMES := 14
const FADE_IN_FRAMES := 14
const HOLD_FRAMES := 30

## 玩家可见文字（小A 定稿，T182 核查报告第二节）。%s 是角色名，%d 是回合数
const TEXT_FORCED := "%s被迫退下，%s接替上场！"
const TEXT_AUTO_BACK := "%s退下，%s重返场上。"
const TEXT_LOCK_REASON := "助力位暂不可换：%s还需 %d 回合"
const TEXT_LOCK_HUD := "助力位　%s　暂不可换 · 还剩 %d 回合"
const TEXT_SWAP_CMD := "换人"


## 记录是哪一种：forced（发作强制换下）、auto（自动换回）、manual（玩家自己点的）
static func kind_of(rec: Dictionary) -> String:
	if bool(rec.get("forced", false)):
		return "forced"
	if bool(rec.get("auto", false)):
		return "auto"
	return "manual"


static func line(kind: String, out: XActor, h: XActor) -> String:
	match kind:
		"forced":
			return TEXT_FORCED % [out.display_name(), h.display_name()]
		"auto":
			return TEXT_AUTO_BACK % [out.display_name(), h.display_name()]
	return ""


## 助力位锁定还剩几回合（含这一回合；没锁为 0）。换下那回合算第 1 回合（lock_until＝换下回合＋锁定回合−1）
static func lock_left(logic) -> int:
	if logic == null or not XTianqiBrand.swap_locked(logic):
		return 0
	return maxi(0, int(XTianqiBrand.swap_data(logic).get("lock_until", -1)) - int(logic.turn) + 1)


## 锁着的是谁：助力位上坐着的、正是最近一次被强制换下去的人（结算前还原之后助力位换了人，不再报）
static func locked_actor(logic) -> XActor:
	if lock_left(logic) <= 0 or logic.state == null:
		return null
	var h: XActor = logic.state.helper()
	return h if h != null and int(h.actor_id) == int(XTianqiBrand.swap_data(logic).get("last_out", 0)) else null


## 「换人」指令：能换就是平常那项；助力位锁着、其它条件都过时列出变灰的一项带原因；别的情况不列（同 T181 前）
static func command_entry(logic, a) -> Dictionary:
	if logic.can_tianqi_swap(a):
		return {"text": TEXT_SWAP_CMD, "key": "tianqiSwap"}
	var h := locked_actor(logic)
	if h == null or not _would_swap(logic, a, h):
		return {}
	return {"text": TEXT_SWAP_CMD, "key": "tianqiSwap", "enabled": false, "reason": TEXT_LOCK_REASON % [h.display_name(), lock_left(logic)]}


## 撇开锁定，这个人平常有没有「换人」这一项：can_tianqi_swap 除锁定以外的每一条（助力位活着、D57 超强者拦截含临时口子、上场上限），
## 锁过之后有就是有、没有就是没有，锁着时不会先灰后消失（T182 核查 P3-2）
static func _would_swap(logic, a, h: XActor) -> bool:
	var s: XState = logic.state
	if not XTianqi.SWAP_IN_BATTLE or not XTianqi.active(s) or not a is XActor or not logic.actors.has(a):
		return false
	if h == a or logic.actors.has(h) or not h.is_alive() or XActorModules.IDS.has(h.actor_id) or XActorModules.IDS.has(a.actor_id):
		return false
	if XTianqi.HELPER_RULES and not a.is_alive():
		return false
	var h_super := XTianqiSkills.is_super(h.actor_id, true)
	if XTianqi.HELPER_RULES and not XTianqi.helper_super_ok(s) and (h_super or XTianqiSkills.is_super(a.actor_id, true)) \
			and not (XTianqiBrand.REAL_SWAP and not XTianqiBrand.snap_of(logic).is_empty() and h_super):
		return false
	if h_super and not XTianqiSkills.is_super(a.actor_id, true):
		return logic.actors.filter(func(x): return x is XActor and XTianqiSkills.is_super(x.actor_id, true)).size() < XTianqi.super_cap(s)
	return true


static func hud_text(logic) -> String:
	var h := locked_actor(logic)
	return "" if h == null else TEXT_LOCK_HUD % [h.display_name(), lock_left(logic)]


## 小字条：队伍面板下的锁定行、指令旁的原因共用
static func make_tag(z := 9) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.border_color = Color(0.85, 0.25, 0.25, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := XUI.label("", 18)
	l.name = "Text"
	p.add_child(l)
	p.z_index = z
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	return p


static func set_tag(p: PanelContainer, text: String) -> void:
	if p == null:
		return
	(p.get_node("Text") as Label).text = text
	p.visible = text != ""
	p.reset_size()


static func tag_text(p: PanelContainer) -> String:
	return (p.get_node("Text") as Label).text if p != null and p.visible else ""
