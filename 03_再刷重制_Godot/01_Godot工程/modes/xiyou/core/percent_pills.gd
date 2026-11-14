class_name XPercentPills
extends RefCounted
## 后期百分比丹药「淬元丹」（正式版插件 js/plugins/Codex_PercentPills.js，plugins.js 第 172 个、启用）：
## - 物品备注 <CodexPill: mhp|mmp|atk|def|mat|mdf|agi|luk>（现有 2882～2887 六颗），数据库里没有效果栏，效果全在插件里；
## - hasItemAnyValidEffects 包装：对象是角色且该种没满 20 颗才有效（满了「使用」蜂鸣）；
## - applyItemUserEffect 包装：该种计数 +1（存在角色 _codexPills，随存档），refresh，makeSuccess，弹提示「名字 属性 +N%（n/20）」；
## - Game_Actor.param 包装：round(min(paramMax, 值×(1＋2%×颗数)))。插件在 main.js 装各 Codex 运行时之前载入，
##   所以这一层紧贴插件层的 param（XBattler.param），在专属角色模块等运行时包装之内；
## - 商店追加（卖养血丹 1693 的店末尾补上这六颗）在 XItemMarks。
## v0.01.09 只移植了商店追加，使用效果漏了：效果栏为空 → 物品页 testApply 判无效 → 「使用」只蜂鸣（玩家反馈「淬元丹无法使用」）。
## 计数放在 state_data（「状态脚本的私有字段」，随局内存档、equipment 的影子拷贝也带上），键名照原版 _codexPills。

const KEYS := {"mhp": 0, "mmp": 1, "atk": 2, "def": 3, "mat": 4, "mdf": 5, "agi": 6, "luk": 7}
const STEP := 0.02
const CAP := 20
const FIELD := "_codexPills"


## pillOf：物品对应的能力值号，不是淬元丹为 -1
static func param_of(item) -> int:
	if not item is Dictionary:
		return -1
	var k := str(item.get("meta", {}).get("CodexPill", "")).strip_edges()
	return int(KEYS[k]) if KEYS.has(k) else -1


static func count(a, param_id: int) -> int:
	if a == null:
		return 0
	var m = a.state_data.get(FIELD)
	return int(m.get(str(param_id), 0)) if m is Dictionary else 0


## hasItemAnyValidEffects 包装：淬元丹只看「是角色且没满」；返回 -1 表示不是淬元丹（照原来的判断）
static func valid(item, t) -> int:
	var id := param_of(item)
	if id < 0:
		return -1
	return 1 if t is XActor and count(t, id) < CAP else 0


## applyItemUserEffect 包装：吃下一颗。返回是否生效（不是淬元丹、或已满为假）
static func apply(item, t) -> bool:
	var id := param_of(item)
	if id < 0 or not t is XActor or count(t, id) >= CAP:
		return false
	var m = t.state_data.get(FIELD)
	if not m is Dictionary:
		m = {}
	var n := count(t, id) + 1
	m[str(id)] = n
	t.state_data[FIELD] = m
	t.param_mark_dirty()
	t.refresh_resources()
	XToast.show_text("%s %s +%d%%（%d/%d）" % [t.display_name(), XItemStatusPainter.param_name(id), roundi(STEP * 100.0 * n), n, CAP], true)
	return true


## Game_Actor.param 包装
static func param(a, i: int, v: float) -> float:
	var n := count(a, i)
	return roundf(minf(a.param_max(i), v * (1.0 + STEP * n))) if n > 0 else v
