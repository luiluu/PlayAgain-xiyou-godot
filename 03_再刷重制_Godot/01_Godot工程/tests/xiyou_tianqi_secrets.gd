extends Node
## T446（T013-1b）秘籍格核心系统专项：
## 1) 弱 6 / 强 4 / 超 3 格数上限、占格与豁免判定（功法/通用被动 code 43+44/元素转换/深渊六式 vs 号卷/抽奖被动/主动/血脉/变身/自带）；
## 2) 元素转换书首次占 1 格、已学转换书原地替换；
## 3) 满格拦截（不消耗物品、弹提示）＋花场钱封印（不退书、腾格、被动与总账 bySource 立即失效）＋启封；
## 4) 老存档超格迁移（不没收、超出进已封、一次免费自选生效格）＋ flags.tianqi.secrets 真实写盘读档往返与幂等；
## 5) 新旧两套皮肤技能页 UI 展示与封印交互（--out=<目录> 非 headless 时拍 16:9／20:9 截图）；
## 6) ENABLED = false 完整回退到旧临时截断；西游档零字段、零变化。

const Kit := preload("res://tests/lib/tq_save_kit.gd")

var results: Array = []
var kit: Kit
var out_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	_run.call_deferred()


func _check(name: String, ok: bool, detail = null) -> bool:
	results.append({"name": name, "passed": ok, "detail": detail})
	if not ok:
		print("FAIL ", name, " ", JSON.stringify(detail))
	return ok


func _frames(n := 2) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _windowed() -> bool:
	return out_dir != "" and DisplayServer.get_name() != "headless"


func _clear_toasts() -> void:
	var root := get_tree().root
	for ch in root.get_children():
		if ch is XToast or ch is XSkinNoticeLane:
			ch.queue_free()
	await _frames(2)


func _shot(tag: String) -> void:
	if not _windowed():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img := get_viewport().get_texture().get_image()
	_check("screenshot_" + tag, img.save_png(out_dir.path_join(tag + ".png")) == OK, img.get_size())
	if tag.ends_with("_20x9"):
		_check("shot_size_" + tag, img.get_size() == Vector2i(1000, 450), img.get_size())
	elif tag.ends_with("_16x9"):
		_check("shot_size_" + tag, img.get_size() == Vector2i(800, 450), img.get_size())


func _shots_pair(tag: String) -> void:
	if not _windowed():
		return
	var win := get_window()
	var old_sz := win.size
	var old_aspect := win.content_scale_aspect
	win.unresizable = false
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.size = Vector2i(800, 450)
	DisplayServer.window_set_size(Vector2i(800, 450))
	await _frames(10)
	await _shot(tag + "_16x9")
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	win.size = Vector2i(1000, 450)
	DisplayServer.window_set_size(Vector2i(1000, 450))
	await get_tree().create_timer(0.5).timeout
	await _frames(10)
	await _shot(tag + "_20x9")
	win.content_scale_aspect = old_aspect
	win.size = old_sz
	DisplayServer.window_set_size(old_sz)
	await _frames(4)


func _find_actor_by_tier(s: XState, tier: String) -> XActor:
	for rec in XDB.table("Actors"):
		if not (rec is Dictionary):
			continue
		var aid := int(rec.get("id", 0))
		if aid <= 0 or str(rec.get("name", "")) == "":
			continue
		var a := s.actor(aid)
		if a != null and XTier.tier_of(a) == tier:
			return a
	return null


func _pick_gongfa_items(n: int) -> Array:
	var out := []
	for it in XDB.table("Items"):
		if not (it is Dictionary):
			continue
		for e in it.get("effects", []):
			if int(e.get("code", 0)) == 43:
				var sid := int(e.get("dataId", 0))
				var sk := XDB.rec("Skills", sid)
				if int(sk.get("stypeId", 0)) == 6 and XTianqiSecrets.occupies_slot(sid) and not out.any(func(x): return x[1] == sid):
					out.append([int(it.id), sid])
					if out.size() >= n:
						return out
	return out


# ---- 1. 格数上限与占格判定 ----

