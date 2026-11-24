extends Node
## T446（T013-1b）秘籍格核心系统专项：
## 1) 弱 6 / 强 4 / 超 3 格数上限、占格与豁免判定（功法/通用被动 code 43+44/元素转换/深渊六式 vs 号卷/抽奖被动/主动/血脉/变身/自带）；
## 2) 元素转换书首次占 1 格、已学转换书原地替换；
## 3) 满格拦截（不消耗物品、弹提示）＋花场钱封印（不退书、腾格、被动与总账 bySource 立即失效）＋启封；
## 4) 老存档超格迁移（不没收、超出进已封、一次免费自选生效格）＋ flags.tianqi.secrets 真实写盘读档往返与幂等；
## 5) 新旧两套皮肤技能页 UI 展示与封印交互（--out=<目录> 非 headless 时拍 16:9／20:9 截图）；
## 6) ENABLED = false 完整回退到旧临时截断；西游档零字段、零变化。

const Kit := preload("res://tests/lib/tq_save_kit.gd")

class FakeMapHost extends Node:
	var toasts: Array = []
	func toast(text: String) -> void:
		toasts.append(text)
	func character(_ev: int, _id: int):
		return null

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
	for aid in XTianqiSkills.ids(tier):
		var a := s.actor(int(aid))
		if a != null and XTianqiSkills.tier_of(a) == tier:
			return a
	return null


func _pick_gongfa_items(n: int) -> Array:
	var out := []
	var seen_sc := {}
	for it in XDB.table("Items"):
		if not (it is Dictionary):
			continue
		for e in it.get("effects", []):
			if int(e.get("code", 0)) == 43:
				var sid := int(e.get("dataId", 0))
				var sk := XDB.rec("Skills", sid)
				if int(sk.get("stypeId", 0)) != 6 or not XTianqiSecrets.occupies_slot(sid):
					continue
				if XTianqiSecrets.is_banned_skill(sid):
					continue
				# 跳过专属限制书（如紫霞神功录）并保证不同门不互顶
				var sp: Dictionary = XTianqiSecrets.data().get("skills", {}).get(str(sid), {})
				if int(sp.get("only_actor", 0)) > 0:
					continue
				var sc := XTianqiSecrets.school_of(sid)
				if sc != "" and seen_sc.has(sc):
					continue
				if not out.any(func(x): return x[1] == sid):
					out.append([int(it.id), sid])
					if sc != "":
						seen_sc[sc] = true
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
	# 选 4 本不同门功法（首本 7168 裂魔大成带终伤，其余 3 本不同门不互顶）
	var books := []
	for sid in [7168, 7145, 7147, 7149]:
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
	# P2-1：二次超格读档不再重复赠送 free_pick（migrated 只给一次）
	XTianqiSecrets.ENABLED = false
	var extra_book: Array = _pick_gongfa_items(6)[5]
	msup2.learn_skill(int(extra_book[1]))
	XTianqiSecrets.ENABLED = true
	kit.save()
	var m3 := kit.reload()
	var msup3 := m3.actor(lsup.actor_id)
	_check("p2_1_second_overflow_no_repeat_free_pick", XTianqiSecrets.used_slots(msup3, m3) == 3 and not XTianqiSecrets.has_free_pick(msup3, m3), [XTianqiSecrets.used_slots(msup3, m3), XTianqiSecrets.has_free_pick(msup3, m3)])
	# P2-1：进入下一场战斗自动结束免费封印期
	var bs := Kit.new_game()
	var bsup := _find_actor_by_tier(bs, XTier.SUPER)
	bs.party = [bsup.actor_id]
	bs.battle_slots = [bsup.actor_id]
	XTianqiSecrets.ENABLED = false
	for i in range(5):
		bsup.learn_skill(int(books[i][1]))
	XTianqiSecrets.ENABLED = true
	XTianqiSecrets.migrate_after_load(bs)
	var before_battle_free := XTianqiSecrets.has_free_pick(bsup, bs)
	var blogic := XBattleLogic.new()
	blogic.setup(1, bs)
	_check("p2_1_free_pick_auto_ends_on_battle_start", before_battle_free and not XTianqiSecrets.has_free_pick(bsup, bs) and XTianqiSecrets.seal_cost(bs, bsup) > 0)

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
	_check("new_skin_list_title_has_slots", page1.skin.list_title.contains("秘籍格 3 / 3") and page1.skin.list_title.contains("已封 2") and page1.skin.list_title.contains("旧档补偿：免费封印中"), page1.skin.list_title)
	_check("new_skin_entries_include_sealed", page1.entries().size() >= 5 and page1.entries().any(func(sk): return XTianqiSecrets.is_entry_sealed(sk)), page1.entries().size())
	_check("new_skin_card_has_seal_btn", page1.skin._card_actions.size() >= 2 and str(page1.skin._card_actions[0].get("action", "")) == "seal" and str(page1.skin._card_actions[1].get("text", "")) == "结束免费期", page1.skin._card_actions)
	# 文字审 P3：新皮肤列表行尾不塞长原因挤名字，改为底栏提示；徽标新旧统一「占格/已封」
	var first_row: Dictionary = page1.skin.list.items[0] if not page1.skin.list.items.is_empty() else {}
	var meta_act := XTianqiSecrets.ui_row_meta(a1, page1.entries()[0], d1.state)
	_check("text_review_badge_and_no_row_squeeze", str(meta_act.get("badge", "")) == "占格" and str(meta_act.get("old_badge", "")) == "[占格]" and not first_row.has("reason") and XTianqiSecrets.ui_accept_hint(a1, page1.current(), d1.state) == "免费封印", [meta_act, first_row])
	await _shots_pair("new_skin_secrets_list")
	# 打开封印确认弹窗（免费补偿）
	page1.ok()
	await _frames(3)
	_check("new_skin_confirm_open", page1.mode == "secret_confirm" and page1.skin.confirm_dlg != null and str(page1.secret_spec.get("body", "")).contains("旧存档") and str(page1.secret_spec.get("body", "")).contains("结束免费期"))
	await _shots_pair("new_skin_secrets_confirm")
	# 确认免费封印
	page1.confirm_secret_choice(0)
	await _frames(2)
	_check("new_skin_sealed_via_ui", XTianqiSecrets.used_slots(a1, d1.state) == 2 and page1.mode == "list")
	# P2-1：改完离开技能页后自动结束免费封印期
	page1.cancel()
	page1.cancel()
	await _frames(2)
	_check("p2_1_free_pick_auto_ends_on_skill_page_close", not XTianqiSecrets.has_free_pick(a1, d1.state) and XTianqiSecrets.seal_cost(d1.state, a1) > 0)
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


