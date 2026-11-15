class_name XPartyFormation
extends RefCounted
## 战斗我方站位（O-待定，Kyo 2026-11-15「做菱形和两排错开。设置里面可以更改，位置对应上编队位置」）：
## 原版 1～4 人在同一 x 竖排一列（XBattleScene.party_layout），角色放大后上下叠在一起。
## 设置页「战斗站位」三档，存配置 codexPartyFormation：0 两排错开（默认）、1 菱形、2 原版竖排。
## 编队第 k 位固定站阵型的第 k 个点（不按体型换位），谁站哪靠编队决定：
## - 两排错开（4 人）：1 前上、2 前下、3 后上、4 后下；后排比前排低半格（上下错开），「前」＝离敌人近（左）。
##   5 人：前排三人（1 前上、5 前中、2 前下）、后排两人（3 后上、4 后下）。
## - 菱形（4 人）：1 前尖、2 上角、3 下角、4 后尖；5 人时 5 号站菱形中心。
## - 1～3 人：两排 1 人居中；2 人 1 前上、2 前下；3 人 1 前上、2 前下、3 后中。
##   菱形 1 人居中；2 人 1 前尖、2 后尖（斜开）；3 人 1 前尖、2 上角、3 下角。
## - 6 人以上（目前没有）照原版竖排。
## 点位是脚底坐标（1280×720 画面）。可用区：x ≤ 1080 − 半身宽（右侧状态栏）、脚底 y ≤ 600（底部行动顺序条约在 610）、
## 头顶留顶部 Boss 信息框；按将来大体型 ×1.35（可视宽约 180、高约 215）留空：上下相邻同列间隔 ≥ 200、前后排 x 差 160。
## 回退：ENABLED＝false，设置页不列这一项，站位照原版竖排。

static var ENABLED := true
const KEY := "codexPartyFormation"
const ROWS := 0
const DIAMOND := 1
const COLUMN := 2
const NAMES := ["两排错开", "菱形", "原版竖排"]
const DEFAULT := ROWS

## 两排错开：前排 x、后排 x、4 人时四个脚底 y（前上、后上、前下、后下依次低半格）
const ROW_FRONT_X := 790.0
const ROW_BACK_X := 950.0
const ROW_Y := [280.0, 380.0, 480.0, 580.0]
## 菱形：中线 x、前后尖离中线、上下角离中线、中线 y
const DIA_CX := 860.0
const DIA_DX := 125.0
const DIA_DY := 150.0
const DIA_CY := 430.0
## 各点位的名字（交付单、编队提示用），按编队顺序
const SLOT_NAMES := {
	ROWS: ["前上", "前下", "后上", "后下", "前中"],
	DIAMOND: ["前尖", "上角", "下角", "后尖", "中心"],
}


static func current() -> int:
	return XConfig.party_formation() if ENABLED else COLUMN


static func text() -> String:
	return NAMES[clampi(current(), 0, NAMES.size() - 1)]


static func sanitize(v) -> int:
	return clampi(int(v), 0, NAMES.size() - 1) if (v is int or v is float) else DEFAULT


## 第 1～n 位的脚底坐标（按编队顺序）
static func points(kind: int, n: int) -> Array:
	if n <= 0:
		return []
	if kind == COLUMN or n > 5 or not ENABLED:
		return XBattleScene.party_layout(n)
	if kind == DIAMOND:
		return _diamond(n)
	return _rows(n)


static func _rows(n: int) -> Array:
	var fx := ROW_FRONT_X
	var bx := ROW_BACK_X
	match n:
		1:
			return [Vector2((fx + bx) / 2.0, 430.0)]
		2:
			return [Vector2(fx, 330.0), Vector2(fx, 530.0)]
		3:
			return [Vector2(fx, 300.0), Vector2(fx, 540.0), Vector2(bx, 420.0)]
		4:
			return [Vector2(fx, ROW_Y[0]), Vector2(fx, ROW_Y[2]), Vector2(bx, ROW_Y[1]), Vector2(bx, ROW_Y[3])]
	# 5 人：前排 280／430／580，后排 355／505
	return [Vector2(fx, 280.0), Vector2(fx, 580.0), Vector2(bx, 355.0), Vector2(bx, 505.0), Vector2(fx, 430.0)]


static func _diamond(n: int) -> Array:
	var front := Vector2(DIA_CX - DIA_DX, DIA_CY)
	var top := Vector2(DIA_CX, DIA_CY - DIA_DY)
	var bottom := Vector2(DIA_CX, DIA_CY + DIA_DY)
	var back := Vector2(DIA_CX + DIA_DX, DIA_CY)
	match n:
		1:
			return [Vector2(DIA_CX, DIA_CY)]
		2:
			return [Vector2(DIA_CX - 80.0, DIA_CY - 75.0), Vector2(DIA_CX + 80.0, DIA_CY + 75.0)]
		3:
			return [front, Vector2(DIA_CX + 30.0, top.y + 20.0), Vector2(DIA_CX + 30.0, bottom.y - 20.0)]
		4:
			return [front, top, bottom, back]
	return [front, top, bottom, back, Vector2(DIA_CX, DIA_CY)]