func _test_classification() -> void:
	var s := Kit.new_game()
	var weak := _find_actor_by_tier(s, XTier.WEAK)
	var strong := _find_actor_by_tier(s, XTier.STRONG)
	var sup := _find_actor_by_tier(s, XTier.SUPER)
	_check("tier_actors_found", weak != null and strong != null and sup != null)
	_check("cap_weak_6", XTianqiSecrets.limit(weak) == 6, XTianqiSecrets.limit(weak))
	_check("cap_strong_4", XTianqiSecrets.limit(strong) == 4, XTianqiSecrets.limit(strong))
	_check("cap_super_3", XTianqiSecrets.limit(sup) == 3, XTianqiSecrets.limit(sup))
	# 占格：功法、通用被动 code 43、CE code 44 被动、元素转换书（老+新）、深渊六式被动、止戈/天怒
	var must_slot := [7136, 7166, 488, 2471, 3680, 3687, 5189, 5068, 5072, 11201, 11205, 6192, 6203, 6206, 6211, 6185, 6204]
	var bad_slot := must_slot.filter(func(id): return not XTianqiSecrets.occupies_slot(id))
	_check("occupies_slot_positive", bad_slot.is_empty(), bad_slot)
	# 不占格：主动书（战技/魔法）、抽奖被动 stype=5、号卷、27 本血脉、外观变身卡、超越极限、转换药剂
	var bloodlines := [2807, 2808, 2809, 2810, 2811, 2812, 2813, 3224, 3225, 3226, 3227, 3228, 3229, 3230, 3231, 3232, 3233, 3234, 3235, 3236, 4701, 4702, 4703, 4704, 4705, 4706, 4707]
	var blood_wrong := bloodlines.filter(func(id): return XTianqiSecrets.occupies_slot(id))
	_check("bloodlines_exempt_27", blood_wrong.is_empty(), blood_wrong)
	var costumes_wrong := [6801, 6820, 6858].filter(func(id): return XTianqiSecrets.occupies_slot(id))
	_check("costumes_exempt", costumes_wrong.is_empty(), costumes_wrong)
	var not_book_wrong := [1240, 1241, 1242, 1244].filter(func(id): return XTianqiSecrets.occupies_slot(id))
	_check("not_book_exempt", not_book_wrong.is_empty(), not_book_wrong)
	# 主动书（284 冰锥术 stype=2、2249 投石问路）与抽奖被动（6301 stype=5）不占格
	_check("active_and_lottery_exempt", not XTianqiSecrets.occupies_slot(284) and not XTianqiSecrets.occupies_slot(6301))
	# 号卷不占格
	var power_ids := XPowerBooks.skills()
	_check("power_books_exempt", not power_ids.is_empty() and not XTianqiSecrets.occupies_slot(int(power_ids[0])), power_ids.slice(0, 3))
	# 转换药剂 1058 不归秘籍格拦截
	_check("ignore_potion_1058", XTianqiSecrets.item_effective(sup, XDB.rec("Items", 1058), s) == -1)


# ---- 2. 元素转换书占格与原地替换 ----

func _test_conversion_replace() -> void:
	var s := Kit.new_game()
	var sup := _find_actor_by_tier(s, XTier.SUPER)  # 3 格
	var books := _pick_gongfa_items(4)
	sup.learn_skill(int(books[0][1]))
	sup.learn_skill(int(books[1][1]))
	_check("conv_before_used_2", XTianqiSecrets.used_slots(sup, s) == 2)
	# 第 3 格学元素转换:火（5068）
	_check("conv_item_1035_ok", XTianqiSecrets.item_effective(sup, XDB.rec("Items", 1035), s) == 1)
	sup.learn_skill(5068)
	_check("conv_first_occupies_slot", XTianqiSecrets.used_slots(sup, s) == 3 and sup.skill_ids.has(5068))
	# 满格 3/3 时，普通功法被拦
	_check("conv_full_blocks_normal", XTianqiSecrets.blocks_learn(sup, int(books[2][1]), s) and not XTianqiSecrets.item_learn_reason(sup, XDB.rec("Items", int(books[2][0])), s).is_empty())
	# 满格 3/3 时，再学另一门转换书（冰 5069 / 物品 1036；水 11201 / 物品 3101）→ 原地替换放行！
	_check("conv_replace_item_1036_allowed", XTianqiSecrets.item_learn_reason(sup, XDB.rec("Items", 1036), s).is_empty() and XTianqiSecrets.item_effective(sup, XDB.rec("Items", 1036), s) == 1)
	sup.learn_skill(5069)
	_check("conv_replaced_in_place", sup.skill_ids.has(5069) and not sup.skill_ids.has(5068) and XTianqiSecrets.used_slots(sup, s) == 3)
	_check("conv_replace_new_11201_allowed", XTianqiSecrets.can_learn(sup, 11201, s))
	sup.learn_skill(11201)
	_check("conv_replaced_with_water", sup.skill_ids.has(11201) and not sup.skill_ids.has(5069) and XTianqiSecrets.used_slots(sup, s) == 3)
	# 把 11201 封印后再塞满 3 本普通功法：此时无生效转换书，再学 5068 必须被满格拦
	s.gold = 999999
	var sr := XTianqiSecrets.seal(s, sup, 11201)
	_check("conv_sealed_ok", bool(sr.get("ok", false)) and XTianqiSecrets.used_slots(sup, s) == 2)
	sup.learn_skill(int(books[2][1]))
	_check("conv_sealed_then_full_blocks_new_conv", XTianqiSecrets.used_slots(sup, s) == 3 and XTianqiSecrets.blocks_learn(sup, 5068, s))