# ---- 7. P1-1 总账分桶与 secret_kept 协同（满格功法＋抽奖被动＋血脉，3 本功法全算伤害）----

func _test_ledger_coexistence() -> void:
	var s := Kit.new_game()
	var sup := _find_actor_by_tier(s, XTier.SUPER)  # 3 格
	var enemy := XEnemy.new().setup(1, 3, 100.0)
	# 挑 3 本不同门且带 passiveHarmRi 的占格秘籍（含 7168 裂魔大成＋2 本通用被动书）
	var gongfas: Array[int] = [7168]
	var re_harm := RegEx.create_from_string("<passiveHarmRi\\s*:\\s*(\\d+)")
	for sk0 in XDB.table("Skills"):
		if not (sk0 is Dictionary):
			continue
		var sid := int(sk0.get("id", 0))
		if sid <= 0 or gongfas.has(sid) or not XTianqiSecrets.occupies_slot(sid) or XTianqiSecrets.is_banned_skill(sid):
			continue
		var sk := XDB.rec("Skills", sid)
		if int(sk.get("stypeId", 0)) != 4:
			continue
		var m := re_harm.search(str(sk.get("note", "")))
		if m != null and float(m.get_string(1)) > 0.0:
			gongfas.append(sid)
			if gongfas.size() >= 3:
				break
	gongfas.sort()
	var lotteries := [6305, 6306, 6307]
	var bloodlines := [2807, 3236]
	for sid in gongfas:
		sup.learn_skill(sid)
	for sid in lotteries:
		sup.learn_skill(sid)
	for sid in bloodlines:
		sup.learn_skill(sid)
	sup.refresh_passive()
	# 占格秘籍进 secret，抽奖被动与血脉回 actor 桶，不再混进秘籍格
	var bucket_ok := gongfas.all(func(id): return XTianqiLedger.bucket_of(XDB.rec("Skills", id), sup) == "secret") \
		and lotteries.all(func(id): return XTianqiLedger.bucket_of(XDB.rec("Skills", id), sup) == "actor") \
		and bloodlines.all(func(id): return XTianqiLedger.bucket_of(XDB.rec("Skills", id), sup) == "actor")
	_check("p1_1_bucket_uses_occupies_slot", bucket_ok)
	var by: Dictionary = sup.passive_cache().get("bySource", {})
	var kept := XTianqiLedger.secret_kept(sup, by)
	var expect_kept := gongfas.map(func(id): return "#%d" % id)
	_check("p1_1_secret_kept_all_3_gongfas", kept == expect_kept, [kept, expect_kept])
	var dmg_with := XDamage.calculate(XDB.rec("Skills", 1), sup, enemy, {"critical": false, "variance": false})
	var per := XTianqiBase.secret_slot(XTianqiLedger.nine_cap("secret_slot"))
	var expect_diff := 0.0
	for id in gongfas:
		expect_diff += minf(float(by.get("books", {}).get("globalHarmRi", {}).get("#%d" % id, 0.0)), per)
	# 把 3 本秘籍都封印后，终伤池必须正好少掉 3 本各自封顶到 per 后的合计值
	s.gold = 9999999
	for sid in gongfas:
		XTianqiSecrets.seal(s, sup, sid)
	var dmg_sealed := XDamage.calculate(XDB.rec("Skills", 1), sup, enemy, {"critical": false, "variance": false})
	var diff := float(dmg_with.breakdown.row.terminal) - float(dmg_sealed.breakdown.row.terminal)
	_check("p1_1_all_3_gongfa_damage_counted", is_equal_approx(diff, expect_diff) and float(dmg_with.value) > float(dmg_sealed.value), [diff, expect_diff, dmg_with.value, dmg_sealed.value])


