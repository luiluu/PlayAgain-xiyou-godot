class_name XVisualStateFx
extends RefCounted
## YEP_X_VisualStateFX 状态循环动画。参照 oracle/vsfx.json（mv_oracle/vsfx_probe.cjs 量冻结正式源）：
##  - 备注 <State Animation: N>（别名 <State Ani: N>），states() 顺序里第一个有值的状态决定动画号（Game_Battler.stateAnimationId）；
##  - 全游戏只有状态 1297「刻印环身盾」带动画 900「光环(中间呼吸)」（60 帧，位置＝目标中心，没有闪光、音效节点）；
##  - 动画号变化时才重播（相同号不重启）；播完同一帧接着重播（Sprite_StateAnimation.updateLoop）；去掉状态（号变 0）立刻清掉；
##  - 画在身体上（SV 取 _mainSprite），不透明度跟目标；参数 Actor／Enemy State Animation 都是 true。

static func animation_id(b: XBattler) -> int:
	for s in b.states():
		var v = s.get("meta", {}).get("State Animation", s.get("meta", {}).get("State Ani"))
		if v != null:
			var m := RegEx.create_from_string("^\\s*(\\d+)\\s*$").search(str(v))
			if m and int(m.get_string(1)) > 0:
				return int(m.get_string(1))
	return 0
