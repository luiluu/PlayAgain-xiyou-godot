class_name XBattleTiming
extends RefCounted
## YEP_BattleAniSpeedOpt 的局部计时。SSEP 默认 2 倍只先作用于移动；不改 Engine.time_scale。


static func wait_frames(frames: int) -> int:
	return ceili(float(maxi(0, frames)) / (5 - XConfig.battle_speed()))


static func move_frames(frames: int) -> int:
	var base := float(XDB.plugin("SSEP_BattleSpeedUp_v2").get("BattleSpeed (Default)", "2"))
	return wait_frames(ceili(float(maxi(0, frames)) / maxf(base, 1.0)))


static func animation_wait(frames: int) -> int:
	return maxi(0, frames) * XConfig.battle_speed()