# ---- 8. P2-2 单书多技能预检与固定角色 CE 预检 ----

func _test_multi_slot_and_fixed_actor() -> void:
	var s := Kit.new_game()
	var a30 := s.actor(30)  # 西凉女帝（CE 1088 物品 77 固定教 30 号角色，正练同时学 4901 + 4920）
	var other := _find_actor_by_tier(s, XTier.WEAK)
	if other.actor_id == 30:
		other = s.actor(1)
	s.party = [other.actor_id, 30]
	s.battle_slots = [other.actor_id, 30]
	var cap30 := XTianqiSecrets.limit(a30)
	var books := _pick_gongfa_items(cap30 + 2)
	# 给 30 号角色填到只剩 1 格空位；other 保持 0 格已用
	for i in range(cap30 - 1):
		a30.learn_skill(int(books[i][1]))
	_check("p2_2_setup_a30_one_left", XTianqiSecrets.used_slots(a30, s) == cap30 - 1 and XTianqiSecrets.used_slots(other, s) == 0)
	var item77 := XDB.rec("Items", 77)
	# 传 other 也会查对 30 号角色，且 1 格不够 2 格必须整本拒收
	var reason77 := XTianqiSecrets.item_learn_reason(other, item77, s)
	_check("p2_2_item77_checks_actor30_needs_2", not reason77.is_empty() and reason77.contains("需 2 格") and reason77.contains(a30.display_name()), reason77)
	# 通过 XItemScene._use_direct() 实测：不吃书、不预约 CE、弹提示
	s.gain_item(77, 1)
	var old_skin := XUiSkin.ENABLED
	XUiSkin.ENABLED = false
	var isc := XItemScene.new()
	add_child(isc)
	await _frames(2)
	isc._item = item77
	XToast.shown.clear()
	isc._use_direct()
	_check("p2_2_item77_direct_no_consume", s.item_count(77) == 1 and s.peek_common_event() == 0 and not XToast.shown.is_empty(), [s.item_count(77), s.peek_common_event(), XToast.shown])
	# 30 号角色再封 1 本（空出 2 格）后放行
	s.gold = 9999999
	XTianqiSecrets.seal(s, a30, int(books[0][1]))
	_check("p2_2_item77_allowed_with_2_slots", XTianqiSecrets.item_learn_reason(other, item77, s).is_empty())
	# 同测 code 43 单书双技能（物品 1998 幸运女神的眷顾：498 + 4817）
	var sup := _find_actor_by_tier(s, XTier.SUPER)
	s.party = [sup.actor_id]
	sup.learn_skill(int(books[0][1]))
	sup.learn_skill(int(books[1][1]))  # 2/3，只剩 1 格
	var item1998 := XDB.rec("Items", 1998)
	s.gain_item(1998, 1)
	isc._item = item1998
	isc._actor = 0
	_check("p2_2_item1998_needs_2_blocks_1_left", XTianqiSecrets.item_effective(sup, item1998, s) == 0 and XTianqiSecrets.item_learn_reason(sup, item1998, s).contains("需 2 格"))
	isc._use()
	_check("p2_2_item1998_no_consume", s.item_count(1998) == 1 and not sup.skill_ids.has(498) and not sup.skill_ids.has(4817))
	XTianqiSecrets.seal(s, sup, int(books[0][1]))  # 1/3，空出 2 格
	_check("p2_2_item1998_allowed_with_2_slots", XTianqiSecrets.item_effective(sup, item1998, s) == 1)
	isc.queue_free()
	await _frames(2)
	XUiSkin.ENABLED = old_skin