# ---- 3. 满格拦截（含 item_scene 实测不消耗）＋花场钱封印与被动/总账立即失效 ----

func _test_intercept_and_seal() -> void:
	var s := Kit.new_game()
	s.set_variable(20, 10)  # 10 层测场钱
	var sup := _find_actor_by_tier(s, XTier.SUPER)  # 3 格
	s.party = [sup.actor_id]
	s.battle_slots = [sup.actor_id]
	# 选 4 本带终伤的功法（7166/7167/7168/7179 等）
	var books := []
	for sid in [7166, 7167, 7168, 7179]:
		for it in XDB.table("Items"):
			if it is Dictionary:
				for e in it.get("effects", []):
					if int(e.get("code", 0)) == 43 and int(e.get("dataId", 0)) == sid:
						books.append([int(it.id), sid])
						break
	_check("harm_books_found", books.size() == 4, books)
	for i in range(3):
		sup.learn_skill(int(books[i][1]))
	sup.refresh_passive()
	_check("sup_full_3_of_3", XTianqiSecrets.used_slots(sup, s) == 3)
	# 挂 XItemScene 真实用第 4 本功法书与 CE 转换书 1035：被拦、不消耗
	var extra_item_id := int(books[3][0])
	var extra_skill_id := int(books[3][1])
	s.gain_item(extra_item_id, 2)
	s.gain_item(1035, 1)
	var old_skin := XUiSkin.ENABLED
	XUiSkin.ENABLED = false
	var isc := XItemScene.new()
	add_child(isc)
	await _frames(2)
	isc._item = XDB.rec("Items", extra_item_id)
	isc._actor = 0
	XToast.shown.clear()
	_check("item_scene_full_ineffective", not isc._effective(sup))
	isc._use()
	_check("item_scene_full_no_consume", s.item_count(extra_item_id) == 2 and not sup.skill_ids.has(extra_skill_id), [s.item_count(extra_item_id), sup.skill_ids.has(extra_skill_id)])
	_check("item_scene_full_toast_shown", not XToast.shown.is_empty() and str(XToast.shown[XToast.shown.size() - 1]).contains("最多装备 3 本秘籍"), XToast.shown)
	# CE 元素转换书 1035 也被拦、不消耗
	isc._item = XDB.rec("Items", 1035)
	_check("item_scene_conv_full_ineffective", not isc._effective(sup))
	isc._use()
	_check("item_scene_conv_full_no_consume", s.item_count(1035) == 1 and s.peek_common_event() == 0)
	isc.queue_free()
	await _frames(2)
	XUiSkin.ENABLED = old_skin

	# 封印前：记录终伤被动与 bySource
	var by_before: Dictionary = sup.passive_cache().get("bySource", {})
	var book0_sid := int(books[0][1])
	var book0_key := "#%d" % book0_sid
	var harm_before := float(sup.passive_cache().get("globalHarmRi", 0.0))
	_check("before_seal_in_by_source", by_before.get("books", {}).get("globalHarmRi", {}).has(book0_key), by_before.get("books", {}).get("globalHarmRi", {}))
	# 精魂不足被拒
	var cost := XTianqiSecrets.seal_cost(s, sup)
	_check("seal_cost_positive", cost > 0 and cost == XTianqiMoney.price(s, 5.0), cost)
	s.gold = cost - 1
	var fail_res := XTianqiSecrets.seal(s, sup, book0_sid)
	_check("seal_insufficient_gold", not bool(fail_res.get("ok", false)) and s.gold == cost - 1 and not XTianqiSecrets.is_sealed(sup, book0_sid, s))
	# 精魂充足花场钱封印：扣钱、不退书、腾出 1 格、skill_ids 仍在、被动与 bySource 立即失效
	s.gold = cost + 500
	var item0_before := s.item_count(int(books[0][0]))
	var ok_res := XTianqiSecrets.seal(s, sup, book0_sid)
	_check("seal_paid_ok", bool(ok_res.get("ok", false)) and s.gold == 500 and s.item_count(int(books[0][0])) == item0_before)
	_check("seal_slot_freed_and_kept_in_skill_ids", XTianqiSecrets.used_slots(sup, s) == 2 and sup.skill_ids.has(book0_sid) and XTianqiSecrets.is_sealed(sup, book0_sid, s))
	var by_after: Dictionary = sup.passive_cache().get("bySource", {})
	var harm_after := float(sup.passive_cache().get("globalHarmRi", 0.0))
	_check("seal_passive_dropped_immediately", harm_after < harm_before and not sup.skills().any(func(sk): return int(sk.get("id", 0)) == book0_sid), [harm_before, harm_after])
	_check("seal_excluded_from_by_source", not by_after.get("books", {}).get("globalHarmRi", {}).has(book0_key), by_after.get("books", {}).get("globalHarmRi", {}))
	# 腾格后可以学第 4 本
	sup.learn_skill(extra_skill_id)
	_check("learn_after_seal_ok", sup.skill_ids.has(extra_skill_id) and XTianqiSecrets.used_slots(sup, s) == 3)
	# 满格时启封被拦
	var up_fail := XTianqiSecrets.unseal(s, sup, book0_sid)
	_check("unseal_blocked_when_full", not bool(up_fail.get("ok", false)))
	# 再封一本后启封 book0_sid 立即恢复生效
	s.gold = cost * 2
	XTianqiSecrets.seal(s, sup, extra_skill_id)
	var up_ok := XTianqiSecrets.unseal(s, sup, book0_sid)
	_check("unseal_restores_passive", bool(up_ok.get("ok", false)) and not XTianqiSecrets.is_sealed(sup, book0_sid, s) and sup.skills().any(func(sk): return int(sk.get("id", 0)) == book0_sid))


