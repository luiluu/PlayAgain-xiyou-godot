class_name XTianqiAlienCodex
extends RefCounted
## 【cc·天启篇·未经审查】天启篇异化图鉴本线页（四线剧情与关卡设计稿 v0.4 第 6 节「异化图鉴本线页：本线 5 种异化 × 四级，线内逐步点亮」；
## 跨存档按 Kyo 11-11 选的乙：图鉴跨档保留，不带数值）。
## - 记：赢下的战斗里倒下的本线异化怪（各线异化模块本场的 units），点亮「线:种类:级」，存在全局配置 codexTianqiAliens（XConfig）。
##   由 XTianqiAlienGear.grant（BattleLogic.grant，赢了发奖时）先调 record。
## - 看：异化工坊页（天启篇存档）底下一节「本线异化图鉴」，本线每种一行，四级各一格，打倒过的亮名字，没打过的「？？」。
## 只认天启篇存档（XTianqiLine.open_for），开关关着不记也不显示。
##
## 开关（O-345）：false＝不记也不显示异化图鉴

## 开关：false＝没有异化图鉴
static var ENABLED := true

const TIERS := ["qinran", "shigu", "huaxing", "zhongyan"]
const TIER_NAMES := {"qinran": "侵染", "shigu": "蚀骨", "huaxing": "化形", "zhongyan": "终焉"}


static func on(s: XState = null) -> bool:
	if s == null:
		s = XState.current
	return ENABLED and s != null and XTianqiLine.open_for(s)


static func key(line: String, kind: String, tier: String) -> String:
	return "%s:%s:%s" % [line, kind, tier]


## 赢了：本场倒下的本线异化怪点亮；返回新点亮的键
static func record(logic) -> Array:
	var out := []
	if logic == null or not on(logic.state):
		return out
	for u in XTianqiAlienGear.alien_units(logic):
		if not u.enemy.is_dead() or not TIERS.has(str(u.level)):
			continue
		var kind := _kind_of(logic, u.enemy, str(u.line))
		if kind == "":
			continue
		var k := key(str(u.line), kind, str(u.level))
		if XConfig.tianqi_alien_mark(k):
			out.append(k)
	return out


static func _kind_of(logic, e, line: String) -> String:
	var mod = {"war": XTianqiWarAlien, "famine": XTianqiFamineAlien, "plague": XTianqiPlagueAlien, "death": XTianqiDeathAlien}.get(line)
	if mod == null:
		return ""
	return str(mod.unit(logic, e).get("kind", ""))


static func seen(line: String, kind: String, tier: String) -> bool:
	return XConfig.tianqi_aliens().has(key(line, kind, tier))


## 种类的名字（各线表 alien.kinds）
static func kind_name(line: String, kind: String) -> String:
	var mod = {"war": XTianqiWarAlien, "famine": XTianqiFamineAlien, "plague": XTianqiPlagueAlien, "death": XTianqiDeathAlien}.get(line)
	return str(mod.kind_info(kind).get("name", kind)) if mod != null else kind


## 本线的图鉴行：[{kind, name, cells: [{tier, name, seen}…]}…]
static func rows(line: String) -> Array:
	var out := []
	for kind in XTianqiLine.alien_kinds(line):
		var cells := []
		for t in TIERS:
			cells.append({"tier": t, "name": TIER_NAMES[t], "seen": seen(line, str(kind), t)})
		out.append({"kind": str(kind), "name": kind_name(line, str(kind)), "cells": cells})
	return out


## 点亮了几格／一共几格
static func progress(line: String) -> Array:
	var n := 0
	var total := 0
	for r in rows(line):
		for c in r.cells:
			total += 1
			if c.seen:
				n += 1
	return [n, total]