# ---- 9. P3-2 非道具学技能被拦的提示与防伪成功 ----

func _test_non_item_block_feedback() -> void:
	var s := Kit.new_game()
	var sup := _find_actor_by_tier(s, XTier.SUPER)
	var books := _pick_gongfa_items(5)
	for i in range(3):
		sup.learn_skill(int(books[i][1]))
	# 9a) forget_skill_scene.toggle：满格学占格秘籍时弹提示且不翻 r.kept
	var row := {"id": int(books[3][1]), "kept": false}
	XToast.shown.clear()
	XForgetSkillScene.toggle(sup, row)
	_check("p3_2_forget_toggle_no_flip", not bool(row.kept) and not sup.skill_ids.has(int(books[3][1])) and not XToast.shown.is_empty(), [row, XToast.shown])
	# 9b) CE 1626（88 号角色学 7515 + 紧随其后的 $.toaster('融合成功...')）：满格时弹秘籍满格提示且不弹「融合成功」
	var a88 := s.actor(88)
	var cap88 := XTianqiSecrets.limit(a88)
	var books88 := _pick_gongfa_items(cap88 + 1)
	for i in range(cap88):
		a88.learn_skill(int(books88[i][1]))
	var ce1626: Dictionary = XDB.table("CommonEvents")[1626]
	var sub_cmds := [ce1626.list[15], ce1626.list[16], {"code": 0, "indent": 3, "parameters": []}]
	var host := FakeMapHost.new()
	add_child(host)
	var interp := MVInterpreter.new(host, 0, 0, sub_cmds)
	XToast.shown.clear()
	await interp.run()
	_check("p3_2_ce1626_blocked_no_fake_success", not a88.skill_ids.has(7515) and not XToast.shown.is_empty() and not host.toasts.any(func(t): return str(t).contains("融合成功")), [a88.skill_ids.has(7515), XToast.shown, host.toasts])
	host.queue_free()
	await _frames(2)
	# 文字审 P3 细节校验（已封重学提示 + 满格启封提示）
	s.gold = 9999999
	XTianqiSecrets.seal(s, sup, int(books[0][1]))
	_check("text_review_p3_strings", XTianqiSecrets.learn_reason(sup, int(books[0][1]), s).contains("启封后生效") and XTianqiSecrets.learn_reason(sup, int(books[0][1]), s).contains("启封"))
	sup.learn_skill(int(books[3][1]))
	var up_full := XTianqiSecrets.unseal(s, sup, int(books[0][1]))
	_check("text_review_p3_unseal_full", str(up_full.get("reason", "")).contains("生效中的") and str(up_full.get("reason", "")).contains("3 / 3"), up_full)


# ---- 10. T473：天启篇运行时档位（95/2/22 → 3/4/4）＋老存档超量封印不丢书＋西游档零改动 ----