# ---- 4. 老存档迁移 + flags.tianqi.secrets 写盘读档往返 + 西游档零字段 ----

func _test_save_and_migration() -> void:
	# 4a) 新天启篇档：懒建（未触及 secrets 时 flags.tianqi 无 secrets）
	var s := Kit.new_game()
	_check("new_save_lazy_no_secrets", XTianqiSave.peek(s, "secrets") == null and not s.flags.tianqi.has("secrets"))
	# 4b) 封印后真实写盘读档往返＋幂等
	var sup := _find_actor_by_tier(s, XTier.SUPER)
	var books := _pick_gongfa_items(5)
	sup.learn_skill(int(books[0][1]))
	sup.learn_skill(int(books[1][1]))
	s.gold = 999999
	XTianqiSecrets.seal(s, sup, int(books[0][1]))
	var loaded := kit.roundtrip()
	_check("rt_secrets_loaded", loaded != null and XTianqiSave.version(loaded, "secrets") == 1)
	var sup2 := loaded.actor(sup.actor_id)
	_check("rt_sealed_preserved", XTianqiSecrets.is_sealed(sup2, int(books[0][1]), loaded) and not sup2.skills().any(func(sk): return int(sk.get("id", 0)) == int(books[0][1])))
	var j1 := JSON.stringify(kit.roundtrip().flags.tianqi, "", true)
	var j2 := JSON.stringify(kit.roundtrip().flags.tianqi, "", true)
	_check("rt_secrets_idempotent", j1 == j2)

	# 4c) 老天启篇档迁移：模拟旧版本超格（超强者学了 5 本功法，档里无 secrets 节）
	var legacy_s := Kit.new_game()
	var lsup := _find_actor_by_tier(legacy_s, XTier.SUPER)  # 3 格
	XTianqiSecrets.ENABLED = false
	for i in range(5):
		lsup.learn_skill(int(books[i][1]))
	XTianqiSecrets.ENABLED = true
	kit.save()
	kit.legacy(["secrets", "v"])
	var migrated := kit.reload()
	var msup := migrated.actor(lsup.actor_id)
	_check("legacy_not_confiscated", books.all(func(b): return msup.skill_ids.has(int(b[1]))))
	_check("legacy_active_clamped_3", XTianqiSecrets.used_slots(msup, migrated) == 3, XTianqiSecrets.used_slots(msup, migrated))
	_check("legacy_overflow_2_sealed", XTianqiSecrets.sealed_ids(msup, migrated).size() == 2, XTianqiSecrets.sealed_ids(msup, migrated))
	_check("legacy_free_pick_granted", XTianqiSecrets.has_free_pick(msup, migrated))
	# 免费自选：免费封印（0 精魂）＋启封另一本＋完成自选后恢复收费
	migrated.gold = 0
	var act0 := XTianqiSecrets.active_ids(msup, migrated)[0]
	var seal0 := XTianqiSecrets.sealed_ids(msup, migrated)[0]
	var fr := XTianqiSecrets.seal(migrated, msup, act0)
	_check("legacy_free_seal_zero_cost", bool(fr.get("ok", false)) and int(fr.get("cost", -1)) == 0 and migrated.gold == 0)
	var ur := XTianqiSecrets.unseal(migrated, msup, seal0)
	_check("legacy_free_unseal_ok", bool(ur.get("ok", false)) and XTianqiSecrets.used_slots(msup, migrated) == 3)
	XTianqiSecrets.finish_free_pick(migrated, msup)
	_check("legacy_finish_free_restores_cost", not XTianqiSecrets.has_free_pick(msup, migrated) and XTianqiSecrets.seal_cost(migrated, msup) > 0)
	# 再次读档幂等
	kit.save()
	var m2 := kit.reload()
	var msup2 := m2.actor(lsup.actor_id)
	_check("legacy_reload_idempotent", XTianqiSecrets.active_ids(msup2, m2) == XTianqiSecrets.active_ids(msup, migrated) and XTianqiSecrets.sealed_ids(msup2, m2) == XTianqiSecrets.sealed_ids(msup, migrated) and not XTianqiSecrets.has_free_pick(msup2, m2))

	# 4d) 西游档：零字段、零拦截、读写往返零变化
	var xiyou := XState.new_game(1, 1, [])
	XState.current = xiyou
	var xa := xiyou.actor(int(xiyou.party[0]))
	var extra_books := _pick_gongfa_items(8)
	for b in extra_books:
		xa.learn_skill(int(b[1]))
	_check("xiyou_no_cap_intercept", extra_books.all(func(b): return xa.skill_ids.has(int(b[1]))))
	_check("xiyou_no_tianqi_or_secrets", not xiyou.flags.has("tianqi") or not (xiyou.flags.tianqi as Dictionary).has("secrets"))
	var xrt := kit.roundtrip()
	_check("xiyou_roundtrip_zero_fields", xrt != null and (not xrt.flags.has("tianqi") or not (xrt.flags.tianqi as Dictionary).has("secrets")))


