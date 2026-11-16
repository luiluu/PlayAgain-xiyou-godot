class_name XSkinBattleMotion
extends RefCounted
## 【cc·天启篇·未经审查】T096 战斗界面切换动效（界面风格提案 v0.7 样稿 battle.mp4）：指令环铺开、确定后环淡出＋列表从环那边展开、
## 关窗口收起淡出、换人回合提示、开战时界面淡入。全是画面：不改战斗流程、顺序和随机数，窗口引用照旧当场清掉（收起的只是一个残影）。
## 受设置「界面动效：全部／简化／关」管：全部、简化都演切换（简化只停掉循环的装饰，同环形导航的口径），「关」直接到位。
## ENABLED＝false 整套回到 T096 之前（直接出现、直接消失；可回退）。

static var ENABLED := true

## 样稿的时长（秒）
const RING_ORB_IN := 0.25      # 每颗指令球从 0.6 长到 1
const RING_STAGGER := 0.03     # 相邻两颗错开
const RING_FADE := 0.12        # 环失活（开列表、选目标）时淡出、回来时淡入
const LIST_IN := 0.17          # 列表从 0.3 展开到 1（右边中点为轴，样稿 .sk transform-origin:100% 50%）
const LIST_IN_FROM := 0.3
const CLOSE := 0.12            # 关列表／环：缩到 0.5 淡出
const CLOSE_TO := 0.5
const HUD_IN := 0.26           # 开战：队伍条、行动条、首领血弧淡入（样稿 .in）
const HUD_DELAY := 0.15        # 开战黑幕（24 帧＝0.4 秒）淡到一半再开始，第一块和黑幕后半段叠着
const HUD_STAGGER := 0.06      # 相邻两块错开


## 现在演不演切换
static func on() -> bool:
	return ENABLED and XUiSkin.on() and XUiSkin.motion() != XUiSkin.Motion.OFF


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


## 带一点回弹（样稿 cubic-bezier(.2,1.2,.4,1)）
static func ease_out_back(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1 := 1.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


## 关窗口：演的时候先失活、不接输入，缩到 0.5 淡出后再释放；不演就当场 queue_free（同原来）。
## 调用方照旧把自己手里的引用清成 null。
static func dismiss(w: Node) -> void:
	if w == null or not is_instance_valid(w):
		return
	if not (on() and w is Control and w.is_inside_tree() and (w is XSkinBattleRing or w is XSkinBattleSkillList)):
		w.queue_free()
		return
	var c := w as Control
	if c is XBattleList:
		(c as XBattleList).active = false
		(c as XBattleList).cancel_enabled = false
	c.set_process_unhandled_input(false)
	c.set_process_input(false)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("dismissing", true)
	if c is XSkinBattleSkillList:
		c.pivot_offset = Vector2(c.size.x, c.size.y / 2.0)
	elif c is XSkinBattleRing:
		c.pivot_offset = (c as XSkinBattleRing).center
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if c is XSkinBattleSkillList:   # 环本来就在失活时自己淡出了，只有列表要缩
		tw.tween_property(c, "scale", Vector2.ONE * CLOSE_TO, CLOSE)
	tw.tween_property(c, "modulate:a", 0.0, CLOSE)
	tw.chain().tween_callback(c.queue_free)


## 正在收起的残影（测试、找窗口时跳过）
static func dismissing(n: Node) -> bool:
	return n != null and n.has_meta("dismissing")


## 列表展开：从 0.3 长到 1、淡入（轴在右边中点，靠着环那边）
static func list_in(w: Control) -> void:
	if not on():
		return
	w.pivot_offset = Vector2(w.size.x, w.size.y / 2.0)
	w.scale = Vector2.ONE * LIST_IN_FROM
	w.modulate.a = 0.0
	var tw := w.create_tween().set_parallel(true)
	tw.tween_property(w, "scale", Vector2.ONE, LIST_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "modulate:a", 1.0, LIST_IN * 0.7)


## 开战淡入（只动透明度，不碰位置：各组件的位置由自己的逻辑摆）
static func fade_in(n: CanvasItem, delay := 0.0) -> void:
	if not on() or n == null or not is_instance_valid(n):
		return
	n.modulate.a = 0.0
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "modulate:a", 1.0, HUD_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 开战：各块界面依次淡入（XBattleScene._build_ui 末尾调；只动透明度，演完 modulate.a 回 1）
static func hud_in(nodes: Array) -> void:
	if not on():
		return
	var k := 0
	for n in nodes:
		if n is CanvasItem and is_instance_valid(n):
			fade_in(n, HUD_DELAY + HUD_STAGGER * k)
			k += 1