func _test_t473_runtime_tier_and_migration() -> void:
	var s := Kit.new_game()
	var a95 := s.actor(95)   # 三笠：天启超强者（原版 XTier 为强者）→ 应 3 格
	var a2 := s.actor(2)     # 绿司机：天启强者（原版 XTier 为弱者）→ 应 4 格
	var a22 := s.actor(22)   # 维利：天启强者（原版 XTier 为弱者）→ 应 4 格
	var a3 := s.actor(3)     # 艾坤：天启弱者 → 应 6 格
	# 三笠尚未锻炼/进阶时，秘籍格仍按天启名单档位（超强者 3 格），不随 battle_tier 浮动
	var caps := [XTianqiSecrets.limit(a95, s), XTianqiSecrets.limit(a2, s), XTianqiSecrets.limit(a22, s), XTianqiSecrets.limit(a3, s)]
	var tiers := [XTianqiSecrets.tier_of(a95, s), XTianqiSecrets.tier_of(a2, s), XTianqiSecrets.tier_of(a22, s), XTianqiSecrets.tier_of(a3, s)]
	var books := _pick_gongfa_items(8)
	for i in range(3):
		a95.learn_skill(int(books[i][1]))
	var r95 := XTianqiSecrets.learn_reason(a95, int(books[3][1]), s)
	_check("t473_secrets_limit_mikasa_green_willy",
		caps == [3, 4, 4, 6]
		and tiers == [XTier.SUPER, XTier.STRONG, XTier.STRONG, XTier.WEAK]
		and r95.contains("超强者最多装备 3 本秘籍"),
		{"caps": caps, "tiers": tiers, "r95": r95})
	# 老存档超量封印：模拟 T446 旧档下 95/2/22 已装 4/6/6 本书，读档时 XState.current 置 null（模拟标题页读档）走 XTianqiSave.after_load
	var legacy := Kit.new_game()
	XTianqiSecrets.ENABLED = false
	var l95 := legacy.actor(95)
	var l2 := legacy.actor(2)
	var l22 := legacy.actor(22)
	var b95: Array[int] = []
	var b2: Array[int] = []
	var b22: Array[int] = []
	for i in range(4):
		var sid := int(books[i][1])
		l95.learn_skill(sid)
		b95.append(sid)
	for i in range(6):
		var sid := int(books[i][1])
		l2.learn_skill(sid)
		l22.learn_skill(sid)
		b2.append(sid)
		b22.append(sid)
	var raw_save := legacy.to_dict()
	XTianqiSecrets.ENABLED = true
	XState.current = null  # 模拟标题页／非天启上下文读档，验证 migrate_after_load 传 s 不误退回 XTier
	var loaded := XState.from_dict(raw_save)
	XState.current = loaded
	var r_l95 := loaded.actor(95)
	var r_l2 := loaded.actor(2)
	var r_l22 := loaded.actor(22)
	var all_kept := b95.all(func(id): return r_l95.skill_ids.has(id)) \
		and b2.all(func(id): return r_l2.skill_ids.has(id)) \
		and b22.all(func(id): return r_l22.skill_ids.has(id))
	var slots_clamped := XTianqiSecrets.active_ids(r_l95, loaded).size() == 3 \
		and XTianqiSecrets.sealed_ids(r_l95, loaded).size() == 1 \
		and XTianqiSecrets.active_ids(r_l2, loaded).size() == 4 \
		and XTianqiSecrets.sealed_ids(r_l2, loaded).size() == 2 \
		and XTianqiSecrets.active_ids(r_l22, loaded).size() == 4 \
		and XTianqiSecrets.sealed_ids(r_l22, loaded).size() == 2 \
		and XTianqiSecrets.has_free_pick(r_l95, loaded) \
		and XTianqiSecrets.has_free_pick(r_l2, loaded) \
		and XTianqiSecrets.has_free_pick(r_l22, loaded)
	# 结束免费期后二次读档幂等：不丢书、不重复赠免费期
	XTianqiSecrets.finish_free_pick(loaded, r_l95)
	var loaded2 := XState.from_dict(loaded.to_dict())
	XState.current = loaded2
	var idempotent := XTianqiSecrets.active_ids(loaded2.actor(95), loaded2).size() == 3 \
		and XTianqiSecrets.sealed_ids(loaded2.actor(95), loaded2).size() == 1 \
		and not XTianqiSecrets.has_free_pick(loaded2.actor(95), loaded2)
	_check("t473_legacy_overflow_95_2_22_no_loss", all_kept and slots_clamped and idempotent, {
		"all_kept": all_kept, "slots_clamped": slots_clamped, "idempotent": idempotent,
		"act95": XTianqiSecrets.active_ids(r_l95, loaded).size(),
		"seal95": XTianqiSecrets.sealed_ids(r_l95, loaded).size(),
		"act2": XTianqiSecrets.active_ids(r_l2, loaded).size(),
		"seal2": XTianqiSecrets.sealed_ids(r_l2, loaded).size(),
		"act22": XTianqiSecrets.active_ids(r_l22, loaded).size(),
		"seal22": XTianqiSecrets.sealed_ids(r_l22, loaded).size(),
	})
	# 西游档零改动：XTianqi.active == false 时 limit 照 XTier（4/6/6），不拦学书，读档不建 flags.tianqi
	var xs := XState.new()
	XState.current = xs
	var x95 := xs.actor(95)
	var x2 := xs.actor(2)
	var x22 := xs.actor(22)
	var xy_caps := [XTianqiSecrets.limit(x95, xs), XTianqiSecrets.limit(x2, xs), XTianqiSecrets.limit(x22, xs)]
	for i in range(4):
		x95.learn_skill(int(books[i][1]))
	for i in range(6):
		x2.learn_skill(int(books[i][1]))
		x22.learn_skill(int(books[i][1]))
	var xs_reloaded := XState.from_dict(xs.to_dict())
	var xy_ok := not XTianqiSecrets.on(xs) \
		and xy_caps == [4, 6, 6] \
		and b95.all(func(id): return xs_reloaded.actor(95).skill_ids.has(id)) \
		and b2.all(func(id): return xs_reloaded.actor(2).skill_ids.has(id)) \
		and b22.all(func(id): return xs_reloaded.actor(22).skill_ids.has(id)) \
		and not xs_reloaded.flags.has("tianqi")
	_check("t473_xiyou_save_untouched", xy_ok, {"xy_caps": xy_caps, "has_tianqi": xs_reloaded.flags.has("tianqi")})