# ---- 5. ENABLED = false 完整回退 ----

func _test_rollback() -> void:
	var s := Kit.new_game()
	var sup := _find_actor_by_tier(s, XTier.SUPER)
	var books := _pick_gongfa_items(5)
	for i in range(3):
		sup.learn_skill(int(books[i][1]))
	s.gold = 999999
	XTianqiSecrets.seal(s, sup, int(books[0][1]))
	_check("rollback_before_sealed", XTianqiSecrets.is_sealed(sup, int(books[0][1]), s) and not sup.skills().any(func(sk): return int(sk.get("id", 0)) == int(books[0][1])))
	XTianqiSecrets.ENABLED = false
	sup.read_touch()
	sup.refresh_passive()
	# 关开关后：已封秘籍恢复进 skills()，且可学超格技能、交回旧临时截断
	_check("rollback_sealed_restored", not XTianqiSecrets.is_sealed(sup, int(books[0][1]), s) and sup.skills().any(func(sk): return int(sk.get("id", 0)) == int(books[0][1])))
	sup.learn_skill(int(books[3][1]))
	sup.learn_skill(int(books[4][1]))
	_check("rollback_no_intercept", sup.skill_ids.has(int(books[3][1])) and sup.skill_ids.has(int(books[4][1])))
	XTianqiSecrets.ENABLED = true


# ---- 6. 两套皮肤功法页 UI 交互与 16:9 / 20:9 截图 ----

