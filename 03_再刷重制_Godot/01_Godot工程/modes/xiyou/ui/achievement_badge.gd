class_name XAchievementBadge
extends RefCounted
## 成就 142「本质高手」／143「kyo专属」的专用徽章与特殊样式（installWeakChallengeRuntime／installKyoAchievementRuntime）。
## 参照 achievement_badge_probe（achievement_badges.json）的 canvas 级绘制调用。这里把「画什么」写成数据（plan），
## 界面按 plan 画（paint），测试按 plan 与参照逐项对照。
## - 图标 240201／240202 改画 img/codex_achievements/EssenceMaster.png／KYO.png（256²，缩到目标边长）。
## - 列表行（行高 108、宽 920）：142 已得时徽章 64 在 (6, y)（普通图标是 2 倍在 22），成就名画成渐变描边字（字号 26，baseline = y + 108/3/2 + 26×0.35）；
##   143 不论得否都只画 64 徽章在 (14, y + 22)，未得透明度 80/255，不写「未获得」。
## - 弹窗（高 50）：142 图标 32 在 (10,10)，标题渐变描边字（字号 20，(50,5)，行高 20），上下各 1px 线（#b391d5／#c7a261）；
##   143 窗宽 64、窗口不透明度 0，只画 40 徽章在 ((64−40)/2, (50−40)/2)，无标题与说明。
## - 渐变字：Godot 没有逐字渐变填充，用描边＋阴影（外圈 #9463d0）＋中间色填充近似，参数同参照，画面为近似。

const ESSENCE_ID := 142
const KYO_ID := 143
const FILES := {240201: "EssenceMaster", 240202: "KYO"}
const GRAD := [[0.0, "#fff8db"], [0.45, "#f7dda0"], [1.0, "#c69d55"]]
const STROKE := "#2d1749"
const SHADOW := "#9463d0"
const LINE_TOP := "#b391d5"
const LINE_BOTTOM := "#c7a261"
const NAME := "本质高手"
const POPUP_NAME_SIZE := 20.0
const POPUP_W_KYO := 64.0


static func file_of(icon: int) -> String:
	return str(FILES.get(icon, ""))


static func is_special(ach_id: int) -> bool:
	return ach_id == ESSENCE_ID or ach_id == KYO_ID


## 渐变描边字的 baseline 与渐变区间：height 行高三分之一（列表）或 20（弹窗）
static func name_plan(x: float, y: float, size: float, height: float) -> Dictionary:
	var baseline := y + height / 2.0 + size * 0.35
	return {"op": "gradientText", "text": NAME, "x": x, "baseline": baseline, "size": size, "gradientFrom": baseline - size, "gradientTo": baseline,
		"stops": GRAD, "lineWidth": 3.0, "stroke": STROKE, "shadow": SHADOW, "shadowBlur": 4.0}


## 列表行里需要替换的绘制：返回 {badge, name}（name 为空表示不替换）。owned＝全局已得。
## 143 不论得否都画徽章；142 未得走普通「未获得」，plan 为空。
static func list_plan(ach_id: int, y: float, row_h: float, owned: bool) -> Dictionary:
	if ach_id == KYO_ID:
		return {"badge": {"op": "drawImage", "file": "KYO", "x": 6.0 + 8.0, "y": y + maxf(0.0, (row_h - 64.0) / 2.0), "w": 64.0, "h": 64.0,
			"alpha": 1.0 if owned else 80.0 / 255.0}, "name": {}, "only_badge": true}
	if ach_id == ESSENCE_ID and owned:
		return {"badge": {"op": "drawImage", "file": "EssenceMaster", "x": 6.0, "y": y, "w": 64.0, "h": 64.0, "alpha": 1.0},
			"name": name_plan(6.0 + row_h, y, 26.0, row_h / 3.0), "only_badge": false}
	return {}


## 弹窗：窗宽、窗口不透明度（-1＝照常）、各绘制
static func popup_plan(ach_id: int, width: float, height: float) -> Dictionary:
	if ach_id == KYO_ID:
		return {"width": POPUP_W_KYO, "opacity": 0, "title": false, "message": false,
			"ops": [{"op": "drawImage", "file": "KYO", "x": (POPUP_W_KYO - 40.0) / 2.0, "y": (height - 40.0) / 2.0, "w": 40.0, "h": 40.0, "alpha": 1.0}]}
	if ach_id == ESSENCE_ID:
		return {"width": width, "opacity": -1, "title": false, "message": true,
			"ops": [{"op": "drawImage", "file": "EssenceMaster", "x": 10.0, "y": 10.0, "w": 32.0, "h": 32.0, "alpha": 1.0},
				name_plan(50.0, 5.0, POPUP_NAME_SIZE, 20.0)],
			"after": [{"op": "fillRect", "x": 0.0, "y": 0.0, "w": width, "h": 1.0, "color": LINE_TOP},
				{"op": "fillRect", "x": 0.0, "y": height - 1.0, "w": width, "h": 1.0, "color": LINE_BOTTOM}]}
	return {}


## 在画布上执行一条 plan 操作
static func paint_op(c: XMVCanvas, op: Dictionary) -> void:
	match str(op.op):
		"drawImage":
			c.badge(str(op.file), float(op.x), float(op.y), float(op.w), float(op.alpha))
		"gradientText":
			c.gradient_text(op)
		"fillRect":
			c.fill_rect(Rect2(float(op.x), float(op.y), float(op.w), float(op.h)), Color(str(op.color)))
