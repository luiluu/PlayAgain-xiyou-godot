class_name XSkinDialogueFade
extends RefCounted
## 【cc·天启篇·未经审查】T330 剧情对白逐字渐显（带轻模糊，可跳过）。只是画面：不动对白状态机、等待帧、翻页和选项；
## 一页字照旧一帧排完（glyphs 里 MV 核心的「整页立即显示」），这里只在画的时候按「页开始后经过的毫秒」决定每个字的透明度。
## 第 i 个字在 i×STAGGER_MS 毫秒后开始淡入，淡入 FADE_MS 毫秒，淡入途中叠几份偏移的低透明残影当「轻模糊」。
## 只在新皮肤（天启篇存档）里开，菜单、商店等别的窗口不经这里。受设置「界面动效」管：关＝直接显示。
## 跳过：玩家按确认／取消／点击，当页立即显示全句（那一下不翻页，再按才翻）；设置「对话跳过」、快进键时整页不演。
## ENABLED＝false 整套回到 T330 之前（可回退，唯一的开关；O-634）。

static var ENABLED := true

const STAGGER_MS := 38.0   # 相邻两字错开
const FADE_MS := 240.0     # 一个字从全透明到清晰
const BLUR_PX := 2.5       # 刚出现时残影偏移，随淡入收到 0
const GHOST_A := 0.30      # 残影相对透明度（乘字的当前不透明度反比）


static func on() -> bool:
	return ENABLED and XUiSkin.on() and XUiSkin.motion() != XUiSkin.Motion.OFF


## 一页 n 个字演完要多久（毫秒）
static func total_ms(n: int) -> float:
	return 0.0 if n <= 0 else float(n - 1) * STAGGER_MS + FADE_MS


## 第 i 个字在页开始后 elapsed 毫秒时的进度 0～1（ease-out）
static func progress(i: int, elapsed_ms: float) -> float:
	var t := clampf((elapsed_ms - float(i) * STAGGER_MS) / FADE_MS, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 2.0)


## 画一页。elapsed_ms < 0 或已演完＝等同 XMVText.paint
static func paint(c: XMVCanvas, list: Array, elapsed_ms: float) -> void:
	if elapsed_ms < 0.0 or elapsed_ms >= total_ms(list.size()):
		XMVText.paint(c, list)
		return
	for i in range(list.size()):
		var g: Dictionary = list[i]
		var p := progress(i, elapsed_ms)
		if p <= 0.0:
			continue   # 排在后面的字都还没开始（页内按序）
		if g.has("icon"):
			c.icon(int(g.icon), g.x, g.y, p)
			continue
		if p < 1.0:
			var b := (1.0 - p) * BLUR_PX
			var ga := GHOST_A * (1.0 - p)
			for d in [Vector2(b, 0), Vector2(-b, 0), Vector2(0, b), Vector2(0, -b)]:
				c.text(g.t, g.x + d.x, g.y + d.y, g.w * 2.0, "left", g.color, g.size, g.h, ga)
		c.text(g.t, g.x, g.y, g.w * 2.0, "left", g.color, g.size, g.h, p)