# ---- 11. T475 / D282：秘籍格随难度增加（五档×三档、降难度超量封印读档迁移、UI 与满格文案、西游档零改动）----

func _test_t475_difficulty_secret_cap() -> void:
	# 11a) 五档难度 × 三档角色精确断言（弱6/强4/超3 + 寻常/艰险 0、九死 +1、炼狱 +2、证道 +3）
	var matrix := {
		"xunchang": [0, 6, 4, 3],
		"jianxian": [0, 6, 4, 3],
		"jiusi": [1, 7, 5, 4],
		"lianyu": [2, 8, 6, 5],
		"zhengdao": [3, 9, 7, 6],
	}
	for diff_key in ["xunchang", "jianxian", "jiusi", "lianyu", "zhengdao"]:
		var s := Kit.new_game(diff_key)
		var w := _find_actor_by_tier(s, XTier.WEAK)
		var st := _find_actor_by_tier(s, XTier.STRONG)
		var su := _find_actor_by_tier(s, XTier.SUPER)
		var exp: Array = matrix[diff_key]
		var got_limit := [XTianqiSecrets.limit(w, s), XTianqiSecrets.limit(st, s), XTianqiSecrets.limit(su, s)]
		var got_ledger := [XTianqiLedger.secret_slots(w, s), XTianqiLedger.secret_slots(st, s), XTianqiLedger.secret_slots(su, s)]
		var bonus := XTianqiSecrets.difficulty_bonus(s)
		_check("t475_matrix_" + diff_key,
			bonus == int(exp[0]) and got_limit == exp.slice(1) and got_ledger == exp.slice(1),
			{"diff": diff_key, "bonus": bonus, "limit": got_limit, "ledger": got_ledger, "want": exp})
	# 回退开关 DIFFICULTY_BONUS = false → 证道回到 6/4/3
	var s_zd := Kit.new_game("zhengdao")
	var wz := _find_actor_by_tier(s_zd, XTier.WEAK)
	var stz := _find_actor_by_tier(s_zd, XTier.STRONG)
	var suz := _find_actor_by_tier(s_zd, XTier.SUPER)
	XTianqiSecrets.DIFFICULTY_BONUS = false
	var rb_caps := [XTianqiSecrets.limit(wz, s_zd), XTianqiSecrets.limit(stz, s_zd), XTianqiSecrets.limit(suz, s_zd)]
	var rb_ledger := [XTianqiLedger.secret_slots(wz, s_zd), XTianqiLedger.secret_slots(stz, s_zd), XTianqiLedger.secret_slots(suz, s_zd)]
	XTianqiSecrets.DIFFICULTY_BONUS = true
	_check("t475_difficulty_bonus_rollback", rb_caps == [6, 4, 3] and rb_ledger == [6, 4, 3], {"caps": rb_caps, "ledger": rb_ledger})

	# 11b) 换到低难度时多出的书走 T446 超量封印，书不丢，读档迁移断言（证道 9/7/6 → 寻常 6/4/3）
	var books := _pick_gongfa_items(10)
	_check("t475_ten_books_found", books.size() >= 10, books.size())
	var high_s := Kit.new_game("zhengdao")
	var hw := _find_actor_by_tier(high_s, XTier.WEAK)
	var hst := _find_actor_by_tier(high_s, XTier.STRONG)
	var hsu := _find_actor_by_tier(high_s, XTier.SUPER)
	var bw: Array[int] = []
	var bst: Array[int] = []
	var bsu: Array[int] = []
	for i in range(9):
		var sid := int(books[i][1])
		hw.learn_skill(sid)
		bw.append(sid)
	for i in range(7):
		var sid := int(books[i][1])
		hst.learn_skill(sid)
		bst.append(sid)
	for i in range(6):
		var sid := int(books[i][1])
		hsu.learn_skill(sid)
		bsu.append(sid)
	_check("t475_zhengdao_full_9_7_6",
		XTianqiSecrets.used_slots(hw, high_s) == 9
		and XTianqiSecrets.used_slots(hst, high_s) == 7
		and XTianqiSecrets.used_slots(hsu, high_s) == 6,
		[XTianqiSecrets.used_slots(hw, high_s), XTianqiSecrets.used_slots(hst, high_s), XTianqiSecrets.used_slots(hsu, high_s)])
	# 写盘后将难度降为寻常（+0），XState.current = null 模拟标题页真读档（经 XSave.load_slot → XTianqiSave.after_load）
	kit.save()
	kit.edit_raw(func(d: Dictionary): d["flags"]["tianqi"]["difficulty"] = "xunchang")
	XState.current = null
	var low_s := kit.reload()
	var lw := low_s.actor(hw.actor_id)
	var lst := low_s.actor(hst.actor_id)
	var lsu := low_s.actor(hsu.actor_id)
	var no_loss := bw.all(func(id): return lw.skill_ids.has(id)) \
		and bst.all(func(id): return lst.skill_ids.has(id)) \
		and bsu.all(func(id): return lsu.skill_ids.has(id))
	var clamped_643 := XTianqiSecrets.active_ids(lw, low_s).size() == 6 and XTianqiSecrets.sealed_ids(lw, low_s).size() == 3 \
		and XTianqiSecrets.active_ids(lst, low_s).size() == 4 and XTianqiSecrets.sealed_ids(lst, low_s).size() == 3 \
		and XTianqiSecrets.active_ids(lsu, low_s).size() == 3 and XTianqiSecrets.sealed_ids(lsu, low_s).size() == 3
	var sealed_inactive := XTianqiSecrets.sealed_ids(lsu, low_s).all(func(sid):
		return not lsu.skills().any(func(sk): return int(sk.get("id", 0)) == sid))
	var free_granted := XTianqiSecrets.has_free_pick(lw, low_s) and XTianqiSecrets.has_free_pick(lst, low_s) and XTianqiSecrets.has_free_pick(lsu, low_s)
	# 结束免费期再存读档幂等；若再切回炼狱（超强 5 格），已封的书仍在且可免费启封至 5 格
	XTianqiSecrets.finish_free_pick(low_s, lsu)
	var low_rt := kit.roundtrip()
	var lsu_rt := low_rt.actor(hsu.actor_id)
	var rt_idempotent := XTianqiSecrets.active_ids(lsu_rt, low_rt).size() == 3 \
		and XTianqiSecrets.sealed_ids(lsu_rt, low_rt).size() == 3 \
		and not XTianqiSecrets.has_free_pick(lsu_rt, low_rt)
	low_rt.flags.tianqi["difficulty"] = "lianyu"
	var unseal_sids := XTianqiSecrets.sealed_ids(lsu_rt, low_rt)
	var u1 := XTianqiSecrets.unseal(low_rt, lsu_rt, unseal_sids[0])
	var u2 := XTianqiSecrets.unseal(low_rt, lsu_rt, unseal_sids[1])
	var u3 := XTianqiSecrets.unseal(low_rt, lsu_rt, unseal_sids[2])  # 第 6 本超炼狱 5 格应被拦
	var back_high_ok := bool(u1.get("ok", false)) and bool(u2.get("ok", false)) and not bool(u3.get("ok", false)) \
		and XTianqiSecrets.used_slots(lsu_rt, low_rt) == 5 and str(u3.get("reason", "")).contains("5 / 5")
	# 再从炼狱运行期换回九死（超强 4 格）调 enforce_caps → 自动多封 1 本，不丢书
	low_rt.flags.tianqi["difficulty"] = "jiusi"
	XTianqiSecrets.enforce_caps(low_rt)
	var runtime_clamp_ok := XTianqiSecrets.used_slots(lsu_rt, low_rt) == 4 \
		and XTianqiSecrets.sealed_ids(lsu_rt, low_rt).size() == 2 \
		and bsu.all(func(id): return lsu_rt.skill_ids.has(id))
	_check("t475_downgrade_overflow_seal_and_migration",
		no_loss and clamped_643 and sealed_inactive and free_granted and rt_idempotent and back_high_ok and runtime_clamp_ok,
		{"no_loss": no_loss, "clamped": clamped_643, "sealed_inactive": sealed_inactive, "free": free_granted,
		 "rt_idem": rt_idempotent, "back_high": back_high_ok, "rt_clamp": runtime_clamp_ok})

	# 11c) 功法页 UI 显示当前难度格数，满格提示文案随之对（炼狱超强 5 格 + 证道弱者 9 格）
	var ui_s := Kit.new_game("lianyu")
	ui_s.set_variable(20, 12)
	ui_s.gold = 500000
	var ui_sup := _find_actor_by_tier(ui_s, XTier.SUPER)  # 炼狱超强 5 格
	ui_s.party = [ui_sup.actor_id]
	ui_s.battle_slots = [ui_sup.actor_id]
	for i in range(5):
		ui_sup.learn_skill(int(books[i][1]))
	# 满格提示文案（单技能 + code 43 多技能 + unseal + confirm）
	var r_single := XTianqiSecrets.learn_reason(ui_sup, int(books[5][1]), ui_s)
	var r_multi := XTianqiSecrets.item_learn_reason(ui_sup, XDB.rec("Items", 1998), ui_s)
	var lianyu_msg_ok := r_single.contains("炼狱难度下超强者最多装备 5 本秘籍（当前 5 / 5）") \
		and r_multi.contains("炼狱难度下超强者最多装备 5 本秘籍（当前 5 / 5，本书需 2 格）")
	# 证道弱者 9 格满格文案
	var zd_w_s := Kit.new_game("zhengdao")
	var zd_w := _find_actor_by_tier(zd_w_s, XTier.WEAK)
	for i in range(9):
		zd_w.learn_skill(int(books[i][1]))
	var r_zd_w := XTianqiSecrets.learn_reason(zd_w, int(books[9][1]), zd_w_s)
	_check("t475_full_slot_wording_by_difficulty",
		lianyu_msg_ok and r_zd_w.contains("证道难度下弱者最多装备 9 本秘籍（当前 9 / 9）"),
		{"r_single": r_single, "r_multi": r_multi, "r_zd_w": r_zd_w})

	# 切回炼狱档验证新旧两套皮肤功法页 UI 显示「秘籍格 5 / 5（炼狱 +2）」与详情牌副标题
	XState.current = ui_s
	await _clear_toasts()
	var old_skin := XUiSkin.ENABLED
	XUiSkin.ENABLED = true
	var p_new := XSkillScene.new()
	add_child(p_new)
	await _frames(3)
	_open_gongfa_tab(p_new)
	await _frames(3)
	var card_act := XTianqiSecrets.ui_card_actions(ui_s, ui_sup, p_new.current())
	_check("t475_ui_new_skin_lianyu_5_of_5",
		p_new.skin != null
		and p_new.skin.list_title.contains("秘籍格 5 / 5（炼狱 +2）")
		and str(card_act.get("tag", "")) == "占秘籍格（5 / 5，炼狱 +2）",
		{"list_title": p_new.skin.list_title if p_new.skin != null else "", "card_tag": card_act.get("tag", "")})
	await _shots_pair("t475_new_skin_lianyu_5of5")
	p_new.queue_free()
	await _frames(3)

	XUiSkin.ENABLED = false
	var p_old := XSkillScene.new()
	add_child(p_old)
	await _frames(3)
	_open_gongfa_tab(p_old)
	await _frames(3)
	var old_slot_txt := XTianqiSecrets.ui_slot_text(ui_sup, ui_s)
	_check("t475_ui_old_skin_lianyu_5_of_5",
		p_old.skin == null and old_slot_txt == "秘籍格 5 / 5（炼狱 +2）",
		old_slot_txt)
	await _shots_pair("t475_old_skin_lianyu_5of5")
	p_old.queue_free()
	await _frames(3)
	XUiSkin.ENABLED = old_skin

	# 11d) 西游档零改动（XTianqi.active 守卫）
	var xs := XState.new()
	xs.difficulty = 6  # 西游原版高难度（天灾）绝不能触发天启篇难度秘籍加成
	XState.current = xs
	var xw := xs.actor(3)
	var xst := xs.actor(95)
	var x_ok := XTianqiSecrets.difficulty_key(xs) == "" \
		and XTianqiSecrets.difficulty_bonus(xs) == 0 \
		and XTianqiSecrets.limit(xw, xs) == XTianqiBalance.secret_cap(XTier.tier_of(xw)) \
		and XTianqiSecrets.limit(xst, xs) == XTianqiBalance.secret_cap(XTier.tier_of(xst)) \
		and XTianqiLedger.secret_slots(xw, xs) == XTianqiBalance.secret_cap(XTier.tier_of(xw)) \
		and not XTianqiSecrets.on(xs)
	_check("t475_xiyou_save_zero_change", x_ok, {
		"key": XTianqiSecrets.difficulty_key(xs), "bonus": XTianqiSecrets.difficulty_bonus(xs),
		"lim_w": XTianqiSecrets.limit(xw, xs), "lim_st": XTianqiSecrets.limit(xst, xs),
	})


func _run() -> void:
	kit = Kit.new("xiyou_tianqi_secrets")
	_test_classification()
	_test_conversion_replace()
	await _test_intercept_and_seal()
	_test_save_and_migration()
	_test_rollback()
	_test_ledger_coexistence()
	await _test_multi_slot_and_fixed_actor()
	await _test_non_item_block_feedback()
	await _test_ui_both_skins()
	_test_t473_runtime_tier_and_migration()
	await _test_t475_difficulty_secret_cap()
	kit.teardown()
	var passed := results.filter(func(r): return r.passed).size()
	print("TEST_RESULT=", JSON.stringify({"passed": passed, "total": results.size()}))
	get_tree().quit(0 if passed == results.size() else 1)
