class_name XCustomDamage
extends RefCounted
## 冻结 v0.28 的带副作用伤害块。按公式摘要认领，未知脚本仍报告未翻译。
## 净化之雷（857／858／4013）：先直接扣 HP 3000，再按双方上限扣目标 MP／TP，最后 value 取本次扣 TP 的一半向上取整。
## HP 临时变量与中间 value 会被后文覆盖；保留原版最终赋值与执行顺序。
const PURIFY_SHA := "19428a3beaccd5b11fc8cee047bb0a0108b31ac3023dfad2f476cb2f4afce6d8"

static func supports(item: Dictionary) -> bool:
	return item.has("stypeId") and [857, 858, 4013].has(int(item.get("id", 0))) \
		and bool(item.damage.get("custom", false)) and str(item.damage.get("formula", "")).sha256_text() == PURIFY_SHA

static func evaluate(_item: Dictionary, a: XBattler, b: XBattler) -> float:
	b.hp -= 3000.0
	b.refresh_resources()
	# gainMp／gainTp 的 refresh 夹资源；HP 阶段已处理阵亡，避免重复附加死亡状态与重抽状态时长。
	var mp_loss := minf(ceilf(b.mp * 0.5), ceilf(a.mmp * 0.5))
	b.mp = clampf(b.mp - mp_loss, 0.0, b.mmp)
	var tp_loss := minf(ceilf(b.tp * 0.5), ceilf(a.max_tp() * 0.5))
	b.tp = clampf(b.tp - tp_loss, 0.0, b.max_tp())
	return ceilf(tp_loss * 0.5)
