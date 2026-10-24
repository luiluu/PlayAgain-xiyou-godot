extends Node
## 超强者获取限制（冻结 v0.28 js/codex/runtime/installBossDifficultyRuntime.js）：
## 超强者仅限地狱及以上难度获取——持久挑战开关 2494／2489／2487／2483／2461／2462／2463 任一开或难度 ID 9 才放行。
## 包装点：canAcquireItem＝canAcquireId(recruitActorId(item))（号角表、备注 <CodexRecruitActor: n>、效果公共事件里唯一的一条加入队伍）；
## Game_Party.gainItem（得到数量大于 0 时不给）、addActor（未持有时拦下并提示）、meetsItemConditions（物品页「使用」灰）、Window_ShopBuy.isEnabled（商店灰）。
## 商店灰的原版数值由 xiyou_shop_buy 的参照用例对（伙伴号角 245／254／274／277 在原版 exact／rich 状态下都不可买）。
## 未移植：各 Codex*.recruit() 入口（渡鸦等新原生接入）的拦截提示、物品／商店帮助窗的「仅限地狱及以上难度获取与招募」文字、战斗中的物品条件。

const HORNS_SUPER := 45   # 冻结数据里招募角色在超强者名单内的物品数（脚本按同一规则离线数出）

var results := []


func _ready() -> void:
	_run.call_deferred()


func check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail).left(3000))
	return ok


func _state() -> XState:
	var s := XState.new_game_blank()
	s.party.clear()
	for id in [1, 8, 9, 10]:
		s.add_actor(id)
	for sw in XItemMarks.SUPER_SWITCHES:
		s.set_switch(sw, false)
	s.difficulty = 3
	return s


func _run() -> void:
	# 招募角色解析
	var want := {245: 141, 254: 142, 274: 146, 277: 147, 2902: 167, 2941: 174, 1536: 104, 2803: 106, 4: 0}
	for id in want:
		var got := XItemMarks.recruit_actor_id(XDB.rec("Items", id))
		check("recruit_%d" % id, got == int(want[id]), [id, got])
	var n := 0
	for it in XDB.table("Items"):
		if it is Dictionary and XItemMarks.SUPER_STRONG_IDS.has(XItemMarks.recruit_actor_id(it)):
			n += 1
	check("super_horn_count", n == HORNS_SUPER, n)
	# 默认难度：拦下
	var s := _state()
	var horn := XDB.rec("Items", 245)
	check("blocked_item", not XItemMarks.can_acquire_item(s, horn))
	check("normal_item_ok", XItemMarks.can_acquire_item(s, XDB.rec("Items", 4)))
	check("blocked_shop", not XItemMarks.can_buy(s, horn, 1))
	s.gain_item(245, 1)
	check("blocked_gain", s.item_count(245) == 0, s.item_count(245))
	s.gain_item(4, 1)
	check("normal_gain", s.item_count(4) == 1)
	s.add_actor(141)
	check("blocked_actor", not s.party.has(141))
	s.add_actor(12)
	check("normal_actor", s.party.has(12) or XDB.rec("Actors", 12).is_empty())
	# 减少不拦
	s._gain_raw(245, 2)
	s.gain_item(245, -1)
	check("remove_ok", s.item_count(245) == 1, s.item_count(245))
	# 已持有的超强者再次加入不拦（原版只拦未持有）
	s.party.append(141)
	s.add_actor(141)
	check("owned_actor_passes", s.party.has(141))
	# 放行：任一挑战开关、混沌难度
	for sw in XItemMarks.SUPER_SWITCHES:
		var t := _state()
		t.set_switch(sw, true)
		t.gain_item(245, 1)
		t.add_actor(142)
		check("switch_%d_allows" % sw, t.item_count(245) == 1 and t.party.has(142) and XItemMarks.can_acquire_item(t, horn))
	var c := _state()
	c.difficulty = 9
	c.gain_item(245, 1)
	check("difficulty9_allows", c.item_count(245) == 1 and XItemMarks.super_enabled(c))
	var passed := results.filter(func(x): return x.passed).size()
	print("TEST_RESULT=" + JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit.call_deferred(0 if passed == results.size() else 1)