func _setup_ui_state() -> Dictionary:
	var s := Kit.new_game()
	s.set_variable(20, 12)
	s.gold = 500000
	var sup := _find_actor_by_tier(s, XTier.SUPER)
	s.party = [sup.actor_id]
	s.battle_slots = [sup.actor_id]
	var books := _pick_gongfa_items(5)
	# 模拟老档迁移：学 5 本功法 → 3 生效 + 2 已封 + 免费自选
	XTianqiSecrets.ENABLED = false
	for b in books:
		sup.learn_skill(int(b[1]))
	XTianqiSecrets.ENABLED = true
	XTianqiSecrets.migrate_after_load(s)
	return {"state": s, "actor": sup, "books": books}


func _open_gongfa_tab(page: XSkillScene) -> bool:
	var ts := page.types()
	var idx := ts.find(6)
	if idx < 0:
		idx = ts.find(4)
	if idx < 0:
		return false
	page.type_index = idx
	page.type_top = XMenu._scroll_to(idx, 0, XSkillScene.TYPE_ROWS)
	page.mode = "list"
	page.index = 0
	page._refresh()
	return true


func _test_ui_both_skins() -> void:
	await _clear_toasts()
	var old_skin := XUiSkin.ENABLED
	# 6a) 新皮肤
	XUiSkin.ENABLED = true
	var d1 := _setup_ui_state()
	var a1: XActor = d1.actor
	var page1 := XSkillScene.new()
	add_child(page1)
	await _frames(3)
	_check("new_skin_built", page1.skin != null)
	_check("new_skin_gongfa_tab", _open_gongfa_tab(page1))
	await _frames(3)
	_check("new_skin_list_title_has_slots", page1.skin.list_title.contains("秘籍格 3 / 3") and page1.skin.list_title.contains("已封 2"), page1.skin.list_title)
	_check("new_skin_entries_include_sealed", page1.entries().size() >= 5 and page1.entries().any(func(sk): return XTianqiSecrets.is_entry_sealed(sk)), page1.entries().size())
	_check("new_skin_card_has_seal_btn", page1.skin._card_actions.size() >= 1 and str(page1.skin._card_actions[0].get("action", "")) == "seal", page1.skin._card_actions)
	await _shots_pair("new_skin_secrets_list")
	# 打开封印确认弹窗（免费自选）
	page1.ok()
	await _frames(3)
	_check("new_skin_confirm_open", page1.mode == "secret_confirm" and page1.skin.confirm_dlg != null)
	await _shots_pair("new_skin_secrets_confirm")
	# 确认免费封印
	page1.confirm_secret_choice(0)
	await _frames(2)
	_check("new_skin_sealed_via_ui", XTianqiSecrets.used_slots(a1, d1.state) == 2 and page1.mode == "list")
	page1.queue_free()
	await _frames(3)
	await _clear_toasts()

	# 6b) 旧皮肤
	XUiSkin.ENABLED = false
	var d2 := _setup_ui_state()
	var a2: XActor = d2.actor
	XTianqiSecrets.finish_free_pick(d2.state, a2)  # 旧皮肤展示花钱封印
	var page2 := XSkillScene.new()
	add_child(page2)
	await _frames(3)
	_check("old_skin_built", page2.skin == null)
	_check("old_skin_gongfa_tab", _open_gongfa_tab(page2))
	await _frames(3)
	_check("old_skin_entries_include_sealed", page2.entries().size() >= 5 and page2.entries().any(func(sk): return XTianqiSecrets.is_entry_sealed(sk)))
	await _shots_pair("old_skin_secrets_list")
	# 打开花钱封印确认窗
	page2.ok()
	await _frames(3)
	_check("old_skin_confirm_open", page2.mode == "secret_confirm" and page2.secret_win.visible)
	await _shots_pair("old_skin_secrets_confirm")
	var gold_before := int(d2.state.gold)
	page2.confirm_secret_choice(0)
	await _frames(2)
	_check("old_skin_paid_seal_via_ui", XTianqiSecrets.used_slots(a2, d2.state) == 2 and d2.state.gold < gold_before and page2.mode == "list")
	page2.queue_free()
	await _frames(2)
	XUiSkin.ENABLED = old_skin


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_secrets")
	_test_classification()
	_test_conversion_replace()
	await _test_intercept_and_seal()
	_test_save_and_migration()
	_test_rollback()
	await _test_ui_both_skins()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
